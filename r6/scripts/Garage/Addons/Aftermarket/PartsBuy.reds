module Garage.Aftermarket

import Codeware.UI.*
import Garage.*
import Garage.Audio.*
import Garage.Economy.*
import Garage.Scene.*
import Garage.UI.*
import Garage.Vehicle.*

public class ConfirmScreen extends AftermarketScreen {
  private let m_buyBtn: wref<SimpleButton>;
  private let m_addToCartBtn: wref<SimpleButton>;
  private let m_buttonPanel: wref<inkHorizontalPanel>;
  private let m_contentPanel: wref<inkVerticalPanel>;
  private let m_partName: wref<inkText>;
  private let m_partDesc: wref<inkText>;
  private let m_price: ref<GarageMoneyLine>;
  private let m_priceIcon: wref<inkImage>;
  private let m_priceText: wref<inkText>;
  private let m_breakdown: wref<inkText>;
  private let m_balance: ref<GarageMoneyLine>;
  private let m_balanceIcon: wref<inkImage>;
  private let m_balanceText: wref<inkText>;
  private let m_popup: ref<ConstraintPopup>;
  private let m_pendingBuy: Bool;

  protected cb func OnCreate() {
    super.OnCreate();
    let root: ref<inkCanvas> = this.GetRootWidget() as inkCanvas;
    let blue: HDRColor = ThemeColors.ElectricBlue();
    let gold: HDRColor = GarageColors.Gold();

    this.CreateBackButton(root);
    this.CreateTitle(root, GarageText.Get(n"Garage-Confirm-Title"), 60.0);

    let content: ref<inkVerticalPanel> = new inkVerticalPanel();
    content.SetName(n"contentPanel");
    content.SetAnchor(inkEAnchor.Centered);
    content.SetAnchorPoint(new Vector2(0.5, 0.5));
    content.SetMargin(new inkMargin(100.0, 100.0, 100.0, 150.0));
    content.SetChildMargin(new inkMargin(0.0, 15.0, 0.0, 15.0));
    content.Reparent(root);
    this.m_contentPanel = content;

    let partName: ref<inkText> = GarageLabel(n"partName", GarageText.Get(n"Garage-Confirm-PartNamePlaceholder"), n"Bold", 60, blue, content);
    partName.SetHorizontalAlignment(textHorizontalAlignment.Center);
    partName.SetMargin(new inkMargin(0.0, 0.0, 0.0, -32.0));
    this.m_partName = partName;

    let partDesc: ref<inkText> = GarageLabel(n"partDesc", GarageText.Get(n"Garage-Confirm-PartDescPlaceholder"), n"Italic", 32, blue, content);
    partDesc.SetOpacity(0.6);
    partDesc.SetHorizontalAlignment(textHorizontalAlignment.Center);
    this.m_partDesc = partDesc;

    let divider: ref<inkRectangle> = new inkRectangle();
    divider.SetName(n"divider");
    divider.SetSize(new Vector2(400.0, 2.0));
    divider.SetTintColor(blue);
    divider.SetOpacity(0.5);
    divider.SetMargin(new inkMargin(0.0, 20.0, 0.0, 20.0));
    divider.Reparent(content);

    this.CreateLabel(n"priceLabel", n"Garage-Confirm-PriceLabel", content);

    this.m_price = GarageMoneyLine.Make(content, n"price", "", 64, 1.0);
    this.m_price.Root().SetVAlign(inkEVerticalAlign.Center);
    this.m_priceIcon = this.m_price.Icon();
    this.m_priceText = this.m_price.Value();

    let breakdown: ref<inkText> = GarageLabel(n"priceBreakdown", "", n"Regular", 32, gold, content);
    breakdown.SetHorizontalAlignment(textHorizontalAlignment.Center);
    breakdown.SetMargin(new inkMargin(0.0, -40.0, 0.0, 0.0));
    this.m_breakdown = breakdown;

    this.CreateLabel(n"balanceLabel", n"Garage-Confirm-BalanceLabel", content);

    this.m_balance = GarageMoneyLine.Make(content, n"balance", "", 32, 1.0);
    let balanceRow: wref<inkHorizontalPanel> = this.m_balance.Root();
    balanceRow.SetVAlign(inkEVerticalAlign.Center);
    balanceRow.SetMargin(new inkMargin(0.0, 10.0, 0.0, 0.0));
    this.m_balanceIcon = this.m_balance.Icon();
    this.m_balanceText = this.m_balance.Value();

    let buttons: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    buttons.SetName(n"buttonPanel");
    buttons.SetAnchor(inkEAnchor.BottomCenter);
    buttons.SetAnchorPoint(new Vector2(0.5, 1.0));
    buttons.SetMargin(new inkMargin(0.0, 0.0, 0.0, 50.0));
    buttons.SetChildMargin(new inkMargin(20.0, 0.0, 20.0, 0.0));
    buttons.Reparent(root);
    this.m_buttonPanel = buttons;

    this.m_addToCartBtn = this.CreateStandardButton(n"addToCartBtn", GarageText.Get(n"Garage-Confirm-AddToCart"), 300.0, buttons, n"OnAddToCartClick");
    this.m_buyBtn = this.CreateStandardButton(n"buyBtn", GarageText.Get(n"Garage-Confirm-BuyNow"), 300.0, buttons, n"OnBuyClick");

    this.m_popup = new ConstraintPopup();
    this.m_popup.Reparent(root);
    this.m_popup.SetParentScreen(this);
  }

  private func CreateLabel(name: CName, key: CName, parent: ref<inkCompoundWidget>) -> Void {
    let label: ref<inkText> = GarageLabel(name, GarageText.Get(key), n"Regular", 24, ThemeColors.ElectricBlue(), parent);
    label.SetOpacity(0.6);
    label.SetHorizontalAlignment(textHorizontalAlignment.Center);
    label.SetMargin(new inkMargin(0.0, 0.0, 0.0, -40.0));
  }

  public func Show() {
    super.Show();
    this.m_price.InitIcon();
    this.m_balance.InitIcon();
    if !this.Parts().IsCurrent(this.m_flow.pick) { this.m_flow.Reassess(); }
    this.Render();
    this.UpdateHint(n"click", GarageText.Get(n"Garage-Confirm-Hint"), true);
  }

  public func Hide() {
    super.Hide();
    this.RemoveHint(n"click");
    this.ClosePopup();
  }

  // Whatever the popup listed may not be true any more, so it has to ask again
  public func RefreshAfterCartChange() -> Void {
    this.ClosePopup();
    this.m_flow.Reassess();
    this.Render();
  }

  private func ClosePopup() -> Void {
    this.m_pendingBuy = false;
    if this.m_popup.IsVisible() { this.m_popup.Hide(); }
  }

  private func Render() -> Void {
    let pick: ref<GaragePick> = this.m_flow.pick;
    if !IsDefined(pick) { return; }
    let gold: HDRColor = GarageColors.Gold();
    this.m_partName.SetText(pick.name);
    this.m_partDesc.SetText("\"" + this.m_flow.DescriptionOfPick() + "\"");

    let breakdown: String;
    let label: String;
    if Equals(pick.status, EGaragePartStatus.Unowned) {
      breakdown = GarageText.Price(pick.price) + " + " + GarageText.Price(pick.serviceFee) + " " + GarageText.Get(n"Garage-Confirm-Service");
      label = GarageText.Get(n"Garage-Confirm-BuyNow");
    } else {
      breakdown = GarageText.Get(n"Garage-Confirm-ServiceFee");
      label = GarageText.Get(Equals(pick.status, EGaragePartStatus.Stock) ? n"Garage-Confirm-Equip" : n"Garage-Confirm-Install");
    }
    if pick.forcedCost > 0 { breakdown += " + " + GarageText.Price(pick.forcedCost) + " " + GarageText.Get(n"Garage-Confirm-Required"); }
    let garage: String = this.Parts().Markup().Lines(", ");
    if StrLen(garage) > 0 { breakdown += ", " + garage; }
    this.m_breakdown.SetText("(" + breakdown + ")");
    this.m_priceText.SetText(GarageText.Price(pick.Total()));
    this.m_priceText.SetTintColor(gold);
    this.m_priceIcon.SetTintColor(gold);
    this.m_priceIcon.SetVisible(true);

    this.m_balanceText.SetText(GarageText.Price(GarageTransactions.Balance()));
    this.m_balanceText.SetTintColor(gold);
    this.m_balanceIcon.SetTintColor(gold);

    if pick.isInstalled {
      this.m_buyBtn.GetRootWidget().SetOpacity(0.3);
      this.m_buyBtn.SetText(GarageText.Get(n"Garage-Confirm-Installed"));
      this.m_priceText.SetText(GarageText.Get(n"Garage-Confirm-CurrentlyEquipped"));
      this.m_priceText.SetTintColor(GarageColors.Blue());
      this.m_priceIcon.SetVisible(false);
      this.m_breakdown.SetText("");
    } else if !pick.canAfford {
      this.m_balanceText.SetTintColor(GarageColors.Error());
      this.m_balanceIcon.SetTintColor(GarageColors.Error());
      this.m_buyBtn.GetRootWidget().SetOpacity(0.3);
      this.m_buyBtn.SetText(GarageText.Get(n"Garage-Confirm-BuyNow"));
    } else {
      this.m_buyBtn.GetRootWidget().SetOpacity(1.0);
      this.m_buyBtn.SetText(label);
    }

    let key: CName = n"Garage-Confirm-AddToCart";
    if pick.isInstalled {
      key = n"Garage-Confirm-Installed";
    } else if pick.isInCart {
      key = n"Garage-Confirm-Remove";
    }
    this.m_addToCartBtn.GetRootWidget().SetOpacity(pick.isInstalled ? 0.3 : 1.0);
    this.m_addToCartBtn.SetText(GarageText.Get(key));
    this.m_addToCartBtn.SetDisabled(pick.isInstalled);
    FitButtonPair(this.m_addToCartBtn, this.m_buyBtn);
  }

  // A popup's the first thing back closes. The preview stays on so the list can be browsed with it applied
  public func OnBack() -> Bool {
    if !this.m_popup.IsVisible() { return false; }
    this.ClosePopup();
    return true;
  }

  private func Ask(pick: ref<GaragePick>, buying: Bool) -> Void {
    this.m_pendingBuy = buying;
    let message: CName = n"Garage-Constraint-AdditionalMessage";
    let confirm: CName = n"";
    if ArraySize(pick.kept) > 0 {
      message = n"Garage-Constraint-VirtualSplitMessage";
      confirm = n"Garage-Constraint-SplitAndContinue";
    } else if ArraySize(pick.conflicts) > 0 {
      message = n"Garage-Constraint-ReplaceMessage";
    }
    this.m_popup.Show(pick.slot, pick.choice, message, pick.Changes(), pick.kept, confirm);
  }

  protected cb func OnAddToCartClick(widget: wref<inkWidget>) -> Bool {
    let pick: ref<GaragePick> = this.m_flow.pick;
    if !IsDefined(pick) || pick.isInstalled { return false; }
    if pick.isInCart {
      this.Parts().RemoveFromCart(pick.slot);
      this.Trigger(n"OnCartChanged");
    } else if pick.AsksFirst() {
      this.Ask(pick, false);
    } else {
      this.AddToCart();
    }
    return false;
  }

  protected cb func OnBuyClick(widget: wref<inkWidget>) -> Bool {
    let pick: ref<GaragePick> = this.m_flow.pick;
    if !IsDefined(pick) || pick.isInstalled || !pick.canAfford { return false; }
    if pick.AsksFirst() {
      this.Ask(pick, true);
    } else {
      this.BuyNow();
    }
    return false;
  }

  public func HandleConstraintCancelled() -> Void { this.m_pendingBuy = false; }

  public func HandleConstraintConfirmed() -> Void {
    let buying: Bool = this.m_pendingBuy;
    this.m_pendingBuy = false;
    if buying {
      this.BuyNow();
    } else {
      this.AddToCart();
    }
  }

  private func AddToCart() -> Void {
    this.m_flow.Mark("add to cart begin");
    this.Parts().AddPick(this.m_flow.pick);
    this.Trigger(n"OnCartChanged");
    this.m_flow.Mark("add to cart done");
  }

  private func BuyNow() -> Void {
    if this.Parts().BuyPick(this.m_flow.pick) {
      GarageSounds.PlayInstall();
      this.Trigger(n"OnCartChanged");
      this.m_flow.GoBack();
    } else {
      this.m_flow.Reassess();
      this.Render();
    }
  }

  public func HideMainElements() -> Void {
    this.m_titleText.SetVisible(false);
    this.m_contentPanel.SetVisible(false);
    this.m_buttonPanel.SetVisible(false);
  }

  public func ShowMainElements() -> Void {
    this.m_titleText.SetVisible(true);
    this.m_contentPanel.SetVisible(true);
    this.m_buttonPanel.SetVisible(true);
  }
}

/// One line of the checkout's list. The pool only ever grows, a shorter cart hides the rest.
public enum CheckoutSource {
  Parts = 0,
  Quick = 1
}

/// The cart's last stop. Whoever brings the player here for something other than parts calls SetSource just before, so back goes to the hub.
public class CheckoutScreen extends AftermarketScreen {
  private let m_source: CheckoutSource;
  private let m_items: wref<inkVerticalPanel>;
  private let m_rows: array<ref<CartRow>>;
  private let m_emptyText: wref<inkText>;
  private let m_subtotalValue: wref<inkText>;
  private let m_serviceValue: wref<inkText>;
  private let m_garageRates: wref<inkText>;
  private let m_totalValue: wref<inkText>;
  private let m_lines: array<ref<GarageMoneyLine>>;
  private let m_balanceValue: wref<inkText>;
  private let m_confirmBtn: wref<SimpleButton>;
  private let m_scrollRegion: wref<inkCanvas>;
  private let m_scrollArea: wref<inkScrollArea>;
  private let m_sliderArea: wref<inkCanvas>;
  private let m_sliderHandle: wref<inkRectangle>;
  private let m_canAfford: Bool;

  public func SetSource(source: CheckoutSource) -> Void { this.m_source = source; }

  protected cb func OnCreate() {
    super.OnCreate();
    let root: ref<inkCanvas> = this.GetRootWidget() as inkCanvas;
    let accent: HDRColor = GarageColors.AccentBlue();

    this.CreateBackButton(root);
    this.CreateTitle(root, GarageText.Get(n"Garage-Checkout-Title"), 40.0);
    this.CreateSubtitle(root, GarageText.Get(n"Garage-Checkout-Subtitle"), 20, 95.0);

    let region: ref<inkCanvas> = new inkCanvas();
    region.SetName(n"scrollRegion");
    region.SetAnchor(inkEAnchor.TopCenter);
    region.SetAnchorPoint(new Vector2(0.5, 0.0));
    region.SetMargin(new inkMargin(0.0, 160.0, 0.0, 0.0));
    region.SetSize(new Vector2(660.0, 7.0 * CartWidget.RowStep()));
    region.Reparent(root);
    this.m_scrollRegion = region;

    let area: ref<inkScrollArea> = new inkScrollArea();
    area.SetName(n"itemsScrollArea");
    area.SetAnchor(inkEAnchor.Fill);
    area.SetMargin(new inkMargin(0.0, 0.0, 16.0, 0.0));
    area.SetFitToContentDirection(inkFitToContentDirection.Horizontal);
    area.SetInteractive(true);
    area.Reparent(region);
    this.m_scrollArea = area;

    let items: ref<inkVerticalPanel> = new inkVerticalPanel();
    items.SetName(n"itemsContainer");
    items.SetHAlign(inkEHorizontalAlign.Left);
    items.SetChildMargin(new inkMargin(0.0, CartWidget.RowGap(), 0.0, CartWidget.RowGap()));
    items.Reparent(area);
    this.m_items = items;

    let empty: ref<inkText> = GarageLabel(n"emptyText", GarageText.Get(n"Garage-Checkout-EmptyCart"), n"Regular", 24, accent, items);
    empty.SetOpacity(0.5);
    empty.SetHorizontalAlignment(textHorizontalAlignment.Center);
    empty.SetVisible(false);
    this.m_emptyText = empty;

    let slider: ref<inkCanvas> = new inkCanvas();
    slider.SetName(n"sliderArea");
    slider.SetAnchor(inkEAnchor.RightFillVerticaly);
    slider.SetAnchorPoint(new Vector2(1.0, 0.0));
    slider.SetSize(new Vector2(10.0, 7.0 * CartWidget.RowStep()));
    slider.SetInteractive(true);
    slider.Reparent(region);
    this.m_sliderArea = slider;

    let fill: ref<inkRectangle> = new inkRectangle();
    fill.SetName(n"sliderFill");
    fill.SetAnchor(inkEAnchor.Fill);
    fill.SetTintColor(accent);
    fill.SetOpacity(0.15);
    fill.Reparent(slider);

    let handle: ref<inkRectangle> = new inkRectangle();
    handle.SetName(n"sliderHandle");
    handle.SetAnchor(inkEAnchor.TopFillHorizontaly);
    handle.SetSize(new Vector2(10.0, 40.0));
    handle.SetTintColor(accent);
    handle.SetOpacity(0.5);
    handle.SetInteractive(true);
    handle.Reparent(slider);
    this.m_sliderHandle = handle;

    let bottom: ref<inkVerticalPanel> = new inkVerticalPanel();
    bottom.SetName(n"bottomSection");
    bottom.SetAnchor(inkEAnchor.BottomCenter);
    bottom.SetAnchorPoint(new Vector2(0.5, 1.0));
    bottom.SetHAlign(inkEHorizontalAlign.Center);
    bottom.SetMargin(new inkMargin(0.0, 0.0, 0.0, 60.0));
    bottom.SetChildMargin(new inkMargin(0.0, 8.0, 0.0, 8.0));
    bottom.Reparent(root);

    let divider: ref<inkRectangle> = new inkRectangle();
    divider.SetName(n"divider");
    divider.SetSize(new Vector2(300.0, 1.0));
    divider.SetTintColor(accent);
    divider.SetOpacity(0.5);
    divider.Reparent(bottom);

    let size: Int32 = GarageMoneyLine.LineSize();
    this.m_subtotalValue = this.AddLine(bottom, n"subtotal", n"Garage-Checkout-PartsLabel", size, 0.7);
    this.m_serviceValue = this.AddLine(bottom, n"service", n"Garage-Checkout-ServiceLabel", size, 0.7);
    // The prices above already carry these
    let rates: ref<inkText> = GarageLabel(n"garageRates", "", n"Regular", 24, accent, bottom);
    rates.SetHAlign(inkEHorizontalAlign.Center);
    rates.SetOpacity(0.7);
    this.m_garageRates = rates;
    this.m_totalValue = this.AddLine(bottom, n"total", n"Garage-Checkout-TotalLabel", GarageMoneyLine.TotalSize(), 1.0);
    this.m_balanceValue = this.AddLine(bottom, n"balance", n"Garage-Checkout-BalanceLabel", size, 0.7);

    let buttons: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    buttons.SetName(n"buttonContainer");
    buttons.SetHAlign(inkEHorizontalAlign.Center);
    buttons.SetChildMargin(new inkMargin(15.0, 0.0, 15.0, 0.0));
    buttons.SetMargin(new inkMargin(0.0, 15.0, 0.0, 0.0));
    buttons.Reparent(bottom);

    this.CreateStandardButton(n"cancelBtn", GarageText.Get(n"Garage-Checkout-Cancel"), 300.0, buttons, n"OnCancelClick");
    this.m_confirmBtn = this.CreateStandardButton(n"confirmBtn", GarageText.Get(n"Garage-Checkout-Confirm"), 300.0, buttons, n"OnConfirmClick");

    this.SetupScrollController();
  }

  private func AddLine(parent: ref<inkCompoundWidget>, name: CName, key: CName, size: Int32, opacity: Float) -> wref<inkText> {
    let line: ref<GarageMoneyLine> = GarageMoneyLine.Make(parent, name, GarageText.Get(key), size, opacity);
    ArrayPush(this.m_lines, line);
    return line.Value();
  }

  private func SetupScrollController() -> Void {
    let slider: ref<inkSliderController> = new inkSliderController();
    slider.slidingAreaRef = inkWidgetRef.Create(this.m_sliderArea);
    slider.handleRef = inkWidgetRef.Create(this.m_sliderHandle);
    slider.direction = inkESliderDirection.Vertical;
    slider.autoSizeHandle = true;
    slider.Setup(0.0, 1.0, 0.0);
    this.m_sliderArea.AttachController(slider);

    let scroll: ref<inkScrollController> = new inkScrollController();
    scroll.ScrollArea = inkScrollAreaRef.Create(this.m_scrollArea);
    scroll.VerticalScrollBarRef = inkWidgetRef.Create(this.m_sliderArea);
    scroll.autoHideVertical = true;
    this.m_scrollRegion.AttachController(scroll);
  }

  protected func UsesCheckoutCamera() -> Bool { return true; }

  public func Show() {
    super.Show();
    for line in this.m_lines { line.InitIcon(); }
    this.RefreshAfterCartChange();
    this.UpdateHint(n"click", GarageText.Get(n"Garage-Checkout-Hint"), true);
  }

  public func Hide() {
    super.Hide();
    this.RemoveHint(n"click");
    this.m_source = CheckoutSource.Parts;
  }

  public func RefreshAfterCartChange() -> Void {
    let cart: ref<GarageCart> = this.Parts().Cart();
    let items: array<ref<GarageCartItem>> = cart.Items();
    let subtotal: Int32 = 0;
    let service: Int32 = 0;

    this.m_emptyText.SetVisible(ArraySize(items) == 0);
    while ArraySize(this.m_rows) < ArraySize(items) {
      let added: ref<CartRow> = new CartRow();
      added.CreateInstance();
      added.RegisterToCallback(n"OnRemove", this, n"OnRowRemove");
      added.Reparent(this.m_items);
      ArrayPush(this.m_rows, added);
    }
    let i: Int32 = 0;
    while i < ArraySize(this.m_rows) {
      if i < ArraySize(items) {
        this.m_rows[i].Bind(items[i]);
        subtotal += items[i].price;
        service += items[i].serviceFee;
      } else {
        this.m_rows[i].Clear();
      }
      i += 1;
    }

    let total: Int32 = subtotal + service;
    let balance: Int32 = GarageTransactions.Balance();
    this.m_canAfford = balance >= total;
    this.m_subtotalValue.SetText(GarageText.Price(subtotal));
    this.m_serviceValue.SetText(GarageText.Price(service));
    let garage: String = this.Parts().Markup().Lines("   ");
    this.m_garageRates.SetText(garage);
    this.m_garageRates.SetVisible(StrLen(garage) > 0);
    this.m_totalValue.SetText(GarageText.Price(total));
    this.m_balanceValue.SetText(GarageText.Price(balance));
    this.m_balanceValue.SetTintColor(this.m_canAfford ? GarageColors.Gold() : GarageColors.Error());
    this.UpdateConfirmButton(cart.Count());
  }

  protected cb func OnRowRemove(widget: wref<inkWidget>) -> Bool {
    let subcategory: CName = CartRow.Find(this.m_rows, widget);
    if !IsNameValid(subcategory) { return false; }
    this.Parts().RemoveFromCart(subcategory);
    this.Trigger(n"OnCartChanged");
    return false;
  }

  private func UpdateConfirmButton(count: Int32) -> Void {
    let key: CName = n"Garage-Checkout-Confirm";
    if count == 0 {
      key = n"Garage-Checkout-CartEmpty";
    } else if !this.m_canAfford {
      key = n"Garage-Checkout-CantAfford";
    }
    let ready: Bool = count > 0 && this.m_canAfford;
    SetButtonText(this.m_confirmBtn, GarageText.Get(key));
    this.m_confirmBtn.SetDisabled(!ready);
    this.m_confirmBtn.GetRootWidget().SetOpacity(ready ? 1.0 : 0.3);
  }

  // A quick checkout drops straight to the hub, anything else goes back the way it came
  public func OnBack() -> Bool {
    if !Equals(this.m_source, CheckoutSource.Quick) { return false; }
    let manager: ref<ScreenManager> = this.m_screenManager;
    if IsDefined(manager) { manager.RecoverToHub(); }
    return true;
  }

  protected cb func OnCancelClick(widget: wref<inkWidget>) -> Bool {
    let manager: ref<ScreenManager> = this.m_screenManager;
    if IsDefined(manager) { manager.Back(); }
    return false;
  }

  protected cb func OnConfirmClick(widget: wref<inkWidget>) -> Bool {
    if this.Parts().Cart().Count() == 0 || !this.m_canAfford { return false; }
    if this.Parts().Checkout() {
      GarageSounds.PlayInstall();
      this.Trigger(n"OnClosePopup");
    } else {
      this.RefreshAfterCartChange();
    }
    return false;
  }
}
