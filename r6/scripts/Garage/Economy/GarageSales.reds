module Garage.Economy

import Garage.*
import Garage.Vehicle.*
import Garage.World.*

/// What Start agrees. recordId is the record V owns it under (GarageContext.OwnedRecord), or the car's own if it's stolen.
public class GarageSaleDraft extends IScriptable {
  public let recordId: TweakDBID;
  public let vehicleRecord: TweakDBID;
  public let stolen: Bool;
  public let entity: EntityID;
  public let salePrice: Int32;
  public let vehicleName: String;
  public let garageId: CName;
  public let vehicleClass: CName;
}

/// Selling a car, which takes a while on purpose. Start agrees the price. Leaving on foot or in another car starts the wait
/// and takes the car out of V's list. Driving off in the sold car cancels it and bans V for good. When the time's up the
/// garage pays, or hands the car back if its pool can't cover it. Each garage has its own sale, and a car in one stays off
/// V's list until that sale pays, falls through or gets cancelled.
public class GarageSales extends IScriptable {
  private let m_xu: ref<XUtilsMod>;
  private let m_log: ref<XUtilsLog>;
  private let m_draft: ref<GarageSaleDraft>;

  public func Setup(xu: ref<XUtilsMod>) -> Void {
    this.m_xu = xu;
    this.m_log = xu.Log("Economy");
    xu.OnCustom(GarageEvents.ProximityEnter(), this, n"OnEnter");
    xu.OnCustom(GarageEvents.ProximityLeave(), this, n"OnLeave");
  }

  /// Agrees a sale. Replaces one that's only agreed, never one that's under way.
  public func Start(draft: ref<GarageSaleDraft>) -> Void { this.m_draft = draft; }

  public func Draft() -> ref<GarageSaleDraft> { return this.m_draft; }

  /// Drops the agreed sale. One that's under way isn't touched.
  public func CancelDraft() -> Void { this.m_draft = null; }

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
    if !IsDefined(EconomyEngine.Get().PersistPendingSale(draft)) {
      this.m_log.Warn("couldn't start the sale at " + NameToString(id) + ", the car stays V's");
      return;
    }
    this.Tell(GarageEvents.SaleExitDistance(), id);
    if !draft.stolen && !GarageVehicles.SetEnabled(draft.recordId, false) { this.m_log.Warn("couldn't take the sold car out of V's list, it isn't in the vehicle list"); }
  }

  private func IsTheft(id: CName) -> Bool {
    let sold: EntityID;
    if IsDefined(this.m_draft) && Equals(this.m_draft.garageId, id) {
      sold = this.m_draft.entity;
    } else {
      let sale: ref<PendingSaleState> = EconomyEngine.Get().GetPendingSale(id);
      if !IsDefined(sale) { return false; }
      sold = sale.entity;
    }
    if !EntityID.IsDefined(sold) { return false; }
    let mounted: wref<Entity> = this.m_xu.Player().GetVehicle();
    return IsDefined(mounted) && Equals(mounted.GetEntityID(), sold);
  }

  // V drove off in it, so it's V's car again and the garage is done with them
  private func CancelAndBan(id: CName) -> Void {
    if IsDefined(this.m_draft) && Equals(this.m_draft.garageId, id) { this.m_draft = null; }
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    let sale: ref<PendingSaleState> = engine.GetPendingSale(id);
    if IsDefined(sale) {
      this.GiveBack(sale);
      engine.ClearPendingSale(id);
    }
    engine.BanGarage(id);
    this.m_xu.Screen().Notify(GarageText.Get(n"Garage-Sale-Cancelled"), SimpleMessageType.Negative, 8.0, true);
  }

  /// The engine's call when a sale's time is up. It's checked against the pool here, since a pool can drain during the wait.
  public func Complete(sale: ref<PendingSaleState>) -> Void {
    let id: CName = sale.garageId;
    let name: String = NameToString(sale.vehicleName);
    let paid: ref<GarageReceipt> = GarageTransactions.Payout(id, sale.salePrice, EGarageTxKind.Sale, n"chopshop");
    if !paid.ok {
      this.m_log.Debug(NameToString(id) + " couldn't cover the sale: " + NameToString(paid.error));
      this.GiveBack(sale);
      this.m_xu.Screen().Notify(GarageText.Format(n"Garage-Sale-FellThrough", [name]), SimpleMessageType.Negative, 8.0, true);
      this.Tell(GarageEvents.SaleFailure(), id);
      this.Tell(GarageEvents.LockdownExpired(), id);
      return;
    }
    let entity: wref<Entity> = EntityID.IsDefined(sale.entity) ? this.m_xu.World().Find(sale.entity) : null;
    if IsDefined(entity) {
      GarageRepairLedger.Get().Forget(entity as VehicleObject);
      this.m_xu.World().Remove(entity);
    } else {
      // Out of V's list since V walked away, but a copy could still be out somewhere
      if !sale.stolen { GarageVehicles.SetEnabled(sale.recordId, false, true); }
    }
    this.Finish(sale);
    this.m_xu.Screen().Notify(GarageText.Format(n"Garage-Sale-Cleared", [name]), SimpleMessageType.Money, 6.0, true);
    this.Tell(GarageEvents.LockdownExpired(), id);
  }

  private func GiveBack(sale: ref<PendingSaleState>) -> Void {
    if !sale.stolen { GarageVehicles.SetEnabled(sale.recordId, true); }
  }

  private func Finish(sale: ref<PendingSaleState>) -> Void {
    let system: ref<GarageSystem> = GarageSystem.Get();
    if IsDefined(system) { system.Parts().StripSold(TDBID.IsValid(sale.vehicleRecord) ? sale.vehicleRecord : sale.recordId); }
    this.Tell(GarageEvents.SaleCompleted(), sale.garageId);
  }

  private func Tell(event: CName, id: CName) -> Void {
    let data: ref<GarageEventData> = new GarageEventData();
    data.garageId = id;
    this.m_xu.Emit(event, data);
  }

  /// Session end. Drops a sale that's only agreed. One under way is in the save and carries on after the next load.
  public func Stop() -> Void {
    this.m_draft = null;
  }
}
