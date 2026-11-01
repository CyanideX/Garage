module Garage.Vehicle

import Garage.*
import Garage.Data.*
import Garage.Economy.*
import Garage.Services.*
import Garage.UI.*
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
}

/// What never changes about a choice on a car. price is the whole group's for a group.
public class GaragePartData extends IScriptable {
  public let id: CName;
  public let name: String;
  public let description: String;
  public let price: Int32;
  public let swatch: String;
  public let tint: HDRColor;
  public let finish: CName;
  public let isStock: Bool;
}

public class GaragePartList extends IScriptable {
  public let finish: CName;
  public let parts: array<ref<GaragePartData>>;
}

/// Anything a picker can point at, a category or a group.
public class GaragePartsSlot extends IScriptable {
  public let id: CName;
  public let name: String;
  public let section: CName;
  public let isColor: Bool;
  public let group: ref<VehicleGroup>;
  public let source: ref<VehicleCategory>;
  public let targets: array<CName>;
  public let owned: array<CName>;
  // The groups with this one in their targets, more than one if the schema overlaps them
  public let holders: array<ref<GaragePartsSlot>>;
  // [0] is every choice, then one list per paint finish. Empty until something reads the slot, a car has a lot of names to look up
  public let lists: array<ref<GaragePartList>>;
  public let choiceIds: array<CName>;
}

public class GaragePartsSection extends IScriptable {
  public let id: CName;
  public let infos: array<ref<GarageCategoryInfo>>;
  public let lower: array<String>;
}

/// A schema worked out once, kept for the session since none of it changes between visits.
public class GaragePartsCatalog extends IScriptable {
  public let schema: ref<VehicleSchema>;
  public let constraints: ref<GarageConstraints>;
  private let m_categoryIds: array<CName>;
  private let m_ids: array<CName>;
  private let m_slots: array<ref<GaragePartsSlot>>;
  private let m_sections: array<ref<GaragePartsSection>>;

  public static func Create(schema: ref<VehicleSchema>) -> ref<GaragePartsCatalog> {
    let self: ref<GaragePartsCatalog> = new GaragePartsCatalog();
    self.schema = schema;
    self.constraints = GarageConstraints.For(schema);
    for category in schema.categories { ArrayPush(self.m_categoryIds, category.id); }
    // Groups first, so an id that's both reads as the group
    let groups: array<ref<VehicleGroup>> = schema.GetGroups();
    for group in groups { self.AddGroup(group); }
    for category in schema.categories { self.AddCategory(category); }
    for group in groups { self.LinkHolders(group); }
    return self;
  }

  public static func IsPaint(category: CName) -> Bool { return Equals(category, n"car_paint") || Equals(category, n"car_secpaint"); }

  private func AddGroup(group: ref<VehicleGroup>) -> Void {
    let slot: ref<GaragePartsSlot> = this.AddSlot(group.id);
    slot.name = group.GetName();
    slot.section = group.section;
    slot.isColor = Equals(group.type, VehicleCategoryType.Color);
    slot.group = group;
    slot.source = this.Category(group.source);
    slot.targets = group.targets;
    slot.owned = group.targets;
    if !ArrayContains(slot.owned, group.id) { ArrayPush(slot.owned, group.id); }
    let complete: Bool = true;
    for target in group.targets {
      if !ArrayContains(this.m_categoryIds, target) { complete = false; }
    }
    if complete { this.AddToSection(slot); }
  }

  private func AddCategory(category: ref<VehicleCategory>) -> Void {
    let slot: ref<GaragePartsSlot> = this.AddSlot(category.id);
    slot.name = category.GetName();
    slot.section = category.section;
    slot.isColor = category.IsColor();
    slot.source = category;
    ArrayPush(slot.targets, category.id);
    ArrayPush(slot.owned, category.id);
    this.AddToSection(slot);
  }

  private func AddSlot(id: CName) -> ref<GaragePartsSlot> {
    let slot: ref<GaragePartsSlot> = new GaragePartsSlot();
    slot.id = id;
    ArrayPush(this.m_ids, id);
    ArrayPush(this.m_slots, slot);
    return slot;
  }

  private func LinkHolders(group: ref<VehicleGroup>) -> Void {
    let holder: ref<GaragePartsSlot> = this.Slot(group.id);
    for target in group.targets {
      let slot: ref<GaragePartsSlot> = this.Slot(target);
      if IsDefined(slot) && !IsDefined(slot.group) { ArrayPush(slot.holders, holder); }
    }
  }

  private func AddToSection(slot: ref<GaragePartsSlot>) -> Void {
    let section: ref<GaragePartsSection> = this.Section(slot.section);
    if !IsDefined(section) {
      section = new GaragePartsSection();
      section.id = slot.section;
      ArrayPush(this.m_sections, section);
    }
    let info: ref<GarageCategoryInfo> = new GarageCategoryInfo();
    info.id = slot.id;
    info.name = slot.name;
    info.isColor = slot.isColor;
    let lower: String = StrLower(slot.name);
    let at: Int32 = 0;
    while at < ArraySize(section.lower) && StrCmp(section.lower[at], lower) <= 0 { at += 1; }
    ArrayInsert(section.infos, at, info);
    ArrayInsert(section.lower, at, lower);
  }

  public func Section(id: CName) -> ref<GaragePartsSection> {
    for section in this.m_sections {
      if Equals(section.id, id) { return section; }
    }
    return null;
  }

  public func Slot(id: CName) -> ref<GaragePartsSlot> {
    let at: Int32 = ArrayFindFirst(this.m_ids, id);
    return at >= 0 ? this.m_slots[at] : null;
  }

  public func Category(id: CName) -> ref<VehicleCategory> {
    let at: Int32 = ArrayFindFirst(this.m_categoryIds, id);
    return at >= 0 ? this.schema.categories[at] : null;
  }

  /// A finish narrows a colour slot's list, n"" or any other slot gets the lot.
  public func List(slot: ref<GaragePartsSlot>, finish: CName) -> ref<GaragePartList> {
    if ArraySize(slot.lists) == 0 { this.BuildLists(slot); }
    if !slot.isColor || !IsNameValid(finish) { return slot.lists[0]; }
    for list in slot.lists {
      if Equals(list.finish, finish) { return list; }
    }
    return new GaragePartList();
  }

  public func Part(slot: ref<GaragePartsSlot>, choice: CName) -> ref<GaragePartData> {
    if ArraySize(slot.lists) == 0 { this.BuildLists(slot); }
    let at: Int32 = ArrayFindFirst(slot.choiceIds, choice);
    return at >= 0 ? slot.lists[0].parts[at] : null;
  }

  private func BuildLists(slot: ref<GaragePartsSlot>) -> Void {
    ArrayPush(slot.lists, new GaragePartList());
    if !IsDefined(slot.source) { return; }
    let source: ref<VehicleCategory> = slot.source;
    let system: ref<VCSystem> = VCSystem.Get(GetGameInstance());
    for choice in source.choices {
      let part: ref<GaragePartData> = new GaragePartData();
      part.id = choice.id;
      part.name = source.GetChoiceName(choice.id);
      part.description = source.GetChoiceDescription(choice.id);
      part.swatch = choice.swatch;
      part.price = IsDefined(slot.group) ? this.GroupPrice(slot.targets, choice) : choice.price;
      part.isStock = true;
      for target in slot.targets {
        if GaragePartsCatalog.IsPaint(target) || !this.IsStock(system, target, choice.id) { part.isStock = false; }
      }
      ArrayPush(slot.choiceIds, choice.id);
      ArrayPush(slot.lists[0].parts, part);
      if slot.isColor {
        let name: String = NameToString(choice.id);
        part.tint = GarageColors.ResolveSwatch(choice.swatch, name);
        part.finish = StringToName(GarageColors.GetPaintType(name));
        ArrayPush(this.FinishList(slot, part.finish).parts, part);
      }
    }
  }

  private func FinishList(slot: ref<GaragePartsSlot>, finish: CName) -> ref<GaragePartList> {
    for list in slot.lists {
      if Equals(list.finish, finish) { return list; }
    }
    let added: ref<GaragePartList> = new GaragePartList();
    added.finish = finish;
    ArrayPush(slot.lists, added);
    return added;
  }

  // A target that doesn't list the choice costs what the source says
  private func GroupPrice(targets: array<CName>, choice: ref<VehicleChoice>) -> Int32 {
    let total: Int32 = 0;
    for target in targets {
      let category: ref<VehicleCategory> = this.Category(target);
      total += IsDefined(category) && category.HasChoice(choice.id) ? category.GetPrice(choice.id) : choice.price;
    }
    return total;
  }

  public func IsStock(system: ref<VCSystem>, category: CName, choice: CName) -> Bool {
    let fallback: CName = system.GetDefaultCName(this.schema.id, category);
    if IsNameValid(fallback) { return Equals(fallback, choice); }
    if Equals(choice, n"OptionNone") || Equals(choice, n"Stock") || Equals(choice, n"Default") { return true; }
    let definition: ref<VehicleCategory> = this.Category(category);
    let name: String = IsDefined(definition) ? StrLower(definition.GetChoiceName(choice)) : "";
    return StrBeginsWith(name, "no ") || StrBeginsWith(name, "none") || StrContains(name, "stock") || StrContains(name, "default")
           || StrContains(name, "original") || StrContains(name, "factory");
  }
}

// One slot's starting point. A slot owns its cart entry and whatever that entry forced in, and a new pick there starts from
// installed for all of them, so stale forced parts (an old rim size) can't leak into the result
public class GaragePartsContext extends IScriptable {
  public let slot: ref<GaragePartsSlot>;
  public let plan: ref<GarageChoices>;
  public let base: ref<GarageChoices>;
  public let released: array<CName>;
}

/// The car as it stands and as the cart would leave it. Rebuilt when the cart changes or something's bought, and shared until then.
public class GaragePlan extends IScriptable {
  public let stamp: Int32;
  public let cartRevision: Int32;
  public let installed: ref<GarageChoices>;
  public let planned: ref<GarageChoices>;
  public let contexts: array<ref<GaragePartsContext>>;
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

/// What a row on a picker shows after the name.
public enum EGaragePartBadge {
  Price = 0,
  Stock = 1,
  Owned = 2,
  Installed = 3,
  Cart = 4,
}

/// One row of parts.Rows.
public class GaragePartRow extends IScriptable {
  public let part: ref<GaragePartData>;
  public let status: EGaragePartStatus;
  public let badge: EGaragePartBadge;
  public let forcesOthers: Bool;
  public let serviceFee: Int32;
}

/// Another part a pick drags along. Going back to what's installed costs nothing and leaves no cart entry.
public class GaragePickPart extends IScriptable {
  public let category: CName;
  public let choice: CName;
  public let categoryName: String;
  public let entryName: String;
  public let price: Int32;
  public let serviceFee: Int32;
  public let status: EGaragePartStatus;
  public let backToInstalled: Bool;
}

/// Everything a pick would do, worked out once. Popups, Add to Cart and Buy Now all read this, so they can't disagree.
/// Good until the cart changes or something's bought, parts.IsCurrent says which.
public class GaragePick extends IScriptable {
  public let slot: CName;
  public let choice: CName;
  public let name: String;
  public let description: String;
  /// What goes in the cart for it, the category's name and the part's.
  public let cartName: String;
  public let status: EGaragePartStatus;
  /// 0 unless V has to buy it.
  public let price: Int32;
  public let serviceFee: Int32;
  public let forced: array<ref<GaragePickPart>>;
  public let forcedCost: Int32;
  /// The cart entries this replaces or drops, by name. A group that's only splitting is in kept instead.
  public let conflicts: array<String>;
  /// The categories that keep their own cart entry when a group entry splits for this.
  public let kept: array<String>;
  public let final: ref<GarageChoices>;
  public let touched: array<CName>;
  public let targets: array<CName>;
  public let owned: array<CName>;
  public let taken: array<CName>;
  public let splits: array<ref<GaragePartsSlot>>;
  public let clashes: array<CName>;
  public let isInstalled: Bool;
  public let isInCart: Bool;
  public let canAfford: Bool;
  public let stamp: Int32;

  public func OwnCost() -> Int32 { return this.price + this.serviceFee; }

  public func Total() -> Int32 { return this.OwnCost() + this.forcedCost; }

  /// True when something other than this part changes, so it's worth asking first.
  public func AsksFirst() -> Bool { return ArraySize(this.forced) > 0 || ArraySize(this.conflicts) > 0 || ArraySize(this.kept) > 0; }

  /// Everything else this changes, by name, for the popup.
  public func Changes() -> array<String> {
    let names: array<String> = this.conflicts;
    for part in this.forced {
      if !ArrayContains(names, part.categoryName) { ArrayPush(names, part.categoryName); }
    }
    return names;
  }

  public func Purchases() -> Int32 {
    let count: Int32 = 1;
    for part in this.forced {
      if !part.backToInstalled { count += 1; }
    }
    return count;
  }
}

/// One car's parts during a garage visit: what's on it, what a pick would drag along, previews and checkout. Icons, popups and
/// the cart all read the same evaluation. The preview on the car is the planned car (installed plus cart) with the active pick
/// and everything it forces on top. A category id can also be a group from the schema, which stands for all its targets.
public class GarageParts extends IScriptable {
  private let m_vehicle: wref<VehicleObject>;
  private let m_schema: ref<VehicleSchema>;
  private let m_system: wref<VCSystem>;
  private let m_catalog: ref<GaragePartsCatalog>;
  private let m_catalogs: array<ref<GaragePartsCatalog>>;
  private let m_location: ref<GarageLocation>;
  private let m_cart: ref<GarageCart>;
  private let m_plan: ref<GaragePlan>;
  private let m_stamp: Int32;
  private let m_effects: array<ref<GaragePreviewEffect>>;
  private let m_totals: ref<GarageVisitTotals>;
  private let m_context: ref<GarageContext>;

  /// False for a car with no schema, which only gets the trade services.
  public func Begin(vehicle: wref<VehicleObject>, location: ref<GarageLocation>) -> Bool {
    this.End();
    this.m_vehicle = vehicle;
    this.m_location = location;
    this.m_cart = new GarageCart();
    this.m_totals = new GarageVisitTotals();
    let schemas: ref<VehicleSchemas> = VehicleSchemas.Get();
    this.m_schema = IsDefined(schemas) && IsDefined(vehicle) ? schemas.GetSchemaByRecord(vehicle.GetRecordID()) : null;
    this.m_system = VCSystem.Get(GetGameInstance());
    this.m_context = this.BuildContext(vehicle, location);
    if !IsDefined(this.m_schema) || !IsDefined(this.m_system) { return false; }
    this.m_catalog = this.CatalogFor(this.m_schema);
    this.m_system.ClearPreview(this.m_schema.id);
    return true;
  }

  public func End() -> Void {
    this.m_vehicle = null;
    this.m_schema = null;
    this.m_catalog = null;
    this.m_plan = null;
    this.m_location = null;
    this.m_context = null;
    ArrayClear(this.m_effects);
  }

  // Schemas are remade each session, and the stale one for a car gets replaced rather than kept
  private func CatalogFor(schema: ref<VehicleSchema>) -> ref<GaragePartsCatalog> {
    let i: Int32 = 0;
    while i < ArraySize(this.m_catalogs) {
      if Equals(this.m_catalogs[i].schema.id, schema.id) {
        if !Equals(this.m_catalogs[i].schema, schema) { this.m_catalogs[i] = GaragePartsCatalog.Create(schema); }
        return this.m_catalogs[i];
      }
      i += 1;
    }
    let catalog: ref<GaragePartsCatalog> = GaragePartsCatalog.Create(schema);
    ArrayPush(this.m_catalogs, catalog);
    return catalog;
  }

  /// The banner for leaving, if parts were bought. Services, claims, sales and rushes post their own.
  public func PostExitSummary() -> Void {
    let totals: ref<GarageVisitTotals> = this.m_totals;
    if !IsDefined(totals) || totals.parts <= 0 { return; }
    let cost: String = GarageText.Price(totals.partsCost);
    let text: String = totals.parts == 1 ? GarageText.Format(n"Garage-Notify-SinglePartPurchased", [cost])
                                         : GarageText.Format(n"Garage-Notify-MultiPartPurchased", [IntToString(totals.parts), cost]);
    XUtils.Mod("Garage").Screen().Notify(text, SimpleMessageType.Money, 5.0, false);
  }

  private func BuildContext(vehicle: wref<VehicleObject>, location: ref<GarageLocation>) -> ref<GarageContext> {
    let context: ref<GarageContext> = new GarageContext();
    context.hasSchema = IsDefined(this.m_schema);
    if IsDefined(location) {
      context.locationId = location.id;
      context.locationName = location.name;
      context.garageTier = EconomyEngine.TierRank(location.economy.tier);
    }
    if IsDefined(vehicle) {
      context.vehicle = vehicle;
      context.vehicleRecord = vehicle.GetRecordID();
      context.vehicleDisplayName = IsDefined(this.m_schema) ? this.m_schema.GetName() : GetLocalizedTextByKey(vehicle.GetRecord().DisplayName());
      context.isOwned = GarageVehicles.IsOwned(vehicle.GetRecordID(), vehicle.GetCurrentAppearanceName());
    }
    return context;
  }

  /// What services get asked with, for this visit.
  public func Context() -> ref<GarageContext> {
    if !IsDefined(this.m_context) { this.m_context = new GarageContext(); }
    return this.m_context;
  }

  public func Schema() -> ref<VehicleSchema> { return this.m_schema; }

  public func Cart() -> ref<GarageCart> {
    if !IsDefined(this.m_cart) { this.m_cart = new GarageCart(); }
    return this.m_cart;
  }

  /// Takes an entry out, along with what it's tied to, and puts those parts back to the planned car.
  public func RemoveFromCart(category: CName) -> Void {
    let removed: array<CName> = this.Cart().RemoveGroup(category);
    this.RevertPreviews(removed);
  }

  /// Empties the cart and takes every preview off the car.
  public func DiscardCart() -> Void {
    this.Cart().Clear();
    this.RevertAll();
    let vehicle: wref<VehicleObject> = this.m_vehicle;
    if IsDefined(vehicle) { VehicleRefresh.Vehicle(vehicle); }
  }

  /// Empties the cart and puts those parts back to the planned car. Unlike DiscardCart, parts bought this visit stay on.
  public func ClearCart() -> Void {
    let cleared: array<CName>;
    let items: array<ref<GarageCartItem>> = this.Cart().Items();
    for item in items { ArrayPush(cleared, item.category); }
    this.Cart().Clear();
    this.RevertPreviews(cleared);
  }

  /// Replaces the cart with every part that isn't stock, as stock, and shows them on the car.
  public func AddAllStockToCart() -> Void {
    if !IsDefined(this.m_schema) { return; }
    this.ClearCart();
    let installed: ref<GarageChoices> = this.Plan().installed;
    let sections: array<CName> = [n"body", n"interior", n"wheels", n"misc", n"paint"];
    for category in this.m_schema.categories {
      let stock: CName = this.m_system.GetDefaultCName(this.m_schema.id, category.id);
      if !IsNameValid(stock) && ArraySize(category.choices) > 0 { stock = category.choices[0].id; }
      if ArrayContains(sections, category.section) && IsNameValid(stock) && !Equals(stock, installed.Get(category.id)) {
        this.AddItem(category.id, stock);
        this.m_system.SetPreviewCName(this.m_schema.id, category.id, stock);
      }
    }
    let vehicle: wref<VehicleObject> = this.m_vehicle;
    if IsDefined(vehicle) { VehicleRefresh.Vehicle(vehicle); }
  }

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
    let slot: ref<GaragePartsSlot> = this.Slot(id);
    return IsDefined(slot) ? slot.group : null;
  }

  /// The first group holding a category. They can overlap, Holders has them all.
  public func GroupOf(category: CName) -> ref<VehicleGroup> {
    let holders: array<ref<VehicleGroup>> = this.Holders(category);
    return ArraySize(holders) > 0 ? holders[0] : null;
  }

  /// Every group with this category in its targets.
  public func Holders(category: CName) -> array<ref<VehicleGroup>> {
    let groups: array<ref<VehicleGroup>>;
    let slot: ref<GaragePartsSlot> = this.Slot(category);
    if IsDefined(slot) {
      for holder in slot.holders { ArrayPush(groups, holder.group); }
    }
    return groups;
  }

  public func Targets(id: CName) -> array<CName> {
    let slot: ref<GaragePartsSlot> = this.Slot(id);
    if IsDefined(slot) { return slot.targets; }
    let single: array<CName> = [id];
    return single;
  }

  /// A category's or group's display name, the id itself if the schema doesn't know it.
  public func CategoryName(id: CName) -> String {
    let slot: ref<GaragePartsSlot> = this.Slot(id);
    return IsDefined(slot) ? slot.name : NameToString(id);
  }

  /// The names of the group mates that get their own cart entries if this category's picked alone. Empty unless a group holding it is in the cart.
  public func SplitSiblings(category: CName) -> array<String> {
    let names: array<String>;
    let slot: ref<GaragePartsSlot> = this.Slot(category);
    if !IsDefined(slot) { return names; }
    for holder in slot.holders {
      if IsDefined(this.Cart().ItemFor(holder.id)) {
        for target in holder.targets {
          let name: String = this.CategoryName(target);
          if !Equals(target, category) && !ArrayContains(names, name) { ArrayPush(names, name); }
        }
      }
    }
    return names;
  }

  private func Slot(id: CName) -> ref<GaragePartsSlot> {
    return IsDefined(this.m_catalog) ? this.m_catalog.Slot(id) : null;
  }

  // --- What's on the car

  /// Forget the snapshot, for an addon that changed the car's settings itself. Cart edits and anything bought here already do.
  public func Invalidate() -> Void { this.m_plan = null; }

  // A cart edit leaves the car alone, so only something bought has to read its settings again
  private func Plan() -> ref<GaragePlan> {
    let revision: Int32 = this.Cart().Revision();
    if IsDefined(this.m_plan) && this.m_plan.cartRevision == revision { return this.m_plan; }
    let plan: ref<GaragePlan> = new GaragePlan();
    this.m_stamp += 1;
    plan.stamp = this.m_stamp;
    plan.cartRevision = revision;
    plan.installed = IsDefined(this.m_plan) ? this.m_plan.installed : this.ReadInstalled();
    plan.planned = plan.installed.Copy();
    let items: array<ref<GarageCartItem>> = this.m_cart.Items();
    for item in items {
      let targets: array<CName> = this.Targets(item.category);
      for target in targets { plan.planned.Set(target, item.choice); }
    }
    this.m_plan = plan;
    return plan;
  }

  private func ReadInstalled() -> ref<GarageChoices> {
    let settings: ref<GarageChoices> = new GarageChoices();
    if !IsDefined(this.m_schema) { return settings; }
    for category in this.m_schema.categories {
      let value: CName = this.m_system.GetSettingOrDefault(this.m_schema.id, category.id);
      if IsNameValid(value) { settings.Push(category.id, value); }
    }
    return settings;
  }

  public func Installed() -> ref<GarageChoices> {
    return IsDefined(this.m_schema) ? this.Plan().installed.Copy() : new GarageChoices();
  }

  /// What the non-stock parts on a car cost new, for GaragePricing's partsCost. This visit's car unless you name one.
  public func InstalledValue(opt record: TweakDBID) -> Int32 {
    let schema: ref<VehicleSchema> = this.m_schema;
    if TDBID.IsValid(record) {
      let schemas: ref<VehicleSchemas> = VehicleSchemas.Get();
      schema = IsDefined(schemas) ? schemas.GetSchemaByRecord(record) : null;
    }
    let system: ref<VCSystem> = VCSystem.Get(GetGameInstance());
    if !IsDefined(schema) || !IsDefined(system) { return 0; }
    let total: Int32 = 0;
    for category in schema.categories {
      let value: CName = system.GetSettingOrDefault(schema.id, category.id);
      if IsNameValid(value) && NotEquals(value, n"None") && NotEquals(value, system.GetDefaultCName(schema.id, category.id)) && category.HasChoice(value) {
        total += Max(category.GetPrice(value), 0);
      }
    }
    return total;
  }

  /// What the picker should mark as current. n"" for a group whose targets differ.
  public func CurrentChoice(id: CName) -> CName {
    if !IsDefined(this.m_schema) { return n""; }
    let slot: ref<GaragePartsSlot> = this.Slot(id);
    return IsDefined(slot) ? this.CurrentOf(slot, this.Plan()) : this.Plan().installed.Get(id);
  }

  private func CurrentOf(slot: ref<GaragePartsSlot>, plan: ref<GaragePlan>) -> CName {
    if ArraySize(slot.targets) == 0 { return n""; }
    let first: CName = plan.installed.Get(slot.targets[0]);
    for target in slot.targets {
      if !Equals(plan.installed.Get(target), first) { return n""; }
    }
    return first;
  }

  public func IsPaint(category: CName) -> Bool { return GaragePartsCatalog.IsPaint(category); }

  public func Status(category: CName, choice: CName) -> EGaragePartStatus {
    if this.IsPaint(category) || !IsDefined(this.m_catalog) { return EGaragePartStatus.Unowned; }
    if this.m_catalog.IsStock(this.m_system, category, choice) { return EGaragePartStatus.Stock; }
    return this.m_system.OwnsPartCName(this.m_schema.id, category, choice) ? EGaragePartStatus.Owned : EGaragePartStatus.Unowned;
  }

  private func StatusOf(slot: ref<GaragePartsSlot>, choice: CName, part: ref<GaragePartData>) -> EGaragePartStatus {
    if IsDefined(part) && part.isStock { return EGaragePartStatus.Stock; }
    if !IsDefined(slot.group) { return this.Status(slot.id, choice); }
    let allStock: Bool = true;
    let allOwned: Bool = true;
    for target in slot.targets {
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
    let found: ref<GaragePartsSection> = IsDefined(this.m_catalog) ? this.m_catalog.Section(section) : null;
    return IsDefined(found) ? found.infos : list;
  }

  /// The choices for a category or group, all of them with their current status. A group shows its source's list and costs the sum of its targets.
  /// A picker wants Rows, which only works out the page it's showing.
  public func Choices(id: CName) -> array<ref<GarageChoiceInfo>> {
    let list: array<ref<GarageChoiceInfo>>;
    let slot: ref<GaragePartsSlot> = this.Slot(id);
    if !IsDefined(slot) { return list; }
    let fee: Int32 = this.ServiceFee(id);
    let parts: array<ref<GaragePartData>> = this.m_catalog.List(slot, n"").parts;
    for part in parts {
      let info: ref<GarageChoiceInfo> = new GarageChoiceInfo();
      info.id = part.id;
      info.name = part.name;
      info.description = part.description;
      info.serviceFee = fee;
      info.swatch = part.swatch;
      info.status = this.StatusOf(slot, part.id, part);
      info.price = part.price;
      ArrayPush(list, info);
    }
    return list;
  }

  /// How many rows a picker has, narrowed to a paint finish if you pass one (n"standard", n"metallic", n"matte").
  public func RowCount(id: CName, finish: CName) -> Int32 {
    let slot: ref<GaragePartsSlot> = this.Slot(id);
    return IsDefined(slot) ? ArraySize(this.m_catalog.List(slot, finish).parts) : 0;
  }

  /// One page of a picker. Bind these rather than asking about each one, it's all read from one plan.
  public func Rows(id: CName, finish: CName, start: Int32, count: Int32) -> array<ref<GaragePartRow>> {
    let rows: array<ref<GaragePartRow>>;
    let slot: ref<GaragePartsSlot> = this.Slot(id);
    if !IsDefined(slot) { return rows; }
    let list: ref<GaragePartList> = this.m_catalog.List(slot, finish);
    let plan: ref<GaragePlan> = this.Plan();
    let context: ref<GaragePartsContext> = this.ContextOf(slot, plan);
    let current: CName = this.CurrentOf(slot, plan);
    let entry: ref<GarageCartItem> = this.m_cart.ItemFor(id);
    let inCart: CName = IsDefined(entry) ? entry.choice : n"";
    let fee: Int32 = this.ServiceFee(id);
    let end: Int32 = Min(start + count, ArraySize(list.parts));
    let i: Int32 = start;
    while i < end {
      let part: ref<GaragePartData> = list.parts[i];
      let row: ref<GaragePartRow> = new GaragePartRow();
      row.part = part;
      row.serviceFee = fee;
      row.status = this.StatusOf(slot, part.id, part);
      row.forcesOthers = this.Forces(context, part.id);
      if IsNameValid(inCart) && Equals(part.id, inCart) {
        row.badge = EGaragePartBadge.Cart;
      } else if Equals(part.id, current) {
        row.badge = EGaragePartBadge.Installed;
      } else if Equals(row.status, EGaragePartStatus.Stock) {
        row.badge = EGaragePartBadge.Stock;
      } else if Equals(row.status, EGaragePartStatus.Owned) {
        row.badge = EGaragePartBadge.Owned;
      } else {
        row.badge = EGaragePartBadge.Price;
      }
      ArrayPush(rows, row);
      i += 1;
    }
    return rows;
  }

  // --- What a pick does

  private func ContextOf(slot: ref<GaragePartsSlot>, plan: ref<GaragePlan>) -> ref<GaragePartsContext> {
    for known in plan.contexts {
      if Equals(known.slot.id, slot.id) { return known; }
    }
    let context: ref<GaragePartsContext> = new GaragePartsContext();
    context.slot = slot;
    context.plan = plan.planned;
    context.base = plan.planned.Copy();
    let items: array<ref<GarageCartItem>> = this.m_cart.Items();
    for item in items {
      if ArrayContains(slot.owned, item.category) || (IsNameValid(item.source) && ArrayContains(slot.owned, item.source)) {
        let targets: array<CName> = this.Targets(item.category);
        for target in targets {
          context.base.Set(target, plan.installed.Get(target));
          if !ArrayContains(slot.owned, target) && !ArrayContains(context.released, target) { ArrayPush(context.released, target); }
        }
      }
    }
    ArrayPush(plan.contexts, context);
    return context;
  }

  private func ResolveTargets(targets: array<CName>, choice: CName, base: ref<GarageChoices>, out settings: ref<GarageChoices>) -> ref<GarageChoices> {
    let constraints: ref<GarageConstraints> = this.m_catalog.constraints;
    let changes: ref<GarageChoices> = new GarageChoices();
    settings = base.Copy();
    for target in targets {
      changes.Set(target, choice);
      settings.Set(target, choice);
    }
    for target in targets {
      if constraints.HasRules(target, choice) {
        let resolved: ref<GarageChoices> = constraints.ResolveAll(target, choice, settings);
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
    }
    return changes;
  }

  // A sibling a constraint forces along (the front rim drags the rear to a new size) gets the same rim when it fits, instead of
  // the constraint's fallback
  private func ResolveSelection(slot: ref<GaragePartsSlot>, choice: CName, base: ref<GarageChoices>, out settled: ref<GarageChoices>) -> ref<GarageChoices> {
    let changes: ref<GarageChoices> = this.ResolveTargets(slot.targets, choice, base, settled);
    if ArraySize(changes.categories) == ArraySize(slot.targets) { return changes; }
    let widened: array<CName> = slot.targets;
    for target in slot.targets {
      let targetSlot: ref<GaragePartsSlot> = this.m_catalog.Slot(target);
      if IsDefined(targetSlot) {
        for holder in targetSlot.holders {
          for sibling in holder.targets {
            let category: ref<VehicleCategory> = this.m_catalog.Category(sibling);
            if !ArrayContains(widened, sibling) && changes.Has(sibling) && !Equals(changes.Get(sibling), choice) && IsDefined(category) && category.HasChoice(choice) {
              ArrayPush(widened, sibling);
            }
          }
        }
      }
    }
    if ArraySize(widened) == ArraySize(slot.targets) { return changes; }
    let wideFinal: ref<GarageChoices>;
    let wideChanges: ref<GarageChoices> = this.ResolveTargets(widened, choice, base, wideFinal);
    for target in widened {
      let conflicts: array<ref<GarageConflict>> = this.m_catalog.constraints.Conflicts(target, choice, wideFinal);
      if ArraySize(conflicts) > 0 { return changes; }
    }
    settled = wideFinal;
    return wideChanges;
  }

  private func Evaluate(context: ref<GaragePartsContext>, choice: CName) -> ref<GaragePartsResult> {
    let result: ref<GaragePartsResult> = new GaragePartsResult();
    let settled: ref<GarageChoices>;
    result.changes = this.ResolveSelection(context.slot, choice, context.base, settled);
    result.final = settled;
    result.touched = context.released;
    for category in result.changes.categories {
      if !ArrayContains(context.slot.targets, category) && !ArrayContains(result.touched, category) { ArrayPush(result.touched, category); }
    }
    return result;
  }

  // Most choices have no rules at all, and asking the map costs nothing next to working a pick out
  private func Forces(context: ref<GaragePartsContext>, choice: CName) -> Bool {
    if ArraySize(context.released) == 0 && !this.HasRulesFor(context.slot, choice) { return false; }
    let result: ref<GaragePartsResult> = this.Evaluate(context, choice);
    for category in result.touched {
      if !Equals(result.final.Get(category), context.plan.Get(category)) { return true; }
    }
    return false;
  }

  private func HasRulesFor(slot: ref<GaragePartsSlot>, choice: CName) -> Bool {
    for target in slot.targets {
      if this.m_catalog.constraints.HasRules(target, choice) { return true; }
    }
    return false;
  }

  /// True when picking this would change a part other than its own, for the picker's warning icon.
  public func WouldForceOthers(id: CName, choice: CName) -> Bool {
    let slot: ref<GaragePartsSlot> = this.Slot(id);
    return IsDefined(slot) && this.Forces(this.ContextOf(slot, this.Plan()), choice);
  }

  /// WouldForceOthers for a whole list, in the same order.
  public func WhichForceOthers(id: CName, choices: array<CName>) -> array<Bool> {
    let answers: array<Bool>;
    let slot: ref<GaragePartsSlot> = this.Slot(id);
    let context: ref<GaragePartsContext> = IsDefined(slot) ? this.ContextOf(slot, this.Plan()) : null;
    for choice in choices { ArrayPush(answers, IsDefined(context) && this.Forces(context, choice)); }
    return answers;
  }

  /// The other parts this pick would force, for the popup that asks first.
  public func ForcedBy(id: CName, choice: CName) -> ref<GarageChoices> {
    let forced: ref<GarageChoices> = new GarageChoices();
    let slot: ref<GaragePartsSlot> = this.Slot(id);
    if !IsDefined(slot) { return forced; }
    let result: ref<GaragePartsResult> = this.Evaluate(this.ContextOf(slot, this.Plan()), choice);
    let i: Int32 = 0;
    while i < ArraySize(result.changes.categories) {
      if !ArrayContains(slot.targets, result.changes.categories[i]) { forced.Set(result.changes.categories[i], result.changes.choices[i]); }
      i += 1;
    }
    return forced;
  }

  /// Cart entries this pick would replace or drop, its own slot included.
  public func CartConflicts(id: CName, choice: CName) -> array<ref<GarageCartItem>> {
    let conflicts: array<ref<GarageCartItem>>;
    let slot: ref<GaragePartsSlot> = this.Slot(id);
    if !IsDefined(slot) { return conflicts; }
    return this.ConflictItems(this.Evaluate(this.ContextOf(slot, this.Plan()), choice).final);
  }

  private func ConflictItems(settled: ref<GarageChoices>) -> array<ref<GarageCartItem>> {
    let conflicts: array<ref<GarageCartItem>>;
    let items: array<ref<GarageCartItem>> = this.m_cart.Items();
    for item in items {
      let differs: Bool = false;
      let targets: array<CName> = this.Targets(item.category);
      for target in targets {
        if !Equals(settled.Get(target), item.choice) { differs = true; }
      }
      if differs { ArrayPush(conflicts, item); }
    }
    return conflicts;
  }

  /// What a pick would do, without touching the car. Null without a schema or a slot of that name.
  public func Assess(id: CName, choice: CName) -> ref<GaragePick> {
    let slot: ref<GaragePartsSlot> = this.Slot(id);
    if !IsDefined(slot) { return null; }
    let plan: ref<GaragePlan> = this.Plan();
    let result: ref<GaragePartsResult> = this.Evaluate(this.ContextOf(slot, plan), choice);
    let part: ref<GaragePartData> = this.m_catalog.Part(slot, choice);
    let pick: ref<GaragePick> = new GaragePick();
    pick.stamp = plan.stamp;
    pick.slot = id;
    pick.choice = choice;
    pick.name = IsDefined(part) ? part.name : NameToString(choice);
    pick.description = IsDefined(part) ? part.description : "";
    pick.cartName = slot.name + " - " + pick.name;
    pick.status = this.StatusOf(slot, choice, part);
    pick.price = Equals(pick.status, EGaragePartStatus.Unowned) && IsDefined(part) ? part.price : 0;
    pick.serviceFee = this.ServiceFee(id);
    pick.final = result.final;
    pick.touched = result.touched;
    pick.targets = slot.targets;
    pick.owned = slot.owned;
    pick.taken = slot.targets;
    pick.isInstalled = Equals(this.CurrentOf(slot, plan), choice);
    pick.isInCart = this.m_cart.Has(id, choice);
    let i: Int32 = 0;
    while i < ArraySize(result.changes.categories) {
      let category: CName = result.changes.categories[i];
      if !ArrayContains(slot.targets, category) {
        let forced: ref<GaragePickPart> = this.ForcedPart(category, result.changes.choices[i], plan);
        pick.forcedCost += forced.price + forced.serviceFee;
        ArrayPush(pick.forced, forced);
        ArrayPush(pick.taken, category);
      }
      i += 1;
    }
    if this.m_cart.Count() > 0 { this.AssessCart(pick); }
    pick.canAfford = GarageTransactions.Balance() >= pick.Total();
    return pick;
  }

  private func ForcedPart(category: CName, choice: CName, plan: ref<GaragePlan>) -> ref<GaragePickPart> {
    let part: ref<GaragePickPart> = new GaragePickPart();
    let definition: ref<VehicleCategory> = this.m_catalog.Category(category);
    part.category = category;
    part.choice = choice;
    part.categoryName = this.CategoryName(category);
    part.entryName = part.categoryName + " - " + (IsDefined(definition) ? definition.GetChoiceName(choice) : NameToString(choice));
    part.status = this.Status(category, choice);
    part.backToInstalled = Equals(choice, plan.installed.Get(category));
    if !part.backToInstalled {
      part.price = Equals(part.status, EGaragePartStatus.Unowned) && IsDefined(definition) ? definition.GetPrice(choice) : 0;
      part.serviceFee = this.ServiceFee(category);
    }
    return part;
  }

  // Works out the cart side up front, so the popup can list all of it and the edits only have to carry it out
  private func AssessCart(pick: ref<GaragePick>) -> Void {
    let splitting: array<CName>;
    for category in pick.taken {
      let slot: ref<GaragePartsSlot> = this.m_catalog.Slot(category);
      if IsDefined(slot) {
        for holder in slot.holders {
          if !Equals(holder.id, pick.slot) && !ArrayContains(splitting, holder.id) && IsDefined(this.m_cart.ItemFor(holder.id)) {
            ArrayPush(splitting, holder.id);
            ArrayPush(pick.splits, holder);
          }
        }
      }
    }
    for split in pick.splits {
      for target in split.targets {
        let name: String = this.CategoryName(target);
        if !ArrayContains(pick.taken, target) && !ArrayContains(pick.kept, name) { ArrayPush(pick.kept, name); }
      }
    }
    let conflicts: array<ref<GarageCartItem>> = this.ConflictItems(pick.final);
    for item in conflicts {
      if !ArrayContains(splitting, item.category) { ArrayPush(pick.conflicts, this.CategoryName(item.category)); }
    }
    // An entry no constraint could resolve around gets dropped rather than selling a broken car
    let items: array<ref<GarageCartItem>> = this.m_cart.Items();
    for item in items {
      if !ArrayContains(pick.owned, item.category) && !Equals(item.source, pick.slot) && !ArrayContains(pick.taken, item.category) && !ArrayContains(splitting, item.category) && this.Clashes(item, pick.final) {
        ArrayPush(pick.clashes, item.category);
        let name: String = this.CategoryName(item.category);
        if !ArrayContains(pick.conflicts, name) { ArrayPush(pick.conflicts, name); }
      }
    }
  }

  private func Clashes(item: ref<GarageCartItem>, settled: ref<GarageChoices>) -> Bool {
    let targets: array<CName> = this.Targets(item.category);
    for target in targets {
      let conflicts: array<ref<GarageConflict>> = this.m_catalog.constraints.Conflicts(target, item.choice, settled);
      if ArraySize(conflicts) > 0 { return true; }
    }
    return false;
  }

  /// Assess, and shows it on the car. Null without a schema or a slot of that name.
  public func Pick(id: CName, choice: CName) -> ref<GaragePick> {
    let pick: ref<GaragePick> = this.Assess(id, choice);
    if IsDefined(pick) { this.ShowPick(pick); }
    return pick;
  }

  /// False once the cart's changed or something's been bought, and BuyPick won't take it after that.
  public func IsCurrent(pick: ref<GaragePick>) -> Bool {
    return IsDefined(pick) && IsDefined(this.m_schema) && pick.stamp == this.Plan().stamp;
  }

  // --- Previews

  private func OnCar(category: CName) -> CName {
    let preview: CName = this.m_system.GetPreviewCName(this.m_schema.id, category);
    return IsNameValid(preview) ? preview : this.m_system.GetSettingOrDefault(this.m_schema.id, category);
  }

  // Only what's really different, a mesh refresh is the slow part of all this
  private func ApplyPreview(values: ref<GarageChoices>, ids: array<CName>) -> Bool {
    let changed: String = "";
    for category in ids {
      let value: CName = values.Get(category);
      if IsNameValid(value) && !Equals(value, this.OnCar(category)) {
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

  private func ShowPick(pick: ref<GaragePick>) -> Bool {
    let effect: ref<GaragePreviewEffect> = this.EffectOf(pick.slot);
    if !IsDefined(effect) {
      effect = new GaragePreviewEffect();
      effect.slot = pick.slot;
      ArrayPush(this.m_effects, effect);
    }
    for category in pick.touched {
      if !ArrayContains(effect.categories, category) { ArrayPush(effect.categories, category); }
    }
    let ids: array<CName> = effect.categories;
    for target in pick.targets {
      if !ArrayContains(ids, target) { ArrayPush(ids, target); }
    }
    return this.ApplyPreview(pick.final, ids);
  }

  /// Shows the pick and what it drags along. Last pick's extras this one doesn't decide fall back to the base.
  public func Preview(id: CName, choice: CName) -> Bool {
    let pick: ref<GaragePick> = this.Assess(id, choice);
    return IsDefined(pick) && this.ShowPick(pick);
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
    return this.ApplyPreview(this.Plan().planned, ids);
  }

  public func RevertPreview(slot: CName) -> Bool {
    let slots: array<CName> = [slot];
    return this.RevertPreviews(slots);
  }

  /// A picker is done with this slot, however it left. Puts the car back if a pick was showing.
  public func LeaveSlot(slot: CName) -> Bool {
    return IsDefined(this.EffectOf(slot)) && this.RevertPreview(slot);
  }

  /// Drops every unbought preview. The caller refreshes the car.
  public func RevertAll() -> Void {
    if IsDefined(this.m_schema) { this.m_system.ClearPreview(this.m_schema.id); }
    ArrayClear(this.m_effects);
  }

  // --- The cart

  private func AddItem(category: CName, choice: CName, opt source: CName) -> Void {
    let definition: ref<VehicleCategory> = this.m_catalog.Category(category);
    if !IsDefined(definition) { return; }
    let status: EGaragePartStatus = this.Status(category, choice);
    let price: Int32 = Equals(status, EGaragePartStatus.Unowned) ? definition.GetPrice(choice) : 0;
    this.m_cart.Add(category, choice, definition.GetName() + " - " + definition.GetChoiceName(choice), price, this.ServiceFee(category), status, source);
  }

  // The one place stale entries come out, for adding and buying alike. anchor is who takes over what a replaced entry forced.
  // Returns what came out, for the preview
  private func ClearWay(pick: ref<GaragePick>, anchor: CName) -> array<CName> {
    let dropped: array<CName>;
    for owner in pick.owned { this.Drop(owner, dropped); }
    for split in pick.splits {
      let entry: ref<GarageCartItem> = this.m_cart.ItemFor(split.id);
      if IsDefined(entry) {
        let heir: CName = anchor;
        this.m_cart.Remove(split.id);
        for target in split.targets {
          if !ArrayContains(pick.taken, target) {
            this.AddItem(target, entry.choice, entry.source);
            heir = target;
          }
        }
        this.m_cart.Reparent(split.id, heir);
      }
    }
    for part in pick.forced {
      this.m_cart.Reparent(part.category, anchor);
      this.m_cart.Remove(part.category);
    }
    for clash in pick.clashes { this.Drop(clash, dropped); }
    return dropped;
  }

  private func Drop(category: CName, out dropped: array<CName>) -> Void {
    let removed: array<CName> = this.m_cart.RemoveWithForced(category);
    for gone in removed { ArrayPush(dropped, gone); }
  }

  /// Puts a pick in the cart, then whatever it forces, and clears out every entry it makes stale. Assesses it again if the cart moved on.
  public func AddPick(pick: ref<GaragePick>) -> Void {
    if !IsDefined(pick) || !IsDefined(this.m_schema) { return; }
    let current: ref<GaragePick> = this.IsCurrent(pick) ? pick : this.Assess(pick.slot, pick.choice);
    if !IsDefined(current) { return; }
    let changed: array<CName> = this.ClearWay(current, current.slot);
    this.m_cart.Add(current.slot, current.choice, current.cartName, current.price, current.serviceFee, current.status);
    for part in current.forced {
      if !part.backToInstalled { this.m_cart.Add(part.category, part.choice, part.entryName, part.price, part.serviceFee, part.status, current.slot); }
      ArrayPush(changed, part.category);
    }
    ArrayPush(changed, current.slot);
    this.RevertPreviews(changed);
  }

  /// Puts a pick in the cart, free if V already has it or it's stock. AddPick does the work, this takes your own name and price.
  public func AddToCart(id: CName, choice: CName, name: String, price: Int32, serviceFee: Int32, status: EGaragePartStatus) -> Void {
    let pick: ref<GaragePick> = this.Assess(id, choice);
    if !IsDefined(pick) { return; }
    pick.cartName = name;
    pick.price = Equals(status, EGaragePartStatus.Unowned) ? price : 0;
    pick.serviceFee = serviceFee;
    pick.status = status;
    this.AddPick(pick);
  }

  // --- Buying

  private func Apply(id: CName, choice: CName, status: EGaragePartStatus) -> Void {
    let targets: array<CName> = this.Targets(id);
    for target in targets {
      if Equals(status, EGaragePartStatus.Unowned) && !this.IsPaint(target) { this.m_system.AddOwnedPartCName(this.m_schema.id, target, choice); }
      this.m_system.SetSettingCName(this.m_schema.id, target, choice);
      // The preview layer beats saved settings, so it has to agree with what was just bought
      this.m_system.SetPreviewCName(this.m_schema.id, target, choice);
    }
    this.m_plan = null;
  }

  private func RefreshTargets(id: CName) -> Void {
    let changed: String = "";
    let targets: array<CName> = this.Targets(id);
    for target in targets { changed += (StrLen(changed) > 0 ? "|" : "") + NameToString(target); }
    let vehicle: wref<VehicleObject> = this.m_vehicle;
    if IsDefined(vehicle) { VehicleRefresh.Parts(vehicle, changed); }
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

  /// Buys a pick and what it forces, right now, and leaves the rest of the cart alone. Nothing changes unless the money moved,
  /// and false if the pick's out of date, so it can't buy something other than what was listed.
  public func BuyPick(pick: ref<GaragePick>) -> Bool {
    if !this.IsCurrent(pick) { return false; }
    if !this.Charge(pick.Total(), pick.Purchases(), EGarageTxKind.Parts, n"aftermarket") { return false; }
    this.ShowPick(pick);
    let changed: array<CName> = this.ClearWay(pick, n"");
    this.Apply(pick.slot, pick.choice, pick.status);
    for part in pick.forced {
      if !part.backToInstalled { this.Apply(part.category, part.choice, part.status); }
      ArrayPush(changed, part.category);
    }
    ArrayPush(changed, pick.slot);
    this.RevertPreviews(changed);
    return true;
  }

  /// One part, right now, with no thought for what it forces. Pass kind and source together, or it's a Parts charge from the aftermarket.
  public func Purchase(id: CName, choice: CName, totalCost: Int32, status: EGaragePartStatus, opt kind: EGarageTxKind, opt source: CName) -> Bool {
    if !IsDefined(this.m_schema) { return false; }
    let chargedAs: EGarageTxKind = IsNameValid(source) ? kind : EGarageTxKind.Parts;
    if !this.Charge(totalCost, 1, chargedAs, IsNameValid(source) ? source : n"aftermarket") { return false; }
    this.Apply(id, choice, status);
    this.RefreshTargets(id);
    return true;
  }

  /// Puts a part on with no charge, for a service that took its money its own way.
  public func Install(id: CName, choice: CName, status: EGaragePartStatus) -> Bool {
    if !IsDefined(this.m_schema) { return false; }
    this.Apply(id, choice, status);
    this.RefreshTargets(id);
    return true;
  }

  /// Checks out the cart. Nothing's applied unless the money moved.
  public func Checkout() -> Bool {
    if !IsDefined(this.m_schema) || this.Cart().Count() == 0 { return false; }
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
