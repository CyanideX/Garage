module Garage.Vehicle

import Garage.*
import Garage.Data.*

/// What a swap reports back. reason is n"" when it worked, otherwise busy, bad_args, timeout, lost, wrong_look, cancelled or aborted.
public abstract class GarageSwapListener extends IScriptable {
  /// First thing behind the black, for closing a popup.
  public func OnBlack() -> Void {}
  /// With no respawn asked for, the work to do behind the black. Return a reason if it failed.
  public func InPlace() -> CName { return n""; }
  /// Still black, or just done if there's no fade. car is the fresh one if it got spawned, even on a failure, since it's V's car now.
  public func OnResult(reason: CName, car: wref<VehicleObject>) -> Void {}
  /// The screen's back. timedOut means the black ran past its limit.
  public func OnClear(reason: CName, timedOut: Bool) -> Void {}
}

/// Replaces the player's car on the deck with a fresh copy of the same record: a new appearance, full health. One at a time.
public class GarageEntitySwap extends IScriptable {
  private let m_xu: ref<XUtilsMod>;
  private let m_log: ref<XUtilsLog>;
  private let m_summon: ref<XUtilsSummon>;
  private let m_listener: ref<GarageSwapListener>;
  private let m_record: TweakDBID;
  private let m_appearance: CName;
  private let m_spot: ref<GarageSpot>;
  private let m_old: wref<GameObject>;
  private let m_fade: ref<XUtilsFade>;
  private let m_fadeReason: CName;

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
  public func CanStart() -> Bool { return !IsDefined(this.m_summon) && !IsDefined(this.m_fade) && !this.m_xu.Vehicles().IsBusy(); }

  public func IsBusy() -> Bool { return IsDefined(this.m_summon); }

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
    let options: ref<XUtilsSummonOptions> = XUtilsSummonOptions.Record(record).At(spot.Pose()).Appearance(appearance).Replace(old)
      .Fresh(true).Instant(true).Settle(true).Seconds(GarageEntitySwap.Timeout());
    let summon: ref<XUtilsSummon> = this.m_xu.Vehicles().Summon(options);
    if !IsDefined(summon) {
      listener.OnResult(n"bad_args", null);
      return false;
    }
    this.m_summon = summon;
    this.m_listener = listener;
    this.m_record = record;
    this.m_appearance = appearance;
    summon.On(XUtilsEventType.VehicleSummoned, this, n"OnSummoned");
    summon.On(XUtilsEventType.VehicleSummonFailed, this, n"OnSummonFailed");
    return true;
  }

  public func OnSummoned(e: ref<XUtilsEvent>) -> Void {
    if !IsDefined(this.m_summon) { return; }
    let car: wref<VehicleObject> = this.m_summon.GetVehicle() as VehicleObject;
    let worn: CName = IsDefined(car) ? car.GetCurrentAppearanceName() : n"";
    // Charging for a look it didn't get would be a lie
    if IsNameValid(this.m_appearance) && !Equals(worn, this.m_appearance) {
      this.m_log.Warn((IsDefined(car) ? "fresh car settled in " + NameToString(worn) : "summon reported no car") + ", wanted " + NameToString(this.m_appearance));
      this.Finish(n"wrong_look", car);
      return;
    }
    this.Finish(n"", car);
  }

  public func OnSummonFailed(e: ref<XUtilsEvent>) -> Void {
    if IsDefined(this.m_summon) { this.Finish(StringToName(e.text), e.entity as VehicleObject); }
  }

  // The summon's already put the old car back if nothing spawned, and kept the fresh one if something did
  private func Finish(reason: CName, car: wref<VehicleObject>) -> Void {
    this.m_summon = null;
    if IsNameValid(reason) {
      this.m_log.Warn("swap failed: " + NameToString(reason) + (IsDefined(car) ? ", fresh car kept" : ""));
    }
    let listener: ref<GarageSwapListener> = this.m_listener;
    this.m_listener = IsDefined(this.m_fade) ? listener : null;
    if IsDefined(listener) { listener.OnResult(reason, car); }
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
    this.m_old = old;
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
      if !this.Begin(this.m_record, this.m_appearance, this.m_spot, this.m_old, listener) {
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
  }

  /// Gives up on the running swap. It reports n"cancelled" once the summon's let go
  public func Cancel() -> Void {
    if IsDefined(this.m_summon) { this.m_summon.Cancel(); }
  }

  /// Session end: XU's ended the summon already. The listener never gets OnClear.
  public func Abort() -> Void {
    this.m_summon = null;
    if IsDefined(this.m_fade) { this.m_fade.Destroy(); }
    this.m_fade = null;
    this.m_listener = null;
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
    if IsDefined(system) { system.Xu().Screen().Notify(message, use, seconds > 0.0 ? seconds : 4.0, false); }
  }
}
