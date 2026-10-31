module Garage.Economy

import Garage.*
import Garage.Data.*
import Garage.World.*

public class PendingSaleState {
  public persistent let recordId: TweakDBID;
  public persistent let salePrice: Int32;
  public persistent let garageId: CName;
  // A String can't be persistent
  public persistent let vehicleName: CName;
  public persistent let deadlineGameSeconds: Int32;
  public persistent let active: Bool;
}

public class GarageEconomyState {
  public persistent let garageId: CName;
  public persistent let cashPool: Int32;
  public persistent let maxFloat: Int32;
  public persistent let lastRegenGameSeconds: Int32;
  public persistent let reputation: Int32;
  public persistent let tierName: CName;
  public persistent let banned: Bool;
  public persistent let lockoutGameSeconds: Int32;
  public persistent let lockoutDuration: Int32;
  public persistent let lockoutReason: CName;
  public persistent let pendingSale: ref<PendingSaleState>;
  // From the location file, every session. Null until InitGarage, for a garage whose file's gone
  public let config: ref<GarageEconomyData>;
  public let services: array<CName>;
  public let activityPaused: Bool;
}

public class GarageTier {
  public let name: CName;
  public let minFloat: Int32;
  public let maxFloat: Int32;
  // Rate * 10000: 2500 is 25% a day
  public let regenRate: Int32;
  public let pricingMultiplier: Int32;
  // Pct * 100: 2000 is 20%
  public let maxDiscount: Int32;
  public let services: array<CName>;
  // What a busy shop does above its float
  public let serviceMargin: Int32;
  public let overheadPct: Int32;
  public let purchasePeriod: Int32;
  public let purchasePct: Int32;
  public let activityCeilingPct: Int32;
  public let baseSaleDelay: Int32;
}

/// Everything GetEconomyInfo knows about a garage in one lookup.
public class GarageEconomyInfo extends IScriptable {
  public let pool: Int32;
  public let maxFloat: Int32;
  public let tier: CName;
  public let reputation: Int32;
  public let playerFactor: Float;
  public let discount: Float;
  public let streetCred: Int32;
}

/// Each garage's money, bans, locks and pending sale, saved with the game. Moving the player's money goes through
/// GarageTransactions. AddToPool, DeductFromPool and SetPool are for admin and tools, and don't count as transactions.
public class EconomyEngine extends ScriptableSystem {
  private persistent let m_garages: array<ref<GarageEconomyState>>;
  private let m_index: ref<inkHashMap>;
  private let m_tiers: array<ref<GarageTier>>;
  private let m_repDeltas: array<Int32>;
  private let m_xu: ref<XUtilsMod>;
  private let m_log: ref<XUtilsLog>;
  private let m_regenTimer: Uint64;
  private let m_saleTimer: Uint64;

  public static func Get() -> ref<EconomyEngine> {
    return GameInstance.GetScriptableSystemsContainer(GetGameInstance()).Get(n"Garage.Economy.EconomyEngine") as EconomyEngine;
  }

  private static func RegenInterval() -> Float { return 150.0; }
  private static func SaleCheckInterval() -> Float { return 10.0; }

  // The index isn't saved, and a load swaps m_garages out from under it
  private func OnRestored(saveVersion: Int32, gameVersion: Int32) -> Void { this.RebuildIndex(); }

  private func RebuildIndex() -> Void {
    this.m_index = new inkHashMap();
    for state in this.m_garages { this.m_index.Insert(Cast<Uint64>(state.garageId), state); }
  }

  // --- Session

  public func Start(xu: ref<XUtilsMod>, data: ref<GarageData>) -> Void {
    this.Stop();
    this.m_xu = xu;
    this.m_log = xu.Log("Economy");
    let locations: array<ref<GarageLocation>> = data.GetLocations();
    for location in locations { this.InitGarage(location.id, location.economy); }
    // Time spent saved at a garage isn't time it was running
    let now: Int32 = this.GameSeconds();
    for state in this.m_garages {
      state.activityPaused = false;
      if now > 0 { state.lastRegenGameSeconds = now; }
    }
    this.m_regenTimer = xu.Every(EconomyEngine.RegenInterval(), this, n"OnRegenTick");
    this.ProcessExpiredSales();
    this.WatchSales();
  }

  public func Stop() -> Void {
    if !IsDefined(this.m_xu) { return; }
    if this.m_regenTimer != 0ul { this.m_xu.Cancel(this.m_regenTimer); }
    if this.m_saleTimer != 0ul { this.m_xu.Cancel(this.m_saleTimer); }
    this.m_regenTimer = 0ul;
    this.m_saleTimer = 0ul;
  }

  public func OnRegenTick(e: ref<XUtilsEvent>) -> Void { this.TickRegeneration(); }

  public func OnSaleCheck(e: ref<XUtilsEvent>) -> Void {
    this.ProcessExpiredSales();
    this.WatchSales();
  }

  // Only runs with a sale waiting, and a deadline in game time survives skips and sleep this way
  private func WatchSales() -> Void {
    let pending: Bool = false;
    for state in this.m_garages {
      if this.IsSalePending(state) { pending = true; }
    }
    if pending && this.m_saleTimer == 0ul {
      this.m_saleTimer = this.m_xu.Every(EconomyEngine.SaleCheckInterval(), this, n"OnSaleCheck");
    }
    if !pending && this.m_saleTimer != 0ul {
      this.m_xu.Cancel(this.m_saleTimer);
      this.m_saleTimer = 0ul;
    }
  }

  // --- Lookups

  private func FindState(garageId: CName) -> ref<GarageEconomyState> {
    if !IsDefined(this.m_index) { this.RebuildIndex(); }
    return this.m_index.Get(Cast<Uint64>(garageId)) as GarageEconomyState;
  }

  private func FindOrCreateState(garageId: CName) -> ref<GarageEconomyState> {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if IsDefined(state) { return state; }
    state = new GarageEconomyState();
    state.garageId = garageId;
    state.lastRegenGameSeconds = this.GameSeconds();
    state.tierName = n"Standard";
    ArrayPush(this.m_garages, state);
    this.m_index.Insert(Cast<Uint64>(garageId), state);
    return state;
  }

  private func GameSeconds() -> Int32 {
    let time: GameTime = GameInstance.GetTimeSystem(this.GetGameInstance()).GetGameTime();
    return GameTime.Days(time) * 86400 + GameTime.Hours(time) * 3600 + GameTime.Minutes(time) * 60 + GameTime.Seconds(time);
  }

  public func GetStreetCred() -> Int32 {
    let player: ref<PlayerPuppet> = GetPlayer(this.GetGameInstance());
    if !IsDefined(player) { return 0; }
    let stats: ref<StatsSystem> = GameInstance.GetStatsSystem(this.GetGameInstance());
    return RoundF(stats.GetStatValue(Cast<StatsObjectID>(player.GetEntityID()), gamedataStatType.StreetCred));
  }

  private func RandomInRange(min: Int32, max: Int32) -> Int32 {
    return min >= max ? min : RandRange(min, max + 1);
  }

  // --- Tiers

  private func AddTier(name: CName, minFloat: Int32, maxFloat: Int32, regenRate: Int32, pricing: Int32, maxDiscount: Int32, services: array<CName>,
                       margin: Int32, overhead: Int32, period: Int32, purchase: Int32, ceiling: Int32, saleDelay: Int32) -> Void {
    let tier: ref<GarageTier> = new GarageTier();
    tier.name = name;
    tier.minFloat = minFloat;
    tier.maxFloat = maxFloat;
    tier.regenRate = regenRate;
    tier.pricingMultiplier = pricing;
    tier.maxDiscount = maxDiscount;
    tier.services = services;
    tier.serviceMargin = margin;
    tier.overheadPct = overhead;
    tier.purchasePeriod = period;
    tier.purchasePct = purchase;
    tier.activityCeilingPct = ceiling;
    tier.baseSaleDelay = saleDelay;
    ArrayPush(this.m_tiers, tier);
  }

  private func BuildTiers() -> Void {
    this.AddTier(n"Standard", 80000, 150000, 2500, 100, 1500, [n"repair", n"storage"], 70, 25, 86400, 10, 40, 48600);
    this.AddTier(n"Classic", 100000, 200000, 2000, 80, 1500, [n"repair", n"storage", n"customization"], 65, 30, 108000, 12, 45, 32400);
    this.AddTier(n"Sport", 400000, 750000, 1500, 90, 2000, [n"repair", n"storage", n"customization", n"paint"], 60, 30, 129600, 14, 50, 32400);
    this.AddTier(n"Premium", 250000, 500000, 2000, 115, 2000, [n"repair", n"storage", n"customization", n"paint"], 55, 35, 129600, 15, 50, 16200);
    this.AddTier(n"Exotic", 600000, 1000000, 1000, 135, 2500, [n"repair", n"storage", n"customization", n"paint", n"chopshop"], 50, 40, 172800, 18, 60, 16200);
    this.AddTier(n"Hyper", 1000000, 2000000, 800, 160, 2500, [n"repair", n"storage", n"customization", n"paint", n"chopshop"], 45, 45, 216000, 20, 70, 10800);
  }

  // Standard comes first, so it's what a typo in a file gets
  private func Tier(name: CName) -> ref<GarageTier> {
    if ArraySize(this.m_tiers) == 0 { this.BuildTiers(); }
    for tier in this.m_tiers {
      if Equals(tier.name, name) { return tier; }
    }
    return this.m_tiers[0];
  }

  // --- Setup

  /// Runs for every garage each session and when a location's saved. The pool and reputation carry over.
  public func InitGarage(garageId: CName, config: ref<GarageEconomyData>) -> Void {
    if !IsNameValid(garageId) || !IsDefined(config) { return; }
    let tier: ref<GarageTier> = this.Tier(config.tier);
    if !Equals(tier.name, config.tier) && IsDefined(this.m_log) {
      this.m_log.Warn("unknown tier " + NameToString(config.tier) + " at " + NameToString(garageId) + ", using Standard");
    }
    let state: ref<GarageEconomyState> = this.FindOrCreateState(garageId);
    state.tierName = tier.name;
    state.config = config;
    if config.maxPool > 0 {
      state.maxFloat = config.maxPool;
    } else {
      if state.maxFloat == 0 { state.maxFloat = this.RandomInRange(tier.minFloat, tier.maxFloat); }
    }
    if state.cashPool == 0 { state.cashPool = state.maxFloat; }
    state.services = this.KnowsAService(config.services) ? config.services : tier.services;
    if ArraySize(config.services) > 0 && !this.KnowsAService(config.services) && IsDefined(this.m_log) {
      this.m_log.Warn("no known service in the list for " + NameToString(garageId) + ", using its tier's");
    }
  }

  private func KnowsAService(services: array<CName>) -> Bool {
    for service in services {
      if Equals(service, n"repair") || Equals(service, n"storage") || Equals(service, n"customization") || Equals(service, n"paint") || Equals(service, n"chopshop") { return true; }
    }
    return false;
  }

  // --- Pool

  public func GetPool(garageId: CName) -> Int32 {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) ? state.cashPool : 0;
  }

  public func GetMaxFloat(garageId: CName) -> Int32 {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) ? state.maxFloat : 0;
  }

  public func CanAfford(garageId: CName, amount: Int32) -> Bool {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) && state.cashPool >= amount;
  }

  /// False, with the pool untouched, when it can't cover amount.
  public func DeductFromPool(garageId: CName, amount: Int32) -> Bool {
    if amount <= 0 { return true; }
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if !IsDefined(state) || state.cashPool < amount { return false; }
    state.cashPool -= amount;
    return true;
  }

  /// Player money can take a pool past its float, so this doesn't cap at it.
  public func AddToPool(garageId: CName, amount: Int32) -> Void {
    if amount <= 0 { return; }
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if !IsDefined(state) { return; }
    // Claims feed the pool, and an Int32 wrapping around is a bad day
    let sum: Int64 = Cast<Int64>(state.cashPool) + Cast<Int64>(amount);
    state.cashPool = Cast<Int32>(sum > 1000000000l ? 1000000000l : sum);
  }

  public func SetPool(garageId: CName, amount: Int32) -> Void { this.FindOrCreateState(garageId).cashPool = amount; }

  // --- Reputation and pricing

  public func GetTier(garageId: CName) -> CName {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) ? state.tierName : n"";
  }

  public func GetReputation(garageId: CName) -> Int32 {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) ? state.reputation : 0;
  }

  public func AddReputation(garageId: CName, amount: Int32) -> Void {
    if amount <= 0 { return; }
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if IsDefined(state) { state.reputation = Min(state.reputation + amount, 100); }
  }

  public func SetReputation(garageId: CName, value: Int32) -> Void {
    this.FindOrCreateState(garageId).reputation = Max(Min(value, 100), 0);
  }

  /// Reputation a transaction of this kind earns. All 0 for now, waiting on a balance pass.
  public func SetReputationDelta(kind: EGarageTxKind, delta: Int32) -> Void {
    while ArraySize(this.m_repDeltas) <= EnumInt(kind) { ArrayPush(this.m_repDeltas, 0); }
    this.m_repDeltas[EnumInt(kind)] = delta;
  }

  public func OnTransaction(garageId: CName, kind: EGarageTxKind) -> Void {
    let at: Int32 = EnumInt(kind);
    if at < ArraySize(this.m_repDeltas) { this.AddReputation(garageId, this.m_repDeltas[at]); }
  }

  // 0 to 10000, for integer math that matches the Float getter
  private func PlayerFactorScaled(state: ref<GarageEconomyState>) -> Int32 {
    let cred: Int32 = Max(Min(this.GetStreetCred() * 10000 / 50, 10000), 0);
    let reputation: Int32 = Max(Min(state.reputation * 100, 10000), 0);
    return (35 * cred + 65 * reputation) / 100;
  }

  /// 0 to 1: 35% street cred out of 50, 65% reputation out of 100.
  public func GetPlayerFactor(garageId: CName) -> Float {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) ? Cast<Float>(this.PlayerFactorScaled(state)) / 10000.0 : 0.0;
  }

  /// The fraction off prices here: the player factor times the tier's most.
  public func GetPricingDiscount(garageId: CName) -> Float {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if !IsDefined(state) { return 0.0; }
    return Cast<Float>(this.PlayerFactorScaled(state)) / 10000.0 * Cast<Float>(this.Tier(state.tierName).maxDiscount) / 10000.0;
  }

  /// Null for a garage it doesn't know.
  public func GetEconomyInfo(garageId: CName) -> ref<GarageEconomyInfo> {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if !IsDefined(state) { return null; }
    let info: ref<GarageEconomyInfo> = new GarageEconomyInfo();
    info.pool = state.cashPool;
    info.maxFloat = state.maxFloat;
    info.tier = state.tierName;
    info.reputation = state.reputation;
    info.playerFactor = Cast<Float>(this.PlayerFactorScaled(state)) / 10000.0;
    info.discount = info.playerFactor * Cast<Float>(this.Tier(state.tierName).maxDiscount) / 10000.0;
    info.streetCred = this.GetStreetCred();
    return info;
  }

  public func IsVehicleClassBlocked(garageId: CName, vehicleClass: CName) -> Bool {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) && IsDefined(state.config) && ArrayContains(state.config.blockedClasses, vehicleClass);
  }

  /// 1.0 unless the file charges this class extra.
  public func GetSurchargeMultiplier(garageId: CName, vehicleClass: CName) -> Float {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if !IsDefined(state) || !IsDefined(state.config) { return 1.0; }
    for surcharge in state.config.surcharges {
      if Equals(surcharge.vehicleClass, vehicleClass) { return surcharge.multiplier; }
    }
    return 1.0;
  }

  public func IsServiceAvailable(garageId: CName, serviceId: CName) -> Bool {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) && ArrayContains(state.services, serviceId);
  }

  public func GetAvailableServices(garageId: CName) -> array<CName> {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if IsDefined(state) { return state.services; }
    let none: array<CName>;
    return none;
  }

  // --- Activity

  /// V's here, so the shop's own business stops while they are.
  public func PauseActivity(garageId: CName) -> Void {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if IsDefined(state) { state.activityPaused = true; }
  }

  public func ResumeActivity(garageId: CName) -> Void {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if !IsDefined(state) { return; }
    state.activityPaused = false;
    state.lastRegenGameSeconds = this.GameSeconds();
  }

  /// Below the float it recovers. At or above, it runs a business: service income less overhead less the odd car it buys.
  public func TickRegeneration() -> Void {
    let now: Int32 = this.GameSeconds();
    if now == 0 { return; }
    for state in this.m_garages {
      let elapsed: Int32 = now - state.lastRegenGameSeconds;
      state.lastRegenGameSeconds = now;
      // A load can move the clock backward
      if !state.activityPaused && elapsed >= 0 {
        if state.cashPool >= state.maxFloat {
          this.RunBusiness(state, elapsed);
        } else {
          this.Recover(state, elapsed);
        }
      }
    }
  }

  // Hours first, or a long skip overflows an Int32
  private func Accrued(dailyRate: Int32, elapsed: Int32) -> Int32 {
    let hours: Int32 = elapsed / 3600;
    let remainder: Int32 = elapsed - hours * 3600;
    return dailyRate * hours / 24 + dailyRate * remainder / 86400;
  }

  private func Recover(state: ref<GarageEconomyState>, elapsed: Int32) -> Void {
    let daily: Int32 = Cast<Int32>(Cast<Int64>(this.Tier(state.tierName).regenRate) * Cast<Int64>(state.maxFloat) / 10000l);
    let amount: Int32 = this.Accrued(daily, elapsed);
    if amount > 0 { state.cashPool = Min(state.cashPool + amount, state.maxFloat); }
  }

  private func RunBusiness(state: ref<GarageEconomyState>, elapsed: Int32) -> Void {
    let tier: ref<GarageTier> = this.Tier(state.tierName);
    let ceiling: Int32 = state.maxFloat + state.maxFloat * tier.activityCeilingPct / 100;
    if state.cashPool >= ceiling { return; }
    let daily: Int32 = Cast<Int32>(Cast<Int64>(tier.regenRate * tier.serviceMargin / 100) * Cast<Int64>(state.maxFloat) / 10000l);
    let income: Int32 = this.Accrued(daily, elapsed);
    let overhead: Int32 = income * tier.overheadPct / 100;
    let purchases: Int32 = elapsed / tier.purchasePeriod * (state.maxFloat * tier.purchasePct / 100);
    let net: Int32 = income - overhead - purchases;
    // Taper toward the ceiling rather than hit it
    let range: Int32 = ceiling - state.maxFloat;
    if range > 0 && net > 0 { net = net * (ceiling - state.cashPool) / range; }
    state.cashPool = Min(Max(state.cashPool + net, state.maxFloat / 2), ceiling);
  }

  // --- Bans

  /// V inside gets let out, then the door seals behind them and the garage stops being watched.
  public func BanGarage(garageId: CName) -> Void {
    this.FindOrCreateState(garageId).banned = true;
    this.OnBanChanged(garageId, true);
  }

  public func UnbanGarage(garageId: CName) -> Void {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if !IsDefined(state) { return; }
    state.banned = false;
    this.OnBanChanged(garageId, false);
  }

  private func OnBanChanged(garageId: CName, banned: Bool) -> Void {
    if IsDefined(this.m_log) { this.m_log.Info(NameToString(garageId) + (banned ? " banned" : " unbanned")); }
    let system: ref<GarageSystem> = GarageSystem.Get();
    if !IsDefined(system) { return; }
    system.World().OnBanChanged(garageId);
    let data: ref<GarageEventData> = new GarageEventData();
    data.garageId = garageId;
    system.Xu().Emit(banned ? GarageEvents.GarageBanned() : GarageEvents.GarageUnbanned(), data);
  }

  public func IsGarageBanned(garageId: CName) -> Bool {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) && state.banned;
  }

  // --- Locks

  /// A timed lock, in game seconds before the Cooldown Multiplier setting. 0 clears it. A pending sale locks by itself.
  public func LockGarage(garageId: CName, duration: Int32, reason: CName) -> Void {
    let settings: ref<GarageSettings> = GarageSettings.Get();
    let scaled: Int32 = IsDefined(settings) ? RoundF(Cast<Float>(duration) * ClampF(settings.cooldownMultiplier, 0.0, 2.0)) : duration;
    let state: ref<GarageEconomyState> = this.FindOrCreateState(garageId);
    state.lockoutGameSeconds = this.GameSeconds();
    state.lockoutDuration = scaled;
    state.lockoutReason = reason;
  }

  private func IsSalePending(state: ref<GarageEconomyState>) -> Bool {
    return IsDefined(state.pendingSale) && state.pendingSale.active;
  }

  private func HasActiveLockout(state: ref<GarageEconomyState>) -> Bool {
    if state.lockoutDuration <= 0 { return false; }
    let elapsed: Int32 = this.GameSeconds() - state.lockoutGameSeconds;
    return elapsed >= 0 && elapsed < state.lockoutDuration;
  }

  public func IsGarageLocked(garageId: CName) -> Bool {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) && (this.IsSalePending(state) || this.HasActiveLockout(state));
  }

  /// Game seconds left, a pending sale's first. 0 when it isn't locked.
  public func GetLockoutRemainingSeconds(garageId: CName) -> Int32 {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if !IsDefined(state) { return 0; }
    if this.IsSalePending(state) { return Max(state.pendingSale.deadlineGameSeconds - this.GameSeconds(), 0); }
    if state.lockoutDuration > 0 { return Max(state.lockoutDuration - (this.GameSeconds() - state.lockoutGameSeconds), 0); }
    return 0;
  }

  /// One of GarageLockReason's, n"" when it isn't locked.
  public func GetLockoutReason(garageId: CName) -> CName {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if !IsDefined(state) { return n""; }
    if this.IsSalePending(state) { return GarageLockReason.SalePending(); }
    return this.HasActiveLockout(state) ? state.lockoutReason : n"";
  }

  /// base * the file's multiplier, up to 30% less for a good player factor. Never under 1.
  public func ComputeEffectiveCooldown(garageId: CName, baseDuration: Int32) -> Int32 {
    if baseDuration <= 0 { return 1; }
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if !IsDefined(state) { return baseDuration; }
    let keep: Int32 = 10000 - this.PlayerFactorScaled(state) * 3000 / 10000;
    let multiplier: Int32 = IsDefined(state.config) && state.config.cooldownMultiplier > 0.0 ? FloorF(state.config.cooldownMultiplier * 100.0) : 100;
    return Max(baseDuration * multiplier / 100 * keep / 10000, 1);
  }

  /// Locks it for the effective cooldown of baseDuration and returns what that came to.
  public func ApplyCooldown(garageId: CName, baseDuration: Int32) -> Int32 {
    let effective: Int32 = this.ComputeEffectiveCooldown(garageId, baseDuration);
    this.LockGarage(garageId, effective, GarageLockReason.Cooldown());
    return effective;
  }

  // --- Pending sales

  /// False for a garage it doesn't know, one with a sale already, or no record.
  public func PersistPendingSale(garageId: CName, recordId: TweakDBID, salePrice: Int32, vehicleName: String, vehicleClass: CName) -> Bool {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if !IsDefined(state) || !TDBID.IsValid(recordId) || this.IsSalePending(state) { return false; }
    let sale: ref<PendingSaleState> = new PendingSaleState();
    sale.recordId = recordId;
    sale.salePrice = salePrice;
    sale.garageId = garageId;
    sale.vehicleName = StringToName(vehicleName);
    sale.deadlineGameSeconds = this.GameSeconds() + this.ComputeSaleDelay(garageId, vehicleClass);
    sale.active = true;
    state.pendingSale = sale;
    this.WatchSales();
    return true;
  }

  public func HasPendingSale(garageId: CName) -> Bool {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) && this.IsSalePending(state);
  }

  /// Null unless a sale's waiting.
  public func GetPendingSale(garageId: CName) -> ref<PendingSaleState> {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) && this.IsSalePending(state) ? state.pendingSale : null;
  }

  public func ClearPendingSale(garageId: CName) -> Void {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if IsDefined(state) && this.IsSalePending(state) {
      state.pendingSale.active = false;
      this.WatchSales();
    }
  }

  public func IsPendingSaleExpired(garageId: CName) -> Bool {
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    return IsDefined(state) && this.IsSalePending(state) && state.pendingSale.deadlineGameSeconds <= this.GameSeconds();
  }

  public func ProcessExpiredSales() -> Void {
    let now: Int32 = this.GameSeconds();
    if now == 0 { return; }
    for state in this.m_garages {
      if this.IsSalePending(state) && state.pendingSale.deadlineGameSeconds <= now {
        state.pendingSale.active = false;
        // The payout and the car come with the sale flow
        if IsDefined(this.m_log) { this.m_log.Info("sale due at " + NameToString(state.garageId)); }
      }
    }
  }

  /// In game seconds. The instant setting wins, then the file's own range, then the formula: tier base * class * chance.
  public func ComputeSaleDelay(garageId: CName, vehicleClass: CName) -> Int32 {
    let settings: ref<GarageSettings> = GarageSettings.Get();
    // About 10 real seconds at normal speed
    if IsDefined(settings) && settings.disableSaleDelay { return 80; }
    let state: ref<GarageEconomyState> = this.FindState(garageId);
    if !IsDefined(state) { return 86400; }
    let config: ref<GarageEconomyData> = state.config;
    let delay: ref<GarageSaleDelay> = IsDefined(config) ? config.saleDelay : null;
    let result: Int32;
    if IsDefined(delay) && delay.min > 0 && delay.max > 0 {
      result = this.RandomInRange(delay.min, delay.max);
    } else {
      result = this.Tier(state.tierName).baseSaleDelay * this.ClassDelayPercent(vehicleClass) / 100 * this.RandomInRange(70, 130) / 100;
      if IsDefined(delay) && delay.multiplier > 0.0 { result = result * FloorF(delay.multiplier * 100.0) / 100; }
    }
    result = Min(Max(result, 3600), 345600);
    // Past the clamp, so the player's setting can go under the 1 hour floor
    return IsDefined(settings) ? RoundF(Cast<Float>(result) * ClampF(settings.saleDelayMultiplier, 0.1, 2.0)) : result;
  }

  private func ClassDelayPercent(vehicleClass: CName) -> Int32 {
    if Equals(vehicleClass, n"Economy") { return 50; }
    if Equals(vehicleClass, n"Standard") { return 70; }
    if Equals(vehicleClass, n"Premium") { return 130; }
    if Equals(vehicleClass, n"Exotic") { return 150; }
    if Equals(vehicleClass, n"Hyper") { return 200; }
    return 100;
  }

  /// "3h 20m", or "4m 10s" under an hour.
  public static func FormatTimeRemaining(totalSecs: Int32) -> String {
    if totalSecs <= 0 { return "0m 0s"; }
    let hours: Int32 = totalSecs / 3600;
    let minutes: Int32 = (totalSecs % 3600) / 60;
    if hours > 0 { return s"\(hours)h \(minutes)m"; }
    return s"\(minutes)m \(totalSecs % 60)s";
  }
}
