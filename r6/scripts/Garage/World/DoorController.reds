module Garage.World

import Garage.Economy.*

public enum DoorState {
  Open = 0,
  Closed = 1,
  Sealed = 2,
}

public class DoorRegistration {
  public persistent let garageId: CName;
  // A String can't be persistent
  public persistent let nodeRefPathName: CName;
  public persistent let entityHash: Uint64;
  public persistent let questFactCName: CName;
  public persistent let doorState: Int32;
  // doorState folds several fact values together, so a load puts back the exact one
  public persistent let lastQuestFactValue: Int32;
  public let lastTransitionTime: Float;
  public let cachedPersistentID: PersistentID;
  // 0 past the enter ring, then one up per ring: 2 is the exit ring, the door's own
  public let lastZoneState: Int32;
  public let wantOpen: Bool;
  // V loaded in inside a banned garage: the seal lifts this once, on their way out
  public let letOut: Bool;
  // The door isn't streamed in yet, and the log's already said so
  public let pendingPS: Bool;
  public let resealPending: Bool;
  public let retryActive: Bool;
  public let retryTries: Int32;
  public let retryMax: Int32;
  public let retryInterval: Float;
  public let retryTimer: Uint64;
}

/// Every garage door. A location file with a door gets one that follows the zones by itself.
///
/// For a door your own archive and quest logic depend on, call RegisterDoor from your ScriptableSystem's OnAttach, with a
/// quest fact of your own. It sets the fact as the door changes (3 open, 4 closed, 1 sealed, 0 unsealed). With no door in the
/// location file it gets no zone updates: drive it with OnTriggerEnter and OnTriggerLeave, usually from Garage.ProximityEnter
/// and Garage.ProximityLeave (see GarageEvents), plus OnSaleExitDistance, OnLockdownExpired and OnSaleFailure.
///
/// A door that isn't streamed in is retried for a few seconds, a change within 2 seconds of the last is held back, and a
/// banned garage's door never opens from outside.
public class DoorController extends ScriptableSystem {
  private persistent let m_registrations: array<ref<DoorRegistration>>;

  private static func TransitionDebounce() -> Float { return 2.0; }
  private static func RetryInterval() -> Float { return 0.5; }
  private static func RetryMaxTries() -> Int32 { return 20; }
  // A seal after a load waits on streaming too, and longer
  private static func ResealInterval() -> Float { return 2.0; }
  private static func ResealMaxTries() -> Int32 { return 30; }

  private func Log() -> ref<XUtilsLog> { return XUtils.Mod("Garage").Log("Door"); }

  public static func Get() -> ref<DoorController> {
    return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"Garage.World.DoorController") as DoorController;
  }

  /// A door you own. garageId is the location's id, nodeRefPath the door's world path from WolvenKit (it starts with $/),
  /// questFact a unique fact name. Takes precedence over a door in the location file. False if any is empty.
  public func RegisterDoor(garageId: String, nodeRefPath: String, questFact: CName) -> Bool {
    if StrLen(garageId) == 0 || StrLen(nodeRefPath) == 0 || !IsNameValid(questFact) {
      this.Log().Warn(s"RegisterDoor needs a garage id, a node path and a quest fact: \(garageId), \(nodeRefPath)");
      return false;
    }
    let id: CName = StringToName(garageId);
    let reg: ref<DoorRegistration> = this.Find(id);
    if !IsDefined(reg) { reg = this.Add(id); }
    reg.nodeRefPathName = StringToName(nodeRefPath);
    reg.questFactCName = questFact;
    reg.cachedPersistentID = this.ResolvePersistentID(reg);
    return true;
  }

  /// A door from a location file. Runs every session, so one from the save gets refreshed and a sealed one re-sealed.
  /// A door someone registered with RegisterDoor stays as they set it. False if there's no usable node path or hash.
  public func RegisterLocationDoor(garageId: CName, nodeRef: String, entityHash: String) -> Bool {
    let hash: Uint64 = DoorController.ParseHash(entityHash);
    if StrLen(nodeRef) == 0 && hash == 0ul {
      this.Log().Warn(s"\(NameToString(garageId)) has no node path or hash: \(entityHash)");
      return false;
    }
    let reg: ref<DoorRegistration> = this.Find(garageId);
    if !IsDefined(reg) { reg = this.Add(garageId); }
    if !IsNameValid(reg.questFactCName) {
      reg.nodeRefPathName = StringToName(nodeRef);
      reg.entityHash = hash;
      reg.cachedPersistentID = this.ResolvePersistentID(reg);
    }
    reg.lastZoneState = 0;
    reg.wantOpen = false;
    reg.letOut = false;
    if reg.doorState == EnumInt(DoorState.Sealed) {
      reg.resealPending = true;
      this.ScheduleRetry(reg, DoorController.ResealInterval(), DoorController.ResealMaxTries());
    }
    return true;
  }

  /// V is inside this banned garage at session start, so it opens for them once and seals behind them.
  public func LetOut(garageId: CName) -> Void {
    let reg: ref<DoorRegistration> = this.Find(garageId);
    if !IsDefined(reg) { return; }
    reg.letOut = true;
    reg.resealPending = false;
  }

  private func Add(garageId: CName) -> ref<DoorRegistration> {
    let reg: ref<DoorRegistration> = new DoorRegistration();
    reg.garageId = garageId;
    reg.doorState = EnumInt(DoorState.Closed);
    ArrayPush(this.m_registrations, reg);
    return reg;
  }

  public func IsRegistered(garageId: CName) -> Bool { return IsDefined(this.Find(garageId)); }

  // A JSON number can't hold these, so they're text. 0 on anything else
  private static func ParseHash(text: String) -> Uint64 {
    let result: Uint64 = 0ul;
    let i: Int32 = 0;
    while i < StrLen(text) {
      let digit: Int32 = StrFindFirst("0123456789", StrMid(text, i, 1));
      if digit < 0 { return 0ul; }
      result = result * 10ul + Cast<Uint64>(digit);
      i += 1;
    }
    return result;
  }

  private func ResolvePersistentID(reg: ref<DoorRegistration>) -> PersistentID {
    let id: EntityID = IsNameValid(reg.nodeRefPathName)
      ? EntityID.FromHash(NodeRefToHash(CreateNodeRef(NameToString(reg.nodeRefPathName))))
      : EntityID.FromHash(reg.entityHash);
    return CreatePersistentID(id, n"controller");
  }

  private func Find(garageId: CName) -> ref<DoorRegistration> {
    for reg in this.m_registrations {
      if Equals(reg.garageId, garageId) { return reg; }
    }
    return null;
  }

  private func GetDoorPS(reg: ref<DoorRegistration>) -> ref<DoorControllerPS> {
    let ps: ref<GamePersistencySystem> = GameInstance.GetPersistencySystem(this.GetGameInstance());
    let door: ref<DoorControllerPS> = IsDefined(ps) ? ps.GetConstAccessToPSObject(reg.cachedPersistentID, n"DoorControllerPS") as DoorControllerPS : null;
    if !IsDefined(door) && !reg.pendingPS {
      reg.pendingPS = true;
      this.Log().Info(s"\(NameToString(reg.garageId)) isn't streamed in, retrying");
    }
    if IsDefined(door) { reg.pendingPS = false; }
    return door;
  }

  // --- What asks

  /// From the zones, for doors in a location file. Going in opens, dropping out past the exit ring closes.
  public func OnZoneChanged(garageId: CName, zone: Int32) -> Void {
    let reg: ref<DoorRegistration> = this.Find(garageId);
    if !IsDefined(reg) { return; }
    if zone > reg.lastZoneState {
      reg.wantOpen = true;
    } else {
      if zone < reg.lastZoneState && zone < 2 {
        reg.wantOpen = false;
        reg.letOut = false;
      }
    }
    reg.lastZoneState = zone;
    this.EvaluateOrRetry(reg);
  }

  /// Opens it, for a door you drive yourself.
  public func OnTriggerEnter(garageId: CName) -> Void {
    let reg: ref<DoorRegistration> = this.Find(garageId);
    if !IsDefined(reg) { return; }
    if reg.lastZoneState < 1 { reg.lastZoneState = 1; }
    reg.wantOpen = true;
    this.EvaluateOrRetry(reg);
  }

  /// Closes it, for a door you drive yourself.
  public func OnTriggerLeave(garageId: CName) -> Void {
    let reg: ref<DoorRegistration> = this.Find(garageId);
    if !IsDefined(reg) { return; }
    reg.lastZoneState = 0;
    reg.wantOpen = false;
    this.EvaluateOrRetry(reg);
  }

  /// Closes it now, when V walks off during a sale.
  public func OnSaleExitDistance(garageId: CName) -> Void {
    let reg: ref<DoorRegistration> = this.Find(garageId);
    if !IsDefined(reg) { return; }
    reg.wantOpen = false;
    this.EvaluateOrRetry(reg);
  }

  /// A sale's done: a door you drive yourself goes back to what the last trigger asked for.
  public func OnLockdownExpired(garageId: CName) -> Void { this.RefreshFromTrigger(garageId); }

  /// A sale failed: as OnLockdownExpired.
  public func OnSaleFailure(garageId: CName) -> Void { this.RefreshFromTrigger(garageId); }

  private func RefreshFromTrigger(garageId: CName) -> Void {
    let reg: ref<DoorRegistration> = this.Find(garageId);
    if !IsDefined(reg) { return; }
    if IsNameValid(reg.questFactCName) { reg.wantOpen = reg.lastZoneState >= 1; }
    this.EvaluateOrRetry(reg);
  }

  /// The ban changed. The door follows by itself: sealed once V's outside the exit ring.
  public func OnBanChanged(garageId: CName) -> Void {
    let reg: ref<DoorRegistration> = this.Find(garageId);
    if IsDefined(reg) { this.EvaluateOrRetry(reg); }
  }

  /// doorState only knows what we sent. The game can shut a door by itself, and no ring would open it again.
  public func Reassert(garageId: CName) -> Void {
    let reg: ref<DoorRegistration> = this.Find(garageId);
    if !IsDefined(reg) || reg.lastZoneState < 2 || reg.doorState != EnumInt(DoorState.Open) || (GarageLocks.IsBanned(garageId) && !reg.letOut) { return; }
    let door: ref<DoorControllerPS> = this.GetDoorPS(reg);
    if !IsDefined(door) || (door.IsOpen() && !door.IsLocked()) { return; }
    reg.doorState = EnumInt(DoorState.Closed);
    this.EvaluateOrRetry(reg);
  }

  public func OnRetry(garageId: CName) -> Void {
    let reg: ref<DoorRegistration> = this.Find(garageId);
    if !IsDefined(reg) || !reg.retryActive { return; }
    reg.retryTries += 1;
    if this.Evaluate(reg) {
      reg.retryActive = false;
      return;
    }
    if reg.retryTries >= reg.retryMax {
      reg.retryActive = false;
      this.Log().Warn(s"\(NameToString(reg.garageId)): gave up, the next ring tries again");
      return;
    }
    this.QueueRetry(reg);
  }

  // --- Getting it there

  // Banned: V inside gets let out, then it seals and stays sealed
  private func Target(reg: ref<DoorRegistration>) -> Int32 {
    let wanted: Int32 = reg.wantOpen ? EnumInt(DoorState.Open) : EnumInt(DoorState.Closed);
    if !GarageLocks.IsBanned(reg.garageId) || reg.letOut { return wanted; }
    if reg.doorState == EnumInt(DoorState.Sealed) || reg.lastZoneState < 2 { return EnumInt(DoorState.Sealed); }
    return wanted;
  }

  private func EvaluateOrRetry(reg: ref<DoorRegistration>) -> Void {
    if !this.Evaluate(reg) {
      this.ScheduleRetry(reg, DoorController.RetryInterval(), DoorController.RetryMaxTries());
    }
  }

  private func ScheduleRetry(reg: ref<DoorRegistration>, interval: Float, maxTries: Int32) -> Void {
    if reg.retryActive { return; }
    reg.retryActive = true;
    reg.retryTries = 0;
    reg.retryMax = maxTries;
    reg.retryInterval = interval;
    this.QueueRetry(reg);
  }

  // On the game clock, since a door only streams in while the world runs. Keyed by garage, so a retry re-arms
  private func QueueRetry(reg: ref<DoorRegistration>) -> Void {
    reg.retryTimer = XUtils.Mod("Garage").After(reg.retryInterval, this, n"OnRetryTimer", reg.garageId, XUtilsClock.Game);
  }

  public func OnRetryTimer(e: ref<XUtilsEvent>) -> Void {
    for reg in this.m_registrations {
      if reg.retryTimer == e.id {
        reg.retryTimer = 0ul;
        this.OnRetry(reg.garageId);
        return;
      }
    }
  }

  private func InDebounce(reg: ref<DoorRegistration>) -> Bool {
    let now: Float = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    return now - reg.lastTransitionTime < DoorController.TransitionDebounce();
  }

  // True once the door's where it should be. False while it can't be reached or the debounce holds it back
  private func Evaluate(reg: ref<DoorRegistration>) -> Bool {
    let target: Int32 = this.Target(reg);
    if target == EnumInt(DoorState.Sealed) {
      if reg.doorState == EnumInt(DoorState.Sealed) && !reg.resealPending { return true; }
      if !this.Apply(reg, EnumInt(DoorState.Sealed)) { return false; }
      reg.resealPending = false;
      return true;
    }
    reg.resealPending = false;
    if reg.doorState == EnumInt(DoorState.Sealed) && !this.Apply(reg, -1) { return false; }
    if target == EnumInt(DoorState.Open) && reg.doorState == EnumInt(DoorState.Closed) {
      // Archive triggers rapid-fire on entry, and only doors with a quest fact see those
      if IsNameValid(reg.questFactCName) && this.InDebounce(reg) { return false; }
      return this.Apply(reg, EnumInt(DoorState.Open));
    }
    if target == EnumInt(DoorState.Closed) && reg.doorState == EnumInt(DoorState.Open) {
      if this.InDebounce(reg) { return false; }
      return this.Apply(reg, EnumInt(DoorState.Closed));
    }
    return true;
  }

  // The quest actions, since the toggle ones have no say over story-locked doors. -1 only lifts a seal.
  // The fact goes first: an archive's quest logic reads it whether the door's streamed in or not
  private func Apply(reg: ref<DoorRegistration>, state: Int32) -> Bool {
    if IsNameValid(reg.questFactCName) {
      let fact: Int32 = 0;
      if state == EnumInt(DoorState.Open) { fact = 3; }
      if state == EnumInt(DoorState.Closed) { fact = 4; }
      if state == EnumInt(DoorState.Sealed) { fact = 1; }
      GameInstance.GetQuestsSystem(this.GetGameInstance()).SetFact(reg.questFactCName, fact);
      reg.lastQuestFactValue = fact;
    }
    let door: ref<DoorControllerPS> = this.GetDoorPS(reg);
    if !IsDefined(door) { return false; }
    let ps: ref<GamePersistencySystem> = GameInstance.GetPersistencySystem(this.GetGameInstance());
    let id: PersistentID = reg.cachedPersistentID;
    if state == EnumInt(DoorState.Open) {
      ps.QueuePSEvent(id, n"DoorControllerPS", door.ActionQuestForceUnlock());
      ps.QueuePSEvent(id, n"DoorControllerPS", door.ActionQuestForceOpen());
    }
    if state == EnumInt(DoorState.Closed) {
      ps.QueuePSEvent(id, n"DoorControllerPS", door.ActionQuestForceCloseImmediate());
    }
    if state == EnumInt(DoorState.Sealed) {
      if reg.doorState == EnumInt(DoorState.Open) {
        ps.QueuePSEvent(id, n"DoorControllerPS", door.ActionQuestForceCloseImmediate());
      }
      ps.QueuePSEvent(id, n"DoorControllerPS", door.ActionQuestForceSeal());
    }
    if state == -1 {
      ps.QueuePSEvent(id, n"DoorControllerPS", door.ActionQuestForceUnlock());
    }
    this.Log().Debug(s"\(NameToString(reg.garageId)) to state \(state)");
    if state == -1 {
      reg.doorState = EnumInt(DoorState.Closed);
      return true;
    }
    reg.doorState = state;
    reg.lastTransitionTime = EngineTime.ToFloat(GameInstance.GetSimTime(this.GetGameInstance()));
    return true;
  }

  /// Brings a door in line with the ban, for console use.
  public func SealDoor(garageId: CName) -> Void { this.OnBanChanged(garageId); }

  /// Brings a door in line with the ban, for console use.
  public func UnsealDoor(garageId: CName) -> Void { this.OnBanChanged(garageId); }

  // The game resets a location door to closed on a load, so a saved Open is stale. A door with a quest fact gets its exact
  // fact back, which its archive's pause conditions read. PersistentID doesn't persist
  private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void {
    for reg in this.m_registrations {
      reg.cachedPersistentID = this.ResolvePersistentID(reg);
      if IsNameValid(reg.questFactCName) {
        GameInstance.GetQuestsSystem(this.GetGameInstance()).SetFact(reg.questFactCName, reg.lastQuestFactValue);
      } else {
        if reg.doorState == EnumInt(DoorState.Open) { reg.doorState = EnumInt(DoorState.Closed); }
      }
      if reg.doorState == EnumInt(DoorState.Sealed) { reg.resealPending = true; }
    }
  }
}
