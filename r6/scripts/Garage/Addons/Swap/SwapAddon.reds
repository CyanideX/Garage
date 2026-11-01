module Garage.Swap

import Garage.*
import Garage.Data.*
import Garage.Economy.*
import Garage.Scene.*
import Garage.Services.*
import Garage.UI.*
import Garage.Vehicle.*

public class SwapAddon extends GarageAddon {
  private let m_screen: wref<SwapScreen>;

  public func Id() -> CName { return n"swap"; }
  public func IsEnabled(settings: ref<GarageSettings>) -> Bool { return settings.swapEnabled; }

  // Flats don't survive a load
  public func Start(garage: ref<GarageSystem>) -> Void {
    let done: Int32 = GaragePaint.ReapplyAll();
    if done > 0 {
      GaragePaint.RefreshNearby();
      garage.Xu().Log("Vehicle").Info("re-applied " + IntToString(done) + " saved looks");
    }
  }

  public func Services() -> array<ref<GarageService>> {
    let list: array<ref<GarageService>>;
    ArrayPush(list, new SwapService());
    return list;
  }

  public func RegisterScreens(screens: ref<ScreenManager>, frame: ref<GarageFrame>) -> Void {
    let screen: ref<SwapScreen> = new SwapScreen();
    screen.CreateInstance();
    frame.AddScreen(screen);
    screens.RegisterScreen(n"swap", screen);
    this.m_screen = screen;
  }

  public func OnVisitEnd(ctx: ref<GarageContext>) -> Void {
    let screen: wref<SwapScreen> = this.m_screen;
    if IsDefined(screen) { screen.RevertLook(); }
  }
}

public class SwapService extends GarageService {
  public func Id() -> CName { return n"swap"; }
  public func Label() -> String { return GarageText.Get(n"Garage-Desc-Swap"); }
  public func Priority() -> Int32 { return 60; }

  private func LookCount(ctx: ref<GarageContext>) -> Int32 {
    let vehicle: wref<VehicleObject> = ctx.vehicle;
    if ctx.hasSchema || !IsDefined(vehicle) { return 0; }
    return GarageSystem.Get().Appearances().Count(ctx.vehicleRecord, vehicle.GetCurrentAppearanceName());
  }

  public func IsMuted(ctx: ref<GarageContext>) -> Bool {
    return this.LookCount(ctx) <= 1 || (!ctx.isOwned && GarageSystem.Get().IsAddonUp(n"chopshop"));
  }

  public func Open(ctx: ref<GarageContext>) -> Void {
    if this.LookCount(ctx) <= 1 {
      ctx.screens.ShowUnavailable(GarageText.Get(n"Garage-Unavailable-SwapTitle"), GarageText.Get(n"Garage-Unavailable-SwapMessage"));
      return;
    }
    GarageSystem.Get().Scene().GoToCategory(n"car_paint");
    ctx.screens.ShowScreen(n"swap");
  }
}

public class SwapJob extends GarageSwapListener {
  private let m_amount: Int32;

  public func Setup(amount: Int32) -> Void { this.m_amount = amount; }

  public func OnBlack() -> Void { GarageSystem.Get().ClosePopup(); }

  public func OnClear(reason: CName, timedOut: Bool) -> Void {
    if !timedOut { GarageServiceNotify.Post(GarageText.Get(n"Garage-Notify-DesignApplied"), "", this.m_amount); }
  }
}

public class SwapScreen extends GarageConfirmScreen {
  private let m_looks: array<CName>;
  private let m_index: Int32;
  private let m_preview: ref<GarageLookPreview>;

  public func Show() {
    let ctx: ref<GarageContext> = GarageSystem.Get().Parts().Context();
    let vehicle: wref<VehicleObject> = ctx.vehicle;
    this.m_preview = new GarageLookPreview();
    this.m_preview.Begin(vehicle);
    let worn: CName = this.m_preview.Original();
    this.m_looks = GarageSystem.Get().Appearances().For(ctx.vehicleRecord, worn);
    this.m_index = Max(ArrayFindFirst(this.m_looks, worn), 0);
    super.Show();
  }

  public func NextPage() -> Void { this.Step(1); }
  public func PrevPage() -> Void { this.Step(-1); }

  private func Step(by: Int32) -> Void {
    let count: Int32 = ArraySize(this.m_looks);
    if count == 0 { return; }
    this.m_index = (this.m_index + by + count) % count;
    this.Refresh();
  }

  private func Price(ctx: ref<GarageContext>, look: CName) -> Int32 {
    return GarageSystem.Get().Pricing().SwapPrice(ctx.vehicleRecord, this.m_preview.Original(), look, n"", 1.0, 0);
  }

  protected func Fill() -> Void {
    let system: ref<GarageSystem> = GarageSystem.Get();
    let ctx: ref<GarageContext> = system.Parts().Context();
    this.SetTitle(GarageText.Get(n"Garage-Paint-Title"));
    this.SetCar(ctx.vehicleDisplayName);
    let count: Int32 = ArraySize(this.m_looks);
    if count == 0 {
      this.Refuse(GarageText.Get(n"Garage-Paint-NoAppearances"));
      return;
    }
    let appearances: ref<GarageAppearances> = system.Appearances();
    let look: CName = this.m_looks[this.m_index];
    let original: CName = this.m_preview.Original();
    this.m_preview.Show(look);
    this.SetStatus(appearances.DisplayName(original), GarageColors.Gold());
    this.SetOption(appearances.DisplayName(look) + " (" + IntToString(this.m_index + 1) + " / " + IntToString(count) + ")", "");
    let price: Int32 = this.Price(ctx, look);
    let balance: Int32 = GarageTransactions.Balance();
    this.SetPrice(GarageText.Get(n"Garage-Paint-PriceLabel"), price, "");
    this.SetBalance(GarageText.Get(n"Garage-Paint-BalanceLabel"), balance - price, balance >= price);
    let same: Bool = Equals(look, original);
    let unowned: Bool = !ctx.isOwned && system.IsAddonUp(n"chopshop");
    if unowned {
      this.SetConfirmText(GarageText.Get(n"Garage-Paint-ClaimFirst"));
    } else {
      if same { this.SetConfirmText(GarageText.Get(ctx.isOwned ? n"Garage-Paint-Owned" : n"Garage-Paint-Active")); }
    }
    this.SetCanConfirm(balance >= price && !same && !unowned && system.Swap().CanStart());
  }

  public func RevertLook() -> Void {
    if IsDefined(this.m_preview) { this.m_preview.Revert(); }
    this.m_preview = null;
  }

  public func OnBack() -> Bool {
    this.RevertLook();
    return false;
  }

  protected func OnConfirmed() -> Void {
    let system: ref<GarageSystem> = GarageSystem.Get();
    let ctx: ref<GarageContext> = system.Parts().Context();
    let vehicle: wref<VehicleObject> = ctx.vehicle;
    if !IsDefined(vehicle) || !system.Swap().CanStart() {
      this.Refresh();
      return;
    }
    let look: CName = this.m_looks[this.m_index];
    let price: Int32 = this.Price(ctx, look);
    let receipt: ref<GarageReceipt> = GarageTransactions.Charge(ctx.locationId, price, EGarageTxKind.Service, n"swap");
    if !receipt.ok {
      system.Xu().Screen().Notify(GarageText.Get(n"Garage-Transaction-DeductFailed"), SimpleMessageType.Negative, 3.0, true);
      this.Refresh();
      return;
    }
    this.SetBusy(GarageText.Get(n"Garage-Paint-Confirm"));
    let job: ref<SwapJob> = new SwapJob();
    job.Setup(price);
    let options: ref<XUtilsFadeOptions> = XUtilsFadeOptions.Create().Out(0.75).In(0.75).MinHold(0.5).MaxHold(17.0);
    let record: TweakDBID = ctx.isOwned ? ctx.vehicleRecord : TDBID.None();
    if !system.Swap().BehindFade(options, record, look, GarageVehicles.SpotOf(vehicle), vehicle, job) {
      GarageTransactions.Refund(receipt);
      this.Refresh();
      return;
    }
    this.m_preview.Keep();
    // A stolen car keeps its new look, but writing the record would repaint every one in traffic
    if ctx.isOwned { GaragePaint.Apply(ctx.vehicleRecord, look); }
  }
}
