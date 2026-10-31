module Garage.Economy

import Garage.*
import Garage.Vehicle.*
import Garage.World.*

public class GarageSaleDraft extends IScriptable {
  public let recordId: TweakDBID;
  public let salePrice: Int32;
  public let vehicleName: String;
  public let garageId: CName;
  public let vehicleClass: CName;
}

/// Selling a car, which takes a while on purpose. Start agrees the price. Leaving on foot or in another car starts the wait
/// and takes the car out of V's list. Driving off in the sold car cancels it and bans V for good. When the time's up the
/// garage pays, or hands the car back if its pool can't cover it.
public class GarageSales extends IScriptable {
  private let m_xu: ref<XUtilsMod>;
  private let m_log: ref<XUtilsLog>;
  private let m_draft: ref<GarageSaleDraft>;
  private let m_soldEntity: EntityID;
  private let m_hasSold: Bool;
  private let m_disabled: TweakDBID;
  private let m_doomed: wref<GameObject>;
  private let m_doomedRecord: TweakDBID;
  private let m_doomedGarage: CName;
  private let m_removeTimer: Uint64;

  public func Setup(xu: ref<XUtilsMod>) -> Void {
    this.m_xu = xu;
    this.m_log = xu.Log("Economy");
    xu.OnCustom(GarageEvents.ProximityEnter(), this, n"OnEnter");
    xu.OnCustom(GarageEvents.ProximityLeave(), this, n"OnLeave");
  }

  /// Agrees the sale of this car at this garage. Replaces one that's agreed and not yet under way.
  public func Start(recordId: TweakDBID, salePrice: Int32, vehicleName: String, garageId: CName, entity: EntityID, vehicleClass: CName) -> Void {
    if IsDefined(this.m_draft) { EconomyEngine.Get().ClearPendingSale(this.m_draft.garageId); }
    this.Stop();
    let draft: ref<GarageSaleDraft> = new GarageSaleDraft();
    draft.recordId = recordId;
    draft.salePrice = salePrice;
    draft.vehicleName = vehicleName;
    draft.garageId = garageId;
    draft.vehicleClass = vehicleClass;
    this.m_draft = draft;
    this.m_soldEntity = entity;
    this.m_hasSold = true;
  }

  public func OnEnter(e: ref<XUtilsEvent>) -> Void {
    let data: ref<GarageEventData> = e.data as GarageEventData;
    if IsDefined(data) && EconomyEngine.Get().HasPendingSale(data.garageId) {
      this.m_xu.Screen().Notify(GarageText.Get(n"Garage-Sale-NotCleared"), SimpleMessageType.Neutral, 5.0, true);
    }
  }

  public func OnLeave(e: ref<XUtilsEvent>) -> Void {
    let data: ref<GarageEventData> = e.data as GarageEventData;
    if !IsDefined(data) { return; }
    let id: CName = data.garageId;
    if this.IsTheft(id) {
      this.CancelAndBan(id);
      return;
    }
    if !IsDefined(this.m_draft) || !Equals(this.m_draft.garageId, id) { return; }
    let draft: ref<GarageSaleDraft> = this.m_draft;
    this.m_draft = null;
    this.Tell(GarageEvents.SaleExitDistance(), id);
    if !GarageVehicles.SetEnabled(draft.recordId, false) { this.m_log.Warn("couldn't take the sold car out of V's list, it isn't in the vehicle list"); }
    this.m_disabled = draft.recordId;
    EconomyEngine.Get().PersistPendingSale(id, draft.recordId, draft.salePrice, draft.vehicleName, draft.vehicleClass);
  }

  private func IsTheft(id: CName) -> Bool {
    if !this.m_hasSold { return false; }
    if IsDefined(this.m_draft) ? !Equals(this.m_draft.garageId, id) : !EconomyEngine.Get().HasPendingSale(id) { return false; }
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    let mounted: wref<VehicleObject> = IsDefined(player) ? GetMountedVehicle(player) : null;
    return IsDefined(mounted) && Equals(mounted.GetEntityID(), this.m_soldEntity);
  }

  private func CancelAndBan(id: CName) -> Void {
    this.Stop();
    EconomyEngine.Get().ClearPendingSale(id);
    EconomyEngine.Get().BanGarage(id);
    this.m_xu.Screen().Notify(GarageText.Get(n"Garage-Sale-Cancelled"), SimpleMessageType.Negative, 8.0, true);
  }

  /// The engine's call when a sale's time is up. It's checked against the pool here, since a pool can drain during the wait.
  public func Complete(sale: ref<PendingSaleState>) -> Void {
    let id: CName = sale.garageId;
    let name: String = NameToString(sale.vehicleName);
    this.m_disabled = TDBID.None();
    let paid: ref<GarageReceipt> = GarageTransactions.Payout(id, sale.salePrice, EGarageTxKind.Sale, n"chopshop");
    if !paid.ok {
      this.m_log.Debug(NameToString(id) + " couldn't cover the sale: " + NameToString(paid.error));
      this.m_hasSold = false;
      GarageVehicles.SetEnabled(sale.recordId, true);
      this.m_xu.Screen().Notify(GarageText.Format(n"Garage-Sale-FellThrough", [name]), SimpleMessageType.Negative, 8.0, true);
      this.Tell(GarageEvents.SaleFailure(), id);
      this.Tell(GarageEvents.LockdownExpired(), id);
      return;
    }
    // Gone after a load, and then the game's already taken the car away
    let entity: wref<GameObject> = this.m_hasSold ? GameInstance.FindEntityByID(GetGameInstance(), this.m_soldEntity) as GameObject : null;
    this.m_hasSold = false;
    if IsDefined(entity) {
      // Under the map first, so nobody watches it pop out of existence
      let at: Vector4 = entity.GetWorldPosition();
      let flat: EulerAngles;
      GameInstance.GetTeleportationFacility(GetGameInstance()).Teleport(entity, new Vector4(at.X, at.Y, at.Z - 100.0, at.W), flat);
      this.m_doomed = entity;
      this.m_doomedRecord = sale.recordId;
      this.m_doomedGarage = id;
      this.m_removeTimer = this.m_xu.After(0.5, this, n"OnRemove");
    } else {
      this.Finish(sale.recordId, id);
    }
    this.m_xu.Screen().Notify(GarageText.Format(n"Garage-Sale-Cleared", [name]), SimpleMessageType.Money, 6.0, true);
    this.Tell(GarageEvents.LockdownExpired(), id);
  }

  public func OnRemove(e: ref<XUtilsEvent>) -> Void {
    this.m_removeTimer = 0ul;
    let entity: wref<GameObject> = this.m_doomed;
    if IsDefined(entity) { EntityGameInterface.Destroy(entity.GetEntity()); }
    this.Finish(this.m_doomedRecord, this.m_doomedGarage);
  }

  private func Finish(record: TweakDBID, id: CName) -> Void {
    GarageVehicles.SetEnabled(record, false, true);
    this.Tell(GarageEvents.SaleCompleted(), id);
  }

  private func Tell(event: CName, id: CName) -> Void {
    let data: ref<GarageEventData> = new GarageEventData();
    data.garageId = id;
    this.m_xu.Emit(event, data);
  }

  /// Drops a sale that hasn't finished, and gives back a car it took. A persisted one still pays out after the next load.
  public func Stop() -> Void {
    if TDBID.IsValid(this.m_disabled) { GarageVehicles.SetEnabled(this.m_disabled, true); }
    this.m_disabled = TDBID.None();
    this.m_draft = null;
    this.m_hasSold = false;
    if this.m_removeTimer != 0ul {
      this.m_xu.Cancel(this.m_removeTimer);
      this.m_removeTimer = 0ul;
    }
  }
}
