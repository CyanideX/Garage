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

// Holds its own car, the popup takes the visit's with it
public class RepairJob extends GarageSwapListener {
  private let m_addon: wref<RepairAddon>;
  private let m_xu: ref<XUtilsMod>;
  private let m_car: wref<VehicleObject>;
  private let m_receipt: ref<GarageReceipt>;
  private let m_full: Bool;
  private let m_timer: Uint64;
  private let m_sessionEnd: Uint64;

  public func Setup(addon: ref<RepairAddon>, xu: ref<XUtilsMod>, car: wref<VehicleObject>, receipt: ref<GarageReceipt>, full: Bool) -> Void {
    this.m_addon = addon;
    this.m_xu = xu;
    this.m_car = car;
    this.m_receipt = receipt;
    this.m_full = full;
    this.m_sessionEnd = xu.On(XUtilsEventType.SessionEnd, this, n"OnSessionEnd");
  }

  public func RunQuick(delay: Float) -> Void {
    this.m_timer = this.m_xu.After(delay, this, n"OnDelay");
    GarageSystem.Get().RequestClose();
  }

  public func OnDelay(e: ref<XUtilsEvent>) -> Void {
    this.m_timer = 0ul;
    this.Settle(this.FixHere());
  }

  public func OnBlack() -> Void { GarageSystem.Get().RequestClose(); }

  public func InPlace() -> CName { return this.FixHere(); }

  public func OnClear(reason: CName, timedOut: Bool) -> Void { this.Settle(reason); }

  public func Refused() -> Void { this.Settle(n"busy"); }

  private func FixHere() -> CName {
    let car: wref<VehicleObject> = this.m_car;
    if !IsDefined(car) { return n"gone"; }
    if GarageVehicles.IsFullHealth(car) { return n"already_fixed"; }
    GarageVehicles.RepairInPlace(car);
    return n"";
  }

  private func Settle(reason: CName) -> Void {
    let amount: Int32 = this.m_receipt.amount;
    this.Drop();
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

  // A load replaces the money anyway. XU timers outlive it though, and this one would pay into the next save
  public func OnSessionEnd(e: ref<XUtilsEvent>) -> Void { this.Drop(); }

  private func Drop() -> Void {
    this.m_xu.Off(this.m_sessionEnd);
    if this.m_timer != 0ul { this.m_xu.Cancel(this.m_timer); }
    this.m_timer = 0ul;
    let addon: wref<RepairAddon> = this.m_addon;
    if IsDefined(addon) { addon.JobDone(); }
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
    let health: Float = GarageVehicles.HealthShown(ctx.vehicle);
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
    let unowned: Bool = ctx.MustClaimFirst();
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
    if !IsDefined(vehicle) || GarageVehicles.IsFullHealth(vehicle) || this.IsHeatBlocked() || ctx.MustClaimFirst() || !this.CarIsFree() {
      this.Refresh();
      return;
    }
    let quote: ref<GarageRepairQuote> = this.Quote(ctx, GarageVehicles.HealthShown(vehicle));
    let receipt: ref<GarageReceipt> = this.Charge(ctx.locationId, quote.total, EGarageTxKind.Service, n"repair");
    if !IsDefined(receipt) { return; }
    this.SetBusy(GarageText.Get(n"Garage-Repair-Repairing"));
    let job: ref<RepairJob> = new RepairJob();
    job.Setup(this.m_addon, system.Xu(), vehicle, receipt, this.m_full);
    this.m_addon.SetJob(job);
    let prices: ref<GaragePrices> = system.Pricing().Prices();
    if !this.m_full {
      job.RunQuick(prices.repairDelay);
      return;
    }
    let options: ref<XUtilsFadeOptions> = GarageEntitySwap.FadeOptions(prices.repairFadeHold);
    if !system.Swap().BehindFade(options, ctx.OwnedRecord(), vehicle.GetCurrentAppearanceName(), GarageVehicles.SpotOf(vehicle), vehicle, job) {
      system.RequestClose();
      job.Refused();
    }
  }
}
