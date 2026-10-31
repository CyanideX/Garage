module Garage

import Garage.Services.*

// A service, so it outlives every load and session events start and stop the addons
public class GarageSystem extends ScriptableService {
  private let m_xu: ref<XUtilsMod>;
  private let m_log: ref<XUtilsLog>;
  private let m_addons: array<ref<GarageAddon>>;
  private let m_started: array<Bool>;
  private let m_inSession: Bool;
  private let m_said: Bool;
  private let m_visited: Bool;

  public static func Get() -> ref<GarageSystem> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"Garage.GarageSystem") as GarageSystem;
  }

  private cb func OnInitialize() {
    this.m_xu = XUtils.Mod("Garage");
    this.m_log = this.m_xu.Log("Core");
    this.FindAddons();
    this.m_xu.On(XUtilsEventType.PlayerReady, this, n"OnPlayerReady");
    this.m_xu.On(XUtilsEventType.SessionEnd, this, n"OnSessionEnd");
  }

  public func Xu() -> ref<XUtilsMod> { return this.m_xu; }

  public func Log() -> ref<XUtilsLog> { return this.m_log; }

  // Third parties subclass GarageAddon, there's no registration call
  private func FindAddons() -> Void {
    let classes: array<ref<ReflectionClass>> = Reflection.GetDerivedClasses(n"Garage.Services.GarageAddon");
    for cls in classes {
      if !cls.IsAbstract() {
        let addon: ref<GarageAddon> = cls.MakeHandle() as GarageAddon;
        if IsDefined(addon) {
          ArrayPush(this.m_addons, addon);
          ArrayPush(this.m_started, false);
        }
      }
    }
  }

  public func OnPlayerReady(e: ref<XUtilsEvent>) -> Void {
    this.m_inSession = true;
    this.ApplySettings();
    if !this.m_said {
      this.m_said = true;
      this.m_log.Info("Garage up: " + IntToString(ArraySize(this.m_addons)) + " addons, hub title reads \"" + GarageText.Get(n"Garage-Hub-Title") + "\"");
    }
  }

  // XU has already dropped the mod's holds, watchers and spawns by now
  public func OnSessionEnd(e: ref<XUtilsEvent>) -> Void {
    this.m_inSession = false;
    this.SyncAddons();
  }

  public func OnSettingsChanged() -> Void { this.ApplySettings(); }

  private func ApplySettings() -> Void {
    let settings: ref<GarageSettings> = GarageSettings.Get();
    if IsDefined(settings) {
      this.m_log.SetLevel(settings.debugLogging ? XUtilsLogLevel.Debug : XUtilsLogLevel.Info);
    }
    this.SyncAddons();
  }

  private func SyncAddons() -> Void {
    let settings: ref<GarageSettings> = GarageSettings.Get();
    let i: Int32 = 0;
    while i < ArraySize(this.m_addons) {
      let addon: ref<GarageAddon> = this.m_addons[i];
      let wanted: Bool = this.m_inSession && IsDefined(settings) && addon.IsEnabled(settings);
      if wanted && !this.m_started[i] {
        this.m_started[i] = true;
        addon.Start(this);
        this.m_log.Info("started " + NameToString(addon.Id()));
      }
      if !wanted && this.m_started[i] {
        this.m_started[i] = false;
        addon.Stop();
        this.m_log.Info("stopped " + NameToString(addon.Id()));
      }
      i += 1;
    }
  }

  // Only what started addons bring, so an addon that's off leaves nothing in the hub
  public func Services() -> array<ref<GarageService>> {
    let out: array<ref<GarageService>>;
    let i: Int32 = 0;
    while i < ArraySize(this.m_addons) {
      if this.m_started[i] {
        let services: array<ref<GarageService>> = this.m_addons[i].Services();
        for service in services { ArrayPush(out, service); }
      }
      i += 1;
    }
    return out;
  }

  public func MarkVisited() -> Void { this.m_visited = true; }

  // Read and clear in one call, so a visit only triggers one reload
  public func TakeVisited() -> Bool {
    let was: Bool = this.m_visited;
    this.m_visited = false;
    return was;
  }
}
