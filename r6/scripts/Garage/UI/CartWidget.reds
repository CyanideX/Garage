module Garage.UI

import Codeware.UI.*
import Garage.*
import Garage.Data.*
import Garage.Economy.*
import Garage.Services.*
import Garage.Vehicle.*
import Garage.World.*
import VehicleCore.*
import VehicleCore.Features.*

public class CartWidget extends inkCustomController {
    private let m_screenManager: wref<ScreenManager>;
    private let m_exitWarningPopup: wref<ExitWarningPopup>;
    private let m_isExpanded: Bool;

    // Rows, the list and the panel are all sized from these, so the total can't end up over the last row
    public static func RowHeight() -> Float { return 42.0; }
    public static func RowGap() -> Float { return 2.0; }
    public static func RowStep() -> Float { return CartWidget.RowHeight() + 2.0 * CartWidget.RowGap(); }
    // Past this the list scrolls instead of running off the screen
    private static func MaxRows() -> Int32 { return 12; }
    private static func ListTop() -> Float { return 76.0; }
    private static func BottomHeight() -> Float { return 244.0; }
    private static func Width() -> Float { return 700.0; }

    private let m_rootCanvas: wref<inkCanvas>;
    private let m_collapsedView: wref<inkCanvas>;
    private let m_expandedView: wref<inkCanvas>;

    private let m_cartIcon: wref<inkImage>;
    private let m_cartCountText: wref<inkText>;
    private let m_cartTotalText: wref<inkText>;
    private let m_cashIcon: wref<inkImage>;

    private let m_headerText: wref<inkText>;
    private let m_itemsContainer: wref<inkVerticalPanel>;
    private let m_rows: array<ref<CartRow>>;
    private let m_emptyText: wref<inkText>;
    private let m_listRegion: wref<inkCanvas>;
    private let m_total: ref<GarageMoneyLine>;
    private let m_checkoutBtn: wref<SimpleButton>;
    private let m_clearBtn: wref<SimpleButton>;

    private let m_collapsedBg: wref<inkRectangle>;
    private let m_expandedBg: wref<inkRectangle>;

    private let m_accentColor: HDRColor;
    private let m_priceColor: HDRColor;

    public func SetScreenManager(manager: ref<ScreenManager>) {
        this.m_screenManager = manager;
    }

    public func SetExitWarningPopup(popup: ref<ExitWarningPopup>) {
        this.m_exitWarningPopup = popup;
    }

    protected cb func OnCreate() {
        this.m_isExpanded = false;
        this.m_accentColor = new HDRColor(0.24, 0.77, 0.89, 1.0);  // Electric Blue
        this.m_priceColor = new HDRColor(1.0, 0.81, 0.06, 1.0);    // Gold

        let root = new inkCanvas();
        root.SetName(n"CartWidget");
        root.SetAnchor(inkEAnchor.TopRight);
        root.SetAnchorPoint(new Vector2(1.0, 0.0));
        root.SetMargin(new inkMargin(0.0, GarageLayout.EdgeInsetTop(), GarageLayout.EdgeInsetSide(), 0.0));
        root.SetSize(new Vector2(400.0, 600.0));
        this.SetRootWidget(root);
        this.m_rootCanvas = root;

        this.CreateCollapsedView(root);
        this.CreateExpandedView(root);
        this.Collapse();
    }

    // Atlas resources must be set after the widget tree is fully built
    protected cb func OnInitialize() {
        this.InitializeIconAtlases();
    }

    private func InitializeIconAtlases() {
        // wandering_merchant is the closest thing to a shopping cart in the mappin atlas
        if IsDefined(this.m_cartIcon) {
            this.m_cartIcon.SetAtlasResource(r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas");
            this.m_cartIcon.SetTexturePart(n"wandering_merchant");
            this.m_cartIcon.SetVisible(true);
        }

        InitMoneyIcon(this.m_cashIcon);
        if IsDefined(this.m_total) { this.m_total.InitIcon(); }
    }

    private func CreateCollapsedView(parent: ref<inkCanvas>) {
        let container = new inkCanvas();
        container.SetName(n"collapsedView");
        container.SetAnchor(inkEAnchor.TopRight);
        container.SetAnchorPoint(new Vector2(1.0, 0.0));
        container.SetSize(new Vector2(700.0, 80.0));
        container.SetInteractive(true);
        container.Reparent(parent);
        this.m_collapsedView = container;

        let bg = new inkRectangle();
        bg.SetName(n"collapsedBg");
        bg.SetAnchor(inkEAnchor.Fill);
        bg.SetTintColor(new HDRColor(0.02, 0.02, 0.03, 1.0));
        bg.SetOpacity(0.85);
        bg.Reparent(container);
        this.m_collapsedBg = bg;

        let border = new inkRectangle();
        border.SetName(n"collapsedBorder");
        border.SetAnchor(inkEAnchor.Fill);
        border.SetTintColor(this.m_accentColor);
        border.SetOpacity(0.3);
        border.SetMargin(new inkMargin(-1.0, -1.0, -1.0, -1.0));
        border.Reparent(container);

        let mainPanel = new inkHorizontalPanel();
        mainPanel.SetName(n"collapsedContent");
        mainPanel.SetAnchor(inkEAnchor.Fill);
        mainPanel.SetVAlign(inkEVerticalAlign.Center);
        mainPanel.SetMargin(new inkMargin(16.0, 0.0, 12.0, 0.0));
        mainPanel.SetChildMargin(new inkMargin(6.0, 0.0, 6.0, 0.0));
        mainPanel.Reparent(container);

        // Atlas set in OnInitialize
        let cartIcon = new inkImage();
        cartIcon.SetName(n"cartIcon");
        cartIcon.SetSize(new Vector2(24.0, 24.0));
        cartIcon.SetBrushMirrorType(inkBrushMirrorType.NoMirror);
        cartIcon.SetContentHAlign(inkEHorizontalAlign.Center);
        cartIcon.SetContentVAlign(inkEVerticalAlign.Center);
        cartIcon.SetTintColor(this.m_accentColor);
        cartIcon.SetMargin(new inkMargin(20.0, 0.0, 0.0, 0.0));
        cartIcon.Reparent(mainPanel);
        this.m_cartIcon = cartIcon;

        let countText = new inkText();
        countText.SetName(n"cartCountText");
        countText.SetText("0");
        countText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        countText.SetFontStyle(n"Bold");
        countText.SetFontSize(36);
        countText.SetTintColor(this.m_accentColor);
        countText.SetVAlign(inkEVerticalAlign.Center);
        countText.Reparent(mainPanel);
        this.m_cartCountText = countText;

        let sep = new inkRectangle();
        sep.SetName(n"separator");
        sep.SetSize(new Vector2(1.0, 24.0));
        sep.SetTintColor(this.m_accentColor);
        sep.SetOpacity(0.4);
        sep.SetMargin(new inkMargin(8.0, 0.0, 8.0, 0.0));
        sep.Reparent(mainPanel);

        // Atlas set in OnInitialize
        let cashIcon = CreateMoneyIconForFont(24, 0.7, this.m_priceColor);
        cashIcon.SetName(n"cashIcon");
        cashIcon.SetSize(new Vector2(32.0, 32.0));
        cashIcon.SetContentHAlign(inkEHorizontalAlign.Center);
        cashIcon.SetMargin(new inkMargin(6.0, 0.0, 6.0, 0.0));
        cashIcon.SetVAlign(inkEVerticalAlign.Center);
        cashIcon.Reparent(mainPanel);
        this.m_cashIcon = cashIcon;

        let totalText = new inkText();
        totalText.SetName(n"cartTotalText");
        totalText.SetText("0");
        totalText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        totalText.SetFontStyle(n"Bold");
        totalText.SetFontSize(36);
        totalText.SetTintColor(this.m_priceColor);
        totalText.SetVAlign(inkEVerticalAlign.Center);
        totalText.Reparent(mainPanel);
        this.m_cartTotalText = totalText;

        let spacer = new inkFlex();
        spacer.SetName(n"spacer");
        spacer.SetHAlign(inkEHorizontalAlign.Fill);
        spacer.Reparent(mainPanel);

        let expandIcon = new inkText();
        expandIcon.SetName(n"expandIcon");
        expandIcon.SetText("v");
        expandIcon.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        expandIcon.SetFontStyle(n"Bold");
        expandIcon.SetFontSize(18);
        expandIcon.SetTintColor(this.m_accentColor);
        expandIcon.SetOpacity(0.6);
        expandIcon.SetVAlign(inkEVerticalAlign.Center);
        expandIcon.Reparent(mainPanel);

        container.RegisterToCallback(n"OnRelease", this, n"OnExpandClick");
    }

    private func CreateExpandedView(parent: ref<inkCanvas>) {
        let container = new inkCanvas();
        container.SetName(n"expandedView");
        container.SetAnchor(inkEAnchor.TopRight);
        container.SetAnchorPoint(new Vector2(1.0, 0.0));
        container.SetMargin(new inkMargin(0.0, 82.0, 0.0, 0.0));  // Below collapsed header (80px + 2px gap)
        container.SetSize(new Vector2(700.0, 500.0));
        container.Reparent(parent);
        this.m_expandedView = container;

        let bg = new inkRectangle();
        bg.SetName(n"expandedBg");
        bg.SetAnchor(inkEAnchor.Fill);
        bg.SetTintColor(new HDRColor(0.02, 0.02, 0.03, 1.0));
        bg.SetOpacity(0.4);
        bg.Reparent(container);
        this.m_expandedBg = bg;

        let headerPanel = new inkVerticalPanel();
        headerPanel.SetName(n"headerPanel");
        headerPanel.SetAnchor(inkEAnchor.TopCenter);
        headerPanel.SetAnchorPoint(new Vector2(0.5, 0.0));
        headerPanel.SetMargin(new inkMargin(15.0, 12.0, 15.0, 0.0));
        headerPanel.SetChildMargin(new inkMargin(0.0, 4.0, 0.0, 4.0));
        headerPanel.Reparent(container);

        let header = new inkText();
        header.SetName(n"headerText");
        header.SetText(GetLocalizedTextByKey(n"Garage-Cart-Header"));
        header.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        header.SetFontStyle(n"Bold");
        header.SetFontSize(36);
        header.SetTintColor(this.m_accentColor);
        header.SetHorizontalAlignment(textHorizontalAlignment.Center);
        header.Reparent(headerPanel);
        this.m_headerText = header;

        let divider = new inkRectangle();
        divider.SetName(n"headerDivider");
        divider.SetSize(new Vector2(670.0, 1.0));
        divider.SetTintColor(this.m_accentColor);
        divider.SetOpacity(0.3);
        divider.Reparent(headerPanel);

        this.CreateList(container);

        let bottomPanel = new inkVerticalPanel();
        bottomPanel.SetName(n"bottomPanel");
        bottomPanel.SetAnchor(inkEAnchor.BottomCenter);
        bottomPanel.SetAnchorPoint(new Vector2(0.5, 1.0));
        bottomPanel.SetMargin(new inkMargin(15.0, 0.0, 0.0, 12.0));
        bottomPanel.SetChildMargin(new inkMargin(0.0, 6.0, 0.0, 6.0));
        bottomPanel.Reparent(container);

        let divider2 = new inkRectangle();
        divider2.SetName(n"totalDivider");
        divider2.SetSize(new Vector2(670.0, 1.0));
        divider2.SetTintColor(this.m_accentColor);
        divider2.SetOpacity(0.3);
        divider2.Reparent(bottomPanel);

        this.m_total = GarageMoneyLine.Make(bottomPanel, n"total", GetLocalizedTextByKey(n"Garage-Cart-TotalLabel"), GarageMoneyLine.TotalSize(), 1.0);
        this.m_total.Root().SetHAlign(inkEHorizontalAlign.Right);
        this.m_total.Root().SetMargin(new inkMargin(0.0, 0.0, 28.0, 0.0));

        let buttonsPanel = new inkHorizontalPanel();
        buttonsPanel.SetName(n"buttonsPanel");
        buttonsPanel.SetHAlign(inkEHorizontalAlign.Center);
        buttonsPanel.SetChildMargin(new inkMargin(8.0, 0.0, 8.0, 0.0));
        buttonsPanel.Reparent(bottomPanel);

        this.m_clearBtn = SimpleButton.Create();
        this.m_clearBtn.SetName(n"clearBtn");
        this.m_clearBtn.SetText(GetLocalizedTextByKey(n"Garage-Cart-Clear"));
        this.m_clearBtn.SetWidth(250.0);
        this.m_clearBtn.ToggleAnimations(true);
        this.m_clearBtn.ToggleSounds(true);
        this.m_clearBtn.Reparent(buttonsPanel);
        this.m_clearBtn.RegisterToCallback(n"OnBtnClick", this, n"OnClearClick");

        this.m_checkoutBtn = SimpleButton.Create();
        this.m_checkoutBtn.SetName(n"checkoutBtn");
        this.m_checkoutBtn.SetText(GetLocalizedTextByKey(n"Garage-Cart-Checkout"));
        this.m_checkoutBtn.SetWidth(250.0);
        this.m_checkoutBtn.ToggleAnimations(true);
        this.m_checkoutBtn.ToggleSounds(true);
        this.m_checkoutBtn.Reparent(buttonsPanel);
        this.m_checkoutBtn.RegisterToCallback(n"OnBtnClick", this, n"OnCheckoutClick");
    }

    private func CreateList(parent: ref<inkCanvas>) {
        let region = new inkCanvas();
        region.SetName(n"listRegion");
        region.SetAnchor(inkEAnchor.TopCenter);
        region.SetAnchorPoint(new Vector2(0.5, 0.0));
        region.SetMargin(new inkMargin(0.0, CartWidget.ListTop(), 0.0, 0.0));
        region.SetSize(new Vector2(CartWidget.Width() - 20.0, CartWidget.RowStep()));
        region.Reparent(parent);
        this.m_listRegion = region;

        let area = new inkScrollArea();
        area.SetName(n"itemsScrollArea");
        area.SetAnchor(inkEAnchor.Fill);
        area.SetMargin(new inkMargin(0.0, 0.0, 16.0, 0.0));
        area.SetFitToContentDirection(inkFitToContentDirection.Horizontal);
        area.SetInteractive(true);
        area.Reparent(region);

        let items = new inkVerticalPanel();
        items.SetName(n"itemsContainer");
        items.SetChildMargin(new inkMargin(0.0, CartWidget.RowGap(), 0.0, CartWidget.RowGap()));
        items.Reparent(area);
        this.m_itemsContainer = items;

        let empty = new inkText();
        empty.SetName(n"emptyText");
        empty.SetText(GetLocalizedTextByKey(n"Garage-Cart-Empty"));
        empty.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        empty.SetFontStyle(n"Regular");
        empty.SetFontSize(18);
        empty.SetTintColor(this.m_accentColor);
        empty.SetOpacity(0.4);
        empty.SetHorizontalAlignment(textHorizontalAlignment.Center);
        empty.SetVisible(false);
        empty.Reparent(items);
        this.m_emptyText = empty;

        let slider = new inkCanvas();
        slider.SetName(n"sliderArea");
        slider.SetAnchor(inkEAnchor.RightFillVerticaly);
        slider.SetAnchorPoint(new Vector2(1.0, 0.0));
        slider.SetSize(new Vector2(8.0, CartWidget.RowStep()));
        slider.SetInteractive(true);
        slider.Reparent(region);

        let fill = new inkRectangle();
        fill.SetName(n"sliderFill");
        fill.SetAnchor(inkEAnchor.Fill);
        fill.SetTintColor(this.m_accentColor);
        fill.SetOpacity(0.15);
        fill.Reparent(slider);

        let handle = new inkRectangle();
        handle.SetName(n"sliderHandle");
        handle.SetAnchor(inkEAnchor.TopFillHorizontaly);
        handle.SetSize(new Vector2(8.0, 40.0));
        handle.SetTintColor(this.m_accentColor);
        handle.SetOpacity(0.5);
        handle.SetInteractive(true);
        handle.Reparent(slider);

        let sliderController = new inkSliderController();
        sliderController.slidingAreaRef = inkWidgetRef.Create(slider);
        sliderController.handleRef = inkWidgetRef.Create(handle);
        sliderController.direction = inkESliderDirection.Vertical;
        sliderController.autoSizeHandle = true;
        sliderController.Setup(0.0, 1.0, 0.0);
        slider.AttachController(sliderController);

        let scroll = new inkScrollController();
        scroll.ScrollArea = inkScrollAreaRef.Create(area);
        scroll.VerticalScrollBarRef = inkWidgetRef.Create(slider);
        scroll.autoHideVertical = true;
        region.AttachController(scroll);
    }

    public func Expand() {
        this.m_isExpanded = true;
        if IsDefined(this.m_collapsedView) {
            this.m_collapsedView.SetVisible(true);
        }
        if IsDefined(this.m_expandedView) {
            this.m_expandedView.SetVisible(true);
        }
        this.RefreshItemsList();
    }

    public func Collapse() {
        this.m_isExpanded = false;
        if IsDefined(this.m_collapsedView) {
            this.m_collapsedView.SetVisible(true);
        }
        if IsDefined(this.m_expandedView) {
            this.m_expandedView.SetVisible(false);
        }
    }

    public func Toggle() {
        if this.m_isExpanded {
            this.Collapse();
        } else {
            this.Expand();
        }
    }

    public func RefreshDisplay() {
        let count = GarageSystem.Get().Parts().Cart().Count();
        let total = GarageSystem.Get().Parts().Cart().Total();
        let formattedTotal = GarageText.Price(total);

        if IsDefined(this.m_cartCountText) {
            this.m_cartCountText.SetText(ToString(count));
        }
        if IsDefined(this.m_cartTotalText) {
            this.m_cartTotalText.SetText(formattedTotal);
        }

        if IsDefined(this.m_total) {
            this.m_total.SetValue(formattedTotal);
        }

        if count > 0 {
            this.Show();
        } else {
            this.Hide();
        }

        if this.m_isExpanded {
            this.RefreshItemsList();
        }
    }

    // Rows are kept and rebound; the pool only grows to the longest cart seen
    private func RefreshItemsList() {
        if !IsDefined(this.m_itemsContainer) {
            return;
        }
        let items = GarageSystem.Get().Parts().Cart().Items();
        let count = ArraySize(items);
        this.m_emptyText.SetVisible(count == 0);
        while ArraySize(this.m_rows) < count {
            let row = new CartRow();
            row.CreateInstance();
            row.RegisterToCallback(n"OnRemove", this, n"OnRowRemove");
            row.Reparent(this.m_itemsContainer);
            ArrayPush(this.m_rows, row);
        }
        let i = 0;
        while i < ArraySize(this.m_rows) {
            if i < count {
                this.m_rows[i].Bind(items[i], this.m_priceColor, this.m_accentColor);
            } else {
                this.m_rows[i].Clear();
            }
            i += 1;
        }
        this.UpdateExpandedHeight(count);
    }

    private func UpdateExpandedHeight(itemCount: Int32) {
        if !IsDefined(this.m_expandedView) || !IsDefined(this.m_listRegion) {
            return;
        }
        let shown = Max(Min(itemCount, CartWidget.MaxRows()), 1);
        let listHeight = Cast<Float>(shown) * CartWidget.RowStep();
        this.m_listRegion.SetSize(new Vector2(CartWidget.Width() - 20.0, listHeight));
        this.m_expandedView.SetSize(new Vector2(CartWidget.Width(), CartWidget.ListTop() + listHeight + CartWidget.BottomHeight()));
    }

    protected cb func OnRowRemove(widget: wref<inkWidget>) -> Bool {
        let subcategory = CartRow.Find(this.m_rows, widget);
        if IsNameValid(subcategory) { this.RemoveItem(subcategory); }
        return false;
    }

    public func RemoveItem(subcategory: CName) {
        GarageSystem.Get().Parts().RemoveFromCart(subcategory);
        this.RefreshDisplay();
        if IsDefined(this.m_screenManager) {
            let screen = this.m_screenManager.GetScreen(this.m_screenManager.GetCurrentScreen());
            if IsDefined(screen) {
                screen.RefreshAfterCartChange();
            }
            let garageFrame = this.m_screenManager.GetGarageFrame();
            if IsDefined(garageFrame) {
                garageFrame.TriggerCartChanged();
            }
        }
    }

    public func Show() {
        let root = this.GetRootWidget();
        if IsDefined(root) {
            root.SetVisible(true);
        }
        // Re-initialize atlases when showing - icons fail to load if set while invisible
        this.InitializeIconAtlases();
    }

    public func Hide() {
        let root = this.GetRootWidget();
        if IsDefined(root) {
            root.SetVisible(false);
        }
        this.Collapse();
    }

    protected cb func OnExpandClick(evt: ref<inkPointerEvent>) -> Bool {
        if evt.IsAction(n"click") {
            this.Toggle();
        }
        return false;
    }

    protected cb func OnCheckoutClick(widget: wref<inkWidget>) -> Bool {
        if IsDefined(this.m_screenManager) {
            this.m_screenManager.ShowScreen(n"parts_checkout");
        }
        this.Collapse();
        return false;
    }

    protected cb func OnClearClick(widget: wref<inkWidget>) -> Bool {
        let count = GarageSystem.Get().Parts().Cart().Count();
        if count == 0 {
            return false;
        }
        let total = GarageSystem.Get().Parts().Cart().Total();
        if IsDefined(this.m_exitWarningPopup) {
            this.m_exitWarningPopup.ShowForClearCart(count, total);
        } else {
            XUtils.Mod("Garage").Log("UI").Warn("CartWidget.OnClearClick - m_exitWarningPopup not set");
        }
        return false;
    }

    public func IsExpanded() -> Bool {
        return this.m_isExpanded;
    }
}

/// One cart line: name, price and a remove button. The cart and the checkout list both use it; a click on the X fires
/// OnRemove and the owner asks Subcategory() which item that was.
public class CartRow extends inkCustomController {
    private let m_subcategory: CName;
    private let m_name: wref<inkText>;
    private let m_price: wref<inkText>;
    private let m_icon: wref<inkImage>;
    private let m_iconReady: Bool;

    public static func Width() -> Float { return 644.0; }
    // What's left for the name once the price and the X have their room
    private static func NameWidth() -> Float { return 400.0; }

    public func Subcategory() -> CName { return this.m_subcategory; }

    // The row whose root fired a callback, by widget
    public static func Find(rows: array<ref<CartRow>>, widget: wref<inkWidget>) -> CName {
        for row in rows {
            if row.GetRootWidget() == widget { return row.Subcategory(); }
        }
        return n"";
    }

    protected cb func OnCreate() {
        let fontSize = 32;
        let row = new inkCanvas();
        row.SetName(n"cartRow");
        row.SetSize(new Vector2(CartRow.Width(), CartWidget.RowHeight()));
        this.SetRootWidget(row);

        let name = new inkText();
        name.SetName(n"itemName");
        name.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        name.SetFontStyle(n"Regular");
        name.SetFontSize(fontSize);
        name.SetAnchor(inkEAnchor.CenterLeft);
        name.SetAnchorPoint(new Vector2(0.0, 0.5));
        name.SetMargin(new inkMargin(15.0, 0.0, 0.0, 0.0));
        name.SetSize(new Vector2(CartRow.NameWidth(), CartWidget.RowHeight()));
        name.SetOverflowPolicy(textOverflowPolicy.DotsEnd);
        name.Reparent(row);
        this.m_name = name;

        // 64x64 at half scale draws at 32. The negative margins let the hit area overhang the row without moving it
        let remove = new inkImage();
        remove.SetName(n"removeBtn");
        remove.SetAtlasResource(r"base\\gameplay\\gui\\common\\icons\\garage_menu_icons.inkatlas");
        remove.SetTexturePart(n"garage_remove");
        remove.SetSize(new Vector2(64.0, 64.0));
        remove.SetScale(new Vector2(0.5, 0.5));
        remove.SetFitToContent(false);
        remove.SetBrushMirrorType(inkBrushMirrorType.NoMirror);
        remove.SetContentHAlign(inkEHorizontalAlign.Center);
        remove.SetContentVAlign(inkEVerticalAlign.Center);
        remove.SetOpacity(0.75);
        remove.SetAnchor(inkEAnchor.CenterRight);
        remove.SetAnchorPoint(new Vector2(1.0, 0.5));
        remove.SetMargin(new inkMargin(0.0, -32.0, 0.0, -32.0));
        remove.SetInteractive(true);
        remove.Reparent(row);
        remove.RegisterToCallback(n"OnRelease", this, n"OnRemoveClick");

        // 57 = the 32 px button and a 25 px gap
        let priceRow = new inkHorizontalPanel();
        priceRow.SetName(n"priceRow");
        priceRow.SetAnchor(inkEAnchor.CenterRight);
        priceRow.SetAnchorPoint(new Vector2(1.0, 0.5));
        priceRow.SetMargin(new inkMargin(0.0, 0.0, 57.0, 0.0));
        priceRow.SetChildMargin(new inkMargin(2.0, 0.0, 2.0, 0.0));
        priceRow.Reparent(row);

        let icon = CreateMoneyIconForFont(fontSize, 0.5, GarageColors.Gold());
        icon.SetName(n"priceIcon");
        icon.SetSize(new Vector2(32.0, 32.0));
        icon.SetContentHAlign(inkEHorizontalAlign.Center);
        icon.SetMargin(new inkMargin(4.0, 0.0, 4.0, 0.0));
        icon.SetVAlign(inkEVerticalAlign.Center);
        icon.Reparent(priceRow);
        this.m_icon = icon;

        let price = new inkText();
        price.SetName(n"itemPrice");
        price.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        price.SetFontStyle(n"Bold");
        price.SetFontSize(fontSize);
        price.Reparent(priceRow);
        this.m_price = price;
    }

    public func Bind(item: ref<GarageCartItem>, priceColor: HDRColor, nameColor: HDRColor) {
        this.GetRootWidget().SetVisible(true);
        this.m_subcategory = item.category;
        this.m_name.SetText(item.name);
        this.m_name.SetTintColor(nameColor);
        this.m_price.SetText(GarageText.Price(item.Total()));
        this.m_price.SetTintColor(priceColor);
        // The atlas only takes once the row's in the tree
        if !this.m_iconReady {
            this.m_iconReady = true;
            InitMoneyIcon(this.m_icon);
        }
    }

    public func Clear() {
        this.GetRootWidget().SetVisible(false);
        this.m_subcategory = n"";
    }

    protected cb func OnRemoveClick(evt: ref<inkPointerEvent>) -> Bool {
        if evt.IsAction(n"click") && IsNameValid(this.m_subcategory) { this.CallCustomCallback(n"OnRemove"); }
        return false;
    }
}

/// A label, the money icon and an amount, built the same way everywhere so totals line up: the cart's and checkout's
/// TOTAL at TotalSize, checkout's other lines at LineSize.
public class GarageMoneyLine extends IScriptable {
    private let m_root: wref<inkHorizontalPanel>;
    private let m_icon: wref<inkImage>;
    private let m_value: wref<inkText>;

    public static func TotalSize() -> Int32 { return 48; }
    public static func LineSize() -> Int32 { return 30; }

    public static func Make(parent: ref<inkCompoundWidget>, name: CName, label: String, size: Int32, labelOpacity: Float) -> ref<GarageMoneyLine> {
        let line = new GarageMoneyLine();
        let points = Cast<Float>(size);
        let style = size >= GarageMoneyLine.TotalSize() ? n"Bold" : n"Regular";

        let row = new inkHorizontalPanel();
        row.SetName(StringToName(NameToString(name) + "Row"));
        row.SetHAlign(inkEHorizontalAlign.Center);
        row.SetChildMargin(new inkMargin(4.0, 0.0, 4.0, 0.0));
        row.Reparent(parent);
        line.m_root = row;

        let text = new inkText();
        text.SetName(StringToName(NameToString(name) + "Label"));
        text.SetText(label);
        text.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        text.SetFontStyle(style);
        text.SetFontSize(size);
        text.SetTintColor(GarageColors.AccentBlue());
        text.SetOpacity(labelOpacity);
        text.SetVAlign(inkEVerticalAlign.Center);
        text.SetMargin(new inkMargin(0.0, 0.0, points / 3.0, 0.0));
        text.Reparent(row);

        let icon = new inkImage();
        icon.SetName(StringToName(NameToString(name) + "Icon"));
        icon.SetSize(new Vector2(points, points));
        icon.SetFitToContent(true);
        icon.SetMargin(new inkMargin(0.0, 0.0, points / 8.0, 0.0));
        icon.SetTintColor(GarageColors.Gold());
        icon.SetVAlign(inkEVerticalAlign.Center);
        icon.Reparent(row);
        line.m_icon = icon;

        let value = new inkText();
        value.SetName(StringToName(NameToString(name) + "Value"));
        value.SetText("0");
        value.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        value.SetFontStyle(n"Bold");
        value.SetFontSize(size);
        value.SetTintColor(GarageColors.Gold());
        value.SetVAlign(inkEVerticalAlign.Center);
        value.Reparent(row);
        line.m_value = value;

        line.InitIcon();
        return line;
    }

    public func Root() -> wref<inkHorizontalPanel> { return this.m_root; }
    public func Value() -> wref<inkText> { return this.m_value; }
    public func SetValue(text: String) { this.m_value.SetText(text); }
    // Again whenever the widget's shown: an atlas set while hidden doesn't take
    public func InitIcon() { InitMoneyIcon(this.m_icon); }
}
