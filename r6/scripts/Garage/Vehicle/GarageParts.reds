module Garage.Vehicle

import Garage.*
import Garage.Data.*
import Garage.Economy.*
import Garage.World.*
import VehicleCore.*
import VehicleCore.Features.*
import VehicleCore.Schema.*

/// One row of a part picker.
public class GarageChoiceInfo extends IScriptable {
  public let id: CName;
  public let name: String;
  public let description: String;
  public let price: Int32;
  public let serviceFee: Int32;
  public let status: EGaragePartStatus;
  public let swatch: String;
}

/// A category, or a group of them, on a section's list.
public class GarageCategoryInfo extends IScriptable {
  public let id: CName;
  public let name: String;
  public let isColor: Bool;
}

/// e.g. meta on a parts transaction, what the exit summary counts.
public class GaragePartsMeta extends IScriptable {
  public let items: Int32;
}

/// What this visit has bought, for the exit summary. Refunds come back off it.
public class GarageVisitTotals extends IScriptable {
  public let parts: Int32;
  public let partsCost: Int32;
  /// The only thing bought was the Quick addon's rush, which posts its own banner.
  public let quickServiceOnly: Bool;
}

// One slot's starting point. A slot owns its cart entry and whatever that entry forced in, and a new pick there starts from
// installed for all of them, so stale forced parts (an old rim size) can't leak into the result
public class GaragePartsContext extends IScriptable {
  public let slot: CName;
  public let targets: array<CName>;
  public let owned: array<CName>;
  public let installed: ref<GarageChoices>;
  public let plan: ref<GarageChoices>;
  public let base: ref<GarageChoices>;
  public let released: array<CName>;
}

public class GaragePartsResult extends IScriptable {
  public let changes: ref<GarageChoices>;
  public let final: ref<GarageChoices>;
  // Every category this pick decides that isn't its own: forced parts, plus parts the slot lets go of
  public let touched: array<CName>;
}

public class GaragePreviewEffect extends IScriptable {
  public let slot: CName;
  public let categories: array<CName>;
}

/// One car's parts during a garage visit: what's on it, what a pick would drag along, previews and checkout. Icons, popups and
/// the cart all read the same evaluation. The preview on the car is the planned car (installed plus cart) with the active pick
/// and everything it forces on top. A category id can also be a group from the schema, which stands for all its targets.
public class GarageParts extends IScriptable {
  private let m_vehicle: wref<VehicleObject>;
  private let m_schema: ref<VehicleSchema>;
  private let m_system: wref<VCSystem>;
  private let m_constraints: ref<GarageConstraints>;
  private let m_location: ref<GarageLocation>;
  private let m_cart: ref<GarageCart>;
  private let m_effects: array<ref<GaragePreviewEffect>>;
  private let m_purchases: ref<GarageChoices>;
  private let m_totals: ref<GarageVisitTotals>;

  /// False for a car with no schema, which only gets the trade services.
  public func Begin(vehicle: wref<VehicleObject>, location: ref<GarageLocation>) -> Bool {
    this.End();
    this.m_vehicle = vehicle;
    this.m_location = location;
    this.m_cart = new GarageCart();
    this.m_purchases = new GarageChoices();
    this.m_totals = new GarageVisitTotals();
    let schemas: ref<VehicleSchemas> = VehicleSchemas.Get();
    this.m_schema = IsDefined(schemas) && IsDefined(vehicle) ? schemas.GetSchemaByRecord(vehicle.GetRecordID()) : null;
    this.m_system = VCSystem.Get(GetGameInstance());
    if !IsDefined(this.m_schema) || !IsDefined(this.m_system) { return false; }
    this.m_constraints = GarageConstraints.For(this.m_schema);
    this.m_system.ClearPreview(this.m_schema.id);
    return true;
  }

  public func End() -> Void {
    this.m_vehicle = null;
    this.m_schema = null;
    this.m_constraints = null;
    this.m_location = null;
    ArrayClear(this.m_effects);
  }

  /// The banner for leaving, if parts were bought. Services, claims, sales and rushes post their own.
  public func PostExitSummary() -> Void {
    let totals: ref<GarageVisitTotals> = this.m_totals;
    if !IsDefined(totals) || totals.parts <= 0 || totals.quickServiceOnly { return; }
    let cost: String = GarageText.Price(totals.partsCost);
    let text: String = totals.parts == 1 ? GarageText.Format(n"Garage-Notify-SinglePartPurchased", [cost])
                                         : GarageText.Format(n"Garage-Notify-MultiPartPurchased", [IntToString(totals.parts), cost]);
    XUtils.Mod("Garage").Screen().Notify(text, SimpleMessageType.Money, 5.0, false);
  }

  public func Schema() -> ref<VehicleSchema> { return this.m_schema; }

  public func Cart() -> ref<GarageCart> { return this.m_cart; }

  public func Totals() -> ref<GarageVisitTotals> { return this.m_totals; }

  /// Counts what a transaction did to this visit's parts.
  public func OnTransaction(data: ref<GarageTransactionData>) -> Void {
    if !IsDefined(this.m_totals) || !Equals(data.refundOf, EGarageTxKind.Parts) { return; }
    let meta: ref<GaragePartsMeta> = data.meta as GaragePartsMeta;
    let items: Int32 = IsDefined(meta) ? meta.items : 1;
    let refund: Bool = Equals(data.kind, EGarageTxKind.Refund);
    this.m_totals.parts = Max(this.m_totals.parts + (refund ? -items : items), 0);
    this.m_totals.partsCost = Max(this.m_totals.partsCost + (refund ? -data.amount : data.amount), 0);
  }

  // --- Groups

  public func Group(id: CName) -> ref<VehicleGroup> {
    if !IsDefined(this.m_schema) { return null; }
    let groups: array<ref<VehicleGroup>> = this.m_schema.GetGroups();
    for group in groups {
      if Equals(group.id, id) { return group; }
    }
    return null;
  }

  public func GroupOf(category: CName) -> ref<VehicleGroup> {
    if !IsDefined(this.m_schema) { return null; }
    let groups: array<ref<VehicleGroup>> = this.m_schema.GetGroups();
    for group in groups {
      if ArrayContains(group.targets, category) { return group; }
    }
    return null;
  }

  public func Targets(id: CName) -> array<CName> {
    let group: ref<VehicleGroup> = this.Group(id);
    if IsDefined(group) { return group.targets; }
    let single: array<CName> = [id];
    return single;
  }

  // --- What's on the car

  public func Installed() -> ref<GarageChoices> {
    let settings: ref<GarageChoices> = new GarageChoices();
    for category in this.m_schema.categories {
      let value: CName = this.m_system.GetSettingOrDefault(this.m_schema.id, category.id);
      if IsNameValid(value) { settings.Set(category.id, value); }
    }
    return settings;
  }

  private func Planned(installed: ref<GarageChoices>) -> ref<GarageChoices> {
    let plan: ref<GarageChoices> = installed.Copy();
    let items: array<ref<GarageCartItem>> = this.m_cart.Items();
    for item in items {
      let targets: array<CName> = this.Targets(item.category);
      for target in targets { plan.Set(target, item.choice); }
    }
    return plan;
  }

  /// What the picker should mark as current. n"" for a group whose targets differ.
  public func CurrentChoice(id: CName) -> CName {
    if !IsDefined(this.m_schema) { return n""; }
    let targets: array<CName> = this.Targets(id);
    let first: CName = this.CurrentOne(targets[0]);
    for target in targets {
      if !Equals(this.CurrentOne(target), first) { return n""; }
    }
    return first;
  }

  private func CurrentOne(category: CName) -> CName {
    let bought: CName = this.m_purchases.Get(category);
    return IsNameValid(bought) ? bought : this.m_system.GetSettingOrDefault(this.m_schema.id, category);
  }

  public func IsPaint(category: CName) -> Bool { return Equals(category, n"car_paint") || Equals(category, n"car_secpaint"); }

  public func Status(category: CName, choice: CName) -> EGaragePartStatus {
    if this.IsPaint(category) { return EGaragePartStatus.Unowned; }
    if this.IsStock(category, choice) { return EGaragePartStatus.Stock; }
    return this.m_system.OwnsPartCName(this.m_schema.id, category, choice) ? EGaragePartStatus.Owned : EGaragePartStatus.Unowned;
  }

  private func IsStock(category: CName, choice: CName) -> Bool {
    let fallback: CName = this.m_system.GetDefaultCName(this.m_schema.id, category);
    if IsNameValid(fallback) { return Equals(fallback, choice); }
    if Equals(choice, n"OptionNone") || Equals(choice, n"Stock") || Equals(choice, n"Default") { return true; }
    let definition: ref<VehicleCategory> = this.m_schema.GetCategory(category);
    let name: String = IsDefined(definition) ? StrLower(definition.GetChoiceName(choice)) : "";
    return StrBeginsWith(name, "no ") || StrBeginsWith(name, "none") || StrContains(name, "stock") || StrContains(name, "default")
           || StrContains(name, "original") || StrContains(name, "factory");
  }

  private func GroupStatus(targets: array<CName>, choice: CName) -> EGaragePartStatus {
    let allStock: Bool = true;
    let allOwned: Bool = true;
    for target in targets {
      let status: EGaragePartStatus = this.Status(target, choice);
      if !Equals(status, EGaragePartStatus.Stock) { allStock = false; }
      if !Equals(status, EGaragePartStatus.Owned) { allOwned = false; }
    }
    if allStock { return EGaragePartStatus.Stock; }
    return allOwned ? EGaragePartStatus.Owned : EGaragePartStatus.Unowned;
  }

  // --- Lists and prices

  private func FeeMultiplier(tier: CName) -> Float {
    let settings: ref<GarageSettings> = GarageSettings.Get();
    let name: String = NameToString(tier);
    if IsDefined(settings) && settings.tierMultiplierEnabled { return settings.GetTierMultiplier(name); }
    if Equals(name, "Classic") { return 0.80; }
    if Equals(name, "Sport") { return 0.90; }
    if Equals(name, "Premium") { return 1.15; }
    if Equals(name, "Exotic") { return 1.35; }
    if Equals(name, "Hyper") { return 1.60; }
    return 1.0;
  }

  /// Labour for a category or a whole group, with the car's tier and this garage's multiplier on it.
  public func ServiceFee(id: CName) -> Int32 {
    let pricing: ref<GaragePricing> = GarageSystem.Get().Pricing();
    let raw: Int32 = 0;
    let targets: array<CName> = this.Targets(id);
    for target in targets { raw += pricing.ServiceFee(target); }
    let garage: Float = IsDefined(this.m_location) ? this.m_location.economy.serviceMultiplier : 1.0;
    return FloorF(Cast<Float>(raw) * this.FeeMultiplier(IsDefined(this.m_schema) ? this.m_schema.tier : n"") * garage);
  }

  /// A section's categories and the groups whose targets all exist on this car, sorted by name.
  public func CategoriesIn(section: CName) -> array<ref<GarageCategoryInfo>> {
    let list: array<ref<GarageCategoryInfo>>;
    if !IsDefined(this.m_schema) { return list; }
    for category in this.m_schema.categories {
      if Equals(category.section, section) { this.InsertSorted(list, category.id, category.GetName(), category.IsColor()); }
    }
    let groups: array<ref<VehicleGroup>> = this.m_schema.GetGroups();
    for group in groups {
      if Equals(group.section, section) && this.AllExist(group.targets) {
        this.InsertSorted(list, group.id, group.GetName(), Equals(group.type, VehicleCategoryType.Color));
      }
    }
    return list;
  }

  private func AllExist(targets: array<CName>) -> Bool {
    for target in targets {
      if !IsDefined(this.m_schema.GetCategory(target)) { return false; }
    }
    return true;
  }

  private func InsertSorted(out list: array<ref<GarageCategoryInfo>>, id: CName, name: String, isColor: Bool) -> Void {
    let info: ref<GarageCategoryInfo> = new GarageCategoryInfo();
    info.id = id;
    info.name = name;
    info.isColor = isColor;
    let lower: String = StrLower(name);
    let at: Int32 = 0;
    while at < ArraySize(list) && StrCmp(StrLower(list[at].name), lower) <= 0 { at += 1; }
    ArrayInsert(list, at, info);
  }

  /// The choices for a category or group. A group shows its source's list and costs the sum of its targets.
  public func Choices(id: CName) -> array<ref<GarageChoiceInfo>> {
    let list: array<ref<GarageChoiceInfo>>;
    if !IsDefined(this.m_schema) { return list; }
    let group: ref<VehicleGroup> = this.Group(id);
    let source: ref<VehicleCategory> = this.m_schema.GetCategory(IsDefined(group) ? group.source : id);
    if !IsDefined(source) { return list; }
    let fee: Int32 = this.ServiceFee(id);
    let targets: array<CName> = this.Targets(id);
    for choice in source.choices {
      let info: ref<GarageChoiceInfo> = new GarageChoiceInfo();
      info.id = choice.id;
      info.name = source.GetChoiceName(choice.id);
      info.description = source.GetChoiceDescription(choice.id);
      info.serviceFee = fee;
      info.swatch = choice.swatch;
      if IsDefined(group) {
        info.status = this.GroupStatus(targets, choice.id);
        info.price = this.GroupPrice(targets, choice);
      } else {
        info.status = this.Status(id, choice.id);
        info.price = choice.price;
      }
      ArrayPush(list, info);
    }
    return list;
  }

  // A target that doesn't list the choice costs what the source says
  private func GroupPrice(targets: array<CName>, choice: ref<VehicleChoice>) -> Int32 {
    let total: Int32 = 0;
    for target in targets {
      let category: ref<VehicleCategory> = this.m_schema.GetCategory(target);
      total += IsDefined(category) && category.HasChoice(choice.id) ? category.GetPrice(choice.id) : choice.price;
    }
    return total;
  }

  // --- What a pick does

  private func Context(slot: CName) -> ref<GaragePartsContext> {
    let context: ref<GaragePartsContext> = new GaragePartsContext();
    context.slot = slot;
    context.targets = this.Targets(slot);
    context.owned = context.targets;
    if !ArrayContains(context.owned, slot) { ArrayPush(context.owned, slot); }
    context.installed = this.Installed();
    context.plan = this.Planned(context.installed);
    context.base = context.plan.Copy();
    let items: array<ref<GarageCartItem>> = this.m_cart.Items();
    for item in items {
      if ArrayContains(context.owned, item.category) || (IsNameValid(item.source) && ArrayContains(context.owned, item.source)) {
        let targets: array<CName> = this.Targets(item.category);
        for target in targets {
          context.base.Set(target, context.installed.Get(target));
          if !ArrayContains(context.owned, target) && !ArrayContains(context.released, target) { ArrayPush(context.released, target); }
        }
      }
    }
    return context;
  }

  private func ResolveTargets(targets: array<CName>, choice: CName, base: ref<GarageChoices>, out settings: ref<GarageChoices>) -> ref<GarageChoices> {
    let changes: ref<GarageChoices> = new GarageChoices();
    settings = base.Copy();
    for target in targets {
      changes.Set(target, choice);
      settings.Set(target, choice);
    }
    for target in targets {
      let resolved: ref<GarageChoices> = this.m_constraints.ResolveAll(target, choice, settings);
      let i: Int32 = 0;
      while i < ArraySize(resolved.categories) {
        let category: CName = resolved.categories[i];
        if !ArrayContains(targets, category) {
          changes.Set(category, resolved.choices[i]);
          settings.Set(category, resolved.choices[i]);
        }
        i += 1;
      }
    }
    return changes;
  }

  // A sibling a constraint forces along (the front rim drags the rear to a new size) gets the same rim when it fits, instead of
  // the constraint's fallback
  private func ResolveSelection(targets: array<CName>, choice: CName, base: ref<GarageChoices>) -> ref<GarageChoices> {
    let settings: ref<GarageChoices>;
    let changes: ref<GarageChoices> = this.ResolveTargets(targets, choice, base, settings);
    let widened: array<CName> = targets;
    for target in targets {
      let group: ref<VehicleGroup> = this.GroupOf(target);
      if IsDefined(group) {
        for sibling in group.targets {
          let category: ref<VehicleCategory> = this.m_schema.GetCategory(sibling);
          if !ArrayContains(widened, sibling) && changes.Has(sibling) && !Equals(changes.Get(sibling), choice) && IsDefined(category) && category.HasChoice(choice) {
            ArrayPush(widened, sibling);
          }
        }
      }
    }
    if ArraySize(widened) == ArraySize(targets) { return changes; }
    let wideSettings: ref<GarageChoices>;
    let wideChanges: ref<GarageChoices> = this.ResolveTargets(widened, choice, base, wideSettings);
    for target in widened {
      let conflicts: array<ref<GarageConflict>> = this.m_constraints.Conflicts(target, choice, wideSettings);
      if ArraySize(conflicts) > 0 { return changes; }
    }
    return wideChanges;
  }

  private func Evaluate(context: ref<GaragePartsContext>, choice: CName) -> ref<GaragePartsResult> {
    let result: ref<GaragePartsResult> = new GaragePartsResult();
    result.changes = this.ResolveSelection(context.targets, choice, context.base);
    result.final = context.base.Copy();
    result.touched = context.released;
    let i: Int32 = 0;
    while i < ArraySize(result.changes.categories) {
      let category: CName = result.changes.categories[i];
      result.final.Set(category, result.changes.choices[i]);
      if !ArrayContains(context.targets, category) && !ArrayContains(result.touched, category) { ArrayPush(result.touched, category); }
      i += 1;
    }
    return result;
  }

  /// True when picking this would change a part other than its own, for the picker's warning icon.
  public func WouldForceOthers(id: CName, choice: CName) -> Bool {
    if !IsDefined(this.m_schema) { return false; }
    let context: ref<GaragePartsContext> = this.Context(id);
    let result: ref<GaragePartsResult> = this.Evaluate(context, choice);
    for category in result.touched {
      if !Equals(result.final.Get(category), context.plan.Get(category)) { return true; }
    }
    return false;
  }

  /// The other parts this pick would force, for the popup that asks first.
  public func ForcedBy(id: CName, choice: CName) -> ref<GarageChoices> {
    let forced: ref<GarageChoices> = new GarageChoices();
    if !IsDefined(this.m_schema) { return forced; }
    let context: ref<GaragePartsContext> = this.Context(id);
    let result: ref<GaragePartsResult> = this.Evaluate(context, choice);
    let i: Int32 = 0;
    while i < ArraySize(result.changes.categories) {
      if !ArrayContains(context.targets, result.changes.categories[i]) { forced.Set(result.changes.categories[i], result.changes.choices[i]); }
      i += 1;
    }
    return forced;
  }

  /// Cart entries this pick would replace or drop, its own slot included.
  public func CartConflicts(id: CName, choice: CName) -> array<ref<GarageCartItem>> {
    let conflicts: array<ref<GarageCartItem>>;
    if !IsDefined(this.m_schema) { return conflicts; }
    let result: ref<GaragePartsResult> = this.Evaluate(this.Context(id), choice);
    let items: array<ref<GarageCartItem>> = this.m_cart.Items();
    for item in items {
      let differs: Bool = false;
      let targets: array<CName> = this.Targets(item.category);
      for target in targets {
        if !Equals(result.final.Get(target), item.choice) { differs = true; }
      }
      if differs { ArrayPush(conflicts, item); }
    }
    return conflicts;
  }

  // --- Previews

  private func ApplyPreview(values: ref<GarageChoices>, ids: array<CName>) -> Bool {
    let changed: String = "";
    for category in ids {
      let value: CName = values.Get(category);
      if IsNameValid(value) {
        this.m_system.SetPreviewCName(this.m_schema.id, category, value);
        changed += (StrLen(changed) > 0 ? "|" : "") + NameToString(category);
      }
    }
    if StrLen(changed) == 0 { return false; }
    let vehicle: wref<VehicleObject> = this.m_vehicle;
    if IsDefined(vehicle) { VehicleRefresh.Parts(vehicle, changed); }
    return true;
  }

  private func EffectOf(slot: CName) -> ref<GaragePreviewEffect> {
    for effect in this.m_effects {
      if Equals(effect.slot, slot) { return effect; }
    }
    return null;
  }

  /// Shows the pick and what it drags along. Last pick's extras this one doesn't decide fall back to the base.
  public func Preview(id: CName, choice: CName) -> Bool {
    if !IsDefined(this.m_schema) { return false; }
    let context: ref<GaragePartsContext> = this.Context(id);
    let result: ref<GaragePartsResult> = this.Evaluate(context, choice);
    let effect: ref<GaragePreviewEffect> = this.EffectOf(id);
    if !IsDefined(effect) {
      effect = new GaragePreviewEffect();
      effect.slot = id;
      ArrayPush(this.m_effects, effect);
    }
    for category in result.touched {
      if !ArrayContains(effect.categories, category) { ArrayPush(effect.categories, category); }
    }
    let ids: array<CName> = effect.categories;
    for target in context.targets {
      if !ArrayContains(ids, target) { ArrayPush(ids, target); }
    }
    return this.ApplyPreview(result.final, ids);
  }

  /// Puts these slots and what their previews dragged along back to the planned car, in one refresh.
  public func RevertPreviews(slots: array<CName>) -> Bool {
    if !IsDefined(this.m_schema) { return false; }
    let ids: array<CName>;
    for slot in slots {
      let effect: ref<GaragePreviewEffect> = this.EffectOf(slot);
      if IsDefined(effect) {
        for category in effect.categories {
          if !ArrayContains(ids, category) { ArrayPush(ids, category); }
        }
        ArrayRemove(this.m_effects, effect);
      }
      let targets: array<CName> = this.Targets(slot);
      for target in targets {
        if !ArrayContains(ids, target) { ArrayPush(ids, target); }
      }
    }
    return this.ApplyPreview(this.Planned(this.Installed()), ids);
  }

  public func RevertPreview(slot: CName) -> Bool {
    let slots: array<CName> = [slot];
    return this.RevertPreviews(slots);
  }

  /// Drops every unbought preview. The caller refreshes the car.
  public func RevertAll() -> Void {
    if IsDefined(this.m_schema) { this.m_system.ClearPreview(this.m_schema.id); }
    this.m_purchases = new GarageChoices();
    ArrayClear(this.m_effects);
  }

  // --- The cart

  private func AddItem(category: CName, choice: CName, opt source: CName) -> Void {
    let definition: ref<VehicleCategory> = this.m_schema.GetCategory(category);
    if !IsDefined(definition) { return; }
    let status: EGaragePartStatus = this.Status(category, choice);
    let price: Int32 = Equals(status, EGaragePartStatus.Unowned) ? definition.GetPrice(choice) : 0;
    this.m_cart.Add(category, choice, definition.GetName() + " - " + definition.GetChoiceName(choice), price, this.ServiceFee(category), status, source);
  }

  /// Puts a pick in the cart at the price it shows, then whatever it forces, and drops anything it leaves impossible.
  public func AddToCart(id: CName, choice: CName, name: String, price: Int32, serviceFee: Int32, status: EGaragePartStatus) -> Void {
    if !IsDefined(this.m_schema) { return; }
    let forced: ref<GarageChoices> = this.ForcedBy(id, choice);
    this.SplitGroupFor(id);
    this.m_cart.Add(id, choice, name, price, serviceFee, status);
    this.AddForced(id, choice, forced);
  }

  // A group's cart entry becomes one per target, so a single target can change on its own
  private func SplitGroupFor(category: CName, opt skip: CName) -> Bool {
    let group: ref<VehicleGroup> = this.GroupOf(category);
    if !IsDefined(group) || Equals(group.id, category) { return false; }
    let entry: ref<GarageCartItem> = this.m_cart.ItemFor(group.id);
    if !IsDefined(entry) { return false; }
    let choice: CName = entry.choice;
    this.m_cart.Remove(group.id);
    for target in group.targets {
      if !Equals(target, category) && !Equals(target, skip) { this.AddItem(target, choice); }
    }
    return true;
  }

  private func AddForced(source: CName, choice: CName, forced: ref<GarageChoices>) -> Void {
    let context: ref<GaragePartsContext> = this.Context(source);
    let final: ref<GarageChoices> = this.Evaluate(context, choice).final;
    for owner in context.owned { this.m_cart.RemoveForcedBy(owner); }
    let i: Int32 = 0;
    while i < ArraySize(forced.categories) {
      this.SplitGroupFor(forced.categories[i], forced.categories[i]);
      this.AddItem(forced.categories[i], forced.choices[i], source);
      i += 1;
    }
    // Safety net for an entry no constraint could resolve around: drop it rather than sell a broken car
    let dropped: array<CName>;
    let items: array<ref<GarageCartItem>> = this.m_cart.Items();
    for item in items {
      if !ArrayContains(context.owned, item.category) && !Equals(item.source, source) {
        let conflicts: array<ref<GarageConflict>> = this.m_constraints.Conflicts(item.category, item.choice, final);
        if ArraySize(conflicts) > 0 {
          this.m_cart.RemoveForcedBy(item.category);
          this.m_cart.Remove(item.category);
          let targets: array<CName> = this.Targets(item.category);
          for target in targets { ArrayPush(dropped, target); }
        }
      }
    }
    if ArraySize(dropped) > 0 { this.ApplyPreview(this.Planned(context.installed), dropped); }
  }

  // --- Buying

  private func Apply(id: CName, choice: CName, status: EGaragePartStatus) -> Void {
    let targets: array<CName> = this.Targets(id);
    for target in targets {
      if Equals(status, EGaragePartStatus.Unowned) && !this.IsPaint(target) { this.m_system.AddOwnedPartCName(this.m_schema.id, target, choice); }
      this.m_system.SetSettingCName(this.m_schema.id, target, choice);
      // The preview layer beats saved settings, so it has to agree with what was just bought
      this.m_system.SetPreviewCName(this.m_schema.id, target, choice);
      this.m_purchases.Set(target, choice);
    }
    this.m_purchases.Set(id, choice);
  }

  private func Charge(amount: Int32, items: Int32, kind: EGarageTxKind, source: CName) -> Bool {
    let meta: ref<GaragePartsMeta> = new GaragePartsMeta();
    meta.items = items;
    let garage: CName = IsDefined(this.m_location) ? this.m_location.id : n"";
    let receipt: ref<GarageReceipt> = GarageTransactions.Charge(garage, amount, kind, source, meta);
    if receipt.ok { return true; }
    let key: CName = Equals(receipt.error, n"insufficient_funds") ? n"Garage-Notify-InsufficientFunds" : n"Garage-Notify-TransactionFailed";
    XUtils.Mod("Garage").Screen().Notify(GarageText.Get(key), SimpleMessageType.Negative, 3.0, true);
    return false;
  }

  /// One part, right now.
  public func Purchase(id: CName, choice: CName, totalCost: Int32, status: EGaragePartStatus) -> Bool {
    if !IsDefined(this.m_schema) || !this.Charge(totalCost, 1, EGarageTxKind.Parts, n"aftermarket") { return false; }
    this.Apply(id, choice, status);
    return true;
  }

  /// Checks out the cart. Nothing's applied unless the money moved.
  public func Checkout() -> Bool {
    if !IsDefined(this.m_schema) || this.m_cart.Count() == 0 { return false; }
    let total: Int32 = this.m_cart.Total();
    let rush: Bool = this.m_cart.quickServicePending;
    if !this.Charge(total, this.m_cart.Count(), rush ? EGarageTxKind.Rush : EGarageTxKind.Parts, rush ? n"quick" : n"aftermarket") { return false; }
    let items: array<ref<GarageCartItem>> = this.m_cart.Items();
    for item in items { this.Apply(item.category, item.choice, item.status); }
    let vehicle: wref<VehicleObject> = this.m_vehicle;
    if IsDefined(vehicle) { VehicleRefresh.Vehicle(vehicle); }
    this.m_cart.Clear();
    return true;
  }
}
