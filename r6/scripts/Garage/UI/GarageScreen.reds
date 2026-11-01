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

// Create a money icon image with scale-based sizing (call InitMoneyIcon after reparenting)
// baseSize: the native icon size in the atlas (use 24.0 as default)
// scale: transform scale factor (e.g., 0.5 = half size)
public static func CreateMoneyIconScaled(baseSize: Float, scale: Float, tintColor: HDRColor) -> ref<inkImage> {
    let icon = new inkImage();
    icon.SetName(n"moneyIcon");
    icon.SetSize(new Vector2(baseSize, baseSize));
    icon.SetScale(new Vector2(scale, scale));
    icon.SetBrushMirrorType(inkBrushMirrorType.NoMirror);
    icon.SetContentHAlign(inkEHorizontalAlign.Left);
    icon.SetContentVAlign(inkEVerticalAlign.Center);
    icon.SetTintColor(tintColor);
    return icon;
}

// Creates a money icon scaled relative to font size.
// scaleFactor: fraction of fontSize the icon should occupy (e.g., 0.5 = 50%)
public static func CreateMoneyIconForFont(fontSize: Int32, scaleFactor: Float, tintColor: HDRColor) -> ref<inkImage> {
    // Atlas icon is natively 24px, so the scale factor is relative to that
    let targetSize = Cast<Float>(fontSize) * scaleFactor;
    let scale = targetSize / 24.0;
    return CreateMoneyIconScaled(24.0, scale, tintColor);
}

// Initialize money icon atlas (call after reparenting)
public static func InitMoneyIcon(icon: ref<inkImage>) {
    if IsDefined(icon) {
        icon.SetAtlasResource(GetMoneyIconAtlas());
        icon.SetTexturePart(GetMoneyIconPart());
        icon.SetVisible(true);
    }
}

// Create a price display row with money icon + text (horizontal panel)
// iconScale: fraction of font size for icon (e.g., 0.6 = 60% of font size)
public static func CreatePriceRow(price: Int32, fontSize: Int32, tintColor: HDRColor, iconScale: Float) -> ref<inkHorizontalPanel> {
    let row = new inkHorizontalPanel();
    row.SetName(n"priceRow");
    // Proportional child margins based on font size
    let marginSize = Cast<Float>(fontSize) * 0.1;
    row.SetChildMargin(new inkMargin(marginSize, 0.0, marginSize, 0.0));
    row.SetVAlign(inkEVerticalAlign.Center);

    let icon = CreateMoneyIconForFont(fontSize, iconScale, tintColor);
    // Proportional icon margin (right side only, to separate from text)
    let iconMargin = Cast<Float>(fontSize) * 0.15;
    icon.SetMargin(new inkMargin(0.0, 0.0, iconMargin, 0.0));
    icon.SetVAlign(inkEVerticalAlign.Center);
    icon.Reparent(row);
    InitMoneyIcon(icon);

    let priceText = new inkText();
    priceText.SetName(n"priceText");
    priceText.SetText(GarageText.Price(price));
    priceText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    priceText.SetFontStyle(n"Bold");
    priceText.SetFontSize(fontSize);
    priceText.SetTintColor(tintColor);
    priceText.SetVAlign(inkEVerticalAlign.Center);
    priceText.Reparent(row);

    return row;
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

    public func Show() {
        this.m_isVisible = true;
        this.GetRootWidget().SetVisible(true);
    }

    public func Hide() {
        this.m_isVisible = false;
        this.GetRootWidget().SetVisible(false);
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

    protected func UpdateHint(action: CName, label: String, active: Bool) {
        if active {
            this.m_garageFrame.GetHints().AddButtonHint(action, label);
        } else {
            this.m_garageFrame.GetHints().RemoveButtonHint(action);
        }
    }

    protected func RemoveHint(action: CName) {
        this.m_garageFrame.GetHints().RemoveButtonHint(action);
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
