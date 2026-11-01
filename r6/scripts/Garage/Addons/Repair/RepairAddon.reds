module Garage.Repair

import Garage.*
import Garage.Data.*
import Garage.Economy.*
import Garage.Services.*
import Garage.UI.*
import Garage.Vehicle.*

public class RepairAddon extends GarageAddon {
  private let m_job: ref<RepairJob>;

  public func Id() -> CName { return n"repair"; }
  public func IsEnabled(settings: ref<GarageSettings>) -> Bool { return settings.repairEnabled; }

  public func Stop() -> Void {
    if IsDefined(this.m_job) { this.m_job.Abandon(); }
    this.m_job = null;
  }

  public func Services() -> array<ref<GarageService>> {
    let list: array<ref<GarageService>>;
    ArrayPush(list, new RepairService());
    return list;
  }

  public func RegisterScreens(screens: ref<ScreenManager>, frame: ref<GarageFrame>) -> Void {
    let screen: ref<RepairScreen> = new RepairScreen();
    screen.CreateInstance();
    screen.SetAddon(this);
    frame.AddScreen(screen);
    screens.RegisterScreen(n"repair_confirm", screen);
  }

  public func HasJob() -> Bool { return IsDefined(this.m_job); }
  public func SetJob(job: ref<RepairJob>) -> Void { this.m_job = job; }
  public func JobDone() -> Void { this.m_job = null; }
}

public class RepairService extends GarageService {
  public func Id() -> CName { return n"repair"; }
  public func Label() -> String { return GarageText.Get(n"Garage-Desc-Repair"); }
  public func Priority() -> Int32 { return 40; }
  public func IsMuted(ctx: ref<GarageContext>) -> Bool { return GarageVehicles.IsFullHealth(ctx.vehicle); }
  public func Open(ctx: ref<GarageContext>) -> Void { ctx.screens.ShowScreen(n"repair_confirm"); }
}

/// One paid repair from Confirm to the banner. It keeps the car it was given, since the popup closes under it and takes the visit's car with it.
public class RepairJob extends GarageSwapListener {
  private let m_addon: wref<RepairAddon>;
  private let m_xu: ref<XUtilsMod>;
  private let m_car: wref<VehicleObject>;
  private let m_receipt: ref<GarageReceipt>;
  private let m_full: Bool;
  private let m_timer: Uint64;
  private let m_reported: Bool;
  private let m_settled: Bool;

  public func Setup(addon: ref<RepairAddon>, xu: ref<XUtilsMod>, car: wref<VehicleObject>, receipt: ref<GarageReceipt>, full: Bool) -> Void {
    this.m_addon = addon;
    this.m_xu = xu;
    this.m_car = car;
    this.m_receipt = receipt;
    this.m_full = full;
  }

  public func RunQuick(delay: Float) -> Void {
    this.m_timer = this.m_xu.After(delay, this, n"OnDelay");
    GarageSystem.Get().ClosePopup();
  }

  public func OnDelay(e: ref<XUtilsEvent>) -> Void {
    this.m_timer = 0ul;
    this.Settle(this.FixHere());
  }

  public func OnBlack() -> Void { GarageSystem.Get().ClosePopup(); }

  public func InPlace() -> CName { return this.FixHere(); }

  public func OnResult(reason: CName, car: wref<VehicleObject>) -> Void { this.m_reported = true; }

  public func OnClear(reason: CName, timedOut: Bool) -> Void { this.Settle(this.m_reported ? reason : n"timeout"); }

  private func FixHere() -> CName {
    let car: wref<VehicleObject> = this.m_car;
    if !IsDefined(car) { return n"gone"; }
    if GarageVehicles.IsFullHealth(car) { return n"already_fixed"; }
    GarageVehicles.RepairInPlace(car);
    return n"";
  }

  private func Settle(reason: CName) -> Void {
    if this.m_settled { return; }
    this.m_settled = true;
    let amount: Int32 = this.m_receipt.amount;
    let addon: wref<RepairAddon> = this.m_addon;
    if IsDefined(addon) { addon.JobDone(); }
    if !IsNameValid(reason) {
      GarageServiceNotify.Post(GarageText.Get(this.m_full ? n"Garage-Repair-CompleteFull" : n"Garage-Repair-CompleteQuick"), "", amount);
      return;
    }
    GarageTransactions.Refund(this.m_receipt);
    let price: String = GarageText.Price(amount);
    let text: String = Equals(reason, n"gone") ? GarageText.Format(n"Garage-Repair-RefundedUnavailable", [price])
                       : Equals(reason, n"already_fixed") ? GarageText.Format(n"Garage-Repair-RefundedAlreadyFixed", [price])
                       : GarageText.Format(n"Garage-Repair-RefundedFailed", [NameToString(reason), price]);
    this.m_xu.Log("Vehicle").Warn("repair failed: " + NameToString(reason));
    this.m_xu.Screen().Notify(text, SimpleMessageType.Negative, 5.0, false);
  }

  /// The session ended under it, so the money goes back with no banner.
  public func Abandon() -> Void {
    if this.m_settled { return; }
    this.m_settled = true;
    if this.m_timer != 0ul { this.m_xu.Cancel(this.m_timer); }
    this.m_timer = 0ul;
    GarageTransactions.Refund(this.m_receipt);
  }
}

public class RepairScreen extends GarageConfirmScreen {
  private let m_addon: wref<RepairAddon>;
  private let m_full: Bool;

  public func SetAddon(addon: ref<RepairAddon>) -> Void { this.m_addon = addon; }

  public func Show() {
    this.m_full = false;
    super.Show();
  }

  public func NextPage() -> Void { this.Flip(); }
  public func PrevPage() -> Void { this.Flip(); }

  private func Flip() -> Void {
    this.m_full = !this.m_full;
    this.Refresh();
  }

  private func Quote(ctx: ref<GarageContext>, health: Float) -> ref<GarageRepairQuote> {
    let system: ref<GarageSystem> = GarageSystem.Get();
    let location: ref<GarageLocation> = system.Data().GetLocation(ctx.locationId);
    let garage: Float = IsDefined(location) ? location.economy.serviceMultiplier : 1.0;
    return system.Pricing().QuoteRepair(ctx.vehicleRecord, health, this.m_full, garage);
  }

  private func IsHeatBlocked() -> Bool {
    return this.m_full && GarageSystem.Get().Xu().State().Get(XUtilsStateField.WantedLevel) > 0;
  }

  private func MustClaimFirst(ctx: ref<GarageContext>) -> Bool {
    return !ctx.isOwned && GarageSystem.Get().IsAddonUp(n"chopshop");
  }

  // Full swaps the car behind a fade, Quick only needs the car left alone
  private func CarIsFree() -> Bool {
    let swap: ref<GarageEntitySwap> = GarageSystem.Get().Swap();
    return !this.m_addon.HasJob() && (this.m_full ? swap.CanStart() : !swap.IsBusy());
  }

  protected func Fill() -> Void {
    let ctx: ref<GarageContext> = GarageSystem.Get().Parts().Context();
    this.SetTitle(GarageText.Get(n"Garage-Repair-Title"));
    this.SetCar(ctx.vehicleDisplayName);
    let percent: Int32 = GarageVehicles.HealthPercent(ctx.vehicle);
    if percent >= 100 {
      this.SetStatus(GarageText.Get(n"Garage-Repair-NoDamage"), new HDRColor(0.35, 0.85, 0.45, 1.0));
      this.Refuse("");
      return;
    }
    let health: Float = Cast<Float>(percent) / 100.0;
    this.SetStatus(IntToString(percent) + "% " + GarageText.Get(n"Garage-Repair-HealthSuffix"), this.ConditionTint(health));
    this.SetStatusPulsing(percent < 20);
    let name: String = GarageText.Get(this.m_full ? n"Garage-Repair-FullTier" : n"Garage-Repair-QuickTier");
    this.SetOption(name + (this.m_full ? " (2 / 2)" : " (1 / 2)"), GarageText.Get(this.m_full ? n"Garage-Repair-FullDesc" : n"Garage-Repair-QuickDesc"));
    let quote: ref<GarageRepairQuote> = this.Quote(ctx, health);
    let lines: String = GarageText.Get(n"Garage-Repair-BaseLabel") + GarageText.Price(quote.base)
      + "\n" + GarageText.Get(n"Garage-Repair-FeeLabel") + GarageText.Price(quote.fee)
      + "\n" + GarageText.Get(n"Garage-Repair-TotalLabel") + GarageText.Price(quote.total);
    this.SetPrice(GarageText.Get(this.m_full ? n"Garage-Repair-FullPriceLabel" : n"Garage-Repair-QuickPriceLabel"), quote.total, lines);
    let balance: Int32 = GarageTransactions.Balance();
    this.SetBalance(GarageText.Get(n"Garage-Repair-BalanceLabel"), balance, balance >= quote.total);
    let blocked: Bool = this.IsHeatBlocked();
    let unowned: Bool = this.MustClaimFirst(ctx);
    if blocked { this.SetWarning(GarageText.Get(n"Garage-Repair-HeatWarning")); }
    if unowned {
      this.SetConfirmText(GarageText.Get(n"Garage-Paint-ClaimFirst"));
    } else {
      if blocked { this.SetConfirmText(GarageText.Get(n"Garage-Repair-Blocked")); }
    }
    this.SetCanConfirm(balance >= quote.total && !blocked && !unowned && this.CarIsFree());
  }

  protected func OnConfirmed() -> Void {
    let system: ref<GarageSystem> = GarageSystem.Get();
    let ctx: ref<GarageContext> = system.Parts().Context();
    let vehicle: wref<VehicleObject> = ctx.vehicle;
    if !IsDefined(vehicle) || GarageVehicles.IsFullHealth(vehicle) || this.IsHeatBlocked() || this.MustClaimFirst(ctx) || !this.CarIsFree() {
      this.Refresh();
      return;
    }
    let health: Float = Cast<Float>(GarageVehicles.HealthPercent(vehicle)) / 100.0;
    let quote: ref<GarageRepairQuote> = this.Quote(ctx, health);
    let receipt: ref<GarageReceipt> = GarageTransactions.Charge(ctx.locationId, quote.total, EGarageTxKind.Service, n"repair");
    if !receipt.ok {
      system.Xu().Screen().Notify(GarageText.Get(n"Garage-Transaction-DeductFailed"), SimpleMessageType.Negative, 3.0, true);
      this.Refresh();
      return;
    }
    this.SetBusy(GarageText.Get(n"Garage-Repair-Repairing"));
    let job: ref<RepairJob> = new RepairJob();
    job.Setup(this.m_addon, system.Xu(), vehicle, receipt, this.m_full);
    this.m_addon.SetJob(job);
    let prices: ref<GaragePrices> = system.Pricing().Prices();
    if !this.m_full {
      job.RunQuick(prices.repairDelay);
      return;
    }
    let options: ref<XUtilsFadeOptions> = XUtilsFadeOptions.Create().Out(0.75).In(0.75).MinHold(prices.repairFadeHold).MaxHold(17.0);
    // An unowned car can't be summoned again, so it's fixed where it sits
    let record: TweakDBID = ctx.isOwned ? ctx.vehicleRecord : TDBID.None();
    if !system.Swap().BehindFade(options, record, vehicle.GetCurrentAppearanceName(), GarageVehicles.SpotOf(vehicle), vehicle, job) {
      system.ClosePopup();
      job.OnClear(n"busy", false);
    }
  }
}
