module Garage.Economy

import Garage.*
import Garage.Data.*
import Garage.World.*

/// The garage's name, cash and tier in the corner while it's open.
public class GarageEconomyPanel extends IScriptable {
  private let m_xu: ref<XUtilsMod>;
  private let m_panel: ref<XUtilsPanel>;
  private let m_garage: CName;

  public func Setup(xu: ref<XUtilsMod>) -> Void {
    this.m_xu = xu;
    xu.OnCustom(GarageEvents.EconomyRefresh(), this, n"OnRefresh");
  }

  public func Show(garage: ref<GarageLocation>) -> Void {
    this.Hide();
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if !IsDefined(engine) { return; }
    this.m_garage = garage.id;
    let spec: ref<XUtilsPanelSpec> = XUtilsPanelSpec.Create().Header(garage.name).Corner(XUtilsScreenAnchor.BottomRight).Layer(XUtilsScreenLayer.Scene)
      .Row(n"cash", GarageText.Get(n"Garage-HUD-Cash"), XUtilsRowKind.Text)
      .Row(n"tier", GarageText.Get(n"Garage-HUD-Tier"), XUtilsRowKind.Text);
    this.m_panel = this.m_xu.Screen().Panel(spec);
    this.m_panel.SetText(n"tier", GarageText.Get(StringToName("Garage-Tier-" + NameToString(engine.GetTier(garage.id)))));
    this.Update();
    this.m_panel.Show();
  }

  public func Hide() -> Void {
    if IsDefined(this.m_panel) { this.m_panel.Destroy(); }
    this.m_panel = null;
    this.m_garage = n"";
  }

  public func OnRefresh(e: ref<XUtilsEvent>) -> Void {
    if IsDefined(this.m_panel) { this.Update(); }
  }

  private func Update() -> Void {
    this.m_panel.SetText(n"cash", "€$ " + GarageText.Price(EconomyEngine.Get().GetPool(this.m_garage)));
  }
}

/// 15 seconds on screen to drive this car off the lot. Subclass it for what happens each way.
public abstract class GarageGetawayTimer extends IScriptable {
  protected let m_xu: ref<XUtilsMod>;
  protected let m_garage: CName;
  private let m_countdown: ref<XUtilsCountdown>;
  private let m_watch: Uint64;
  private let m_record: TweakDBID;
  private let m_deck: Vector4;

  private static func Seconds() -> Float { return 15.0; }
  private static func LeaveDistance() -> Float { return 15.0; }

  protected func OnGotAway() -> Void {}
  protected func OnTooSlow() -> Void {}

  public func Setup(xu: ref<XUtilsMod>) -> Void { this.m_xu = xu; }

  public func Start(record: TweakDBID, deck: Vector4, garage: CName) -> Void {
    this.Stop();
    this.m_record = record;
    this.m_deck = deck;
    this.m_garage = garage;
    let options: ref<XUtilsCountdownOptions> = XUtilsCountdownOptions.Create().Seconds(GarageGetawayTimer.Seconds()).Format(XUtilsTimeFormat.MinSecTenths)
      .Stage(5.0, new HDRColor(1.176, 0.2, 0.2, 1.0), 2.0)
      .OnZero(XUtilsCountdownEnd.Create().Hold(5.0).Blink(3).FadeOut(1.0)).Layer(XUtilsScreenLayer.Scene);
    this.m_countdown = this.m_xu.Screen().Countdown(options);
    this.m_countdown.On(XUtilsEventType.CountdownComplete, this, n"OnExpired");
    this.m_countdown.Start();
    this.m_watch = this.m_xu.Every(1.0, this, n"OnWatch");
  }

  public func OnWatch(e: ref<XUtilsEvent>) -> Void {
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    let car: wref<VehicleObject> = IsDefined(player) ? GetMountedVehicle(player) : null;
    if !IsDefined(car) || car.GetRecordID() != this.m_record { return; }
    let at: Vector4 = car.GetWorldPosition();
    if Vector4.Distance2D(at, this.m_deck) > GarageGetawayTimer.LeaveDistance() {
      this.CancelWatch();
      this.m_countdown.Cancel(1.0);
      this.OnGotAway();
    }
  }

  public func OnExpired(e: ref<XUtilsEvent>) -> Void {
    this.CancelWatch();
    this.OnTooSlow();
  }

  public func IsRunning() -> Bool { return this.m_watch != 0ul; }

  private func CancelWatch() -> Void {
    if this.m_watch != 0ul { this.m_xu.Cancel(this.m_watch); }
    this.m_watch = 0ul;
  }

  public func Stop() -> Void {
    this.CancelWatch();
    if IsDefined(this.m_countdown) { this.m_countdown.Destroy(); }
    this.m_countdown = null;
  }
}

/// A freshly claimed car has to get clear. Too slow locks the garage for a day.
public class GarageClaimTimer extends GarageGetawayTimer {
  protected func OnTooSlow() -> Void {
    EconomyEngine.Get().LockGarage(this.m_garage, 86400, GarageLockReason.Lockdown());
    this.m_xu.Screen().Notify(GarageText.Get(n"Garage-Notify-ClaimLockdown"), SimpleMessageType.Negative, 5.0, true);
  }
}
