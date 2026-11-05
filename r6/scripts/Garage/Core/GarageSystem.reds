module Garage

import VehicleCore.Schema.*
import Garage.Audio.*
import Garage.Data.*
import Garage.Economy.*
import Garage.Scene.*
import Garage.Services.*
import Garage.UI.*
import Garage.Vehicle.*
import Garage.World.*

// A service, so it outlives every load and session events start and stop the addons
public class GarageSystem extends ScriptableService {
  private let m_xu: ref<XUtilsMod>;
  private let m_log: ref<XUtilsLog>;
  private let m_data: ref<GarageData>;
  private let m_world: ref<GarageWorld>;
  private let m_sales: ref<GarageSales>;
  private let m_pricing: ref<GaragePricing>;
  private let m_parts: ref<GarageParts>;
  private let m_swap: ref<GarageEntitySwap>;
  private let m_appearances: ref<GarageAppearances>;
  private let m_panel: ref<GarageEconomyPanel>;
  private let m_claim: ref<GarageClaimTimer>;
  private let m_scene: ref<GarageScene>;
  private let m_requester: wref<inkGameController>;
  private let m_garageOpen: Bool;
  private let m_popup: wref<GaragePopup>;
  private let m_visitLive: Bool;
  private let m_addons: array<ref<GarageAddon>>;
  private let m_started: array<Bool>;
  private let m_services: array<ref<GarageService>>;
  private let m_inSession: Bool;
  private let m_said: Bool;
  private let m_visited: Bool;

  public static func Get() -> ref<GarageSystem> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"Garage.GarageSystem") as GarageSystem;
  }

  private cb func OnInitialize() {
    this.m_xu = XUtils.Mod("Garage");
    this.m_log = this.m_xu.Log("Core");
    this.m_data = new GarageData();
    this.m_data.Setup(this.m_xu);
    this.m_world = new GarageWorld();
    this.m_world.Setup(this.m_xu);
    this.m_sales = new GarageSales();
    this.m_sales.Setup(this.m_xu);
    this.m_pricing = new GaragePricing();
    this.m_pricing.Setup(this.m_xu);
    this.m_parts = new GarageParts();
    this.m_swap = new GarageEntitySwap();
    this.m_swap.Setup(this.m_xu);
    this.m_appearances = new GarageAppearances();
    this.m_appearances.Setup(this.m_xu);
    this.m_panel = new GarageEconomyPanel();
    this.m_panel.Setup(this.m_xu);
    this.m_claim = new GarageClaimTimer();
    this.m_claim.Setup(this.m_xu);
    this.m_scene = new GarageScene();
    this.m_scene.Setup(this.m_xu);
    this.m_xu.OnCustom(GarageEvents.Transaction(), this, n"OnTransaction");
    this.FindAddons();
    this.m_xu.On(XUtilsEventType.PlayerReady, this, n"OnPlayerReady");
    this.m_xu.On(XUtilsEventType.SessionEnd, this, n"OnSessionEnd");
    this.m_xu.OnCustom(GarageEvents.ProximityEnter(), this, n"OnProximityEnter");
    this.m_xu.OnCustom(GarageEvents.ProximityLeave(), this, n"OnProximityLeave");
  }

  public func OnProximityEnter(e: ref<XUtilsEvent>) -> Void {
    let data: ref<GarageEventData> = e.data as GarageEventData;
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if IsDefined(data) && IsDefined(engine) { engine.PauseActivity(data.garageId); }
  }

  public func OnProximityLeave(e: ref<XUtilsEvent>) -> Void {
    let data: ref<GarageEventData> = e.data as GarageEventData;
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if IsDefined(data) && IsDefined(engine) { engine.ResumeActivity(data.garageId); }
  }

  public func Xu() -> ref<XUtilsMod> { return this.m_xu; }

  public func Log() -> ref<XUtilsLog> { return this.m_log; }

  public func Data() -> ref<GarageData> { return this.m_data; }

  public func World() -> ref<GarageWorld> { return this.m_world; }

  public func Sales() -> ref<GarageSales> { return this.m_sales; }

  public func Pricing() -> ref<GaragePricing> { return this.m_pricing; }

  public func Parts() -> ref<GarageParts> { return this.m_parts; }

  public func Requester() -> wref<inkGameController> { return this.m_requester; }

  public func SetRequester(requester: wref<inkGameController>) -> Void { this.m_requester = requester; }

  public func IsGarageOpen() -> Bool { return this.m_garageOpen; }

  /// Shuts the popup now, cart or no cart. For a service that's finished, or whose work carries on behind it.
  public func RequestClose() -> Void {
    let popup: ref<GaragePopup> = this.m_popup;
    if IsDefined(popup) { popup.ForceClose(); }
  }

  public func SetPopup(popup: ref<GaragePopup>) -> Void { this.m_popup = popup; }

  /// Redraws the hub if it's showing, for when a service's state changed under it.
  public func RefreshHub() -> Void {
    let popup: ref<GaragePopup> = this.m_popup;
    if IsDefined(popup) { popup.RefreshHub(); }
  }

  /// That addon, or null if nothing has that id. It can be off, IsAddonUp says.
  public func Addon(id: CName) -> ref<GarageAddon> {
    for addon in this.m_addons {
      if Equals(addon.Id(), id) { return addon; }
    }
    return null;
  }

  /// True while that addon's enabled and running.
  public func IsAddonUp(id: CName) -> Bool {
    let i: Int32 = 0;
    while i < ArraySize(this.m_addons) {
      if this.m_started[i] && Equals(this.m_addons[i].Id(), id) { return true; }
      i += 1;
    }
    return false;
  }

  public func RegisterScreens(screens: ref<ScreenManager>, frame: ref<GarageFrame>) -> Void {
    let i: Int32 = 0;
    while i < ArraySize(this.m_addons) {
      if this.m_started[i] { this.m_addons[i].RegisterScreens(screens, frame); }
      i += 1;
    }
  }

  public func OnGarageOpen(location: ref<GarageLocation>, vehicle: wref<VehicleObject>) -> Void {
    this.m_garageOpen = true;
    this.m_visited = true;
    this.m_world.SetGarageOpen(true);
    this.m_panel.Show(location);
    this.m_xu.Hold(XUtilsHold.HideHud, "garage");
    this.m_scene.Open(location, vehicle, this.m_parts.Schema());
    let context: ref<GarageContext> = this.m_parts.Context();
    let data: ref<GarageVisitData> = new GarageVisitData();
    data.garageId = location.id;
    data.garageName = location.name;
    data.vehicle = vehicle;
    data.vehicleRecord = context.vehicleRecord;
    data.vehicleDisplayName = context.vehicleDisplayName;
    data.tier = location.economy.tier;
    data.hasSchema = context.hasSchema;
    this.m_xu.Emit(GarageEvents.GarageOpen(), data);
    if IsDefined(vehicle) {
      this.m_xu.Emit(GarageEvents.EntityResolved(), data);
      this.m_xu.Emit(GarageEvents.HealthQueryable(), data);
    }
    this.m_visitLive = true;
    let i: Int32 = 0;
    while i < ArraySize(this.m_addons) {
      if this.m_started[i] { this.m_addons[i].OnVisitStart(context); }
      i += 1;
    }
  }

  public func EndVisit() -> Void {
    if !this.m_visitLive { return; }
    this.m_visitLive = false;
    let context: ref<GarageContext> = this.m_parts.Context();
    let i: Int32 = 0;
    while i < ArraySize(this.m_addons) {
      if this.m_started[i] { this.m_addons[i].OnVisitEnd(context); }
      i += 1;
    }
  }

  public func OnGarageClose(location: ref<GarageLocation>) -> Void {
    this.m_garageOpen = false;
    this.m_popup = null;
    this.m_scene.Close();
    this.m_xu.Release(XUtilsHold.HideHud);
    this.m_appearances.ClearCache();
    this.m_panel.Hide();
    this.m_parts.PostExitSummary();
    this.m_parts.End();
    this.m_world.SetGarageOpen(false);
    let data: ref<GarageEventData> = new GarageEventData();
    data.garageId = location.id;
    data.garageName = location.name;
    this.m_xu.Emit(GarageEvents.GarageClose(), data);
    this.SyncAddons();
  }

  public func Swap() -> ref<GarageEntitySwap> { return this.m_swap; }

  public func Repairs() -> ref<GarageRepairLedger> { return GarageRepairLedger.Get(); }

  public func Appearances() -> ref<GarageAppearances> { return this.m_appearances; }

  public func EconomyPanel() -> ref<GarageEconomyPanel> { return this.m_panel; }

  public func ClaimTimer() -> ref<GarageClaimTimer> { return this.m_claim; }

  public func Scene() -> ref<GarageScene> { return this.m_scene; }

  public func OnTransaction(e: ref<XUtilsEvent>) -> Void {
    let data: ref<GarageTransactionData> = e.data as GarageTransactionData;
    if IsDefined(data) { this.m_parts.OnTransaction(data); }
  }

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
    // OnSessionEnd put the game's own flats back, so this save's looks go on top
    let looks: Int32 = GaragePaint.ReapplyAll();
    if looks > 0 {
      GaragePaint.RefreshNearby();
      this.m_xu.Log("Vehicle").Info("re-applied " + IntToString(looks) + " saved looks");
    }
    this.m_data.Reload();
    this.m_pricing.Reload();
    this.m_data.LogContents();
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if IsDefined(engine) { engine.Start(this.m_xu, this.m_data); }
    this.m_world.Start(this.m_data);
    GarageMusic.Start(this.m_xu, this.m_data);
    this.m_log.Info("Garage up: " + IntToString(ArraySize(this.m_addons)) + " addons, " + IntToString(this.m_data.LocationCount()) + " garages ("
                    + IntToString(this.m_data.UserLocationCount()) + " user's, " + IntToString(this.m_data.BrokenCount()) + " broken), "
                    + IntToString(this.m_data.BoxCount()) + " boxes");
    if !this.m_said {
      this.m_said = true;
      this.m_log.Info("hub title reads \"" + GarageText.Get(n"Garage-Hub-Title") + "\", a Type-66 variant's box by model " + ToString(IsDefined(this.m_data.GetBox(t"Vehicle.v_sport2_quadra_type66_player"))));
    }
  }

  // XU has already dropped the mod's holds, watchers and spawns by now
  public func OnSessionEnd(e: ref<XUtilsEvent>) -> Void {
    this.m_inSession = false;
    let popup: ref<GaragePopup> = this.m_popup;
    if IsDefined(popup) { popup.Abandon(); }
    this.m_popup = null;
    this.EndVisit();
    this.m_visited = false;
    this.m_garageOpen = false;
    this.m_parts.End();
    this.m_scene.Close();
    this.m_swap.Abort();
    this.m_appearances.ClearCache();
    this.m_panel.Hide();
    this.m_claim.Stop();
    this.m_sales.Stop();
    this.m_world.Stop();
    GarageMusic.Stop();
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if IsDefined(engine) { engine.Stop(); }
    this.SyncAddons();
  }

  public func OnSettingsChanged() -> Void {
    this.ApplySettings();
    if this.m_garageOpen { this.m_scene.ApplyLens(); }
  }

  public func OnLocationSaved(id: CName, isUpdate: Bool, source: String) -> Void {
    let location: ref<GarageLocation> = this.m_data.GetLocation(id);
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if IsDefined(engine) && IsDefined(location) { engine.InitGarage(id, location.economy); }
    if this.m_inSession {
      this.m_world.OnLocationSaved(id, this.m_data);
      GarageMusic.LocationSaved(id, this.m_data);
    }
    let data: ref<GarageImportData> = new GarageImportData();
    data.garageId = id;
    data.garageName = IsDefined(location) ? location.name : "";
    data.source = source;
    data.isUpdate = isUpdate;
    this.m_xu.Emit(GarageEvents.LocationImported(), data);
  }

  private func ApplySettings() -> Void {
    let settings: ref<GarageSettings> = GarageSettings.Get();
    if IsDefined(settings) {
      let level: XUtilsLogLevel = settings.debugLogging ? XUtilsLogLevel.Debug : XUtilsLogLevel.Info;
      let categories: array<String> = ["Core", "Data", "World", "Economy", "Door", "Scene", "UI", "Vehicle", "Audio"];
      for category in categories { this.m_xu.Log(category).SetLevel(level); }
    }
    this.SyncAddons();
  }

  private func SyncAddons() -> Void {
    // Toggles wait for the close: the screens are built, and whoever's started still needs OnVisitEnd
    if this.m_garageOpen { return; }
    let settings: ref<GarageSettings> = GarageSettings.Get();
    let changed: Bool = false;
    let i: Int32 = 0;
    while i < ArraySize(this.m_addons) {
      let addon: ref<GarageAddon> = this.m_addons[i];
      let wanted: Bool = this.m_inSession && IsDefined(settings) && addon.IsEnabled(settings);
      if wanted && !this.m_started[i] {
        this.m_started[i] = true;
        addon.Start(this);
        changed = true;
        this.m_log.Info("started " + NameToString(addon.Id()));
      }
      if !wanted && this.m_started[i] {
        this.m_started[i] = false;
        addon.Stop();
        changed = true;
        this.m_log.Info("stopped " + NameToString(addon.Id()));
      }
      i += 1;
    }
    if changed { this.CollectServices(); }
  }

  // Only what started addons bring, so an addon that's off leaves nothing in the hub. Priority order, stable for equal ones
  private func CollectServices() -> Void {
    ArrayClear(this.m_services);
    let i: Int32 = 0;
    while i < ArraySize(this.m_addons) {
      if this.m_started[i] {
        let services: array<ref<GarageService>> = this.m_addons[i].Services();
        for service in services {
          let at: Int32 = 0;
          while at < ArraySize(this.m_services) && this.m_services[at].Priority() <= service.Priority() { at += 1; }
          ArrayInsert(this.m_services, at, service);
        }
      }
      i += 1;
    }
  }

  public func Services() -> array<ref<GarageService>> { return this.m_services; }

  // Read and clear in one call, so a visit only triggers one reload
  public func TakeVisited() -> Bool {
    let was: Bool = this.m_visited;
    this.m_visited = false;
    return was;
  }
}
