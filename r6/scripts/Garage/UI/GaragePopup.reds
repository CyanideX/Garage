module Garage.UI

import Codeware.UI.*
import Garage.*
import Garage.Audio.*
import Garage.Data.*
import Garage.Services.*
import Garage.Vehicle.*
import Garage.World.*
import VehicleCore.Features.*

/// The panel on the left of a garage. Esc and back go through ScreenManager.Back, holding them leaves from anywhere.
public class GaragePopup extends InGamePopup {
  private let m_header: ref<InGamePopupHeader>;
  private let m_footer: ref<InGamePopupFooter>;
  private let m_content: ref<InGamePopupContent>;
  private let m_frame: ref<GarageFrame>;
  private let m_screens: ref<ScreenManager>;
  private let m_cartWidget: ref<CartWidget>;
  private let m_exitWarning: ref<ExitWarningPopup>;
  private let m_location: ref<GarageLocation>;
  private let m_vehicle: wref<VehicleObject>;
  private let m_savedState: ref<VehicleSavedState>;
  private let m_holdTimer: Uint64;
  private let m_watchTimer: Uint64;
  private let m_keepAliveTimer: Uint64;
  private let m_economyListen: Uint64;
  private let m_holding: Bool;
  private let m_holdCompleted: Bool;
  private let m_closing: Bool;
  private let m_abandoned: Bool;

  private static func HoldToExit() -> Float { return 0.3; }

  /// False if there's nothing to open it from yet.
  public static func Open(vehicle: wref<VehicleObject>, location: ref<GarageLocation>) -> Bool {
    let system: ref<GarageSystem> = GarageSystem.Get();
    let requester: wref<inkGameController> = system.Requester();
    if !IsDefined(requester) {
      system.Xu().Log("UI").Warn("no game controller to open the garage from");
      return false;
    }
    let popup: ref<GaragePopup> = new GaragePopup();
    popup.m_location = location;
    popup.m_vehicle = vehicle;
    system.Parts().Begin(vehicle, location);
    if IsDefined(vehicle) {
      popup.m_savedState = VehicleStateHelper.SaveState(vehicle);
      VehicleStateHelper.SetupForGarage(vehicle);
    }
    popup.Open(requester);
    return true;
  }

  protected cb func OnCreate() {
    super.OnCreate();
    this.m_container.SetAnchor(inkEAnchor.CenterLeft);
    this.m_container.SetAnchorPoint(new Vector2(0.0, 0.5));
    this.m_container.SetMargin(new inkMargin(80.0, 0.0, 0.0, 0.0));
    this.m_container.SetWidth(960.0);
    this.m_container.SetHeight(1200.0);

    this.m_header = InGamePopupHeader.Create();
    this.m_header.SetTitle(GetLocalizedTextByKey(n"Garage-Frame-Title"));
    this.m_header.SetFluffRight(GetLocalizedTextByKey(n"Garage-Frame-FluffRight"));
    this.m_header.Reparent(this);

    this.m_footer = InGamePopupFooter.Create();
    this.m_footer.SetFluffIcon(n"fluff_triangle2");
    this.m_footer.SetFluffText("CYX " + GetLocalizedTextByKey(n"Garage-Frame-GarageSystem") + " v1.0");
    this.m_footer.Reparent(this);

    this.m_content = InGamePopupContent.Create();
    this.m_content.Reparent(this);

    this.m_frame = GarageFrame.Create();
    this.m_frame.SetSize(this.m_content.GetSize());
    this.m_frame.SetGameInstance(this.GetGame());
    this.m_frame.Reparent(this.m_content);

    this.m_screens = ScreenManager.Create(this.m_frame);
    this.m_screens.SetPopup(this);

    let hub: ref<ServiceHubScreen> = new ServiceHubScreen();
    hub.CreateInstance();
    this.m_frame.AddScreen(hub);
    this.m_screens.RegisterScreen(n"hub", hub);

    let unavailable: ref<UnavailableScreen> = new UnavailableScreen();
    unavailable.CreateInstance();
    this.m_frame.AddScreen(unavailable);
    this.m_screens.RegisterScreen(n"unavailable", unavailable);

    let system: ref<GarageSystem> = GarageSystem.Get();
    system.RegisterScreens(this.m_screens, this.m_frame);

    this.m_cartWidget = new CartWidget();
    this.m_cartWidget.CreateInstance();
    this.m_cartWidget.SetScreenManager(this.m_screens);
    this.m_cartWidget.Reparent(this.GetRootCompoundWidget());
    this.m_cartWidget.Hide();

    this.m_exitWarning = new ExitWarningPopup();
    this.m_exitWarning.CreateInstance();
    this.m_exitWarning.SetParentPopup(this);
    this.m_exitWarning.SetScreenManager(this.m_screens);
    this.m_exitWarning.Reparent(this.GetRootCompoundWidget());
    this.m_cartWidget.SetExitWarningPopup(this.m_exitWarning);

    system.Parts().Context().screens = this.m_screens;
    system.SetPopup(this);
    system.OnGarageOpen(this.m_location, this.m_vehicle);
    this.m_screens.ShowScreen(n"hub");
    let vehicle: wref<VehicleObject> = this.m_vehicle;
    // Clears anything a preview tool left on the car
    if IsDefined(vehicle) { VehicleRefresh.Vehicle(vehicle); }
  }

  protected cb func OnInitialize() {
    super.OnInitialize();
    GarageSounds.PlayOpen();
    this.m_frame.SetHints(this.m_footer.GetHints());
    this.m_frame.RegisterToCallback(n"OnClosePopup", this, n"OnCloseRequest");
    this.m_frame.RegisterToCallback(n"OnScreenError", this, n"OnScreenError");
    this.m_frame.RegisterToCallback(n"OnCartChanged", this, n"OnCartChanged");
    this.RegisterToGlobalInputCallback(n"OnPostOnPress", this, n"OnButtonPress");
    this.RegisterToGlobalInputCallback(n"OnPostOnRelease", this, n"OnButtonRelease");
    let xu: ref<XUtilsMod> = GarageSystem.Get().Xu();
    this.m_watchTimer = xu.Every(0.25, this, n"OnWatch");
    this.m_keepAliveTimer = xu.Every(3.0, this, n"OnKeepAlive");
    this.m_economyListen = xu.OnCustom(GarageEvents.EconomyRefresh(), this, n"OnEconomyRefresh");
  }

  public func Close() {
    if this.m_closing { return; }
    if !IsDefined(this.m_screens) {
      this.ForceClose();
      return;
    }
    this.m_screens.Back();
  }

  public func DismissWarning() -> Bool {
    if !this.m_exitWarning.IsVisible() { return false; }
    if this.m_holdCompleted {
      this.m_holdCompleted = false;
    } else {
      this.m_exitWarning.Hide();
    }
    return true;
  }

  public func WarnGoingBack(cart: ref<GarageCart>) -> Void { this.m_exitWarning.ShowForBackNavigation(cart.Count(), cart.Total()); }

  public func WarnLeaving(cart: ref<GarageCart>) -> Void { this.m_exitWarning.Show(cart.Count(), cart.Total()); }

  // A second close would detach twice and pop the game context twice
  public func ForceClose() {
    if this.m_closing { return; }
    this.m_closing = true;
    this.StopListening();
    super.Close();
  }

  public func ForceCloseFromWarning() -> Void { this.ForceClose(); }

  // The session's going with us in it, so there's nothing to restore and no one to tell
  public func Abandon() -> Void {
    this.m_closing = true;
    this.m_abandoned = true;
    this.StopListening();
  }

  public func RefreshHub() -> Void {
    if IsDefined(this.m_screens) { this.m_screens.RefreshHub(); }
  }

  public func OnEconomyRefresh(e: ref<XUtilsEvent>) -> Void { this.RefreshHub(); }

  protected cb func OnCartChanged(widget: wref<inkWidget>) {
    this.m_cartWidget.RefreshDisplay();
  }

  // Global input reaches every popup, and 0.3 s of Esc meant for one above would count as hold to leave
  protected cb func OnButtonPress(evt: ref<inkPointerEvent>) {
    if this.m_closing || !this.IsTopPopup() { return; }
    if evt.IsAction(n"cancel") || evt.IsAction(n"back") || evt.IsAction(n"one_click_confirm") {
      this.m_holding = true;
      this.CancelTimer(this.m_holdTimer);
      this.m_holdTimer = GarageSystem.Get().Xu().After(GaragePopup.HoldToExit(), this, n"OnHoldComplete");
    }
  }

  protected cb func OnButtonRelease(evt: ref<inkPointerEvent>) {
    if this.m_closing { return; }
    if this.IsTopPopup() {
      if evt.IsAction(n"UI_MoveUp") || evt.IsAction(n"popup_moveUp") || evt.IsAction(n"scroll_up") {
        this.m_screens.ScrollUp();
        return;
      }
      if evt.IsAction(n"UI_MoveDown") || evt.IsAction(n"popup_moveDown") || evt.IsAction(n"scroll_down") {
        this.m_screens.ScrollDown();
        return;
      }
    }
    if this.m_holding {
      this.m_holding = false;
      this.CancelTimer(this.m_holdTimer);
      this.m_holdTimer = 0ul;
    }
  }

  public func OnHoldComplete(e: ref<XUtilsEvent>) -> Void {
    this.m_holdTimer = 0ul;
    if !this.m_holding || this.m_closing { return; }
    this.m_holding = false;
    if !this.IsTopPopup() { return; }
    let cart: ref<GarageCart> = GarageSystem.Get().Parts().Cart();
    if cart.Count() > 0 {
      this.m_holdCompleted = true;
      this.WarnLeaving(cart);
    } else {
      this.ForceClose();
    }
  }

  // The car can go away under us
  public func OnWatch(e: ref<XUtilsEvent>) -> Void {
    if this.m_closing { return; }
    let vehicle: wref<VehicleObject> = this.m_vehicle;
    if !IsDefined(vehicle) {
      GarageSystem.Get().Xu().Log("UI").Warn("the car went away mid-visit, closing");
      this.ForceClose();
    }
  }

  public func OnKeepAlive(e: ref<XUtilsEvent>) -> Void {
    if this.m_closing { return; }
    let vehicle: wref<VehicleObject> = this.m_vehicle;
    if IsDefined(vehicle) { VehicleStateHelper.PreventShutdown(vehicle); }
  }

  protected cb func OnCloseRequest(widget: wref<inkWidget>) { this.ForceClose(); }

  protected cb func OnScreenError(widget: wref<inkWidget>) {
    GarageSystem.Get().Xu().Log("UI").Warn("a screen failed, back to the hub");
    this.m_screens.ClearHistory();
    this.m_screens.ShowScreen(n"hub");
  }

  private func CancelTimer(timer: Uint64) -> Void {
    if timer != 0ul { GarageSystem.Get().Xu().Cancel(timer); }
  }

  private func StopListening() -> Void {
    this.CancelTimer(this.m_holdTimer);
    this.CancelTimer(this.m_watchTimer);
    this.CancelTimer(this.m_keepAliveTimer);
    this.m_holdTimer = 0ul;
    this.m_watchTimer = 0ul;
    this.m_keepAliveTimer = 0ul;
    this.m_holding = false;
    if this.m_economyListen != 0ul { GarageSystem.Get().Xu().Off(this.m_economyListen); }
    this.m_economyListen = 0ul;
  }

  protected cb func OnUninitialize() {
    this.StopListening();
    if this.m_abandoned {
      super.OnUninitialize();
      return;
    }
    let system: ref<GarageSystem> = GarageSystem.Get();
    let vehicle: wref<VehicleObject> = this.m_vehicle;
    system.EndVisit();
    system.Parts().RevertAll();
    if IsDefined(vehicle) {
      VehicleRefresh.Vehicle(vehicle);
      if IsDefined(this.m_savedState) { VehicleStateHelper.RestoreState(vehicle, this.m_savedState); }
      VehicleStateHelper.ResetView(vehicle);
    }
    system.OnGarageClose(this.m_location);
    super.OnUninitialize();
  }

  public func UseCursor() -> Bool { return true; }

  public func UseBlur() -> Bool { return false; }

  // The stock one's a red gradient over the car
  protected func CreateVignette() {
    let root: wref<inkCompoundWidget> = this.GetRootCompoundWidget();
    if IsDefined(root) {
      let vignette: ref<inkImage> = new inkImage();
      vignette.SetName(n"vignette");
      vignette.SetOpacity(0.0);
      vignette.SetVisible(false);
      vignette.Reparent(root);
    }
  }

  protected func SetBackgroundBlur() {}

  protected func ResetBackgroundBlur() {}

  // ModalPopup hides the HUD properly for something this big
  protected func SetUIContext() {
    GameInstance.GetUISystem(this.GetGame()).PushGameContext(UIGameContext.ModalPopup);
  }

  protected func ResetUIContext() {
    GameInstance.GetUISystem(this.GetGame()).PopGameContext(UIGameContext.ModalPopup);
  }

  // Only freezes the player, the world keeps going
  protected func SetTimeDilation() {
    GameInstance.GetTimeSystem(this.GetGame()).SetTimeDilationOnLocalPlayerZero(n"GarageMenu", 0.0);
  }

  protected func ResetTimeDilation() {
    GameInstance.GetTimeSystem(this.GetGame()).UnsetTimeDilationOnLocalPlayerZero(n"GarageMenu");
  }
}

// The menu controller's what a popup opens from, and this is the one moment it shows itself to us
@wrapMethod(gameuiInGameMenuGameController)
private final func RegisterInputListenersForPlayer(playerPuppet: ref<GameObject>) {
  wrappedMethod(playerPuppet);
  let system: ref<GarageSystem> = GarageSystem.Get();
  if IsDefined(system) { system.SetRequester(this); }
}

// Garages sit in restricted zones
@wrapMethod(VehicleSystem)
public final static func IsSummoningVehiclesRestricted(game: GameInstance) -> Bool {
  let system: ref<GarageSystem> = GarageSystem.Get();
  return IsDefined(system) && system.IsGarageOpen() ? false : wrappedMethod(game);
}
