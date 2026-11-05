module Garage.Economy

import Garage.*
import Garage.Data.*
import Garage.Vehicle.*
import VehicleCore.Schema.*

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

/// What a car's worth before anyone takes a cut. Claims, sales, repairs and swaps all start here.
public class GarageCarValue extends IScriptable {
  public let base: Int32;
  public let risk: Float = 1.0;
  public let appearance: Float = 1.0;
  public let grade: Float = 1.0;
  public let type: Float = 1.0;
  public let special: Float = 1.0;

  public func Total() -> Float { return Cast<Float>(this.base) * this.risk * this.appearance * this.grade * this.type * this.special; }
}

/// A claim's price and how it got there. total = (value x rate + scrub) x market, never under floor
public class GarageClaimQuote extends IScriptable {
  public let value: ref<GarageCarValue>;
  public let tier: CName;
  public let rate: Float;
  public let scrub: Int32;
  public let scrubMultiplier: Float = 1.0;
  public let market: Float = 1.0;
  /// The car's undamaged sale price when the claim had to go up to it, else 0
  public let floor: Int32;
  public let total: Int32;
}

/// What a sale pays and how it got there. total = value x condition x tier x market + parts
public class GarageSaleQuote extends IScriptable {
  public let value: ref<GarageCarValue>;
  public let tierName: CName;
  public let parts: Int32;
  public let condition: Float = 1.0;
  public let tier: Float = 1.0;
  public let market: Float = 1.0;
  public let total: Int32;
}

/// A heat rush's price. The fee scales with the labour it replaces and how hot V is.
public class GarageRushQuote extends IScriptable {
  public let look: Int32;
  public let fee: Int32;
  public let markup: ref<GarageMarkup>;
  public let total: Int32;
}

/// total = (base + fee) x markup
public class GarageRepairQuote extends IScriptable {
  public let base: Int32;
  public let fee: Int32;
  public let markup: ref<GarageMarkup>;
  public let total: Int32;
}

/// What a garage does to the list price of anything V pays for there: its tier's pricing, its surcharge for this class
/// of car, less V's loyalty discount. Sales and claims never go through it, so it can't feed a money loop.
public class GarageMarkup extends IScriptable {
  public let tier: Float = 1.0;
  public let surcharge: Float = 1.0;
  /// 0 to 1
  public let discount: Float;

  public func Factor() -> Float { return this.tier * this.surcharge * (1.0 - this.discount); }

  public func Apply(amount: Int32) -> Int32 { return amount > 0 ? RoundF(Cast<Float>(amount) * this.Factor()) : amount; }

  /// "Loyalty: -12%", or "" with no discount.
  public func DiscountLine() -> String {
    let percent: Int32 = RoundF(this.discount * 100.0);
    return percent > 0 ? GarageText.Get(n"Garage-Price-LoyaltyLabel") + "-" + IntToString(percent) + "%" : "";
  }

  /// "Garage rate: x1.15" for the tier and surcharge together, or "" when they come to 1.
  public func RateLine() -> String {
    let rate: Float = this.tier * this.surcharge;
    return AbsF(rate - 1.0) > 0.001 ? GarageText.Get(n"Garage-Price-RateLabel") + "x" + FloatToStringPrec(rate, 2) : "";
  }

  /// The rate and loyalty lines that are worth showing, joined by separator. "" when neither is.
  public func Lines(separator: String) -> String {
    let rate: String = this.RateLine();
    let loyalty: String = this.DiscountLine();
    if StrLen(rate) == 0 { return loyalty; }
    return StrLen(loyalty) == 0 ? rate : rate + separator + loyalty;
  }
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
  public let rushFeeMultiplier: Float = 3.0;
  public let rushHeatStep: Float = 0.5;
  public let rushMinFee: Int32 = 500;
  public let rushMaxHeat: Int32 = 2;
  /// Counts unique_likely cars as unique: the ones that look like quest or gift cars but nobody's confirmed
  public let blockLikelyUnique: Bool = true;
  public let quickRepairMultiplier: Float = 0.1;
  public let fullRepairMultiplier: Float = 0.2;
  public let quickRepairFee: Int32 = 500;
  public let fullRepairFee: Int32 = 1500;
  public let repairCostMin: Int32 = 100;
  public let repairCostMax: Int32 = 50000;
  public let repairDelay: Float = 1.5;
  public let repairFadeHold: Float = 2.0;
  public let gradeMultipliers: array<ref<GaragePriceRule>>;
  public let appearanceMultipliers: array<ref<GarageAppearanceRule>>;
  public let appearanceFlags: array<ref<GaragePriceRule>>;
  public let typeMultipliers: array<ref<GaragePriceRule>>;
  public let flagMultipliers: array<ref<GaragePriceRule>>;
  public let tierSellPct: array<ref<GaragePriceRule>>;
  public let claimRates: array<ref<GaragePriceRule>>;
  public let vinScrubRates: array<ref<GaragePriceRule>>;
  /// The car value each tier starts at, for a car with no tier of its own
  public let valueTiers: array<ref<GaragePriceRule>>;
  public let serviceFees: array<ref<GaragePriceRule>>;
}

/// What a car's worth and what the work on it costs. A car's own data lives in TweakDB, so a mod sets it in its yaml:
///
///   Vehicle.my_car.dealerPrice: 60000
///   Vehicle.my_car.garageTier: "Exotic"
///   Vehicle.my_car.garageTags:
///     $type: array:String
///     $value: [v_sport1, no_claim]
///
/// Base value is the first of dealerPrice, the game's price through garagePriceAssignment, garageBasePrice, then the default.
/// Tags are what prices.json multiplies by (typeMultipliers, flagMultipliers), plus no_claim, no_sell and unique (a quest or
/// gift car V can't get back: no sale, no new look). Vanilla cars get theirs from the generated r6/tweaks/garage_vehicle_pricing.yaml.
/// The tier is the car's VehicleCore schema tier, else garageTier, else where its value lands in prices.json's valueTiers.
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

  /// True when the price comes from the game or the car's mod, not a fallback. It already knows what kind of car it is, so grade, type and special don't apply.
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

  public func CanSell(record: TweakDBID) -> Bool { return !this.HasTag(record, "no_sell") && !this.IsUnique(record); }

  public func IsUnique(record: TweakDBID) -> Bool {
    let tags: array<String> = this.Tags(record);
    return ArrayContains(tags, "unique") || (this.Prices().blockLikelyUnique && ArrayContains(tags, "unique_likely"));
  }

  /// False for a car whose look has to stay the way the game gave it: a unique one, or one tagged fixed_look.
  public func CanRestyle(record: TweakDBID) -> Bool { return !this.IsUnique(record) && !this.HasTag(record, "fixed_look"); }

  // --- Value and tier

  public func Value(record: TweakDBID, appearance: CName) -> ref<GarageCarValue> {
    let prices: ref<GaragePrices> = this.Prices();
    let name: String = NameToString(appearance);
    let rule: ref<GarageAppearanceRule> = this.AppearanceRule(name);
    let value: ref<GarageCarValue> = new GarageCarValue();
    value.base = this.BaseValue(record);
    value.risk = IsDefined(rule) ? rule.sell : 1.0;
    value.appearance = this.Stacked(prices.appearanceFlags, name);
    if !this.IsGamePriced(record) {
      value.grade = this.Longest(prices.gradeMultipliers, name, 1.0);
      value.type = this.TypeMultiplier(record);
      value.special = this.FlagMultiplier(record);
    }
    return value;
  }

  public func CarValue(record: TweakDBID, appearance: CName) -> Float { return this.Value(record, appearance).Total(); }

  /// The tier every price table and garage gate uses for this car. n"Standard" when nothing says otherwise.
  public func TierOf(record: TweakDBID, appearance: CName) -> CName {
    let schemas: ref<VehicleSchemas> = VehicleSchemas.Get();
    let schema: ref<VehicleSchema> = IsDefined(schemas) ? schemas.GetSchemaByRecord(record) : null;
    if IsDefined(schema) && IsNameValid(schema.tier) { return schema.tier; }
    let own: String = TweakDBInterface.GetString(record + t".garageTier", "");
    if StrLen(own) > 0 { return StringToName(own); }
    let car: Float = this.CarValue(record, appearance);
    let tier: CName = n"Standard";
    let best: Float = 0.0;
    let prices: ref<GaragePrices> = this.Prices();
    for rule in prices.valueTiers {
      if car >= rule.value && rule.value >= best {
        tier = StringToName(rule.tier);
        best = rule.value;
      }
    }
    return tier;
  }

  // --- Prices

  public func ClaimPrice(record: TweakDBID, appearance: CName) -> Int32 { return this.QuoteClaim(record, appearance).total; }

  /// What claiming costs. A cop car isn't worth 20 times as much, but its VIN is that much harder to scrub.
  /// Never under what the car sells for undamaged, whatever the settings say.
  public func QuoteClaim(record: TweakDBID, appearance: CName) -> ref<GarageClaimQuote> {
    let prices: ref<GaragePrices> = this.Prices();
    let settings: ref<GarageSettings> = GarageSettings.Get();
    let rule: ref<GarageAppearanceRule> = this.AppearanceRule(NameToString(appearance));
    let quote: ref<GarageClaimQuote> = new GarageClaimQuote();
    quote.value = this.Value(record, appearance);
    quote.tier = this.TierOf(record, appearance);
    quote.rate = this.TierValue(prices.claimRates, quote.tier, 0.7);
    quote.scrubMultiplier = IsDefined(rule) ? rule.claim : 1.0;
    quote.market = IsDefined(settings) ? settings.claimPriceMultiplier : 1.0;
    let baseClaim: Int32 = FloorF(quote.value.Total() * quote.rate);
    quote.scrub = RoundF(Cast<Float>(baseClaim) * this.TierValue(prices.vinScrubRates, quote.tier, 0.1) * quote.scrubMultiplier);
    quote.total = Max(FloorF(Cast<Float>(baseClaim + quote.scrub) * quote.market), 1);
    let sale: ref<GarageSaleQuote> = this.QuoteSale(record, appearance, 1.0, 0);
    if sale.total > quote.total {
      quote.floor = sale.total;
      quote.total = sale.total;
    }
    return quote;
  }

  /// What a garage pays for a car. partsCost is what V paid for the parts (GarageParts.InstalledValue). They fetch a share
  /// of it, suffer the car's condition with it, and never fetch more. health is 0 to 1.
  public func QuoteSale(record: TweakDBID, appearance: CName, health: Float, partsCost: Int32) -> ref<GarageSaleQuote> {
    let prices: ref<GaragePrices> = this.Prices();
    let settings: ref<GarageSettings> = GarageSettings.Get();
    let quote: ref<GarageSaleQuote> = new GarageSaleQuote();
    quote.value = this.Value(record, appearance);
    quote.tierName = this.TierOf(record, appearance);
    quote.condition = prices.healthSellFloor + (1.0 - prices.healthSellFloor) * ClampF(health, 0.0, 1.0);
    quote.tier = this.TierValue(prices.tierSellPct, quote.tierName, 0.6);
    quote.market = IsDefined(settings) ? settings.salePriceMultiplier : 1.0;
    let cut: Float = quote.condition * quote.tier * quote.market;
    let cost: Int32 = Max(partsCost, 0);
    quote.parts = Min(FloorF(Cast<Float>(cost) * prices.partsResaleRate * cut), cost);
    quote.total = Max(FloorF(quote.value.Total() * cut) + quote.parts, 0);
    return quote;
  }

  /// A look swap's list price. Going to a look worth more costs what it'd add to a sale, on top of the fees.
  public func SwapCost(record: TweakDBID, current: CName, target: CName) -> Int32 {
    let prices: ref<GaragePrices> = this.Prices();
    let baseCost: Int32 = FloorF(this.CarValue(record, current) * prices.minServiceFeeRate);
    let sellCurrent: Int32 = this.QuoteSale(record, current, 1.0, 0).total;
    let sellTarget: Int32 = this.QuoteSale(record, target, 1.0, 0).total;
    let fee: Int32 = FloorF(Cast<Float>(sellTarget) * prices.customizationFeeRate);
    return baseCost + fee + Max(sellTarget - sellCurrent, 0);
  }

  /// SwapCost with garageId's markup on it, n"" for none.
  public func SwapPrice(record: TweakDBID, current: CName, target: CName, garageId: CName) -> Int32 {
    return this.Markup(garageId, this.TierOf(record, current)).Apply(this.SwapCost(record, current, target));
  }

  /// The one way a garage's own pricing reaches what V pays there. n"" or a garage it doesn't know marks nothing up.
  public func Markup(garageId: CName, vehicleClass: CName) -> ref<GarageMarkup> {
    let markup: ref<GarageMarkup> = new GarageMarkup();
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if !IsNameValid(garageId) || !IsDefined(engine) { return markup; }
    markup.tier = engine.GetPricingMultiplier(garageId);
    markup.surcharge = engine.GetSurchargeMultiplier(garageId, vehicleClass);
    markup.discount = ClampF(engine.GetPricingDiscount(garageId), 0.0, 1.0);
    return markup;
  }

  /// look is what the new look costs and labour what the fee scales from, both with markup already on them. Only the
  /// minimum fee still needs it. Heat 1 pays the plain multiplier, each level past it adds rushHeatStep.
  public func QuoteRush(look: Int32, labour: Int32, heat: Int32, markup: ref<GarageMarkup>) -> ref<GarageRushQuote> {
    let prices: ref<GaragePrices> = this.Prices();
    let hot: Float = 1.0 + Cast<Float>(Max(heat - 1, 0)) * prices.rushHeatStep;
    let quote: ref<GarageRushQuote> = new GarageRushQuote();
    quote.markup = IsDefined(markup) ? markup : new GarageMarkup();
    quote.look = look;
    quote.fee = Max(FloorF(Cast<Float>(labour) * prices.rushFeeMultiplier * hot), quote.markup.Apply(prices.rushMinFee));
    quote.total = look + quote.fee;
    return quote;
  }

  /// health is 0 to 1. garageId's service multiplier and markup apply, n"" for neither.
  public func QuoteRepair(record: TweakDBID, appearance: CName, health: Float, full: Bool, garageId: CName) -> ref<GarageRepairQuote> {
    let prices: ref<GaragePrices> = this.Prices();
    let settings: ref<GarageSettings> = GarageSettings.Get();
    let market: Float = IsDefined(settings) ? settings.repairPriceMultiplier : 1.0;
    let location: ref<GarageLocation> = IsNameValid(garageId) ? GarageSystem.Get().Data().GetLocation(garageId) : null;
    let garage: Float = IsDefined(location) ? location.economy.serviceMultiplier : 1.0;
    let rate: Float = full ? prices.fullRepairMultiplier : prices.quickRepairMultiplier;
    let damage: Float = 1.0 - ClampF(health, 0.0, 1.0);
    let quote: ref<GarageRepairQuote> = new GarageRepairQuote();
    quote.base = Max(prices.repairCostMin, Min(prices.repairCostMax, FloorF(this.CarValue(record, appearance) * damage * rate * garage * market)));
    quote.fee = full ? prices.fullRepairFee : prices.quickRepairFee;
    quote.markup = this.Markup(garageId, this.TierOf(record, appearance));
    quote.total = quote.markup.Apply(quote.base + quote.fee);
    return quote;
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
