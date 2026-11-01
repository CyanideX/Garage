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

public class ConstraintPopup extends inkCustomController {
    // UI Elements
    private let m_dialogBox: wref<inkCanvas>;
    private let m_titleText: wref<inkText>;
    private let m_messageText: wref<inkText>;
    private let m_changesText: wref<inkText>;
    private let m_cancelBtn: wref<SimpleButton>;
    private let m_confirmBtn: wref<SimpleButton>;
    private let m_buttonContainer: wref<inkHorizontalPanel>;

    // State
    private let m_pendingSubcategoryId: String;
    private let m_pendingChoiceId: String;
    private let m_pendingChanges: String;

    private let m_parentScreen: wref<GarageScreen>;

    // Styling
    private let m_accentColor: HDRColor;
    private let m_warningColor: HDRColor;

    protected cb func OnCreate() {
        this.m_accentColor = GarageColors.AccentBlue();
        this.m_warningColor = GarageColors.Warning();

        let root = new inkCanvas();
        root.SetName(n"ConstraintPopup");
        root.SetAnchor(inkEAnchor.Fill);
        root.SetVisible(false);
        this.SetRootWidget(root);

        // No overlay or background - dialog floats over content
        let dialogBox = new inkCanvas();
        dialogBox.SetName(n"dialogBox");
        dialogBox.SetAnchor(inkEAnchor.Centered);
        dialogBox.SetAnchorPoint(new Vector2(0.5, 0.5));
        dialogBox.SetSize(new Vector2(700.0, 500.0));
        dialogBox.Reparent(root);
        this.m_dialogBox = dialogBox;

        let dialogBorder = new inkRectangle();
        dialogBorder.SetName(n"dialogBorder");
        dialogBorder.SetAnchor(inkEAnchor.Fill);
        dialogBorder.SetTintColor(this.m_warningColor);
        dialogBorder.SetOpacity(0.05);
        dialogBorder.SetMargin(new inkMargin(-20.0, -20.0, -20.0, -20.0));
        dialogBorder.Reparent(dialogBox);

        let contentPanel = new inkVerticalPanel();
        contentPanel.SetName(n"contentPanel");
        contentPanel.SetAnchor(inkEAnchor.Centered);
        contentPanel.SetAnchorPoint(new Vector2(0.5, 0.5));
        contentPanel.SetChildMargin(new inkMargin(0.0, 8.0, 0.0, 8.0));
        contentPanel.Reparent(dialogBox);

        let title = new inkText();
        title.SetName(n"title");
        title.SetText(GetLocalizedTextByKey(n"Garage-Constraint-Title"));
        title.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        title.SetFontStyle(n"Bold");
        title.SetFontSize(48);
        title.SetTintColor(this.m_warningColor);
        title.SetHorizontalAlignment(textHorizontalAlignment.Center);
        title.Reparent(contentPanel);
        this.m_titleText = title;

        let message = new inkText();
        message.SetName(n"message");
        message.SetText(GetLocalizedTextByKey(n"Garage-Constraint-DefaultMessage"));
        message.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        message.SetFontStyle(n"Regular");
        message.SetFontSize(32);
        message.SetMargin(new inkMargin(0.0, -24.0, 0.0, 0.0));
        message.SetTintColor(this.m_accentColor);
        message.SetOpacity(1.0);
        message.SetWrapping(true, 640.0);
        message.SetHorizontalAlignment(textHorizontalAlignment.Center);
        message.Reparent(contentPanel);
        this.m_messageText = message;

        let changes = new inkText();
        changes.SetName(n"changes");
        changes.SetText("");
        changes.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        changes.SetFontStyle(n"Regular");
        changes.SetFontSize(32);
        changes.SetTintColor(new HDRColor(0.8, 0.8, 0.8, 1.0));
        changes.SetOpacity(0.8);
        changes.SetHorizontalAlignment(textHorizontalAlignment.Center);
        changes.Reparent(contentPanel);
        this.m_changesText = changes;

        let buttonContainer = new inkHorizontalPanel();
        buttonContainer.SetName(n"buttonContainer");
        buttonContainer.SetHAlign(inkEHorizontalAlign.Center);
        buttonContainer.SetChildMargin(new inkMargin(15.0, 0.0, 15.0, 0.0));
        buttonContainer.SetMargin(new inkMargin(0.0, 15.0, 0.0, 0.0));
        buttonContainer.Reparent(contentPanel);
        this.m_buttonContainer = buttonContainer;

        this.m_cancelBtn = SimpleButton.Create();
        this.m_cancelBtn.SetName(n"cancelBtn");
        this.m_cancelBtn.SetText(GetLocalizedTextByKey(n"Garage-Constraint-Cancel"));
        this.m_cancelBtn.SetWidth(250.0);
        this.m_cancelBtn.ToggleAnimations(true);
        this.m_cancelBtn.ToggleSounds(true);
        this.m_cancelBtn.Reparent(buttonContainer);
        this.m_cancelBtn.RegisterToCallback(n"OnBtnClick", this, n"OnCancelClick");

        this.m_confirmBtn = SimpleButton.Create();
        this.m_confirmBtn.SetName(n"confirmBtn");
        this.m_confirmBtn.SetText(GetLocalizedTextByKey(n"Garage-Constraint-Update"));
        this.m_confirmBtn.SetWidth(250.0);
        this.m_confirmBtn.ToggleAnimations(true);
        this.m_confirmBtn.ToggleSounds(true);
        this.m_confirmBtn.Reparent(buttonContainer);
        this.m_confirmBtn.RegisterToCallback(n"OnBtnClick", this, n"OnConfirmClick");
    }

    public func Show(subcategoryId: String, choiceId: String, message: String, changes: String) {
        this.Show(subcategoryId, choiceId, message, changes, n"Garage-Constraint-Update");
    }

    public func Show(subcategoryId: String, choiceId: String, message: String, changes: String, confirmKey: CName) {
        this.m_titleText.SetText(GetLocalizedTextByKey(n"Garage-Constraint-Title"));
        this.m_cancelBtn.SetText(GetLocalizedTextByKey(n"Garage-Constraint-Cancel"));
        this.m_confirmBtn.SetText(GetLocalizedTextByKey(confirmKey));
        FitButtonPair(this.m_cancelBtn, this.m_confirmBtn);

        this.m_pendingSubcategoryId = subcategoryId;
        this.m_pendingChoiceId = choiceId;
        this.m_pendingChanges = changes;

        if IsDefined(this.m_messageText) {
            if NotEquals(message, "") {
                this.m_messageText.SetText(GetLocalizedTextByKey(StringToName(message)));
            } else {
                this.m_messageText.SetText(GetLocalizedTextByKey(n"Garage-Constraint-DefaultMessage"));
            }
        }

        if IsDefined(this.m_changesText) {
            if NotEquals(changes, "") {
                let formatted: String;
                if StrContains(changes, ":") {
                    formatted = this.FormatChanges(changes);
                } else {
                    formatted = this.FormatSiblings(changes);
                }
                this.m_changesText.SetText(formatted);
                this.m_changesText.SetVisible(true);
            } else {
                this.m_changesText.SetVisible(false);
            }
        }

        let root = this.GetRootWidget();
        if IsDefined(root) {
            root.SetVisible(true);
        }

        if IsDefined(this.m_parentScreen) {
            this.m_parentScreen.HideMainElements();
        }
    }

    private func FormatChanges(changes: String) -> String {

        if Equals(changes, "") {
            return "";
        }

        let parts = StrSplit(changes, "|");
        let subcats: array<String>;

        let i = 0;
        while i < ArraySize(parts) {
            let pair = parts[i];
            let colonIdx = StrFindFirst(pair, ":");
            if colonIdx >= 0 {
                let subcatId = StrLeft(pair, colonIdx);
                ArrayPush(subcats, subcatId);
            }
            i += 1;
        }

        if ArraySize(subcats) == 0 {
            return "";
        }

        let result = GetLocalizedTextByKey(n"Garage-Constraint-WillUpdate") + " ";
        let j = 0;
        while j < ArraySize(subcats) {
            if j > 0 {
                result = result + ", ";
            }
            result = result + subcats[j];
            j += 1;
        }
        return result;
    }

    // Pipe-separated display names (already resolved, no subcatId:choiceId format).
    // For splitting a group, where the names are worked out already.
    private func FormatSiblings(siblings: String) -> String {
        if Equals(siblings, "") {
            return "";
        }
        let parts = StrSplit(siblings, "|");
        let result = GetLocalizedTextByKey(n"Garage-Constraint-SplitWillPreserve") + " ";
        let i = 0;
        while i < ArraySize(parts) {
            if i > 0 {
                result = result + ", ";
            }
            result = result + parts[i];
            i += 1;
        }
        return result;
    }

    public func Hide() {
        let root = this.GetRootWidget();
        if IsDefined(root) {
            root.SetVisible(false);
        }

        if IsDefined(this.m_parentScreen) {
            this.m_parentScreen.ShowMainElements();
        }

        this.m_pendingSubcategoryId = "";
        this.m_pendingChoiceId = "";
        this.m_pendingChanges = "";
    }

    public func IsVisible() -> Bool {
        let root = this.GetRootWidget();
        return IsDefined(root) && root.IsVisible();
    }

    protected cb func OnCancelClick(widget: wref<inkWidget>) -> Bool {
        if IsDefined(this.m_parentScreen) {
            this.m_parentScreen.HandleConstraintCancelled();
        }
        this.Hide();
        return false;
    }

    protected cb func OnConfirmClick(widget: wref<inkWidget>) -> Bool {
        if IsDefined(this.m_parentScreen) {
            this.m_parentScreen.HandleConstraintConfirmed();
        }
        this.Hide();
        return false;
    }

    public func SetParentScreen(parent: ref<GarageScreen>) {
        this.m_parentScreen = parent;
    }

    public func GetPendingSubcategoryId() -> String {
        return this.m_pendingSubcategoryId;
    }

    public func GetPendingChoiceId() -> String {
        return this.m_pendingChoiceId;
    }

    public func GetPendingChanges() -> String {
        return this.m_pendingChanges;
    }
}

public class ExitWarningPopup extends inkCustomController {
    private let m_parentPopup: wref<GaragePopup>;
    private let m_screenManager: wref<ScreenManager>;
    private let m_navigateBackMode: Bool;
    private let m_clearCartMode: Bool;

    // UI Elements
    private let m_overlay: wref<inkRectangle>;
    private let m_dialogBox: wref<inkCanvas>;
    private let m_dialogBg: wref<inkRectangle>;
    private let m_titleText: wref<inkText>;
    private let m_messageText: wref<inkText>;
    private let m_valueRow: wref<inkHorizontalPanel>;
    private let m_valueIcon: wref<inkImage>;
    private let m_valueText: wref<inkText>;
    private let m_yesBtn: wref<SimpleButton>;
    private let m_noBtn: wref<SimpleButton>;
    private let m_buttonContainer: wref<inkHorizontalPanel>;

    // Styling
    private let m_accentColor: HDRColor;
    private let m_warningColor: HDRColor;

    public func SetParentPopup(popup: ref<GaragePopup>) {
        this.m_parentPopup = popup;
    }

    public func SetScreenManager(screenManager: ref<ScreenManager>) {
        this.m_screenManager = screenManager;
    }

    protected cb func OnCreate() {
        this.m_accentColor = GarageColors.AccentBlue();
        this.m_warningColor = GarageColors.Warning();

        let root = new inkCanvas();
        root.SetName(n"ExitWarningPopup");
        root.SetAnchor(inkEAnchor.Fill);
        root.SetVisible(false);
        this.SetRootWidget(root);

        let overlay = new inkRectangle();
        overlay.SetName(n"overlay");
        overlay.SetAnchor(inkEAnchor.Fill);
        overlay.SetTintColor(new HDRColor(0.043, 0.043, 0.043, 1.0));
        overlay.SetOpacity(0.7);
        overlay.SetMargin(new inkMargin(-10.0, -10.0, -10.0, -10.0));
        overlay.Reparent(root);
        this.m_overlay = overlay;

        let dialogBox = new inkCanvas();
        dialogBox.SetName(n"dialogBox");
        dialogBox.SetAnchor(inkEAnchor.Centered);
        dialogBox.SetAnchorPoint(new Vector2(0.5, 0.5));
        dialogBox.SetSize(new Vector2(980.0, 400.0));
        dialogBox.Reparent(root);
        this.m_dialogBox = dialogBox;

        let dialogBg = new inkRectangle();
        dialogBg.SetName(n"dialogBg");
        dialogBg.SetAnchor(inkEAnchor.Fill);
        dialogBg.SetTintColor(this.m_warningColor);
        dialogBg.SetOpacity(0.05);
        dialogBg.Reparent(dialogBox);
        this.m_dialogBg = dialogBg;

        let dialogBorder = new inkRectangle();
        dialogBorder.SetName(n"dialogBorder");
        dialogBorder.SetAnchor(inkEAnchor.Fill);
        dialogBorder.SetTintColor(this.m_warningColor);
        dialogBorder.SetOpacity(0.05);
        dialogBorder.SetMargin(new inkMargin(-5.0, -5.0, -5.0, -5.0));
        dialogBorder.Reparent(dialogBox);

        let contentPanel = new inkVerticalPanel();
        contentPanel.SetName(n"contentPanel");
        contentPanel.SetAnchor(inkEAnchor.Centered);
        contentPanel.SetAnchorPoint(new Vector2(0.5, 0.5));
        contentPanel.SetChildMargin(new inkMargin(0.0, 10.0, 0.0, 10.0));
        contentPanel.Reparent(dialogBox);

        let title = new inkText();
        title.SetName(n"title");
        title.SetText(GetLocalizedTextByKey(n"Garage-ExitWarning-Title"));
        title.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        title.SetFontStyle(n"Bold");
        title.SetFontSize(48);
        title.SetTintColor(this.m_warningColor);
        title.SetHorizontalAlignment(textHorizontalAlignment.Center);
        title.SetMargin(new inkMargin(0.0, 0.0, 0.0, -20.0));
        title.Reparent(contentPanel);
        this.m_titleText = title;

        let message = new inkText();
        message.SetName(n"message");
        message.SetText("");
        message.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        message.SetFontStyle(n"Regular");
        message.SetFontSize(32);
        message.SetTintColor(new HDRColor(1.0, 1.0, 1.0, 1.0));  // White
        message.SetOpacity(0.8);
        message.SetHorizontalAlignment(textHorizontalAlignment.Center);
        message.Reparent(contentPanel);
        this.m_messageText = message;

        let valueRow = new inkHorizontalPanel();
        valueRow.SetName(n"valueRow");
        valueRow.SetHAlign(inkEHorizontalAlign.Center);
        valueRow.SetChildMargin(new inkMargin(4.0, 0.0, 4.0, 0.0));
        valueRow.Reparent(contentPanel);
        this.m_valueRow = valueRow;

        let valueIcon = new inkImage();
        valueIcon.SetName(n"valueIcon");
        valueIcon.SetSize(new Vector2(50.0, 50.0));
        valueIcon.SetFitToContent(true);
        valueIcon.SetScale(new Vector2(1.0, 1.0));
        valueIcon.SetMargin(new inkMargin(0.0, 0.0, 8.0, 0.0));
        valueIcon.SetTintColor(this.m_warningColor);
        valueIcon.SetHAlign(inkEHorizontalAlign.Right);
        valueIcon.SetVAlign(inkEVerticalAlign.Center);
        valueIcon.Reparent(valueRow);
        InitMoneyIcon(valueIcon);
        this.m_valueIcon = valueIcon;

        let valueText = new inkText();
        valueText.SetName(n"valueText");
        valueText.SetText("0");
        valueText.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
        valueText.SetFontStyle(n"Bold");
        valueText.SetFontSize(56);
        valueText.SetTintColor(this.m_warningColor);
        valueText.SetVAlign(inkEVerticalAlign.Center);
        valueText.Reparent(valueRow);
        this.m_valueText = valueText;

        let buttonContainer = new inkHorizontalPanel();
        buttonContainer.SetName(n"buttonContainer");
        buttonContainer.SetHAlign(inkEHorizontalAlign.Center);
        buttonContainer.SetChildMargin(new inkMargin(40.0, 0.0, 40.0, 0.0));
        buttonContainer.SetMargin(new inkMargin(0.0, 15.0, 0.0, 0.0));
        buttonContainer.Reparent(contentPanel);
        this.m_buttonContainer = buttonContainer;

        this.m_noBtn = SimpleButton.Create();
        this.m_noBtn.SetName(n"noBtn");
        this.m_noBtn.SetText(GetLocalizedTextByKey(n"Garage-ExitWarning-NoStay"));
        this.m_noBtn.SetWidth(350.0);
        this.m_noBtn.ToggleAnimations(true);
        this.m_noBtn.ToggleSounds(true);
        this.m_noBtn.Reparent(buttonContainer);
        this.m_noBtn.RegisterToCallback(n"OnBtnClick", this, n"OnNoClick");

        this.m_yesBtn = SimpleButton.Create();
        this.m_yesBtn.SetName(n"yesBtn");
        this.m_yesBtn.SetText(GetLocalizedTextByKey(n"Garage-ExitWarning-YesExit"));
        this.m_yesBtn.SetWidth(350.0);
        this.m_yesBtn.ToggleAnimations(true);
        this.m_yesBtn.ToggleSounds(true);
        this.m_yesBtn.Reparent(buttonContainer);
        this.m_yesBtn.RegisterToCallback(n"OnBtnClick", this, n"OnYesClick");
    }

    public func Show(itemCount: Int32, totalValue: Int32) {
        this.m_navigateBackMode = false;
        this.m_clearCartMode = false;
        this.ShowInternal(n"Garage-ExitWarning-YesExit", itemCount, totalValue);
    }

    // Clears cart and goes back to hub instead of exiting the game
    public func ShowForBackNavigation(itemCount: Int32, totalValue: Int32) {
        this.m_navigateBackMode = true;
        this.m_clearCartMode = false;
        this.ShowInternal(n"Garage-ExitWarning-YesDiscard", itemCount, totalValue);
    }

    // Clears cart but stays on the current screen (CLEAR button in cart widget)
    public func ShowForClearCart(itemCount: Int32, totalValue: Int32) {
        this.m_clearCartMode = true;
        this.m_navigateBackMode = false;
        this.ShowInternal(n"Garage-ExitWarning-YesDiscard", itemCount, totalValue);
    }

    private func ShowInternal(yesKey: CName, itemCount: Int32, totalValue: Int32) {
        this.m_titleText.SetText(GetLocalizedTextByKey(n"Garage-ExitWarning-Title"));
        this.m_noBtn.SetText(GetLocalizedTextByKey(n"Garage-ExitWarning-NoStay"));
        this.m_yesBtn.SetText(GetLocalizedTextByKey(yesKey));
        FitButtonPair(this.m_noBtn, this.m_yesBtn);
        this.m_messageText.SetText(s"\(GetLocalizedTextByKey(n"Garage-ExitWarning-YouHave")) \(itemCount) \(GetLocalizedTextByKey(n"Garage-ExitWarning-ItemsWorth"))");
        this.m_valueText.SetText(GarageText.Price(totalValue));

        let root = this.GetRootWidget();
        if IsDefined(root) {
            root.SetVisible(true);
        }
    }

    public func Hide() {
        let root = this.GetRootWidget();
        if IsDefined(root) {
            root.SetVisible(false);
        }
    }

    public func IsVisible() -> Bool {
        let root = this.GetRootWidget();
        return IsDefined(root) && root.IsVisible();
    }

    protected cb func OnNoClick(widget: wref<inkWidget>) -> Bool {
        this.Hide();
        return false;
    }

    private func ClearCartAndRevert() {
        GarageSystem.Get().Parts().DiscardCart();
    }

    protected cb func OnYesClick(widget: wref<inkWidget>) -> Bool {
        if this.m_clearCartMode {
            this.m_clearCartMode = false;
            this.ClearCartAndRevert();
            this.Hide();
            // Targeted refresh - calling Show() would re-fire camera transitions and data fetches
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
        } else if this.m_navigateBackMode {
            this.m_navigateBackMode = false;
            this.ClearCartAndRevert();
            this.Hide();
            if IsDefined(this.m_screenManager) {
                this.m_screenManager.ClearHistory();
                this.m_screenManager.ShowScreen(n"hub");
            }
        } else {
            this.Hide();
            if IsDefined(this.m_parentPopup) {
                this.m_parentPopup.ForceCloseFromWarning();
            }
        }

        return false;
    }
}