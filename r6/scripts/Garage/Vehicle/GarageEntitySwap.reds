module Garage.Vehicle

import Garage.*
import Garage.Data.*

/// What a swap reports back. reason is n"" when it worked, otherwise busy, bad_args, no_player, timeout, lost, cancelled or aborted.
public abstract class GarageSwapListener extends IScriptable {
  /// First thing behind the black, for closing a popup.
  public func OnBlack() -> Void {}
  /// With no respawn asked for, the work to do behind the black. Return a reason if it failed.
  public func InPlace() -> CName { return n""; }
  /// Still black, or just done if there's no fade.
  public func OnResult(reason: CName, car: wref<VehicleObject>) -> Void {}
  /// The screen's back. timedOut means the black ran past its limit.
  public func OnClear(reason: CName, timedOut: Bool) -> Void {}
}

/// Replaces the player's car on the deck with a fresh copy of the same record: a new appearance, full health. One at a time.
public class GarageEntitySwap extends IScriptable {
  private let m_xu: ref<XUtilsMod>;
  private let m_log: ref<XUtilsLog>;
  private let m_active: Bool;
  private let m_record: TweakDBID;
  private let m_spot: ref<GarageSpot>;
  private let m_listener: ref<GarageSwapListener>;
  private let m_summonToggled: Bool;
  private let m_spawnTimer: Uint64;
  private let m_pollTimer: Uint64;
  private let m_settleTimer: Uint64;
  private let m_timeoutTimer: Uint64;
  private let m_attempts: Int32;
  private let m_car: wref<VehicleObject>;
  private let m_settled: Float;
  private let m_still: Int32;
  private let m_last: Vector4;
  private let m_hasLast: Bool;
  private let m_fade: ref<XUtilsFade>;
  private let m_fadeReason: CName;
  private let m_oldCar: wref<GameObject>;
  private let m_appearance: CName;
  // What a failure has to put back: the car moved off the deck, the look it wore
  private let m_moved: wref<GameObject>;
  private let m_movedOld: Bool;
  private let m_wroteFlat: Bool;
  private let m_oldFlat: CName;
  private let m_afterFade: array<String>;
  private let m_afterFadeKinds: array<SimpleMessageType>;
  private let m_afterFadeSeconds: array<Float>;

  private static func PollAttempts() -> Int32 { return 30; }
  private static func PollRadius() -> Float { return 50.0; }
  // Past PollRadius, or the poll finds the old car again
  private static func ParkOffset() -> Float { return 200.0; }
  private static func Timeout() -> Float { return 15.0; }

  /// A fade for BehindFade. It outlasts the swap's own timeout, so a failure reports before the screen clears.
  public static func FadeOptions(minHold: Float) -> ref<XUtilsFadeOptions> {
    return XUtilsFadeOptions.Create().Out(0.75).In(0.75).MinHold(minHold).MaxHold(GarageEntitySwap.Timeout() + 2.0);
  }

  public func Setup(xu: ref<XUtilsMod>) -> Void {
    this.m_xu = xu;
    this.m_log = xu.Log("Vehicle");
  }

  /// Check before charging for a swap. Refusing up front beats refunding after.
  public func CanStart() -> Bool { return !this.m_active && !IsDefined(this.m_fade); }

  public func IsBusy() -> Bool { return this.m_active; }

  /// Reports through listener.OnResult. False if it couldn't start.
  public func Respawn(record: TweakDBID, appearance: CName, spot: ref<GarageSpot>, old: wref<GameObject>, listener: ref<GarageSwapListener>) -> Bool {
    if !this.CanStart() {
      listener.OnResult(n"busy", null);
      return false;
    }
    return this.Begin(record, appearance, spot, old, listener);
  }

  private func Begin(record: TweakDBID, appearance: CName, spot: ref<GarageSpot>, old: wref<GameObject>, listener: ref<GarageSwapListener>) -> Bool {
    if !TDBID.IsValid(record) || !IsDefined(spot) {
      listener.OnResult(n"bad_args", null);
      return false;
    }
    this.m_active = true;
    this.m_record = record;
    this.m_spot = spot;
    this.m_listener = listener;
    this.m_attempts = 0;
    this.m_moved = old;
    this.m_movedOld = IsDefined(old);
    this.m_wroteFlat = IsNameValid(appearance);
    this.m_oldFlat = GaragePaint.GetFlat(record);
    let vehicles: ref<VehicleSystem> = GameInstance.GetVehicleSystem(GetGameInstance());
    TweakDBManager.SetFlat(t"Vehicle.summon_setup.forceDespawnOnResummon", true);
    // Off first, so the spawn system doesn't see an active car
    GarageVehicles.SetEnabled(record, false);
    // Before the spawn, or the game never makes a new one. The old car's gone after this, even teleported straight back
    if IsDefined(old) {
      let flat: EulerAngles;
      let parked: Vector4 = new Vector4(spot.x + GarageEntitySwap.ParkOffset(), spot.y, spot.z - GarageEntitySwap.ParkOffset(), 1.0);
      GameInstance.GetTeleportationFacility(GetGameInstance()).Teleport(old, parked, flat);
    }
    GarageVehicles.SetEnabled(record, true);
    if IsNameValid(appearance) { GaragePaint.WriteFlat(record, appearance); }
    // Instant summon while it spawns. Finish flips it back on every way out
    vehicles.ToggleSummonMode();
    this.m_summonToggled = true;
    this.m_spawnTimer = this.m_xu.After(0.3, this, n"OnSpawn");
    this.m_pollTimer = this.m_xu.After(0.5, this, n"OnPoll");
    this.m_timeoutTimer = this.m_xu.After(GarageEntitySwap.Timeout(), this, n"OnTimeout");
    return true;
  }

  public func OnSpawn(e: ref<XUtilsEvent>) -> Void {
    this.m_spawnTimer = 0ul;
    if !this.m_active { return; }
    let vehicle: wref<Vehicle_Record> = TweakDBInterface.GetVehicleRecord(this.m_record);
    let kind: wref<VehicleType_Record> = IsDefined(vehicle) ? vehicle.Type() : null;
    GameInstance.GetVehicleSystem(GetGameInstance()).SpawnPlayerVehicle(IsDefined(kind) ? kind.Type() : gamedataVehicleType.Car, this.m_record);
  }

  public func OnPoll(e: ref<XUtilsEvent>) -> Void {
    this.m_pollTimer = 0ul;
    if !this.m_active { return; }
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    if !IsDefined(player) {
      this.Finish(n"no_player");
      return;
    }
    this.m_attempts += 1;
    let around: array<ref<Entity>> = player.GetEntitiesAroundObject(GarageEntitySwap.PollRadius());
    for entity in around {
      let car: wref<VehicleObject> = entity as VehicleObject;
      if IsDefined(car) && car.GetRecordID() == this.m_record {
        this.Place(car);
        return;
      }
    }
    if this.m_attempts < GarageEntitySwap.PollAttempts() {
      this.m_pollTimer = this.m_xu.After(0.2, this, n"OnPoll");
    } else {
      this.Finish(n"timeout");
    }
  }

  private func Place(car: wref<VehicleObject>) -> Void {
    let spot: ref<GarageSpot> = this.m_spot;
    let angles: EulerAngles;
    angles.Yaw = spot.yaw;
    GameInstance.GetTeleportationFacility(GetGameInstance()).Teleport(car, spot.Position(), angles);
    this.m_car = car;
    this.m_settled = 0.0;
    this.m_still = 0;
    this.m_hasLast = false;
    this.m_settleTimer = this.m_xu.After(0.1, this, n"OnSettle");
  }

  // Placed means landed. It can still be dropping onto the deck after the teleport, and callers fade back in on this
  public func OnSettle(e: ref<XUtilsEvent>) -> Void {
    this.m_settleTimer = 0ul;
    if !this.m_active { return; }
    let car: wref<VehicleObject> = this.m_car;
    if !IsDefined(car) {
      this.Finish(n"lost");
      return;
    }
    this.m_settled += 0.1;
    let at: Vector4 = car.GetWorldPosition();
    if this.m_hasLast { this.m_still = Vector4.Distance(at, this.m_last) < 0.01 ? this.m_still + 1 : 0; }
    this.m_last = at;
    this.m_hasLast = true;
    if (this.m_settled >= 0.5 && this.m_still >= 3) || this.m_settled >= 3.0 {
      this.Finish(n"");
      return;
    }
    this.m_settleTimer = this.m_xu.After(0.1, this, n"OnSettle");
  }

  // Nobody loses a car to a failed swap: the old one goes back on the deck if it's still there, else it's summoned
  private func Recover(reason: CName) -> Void {
    if this.m_wroteFlat { GaragePaint.WriteFlat(this.m_record, this.m_oldFlat); }
    let how: String = "nothing moved";
    let old: wref<GameObject> = this.m_moved;
    if this.m_movedOld && IsDefined(old) && IsDefined(this.m_spot) {
      let angles: EulerAngles;
      angles.Yaw = this.m_spot.yaw;
      GameInstance.GetTeleportationFacility(GetGameInstance()).Teleport(old, this.m_spot.Position(), angles);
      how = "old car put back";
    } else {
      if this.m_movedOld && !IsDefined(this.m_car) {
        let vehicle: wref<Vehicle_Record> = TweakDBInterface.GetVehicleRecord(this.m_record);
        let kind: wref<VehicleType_Record> = IsDefined(vehicle) ? vehicle.Type() : null;
        GameInstance.GetVehicleSystem(GetGameInstance()).SpawnPlayerVehicle(IsDefined(kind) ? kind.Type() : gamedataVehicleType.Car, this.m_record);
        how = "summoned";
      }
    }
    this.m_log.Warn("swap failed: " + NameToString(reason) + ", " + how + " after " + IntToString(this.m_attempts) + " polls");
    this.m_moved = null;
    this.m_movedOld = false;
    this.m_wroteFlat = false;
  }

  public func OnTimeout(e: ref<XUtilsEvent>) -> Void {
    this.m_timeoutTimer = 0ul;
    this.Finish(n"timeout");
  }

  private func CancelTimers() -> Void {
    if this.m_spawnTimer != 0ul { this.m_xu.Cancel(this.m_spawnTimer); }
    if this.m_pollTimer != 0ul { this.m_xu.Cancel(this.m_pollTimer); }
    if this.m_settleTimer != 0ul { this.m_xu.Cancel(this.m_settleTimer); }
    if this.m_timeoutTimer != 0ul { this.m_xu.Cancel(this.m_timeoutTimer); }
    this.m_spawnTimer = 0ul;
    this.m_pollTimer = 0ul;
    this.m_settleTimer = 0ul;
    this.m_timeoutTimer = 0ul;
  }

  private func Finish(reason: CName) -> Void {
    if !this.m_active { return; }
    this.m_active = false;
    this.CancelTimers();
    if this.m_summonToggled { GameInstance.GetVehicleSystem(GetGameInstance()).ToggleSummonMode(); }
    this.m_summonToggled = false;
    if IsNameValid(reason) { this.Recover(reason); }
    let listener: ref<GarageSwapListener> = this.m_listener;
    let car: wref<VehicleObject> = this.m_car;
    this.m_listener = IsDefined(this.m_fade) ? listener : null;
    if IsDefined(listener) { listener.OnResult(reason, IsNameValid(reason) ? null : car); }
    if IsDefined(this.m_fade) {
      this.m_fadeReason = reason;
      this.m_fade.Release();
    }
  }

  /// The Repair and Swap pattern: fade out, do the work behind black, fade back in once the car's landed.
  /// With an invalid record it runs listener.InPlace instead of respawning.
  /// False, with nothing run, if another swap or fade holds the screen.
  public func BehindFade(options: ref<XUtilsFadeOptions>, record: TweakDBID, appearance: CName, spot: ref<GarageSpot>, old: wref<GameObject>, listener: ref<GarageSwapListener>) -> Bool {
    if !this.CanStart() { return false; }
    this.m_listener = listener;
    this.m_record = record;
    this.m_spot = spot;
    this.m_oldCar = old;
    this.m_appearance = appearance;
    // Stands until something reports, so a black that runs out counts as a failure
    this.m_fadeReason = n"timeout";
    this.m_fade = this.m_xu.Screen().Fade(options);
    this.m_fade.On(XUtilsEventType.FadedOut, this, n"OnBlack");
    this.m_fade.On(XUtilsEventType.FadeCleared, this, n"OnCleared");
    this.m_fade.Start();
    return true;
  }

  public func OnBlack(e: ref<XUtilsEvent>) -> Void {
    let listener: ref<GarageSwapListener> = this.m_listener;
    if !IsDefined(listener) { return; }
    listener.OnBlack();
    if TDBID.IsValid(this.m_record) {
      let old: wref<GameObject> = this.m_oldCar;
      if !this.Begin(this.m_record, this.m_appearance, this.m_spot, old, listener) {
        this.m_fadeReason = n"bad_args";
        this.m_fade.Release();
      }
      return;
    }
    let reason: CName = listener.InPlace();
    this.m_fadeReason = reason;
    listener.OnResult(reason, null);
    this.m_fade.Release();
  }

  public func OnCleared(e: ref<XUtilsEvent>) -> Void {
    let listener: ref<GarageSwapListener> = this.m_listener;
    let reason: CName = this.m_fadeReason;
    this.m_fade.Destroy();
    this.m_fade = null;
    this.m_listener = null;
    if IsDefined(listener) { listener.OnClear(reason, e.flag); }
    let i: Int32 = 0;
    while i < ArraySize(this.m_afterFade) {
      this.m_xu.Screen().Notify(this.m_afterFade[i], this.m_afterFadeKinds[i], this.m_afterFadeSeconds[i], false);
      i += 1;
    }
    ArrayClear(this.m_afterFade);
    ArrayClear(this.m_afterFadeKinds);
    ArrayClear(this.m_afterFadeSeconds);
  }

  /// A banner, held back until any swap's fade is over so behind-black work reports after the fade-in.
  public func NotifyWhenClear(text: String, kind: SimpleMessageType, seconds: Float) -> Void {
    if !IsDefined(this.m_fade) {
      this.m_xu.Screen().Notify(text, kind, seconds, false);
      return;
    }
    ArrayPush(this.m_afterFade, text);
    ArrayPush(this.m_afterFadeKinds, kind);
    ArrayPush(this.m_afterFadeSeconds, seconds);
  }

  /// Gives up on the running swap. It reports n"cancelled" like any other failure, and the car comes back as on any failure.
  public func Cancel() -> Void { this.Finish(n"cancelled"); }

  /// Session end: stops polling and puts summon mode back. The listener never gets OnClear.
  public func Abort() -> Void {
    this.Finish(n"aborted");
    if IsDefined(this.m_fade) { this.m_fade.Destroy(); }
    this.m_fade = null;
    this.m_listener = null;
    ArrayClear(this.m_afterFade);
    ArrayClear(this.m_afterFadeKinds);
    ArrayClear(this.m_afterFadeSeconds);
  }
}

/// The banners a finished service posts. The exit summary only counts parts, so a service reports itself here.
public abstract class GarageServiceNotify {
  /// title is already localized, detail shows after it if there is one. amount above 0 shows as the price paid.
  public static func Post(title: String, opt detail: String, opt amount: Int32, opt kind: SimpleMessageType, opt seconds: Float) -> Void {
    if StrLen(title) == 0 { return; }
    let label: String = StrLen(detail) > 0 ? GarageText.Format(n"Garage-Notify-ServiceDetail", [title, detail]) : title;
    let message: String = amount > 0 ? GarageText.Format(n"Garage-Notify-ServiceDone", [label, GarageText.Price(amount)]) : label;
    let system: ref<GarageSystem> = GarageSystem.Get();
    let use: SimpleMessageType = Equals(kind, SimpleMessageType.Undefined) ? SimpleMessageType.Money : kind;
    if IsDefined(system) { system.Swap().NotifyWhenClear(message, use, seconds > 0.0 ? seconds : 4.0); }
  }
}
