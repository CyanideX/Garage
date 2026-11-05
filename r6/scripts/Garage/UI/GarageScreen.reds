module Garage.UI

import Codeware.UI.*
import Garage.*
import Garage.Data.*
import Garage.Economy.*
import Garage.Scene.*
import Garage.Services.*
import Garage.Vehicle.*
import Garage.World.*
import VehicleCore.*
import VehicleCore.Features.*

public static func GetMoneyIconAtlas() -> ResRef {
    return r"base\\gameplay\\gui\\quests\\assets\\personal_link.inkatlas";
}

public static func GetMoneyIconPart() -> CName {
    return n"money_ico";
}

// Formats price with commas (e.g., 12000 -> "12,000")

public static func FormatCheckoutLabel(label: String, count: Int32, total: Int32) -> String {
    return s"\(label) (\(count)) - €$\(GarageText.Price(total))";
}

// Initialize money icon atlas (call after reparenting)
public static func InitMoneyIcon(icon: ref<inkImage>) {
    if IsDefined(icon) {
        icon.SetAtlasResource(GetMoneyIconAtlas());
        icon.SetTexturePart(GetMoneyIconPart());
        icon.SetVisible(true);
    }
}

public static func GarageLabel(name: CName, text: String, style: CName, size: Int32, tint: HDRColor, parent: ref<inkCompoundWidget>) -> ref<inkText> {
    let label = new inkText();
    label.SetName(name);
    label.SetText(text);
    label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    label.SetFontStyle(style);
    label.SetFontSize(size);
    label.SetTintColor(tint);
    label.Reparent(parent);
    return label;
}

// A label can be anything an addon or a translation hands us, and a button neither wraps nor clips
public static func FittedButtonSize(text: String, width: Float) -> Int32 {
    if StrLen(text) == 0 { return 50; }
    return Min(50, RoundF((width - 40.0) / (Cast<Float>(StrLen(text)) * 0.52)));
}

public static func SetButtonFontSize(btn: ref<SimpleButton>, size: Int32) -> Void {
    let root = btn.GetRootWidget() as inkCompoundWidget;
    let label = IsDefined(root) ? root.GetWidgetByPathName(n"label") as inkText : null;
    if IsDefined(label) { label.SetFontSize(size); }
}

public static func FitButtonText(btn: ref<SimpleButton>, text: String, width: Float) -> Void {
    if StrLen(text) > 0 { SetButtonFontSize(btn, FittedButtonSize(text, width)); }
}

// SetText on its own keeps the size the old label needed
public static func SetButtonText(btn: ref<SimpleButton>, text: String) -> Void {
    btn.SetText(text);
    FitButtonText(btn, text, btn.GetRootWidget().GetWidth());
}

// Side by side they read as a set, so the longer label sets the size for both
public static func FitButtonPair(a: ref<SimpleButton>, b: ref<SimpleButton>) -> Void {
    let size: Int32 = Min(FittedButtonSize(a.GetText(), a.GetRootWidget().GetWidth()), FittedButtonSize(b.GetText(), b.GetRootWidget().GetWidth()));
    SetButtonFontSize(a, size);
    SetButtonFontSize(b, size);
}

public abstract class GarageScreen extends inkCustomController {
    protected let m_name: String;
    protected let m_garageFrame: wref<GarageFrame>;
    protected let m_screenManager: wref<ScreenManager>;
    protected let m_container: wref<inkCanvas>;
    protected let m_isVisible: Bool;
    protected let m_backBtn: wref<SimpleButton>;
    protected let m_backContainer: wref<inkCanvas>;
    protected let m_titleText: wref<inkText>;

    public func SetScreenManager(manager: ref<ScreenManager>) -> Void {
        this.m_screenManager = manager;
    }

    protected cb func OnAssign() {
        let namespace: String;
        StrSplitLast(NameToString(this.GetClassName()), ".", namespace, this.m_name);
        this.m_isVisible = false;
    }

    protected cb func OnCreate() {
        let root = new inkCanvas();
        root.SetName(this.GetClassName());
        root.SetAnchor(inkEAnchor.Fill);
        root.SetVisible(false);

        this.SetRootWidget(root);
    }

    protected func GetAreaSize() -> Vector2 {
        return this.m_garageFrame.GetSize();
    }

    protected func GetGameInstance() -> GameInstance {
        return this.m_garageFrame.GetGameInstance();
    }

    /// True for a screen that frames the car for paying.
    protected func UsesCheckoutCamera() -> Bool { return false; }

    // The camera only moves when the screen really comes or goes
    public func Show() {
        let wasVisible = this.m_isVisible;
        this.m_isVisible = true;
        this.GetRootWidget().SetVisible(true);
        if !wasVisible && this.UsesCheckoutCamera() { GarageSystem.Get().Scene().Checkout(); }
    }

    public func Hide() {
        let wasVisible = this.m_isVisible;
        this.m_isVisible = false;
        this.GetRootWidget().SetVisible(false);
        if wasVisible && this.UsesCheckoutCamera() { GarageSystem.Get().Scene().ExitCheckout(); }
    }

    public func IsVisible() -> Bool {
        return this.m_isVisible;
    }

    // Pagination hooks for scroll input. Override in paginated screens.
    public func NextPage() -> Void {}
    public func PrevPage() -> Void {}

    // Constraint popup delegate hooks. Override in screens that host a ConstraintPopup.
    public func HideMainElements() -> Void {}
    public func ShowMainElements() -> Void {}
    public func HandleConstraintConfirmed() -> Void {}
    public func HandleConstraintCancelled() -> Void {}

    // Override in screens with cart-derived UI (badges, button labels).
    public func RefreshAfterCartChange() -> Void {}

    /// Esc or back on this screen. Return true if you dealt with it, like reverting a preview before going back yourself.
    public func OnBack() -> Bool { return false; }

    /// True if Esc here should ask before going back with a cart, since the warning's yes empties it and goes to the hub.
    public func WarnsOnBack() -> Bool { return false; }

    // Null until the footer's initialized
    protected func UpdateHint(action: CName, label: String, active: Bool) {
        let hints = this.m_garageFrame.GetHints();
        if !IsDefined(hints) { return; }
        if active {
            hints.AddButtonHint(action, label);
        } else {
            hints.RemoveButtonHint(action);
        }
    }

    protected func RemoveHint(action: CName) {
        let hints = this.m_garageFrame.GetHints();
        if IsDefined(hints) { hints.RemoveButtonHint(action); }
    }

    protected func Trigger(event: CName) {
        this.m_garageFrame.CallCustomCallback(event);
    }

    public func Assign(garageFrame: ref<GarageFrame>) {
        this.m_garageFrame = garageFrame;
        this.m_container = this.m_garageFrame.GetContainer();

        this.OnAssign();
        this.Reparent(this.m_garageFrame);
    }

    protected func CreateBackButton(root: ref<inkCanvas>) -> Void {
        let backContainer = new inkCanvas();
        backContainer.SetName(n"backContainer");
        backContainer.SetAnchor(inkEAnchor.TopLeft);
        backContainer.SetAnchorPoint(new Vector2(0.0, 0.0));
        backContainer.SetMargin(new inkMargin(72.0, 60.0, 0.0, 0.0));
        backContainer.SetSize(new Vector2(120.0, 40.0));
        backContainer.Reparent(root);
        this.m_backContainer = backContainer;

        this.m_backBtn = SimpleButton.Create();
        this.m_backBtn.SetName(n"backBtn");
        this.m_backBtn.SetText("<");
        this.m_backBtn.SetWidth(120.0);
        this.m_backBtn.ToggleAnimations(true);
        this.m_backBtn.ToggleSounds(true);
        this.m_backBtn.Reparent(backContainer);
        this.m_backBtn.RegisterToCallback(n"OnBtnClick", this, n"OnBackClick");
    }

    protected cb func OnBackClick(widget: wref<inkWidget>) -> Bool {
        let manager: ref<ScreenManager> = this.m_screenManager;
        if IsDefined(manager) { manager.Back(); }
        return false;
    }

    protected func CreateTitle(root: ref<inkCanvas>, text: String, marginTop: Float) -> ref<inkText> {
        let title = new inkText();
        title.SetName(n"title");
        title.SetText(text);
        title.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        title.SetFontStyle(n"Bold");
        title.SetFontSize(42);
        title.SetTintColor(GarageColors.AccentBlue());
        title.SetAnchor(inkEAnchor.TopCenter);
        title.SetAnchorPoint(new Vector2(0.5, 0.0));
        title.SetMargin(new inkMargin(0.0, marginTop, 0.0, 0.0));
        title.SetHorizontalAlignment(textHorizontalAlignment.Center);
        title.Reparent(root);
        this.m_titleText = title;
        return title;
    }

    protected func CreateStandardButton(name: CName, text: String, width: Float, parent: ref<inkCompoundWidget>, callbackName: CName) -> ref<SimpleButton> {
        let btn = SimpleButton.Create();
        btn.SetName(name);
        btn.SetText(text);
        btn.SetWidth(width);
        FitButtonText(btn, text, width);
        btn.ToggleAnimations(true);
        btn.ToggleSounds(true);
        btn.Reparent(parent);
        btn.RegisterToCallback(n"OnBtnClick", this, callbackName);
        return btn;
    }

    // SimpleButton's 100 tall, so rows stack every 110. Level 0 is the pager's line
    protected func CreateBottomRow(root: ref<inkCanvas>, name: CName, level: Int32) -> ref<inkHorizontalPanel> {
        let row = new inkHorizontalPanel();
        row.SetName(name);
        row.SetAnchor(inkEAnchor.BottomCenter);
        row.SetAnchorPoint(new Vector2(0.5, 1.0));
        row.SetMargin(new inkMargin(0.0, 0.0, 0.0, 50.0 + 110.0 * Cast<Float>(level)));
        row.SetChildMargin(new inkMargin(10.0, 0.0, 10.0, 0.0));
        row.Reparent(root);
        return row;
    }

    // Every paged screen gets the same pager in the same spot. The arrows route to NextPage/PrevPage
    protected func CreatePagination(root: ref<inkCanvas>, itemsPerPage: Int32) -> ref<PaginationHelper> {
        let container = this.CreateBottomRow(root, n"paginationContainer", 0);
        container.SetChildMargin(new inkMargin(15.0, 0.0, 15.0, 0.0));

        let prevBtn = this.CreateStandardButton(n"prevPageBtn", "<", 200.0, container, n"OnPrevPageClick");

        let pageText = new inkText();
        pageText.SetName(n"pageText");
        pageText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        pageText.SetFontStyle(n"Regular");
        pageText.SetFontSize(24);
        pageText.SetTintColor(GarageColors.AccentBlue());
        pageText.SetMargin(new inkMargin(0.0, 32.0, 0.0, 0.0));
        pageText.Reparent(container);

        let nextBtn = this.CreateStandardButton(n"nextPageBtn", ">", 200.0, container, n"OnNextPageClick");

        let pagination = PaginationHelper.Create(itemsPerPage);
        pagination.SetWidgets(prevBtn, nextBtn, pageText);
        pagination.UpdateWidgets();
        return pagination;
    }

    protected cb func OnPrevPageClick(widget: wref<inkWidget>) -> Bool {
        this.PrevPage();
        return false;
    }

    protected cb func OnNextPageClick(widget: wref<inkWidget>) -> Bool {
        this.NextPage();
        return false;
    }
}

/// Label, money icon and amount, built one way so every total lines up
/// An empty label leaves the label out, for a bare price
public class GarageMoneyLine extends IScriptable {
    private let m_root: wref<inkHorizontalPanel>;
    private let m_icon: wref<inkImage>;
    private let m_value: wref<inkText>;

    public static func TotalSize() -> Int32 { return 48; }
    public static func LineSize() -> Int32 { return 30; }
    // The text's visible height against its point size, so the icon stands as tall as the digits beside it
    public static func IconRatio() -> Float { return 0.8; }
    // The game draws its own price icons 50x30. A square box squashes the art
    public static func IconAspect() -> Float { return 50.0 / 30.0; }

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

        if StrLen(label) > 0 {
            let text = GarageLabel(StringToName(NameToString(name) + "Label"), label, style, size, GarageColors.AccentBlue(), row);
            text.SetOpacity(labelOpacity);
            text.SetVAlign(inkEVerticalAlign.Center);
            text.SetMargin(new inkMargin(0.0, 0.0, points / 3.0, 0.0));
        }

        let icon = new inkImage();
        icon.SetName(StringToName(NameToString(name) + "Icon"));
        let height = points * GarageMoneyLine.IconRatio();
        icon.SetSize(new Vector2(height * GarageMoneyLine.IconAspect(), height));
        icon.SetFitToContent(false);
        icon.SetBrushMirrorType(inkBrushMirrorType.NoMirror);
        icon.SetMargin(new inkMargin(0.0, 0.0, points / 8.0, 0.0));
        icon.SetTintColor(GarageColors.Gold());
        icon.SetVAlign(inkEVerticalAlign.Center);
        icon.Reparent(row);
        line.m_icon = icon;

        let value = GarageLabel(StringToName(NameToString(name) + "Value"), "0", n"Bold", size, GarageColors.Gold(), row);
        value.SetVAlign(inkEVerticalAlign.Center);
        line.m_value = value;

        line.InitIcon();
        return line;
    }

    public func Root() -> wref<inkHorizontalPanel> { return this.m_root; }
    public func Icon() -> wref<inkImage> { return this.m_icon; }
    public func Value() -> wref<inkText> { return this.m_value; }
    public func SetValue(text: String) { this.m_value.SetText(text); }
    // Again whenever the widget's shown: an atlas set while hidden doesn't take
    public func InitIcon() { InitMoneyIcon(this.m_icon); }
}
