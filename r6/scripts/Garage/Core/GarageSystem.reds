module Garage

import Garage.Data.*
import Garage.Economy.*
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
  private let m_requester: wref<inkGameController>;
  private let m_garageOpen: Bool;
  private let m_closeRequested: Bool;
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

  /// A service that's finished and wants the garage shut.
  public func RequestClose() -> Void { this.m_closeRequested = true; }

  public func TakeCloseRequest() -> Bool {
    let was: Bool = this.m_closeRequested;
    this.m_closeRequested = false;
    return was;
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
    this.m_closeRequested = false;
    this.m_visited = true;
    this.m_world.SetGarageOpen(true);
    this.m_panel.Show(location);
    this.m_xu.Hold(XUtilsHold.HideHud, "garage");
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
  }

  public func OnGarageClose(location: ref<GarageLocation>) -> Void {
    this.m_garageOpen = false;
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
  }

  public func Swap() -> ref<GarageEntitySwap> { return this.m_swap; }

  public func Appearances() -> ref<GarageAppearances> { return this.m_appearances; }

  public func EconomyPanel() -> ref<GarageEconomyPanel> { return this.m_panel; }

  public func ClaimTimer() -> ref<GarageClaimTimer> { return this.m_claim; }

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
    this.m_data.Reload();
    this.m_pricing.Reload();
    this.m_data.LogContents();
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if IsDefined(engine) { engine.Start(this.m_xu, this.m_data); }
    this.m_world.Start(this.m_data);
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
    this.m_visited = false;
    this.m_garageOpen = false;
    this.m_parts.End();
    this.m_swap.Abort();
    this.m_appearances.ClearCache();
    this.m_panel.Hide();
    this.m_claim.Stop();
    this.m_sales.Stop();
    this.m_world.Stop();
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if IsDefined(engine) { engine.Stop(); }
    this.SyncAddons();
  }

  public func OnSettingsChanged() -> Void { this.ApplySettings(); }

  public func OnLocationSaved(id: CName, isUpdate: Bool, source: String) -> Void {
    let location: ref<GarageLocation> = this.m_data.GetLocation(id);
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if IsDefined(engine) && IsDefined(location) { engine.InitGarage(id, location.economy); }
    if this.m_inSession { this.m_world.OnLocationSaved(id, this.m_data); }
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
      let categories: array<String> = ["Core", "Data", "World", "Economy", "Door"];
      for category in categories { this.m_xu.Log(category).SetLevel(level); }
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

  // Read and clear in one call, so a visit only triggers one reload
  public func TakeVisited() -> Bool {
    let was: Bool = this.m_visited;
    this.m_visited = false;
    return was;
  }
}
