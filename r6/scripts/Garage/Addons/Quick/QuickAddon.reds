module Garage.Quick

import Garage.*
import Garage.Data.*
import Garage.Economy.*
import Garage.Scene.*
import Garage.Services.*
import Garage.UI.*
import Garage.Vehicle.*
import Garage.World.*

public class QuickAddon extends GarageAddon {
  private let m_xu: ref<XUtilsMod>;
  private let m_listener: Uint64;
  private let m_timer: ref<QuickHeatTimer>;
  private let m_screen: wref<QuickScreen>;
  private let m_record: TweakDBID;

  public func Id() -> CName { return n"quick"; }
  public func IsEnabled(settings: ref<GarageSettings>) -> Bool { return settings.quickEnabled; }

  public func Start(garage: ref<GarageSystem>) -> Void {
    this.m_xu = garage.Xu();
    this.m_timer = new QuickHeatTimer();
    this.m_timer.Setup(this.m_xu);
    this.m_listener = this.m_xu.OnCustom(GarageEvents.Transaction(), this, n"OnTransaction");
  }

  public func Stop() -> Void {
    if this.m_listener != 0ul { this.m_xu.Off(this.m_listener); }
    this.m_listener = 0ul;
    if IsDefined(this.m_timer) { this.m_timer.Stop(); }
    this.m_timer = null;
  }

  public func Services() -> array<ref<GarageService>> {
    let list: array<ref<GarageService>>;
    let service: ref<QuickService> = new QuickService();
    service.SetAddon(this);
    ArrayPush(list, service);
    return list;
  }

  public func RegisterScreens(screens: ref<ScreenManager>, frame: ref<GarageFrame>) -> Void {
    let screen: ref<QuickScreen> = new QuickScreen();
    screen.CreateInstance();
    screen.SetAddon(this);
    frame.AddScreen(screen);
    screens.RegisterScreen(n"quick_confirm", screen);
    this.m_screen = screen;
  }

  public func OnVisitStart(ctx: ref<GarageContext>) -> Void { this.m_record = ctx.vehicleRecord; }

  public func OnVisitEnd(ctx: ref<GarageContext>) -> Void {
    let screen: wref<QuickScreen> = this.m_screen;
    if IsDefined(screen) { screen.RevertLook(); }
  }

  public func Heat() -> Int32 { return this.m_xu.State().Get(XUtilsStateField.WantedLevel); }

  public func IsRunning() -> Bool { return IsDefined(this.m_timer) && this.m_timer.IsRunning(); }

  /// Why there's no rush to be had, "" if there is. Being short on eddies isn't one, the screen still shows the price.
  public func Refusal() -> String {
    let heat: Int32 = this.Heat();
    if heat <= 0 { return GarageText.Get(n"Garage-Unavailable-QuickMessage"); }
    if this.IsRunning() { return GarageText.Get(n"Garage-Quick-AlreadyPaid"); }
    if heat > GarageSystem.Get().Pricing().Prices().rushMaxHeat { return GarageText.Get(n"Garage-Quick-HeatTooHigh"); }
    return "";
  }

  // Any rush starts the clock, whether it came through the screen or a cart with quickServicePending set
  public func OnTransaction(e: ref<XUtilsEvent>) -> Void {
    let data: ref<GarageTransactionData> = e.data as GarageTransactionData;
    if !IsDefined(data) || !Equals(data.kind, EGarageTxKind.Rush) { return; }
    let location: ref<GarageLocation> = GarageSystem.Get().Data().GetLocation(data.garageId);
    if !IsDefined(location) { return; }
    let deck: Vector4 = location.deck.Position();
    this.m_timer.Start(this.m_record, deck, data.garageId);
    this.m_xu.Screen().Notify(GarageText.Format(n"Garage-Notify-PaidGetOut", [GarageText.Price(data.amount)]), SimpleMessageType.Negative, 4.0, true);
  }
}

public class QuickService extends GarageService {
  private let m_addon: wref<QuickAddon>;

  public func SetAddon(addon: ref<QuickAddon>) -> Void { this.m_addon = addon; }

  public func Id() -> CName { return n"quick"; }
  public func Label() -> String { return GarageText.Get(n"Garage-Desc-Quick"); }
  public func Priority() -> Int32 { return 30; }

  public func IsMuted(ctx: ref<GarageContext>) -> Bool {
    let addon: wref<QuickAddon> = this.m_addon;
    return addon.Heat() <= 0 || addon.IsRunning();
  }

  public func IsHighlighted(ctx: ref<GarageContext>) -> Bool { return true; }
  public func Open(ctx: ref<GarageContext>) -> Void { ctx.screens.ShowScreen(n"quick_confirm"); }
}

/// New paint and 15 seconds to get clear of the garage, which then shuts for a day whether V made it or not.
public class QuickHeatTimer extends GarageGetawayTimer {
  protected func OnGotAway() -> Void {
    let prevention: ref<PreventionSystem> = GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"PreventionSystem") as PreventionSystem;
    if IsDefined(prevention) {
      prevention.ChangeHeatStage(EPreventionHeatStage.Heat_0, "");
      prevention.ChangeAgentsAttitude(EAIAttitude.AIA_Neutral);
    }
    this.LockOut();
    this.m_xu.Screen().Notify(GarageText.Get(n"Garage-Notify-HeatCleared"), SimpleMessageType.Police, 5.0, true);
  }

  protected func OnTooSlow() -> Void {
    this.LockOut();
    this.m_xu.Screen().Notify(GarageText.Get(n"Garage-Notify-ClaimLockdown"), SimpleMessageType.Negative, 5.0, true);
  }

  private func LockOut() -> Void { EconomyEngine.Get().LockGarage(this.m_garage, 86400, GarageLockReason.Lockdown()); }
}

public class QuickScreen extends GarageConfirmScreen {
  private let m_addon: wref<QuickAddon>;
  private let m_quote: ref<GarageRushQuote>;
  private let m_preview: ref<GarageLookPreview>;
  private let m_look: CName;
  private let m_lookName: String;
  private let m_status: EGaragePartStatus;

  public func SetAddon(addon: ref<QuickAddon>) -> Void { this.m_addon = addon; }

  // The camera only moves when this one really comes or goes
  public func Show() {
    let wasVisible: Bool = this.m_isVisible;
    this.m_quote = null;
    super.Show();
    if !wasVisible { GarageSystem.Get().Scene().Checkout(); }
  }

  public func Hide() {
    let wasVisible: Bool = this.m_isVisible;
    super.Hide();
    if wasVisible { GarageSystem.Get().Scene().ExitCheckout(); }
  }

  protected func Fill() -> Void {
    let ctx: ref<GarageContext> = GarageSystem.Get().Parts().Context();
    let addon: wref<QuickAddon> = this.m_addon;
    this.SetTitle(GarageText.Get(n"Garage-Quick-Title"));
    this.SetCar(ctx.vehicleDisplayName);
    let refusal: String = addon.Refusal();
    if StrLen(refusal) > 0 {
      this.Refuse(refusal);
      return;
    }
    if !IsDefined(this.m_quote) && !this.Roll(ctx) {
      this.Refuse(GarageText.Get(n"Garage-Paint-NoAppearances"));
      return;
    }
    let quote: ref<GarageRushQuote> = this.m_quote;
    let balance: Int32 = GarageTransactions.Balance();
    this.SetOption(this.m_lookName, "");
    let lines: String = GarageText.Get(n"Garage-Quick-AppearanceLabel") + " " + GarageText.Price(quote.look) + "\n" + GarageText.Get(n"Garage-Quick-RushFeeLabel") + " " + GarageText.Price(quote.fee);
    this.SetPrice(GarageText.Get(n"Garage-Quick-TotalLabel"), quote.total, lines);
    this.SetBalance(GarageText.Get(n"Garage-Quick-BalanceLabel"), balance, balance >= quote.total);
    this.SetCanConfirm(balance >= quote.total);
  }

  // Never the look it's already wearing, or V's paid to change nothing
  private func Roll(ctx: ref<GarageContext>) -> Bool {
    let system: ref<GarageSystem> = GarageSystem.Get();
    let heat: Int32 = this.m_addon.Heat();
    if ctx.hasSchema {
      let parts: ref<GarageParts> = system.Parts();
      let current: CName = parts.CurrentChoice(n"car_paint");
      let choices: array<ref<GarageChoiceInfo>> = parts.Choices(n"car_paint");
      let others: array<ref<GarageChoiceInfo>>;
      for choice in choices {
        if !Equals(choice.id, current) { ArrayPush(others, choice); }
      }
      if ArraySize(others) == 0 { return false; }
      let pick: ref<GarageChoiceInfo> = others[RandRange(0, ArraySize(others))];
      this.m_look = pick.id;
      this.m_lookName = pick.name;
      this.m_status = pick.status;
      this.m_quote = system.Pricing().QuoteRush(pick.price, parts.ServiceFee(n"car_paint"), heat);
      parts.Preview(n"car_paint", pick.id);
      return true;
    }
    let vehicle: wref<VehicleObject> = ctx.vehicle;
    if !IsDefined(vehicle) { return false; }
    let worn: CName = vehicle.GetCurrentAppearanceName();
    let looks: array<CName> = system.Appearances().For(ctx.vehicleRecord, worn);
    ArrayRemove(looks, worn);
    if ArraySize(looks) == 0 { return false; }
    this.m_look = looks[RandRange(0, ArraySize(looks))];
    this.m_lookName = system.Appearances().DisplayName(this.m_look);
    let cost: Int32 = system.Pricing().SwapPrice(ctx.vehicleRecord, this.m_look, this.m_look, n"", 1.0, 0);
    this.m_quote = system.Pricing().QuoteRush(cost, cost, heat);
    this.m_preview = new GarageLookPreview();
    this.m_preview.Begin(vehicle);
    this.m_preview.Show(this.m_look);
    return true;
  }

  public func RevertLook() -> Void {
    if IsDefined(this.m_preview) { this.m_preview.Revert(); }
    this.m_preview = null;
    this.m_quote = null;
  }

  public func OnBack() -> Bool {
    GarageSystem.Get().Parts().LeaveSlot(n"car_paint");
    this.RevertLook();
    return false;
  }

  protected func OnConfirmed() -> Void {
    let system: ref<GarageSystem> = GarageSystem.Get();
    let ctx: ref<GarageContext> = system.Parts().Context();
    let quote: ref<GarageRushQuote> = this.m_quote;
    if !IsDefined(quote) || StrLen(this.m_addon.Refusal()) > 0 {
      this.Refresh();
      return;
    }
    let receipt: ref<GarageReceipt> = GarageTransactions.Charge(ctx.locationId, quote.total, EGarageTxKind.Rush, n"quick");
    if !receipt.ok {
      system.Xu().Screen().Notify(GarageText.Get(n"Garage-Transaction-DeductFailed"), SimpleMessageType.Negative, 3.0, true);
      this.Refresh();
      return;
    }
    if ctx.hasSchema {
      system.Parts().Install(n"car_paint", this.m_look, this.m_status);
    } else {
      this.m_preview.Keep();
      // A stolen car keeps its new look, but writing the record would repaint every one in traffic
      if ctx.isOwned { GaragePaint.Apply(ctx.vehicleRecord, this.m_look); }
    }
    this.Trigger(n"OnClosePopup");
  }
}
