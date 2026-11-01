module Garage.Scene

import Garage.*
import Garage.Data.*
import Garage.Vehicle.*
import VehicleCore.Schema.*

/// The camera while a garage is open: idle paths with bars and fades, then positions around the car for the parts screens.
/// Nothing runs per frame. Screens ask for positions by category, and services by name.
public class GarageScene extends IScriptable {
  private let m_xu: ref<XUtilsMod>;
  private let m_log: ref<XUtilsLog>;
  private let m_open: Bool;
  private let m_location: ref<GarageLocation>;
  private let m_vehicle: wref<VehicleObject>;
  private let m_schema: ref<VehicleSchema>;
  private let m_placed: ref<GaragePlacedScene>;
  private let m_timeline: ref<XUtilsTimeline>;
  private let m_cloudCamera: ref<XUtilsPointCloudCamera>;
  private let m_bars: ref<XUtilsBars>;
  private let m_driverListen: Uint64;
  private let m_lens: ref<XUtilsLensRequest>;
  private let m_fade: ref<XUtilsFade>;
  private let m_servicePath: ref<XUtilsPlayback>;
  private let m_settleTimer: Uint64;
  private let m_spot: XUtilsPose;
  private let m_hasSpot: Bool;
  private let m_lastPosition: CName;
  private let m_preCheckout: CName;

  public func Setup(xu: ref<XUtilsMod>) -> Void {
    this.m_xu = xu;
    this.m_log = xu.Log("Scene");
  }

  // --- Opening and closing

  public func Open(location: ref<GarageLocation>, vehicle: wref<VehicleObject>, schema: ref<VehicleSchema>) -> Void {
    this.Close();
    this.m_open = true;
    this.m_location = location;
    this.m_vehicle = vehicle;
    this.m_schema = schema;
    let settings: ref<GarageSettings> = GarageSettings.Get();
    // Blend off snaps and builds behind black, so nobody sees the car teleport
    if !settings.cameraBlendEnabled || settings.cameraBlendInDuration <= 0.0 {
      this.m_fade = this.m_xu.Screen().Fade(XUtilsFadeOptions.Create().Out(1.0).In(2.0).Layer(XUtilsScreenLayer.Scene));
      this.m_fade.On(XUtilsEventType.FadedOut, this, n"OnBlack");
      this.m_fade.On(XUtilsEventType.FadeCleared, this, n"OnCleared");
      this.m_fade.Start();
      return;
    }
    this.SnapCar();
    this.Build();
  }

  public func OnBlack(e: ref<XUtilsEvent>) -> Void {
    if !this.m_open {
      if IsDefined(this.m_fade) { this.m_fade.Release(); }
      return;
    }
    this.SnapCar();
    // The car needs a moment to settle after the teleport, or the ground check reads it mid-drop
    this.m_settleTimer = this.m_xu.After(0.1, this, n"OnSettled");
  }

  public func OnSettled(e: ref<XUtilsEvent>) -> Void {
    this.m_settleTimer = 0ul;
    if this.m_open { this.Build(); }
    if IsDefined(this.m_fade) { this.m_fade.Release(); }
  }

  public func OnCleared(e: ref<XUtilsEvent>) -> Void {
    if IsDefined(this.m_fade) { this.m_fade.Destroy(); }
    this.m_fade = null;
  }

  private func SnapCar() -> Void {
    let vehicle: wref<VehicleObject> = this.m_vehicle;
    if !IsDefined(vehicle) { return; }
    let deck: ref<GarageSpot> = this.m_location.deck;
    let angles: EulerAngles;
    angles.Yaw = deck.yaw;
    GameInstance.GetTeleportationFacility(GetGameInstance()).Teleport(vehicle, deck.Position(), angles);
  }

  // The snap can park the car on V's old spot, so with no playerSpawn V goes beside it on the side they were nearer.
  // Closing leaves V here too
  private func PlacePlayer() -> Void {
    let location: ref<GarageLocation> = this.m_location;
    let player: ref<XUtilsPlayer> = this.m_xu.Player();
    let now: XUtilsPose = player.GetPose();
    let spot: XUtilsPose;
    let spawn: ref<GarageSpot> = location.playerSpawn;
    let angles: EulerAngles;
    if IsDefined(spawn) {
      angles.Yaw = spawn.yaw;
      spot = XUtilsPose.Make(spawn.Position(), angles);
    } else {
      let half: Vector4 = IsDefined(this.m_placed) ? this.m_placed.half : new Vector4(1.0, 2.5, 0.8, 0.0);
      let cosY: Float = CosF(Deg2Rad(location.deck.yaw));
      let sinY: Float = SinF(Deg2Rad(location.deck.yaw));
      let at: Vector4 = now.position;
      let dx: Float = at.X - location.deck.x;
      let dy: Float = at.Y - location.deck.y;
      let side: Float = (dx * cosY + dy * sinY >= 0.0 ? 1.0 : -1.0) * (half.X + 0.8);
      let along: Float = ClampF(-dx * sinY + dy * cosY, -half.Y, half.Y);
      let x: Float = location.deck.x + side * cosY - along * sinY;
      let y: Float = location.deck.y + side * sinY + along * cosY;
      let hit: XUtilsRayHit = this.m_xu.Ray().Ground(new Vector4(x, y, location.deck.z + 1.5, 1.0), XUtilsRayOptions.Create().Depth(5.0));
      let ground: Vector4 = hit.position;
      angles = now.rotation;
      spot = XUtilsPose.Make(new Vector4(x, y, hit.hit ? ground.Z : location.deck.z, 1.0), angles);
    }
    player.Teleport(spot);
    this.m_spot = spot;
    this.m_hasSpot = true;
  }

  private func Build() -> Void {
    this.m_placed = ScenePlacer.Place(this.m_xu, GarageSystem.Get().Data(), this.m_location, this.m_vehicle, this.m_schema);
    this.PlacePlayer();
    if IsDefined(this.m_placed) { this.StartCamera(); }
  }

  public func Close() -> Void {
    if !this.m_open { return; }
    this.m_open = false;
    if this.m_settleTimer != 0ul { this.m_xu.Cancel(this.m_settleTimer); }
    this.m_settleTimer = 0ul;
    let settings: ref<GarageSettings> = GarageSettings.Get();
    let camera: ref<XUtilsCamera> = this.m_xu.Camera();
    if this.m_driverListen != 0ul { camera.Off(this.m_driverListen); }
    this.m_driverListen = 0ul;
    if camera.IsMine() { camera.Stop(settings.cameraBlendEnabled ? settings.cameraBlendOutDuration : 0.0); }
    if IsDefined(this.m_bars) { this.m_bars.Destroy(); }
    this.m_bars = null;
    if IsDefined(this.m_lens) { this.m_lens.Release(); }
    this.m_lens = null;
    if this.m_hasSpot { this.m_xu.Player().Teleport(this.m_spot); }
    this.m_hasSpot = false;
    this.m_timeline = null;
    this.m_cloudCamera = null;
    this.m_servicePath = null;
    this.m_placed = null;
    this.m_location = null;
    this.m_lastPosition = n"";
    this.m_preCheckout = n"";
    // A fade still on screen looks after itself, it comes back when released
    if IsDefined(this.m_fade) { this.m_fade.Release(); }
  }

  // --- The camera

  private func StartCamera() -> Void {
    let settings: ref<GarageSettings> = GarageSettings.Get();
    let camera: ref<XUtilsCamera> = this.m_xu.Camera();
    let blendIn: Float = settings.cameraBlendEnabled ? settings.cameraBlendInDuration : 0.0;
    let blendOut: Float = settings.cameraBlendEnabled ? settings.cameraBlendOutDuration : 0.0;
    let options: ref<XUtilsCameraOptions> = XUtilsCameraOptions.FromHolds(XUtilsHoldSet.Cinematic).Hold(XUtilsHold.HideCrosshair)
      .Blend(blendIn, blendOut).Restore(XUtilsRestore.None).Follow(XUtilsFollow.None());
    if !camera.Start(options) {
      this.m_log.Warn("couldn't start the camera, " + camera.GetOwner() + " has it");
      return;
    }
    let cloud: ref<XUtilsPointCloud> = this.m_placed.cloud;
    if IsDefined(cloud) {
      this.m_cloudCamera = camera.PointCloud(cloud);
      this.m_cloudCamera.SetTransition(XUtilsTransition.Orbit().Duration(0.75).Ease(XUtilsEase.SmootherInOut).ArcEase(XUtilsEase.SmootherInOut).ArcBias(XUtilsArcBias.Left));
      this.m_cloudCamera.SetLookAt(this.LookAt(settings));
      let partShake: String = this.m_location.camera.partViewShake;
      if settings.shakeEnabled && StrLen(partShake) > 0 {
        let shake: ref<XUtilsShake> = camera.Shake(StringToName(partShake));
        shake.SetIntensity(1.0);
        shake.SetFrequency(0.1);
        shake.SetLookAtPull(1.0);
        if settings.perlinShakeEnabled { shake.SetNoise(XUtilsShakeNoise.Perlin); }
        this.m_cloudCamera.SetShake(shake);
      }
    }
    this.BuildTimeline(camera, settings);
    this.StartBars(camera, settings);
    this.ApplyLens();
    if IsDefined(this.m_timeline) {
      this.m_timeline.Drive();
    } else {
      if IsDefined(this.m_cloudCamera) { this.m_cloudCamera.Drive(); }
    }
  }

  // Targets come off each point's own rotation. The shake pulls at full strength, so aiming at the car's centre swings every shot as it lands
  private func LookAt(settings: ref<GarageSettings>) -> ref<XUtilsLookAt> {
    // Perlin comes out weaker than a sine, so it gets more range to work with
    let perlin: Bool = settings.perlinShakeEnabled;
    return XUtilsLookAt.Raycast().Groups(XUtilsCollision.PlayerBlocker).FocalDistance(5.0).Scaling(1.0, 10.0)
      .Intensity(0.15, perlin ? 2.5 : 1.5).Sway(0.0, perlin ? 1.8 : 1.3);
  }

  private static func Cross(fadeOut: Float, fadeIn: Float) -> ref<XUtilsTransition> {
    return XUtilsTransition.Fade(fadeOut, fadeIn).Layer(XUtilsScreenLayer.Scene).FadeCurves(XUtilsEase.QuartIn, XUtilsEase.QuartOut);
  }

  private func BuildTimeline(camera: ref<XUtilsCamera>, settings: ref<GarageSettings>) -> Void {
    let entries: array<ref<GarageIdleEntry>> = this.m_placed.entries;
    if ArraySize(entries) == 0 { return; }
    let timeline: ref<XUtilsTimeline> = camera.Timeline();
    timeline.SetLoop(true);
    timeline.SetShuffle(settings.shufflePathsEnabled);
    timeline.SetResume(true);
    timeline.SetMaxEntrySeconds(MinF(6.0, this.m_location.camera.maxIdleSeconds));
    if ArraySize(entries) > 1 { timeline.SetBetween(GarageScene.Cross(2.75, 2.75)); }
    let idleShake: String = settings.shakeEnabled && settings.cinematicShakeEnabled ? this.m_location.camera.idleShake : "";
    let titled: Bool = false;
    for entry in entries {
      let playback: ref<XUtilsPlayback> = camera.Play(entry.path);
      entry.playback = playback;
      if StrLen(idleShake) > 0 {
        let shake: ref<XUtilsShake> = camera.Shake(StringToName(idleShake));
        shake.SetStrength(entry.shakeIntensity);
        shake.SetSpeed(entry.shakeFrequency);
        if settings.perlinShakeEnabled { shake.SetNoise(XUtilsShakeNoise.Perlin); }
        playback.SetShake(shake);
      }
      // A timeline holds one title, the others just play in the queue
      if entry.title && !titled {
        titled = true;
        timeline.SetTitle(playback, entry.name);
      } else {
        timeline.Add(playback, entry.name);
      }
    }
    timeline.On(XUtilsEventType.EntryStart, this, n"OnEntryStart");
    this.m_timeline = timeline;
  }

  private func StartBars(camera: ref<XUtilsCamera>, settings: ref<GarageSettings>) -> Void {
    if !settings.cinematicBarsEnabled { return; }
    let options: ref<XUtilsBarsOptions> = XUtilsBarsOptions.Create().Aspect(2.35).Opacity(1.0).In(2.0, XUtilsEase.SmoothestInOut).Out(0.5, XUtilsEase.SmoothestInOut).Expand(true).Layer(XUtilsScreenLayer.Scene);
    this.m_bars = this.m_xu.Screen().Bars(options);
    this.m_driverListen = camera.On(XUtilsEventType.DriverChange, this, n"OnDriverChange");
    if IsDefined(this.m_timeline) { this.m_bars.Show(); }
  }

  public func OnDriverChange(e: ref<XUtilsEvent>) -> Void {
    if !IsDefined(this.m_bars) { return; }
    // A service's own path counts as idle too. Positions get the whole screen
    if e.index == EnumInt(XUtilsDriverKind.Timeline) || e.index == EnumInt(XUtilsDriverKind.Playback) {
      this.m_bars.Show();
    } else {
      this.m_bars.Hide();
    }
  }

  // --- Lens

  /// Picks up changed DOF settings while the garage's open.
  public func ApplyLens() -> Void {
    let settings: ref<GarageSettings> = GarageSettings.Get();
    if !this.m_open { return; }
    if !settings.dofEnabled {
      if IsDefined(this.m_lens) { this.m_lens.Release(); }
      this.m_lens = null;
      return;
    }
    if !IsDefined(this.m_lens) { this.m_lens = this.m_xu.Lens().Request(50, "garage"); }
    let lens: ref<XUtilsLensRequest> = this.m_lens;
    // Zone fit: a real lens this wide keeps either the whole garage sharp or only a slice of the car
    lens.SetOption(XUtilsLensParam.LookFit, EnumInt(XUtilsLookFit.Zone));
    lens.Set(XUtilsLensParam.DofTransition, 0.3);
    lens.Set(XUtilsLensParam.LookZoneFront, 0.25);
    lens.Set(XUtilsLensParam.LookZoneBehind, settings.dofFocusDepth);
    lens.Set(XUtilsLensParam.LookZoneFalloff, settings.dofFalloff);
    lens.Set(XUtilsLensParam.LookMaxBlur, 0.5);
    lens.Set(XUtilsLensParam.LookBlurScale, settings.dofIntensity);
    lens.SetFlag(XUtilsLensParam.LookUseNear, Equals(settings.dofMode, GarageDofMode.Both));
    lens.SetFlag(XUtilsLensParam.LookUseFar, true);
    lens.SetOption(XUtilsLensParam.FocusGroups, EnumInt(XUtilsCollision.PlayerBlocker));
    lens.SetOption(XUtilsLensParam.FocusArea, EnumInt(XUtilsFocusArea.Spot));
    lens.Set(XUtilsLensParam.FocusMinRange, 0.5);
    lens.SetOption(XUtilsLensParam.FocusOnMiss, EnumInt(XUtilsFocusOnMiss.Off));
    lens.Set(XUtilsLensParam.FocusSpeed, 0.4 / 3.0);
    lens.Set(XUtilsLensParam.FocusManualSpeed, 0.0);
    this.WireFocusKeys();
    if IsDefined(this.m_cloudCamera) && this.m_cloudCamera.IsDriving() {
      lens.Focus(XUtilsFocus.Driver(this.m_cloudCamera));
    } else {
      lens.Focus(XUtilsFocus.Auto());
    }
  }

  private func WireFocusKeys() -> Void {
    if !IsDefined(this.m_placed) { return; }
    let entries: array<ref<GarageIdleEntry>> = this.m_placed.entries;
    for entry in entries {
      if ArraySize(entry.focusKeys) > 0 {
        let track: ref<XUtilsLensTrack> = this.m_xu.Motion().LensTrack();
        let i: Int32 = 0;
        while i < ArraySize(entry.focusKeys) {
          track.Key(XUtilsTrackAt.Waypoint(entry.focusKeys[i]), XUtilsFocus.Point(entry.focusPoints[i]));
          i += 1;
        }
        track.SetRequest(this.m_lens);
        entry.path.SetLensTrack(track);
      }
    }
  }

  // A shared point's held by the engine, and waypoint focus runs off the path's own lens track
  public func OnEntryStart(e: ref<XUtilsEvent>) -> Void {
    // A path can still roll over while the camera's on its way to a position, and that focus isn't ours to take
    if !IsDefined(this.m_lens) || IsNameValid(this.m_lastPosition) { return; }
    let entries: array<ref<GarageIdleEntry>> = this.m_placed.entries;
    for entry in entries {
      if Equals(entry.name, e.text) {
        if entry.hasFocusPoint {
          this.m_lens.Focus(XUtilsFocus.Point(entry.focusPoint));
        } else {
          if ArraySize(entry.focusKeys) == 0 { this.m_lens.Focus(XUtilsFocus.Auto()); }
        }
        return;
      }
    }
  }

  // --- Positions

  /// Moves to a named cloud position, falling back to default. From the idle paths it orbits in from wherever the path is.
  public func GoTo(name: String) -> Void {
    if !IsDefined(this.m_cloudCamera) || StrLen(name) == 0 { return; }
    let cloud: ref<XUtilsPointCloud> = this.m_placed.cloud;
    let target: CName = StringToName(StrLower(name));
    if cloud.Find(target) < 0 { target = n"default"; }
    let index: Int32 = cloud.Find(target);
    if index < 0 { return; }

    if this.m_cloudCamera.IsDriving() {
      if Equals(target, this.m_lastPosition) { return; }
      this.m_cloudCamera.GoToName(target);
    } else {
      this.m_cloudCamera.SetStart(index);
      this.m_cloudCamera.Drive(XUtilsTransition.Orbit().Duration(0.75).Ease(XUtilsEase.SineInOut));
    }
    if IsDefined(this.m_lens) { this.m_lens.Focus(XUtilsFocus.Driver(this.m_cloudCamera)); }
    this.m_lastPosition = target;
  }

  /// A parts category's position: the schema's override, its slot, the cloud's slot, then slots that stand in for it.
  public func GoToCategory(category: CName) -> Void {
    if !IsDefined(this.m_placed) { return; }
    this.GoTo(NameToString(this.ResolveCategory(category)));
  }

  /// Follows a hover, but never pulls the camera out of the idle paths.
  public func HoverCategory(category: CName) -> Void {
    if IsDefined(this.m_cloudCamera) && this.m_cloudCamera.IsDriving() { this.GoTo(NameToString(this.ResolveCategory(category))); }
  }

  private func ResolveCategory(category: CName) -> CName {
    let cloud: ref<XUtilsPointCloud> = this.m_placed.cloud;
    if IsDefined(this.m_schema) {
      let point: CName = this.m_schema.GetCameraPoint(category);
      if IsNameValid(point) { return point; }
    }
    let slot: CName = this.SlotOf(category);
    if !IsNameValid(slot) && GarageScene.IsKnownSlot(category) { slot = category; }
    if !IsNameValid(slot) { return IsDefined(cloud) && cloud.Find(category) >= 0 ? category : n"default"; }
    if !IsDefined(cloud) || cloud.Find(slot) >= 0 { return slot; }
    let fallbacks: array<String> = GarageScene.SlotFallbacks(slot);
    for fallback in fallbacks {
      if cloud.Find(StringToName(fallback)) >= 0 { return StringToName(fallback); }
    }
    return n"default";
  }

  private func SlotOf(category: CName) -> CName {
    if IsDefined(this.m_schema) {
      let own: ref<VehicleSlot> = this.m_schema.GetSlotFor(category);
      if IsDefined(own) { return own.id; }
    }
    let slots: ref<XUtilsJson> = this.m_placed.slots;
    if !IsDefined(slots) { return n""; }
    let name: String = NameToString(category);
    let i: Int32 = 0;
    while i < slots.Size() {
      let slot: ref<XUtilsJson> = slots.At(i);
      let maps: ref<XUtilsJson> = slot.Get("maps");
      let j: Int32 = 0;
      while j < maps.Size() {
        if Equals(StrLower(maps.StringAt(j)), StrLower(name)) { return StringToName(slot.GetString("id", "")); }
        j += 1;
      }
      i += 1;
    }
    return n"";
  }

  private static func SlotTable() -> String {
    return "default:;checkout:;showcase:;stock:;bumper_front:;splitter_front:bumper_front;headlight:bumper_front;headlight_l:headlight,bumper_front;headlight_r:headlight,bumper_front;"
         + "signlight:headlight,bumper_front;canard:bumper_front;popup:hood,bumper_front;bumper_back:;splitter_back:bumper_back;taillight:bumper_back;taillight_l:taillight,bumper_back;"
         + "taillight_r:taillight,bumper_back;exhaust:bumper_back;hood:;roof:;window_front:hood,roof;window_back:roof;wing:;spoiler:wing;cargo:bumper_back;cargo_hood:hood;side_left:;"
         + "splitter_side:wheel_all,side_left;skirt_side:splitter_side,side_left;mirror:side_left;mirror_l:mirror,side_left;mirror_r:mirror,side_left;fuelcap:side_left,bumper_back;"
         + "fender_front:side_left,bumper_front;fender_back:side_left,bumper_back;window_side:side_left;wheel_front:;wheel_back:wheel_front;wheel_all:wheel_front;paint_brake:wheel_front;"
         + "wheel_all_color:wheel_all;paint_body:;interior_dash:interior_trim;interior_trim:interior_seats;interior_seats:;interior_color:interior_trim;"
         + "interior_all:interior_color,interior_seats,interior_trim;steering_wheel:interior_dash,interior_trim;rollcage:interior_dash,interior_trim;bobble_head:interior_dash;"
         + "hook:bumper_back;ext:;ext_01:ext;ext_02:ext;ext_03:ext;ext_04:ext;ext_05:ext;ext_06:ext;ext_07:ext;ext_08:ext";
  }

  private static func IsKnownSlot(slot: CName) -> Bool {
    return StrContains(";" + GarageScene.SlotTable(), ";" + NameToString(slot) + ":");
  }

  private static func SlotFallbacks(slot: CName) -> array<String> {
    let rows: array<String> = StrSplit(GarageScene.SlotTable(), ";");
    let prefix: String = NameToString(slot) + ":";
    for row in rows {
      if StrBeginsWith(row, prefix) {
        let rest: String = StrRight(row, StrLen(row) - StrLen(prefix));
        if StrLen(rest) > 0 { return StrSplit(rest, ","); }
      }
    }
    let none: array<String>;
    return none;
  }

  public func Checkout() -> Void {
    if !IsDefined(this.m_cloudCamera) { return; }
    this.m_preCheckout = this.m_cloudCamera.IsDriving() ? this.m_lastPosition : n"";
    this.GoTo("checkout");
  }

  /// Back to where it was before checkout, or default, or the idle paths.
  public func ExitCheckout() -> Void {
    if !IsDefined(this.m_cloudCamera) { return; }
    let cloud: ref<XUtilsPointCloud> = this.m_placed.cloud;
    let target: CName = IsNameValid(this.m_preCheckout) ? this.m_preCheckout : n"default";
    this.m_preCheckout = n"";
    if cloud.Find(target) >= 0 || cloud.Find(n"default") >= 0 {
      this.GoTo(NameToString(target));
    } else {
      this.ReturnToIdle();
    }
  }

  /// The explode point, else checkout, else the camera stays where it is.
  public func Explode() -> Void {
    if !IsDefined(this.m_placed) || !IsDefined(this.m_cloudCamera) { return; }
    let cloud: ref<XUtilsPointCloud> = this.m_placed.cloud;
    if cloud.Find(n"explode") >= 0 {
      this.GoTo("explode");
    } else {
      if cloud.Find(n"checkout") >= 0 { this.GoTo("checkout"); }
    }
  }

  public func ReturnToIdle() -> Void {
    this.m_lastPosition = n"";
    this.m_preCheckout = n"";
    if IsDefined(this.m_timeline) && !this.m_timeline.IsDriving() {
      this.m_timeline.Drive(GarageScene.Cross(0.5, 0.5));
      if IsDefined(this.m_lens) { this.m_lens.Focus(XUtilsFocus.Auto()); }
    }
  }

  /// Plays one idle path by name, for a service with its own camera move. False if there's no such path.
  public func PlayPath(name: String) -> Bool {
    if !IsDefined(this.m_placed) { return false; }
    let entries: array<ref<GarageIdleEntry>> = this.m_placed.entries;
    for entry in entries {
      if Equals(entry.name, name) {
        this.m_servicePath = this.m_xu.Camera().Play(entry.path);
        this.m_servicePath.SetEnd(XUtilsEnd.Loop);
        this.m_servicePath.Drive(GarageScene.Cross(0.5, 0.5));
        return true;
      }
    }
    this.m_log.Warn("no idle path called " + name);
    this.ReleasePath();
    return false;
  }

  /// Hands back from a service's own path, unless the camera's busy at a position.
  public func ReleasePath() -> Void {
    if IsDefined(this.m_cloudCamera) && this.m_cloudCamera.IsDriving() { return; }
    this.ReturnToIdle();
  }
}
