module Garage.Vehicle

import VehicleCore.*
import VehicleCore.Schema.*

/// A category to choice map.
public class GarageChoices extends IScriptable {
  public let categories: array<CName>;
  public let choices: array<CName>;

  public func Get(category: CName) -> CName {
    let at: Int32 = ArrayFindFirst(this.categories, category);
    return at >= 0 ? this.choices[at] : n"";
  }

  public func Has(category: CName) -> Bool { return ArrayContains(this.categories, category); }

  public func Set(category: CName, choice: CName) -> Void {
    let at: Int32 = ArrayFindFirst(this.categories, category);
    if at >= 0 {
      this.choices[at] = choice;
    } else {
      ArrayPush(this.categories, category);
      ArrayPush(this.choices, choice);
    }
  }

  /// Set, for a category you know isn't in here yet.
  public func Push(category: CName, choice: CName) -> Void {
    ArrayPush(this.categories, category);
    ArrayPush(this.choices, choice);
  }

  public func Copy() -> ref<GarageChoices> {
    let copy: ref<GarageChoices> = new GarageChoices();
    copy.categories = this.categories;
    copy.choices = this.choices;
    return copy;
  }
}

public class GarageConstraintRule extends IScriptable {
  public let target: CName;
  public let blocked: array<CName>;
  // n"" on a reverse rule, which works one out when it's needed
  public let resolve: CName;
}

public class GarageConstraintRules extends IScriptable {
  public let rules: array<ref<GarageConstraintRule>>;
}

public class GarageConflict extends IScriptable {
  public let target: CName;
  public let current: CName;
  public let resolve: CName;
}

/// What a car's constraints do. A rule runs both ways: picking the blocked part pushes the part that blocked it off too.
public class GarageConstraints extends IScriptable {
  private let m_schema: ref<VehicleSchema>;
  private let m_map: ref<inkHashMap>;

  public static func For(schema: ref<VehicleSchema>) -> ref<GarageConstraints> {
    let self: ref<GarageConstraints> = new GarageConstraints();
    self.m_schema = schema;
    self.m_map = new inkHashMap();
    for constraint in schema.constraints {
      for value in constraint.values {
        for resolve in constraint.resolves {
          let rule: ref<GarageConstraintRule> = new GarageConstraintRule();
          rule.target = resolve.option;
          rule.blocked = resolve.blocked;
          rule.resolve = resolve.value;
          ArrayPush(self.RulesFor(constraint.option, value).rules, rule);
          for blocked in resolve.blocked { self.AddReverse(resolve.option, blocked, constraint.option, constraint.values); }
        }
      }
    }
    return self;
  }

  private static func Key(category: CName, choice: CName) -> Uint64 {
    return VC_PairKey(VC_CNameKey(category), VC_CNameKey(choice));
  }

  private func RulesFor(category: CName, choice: CName) -> ref<GarageConstraintRules> {
    let key: Uint64 = GarageConstraints.Key(category, choice);
    let rules: ref<GarageConstraintRules> = this.m_map.Get(key) as GarageConstraintRules;
    if !IsDefined(rules) {
      rules = new GarageConstraintRules();
      this.m_map.Insert(key, rules);
    }
    return rules;
  }

  // Conflicts reads one rule per target, so these merge or the resolve picks a value that's also blocked
  private func AddReverse(category: CName, choice: CName, option: CName, values: array<CName>) -> Void {
    let list: ref<GarageConstraintRules> = this.RulesFor(category, choice);
    let entry: ref<GarageConstraintRule>;
    for rule in list.rules {
      if !IsNameValid(rule.resolve) && Equals(rule.target, option) { entry = rule; }
    }
    if !IsDefined(entry) {
      entry = new GarageConstraintRule();
      entry.target = option;
      ArrayPush(list.rules, entry);
    }
    for value in values {
      if !ArrayContains(entry.blocked, value) { ArrayPush(entry.blocked, value); }
    }
  }

  /// False means this pick can't push anything else off, whatever the car's on.
  public func HasRules(category: CName, choice: CName) -> Bool {
    return this.m_map.KeyExist(GarageConstraints.Key(category, choice));
  }

  /// What has to move if category goes to choice with these settings. resolve is n"" when nothing can.
  public func Conflicts(category: CName, choice: CName, settings: ref<GarageChoices>) -> array<ref<GarageConflict>> {
    let found: array<ref<GarageConflict>>;
    let seen: array<CName>;
    let list: ref<GarageConstraintRules> = this.m_map.Get(GarageConstraints.Key(category, choice)) as GarageConstraintRules;
    if !IsDefined(list) { return found; }
    for rule in list.rules {
      let current: CName = settings.Get(rule.target);
      if !ArrayContains(seen, rule.target) && ArrayContains(rule.blocked, current) {
        let conflict: ref<GarageConflict> = new GarageConflict();
        conflict.target = rule.target;
        conflict.current = current;
        conflict.resolve = IsNameValid(rule.resolve) ? rule.resolve : this.ReverseResolve(rule.target, category, rule.blocked);
        ArrayPush(found, conflict);
        ArrayPush(seen, rule.target);
      }
    }
    return found;
  }

  // The rule's own fallback if it isn't blocked as well, then the car's default, then the first choice that fits
  private func ReverseResolve(target: CName, forCategory: CName, blocked: array<CName>) -> CName {
    for constraint in this.m_schema.constraints {
      if Equals(constraint.option, forCategory) {
        for resolve in constraint.resolves {
          if Equals(resolve.option, target) && IsNameValid(resolve.value) && !ArrayContains(blocked, resolve.value) { return resolve.value; }
        }
      }
    }
    let system: ref<VCSystem> = VCSystem.Get(GetGameInstance());
    let fallback: CName = IsDefined(system) ? system.GetDefaultCName(this.m_schema.id, target) : n"";
    if IsNameValid(fallback) && !ArrayContains(blocked, fallback) { return fallback; }
    let category: ref<VehicleCategory> = this.m_schema.GetCategory(target);
    if IsDefined(category) {
      for choice in category.choices {
        if !ArrayContains(blocked, choice.id) { return choice.id; }
      }
    }
    return n"";
  }

  /// Everything that changes if category goes to choice, following what each forced part forces in turn. Includes the pick.
  public func ResolveAll(category: CName, choice: CName, current: ref<GarageChoices>) -> ref<GarageChoices> {
    let changes: ref<GarageChoices> = new GarageChoices();
    changes.Set(category, choice);
    let settings: ref<GarageChoices> = current.Copy();
    settings.Set(category, choice);
    let queueCategories: array<CName> = [category];
    let queueChoices: array<CName> = [choice];
    let checked: array<Uint64>;
    let iterations: Int32 = 0;
    while ArraySize(queueCategories) > 0 && iterations < 10 {
      iterations += 1;
      let nextCategory: CName = queueCategories[0];
      let nextChoice: CName = queueChoices[0];
      ArrayErase(queueCategories, 0);
      ArrayErase(queueChoices, 0);
      let key: Uint64 = GarageConstraints.Key(nextCategory, nextChoice);
      if !ArrayContains(checked, key) {
        ArrayPush(checked, key);
        let conflicts: array<ref<GarageConflict>> = this.Conflicts(nextCategory, nextChoice, settings);
        for conflict in conflicts {
          if IsNameValid(conflict.resolve) && !Equals(settings.Get(conflict.target), conflict.resolve) {
            settings.Set(conflict.target, conflict.resolve);
            changes.Set(conflict.target, conflict.resolve);
            ArrayPush(queueCategories, conflict.target);
            ArrayPush(queueChoices, conflict.resolve);
          }
        }
      }
    }
    if ArraySize(queueCategories) > 0 { XUtils.Mod("Garage").Log("Vehicle").Warn("constraints on " + NameToString(this.m_schema.id) + " may be circular"); }
    return changes;
  }
}
