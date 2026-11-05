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
    private static func Width() -> Float { return 700.0; }

    private let m_rootCanvas: wref<inkCanvas>;
    private let m_collapsedView: wref<inkCanvas>;
    private let m_expandedView: wref<inkFlex>;

    private let m_cartIcon: wref<inkImage>;
    private let m_cartCountText: wref<inkText>;
    private let m_headerTotal: ref<GarageMoneyLine>;

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

    public func SetScreenManager(manager: ref<ScreenManager>) {
        this.m_screenManager = manager;
    }

    public func SetExitWarningPopup(popup: ref<ExitWarningPopup>) {
        this.m_exitWarningPopup = popup;
    }

    protected cb func OnCreate() {
        this.m_isExpanded = false;

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

        if IsDefined(this.m_headerTotal) { this.m_headerTotal.InitIcon(); }
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
        border.SetTintColor(GarageColors.AccentBlue());
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
        cartIcon.SetTintColor(GarageColors.AccentBlue());
        cartIcon.SetMargin(new inkMargin(20.0, 0.0, 0.0, 0.0));
        cartIcon.Reparent(mainPanel);
        this.m_cartIcon = cartIcon;

        let countText = GarageLabel(n"cartCountText", "0", n"Bold", 36, GarageColors.AccentBlue(), mainPanel);
        countText.SetVAlign(inkEVerticalAlign.Center);
        this.m_cartCountText = countText;

        let sep = new inkRectangle();
        sep.SetName(n"separator");
        sep.SetSize(new Vector2(1.0, 24.0));
        sep.SetTintColor(GarageColors.AccentBlue());
        sep.SetOpacity(0.4);
        sep.SetMargin(new inkMargin(8.0, 0.0, 8.0, 0.0));
        sep.Reparent(mainPanel);

        this.m_headerTotal = GarageMoneyLine.Make(mainPanel, n"cartTotal", "", 36, 1.0);
        this.m_headerTotal.Root().SetHAlign(inkEHorizontalAlign.Left);
        this.m_headerTotal.Root().SetVAlign(inkEVerticalAlign.Center);
        this.m_headerTotal.Root().SetMargin(new inkMargin(6.0, 0.0, 0.0, 0.0));

        let spacer = new inkFlex();
        spacer.SetName(n"spacer");
        spacer.SetHAlign(inkEHorizontalAlign.Fill);
        spacer.Reparent(mainPanel);

        let expandIcon = GarageLabel(n"expandIcon", "v", n"Bold", 18, GarageColors.AccentBlue(), mainPanel);
        expandIcon.SetOpacity(0.6);
        expandIcon.SetVAlign(inkEVerticalAlign.Center);

        container.RegisterToCallback(n"OnRelease", this, n"OnExpandClick");
    }

    private func CreateExpandedView(parent: ref<inkCanvas>) {
        // Sized by what's in it, so nothing below the list can end up over it
        let container = new inkFlex();
        container.SetName(n"expandedView");
        container.SetAnchor(inkEAnchor.TopRight);
        container.SetAnchorPoint(new Vector2(1.0, 0.0));
        container.SetMargin(new inkMargin(0.0, 82.0, 0.0, 0.0));  // Below collapsed header (80px + 2px gap)
        container.SetFitToContent(true);
        container.Reparent(parent);
        this.m_expandedView = container;

        let bg = new inkRectangle();
        bg.SetName(n"expandedBg");
        bg.SetHAlign(inkEHorizontalAlign.Fill);
        bg.SetVAlign(inkEVerticalAlign.Fill);
        bg.SetTintColor(new HDRColor(0.02, 0.02, 0.03, 1.0));
        bg.SetOpacity(0.4);
        bg.Reparent(container);
        this.m_expandedBg = bg;

        let column = new inkVerticalPanel();
        column.SetName(n"column");
        column.SetHAlign(inkEHorizontalAlign.Center);
        column.SetVAlign(inkEVerticalAlign.Top);
        column.SetMargin(new inkMargin(15.0, 12.0, 15.0, 12.0));
        column.SetChildMargin(new inkMargin(0.0, 4.0, 0.0, 4.0));
        column.Reparent(container);

        let header = GarageLabel(n"headerText", GetLocalizedTextByKey(n"Garage-Cart-Header"), n"Bold", 36, GarageColors.AccentBlue(), column);
        header.SetHAlign(inkEHorizontalAlign.Center);
        this.m_headerText = header;

        let divider = new inkRectangle();
        divider.SetName(n"headerDivider");
        divider.SetSize(new Vector2(670.0, 1.0));
        divider.SetTintColor(GarageColors.AccentBlue());
        divider.SetOpacity(0.3);
        divider.Reparent(column);

        this.CreateList(column);

        let divider2 = new inkRectangle();
        divider2.SetName(n"totalDivider");
        divider2.SetSize(new Vector2(670.0, 1.0));
        divider2.SetTintColor(GarageColors.AccentBlue());
        divider2.SetOpacity(0.3);
        divider2.SetMargin(new inkMargin(0.0, 6.0, 0.0, 6.0));
        divider2.Reparent(column);

        this.m_total = GarageMoneyLine.Make(column, n"total", GetLocalizedTextByKey(n"Garage-Cart-TotalLabel"), GarageMoneyLine.TotalSize(), 1.0);
        this.m_total.Root().SetHAlign(inkEHorizontalAlign.Right);
        this.m_total.Root().SetMargin(new inkMargin(0.0, 0.0, 28.0, 0.0));

        let buttonsPanel = new inkHorizontalPanel();
        buttonsPanel.SetName(n"buttonsPanel");
        buttonsPanel.SetHAlign(inkEHorizontalAlign.Center);
        buttonsPanel.SetChildMargin(new inkMargin(8.0, 0.0, 8.0, 0.0));
        buttonsPanel.SetMargin(new inkMargin(0.0, 6.0, 0.0, 0.0));
        buttonsPanel.Reparent(column);

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

    private func CreateList(parent: ref<inkCompoundWidget>) {
        let region = new inkCanvas();
        region.SetName(n"listRegion");
        region.SetHAlign(inkEHorizontalAlign.Center);
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

        let empty = GarageLabel(n"emptyText", GetLocalizedTextByKey(n"Garage-Cart-Empty"), n"Regular", 18, GarageColors.AccentBlue(), items);
        empty.SetOpacity(0.4);
        empty.SetHorizontalAlignment(textHorizontalAlignment.Center);
        empty.SetVisible(false);
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
        fill.SetTintColor(GarageColors.AccentBlue());
        fill.SetOpacity(0.15);
        fill.Reparent(slider);

        let handle = new inkRectangle();
        handle.SetName(n"sliderHandle");
        handle.SetAnchor(inkEAnchor.TopFillHorizontaly);
        handle.SetSize(new Vector2(8.0, 40.0));
        handle.SetTintColor(GarageColors.AccentBlue());
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
        if IsDefined(this.m_headerTotal) {
            this.m_headerTotal.SetValue(formattedTotal);
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

    // Rows get rebound, never rebuilt. The pool only grows to the longest cart seen
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
                this.m_rows[i].Bind(items[i]);
            } else {
                this.m_rows[i].Clear();
            }
            i += 1;
        }
        this.UpdateExpandedHeight(count);
    }

    private func UpdateExpandedHeight(itemCount: Int32) {
        if !IsDefined(this.m_listRegion) {
            return;
        }
        let shown = Max(Min(itemCount, CartWidget.MaxRows()), 1);
        this.m_listRegion.SetSize(new Vector2(CartWidget.Width() - 20.0, Cast<Float>(shown) * CartWidget.RowStep()));
    }

    protected cb func OnRowRemove(widget: wref<inkWidget>) -> Bool {
        let subcategory = CartRow.Find(this.m_rows, widget);
        if IsNameValid(subcategory) { this.RemoveItem(subcategory); }
        return false;
    }

    public func RemoveItem(subcategory: CName) {
        GarageSystem.Get().Parts().RemoveFromCart(subcategory);
        if IsDefined(this.m_screenManager) {
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

/// One cart line, shared by the cart and checkout. The X fires OnRemove and the owner looks the row up with Find
public class CartRow extends inkCustomController {
    private let m_subcategory: CName;
    private let m_name: wref<inkText>;
    private let m_price: ref<GarageMoneyLine>;
    private let m_iconReady: Bool;

    public static func Width() -> Float { return 644.0; }
    // What's left for the name once the price and the X have their room
    private static func NameWidth() -> Float { return 400.0; }

    public func Subcategory() -> CName { return this.m_subcategory; }

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

        let name = GarageLabel(n"itemName", "", n"Regular", fontSize, GarageColors.AccentBlue(), row);
        name.SetAnchor(inkEAnchor.CenterLeft);
        name.SetAnchorPoint(new Vector2(0.0, 0.5));
        name.SetMargin(new inkMargin(15.0, 0.0, 0.0, 0.0));
        name.SetSize(new Vector2(CartRow.NameWidth(), CartWidget.RowHeight()));
        name.SetOverflowPolicy(textOverflowPolicy.DotsEnd);
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
        this.m_price = GarageMoneyLine.Make(row, n"price", "", fontSize, 1.0);
        let price = this.m_price.Root();
        price.SetAnchor(inkEAnchor.CenterRight);
        price.SetAnchorPoint(new Vector2(1.0, 0.5));
        price.SetMargin(new inkMargin(0.0, 0.0, 57.0, 0.0));
    }

    public func Bind(item: ref<GarageCartItem>) {
        this.GetRootWidget().SetVisible(true);
        this.m_subcategory = item.category;
        this.m_name.SetText(item.name);
        this.m_price.SetValue(GarageText.Price(item.Total()));
        // The atlas only takes once the row's in the tree
        if !this.m_iconReady {
            this.m_iconReady = true;
            this.m_price.InitIcon();
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
