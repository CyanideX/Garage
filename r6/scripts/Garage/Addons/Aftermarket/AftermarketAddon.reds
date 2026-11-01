module Garage.Aftermarket

import Codeware.UI.*
import Garage.*
import Garage.Audio.*
import Garage.Scene.*
import Garage.Services.*
import Garage.UI.*
import Garage.Vehicle.*

public class AftermarketAddon extends GarageAddon {
  private let m_flow: ref<PartsFlow>;

  public func Id() -> CName { return n"aftermarket"; }
  public func IsEnabled(settings: ref<GarageSettings>) -> Bool { return settings.aftermarketEnabled; }

  public func Services() -> array<ref<GarageService>> {
    let list: array<ref<GarageService>>;
    ArrayPush(list, new AftermarketService());
    return list;
  }

  public func RegisterScreens(screens: ref<ScreenManager>, frame: ref<GarageFrame>) -> Void {
    this.m_flow = PartsFlow.Create(screens);
    this.Add(n"parts_category", new CategoryScreen(), screens, frame);
    this.Add(n"parts_subcategory", new SubcategoryScreen(), screens, frame);
    this.Add(n"parts_partsList", new PartsListScreen(), screens, frame);
    this.Add(n"parts_paintType", new PaintTypeScreen(), screens, frame);
    this.Add(n"parts_confirm", new ConfirmScreen(), screens, frame);
    this.Add(n"parts_checkout", new CheckoutScreen(), screens, frame);
  }

  public func OnVisitEnd(ctx: ref<GarageContext>) -> Void {
    if IsDefined(this.m_flow) { this.m_flow.End(); }
    this.m_flow = null;
  }

  private func Add(name: CName, screen: ref<AftermarketScreen>, screens: ref<ScreenManager>, frame: ref<GarageFrame>) -> Void {
    screen.CreateInstance();
    screen.SetFlow(this.m_flow);
    frame.AddScreen(screen);
    screens.RegisterScreen(name, screen);
  }
}

// Vanilla cars still get the button. It's muted, and clicking it says why
public class AftermarketService extends GarageService {
  public func Id() -> CName { return n"aftermarket"; }
  public func Label() -> String { return GarageText.Get(n"Garage-Desc-Parts"); }
  public func Priority() -> Int32 { return 20; }
  public func IsMuted(ctx: ref<GarageContext>) -> Bool { return !ctx.hasSchema; }

  public func Open(ctx: ref<GarageContext>) -> Void {
    if ctx.hasSchema {
      ctx.screens.ShowScreen(n"parts_category");
    } else {
      ctx.screens.ShowUnavailable(GarageText.Get(n"Garage-Unavailable-PartsTitle"), GarageText.Get(n"Garage-Unavailable-PartsMessage"));
    }
  }
}

/// Where the player is in the parts screens this visit.
public class PartsFlow {
  public let section: CName;
  public let slot: CName;
  public let slotName: String;
  public let isColor: Bool;
  public let finish: CName;
  public let pick: ref<GaragePick>;
  private let m_screens: wref<ScreenManager>;
  private let m_log: ref<XUtilsLog>;
  private let m_open: CName;
  private let m_listSlot: CName;
  private let m_listFinish: CName;
  private let m_listPage: Int32;
  private let m_hovered: CName;

  public static func Create(screens: ref<ScreenManager>) -> ref<PartsFlow> {
    let flow: ref<PartsFlow> = new PartsFlow();
    flow.m_screens = screens;
    flow.m_log = XUtils.Mod("Garage").Log("UI");
    return flow;
  }

  public func End() -> Void {
    this.pick = null;
    this.m_open = n"";
  }

  public func Parts() -> ref<GarageParts> { return GarageSystem.Get().Parts(); }

  public func Vehicle() -> wref<VehicleObject> { return this.Parts().Context().vehicle; }

  public func Show(name: CName) -> Void {
    let screens: ref<ScreenManager> = this.m_screens;
    if IsDefined(screens) { screens.ShowScreen(name); }
  }

  public func GoBack() -> Void {
    let screens: ref<ScreenManager> = this.m_screens;
    if IsDefined(screens) { screens.GoBack(); }
  }

  public func OpenSection(section: CName) -> Void {
    this.section = section;
    this.Show(n"parts_subcategory");
  }

  public func OpenSlot(info: ref<GarageCategoryInfo>) -> Void {
    this.slot = info.id;
    this.slotName = info.name;
    this.isColor = info.isColor;
    this.finish = n"";
    this.Show(GarageColors.HasPaintFinishes(NameToString(info.id)) ? n"parts_paintType" : n"parts_partsList");
  }

  public func OpenFinish(finish: CName) -> Void {
    this.finish = finish;
    this.Show(n"parts_partsList");
  }

  public func ChoosePart(choice: CName) -> Void {
    this.pick = this.Parts().Pick(this.slot, choice);
    if !IsDefined(this.pick) { return; }
    if Equals(this.slot, n"seat_color") {
      GarageSounds.PlayFabric();
    } else if PartsFlow.SoundsLikePaint(this.slot) {
      GarageSounds.PlayPaint();
    }
    this.Show(n"parts_confirm");
  }

  private static func SoundsLikePaint(id: CName) -> Bool {
    return Equals(id, n"car_paint") || Equals(id, n"car_secpaint") || Equals(id, n"brake_color")
           || Equals(id, n"wheel_f_color") || Equals(id, n"wheel_b_color") || Equals(id, n"wheel_rim_color") || Equals(id, n"wheel_all_color")
           || Equals(id, n"interior_color") || Equals(id, n"interior_seccolor") || Equals(id, n"roof") || Equals(id, n"roof_color");
  }

  /// The pick again, for when the cart moved under it. The car's left as it is.
  public func Reassess() -> Void {
    if IsDefined(this.pick) { this.pick = this.Parts().Assess(this.pick.slot, this.pick.choice); }
  }

  public func DescriptionOfPick() -> String {
    if StrLen(this.pick.description) > 0 { return this.pick.description; }
    let name: String = StrLen(this.slotName) > 0 ? this.slotName : StrUpper(NameToString(this.slot));
    if Equals(this.pick.status, EGaragePartStatus.Stock) { return GarageText.Get(n"Garage-PartsList-FactoryOriginal") + " " + name; }
    if Equals(this.pick.status, EGaragePartStatus.Owned) { return GarageText.Get(n"Garage-PartsList-PreviouslyPurchased") + " " + name; }
    return GarageText.Get(n"Garage-PartsList-Aftermarket") + " " + name + " " + GarageText.Get(n"Garage-PartsList-Upgrade");
  }

  /// Camera, doors and lights for the slot, once per trip into it. Coming back to the list doesn't run this again.
  public func EnterSlot() -> Void {
    if Equals(this.m_open, this.slot) { return; }
    this.LeaveSlot();
    this.m_open = this.slot;
    GarageSystem.Get().Scene().GoToCategory(this.slot);
    let vehicle: wref<VehicleObject> = this.Vehicle();
    if !IsDefined(vehicle) { return; }
    if Equals(this.slot, n"headlight") || Equals(this.slot, n"popup") || Equals(this.slot, n"taillight") { VehicleStateHelper.EnableHighBeams(vehicle); }
    if Equals(this.slot, n"popup") { VehicleStateHelper.RaisePopupHeadlights(vehicle); }
    let name: String = NameToString(this.slot);
    if VehicleStateHelper.ShouldOpenHood(name) { VehicleStateHelper.OpenHood(vehicle); }
    if VehicleStateHelper.ShouldOpenTrunk(name) { VehicleStateHelper.OpenTrunk(vehicle); }
  }

  /// The screens above the list call this when they show, so no way out of a slot can leave its preview, doors or lights on.
  public func LeaveSlot() -> Void {
    if !IsNameValid(this.m_open) { return; }
    this.Parts().LeaveSlot(this.m_open);
    this.m_open = n"";
    let vehicle: wref<VehicleObject> = this.Vehicle();
    if IsDefined(vehicle) { VehicleStateHelper.ResetView(vehicle); }
  }

  // Only the list you're on keeps its page, going anywhere else starts the next one from the top
  public func ListPage() -> Int32 {
    return Equals(this.m_listSlot, this.slot) && Equals(this.m_listFinish, this.finish) ? this.m_listPage : 0;
  }

  public func SaveListPage(page: Int32) -> Void {
    this.m_listSlot = this.slot;
    this.m_listFinish = this.finish;
    this.m_listPage = page;
  }

  public func Hover(id: CName) -> Void {
    if Equals(this.m_hovered, id) || !GarageSettings.Get().cameraOnHover { return; }
    this.m_hovered = id;
    GarageSystem.Get().Scene().HoverCategory(id);
  }

  public func ForgetHover() -> Void { this.m_hovered = n""; }

  // Script has no real clock, so a begin and a done line time it off the log's stamps
  public func Mark(what: String) -> Void {
    if this.m_log.IsEnabled(XUtilsLogLevel.Debug) { this.m_log.Debug("parts " + what + " " + NameToString(this.slot)); }
  }
}

public static func PartsLabel(name: CName, text: String, style: CName, size: Int32, tint: HDRColor, parent: ref<inkCompoundWidget>) -> ref<inkText> {
  let label: ref<inkText> = new inkText();
  label.SetName(name);
  label.SetText(text);
  label.SetFontFamily("base\\gameplay\\gui\\fonts\\raj\\raj.inkfontfamily");
  label.SetFontStyle(style);
  label.SetFontSize(size);
  label.SetTintColor(tint);
  label.Reparent(parent);
  return label;
}

public abstract class AftermarketScreen extends GarageScreen {
  protected let m_flow: ref<PartsFlow>;

  public func SetFlow(flow: ref<PartsFlow>) -> Void { this.m_flow = flow; }

  protected func Parts() -> ref<GarageParts> { return GarageSystem.Get().Parts(); }

  protected func Vehicle() -> wref<VehicleObject> { return this.Parts().Context().vehicle; }

  public func OnPartsButtonClick(id: CName) -> Void {}

  public func OnPartsButtonHover(id: CName) -> Void {}

  protected func CreateSubtitle(root: ref<inkCanvas>, text: String, size: Int32, marginTop: Float) -> Void {
    let subtitle: ref<inkText> = PartsLabel(n"subtitle", text, n"Regular", size, GarageColors.AccentBlue(), root);
    subtitle.SetOpacity(0.6);
    subtitle.SetAnchor(inkEAnchor.TopCenter);
    subtitle.SetAnchorPoint(new Vector2(0.5, 0.0));
    subtitle.SetMargin(new inkMargin(0.0, marginTop, 0.0, 0.0));
    subtitle.SetHorizontalAlignment(textHorizontalAlignment.Center);
  }

  protected func CreateColumn(root: ref<inkCanvas>, name: CName) -> ref<inkVerticalPanel> {
    let column: ref<inkVerticalPanel> = new inkVerticalPanel();
    column.SetName(name);
    column.SetAnchor(inkEAnchor.TopCenter);
    column.SetAnchorPoint(new Vector2(0.5, 0.0));
    column.SetMargin(new inkMargin(0.0, 150.0, 0.0, 0.0));
    column.SetFitToContent(true);
    column.SetChildMargin(new inkMargin(0.0, 8.0, 0.0, 8.0));
    column.Reparent(root);
    return column;
  }
}
