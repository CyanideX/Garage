module Garage.World

import Garage.*
import Garage.Data.*
import Garage.Economy.*

/// One map pin per garage. A pin's caption carries what the icon and tooltip wraps need: Garage|title|description|id.
public class GarageMapPins extends IScriptable {
  private let m_locations: array<ref<GarageLocation>>;
  private let m_ids: array<NewMappinID>;
  private let m_timer: Uint64;
  private let m_xu: ref<XUtilsMod>;

  /// Pins these garages, replacing any there are.
  public func Start(xu: ref<XUtilsMod>, locations: array<ref<GarageLocation>>) -> Void {
    this.Stop();
    this.m_xu = xu;
    this.m_locations = locations;
    // The mappin system isn't ready at the moment V is
    this.m_timer = xu.After(2.0, this, n"OnRegister");
  }

  public func OnRegister(e: ref<XUtilsEvent>) -> Void {
    this.m_timer = 0ul;
    let system: ref<MappinSystem> = GameInstance.GetMappinSystem(GetGameInstance());
    if !IsDefined(system) { return; }
    let description: String = GarageText.Get(n"Garage-Map-Description");
    for location in this.m_locations {
      let data: MappinData;
      data.mappinType = t"Mappins.GarageMappinDefinition";
      data.variant = gamedataMappinVariant.CPO_PingLootVariant;
      data.active = true;
      data.visibleThroughWalls = false;
      data.debugCaption = "Garage|" + StrReplaceAll(location.name, "|", "/") + "|" + StrReplaceAll(description, "|", "/") + "|" + NameToString(location.id);
      let id: NewMappinID = system.RegisterMappin(data, location.deck.Position());
      system.SetMappinActive(id, true);
      ArrayPush(this.m_ids, id);
    }
  }

  public func Stop() -> Void {
    if this.m_timer != 0ul && IsDefined(this.m_xu) { this.m_xu.Cancel(this.m_timer); }
    this.m_timer = 0ul;
    let system: ref<MappinSystem> = GameInstance.GetMappinSystem(GetGameInstance());
    if IsDefined(system) {
      for id in this.m_ids { system.UnregisterMappin(id); }
    }
    ArrayClear(this.m_ids);
  }
}

// Cached so StrSplit doesn't run on every UpdateIcon of every pin. 0 unchecked, 1 ours, 2 not
@addField(BaseMappinBaseController)
private let garagePinType: Int32;

@addField(BaseMappinBaseController)
private let garagePinId: CName;

@addMethod(BaseMappinBaseController)
protected final func IsGaragePin() -> Bool {
  if this.garagePinType != 0 { return this.garagePinType == 1; }
  let parts: array<String> = StrSplit(this.GetMappin().GetDisplayName(), "|");
  if ArraySize(parts) >= 4 && Equals(parts[0], "Garage") {
    this.garagePinType = 1;
    this.garagePinId = StringToName(parts[3]);
    return true;
  }
  this.garagePinType = 2;
  return false;
}

@addMethod(BaseMappinBaseController)
protected final func ApplyGarageIcon(minimap: Bool) -> Void {
  if !this.IsGaragePin() { return; }
  let closed: Bool = GarageLocks.IsBanned(this.garagePinId) || GarageLocks.IsLocked(this.garagePinId);
  inkImageRef.SetAtlasResource(this.iconWidget, r"base\\gameplay\\gui\\common\\icons\\garage_mappin_icons.inkatlas");
  inkImageRef.SetTexturePart(this.iconWidget, closed ? n"garage_closed" : n"garage");
  let scale: Float = minimap ? 0.60 : 0.65;
  inkWidgetRef.SetScale(this.iconWidget, new Vector2(scale, scale));
}

@wrapMethod(MinimapPOIMappinController)
protected final func UpdateIcon() -> Void {
  wrappedMethod();
  this.ApplyGarageIcon(true);
}

@wrapMethod(QuestMappinController)
protected func UpdateIcon() -> Void {
  wrappedMethod();
  this.ApplyGarageIcon(false);
}

@wrapMethod(BaseWorldMapMappinController)
protected func UpdateIcon() -> Void {
  wrappedMethod();
  this.ApplyGarageIcon(false);
}

@wrapMethod(WorldMapTooltipController)
public func SetData(const data: script_ref<WorldMapTooltipData>, menu: ref<WorldMapMenuGameController>) -> Void {
  wrappedMethod(data, menu);
  let parts: array<String> = StrSplit(Deref(data).mappin.GetDisplayName(), "|");
  if ArraySize(parts) < 4 || !Equals(parts[0], "Garage") { return; }
  let title: String = parts[1];
  let description: String = parts[2];
  let id: CName = StringToName(parts[3]);
  if GarageLocks.IsBanned(id) {
    title += " " + GarageText.Get(n"Garage-Map-ClosedSuffix");
    description += "\n\n" + GarageText.Get(n"Garage-Map-BannedIndefinitely");
  } else {
    if GarageLocks.IsLocked(id) {
      title += " " + GarageText.Get(n"Garage-Map-ClosedSuffix");
      description += "\n\n" + GarageLocks.LockText(id);
    }
  }
  inkTextRef.SetText(this.m_titleText, title);
  inkTextRef.SetText(this.m_descText, description);
}
