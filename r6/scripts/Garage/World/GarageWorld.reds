module Garage.World

import Garage.*
import Garage.Data.*
import Garage.Economy.*

/// One garage's rings and where V is in them. Get one with GarageSystem.Get().World().Site(id), for the radii as they were
/// resolved. No watcher means it's retired: banned, with V outside.
public class GarageSite extends IScriptable {
  public let location: ref<GarageLocation>;
  public let enter: Float;
  public let exit: Float;
  public let service: Float;
  public let arrival: Float;
  public let hasDoor: Bool;
  public let watcher: ref<XUtilsWatcher>;
  public let zone: Int32;
  // Enter has gone out and Leave hasn't yet
  public let announced: Bool;
  private let m_world: wref<GarageWorld>;

  public static func Make(world: ref<GarageWorld>, location: ref<GarageLocation>, log: ref<XUtilsLog>) -> ref<GarageSite> {
    let site: ref<GarageSite> = new GarageSite();
    site.m_world = world;
    site.location = location;
    let door: ref<GarageDoor> = location.door;
    site.hasDoor = IsDefined(door) && (StrLen(door.nodeRef) > 0 || StrLen(door.entityHash) > 0);
    site.Radii(log);
    return site;
  }

  private func Radii(log: ref<XUtilsLog>) -> Void {
    let zone: ref<GarageZone> = this.location.zone;
    let name: String = NameToString(this.location.id);
    this.enter = zone.enter;
    this.exit = zone.exit;
    this.service = MaxF(zone.service > 0.0 ? zone.service : this.exit * 0.8, 2.0);
    this.arrival = zone.arrival > 0.0 ? zone.arrival : 2.0;
    if this.service >= this.exit {
      let clamped: Float = MaxF(this.exit - 1.0, 2.0);
      log.Warn(s"clamped the service radius of \(name): \(this.service) to \(clamped)");
      this.service = clamped;
    }
    if this.hasDoor && this.exit >= this.enter {
      let clamped: Float = MaxF(this.enter - 1.0, this.service + 1.0);
      log.Warn(s"clamped the exit radius of \(name): \(this.exit) to \(clamped)");
      this.exit = clamped;
    }
    // XU merges rings of the same radius, and every zone number after them would shift
    if this.service <= this.arrival { this.service = this.arrival + 0.1; }
    if this.exit <= this.service { this.exit = this.service + 0.1; }
    if this.enter <= this.exit { this.enter = this.exit + 0.1; }
  }

  public func Start(xu: ref<XUtilsMod>) -> Void {
    this.zone = 0;
    let deck: Vector4 = this.location.deck.Position();
    let zones: ref<XUtilsZones> = XUtilsZones.At(deck).Flat(true).Ring(this.enter).Ring(this.exit).Ring(this.service).Ring(this.arrival);
    this.watcher = xu.World().Watch(zones, XUtilsWatchOptions.Create().Interval(0.5));
    this.watcher.On(XUtilsEventType.ZoneEnter, this, n"OnZoneEnter");
    this.watcher.On(XUtilsEventType.ZoneExit, this, n"OnZoneExit");
  }

  public func Stop() -> Void {
    if !IsDefined(this.watcher) { return; }
    this.watcher.Destroy();
    this.watcher = null;
    this.zone = 0;
  }

  // Ring 0 is the outermost. A door counts 0 as outside them all
  public func OnZoneEnter(e: ref<XUtilsEvent>) -> Void {
    let world: ref<GarageWorld> = this.m_world;
    if IsDefined(world) { world.OnSiteZone(this, e.index + 1); }
  }

  public func OnZoneExit(e: ref<XUtilsEvent>) -> Void {
    let world: ref<GarageWorld> = this.m_world;
    if IsDefined(world) { world.OnSiteZone(this, e.index); }
  }
}

/// The world around the garages: rings, doors, the enter prompt and the distance readout. No per-frame script.
public class GarageWorld extends IScriptable {
  private let m_xu: ref<XUtilsMod>;
  private let m_log: ref<XUtilsLog>;
  private let m_sites: array<ref<GarageSite>>;
  private let m_active: ref<GarageSite>;
  private let m_press: ref<XUtilsLongPress>;
  private let m_hints: ref<XUtilsHints>;
  private let m_readout: ref<XUtilsDistance>;
  // Got into a car inside the service ring: nothing to guide, so no readout until the ring's left
  private let m_quiet: Bool;
  private let m_wasInVehicle: Bool;
  private let m_listening: Bool;
  private let m_pins: ref<GarageMapPins>;
  private let m_garageOpen: Bool;

  public func Setup(xu: ref<XUtilsMod>) -> Void {
    this.m_xu = xu;
    this.m_log = xu.Log("World");
    this.m_pins = new GarageMapPins();
  }

  public func Pins() -> ref<GarageMapPins> { return this.m_pins; }

  /// The prompt and readout are off while the garage's open. Doors get checked on the way out, when someone's about to use one.
  public func SetGarageOpen(open: Bool) -> Void {
    this.m_garageOpen = open;
    if !open { this.ReassertDoors(); }
    this.Refresh();
  }

  /// Null for a garage with zone.events off, or none by that id.
  public func Site(id: CName) -> ref<GarageSite> {
    for site in this.m_sites {
      if Equals(site.location.id, id) { return site; }
    }
    return null;
  }

  public func Start(data: ref<GarageData>) -> Void {
    this.Stop();
    let state: ref<XUtilsState> = this.m_xu.State();
    this.m_wasInVehicle = state.Is(XUtilsStateField.IsInVehicle);
    if !this.m_listening {
      this.m_listening = true;
      state.OnFields([XUtilsStateField.IsInVehicle, XUtilsStateField.IsCar, XUtilsStateField.VehicleExiting], this, n"OnVehicleState");
    }
    if !IsDefined(this.m_press) {
      this.m_press = this.m_xu.Input().LongPress(XUtilsPress.Action(n"Garage_Enter").Seconds(0.5));
      this.m_press.On(XUtilsEventType.PressComplete, this, n"OnEnterPressed");
      this.m_hints = this.m_xu.Screen().Hints(n"garage_enter").Hold(this.m_press, GarageText.Get(n"Garage-Prompt-Enter"));
    }
    let locations: array<ref<GarageLocation>> = data.GetLocations();
    for location in locations {
      if location.zone.events { this.AddSite(location); }
    }
    this.m_pins.Start(this.m_xu, locations);
    this.m_log.Debug(IntToString(ArraySize(this.m_sites)) + " garages watched");
  }

  public func Stop() -> Void {
    this.m_garageOpen = false;
    for site in this.m_sites { site.Stop(); }
    ArrayClear(this.m_sites);
    this.SetActive(null);
    this.Refresh();
    this.m_pins.Stop();
  }

  // A banned garage isn't watched, unless V loaded in inside it. Then the door lets them out and it retires on the way out
  private func AddSite(location: ref<GarageLocation>) -> ref<GarageSite> {
    let doors: ref<DoorController> = DoorController.Get();
    let site: ref<GarageSite> = GarageSite.Make(this, location, this.m_log);
    ArrayPush(this.m_sites, site);
    if site.hasDoor && IsDefined(doors) { doors.RegisterLocationDoor(location.id, location.door.nodeRef, location.door.entityHash); }
    if !GarageLocks.IsBanned(location.id) {
      site.Start(this.m_xu);
      return site;
    }
    if this.IsWithinExit(site) {
      if site.hasDoor && IsDefined(doors) { doors.LetOut(location.id); }
      site.Start(this.m_xu);
    } else {
      if site.hasDoor && IsDefined(doors) { doors.OnBanChanged(location.id); }
    }
    return site;
  }

  private func IsWithinExit(site: ref<GarageSite>) -> Bool {
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    if !IsDefined(player) { return false; }
    let at: Vector4 = player.GetWorldPosition();
    let dx: Float = at.X - site.location.deck.x;
    let dy: Float = at.Y - site.location.deck.y;
    return dx * dx + dy * dy < site.exit * site.exit;
  }

  /// A save or import changed this garage: only its rings restart, so V's place in the others stands.
  public func OnLocationSaved(id: CName, data: ref<GarageData>) -> Void {
    for site in this.m_sites {
      let fresh: ref<GarageLocation> = data.GetLocation(site.location.id);
      if IsDefined(fresh) { site.location = fresh; }
    }
    let old: ref<GarageSite> = this.Site(id);
    if IsDefined(old) {
      old.Stop();
      ArrayRemove(this.m_sites, old);
    }
    let location: ref<GarageLocation> = data.GetLocation(id);
    let site: ref<GarageSite> = IsDefined(location) && location.zone.events ? this.AddSite(location) : null;
    // A save isn't V walking off. Leave only goes out if the new rings can't send it later
    if IsDefined(old) && old.announced {
      if IsDefined(site) && IsDefined(site.watcher) {
        site.announced = true;
      } else {
        this.Tell(GarageEvents.ProximityLeave(), old);
      }
    }
    this.m_pins.Start(this.m_xu, data.GetLocations());
    this.Update();
  }

  /// The ban on this garage changed, from the economy or a console.
  public func OnBanChanged(id: CName) -> Void {
    let site: ref<GarageSite> = this.Site(id);
    let doors: ref<DoorController> = DoorController.Get();
    if GarageLocks.IsBanned(id) {
      if IsDefined(site) && site.zone < 2 { this.Retire(site); }
    } else {
      if IsDefined(site) && !IsDefined(site.watcher) {
        // The door's last zone went stale while retired. From outside, the next approach opens it
        if site.hasDoor && IsDefined(doors) { doors.OnZoneChanged(id, 0); }
        site.Start(this.m_xu);
        this.m_log.Debug("revived " + NameToString(id));
      }
    }
    if IsDefined(doors) { doors.OnBanChanged(id); }
    this.Update();
  }

  private func Retire(site: ref<GarageSite>) -> Void {
    if !IsDefined(site.watcher) { return; }
    if site.announced {
      site.announced = false;
      this.Tell(GarageEvents.ProximityLeave(), site);
    }
    site.Stop();
    this.m_log.Debug("retired " + NameToString(site.location.id));
  }

  // zone: 0 outside, 1 enter ring, 2 exit, 3 service, 4 arrival
  public func OnSiteZone(site: ref<GarageSite>, zone: Int32) -> Void {
    // Rings crossed in one tick keep coming after a retire
    if !IsDefined(site.watcher) { return; }
    let was: Int32 = site.zone;
    site.zone = zone;
    let id: CName = site.location.id;
    this.m_log.Debug(NameToString(id) + " zone " + IntToString(was) + " to " + IntToString(zone));
    // Door first: a theft ban fires from Leave and has to find V outside already
    if site.hasDoor {
      let doors: ref<DoorController> = DoorController.Get();
      if IsDefined(doors) { doors.OnZoneChanged(id, zone); }
    }
    this.Announce(site, was, zone);
    // Rings come in one at a time after a load, so V passes zone 1 on the way in. Only going out counts
    if zone < was && zone < 2 && GarageLocks.IsBanned(id) { this.Retire(site); }
    this.Update();
  }

  // Door garages say hello at the enter ring, but V's only gone once past the door. Turning back short of the door
  // leaves at the enter ring instead, so every Enter gets its Leave
  private func Announce(site: ref<GarageSite>, was: Int32, zone: Int32) -> Void {
    if !site.announced && zone > was && zone >= (site.hasDoor ? 1 : 2) {
      site.announced = true;
      this.Tell(GarageEvents.ProximityEnter(), site);
    }
    if site.announced && zone < was && (zone == 0 || (was >= 2 && zone < 2)) {
      site.announced = false;
      this.Tell(GarageEvents.ProximityLeave(), site);
    }
  }

  private func Tell(event: CName, site: ref<GarageSite>) -> Void {
    let data: ref<GarageEventData> = new GarageEventData();
    data.garageId = site.location.id;
    data.garageName = site.location.name;
    this.m_xu.Emit(event, data);
  }

  // Service rings can overlap, and the closest deck is the one V means
  private func PickActive() -> ref<GarageSite> {
    let best: ref<GarageSite>;
    let bestDistance: Float = 0.0;
    for site in this.m_sites {
      if site.zone >= 3 && IsDefined(site.watcher) {
        let distance: Float = site.watcher.GetDistance();
        if !IsDefined(best) || distance < bestDistance {
          best = site;
          bestDistance = distance;
        }
      }
    }
    return best;
  }

  private func SetActive(site: ref<GarageSite>) -> Void {
    if this.m_active == site { return; }
    this.HideReadout();
    this.m_active = site;
    this.m_quiet = false;
  }

  private func Update() -> Void {
    this.SetActive(this.PickActive());
    this.Refresh();
  }

  public func OnVehicleState(e: ref<XUtilsEvent>) -> Void {
    let state: ref<XUtilsState> = this.m_xu.State();
    let inVehicle: Bool = state.Is(XUtilsStateField.IsInVehicle);
    if IsDefined(this.m_active) && ((inVehicle && !this.m_wasInVehicle) || state.Is(XUtilsStateField.VehicleExiting)) { this.m_quiet = true; }
    if !inVehicle && this.m_wasInVehicle { this.ReassertDoors(); }
    this.m_wasInVehicle = inVehicle;
    this.Refresh();
  }

  /// Getting out and closing the popup are when someone inside heads for the door.
  public func ReassertDoors() -> Void {
    let doors: ref<DoorController> = DoorController.Get();
    if !IsDefined(doors) { return; }
    for site in this.m_sites {
      if site.hasDoor { doors.Reassert(site.location.id); }
    }
  }

  private func Refresh() -> Void {
    let state: ref<XUtilsState> = this.m_xu.State();
    let open: Bool = IsDefined(this.m_active) && !this.m_garageOpen && !GarageLocks.IsBanned(this.m_active.location.id);
    let prompt: Bool = open && !state.Is(XUtilsStateField.IsInVehicle);
    if IsDefined(this.m_press) {
      if prompt && !this.m_press.IsArmed() {
        this.m_log.Debug("enter prompt on at " + NameToString(this.m_active.location.id));
        this.m_press.Arm();
        this.m_hints.Show();
      }
      if !prompt && this.m_press.IsArmed() {
        this.m_log.Debug("enter prompt off");
        this.m_press.Disarm();
        this.m_hints.Hide();
      }
    }
    if open && state.Is(XUtilsStateField.IsCar) && !this.m_quiet {
      this.ShowReadout();
    } else {
      this.HideReadout();
    }
  }

  private func ShowReadout() -> Void {
    if IsDefined(this.m_readout) { return; }
    let options: ref<XUtilsDistanceOptions> = XUtilsDistanceOptions.Create().FromWatcher(this.m_active.watcher).Decimals(1)
      .Text(XUtilsTextStyle.Create().Size(72.0))
      .Near(this.m_active.arrival, new HDRColor(0.158, 1.303, 1.414, 1.0), GarageText.Get(n"Garage-HUD-ExitVehicle"));
    this.m_readout = this.m_xu.Screen().Distance(options);
    this.m_readout.Show();
  }

  private func HideReadout() -> Void {
    if !IsDefined(this.m_readout) { return; }
    this.m_readout.Hide(0.3);
    this.m_readout = null;
  }

  public func OnEnterPressed(e: ref<XUtilsEvent>) -> Void {
    if this.m_xu.State().IsCameraActive() { return; }
    let site: ref<GarageSite> = this.PickActive();
    if IsDefined(site) { GarageEntry.Try(this.m_xu, site); }
  }
}
