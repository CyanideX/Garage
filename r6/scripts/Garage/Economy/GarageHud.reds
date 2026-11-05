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
    let style: ref<XUtilsPanelStyle> = XUtilsPanelStyle.Create().Header(new HDRColor(1.0, 1.0, 1.0, 1.0)).HeaderSize(40.0).Size(34.0);
    let spec: ref<XUtilsPanelSpec> = XUtilsPanelSpec.Create().Header(garage.name).Corner(XUtilsScreenAnchor.BottomRight).Layer(XUtilsScreenLayer.Scene)
      .Style(style).Width(640.0)
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

/// 15 seconds on screen to drive this car off the lot, or the garage locks for a day. Subclass it for the getaway.
public abstract class GarageGetawayTimer extends IScriptable {
  protected let m_xu: ref<XUtilsMod>;
  protected let m_garage: CName;
  private let m_countdown: ref<XUtilsCountdown>;
  private let m_watch: ref<XUtilsWatcher>;
  private let m_record: TweakDBID;

  private static func Seconds() -> Float { return 15.0; }
  private static func LeaveDistance() -> Float { return 15.0; }

  protected func OnGotAway() -> Void {}

  protected func OnTooSlow() -> Void {
    this.LockOut();
    this.m_xu.Screen().Notify(GarageText.Get(n"Garage-Notify-ClaimLockdown"), SimpleMessageType.Negative, 5.0, true);
  }

  protected func LockOut() -> Void { EconomyEngine.Get().LockGarage(this.m_garage, GarageLocks.Day(), GarageLockReason.Lockdown()); }

  public func Setup(xu: ref<XUtilsMod>) -> Void { this.m_xu = xu; }

  public func Start(record: TweakDBID, deck: Vector4, garage: CName) -> Void {
    this.Stop();
    this.m_record = record;
    this.m_garage = garage;
    let options: ref<XUtilsCountdownOptions> = XUtilsCountdownOptions.Create().Seconds(GarageGetawayTimer.Seconds()).Format(XUtilsTimeFormat.MinSecTenths)
      .Stage(5.0, new HDRColor(1.176, 0.2, 0.2, 1.0), 2.0)
      .OnZero(XUtilsCountdownEnd.Create().Hold(5.0).Blink(3).FadeOut(1.0)).Layer(XUtilsScreenLayer.Scene);
    this.m_countdown = this.m_xu.Screen().Countdown(options);
    this.m_countdown.On(XUtilsEventType.CountdownComplete, this, n"OnExpired");
    this.m_countdown.Start();
    this.m_watch = this.m_xu.World().Watch(XUtilsZones.At(deck).Flat(true).Ring(GarageGetawayTimer.LeaveDistance()));
    this.m_watch.On(XUtilsEventType.ZoneExit, this, n"OnLeft");
  }

  // Walking out doesn't count. Coming back and driving it off does, since that crosses the ring again
  public func OnLeft(e: ref<XUtilsEvent>) -> Void {
    let car: wref<Entity> = this.m_xu.Player().GetVehicle();
    let vehicle: wref<VehicleObject> = car as VehicleObject;
    if !IsDefined(vehicle) || vehicle.GetRecordID() != this.m_record { return; }
    this.CancelWatch();
    this.m_countdown.Cancel(1.0);
    this.OnGotAway();
  }

  public func OnExpired(e: ref<XUtilsEvent>) -> Void {
    this.CancelWatch();
    this.OnTooSlow();
  }

  public func IsRunning() -> Bool { return IsDefined(this.m_watch); }

  private func CancelWatch() -> Void {
    if IsDefined(this.m_watch) { this.m_watch.Destroy(); }
    this.m_watch = null;
  }

  public func Stop() -> Void {
    this.CancelWatch();
    if IsDefined(this.m_countdown) { this.m_countdown.Destroy(); }
    this.m_countdown = null;
  }
}

/// A freshly claimed car has to get clear.
public class GarageClaimTimer extends GarageGetawayTimer {}
