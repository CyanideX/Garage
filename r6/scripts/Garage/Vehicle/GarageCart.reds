module Garage.Vehicle

public enum EGaragePartStatus {
  Stock = 0,
  Owned = 1,
  Unowned = 2,
}

public class GarageCartItem extends IScriptable {
  public let category: CName;
  public let choice: CName;
  public let name: String;
  public let price: Int32;
  public let serviceFee: Int32;
  public let status: EGaragePartStatus;
  /// The category whose pick forced this one in. n"" for something the player picked.
  public let source: CName;

  public func Total() -> Int32 { return this.price + this.serviceFee; }
}

/// Parts waiting to be bought, one per category. Clears when the garage closes.
public class GarageCart extends IScriptable {
  private let m_items: array<ref<GarageCartItem>>;
  private let m_revision: Int32;
  /// The Quick addon's heat rush is in this checkout, so it's a rush fee rather than parts.
  public let quickServicePending: Bool;

  /// Goes up with every edit, so anything worked out from the cart can tell it's out of date.
  public func Revision() -> Int32 { return this.m_revision; }

  /// Replaces what's in the category. False without a choice or a category.
  public func Add(category: CName, choice: CName, name: String, price: Int32, serviceFee: Int32, status: EGaragePartStatus, opt source: CName) -> Bool {
    if !IsNameValid(category) || !IsNameValid(choice) { return false; }
    this.Remove(category);
    let item: ref<GarageCartItem> = new GarageCartItem();
    item.category = category;
    item.choice = choice;
    item.name = StrLen(name) > 0 ? name : NameToString(choice);
    item.price = price;
    item.serviceFee = serviceFee;
    item.status = status;
    item.source = source;
    ArrayPush(this.m_items, item);
    this.m_revision += 1;
    return true;
  }

  public func Items() -> array<ref<GarageCartItem>> { return this.m_items; }

  public func Count() -> Int32 { return ArraySize(this.m_items); }

  public func Total() -> Int32 {
    let total: Int32 = 0;
    for item in this.m_items { total += item.Total(); }
    return total;
  }

  public func ItemFor(category: CName) -> ref<GarageCartItem> {
    for item in this.m_items {
      if Equals(item.category, category) { return item; }
    }
    return null;
  }

  public func Has(category: CName, choice: CName) -> Bool {
    let item: ref<GarageCartItem> = this.ItemFor(category);
    return IsDefined(item) && Equals(item.choice, choice);
  }

  public func Remove(category: CName) -> Bool {
    let item: ref<GarageCartItem> = this.ItemFor(category);
    if !IsDefined(item) { return false; }
    this.m_revision += 1;
    return ArrayRemove(this.m_items, item);
  }

  /// Drops everything this category's pick forced in, and returns how many.
  public func RemoveForcedBy(source: CName) -> Int32 {
    let removed: Int32 = 0;
    let i: Int32 = ArraySize(this.m_items) - 1;
    while i >= 0 {
      if Equals(this.m_items[i].source, source) {
        ArrayErase(this.m_items, i);
        removed += 1;
      }
      i -= 1;
    }
    if removed > 0 { this.m_revision += 1; }
    return removed;
  }

  /// Takes out a category's entry and what it forced, even if the entry itself has already gone. Returns the categories that came out.
  public func RemoveWithForced(category: CName) -> array<CName> {
    let removed: array<CName>;
    for item in this.m_items {
      if Equals(item.source, category) { ArrayPush(removed, item.category); }
    }
    this.RemoveForcedBy(category);
    if this.Remove(category) { ArrayPush(removed, category); }
    return removed;
  }

  /// Hands what one category forced over to another, n"" making them the player's own. Sources stay one level deep, which RemoveGroup relies on.
  public func Reparent(from: CName, to: CName) -> Void {
    for item in this.m_items {
      if Equals(item.source, from) {
        item.source = to;
        this.m_revision += 1;
      }
    }
  }

  /// Removes an entry along with the pick that forced it and everything else that pick forced, since a forced rear rim
  /// can't leave on its own without breaking its constraint. Returns the categories that came out.
  public func RemoveGroup(category: CName) -> array<CName> {
    let removed: array<CName>;
    let item: ref<GarageCartItem> = this.ItemFor(category);
    if !IsDefined(item) { return removed; }
    let forcer: ref<GarageCartItem> = IsNameValid(item.source) ? this.ItemFor(item.source) : null;
    let root: CName = IsDefined(forcer) ? forcer.category : category;
    return this.RemoveWithForced(root);
  }

  public func Clear() -> Void {
    ArrayClear(this.m_items);
    this.quickServicePending = false;
    this.m_revision += 1;
  }
}
