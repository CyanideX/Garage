module Garage.UI

import Garage.Scene.*
import Codeware.UI.*
import Garage.*
import Garage.Data.*
import Garage.Economy.*
import Garage.Services.*
import Garage.Vehicle.*
import Garage.World.*
import VehicleCore.*
import VehicleCore.Features.*

public class ServiceHubScreen extends GarageScreen {
    private let m_buttonContainer: wref<inkVerticalPanel>;
    private let m_noServicesText: wref<inkText>;
    private let m_pagination: ref<PaginationHelper>;
    private let m_services: array<ref<GarageService>>;

    private let m_checkoutRow: wref<inkHorizontalPanel>;
    private let m_checkoutBtn: wref<SimpleButton>;

    private let m_isRendering: Bool;
    private let m_refreshPending: Bool;
    private let m_pulseProxies: array<ref<inkAnimProxy>>;

    public func NotifyStateChange() -> Void {
        if this.m_isRendering {
            this.m_refreshPending = true;
        } else if this.m_isVisible {
            this.Render();
        }
    }

    public func RefreshAfterCartChange() -> Void {
        if this.m_isVisible { this.UpdateCartIndicator(); }
    }

    protected cb func OnCreate() {
        super.OnCreate();

        let accentColor = GarageColors.AccentBlue();
        let root = this.GetRootWidget() as inkCanvas;

        this.CreateTitle(root, GetLocalizedTextByKey(n"Garage-Hub-Title"), 60.0);
        this.MakeLabel(root, n"subtitle", GetLocalizedTextByKey(n"Garage-Hub-Subtitle"), n"Regular", 32, accentColor, 120.0, 0.6);

        let buttonContainer = new inkVerticalPanel();
        buttonContainer.SetName(n"buttonContainer");
        buttonContainer.SetAnchor(inkEAnchor.TopCenter);
        buttonContainer.SetAnchorPoint(new Vector2(0.5, 0.0));
        buttonContainer.SetMargin(new inkMargin(0.0, 200.0, 0.0, 0.0));
        buttonContainer.SetChildMargin(new inkMargin(0.0, 10.0, 0.0, 10.0));
        buttonContainer.Reparent(root);
        this.m_buttonContainer = buttonContainer;

        let noServices = this.MakeLabel(root, n"noServicesText", GetLocalizedTextByKey(n"Garage-Hub-NoServices"), n"Regular", 32, accentColor, 240.0, 0.5);
        noServices.SetVisible(false);
        this.m_noServicesText = noServices;

        // 4 rows of 2 is all the hub has room for
        this.m_pagination = this.CreatePagination(root, 8);

        let checkoutRow = this.CreateBottomRow(root, n"checkoutRow", 185.0);
        checkoutRow.SetVisible(false);
        this.m_checkoutRow = checkoutRow;
        this.m_checkoutBtn = this.CreateSlottedButton(n"checkoutBtn", "", 700.0, checkoutRow, n"OnCheckoutClick");
    }

    public func Show() {
        if this.m_isVisible {
            return;
        }
        super.Show();
        this.Render();
    }

    public func Hide() {
        if !this.m_isVisible {
            return;
        }
        super.Hide();

        this.StopPulseAnimation();
        this.m_refreshPending = false;
    }

    public func NextPage() -> Void {
        if this.m_pagination.NextPage() {
            this.Render();
        }
    }

    public func PrevPage() -> Void {
        if this.m_pagination.PrevPage() {
            this.Render();
        }
    }

    private func Render() -> Void {
        this.m_isRendering = true;
        this.m_refreshPending = false;

        let context = this.BuildCurrentContext();
        this.m_services = this.VisibleServices(context);

        let total = ArraySize(this.m_services);
        this.m_pagination.SetTotalItems(total);
        this.m_pagination.ClampPage();
        this.m_pagination.UpdateWidgets();

        this.m_noServicesText.SetVisible(total == 0);
        this.UpdateCartIndicator();

        this.StopPulseAnimation();
        this.m_buttonContainer.RemoveAllChildren();

        let start = this.m_pagination.GetStartIndex();
        let end = this.m_pagination.GetEndIndex();
        let row: ref<inkHorizontalPanel>;
        let i = start;
        while i < end {
            if (i - start) % 2 == 0 {
                row = new inkHorizontalPanel();
                row.SetName(StringToName("buttonRow_" + IntToString((i - start) / 2)));
                row.SetHAlign(inkEHorizontalAlign.Center);
                row.SetChildMargin(new inkMargin(10.0, 0.0, 10.0, 0.0));
                row.Reparent(this.m_buttonContainer);
            }
            this.CreateServiceButton(i, row, context);
            i += 1;
        }

        this.m_isRendering = false;
        // A bridge read above can push an event back at us mid-render
        if this.m_refreshPending {
            this.Render();
        }
    }

    private func VisibleServices(context: ref<GarageContext>) -> array<ref<GarageService>> {
        let visible: array<ref<GarageService>>;
        let services = GarageSystem.Get().Services();
        for service in services {
            if service.IsVisible(context) { ArrayPush(visible, service); }
        }
        return visible;
    }

    // Name carries the m_services index for OnServiceButtonClick
    private func CreateServiceButton(index: Int32, row: ref<inkHorizontalPanel>, context: ref<GarageContext>) -> Void {
        let service = this.m_services[index];
        let btn = this.CreateStandardButton(StringToName("svc_" + IntToString(index)), service.Label(), 300.0, row, n"OnServiceButtonClick");
        if service.IsMuted(context) {
            this.ApplyMutedStyle(btn);
        } else {
            if service.IsHighlighted(context) { this.ApplyActiveStyle(btn); }
        }
    }

    protected cb func OnServiceButtonClick(widget: wref<inkWidget>) -> Bool {
        let name = NameToString(widget.GetName());
        if !StrBeginsWith(name, "svc_") {
            return false;
        }
        let i = StringToInt(StrRight(name, StrLen(name) - 4));
        if i < 0 || i >= ArraySize(this.m_services) {
            return false;
        }
        let service = this.m_services[i];
        let context = this.BuildCurrentContext();
        if !service.IsAvailable(context) {
            this.m_screenManager.ShowUnavailable(service.Label(), service.LockReason(context));
            return true;
        }
        GarageSystem.Get().Scene().GoTo(service.CameraPosition());
        service.Open(context);
        return true;
    }

    protected cb func OnCheckoutClick(widget: wref<inkWidget>) -> Bool {
        if IsDefined(this.m_screenManager) {
            this.m_screenManager.ShowScreen(n"parts_checkout");
        }
        return false;
    }

    private func UpdateCartIndicator() -> Void {
        let cart = GarageSystem.Get().Parts().Cart();
        let cartCount = cart.Count();
        this.m_checkoutRow.SetVisible(cartCount > 0);
        if cartCount > 0 {
            SetButtonText(this.m_checkoutBtn, FormatCheckoutLabel(GetLocalizedTextByKey(n"Garage-Hub-Checkout"), cartCount, cart.Total()));
        }
    }

    private func BuildCurrentContext() -> ref<GarageContext> {
        let context = GarageSystem.Get().Parts().Context();
        context.screens = this.m_screenManager;
        return context;
    }

    private func ApplyActiveStyle(btn: ref<SimpleButton>) -> Void {
        let btnRoot = btn.GetRootWidget() as inkCompoundWidget;
        if !IsDefined(btnRoot) { return; }

        // Codeware's hover anims fight the pulse
        btn.ToggleAnimations(false);

        let overlay = this.AddActiveOverlay(btnRoot, n"activeOverlay", 1.0);
        let outer = this.AddActiveOverlay(btnRoot, n"activeOverlayOuter", 0.5);
        outer.SetRenderTransformPivot(new Vector2(0.5, 0.5));
        outer.SetScale(new Vector2(1.02, 1.06));

        let animDef = new inkAnimDef();
        let interpol = new inkAnimTransparency();
        interpol.SetStartTransparency(0.25);
        interpol.SetEndTransparency(1.0);
        interpol.SetType(inkanimInterpolationType.Linear);
        interpol.SetMode(inkanimInterpolationMode.EasyInOut);
        interpol.SetDuration(0.5);
        animDef.AddInterpolator(interpol);

        let options: inkAnimOptions;
        options.loopType = inkanimLoopType.PingPong;
        options.loopInfinite = true;

        ArrayPush(this.m_pulseProxies, overlay.PlayAnimationWithOptions(animDef, options));
    }

    private func AddActiveOverlay(parent: ref<inkCompoundWidget>, name: CName, opacity: Float) -> ref<inkImage> {
        let overlay = new inkImage();
        overlay.SetName(name);
        overlay.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
        overlay.SetTexturePart(n"cell_fg");
        overlay.SetNineSliceScale(true);
        overlay.SetAnchor(inkEAnchor.Fill);
        overlay.SetTintColor(new HDRColor(1.0, 0.761, 0.0, 1.0));
        overlay.SetOpacity(opacity);
        overlay.Reparent(parent);
        return overlay;
    }

    private func StopPulseAnimation() -> Void {
        for proxy in this.m_pulseProxies {
            if IsDefined(proxy) { proxy.Stop(); }
        }
        ArrayClear(this.m_pulseProxies);
    }

    private func ApplyMutedStyle(btn: ref<SimpleButton>) -> Void {
        let btnRoot = btn.GetRootWidget() as inkCompoundWidget;
        if !IsDefined(btnRoot) { return; }

        btn.ToggleAnimations(false);
        this.SetMutedTint(btnRoot, false);

        let label = btnRoot.GetWidgetByPathName(n"label") as inkText;
        if !IsDefined(label) {
            label = btnRoot.GetWidgetByPathName(n"text") as inkText;
        }
        if IsDefined(label) {
            label.SetTintColor(new HDRColor(0.690, 0.475, 0.435, 1.0));
        }

        let fill = btnRoot.GetWidgetByPathName(n"fill");
        if IsDefined(fill) {
            fill.SetOpacity(1.0);
        }

        btnRoot.RegisterToCallback(n"OnHoverOver", this, n"OnMutedButtonHoverOver");
        btnRoot.RegisterToCallback(n"OnHoverOut", this, n"OnMutedButtonHoverOut");
    }

    private func SetMutedTint(btnRoot: ref<inkCompoundWidget>, hovered: Bool) -> Void {
        let bg = btnRoot.GetWidgetByPathName(n"bg");
        if IsDefined(bg) {
            bg.SetTintColor(hovered ? new HDRColor(0.337, 0.196, 0.196, 1.0) : new HDRColor(0.176, 0.067, 0.067, 1.0));
        }
        let fill = btnRoot.GetWidgetByPathName(n"fill");
        if IsDefined(fill) {
            fill.SetTintColor(hovered ? new HDRColor(0.337, 0.196, 0.196, 1.0) : new HDRColor(0.161, 0.094, 0.094, 1.0));
        }
        let frame = btnRoot.GetWidgetByPathName(n"frame");
        if IsDefined(frame) {
            frame.SetOpacity(hovered ? 0.5 : 0.35);
        }
    }

    protected cb func OnMutedButtonHoverOver(widget: wref<inkWidget>) -> Bool {
        let btnRoot = widget as inkCompoundWidget;
        if IsDefined(btnRoot) {
            this.SetMutedTint(btnRoot, true);
        }
        return false;
    }

    protected cb func OnMutedButtonHoverOut(widget: wref<inkWidget>) -> Bool {
        let btnRoot = widget as inkCompoundWidget;
        if IsDefined(btnRoot) {
            this.SetMutedTint(btnRoot, false);
        }
        return false;
    }

    private func MakeLabel(
        parent: ref<inkCompoundWidget>,
        name: CName,
        text: String,
        style: CName,
        size: Int32,
        color: HDRColor,
        topMargin: Float,
        opt opacity: Float
    ) -> ref<inkText> {
        let widget = new inkText();
        widget.SetName(name);
        widget.SetText(text);
        widget.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        widget.SetFontStyle(style);
        widget.SetFontSize(size);
        widget.SetTintColor(color);
        if opacity > 0.0 { widget.SetOpacity(opacity); }
        widget.SetAnchor(inkEAnchor.TopCenter);
        widget.SetAnchorPoint(new Vector2(0.5, 0.0));
        widget.SetMargin(new inkMargin(0.0, topMargin, 0.0, 0.0));
        widget.SetHorizontalAlignment(textHorizontalAlignment.Center);
        widget.Reparent(parent);
        return widget;
    }
}

public class UnavailableScreen extends GarageScreen {
    private let m_root: wref<inkCanvas>;
    private let m_vehicleNameText: wref<inkText>;
    private let m_divider: wref<inkRectangle>;
    private let m_messageText: wref<inkText>;

    private let m_title: String;
    private let m_message: String;

    public func SetMessage(title: String, message: String) -> Void {
        this.m_title = title;
        this.m_message = message;
    }

    protected cb func OnCreate() {
        let accentColor = GarageColors.AccentBlue();

        let root = new inkCanvas();
        root.SetName(n"unavailableScreen");
        root.SetAnchor(inkEAnchor.Fill);
        root.SetVisible(false);

        this.CreateBackButton(root);
        this.CreateTitle(root, "", 60.0);

        // Content panel (centered, matching ChopShopConfirmScreen layout)
        let contentPanel = new inkVerticalPanel();
        contentPanel.SetName(n"contentPanel");
        contentPanel.SetAnchor(inkEAnchor.Centered);
        contentPanel.SetAnchorPoint(new Vector2(0.5, 0.5));
        contentPanel.SetMargin(new inkMargin(100.0, 100.0, 100.0, 150.0));
        contentPanel.SetChildMargin(new inkMargin(0.0, 15.0, 0.0, 15.0));
        contentPanel.Reparent(root);

        let vehicleName = new inkText();
        vehicleName.SetName(n"vehicleName");
        vehicleName.SetText("");
        vehicleName.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        vehicleName.SetFontStyle(n"Bold");
        vehicleName.SetFontSize(60);
        vehicleName.SetTintColor(ThemeColors.ElectricBlue());
        vehicleName.SetHorizontalAlignment(textHorizontalAlignment.Center);
        vehicleName.Reparent(contentPanel);
        this.m_vehicleNameText = vehicleName;

        let divider = new inkRectangle();
        divider.SetName(n"divider");
        divider.SetSize(new Vector2(400.0, 2.0));
        divider.SetTintColor(ThemeColors.ElectricBlue());
        divider.SetOpacity(0.5);
        divider.SetMargin(new inkMargin(0.0, -10.0, 0.0, -10.0));
        divider.Reparent(contentPanel);
        this.m_divider = divider;

        let message = new inkText();
        message.SetName(n"message");
        message.SetText("");
        message.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        message.SetFontStyle(n"Regular");
        message.SetFontSize(36);
        message.SetTintColor(accentColor);
        message.SetOpacity(0.8);
        message.SetHorizontalAlignment(textHorizontalAlignment.Center);
        message.Reparent(contentPanel);
        this.m_messageText = message;

        this.m_root = root;
        this.SetRootWidget(root);
    }

    public func Show() -> Void {
        this.m_isVisible = true;
        this.m_root.SetVisible(true);

        let title = this.m_title;
        let message = this.m_message;
        let vehicleName = GarageSystem.Get().Parts().Context().vehicleDisplayName;

        if Equals(message, "") {
            message = GetLocalizedTextByKey(n"Garage-Unavailable-DefaultMessage");
        }

        if IsDefined(this.m_titleText) {
            this.m_titleText.SetText(title);
        }

        if IsDefined(this.m_vehicleNameText) {
            this.m_vehicleNameText.SetText(vehicleName);
            this.m_vehicleNameText.SetVisible(NotEquals(vehicleName, ""));
        }

        if IsDefined(this.m_divider) {
            this.m_divider.SetVisible(NotEquals(vehicleName, ""));
        }

        if IsDefined(this.m_messageText) {
            this.m_messageText.SetText(message);
        }
    }

    public func Hide() -> Void {
        this.m_isVisible = false;
        this.m_root.SetVisible(false);
    }
}
