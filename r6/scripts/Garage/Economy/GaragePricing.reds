module Garage.Economy

import Garage.*
import Garage.Vehicle.*

public class GaragePriceRule extends IScriptable {
  public let match: String;
  public let tag: String;
  public let tier: String;
  public let value: Float;
}

public class GarageAppearanceRule extends IScriptable {
  public let match: String;
  /// Multiplies the VIN scrub, since that's the work a hot car makes harder
  public let claim: Float = 1.0;
  public let sell: Float = 1.0;
}

/// A claim's price and how it got there. total = (base x rate + scrub) x market
public class GarageClaimQuote extends IScriptable {
  public let base: Int32;
  public let rate: Float;
  public let scrub: Int32;
  public let scrubMultiplier: Float = 1.0;
  public let market: Float = 1.0;
  public let total: Int32;
}

/// What a sale pays and how it got there. total = (base x risk x appearance x grade x type x special + parts) x condition x tier x market
public class GarageSaleQuote extends IScriptable {
  public let base: Int32;
  public let risk: Float = 1.0;
  public let appearance: Float = 1.0;
  public let grade: Float = 1.0;
  public let type: Float = 1.0;
  public let special: Float = 1.0;
  public let parts: Int32;
  public let condition: Float = 1.0;
  public let tier: Float = 1.0;
  public let market: Float = 1.0;
  public let total: Int32;
}

/// data/addons/prices.json, or the user's addons/prices.json in place of it.
public class GaragePrices extends IScriptable {
  public let format: String;
  public let version: Int32;
  public let defaultBasePrice: Int32 = 5000;
  public let defaultServiceFee: Int32 = 250;
  public let healthSellFloor: Float = 0.3;
  public let partsResaleRate: Float = 0.5;
  public let minServiceFeeRate: Float = 0.15;
  public let customizationFeeRate: Float = 0.08;
  public let gradeMultipliers: array<ref<GaragePriceRule>>;
  public let appearanceMultipliers: array<ref<GarageAppearanceRule>>;
  public let appearanceFlags: array<ref<GaragePriceRule>>;
  public let typeMultipliers: array<ref<GaragePriceRule>>;
  public let flagMultipliers: array<ref<GaragePriceRule>>;
  public let tierSellPct: array<ref<GaragePriceRule>>;
  public let claimRates: array<ref<GaragePriceRule>>;
  public let vinScrubRates: array<ref<GaragePriceRule>>;
  public let serviceFees: array<ref<GaragePriceRule>>;
}

/// What a car's worth and what the work on it costs. A car's own data lives in TweakDB, so a mod sets it in its yaml:
///
///   Vehicle.my_car.dealerPrice: 60000
///   Vehicle.my_car.garageTags:
///     $type: array:String
///     $value: [v_sport1, no_claim]
///
/// Base value is the first of dealerPrice, the game's price through garagePriceAssignment, garageBasePrice, then the default.
/// Tags are what prices.json multiplies by (typeMultipliers, flagMultipliers), plus no_claim and no_sell. Vanilla cars get
/// theirs from the generated r6/tweaks/garage_vehicle_pricing.yaml.
public class GaragePricing extends IScriptable {
  private let m_xu: ref<XUtilsMod>;
  private let m_prices: ref<GaragePrices>;

  public func Setup(xu: ref<XUtilsMod>) -> Void { this.m_xu = xu; }

  public func Prices() -> ref<GaragePrices> {
    if !IsDefined(this.m_prices) { this.Load(); }
    return this.m_prices;
  }

  private func Load() -> Void {
    let files: ref<XUtilsFiles> = this.m_xu.Files();
    let json: ref<XUtilsJson> = files.Exists("addons/prices.json") ? files.ReadJson("addons/prices.json") : XUtilsJson.Parse(files.ReadModResource("data/addons/prices.json"));
    let prices: ref<GaragePrices> = new GaragePrices();
    if !IsDefined(json) || !json.ToObject(prices) {
      this.m_xu.Log("Economy").Warn("couldn't read prices.json, nothing's got a multiplier");
      prices = new GaragePrices();
    }
    this.m_prices = prices;
  }

  public func Reload() -> Void { this.m_prices = null; }

  // --- A car's own data

  public func Tags(record: TweakDBID) -> array<String> {
    return TweakDBInterface.GetStringArray(record + t".garageTags");
  }

  public func HasTag(record: TweakDBID, tag: String) -> Bool {
    let tags: array<String> = this.Tags(record);
    return ArrayContains(tags, tag);
  }

  /// True when the price comes from the game or the car's mod, not a fallback. It already knows what kind of car it is, so a sale skips grade, type and special.
  public func IsGamePriced(record: TweakDBID) -> Bool {
    return TweakDBInterface.GetInt(record + t".dealerPrice", 0) > 0 || this.AssignedPrice(record) > 0;
  }

  public func BaseValue(record: TweakDBID) -> Int32 {
    let dealer: Int32 = TweakDBInterface.GetInt(record + t".dealerPrice", 0);
    if dealer > 0 { return dealer; }
    let assigned: Int32 = this.AssignedPrice(record);
    if assigned > 0 { return assigned; }
    let own: Int32 = TweakDBInterface.GetInt(record + t".garageBasePrice", 0);
    return own > 0 ? own : this.Prices().defaultBasePrice;
  }

  private func AssignedPrice(record: TweakDBID) -> Int32 {
    let assignment: String = TweakDBInterface.GetString(record + t".garagePriceAssignment", "");
    return StrLen(assignment) > 0 ? TweakDBInterface.GetInt(TDBID.Create(assignment + ".overrideValue"), 0) : 0;
  }

  /// Quest cars, AVs and the like are tagged out, and a record with no destroyed look isn't a car you could own.
  public func CanClaim(record: TweakDBID) -> Bool {
    if this.HasTag(record, "no_claim") { return false; }
    let vehicle: wref<Vehicle_Record> = TweakDBInterface.GetVehicleRecord(record);
    return IsDefined(vehicle) && IsNameValid(vehicle.DestroyedAppearance());
  }

  public func CanSell(record: TweakDBID) -> Bool { return !this.HasTag(record, "no_sell"); }

  // --- Prices

  public func ClaimPrice(record: TweakDBID, appearance: CName, tier: CName) -> Int32 {
    return this.QuoteClaim(record, appearance, tier).total;
  }

  /// What claiming costs. A cop car isn't worth 20 times as much, but its VIN is that much harder to scrub.
  public func QuoteClaim(record: TweakDBID, appearance: CName, tier: CName) -> ref<GarageClaimQuote> {
    let prices: ref<GaragePrices> = this.Prices();
    let settings: ref<GarageSettings> = GarageSettings.Get();
    let rule: ref<GarageAppearanceRule> = this.AppearanceRule(NameToString(appearance));
    let quote: ref<GarageClaimQuote> = new GarageClaimQuote();
    quote.base = this.BaseValue(record);
    quote.rate = this.TierValue(prices.claimRates, tier, 0.7);
    quote.scrubMultiplier = IsDefined(rule) ? rule.claim : 1.0;
    quote.market = IsDefined(settings) ? settings.claimPriceMultiplier : 1.0;
    let baseClaim: Int32 = FloorF(Cast<Float>(quote.base) * quote.rate);
    quote.scrub = RoundF(Cast<Float>(baseClaim) * this.TierValue(prices.vinScrubRates, tier, 0.1) * quote.scrubMultiplier);
    quote.total = Max(FloorF(Cast<Float>(baseClaim + quote.scrub) * quote.market), 1);
    return quote;
  }

  /// What a garage pays for a car. Parts fetch a share of what they cost and suffer the car's condition with it. health is 0 to 1.
  public func QuoteSale(record: TweakDBID, appearance: CName, tier: CName, health: Float, partsCost: Int32) -> ref<GarageSaleQuote> {
    let prices: ref<GaragePrices> = this.Prices();
    let settings: ref<GarageSettings> = GarageSettings.Get();
    let name: String = NameToString(appearance);
    let rule: ref<GarageAppearanceRule> = this.AppearanceRule(name);
    let quote: ref<GarageSaleQuote> = new GarageSaleQuote();
    quote.base = this.BaseValue(record);
    quote.risk = IsDefined(rule) ? rule.sell : 1.0;
    quote.appearance = this.Stacked(prices.appearanceFlags, name);
    if !this.IsGamePriced(record) {
      quote.grade = this.Longest(prices.gradeMultipliers, name, 1.0);
      quote.type = this.TypeMultiplier(record);
      quote.special = this.FlagMultiplier(record);
    }
    quote.parts = FloorF(Cast<Float>(Max(partsCost, 0)) * prices.partsResaleRate);
    quote.condition = prices.healthSellFloor + (1.0 - prices.healthSellFloor) * ClampF(health, 0.0, 1.0);
    quote.tier = this.TierValue(prices.tierSellPct, tier, 0.6);
    quote.market = IsDefined(settings) ? settings.salePriceMultiplier : 1.0;
    let car: Float = Cast<Float>(quote.base) * quote.risk * quote.appearance * quote.grade * quote.type * quote.special;
    quote.total = Max(FloorF((car + Cast<Float>(quote.parts)) * quote.condition * quote.tier * quote.market), 0);
    return quote;
  }

  /// What Swap compares two looks by. Every multiplier applies, whatever the price's source. health is 0 to 1.
  public func SellValue(record: TweakDBID, appearance: CName, tier: CName, health: Float, partsCost: Int32) -> Int32 {
    let prices: ref<GaragePrices> = this.Prices();
    let name: String = NameToString(appearance);
    let rule: ref<GarageAppearanceRule> = this.AppearanceRule(name);
    let value: Float = Cast<Float>(this.BaseValue(record) + partsCost);
    value *= IsDefined(rule) ? rule.sell : 1.0;
    value *= this.TagMultiplier(record);
    value *= this.Stacked(prices.appearanceFlags, name);
    value *= this.Longest(prices.gradeMultipliers, name, 1.0);
    value *= this.TierValue(prices.tierSellPct, tier, 0.6);
    value *= prices.healthSellFloor + (1.0 - prices.healthSellFloor) * ClampF(health, 0.0, 1.0);
    return FloorF(value);
  }

  /// Going to a look worth more costs the difference on top of the fees.
  public func SwapPrice(record: TweakDBID, current: CName, target: CName, tier: CName, health: Float, partsCost: Int32) -> Int32 {
    let prices: ref<GaragePrices> = this.Prices();
    let baseCost: Int32 = FloorF(Cast<Float>(this.BaseValue(record)) * prices.minServiceFeeRate);
    let sellCurrent: Int32 = this.SellValue(record, current, tier, health, partsCost);
    let sellTarget: Int32 = this.SellValue(record, target, tier, health, partsCost);
    let fee: Int32 = FloorF(Cast<Float>(sellTarget) * prices.customizationFeeRate);
    return baseCost + fee + Max(sellTarget - sellCurrent, 0);
  }

  /// Labour for a part category. Charged on every part change.
  public func ServiceFee(subcategory: CName) -> Int32 {
    let prices: ref<GaragePrices> = this.Prices();
    let name: String = NameToString(subcategory);
    for rule in prices.serviceFees {
      if Equals(rule.match, name) { return RoundF(rule.value); }
    }
    return prices.defaultServiceFee;
  }

  // --- Rules

  private func TagMultiplier(record: TweakDBID) -> Float {
    return this.TypeMultiplier(record) * this.FlagMultiplier(record);
  }

  private func TypeMultiplier(record: TweakDBID) -> Float {
    let prices: ref<GaragePrices> = this.Prices();
    let tags: array<String> = this.Tags(record);
    for rule in prices.typeMultipliers {
      if ArrayContains(tags, rule.tag) { return rule.value; }
    }
    return 1.0;
  }

  private func FlagMultiplier(record: TweakDBID) -> Float {
    let prices: ref<GaragePrices> = this.Prices();
    let tags: array<String> = this.Tags(record);
    let result: Float = 1.0;
    for rule in prices.flagMultipliers {
      if ArrayContains(tags, rule.tag) { result *= rule.value; }
    }
    return result;
  }

  private func AppearanceRule(name: String) -> ref<GarageAppearanceRule> {
    let best: ref<GarageAppearanceRule>;
    let bestLength: Int32 = 0;
    let prices: ref<GaragePrices> = this.Prices();
    for rule in prices.appearanceMultipliers {
      if StrLen(rule.match) > bestLength && StrContains(name, rule.match) {
        best = rule;
        bestLength = StrLen(rule.match);
      }
    }
    return best;
  }

  private func Longest(rules: array<ref<GaragePriceRule>>, name: String, fallback: Float) -> Float {
    let result: Float = fallback;
    let bestLength: Int32 = 0;
    for rule in rules {
      if StrLen(rule.match) > bestLength && StrContains(name, rule.match) {
        result = rule.value;
        bestLength = StrLen(rule.match);
      }
    }
    return result;
  }

  private func Stacked(rules: array<ref<GaragePriceRule>>, name: String) -> Float {
    let result: Float = 1.0;
    for rule in rules {
      if StrContains(name, rule.match) { result *= rule.value; }
    }
    return result;
  }

  // A tier with no entry pays what Standard does
  private func TierValue(rules: array<ref<GaragePriceRule>>, tier: CName, fallback: Float) -> Float {
    let name: String = NameToString(tier);
    let standard: Float = fallback;
    for rule in rules {
      if Equals(rule.tier, name) { return rule.value; }
      if Equals(rule.tier, "Standard") { standard = rule.value; }
    }
    return standard;
  }
}
