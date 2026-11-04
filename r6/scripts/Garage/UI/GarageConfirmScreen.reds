module Garage.UI

import Codeware.UI.*
import Garage.*
import Garage.Economy.*

/// A yes-or-no screen over a price: the car, a status line, options to scroll through, the price and V's eddies.
/// Subclass it, set it up in Fill and do the work in OnConfirmed. Fill runs each time it's shown, and Refresh runs it again.
/// To offer options, keep your own index, call SetOption from Fill, and override NextPage and PrevPage to move it and Refresh.
public abstract class GarageConfirmScreen extends GarageScreen {
  private let m_carText: wref<inkText>;
  private let m_statusText: wref<inkText>;
  private let m_optionName: wref<inkText>;
  private let m_optionDesc: wref<inkText>;
  private let m_priceLabel: wref<inkText>;
  private let m_price: ref<GarageMoneyLine>;
  private let m_balance: ref<GarageMoneyLine>;
  private let m_priceRow: wref<inkHorizontalPanel>;
  private let m_priceText: wref<inkText>;
  private let m_breakdown: wref<inkText>;
  private let m_lowerDivider: wref<inkRectangle>;
  private let m_balanceLabel: wref<inkText>;
  private let m_balanceRow: wref<inkHorizontalPanel>;
  private let m_balanceIcon: wref<inkImage>;
  private let m_balanceText: wref<inkText>;
  private let m_refusal: wref<inkText>;
  private let m_cancelBtn: wref<SimpleButton>;
  private let m_confirmBtn: wref<SimpleButton>;
  private let m_canConfirm: Bool;
  private let m_busy: Bool;
  private let m_pulse: ref<inkAnimProxy>;

  protected cb func OnCreate() {
    super.OnCreate();
    let root: ref<inkCanvas> = this.GetRootWidget() as inkCanvas;
    let blue: HDRColor = ThemeColors.ElectricBlue();
    let gold: HDRColor = GarageColors.Gold();

    this.CreateBackButton(root);
    this.CreateTitle(root, "", 60.0);

    let content: ref<inkVerticalPanel> = new inkVerticalPanel();
    content.SetName(n"contentPanel");
    content.SetAnchor(inkEAnchor.Centered);
    content.SetAnchorPoint(new Vector2(0.5, 0.5));
    content.SetMargin(new inkMargin(100.0, 100.0, 100.0, 150.0));
    content.SetChildMargin(new inkMargin(0.0, 15.0, 0.0, 15.0));
    content.Reparent(root);

    this.m_carText = this.AddText(n"carName", n"Bold", 60, blue, content);

    let status: ref<inkText> = this.AddText(n"status", n"Regular", 32, blue, content);
    status.SetMargin(new inkMargin(0.0, -40.0, 0.0, 0.0));
    this.m_statusText = status;

    this.AddDivider(n"divider", content);

    this.m_optionName = this.AddText(n"optionName", n"Bold", 42, blue, content);

    let optionDesc: ref<inkText> = this.AddText(n"optionDesc", n"Regular", 32, blue, content);
    optionDesc.SetMargin(new inkMargin(0.0, -30.0, 0.0, 0.0));
    this.m_optionDesc = optionDesc;

    let priceLabel: ref<inkText> = this.AddText(n"priceLabel", n"Regular", 32, blue, content);
    priceLabel.SetMargin(new inkMargin(0.0, 0.0, 0.0, -40.0));
    this.m_priceLabel = priceLabel;

    this.m_price = GarageMoneyLine.Make(content, n"price", "", 64, 1.0);
    this.m_priceRow = this.m_price.Root();
    this.m_priceRow.SetVAlign(inkEVerticalAlign.Center);
    this.m_priceText = this.m_price.Value();

    let breakdown: ref<inkText> = this.AddText(n"priceBreakdown", n"Regular", 32, gold, content);
    breakdown.SetVerticalAlignment(textVerticalAlignment.Center);
    breakdown.SetContentHAlign(inkEHorizontalAlign.Center);
    breakdown.justification = textJustificationType.Center;
    breakdown.SetMargin(new inkMargin(0.0, -24.0, 0.0, 0.0));
    this.m_breakdown = breakdown;

    this.m_lowerDivider = this.AddDivider(n"divider2", content);

    let balanceLabel: ref<inkText> = this.AddText(n"balanceLabel", n"Regular", 32, blue, content);
    balanceLabel.SetMargin(new inkMargin(0.0, 0.0, 0.0, -32.0));
    this.m_balanceLabel = balanceLabel;

    this.m_balance = GarageMoneyLine.Make(content, n"balance", "", 40, 1.0);
    this.m_balanceRow = this.m_balance.Root();
    this.m_balanceRow.SetVAlign(inkEVerticalAlign.Center);
    this.m_balanceIcon = this.m_balance.Icon();
    let balanceText: wref<inkText> = this.m_balance.Value();
    this.m_balanceText = balanceText;

    let refusal: ref<inkText> = this.AddText(n"refusal", n"Regular", 36, GarageColors.Error(), content);
    refusal.SetWrapping(true, 700.0);
    this.m_refusal = refusal;

    let buttons: ref<inkHorizontalPanel> = this.CreateBottomRow(root, n"buttonPanel", 0);
    buttons.SetChildMargin(new inkMargin(20.0, 0.0, 20.0, 0.0));
    this.m_cancelBtn = this.CreateStandardButton(n"cancelBtn", GarageText.Get(n"Garage-Checkout-Cancel"), 300.0, buttons, n"OnCancelClick");
    this.m_confirmBtn = this.CreateStandardButton(n"confirmBtn", GarageText.Get(n"Garage-ChopShop-Confirm"), 300.0, buttons, n"OnConfirmClick");
  }

  private func AddText(name: CName, style: CName, size: Int32, tint: HDRColor, parent: ref<inkCompoundWidget>) -> ref<inkText> {
    let text: ref<inkText> = new inkText();
    text.SetName(name);
    text.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
    text.SetFontStyle(style);
    text.SetFontSize(size);
    text.SetTintColor(tint);
    text.SetHorizontalAlignment(textHorizontalAlignment.Center);
    text.Reparent(parent);
    return text;
  }

  private func AddDivider(name: CName, parent: ref<inkCompoundWidget>) -> ref<inkRectangle> {
    let divider: ref<inkRectangle> = new inkRectangle();
    divider.SetName(name);
    divider.SetSize(new Vector2(400.0, 2.0));
    divider.SetTintColor(ThemeColors.ElectricBlue());
    divider.SetOpacity(0.5);
    divider.SetMargin(new inkMargin(0.0, -10.0, 0.0, -10.0));
    divider.Reparent(parent);
    return divider;
  }

  public func Show() {
    super.Show();
    this.m_price.InitIcon();
    this.m_balance.InitIcon();
    this.m_busy = false;
    this.Refresh();
    this.UpdateHint(n"click", GarageText.Get(n"Garage-Confirm-Hint"), true);
  }

  public func Hide() {
    super.Hide();
    this.RemoveHint(n"click");
    this.SetStatusPulsing(false);
  }

  /// Blanks the optional parts and fills the screen in again.
  public func Refresh() -> Void {
    // Scrolling mid-job can't bring the buttons back
    if this.m_busy { return; }
    this.SetPriceShown(true);
    this.m_refusal.SetVisible(false);
    this.SetStatusPulsing(false);
    this.SetStatus("", GarageColors.AccentBlue());
    this.m_cancelBtn.SetDisabled(false);
    this.m_cancelBtn.GetRootWidget().SetOpacity(1.0);
    this.SetOption("", "");
    this.SetConfirmText(GarageText.Get(n"Garage-ChopShop-Confirm"));
    this.SetCanConfirm(true);
    this.Fill();
  }

  protected func Fill() -> Void {}

  protected func OnConfirmed() -> Void {}

  /// Takes the money, or says it couldn't and redraws. Null when it couldn't.
  protected func Charge(location: CName, amount: Int32, kind: EGarageTxKind, source: CName) -> ref<GarageReceipt> {
    let receipt: ref<GarageReceipt> = GarageTransactions.Charge(location, amount, kind, source);
    if receipt.ok { return receipt; }
    GarageSystem.Get().Xu().Screen().Notify(GarageText.Get(n"Garage-Transaction-DeductFailed"), SimpleMessageType.Negative, 3.0, true);
    this.Refresh();
    return null;
  }

  public func OnBack() -> Bool { return this.m_busy; }

  protected func SetTitle(text: String) -> Void { this.m_titleText.SetText(text); }

  protected func SetCar(name: String) -> Void { this.m_carText.SetText(name); }

  /// The line under the car's name. Empty hides it.
  protected func SetStatus(text: String, tint: HDRColor) -> Void {
    this.m_statusText.SetText(text);
    this.m_statusText.SetTintColor(tint);
    this.m_statusText.SetVisible(StrLen(text) > 0);
  }

  /// Throbs the status line, for when it's bad news.
  protected func SetStatusPulsing(on: Bool) -> Void {
    if IsDefined(this.m_pulse) { this.m_pulse.Stop(); }
    this.m_pulse = null;
    this.m_statusText.SetOpacity(1.0);
    if !on { return; }
    let down: ref<inkAnimTransparency> = new inkAnimTransparency();
    down.SetStartTransparency(1.0);
    down.SetEndTransparency(0.4);
    down.SetDuration(0.75);
    let up: ref<inkAnimTransparency> = new inkAnimTransparency();
    up.SetStartTransparency(0.4);
    up.SetEndTransparency(1.0);
    up.SetStartDelay(0.75);
    up.SetDuration(0.75);
    let anim: ref<inkAnimDef> = new inkAnimDef();
    anim.AddInterpolator(down);
    anim.AddInterpolator(up);
    let options: inkAnimOptions;
    options.loopType = inkanimLoopType.Cycle;
    options.loopInfinite = true;
    this.m_pulse = this.m_statusText.PlayAnimationWithOptions(anim, options);
  }

  /// Which option's up, above the price. An empty name hides it.
  protected func SetOption(name: String, description: String) -> Void {
    this.m_optionName.SetText(name);
    this.m_optionDesc.SetText(description);
    this.m_optionName.SetVisible(StrLen(name) > 0);
    this.m_optionDesc.SetVisible(StrLen(description) > 0);
  }

  /// breakdown is one line of the sum per \n.
  protected func SetPrice(label: String, amount: Int32, breakdown: String) -> Void {
    this.m_priceLabel.SetText(label);
    this.m_priceText.SetText(GarageText.Price(amount));
    this.m_breakdown.SetText(breakdown);
    // A long sum would run into the buttons
    let lines: array<String> = StrSplit(breakdown, "\n");
    this.m_breakdown.SetFontSize(ArraySize(lines) > 4 ? 26 : 32);
  }

  /// ok false turns it red, for when V can't pay.
  protected func SetBalance(label: String, amount: Int32, ok: Bool) -> Void {
    let tint: HDRColor = ok ? GarageColors.Gold() : GarageColors.Error();
    this.m_balanceLabel.SetText(label);
    this.m_balanceText.SetText(GarageText.Price(amount));
    this.m_balanceText.SetTintColor(tint);
    this.m_balanceIcon.SetTintColor(tint);
  }

  /// Swaps the price for a reason why not, and turns Confirm off.
  protected func Refuse(reason: String) -> Void {
    this.SetPriceShown(false);
    this.m_refusal.SetText(reason);
    this.m_refusal.SetTintColor(GarageColors.Error());
    this.m_refusal.SetVisible(true);
    this.SetCanConfirm(false);
  }

  /// A caution under the price, which stays. Whether Confirm stays on is up to you.
  protected func SetWarning(text: String) -> Void {
    this.m_refusal.SetText(text);
    this.m_refusal.SetTintColor(GarageColors.Warning());
    this.m_refusal.SetVisible(true);
  }

  /// The money's gone and the work's started, so buttons, scrolling and Esc do nothing until the popup closes.
  protected func SetBusy(text: String) -> Void {
    this.m_busy = true;
    this.SetConfirmText(text);
    this.SetCanConfirm(false);
    this.m_cancelBtn.SetDisabled(true);
    this.m_cancelBtn.GetRootWidget().SetOpacity(0.3);
  }

  protected func SetCanConfirm(can: Bool) -> Void {
    this.m_canConfirm = can;
    this.m_confirmBtn.SetDisabled(!can);
    this.m_confirmBtn.GetRootWidget().SetOpacity(can ? 1.0 : 0.3);
  }

  protected func SetConfirmText(text: String) -> Void {
    this.m_confirmBtn.SetText(text);
    FitButtonPair(this.m_cancelBtn, this.m_confirmBtn);
  }

  /// Yellow when healthy, down to red at 40%. health is 0 to 1.
  protected func ConditionTint(health: Float) -> HDRColor {
    if health >= 1.0 { return new HDRColor(0.95, 0.78, 0.20, 1.0); }
    if health < 0.4 { return new HDRColor(0.87, 0.25, 0.20, 1.0); }
    let t: Float = (health - 0.4) / 0.6;
    return new HDRColor(0.95 - t * 0.08, 0.25 + t * 0.53, 0.20, 1.0);
  }

  private func SetPriceShown(shown: Bool) -> Void {
    this.m_priceLabel.SetVisible(shown);
    this.m_priceRow.SetVisible(shown);
    this.m_breakdown.SetVisible(shown);
    this.m_lowerDivider.SetVisible(shown);
    this.m_balanceLabel.SetVisible(shown);
    this.m_balanceRow.SetVisible(shown);
  }

  protected cb func OnCancelClick(widget: wref<inkWidget>) -> Bool {
    let manager: ref<ScreenManager> = this.m_screenManager;
    if IsDefined(manager) { manager.Back(); }
    return false;
  }

  protected cb func OnConfirmClick(widget: wref<inkWidget>) -> Bool {
    if this.m_canConfirm { this.OnConfirmed(); }
    return false;
  }
}
