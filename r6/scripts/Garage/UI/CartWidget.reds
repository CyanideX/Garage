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

    private let ItemFontSize: Int32 = 32;
    private let ItemRowHeight: Float = 42.0;  // FontSize(32) + 10

    private let m_rootCanvas: wref<inkCanvas>;
    private let m_collapsedView: wref<inkCanvas>;
    private let m_expandedView: wref<inkCanvas>;

    private let m_cartIcon: wref<inkImage>;
    private let m_cartCountText: wref<inkText>;
    private let m_cartTotalText: wref<inkText>;
    private let m_cashIcon: wref<inkImage>;

    private let m_headerText: wref<inkText>;
    private let m_itemsContainer: wref<inkVerticalPanel>;
    private let m_totalLabel: wref<inkText>;
    private let m_totalValue: wref<inkText>;
    private let m_totalCashIcon: wref<inkImage>;
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
        InitMoneyIcon(this.m_totalCashIcon);
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

        let itemsContainer = new inkVerticalPanel();
        itemsContainer.SetName(n"itemsContainer");
        itemsContainer.SetChildMargin(new inkMargin(0.0, 2.0, 0.0, 2.0));
        itemsContainer.Reparent(headerPanel);
        this.m_itemsContainer = itemsContainer;

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

        let totalRow = new inkHorizontalPanel();
        totalRow.SetName(n"totalRow");
        totalRow.SetHAlign(inkEHorizontalAlign.Right);
        totalRow.SetChildMargin(new inkMargin(4.0, 0.0, 4.0, 0.0));
        totalRow.Reparent(bottomPanel);

        let totalLabel = new inkText();
        totalLabel.SetName(n"totalLabel");
        totalLabel.SetText(GetLocalizedTextByKey(n"Garage-Cart-TotalLabel"));
        totalLabel.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        totalLabel.SetFontStyle(n"Bold");
        totalLabel.SetFontSize(48);
        totalLabel.SetTintColor(this.m_accentColor);
        totalLabel.SetHAlign(inkEHorizontalAlign.Center);
        totalLabel.SetVAlign(inkEVerticalAlign.Center);
        totalLabel.SetMargin(new inkMargin(0.0, 0.0, 16.0, 0.0));
        totalLabel.Reparent(totalRow);
        this.m_totalLabel = totalLabel;

        let totalCashIcon = new inkImage();
        totalCashIcon.SetName(n"totalCashIcon");
        totalCashIcon.SetSize(new Vector2(48.0, 48.0));
        totalCashIcon.SetFitToContent(true);
        totalCashIcon.SetScale(new Vector2(1.0, 1.0));
        totalCashIcon.SetMargin(new inkMargin(0.0, 0.0, 6.0, 0.0));
        totalCashIcon.SetTintColor(this.m_priceColor);
        totalCashIcon.SetVAlign(inkEVerticalAlign.Center);
        totalCashIcon.Reparent(totalRow);
        this.m_totalCashIcon = totalCashIcon;

        let totalValue = new inkText();
        totalValue.SetName(n"totalValue");
        totalValue.SetText("0");
        totalValue.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        totalValue.SetFontStyle(n"Bold");
        totalValue.SetFontSize(48);
        totalValue.SetTintColor(this.m_priceColor);
        totalValue.SetMargin(new inkMargin(0.0, 0.0, 28.0, 0.0));
        totalValue.Reparent(totalRow);
        this.m_totalValue = totalValue;

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

        if IsDefined(this.m_totalValue) {
            this.m_totalValue.SetText(formattedTotal);
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

    private func RefreshItemsList() {
        if !IsDefined(this.m_itemsContainer) {
            return;
        }

        this.m_itemsContainer.RemoveAllChildren();

        let items = GarageSystem.Get().Parts().Cart().Items();
        if ArraySize(items) == 0 {
            let emptyText = new inkText();
            emptyText.SetName(n"emptyText");
            emptyText.SetText(GetLocalizedTextByKey(n"Garage-Cart-Empty"));
            emptyText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
            emptyText.SetFontStyle(n"Regular");
            emptyText.SetFontSize(18);
            emptyText.SetTintColor(this.m_accentColor);
            emptyText.SetOpacity(0.4);
            emptyText.SetHorizontalAlignment(textHorizontalAlignment.Center);
            emptyText.Reparent(this.m_itemsContainer);
            this.UpdateExpandedHeight(0);
            return;
        }

        for item in items { this.CreateItemRow(item); }

        this.UpdateExpandedHeight(ArraySize(items));
    }

    private func UpdateExpandedHeight(itemCount: Int32) {
        if !IsDefined(this.m_expandedView) {
            return;
        }

        let expandedWidth = 700.0;

        let baseHeight = 320.0;
        let itemsHeight = Cast<Float>(itemCount) * this.ItemRowHeight;
        let minHeight = 350.0;

        let totalHeight = MaxF(minHeight, baseHeight + itemsHeight);

        this.m_expandedView.SetSize(new Vector2(expandedWidth, totalHeight));
    }

    private func CreateItemRow(item: ref<GarageCartItem>) {
        let itemWidth = 660.0;

        let rowContainer = new inkCanvas();
        rowContainer.SetName(StringToName("itemRowContainer_" + NameToString(item.category)));
        rowContainer.SetSize(new Vector2(itemWidth, this.ItemRowHeight));
        rowContainer.Reparent(this.m_itemsContainer);

        let nameText = new inkText();
        nameText.SetName(n"itemName");
        nameText.SetText(item.name);
        nameText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        nameText.SetFontStyle(n"Regular");
        nameText.SetFontSize(this.ItemFontSize);
        nameText.SetTintColor(this.m_accentColor);
        nameText.SetAnchor(inkEAnchor.CenterLeft);
        nameText.SetAnchorPoint(new Vector2(0.0, 0.5));
        nameText.SetMargin(new inkMargin(15.0, 0.0, 0.0, 0.0));
        nameText.Reparent(rowContainer);

        // Remove button - CenterRight, sized 64x64 with scale 0.5 (renders at 32px)
        // Negative top/bottom margins let the hit area overflow the row without affecting layout
        let removeBtn = new inkImage();
        removeBtn.SetName(StringToName("removeBtn_" + NameToString(item.category)));
        removeBtn.SetAtlasResource(r"base\\gameplay\\gui\\common\\icons\\garage_menu_icons.inkatlas");
        removeBtn.SetTexturePart(n"garage_remove");
        removeBtn.SetSize(new Vector2(64.0, 64.0));
        removeBtn.SetScale(new Vector2(0.5, 0.5));
        removeBtn.SetFitToContent(false);
        removeBtn.SetBrushMirrorType(inkBrushMirrorType.NoMirror);
        removeBtn.SetContentHAlign(inkEHorizontalAlign.Center);
        removeBtn.SetContentVAlign(inkEVerticalAlign.Center);
        removeBtn.SetTintColor(new HDRColor(1.0, 1.0, 1.0, 1.0));
        removeBtn.SetOpacity(0.75);
        removeBtn.SetAnchor(inkEAnchor.CenterRight);
        removeBtn.SetAnchorPoint(new Vector2(1.0, 0.5));
        removeBtn.SetMargin(new inkMargin(0.0, -32.0, 0.0, -32.0));
        removeBtn.SetInteractive(true);
        removeBtn.Reparent(rowContainer);
        removeBtn.RegisterToCallback(n"OnRelease", this, n"OnRemoveItemClick");

        // 57 = 32px icon + 25px gap
        let priceRow = new inkHorizontalPanel();
        priceRow.SetName(n"priceRow");
        priceRow.SetAnchor(inkEAnchor.CenterRight);
        priceRow.SetAnchorPoint(new Vector2(1.0, 0.5));
        priceRow.SetMargin(new inkMargin(0.0, 0.0, 57.0, 0.0));
        priceRow.SetChildMargin(new inkMargin(2.0, 0.0, 2.0, 0.0));
        priceRow.Reparent(rowContainer);

        let priceIcon = CreateMoneyIconForFont(this.ItemFontSize, 0.5, this.m_priceColor);
        priceIcon.SetName(n"priceIcon");
        priceIcon.SetSize(new Vector2(32.0, 32.0));
        priceIcon.SetContentHAlign(inkEHorizontalAlign.Center);
        priceIcon.SetMargin(new inkMargin(4.0, 0.0, 4.0, 0.0));
        priceIcon.SetVAlign(inkEVerticalAlign.Center);
        priceIcon.Reparent(priceRow);
        // Dynamic items need atlas set after reparenting
        InitMoneyIcon(priceIcon);

        let priceText = new inkText();
        priceText.SetName(n"itemPrice");
        priceText.SetText(GarageText.Price(item.Total()));
        priceText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        priceText.SetFontStyle(n"Bold");
        priceText.SetFontSize(this.ItemFontSize);
        priceText.SetTintColor(this.m_priceColor);
        priceText.Reparent(priceRow);
    }

    protected cb func OnRemoveItemClick(evt: ref<inkPointerEvent>) -> Bool {
        if !evt.IsAction(n"click") {
            return false;
        }
        let target = evt.GetTarget();
        if !IsDefined(target) {
            XUtils.Mod("Garage").Log("UI").Warn("CartWidget.OnRemoveItemClick - no target widget");
            return false;
        }
        let nameStr = NameToString(target.GetName());
        let prefix = "removeBtn_";
        if !StrBeginsWith(nameStr, prefix) {
            return false;
        }
        let subcategoryId = StrMid(nameStr, StrLen(prefix));
        if StrLen(subcategoryId) == 0 {
            XUtils.Mod("Garage").Log("UI").Warn("CartWidget.OnRemoveItemClick - empty subcategoryId in widget name");
            return false;
        }
        GarageSystem.Get().Parts().RemoveFromCart(StringToName(subcategoryId));
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
        return false;
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
