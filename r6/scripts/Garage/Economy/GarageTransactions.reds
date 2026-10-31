module Garage.Economy

import Garage.*
import Garage.Data.*
import Garage.World.*

public enum EGarageTxKind {
  Service = 0,
  Parts = 1,
  Claim = 2,
  Sale = 3,
  Refund = 4,
  Rush = 5,
  Job = 6,
  Admin = 7,
}

/// What a Charge or Payout did. Check ok, and error says why not: invalid_amount, no_player, insufficient_funds,
/// remove_failed, no_garage or pool_insufficient. Hold on to a Charge's to refund it.
public class GarageReceipt extends IScriptable {
  public let ok: Bool;
  public let error: CName;
  public let amount: Int32;
  public let garageId: CName;
  public let kind: EGarageTxKind;
  public let source: CName;
  public let meta: ref<IScriptable>;
  public let refunded: Bool;

  public static func Make(garageId: CName, amount: Int32, kind: EGarageTxKind, source: CName, meta: ref<IScriptable>) -> ref<GarageReceipt> {
    let receipt: ref<GarageReceipt> = new GarageReceipt();
    receipt.garageId = garageId;
    receipt.amount = amount;
    receipt.kind = kind;
    receipt.source = source;
    receipt.meta = meta;
    return receipt;
  }

  public func Done() -> ref<GarageReceipt> {
    this.ok = true;
    return this;
  }

  public func Failed(error: CName) -> ref<GarageReceipt> {
    this.error = error;
    return this;
  }
}

/// The one place the player's money moves for garage business. Every call moves the wallet and the garage's pool together
/// and sends Garage.Transaction. meta is yours and comes through on the event. Free things pass through and report nothing.
public abstract class GarageTransactions {
  /// Player to garage. n"" for garageId takes the money without paying a pool.
  public static func Charge(garageId: CName, amount: Int32, kind: EGarageTxKind, source: CName, opt meta: ref<IScriptable>) -> ref<GarageReceipt> {
    let receipt: ref<GarageReceipt> = GarageReceipt.Make(garageId, amount, kind, source, meta);
    if amount < 0 { return receipt.Failed(n"invalid_amount"); }
    if amount == 0 { return receipt.Done(); }
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    let items: ref<TransactionSystem> = GameInstance.GetTransactionSystem(GetGameInstance());
    if !IsDefined(player) || !IsDefined(items) { return receipt.Failed(n"no_player"); }
    if items.GetItemQuantity(player, MarketSystem.Money()) < amount { return receipt.Failed(n"insufficient_funds"); }
    if !items.RemoveItem(player, MarketSystem.Money(), amount) { return receipt.Failed(n"remove_failed"); }
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if IsDefined(engine) && IsNameValid(garageId) { engine.AddToPool(garageId, amount); }
    GarageTransactions.Report(garageId, amount, kind, kind, source, meta);
    return receipt.Done();
  }

  /// Garage to player, and the only way money leaves a pool for the player. Needs a garage.
  public static func Payout(garageId: CName, amount: Int32, kind: EGarageTxKind, source: CName, opt meta: ref<IScriptable>) -> ref<GarageReceipt> {
    let receipt: ref<GarageReceipt> = GarageReceipt.Make(garageId, amount, kind, source, meta);
    if amount < 0 { return receipt.Failed(n"invalid_amount"); }
    if !IsNameValid(garageId) { return receipt.Failed(n"no_garage"); }
    if amount == 0 { return receipt.Done(); }
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    let items: ref<TransactionSystem> = GameInstance.GetTransactionSystem(GetGameInstance());
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if !IsDefined(player) || !IsDefined(items) || !IsDefined(engine) { return receipt.Failed(n"no_player"); }
    if !engine.DeductFromPool(garageId, amount) { return receipt.Failed(n"pool_insufficient"); }
    items.GiveItem(player, MarketSystem.Money(), amount);
    GarageTransactions.Report(garageId, amount, kind, kind, source, meta);
    return receipt.Done();
  }

  /// Undoes a Charge, once. The player always gets it back, and the pool gives up what it still has of it since a sale
  /// may have spent the rest. False if it's been refunded or never went through.
  public static func Refund(receipt: ref<GarageReceipt>) -> Bool {
    if !IsDefined(receipt) || !receipt.ok || receipt.refunded { return false; }
    receipt.refunded = true;
    if receipt.amount <= 0 { return true; }
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    let items: ref<TransactionSystem> = GameInstance.GetTransactionSystem(GetGameInstance());
    if IsDefined(player) && IsDefined(items) { items.GiveItem(player, MarketSystem.Money(), receipt.amount); }
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if IsDefined(engine) && IsNameValid(receipt.garageId) {
      engine.DeductFromPool(receipt.garageId, Min(receipt.amount, engine.GetPool(receipt.garageId)));
    }
    GarageTransactions.Report(receipt.garageId, receipt.amount, EGarageTxKind.Refund, receipt.kind, receipt.source, receipt.meta);
    return true;
  }

  private static func Report(garageId: CName, amount: Int32, kind: EGarageTxKind, refundOf: EGarageTxKind, source: CName, meta: ref<IScriptable>) -> Void {
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if IsDefined(engine) && IsNameValid(garageId) { engine.OnTransaction(garageId, kind); }
    let system: ref<GarageSystem> = GarageSystem.Get();
    if !IsDefined(system) { return; }
    let data: ref<GarageTransactionData> = new GarageTransactionData();
    data.garageId = garageId;
    let location: ref<GarageLocation> = system.Data().GetLocation(garageId);
    data.garageName = IsDefined(location) ? location.name : "";
    data.amount = amount;
    data.kind = kind;
    data.refundOf = refundOf;
    data.source = source;
    data.meta = meta;
    system.Xu().Emit(GarageEvents.Transaction(), data);
    system.Xu().Emit(GarageEvents.EconomyRefresh(), data);
  }
}
