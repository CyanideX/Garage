module Garage.Scene

import Garage.*
import Garage.Data.*
import Garage.Vehicle.*
import VehicleCore.Schema.*

// How a car measures up. half and offset are in the car's own frame
public class GarageMeasure extends IScriptable {
  public let half: Vector4;
  public let offset: Vector4;
  // From a table or schema, tuned for framing rather than the mesh
  public let overridden: Bool;
}

// Where a data file was captured
public class GarageFrameInfo extends IScriptable {
  public let center: Vector4;
  public let yaw: Float;
  public let half: Vector4;
}

// Moves points from one frame to another, with Garage's per-axis scale on generic data
public class GarageMover extends IScriptable {
  public let source: Vector4;
  public let target: Vector4;
  public let dYaw: Float;
  public let scaled: Bool;
  public let scaleX: Float;
  public let scaleY: Float;
  public let scaleZ: Float;
  public let floorZ: Float;
  private let m_cosR: Float;
  private let m_sinR: Float;
  private let m_cosY: Float;
  private let m_sinY: Float;

  public static func Make(from: ref<GarageFrameInfo>, center: Vector4, yaw: Float) -> ref<GarageMover> {
    let mover: ref<GarageMover> = new GarageMover();
    mover.source = from.center;
    mover.target = center;
    mover.dYaw = yaw - from.yaw;
    mover.m_cosR = CosF(Deg2Rad(mover.dYaw));
    mover.m_sinR = SinF(Deg2Rad(mover.dYaw));
    mover.m_cosY = CosF(Deg2Rad(yaw));
    mover.m_sinY = SinF(Deg2Rad(yaw));
    return mover;
  }

  public func Scale(x: Float, y: Float, z: Float, floorZ: Float) -> ref<GarageMover> {
    this.scaled = true;
    this.scaleX = x;
    this.scaleY = y;
    this.scaleZ = z;
    this.floorZ = floorZ;
    return this;
  }

  public func Move(p: Vector4) -> Vector4 {
    let dx: Float = p.X - this.source.X;
    let dy: Float = p.Y - this.source.Y;
    let rx: Float = dx * this.m_cosR - dy * this.m_sinR;
    let ry: Float = dx * this.m_sinR + dy * this.m_cosR;
    if !this.scaled { return new Vector4(this.target.X + rx, this.target.Y + ry, this.target.Z + p.Z - this.source.Z, 1.0); }
    let lx: Float = (rx * this.m_cosY + ry * this.m_sinY) * this.scaleX;
    let ly: Float = (-rx * this.m_sinY + ry * this.m_cosY) * this.scaleY;
    let z: Float = this.target.Z + (p.Z - this.source.Z) * this.scaleZ;
    return new Vector4(this.target.X + lx * this.m_cosY - ly * this.m_sinY, this.target.Y + lx * this.m_sinY + ly * this.m_cosY, MaxF(z, this.floorZ), 1.0);
  }
}

public class GarageIdleEntry extends IScriptable {
  public let name: String;
  public let path: ref<XUtilsPath>;
  public let playback: ref<XUtilsPlayback>;
  public let title: Bool;
  public let shakeIntensity: Float = 1.0;
  public let shakeFrequency: Float = 1.0;
  public let hasFocusPoint: Bool;
  public let focusPoint: Vector4;
  // Waypoint focus, parallel arrays. Only ever steers focus, a path's own look-at would aim the camera
  public let focusKeys: array<Int32>;
  public let focusPoints: array<Vector4>;
}

/// A scene fitted to one car at one garage.
public class GaragePlacedScene extends IScriptable {
  public let cloud: ref<XUtilsPointCloud>;
  public let entries: array<ref<GarageIdleEntry>>;
  public let center: Vector4;
  public let half: Vector4;
  public let slots: ref<XUtilsJson>;
}

/// Fits camera data to the car on the deck. Car data moves rigidly, generic data scales, nothing ends up in a wall or the floor.
/// Static garage paths stay where they were authored.
public abstract class ScenePlacer {
  private static func AdaptiveBoost() -> Float { return 1.08; }
  private static func ZDamping() -> Float { return 0.5; }
  private static func MinScale() -> Float { return 0.5; }
  private static func MinExterior() -> Float { return 0.30; }
  private static func WallClearance() -> Float { return 1.5; }
  private static func StandoffShare() -> Float { return 0.5; }

  public static func Place(xu: ref<XUtilsMod>, data: ref<GarageData>, location: ref<GarageLocation>, vehicle: wref<VehicleObject>, schema: ref<VehicleSchema>) -> ref<GaragePlacedScene> {
    let vehicleCloud: ref<XUtilsPointCloud> = IsDefined(schema) ? data.GetVehicleCloud(schema.id) : null;
    let isCar: Bool = IsDefined(vehicleCloud);
    let source: ref<XUtilsPointCloud> = isCar ? vehicleCloud : data.GetGarageCloud(location.id);
    if !IsDefined(source) { source = data.GetDefaultCloud(); }
    if !IsDefined(source) {
      xu.Log("Scene").Warn("no camera data at all for " + NameToString(location.id));
      return null;
    }
    let frame: ref<GarageFrameInfo> = ScenePlacer.FrameOf(source.ToJson());
    let yaw: Float = location.deck.yaw;
    let measured: ref<GarageMeasure> = ScenePlacer.Measure(xu, data, vehicle, schema, frame);
    let groundZ: Float = ScenePlacer.GroundZ(xu, vehicle, measured, location);
    let center: Vector4 = new Vector4(location.deck.x, location.deck.y, groundZ + (isCar ? frame.half.Z : measured.half.Z), 1.0);
    let larger: Bool = measured.half.X >= frame.half.X || measured.half.Y >= frame.half.Y;
    let geometry: ref<GarageMeasure> = ScenePlacer.Geometry(xu, vehicle, measured);

    let placed: ref<GaragePlacedScene> = new GaragePlacedScene();
    placed.center = center;
    placed.half = measured.half;

    let mover: ref<GarageMover> = GarageMover.Make(frame, center, yaw);
    if !isCar {
      let sx: Float = ScenePlacer.AxisScale(measured.half.X, frame.half.X);
      let sy: Float = ScenePlacer.AxisScale(measured.half.Y, frame.half.Y);
      let rawZ: Float = frame.half.Z > 0.0 ? measured.half.Z / frame.half.Z : 1.0;
      let sz: Float = rawZ >= 1.0 ? 1.0 + (rawZ - 1.0) * ScenePlacer.ZDamping() : ScenePlacer.Shrink(rawZ);
      mover.Scale(sx, sy, sz, groundZ);
    }
    let json: ref<XUtilsJson> = source.ToJson();
    ScenePlacer.MoveList(json, "points", mover);
    if !isCar && larger { ScenePlacer.Clearance(json, "points", center, yaw, measured); }
    // A car's own cloud was authored for that car, so its points stay put unless a wall says otherwise
    ScenePlacer.SafeguardList(xu, json, "points", center, yaw, geometry, XUtilsSafeguardMode.Positions, isCar);
    ScenePlacer.ClampFloor(json, "points", groundZ);
    ScenePlacer.WriteFrame(json, center, yaw, measured);
    placed.cloud = xu.Motion().PointCloudFromJson(json);
    let app: ref<XUtilsJson> = source.GetApp();
    let garage: ref<XUtilsJson> = IsDefined(app) && app.Has("garage") ? app.Get("garage") : null;
    placed.slots = IsDefined(garage) && garage.Has("slots") ? garage.Get("slots") : null;

    ScenePlacer.Paths(xu, data, location, schema, frame, placed, measured, geometry, center, yaw, isCar, larger, groundZ, mover);
    return placed;
  }

  private static func Shrink(raw: Float) -> Float {
    if raw >= 1.0 { return raw; }
    let t: Float = LogF(1.0 + raw) / LogF(2.0);
    return ScenePlacer.MinScale() + (1.0 - ScenePlacer.MinScale()) * t;
  }

  private static func AxisScale(measured: Float, reference: Float) -> Float {
    let raw: Float = reference > 0.0 ? measured / reference : 1.0;
    return raw >= 1.0 ? raw * ScenePlacer.AdaptiveBoost() : ScenePlacer.Shrink(raw);
  }

  // An older file can lack any of this, so it falls back to the middle of the points and a stock car's size
  private static func FrameOf(json: ref<XUtilsJson>) -> ref<GarageFrameInfo> {
    let frame: ref<GarageFrameInfo> = new GarageFrameInfo();
    frame.half = new Vector4(1.0, 2.5, 0.8, 0.0);
    if json.Has("box") {
      let box: ref<XUtilsJson> = json.Get("box");
      if box.Has("half") { frame.half = ScenePlacer.Vec(box.Get("half")); }
      frame.yaw = box.GetFloat("yaw", 0.0);
    }
    if json.Has("center") { frame.center = ScenePlacer.Vec(json.Get("center")); }
    if json.Has("app") && json.Get("app").Has("garage") && json.Get("app").Get("garage").Has("frame") {
      let saved: ref<XUtilsJson> = json.Get("app").Get("garage").Get("frame");
      ScenePlacer.ReadFrame(saved, frame);
    }
    return frame;
  }

  private static func ReadFrame(saved: ref<XUtilsJson>, frame: ref<GarageFrameInfo>) -> Void {
    if saved.Has("center") { frame.center = ScenePlacer.Vec(saved.Get("center")); }
    frame.yaw = saved.GetFloat("yaw", frame.yaw);
    if saved.Has("halfHeight") {
      let half: Vector4 = frame.half;
      half.Z = saved.GetFloat("halfHeight", half.Z);
      frame.half = half;
    }
  }

  private static func Vec(a: ref<XUtilsJson>) -> Vector4 {
    return new Vector4(a.FloatAt(0, 0.0), a.FloatAt(1, 0.0), a.FloatAt(2, 0.0), 1.0);
  }

  private static func VecJson(p: Vector4) -> ref<XUtilsJson> {
    let a: ref<XUtilsJson> = XUtilsJson.NewArray();
    a.PushFloat(p.X);
    a.PushFloat(p.Y);
    a.PushFloat(p.Z);
    return a;
  }

  private static func Measure(xu: ref<XUtilsMod>, data: ref<GarageData>, vehicle: wref<VehicleObject>, schema: ref<VehicleSchema>, frame: ref<GarageFrameInfo>) -> ref<GarageMeasure> {
    let measure: ref<GarageMeasure> = new GarageMeasure();
    let box: ref<GarageBox> = IsDefined(vehicle) ? data.GetBox(vehicle.GetRecordID()) : null;
    if IsDefined(box) {
      measure.half = new Vector4(box.half.X, box.half.Y, box.half.Z, 0.0);
      measure.offset = new Vector4(box.offset.X, box.offset.Y, box.offset.Z, 0.0);
      measure.overridden = true;
      return measure;
    }
    if IsDefined(schema) && schema.hasBox {
      measure.half = new Vector4(schema.boxHalf.X, schema.boxHalf.Y, schema.boxHalf.Z, 0.0);
      measure.offset = new Vector4(schema.boxOffset.X, schema.boxOffset.Y, schema.boxOffset.Z, 0.0);
      measure.overridden = true;
      return measure;
    }
    let measured: ref<GarageMeasure> = ScenePlacer.Geometry(xu, vehicle, measure);
    if measured != measure { return measured; }
    measure.half = frame.half;
    return measure;
  }

  // Override sizes are tuned for framing and don't cover the mesh, and the safeguard needs the real extents
  private static func Geometry(xu: ref<XUtilsMod>, vehicle: wref<VehicleObject>, measured: ref<GarageMeasure>) -> ref<GarageMeasure> {
    if !IsDefined(vehicle) { return measured; }
    let bounds: XUtilsBounds = xu.World().Measure(vehicle);
    if bounds.parts == 0 { return measured; }
    let origin: Vector4 = vehicle.GetWorldPosition();
    let center: Vector4 = bounds.center;
    let dx: Float = center.X - origin.X;
    let dy: Float = center.Y - origin.Y;
    let cosY: Float = CosF(Deg2Rad(bounds.yaw));
    let sinY: Float = SinF(Deg2Rad(bounds.yaw));
    let real: ref<GarageMeasure> = new GarageMeasure();
    real.half = bounds.half;
    real.offset = new Vector4(dx * cosY + dy * sinY, -dx * sinY + dy * cosY, center.Z - origin.Z, 0.0);
    return real;
  }

  private static func GroundZ(xu: ref<XUtilsMod>, vehicle: wref<VehicleObject>, measured: ref<GarageMeasure>, location: ref<GarageLocation>) -> Float {
    let fallback: Float = location.deck.z + measured.offset.Z - measured.half.Z;
    if !IsDefined(vehicle) { return fallback; }
    let at: Vector4 = vehicle.GetWorldPosition();
    let ray: ref<XUtilsRay> = xu.Ray();
    if measured.overridden {
      // These can be narrower than the mesh, so a dropped box would land on the car's own floor
      let start: Vector4 = new Vector4(at.X, at.Y, at.Z + 2.0, 1.0);
      let hit: XUtilsRayHit = ray.Ground(start, XUtilsRayOptions.Create().Groups(XUtilsCollision.Static).Depth(10.0));
      if !hit.hit { hit = ray.Ground(start, XUtilsRayOptions.Create().Groups(XUtilsCollision.Terrain).Depth(10.0)); }
      if hit.hit {
        let ground: Vector4 = hit.position;
        return ground.Z;
      }
      return at.Z + measured.offset.Z - measured.half.Z;
    }
    let drop: XUtilsDropResult = ray.DropBox(at, measured.half, location.deck.yaw);
    if drop.hits == 0 { drop = ray.DropBox(at, measured.half, location.deck.yaw, XUtilsCollision.Static); }
    return drop.hits > 0 ? drop.groundZ : fallback;
  }

  private static func PointOf(item: ref<XUtilsJson>) -> Vector4 {
    return new Vector4(item.GetFloat("x", 0.0), item.GetFloat("y", 0.0), item.GetFloat("z", 0.0), 1.0);
  }

  private static func WritePoint(item: ref<XUtilsJson>, p: Vector4) -> Void {
    item.SetFloat("x", p.X);
    item.SetFloat("y", p.Y);
    item.SetFloat("z", p.Z);
  }

  private static func MoveList(json: ref<XUtilsJson>, key: String, mover: ref<GarageMover>) -> Void {
    let list: ref<XUtilsJson> = json.Get(key);
    let out: ref<XUtilsJson> = XUtilsJson.NewArray();
    let i: Int32 = 0;
    while i < list.Size() {
      let item: ref<XUtilsJson> = list.At(i);
      ScenePlacer.WritePoint(item, mover.Move(ScenePlacer.PointOf(item)));
      item.SetFloat("yaw", item.GetFloat("yaw", 0.0) + mover.dYaw);
      if item.Has("lookAt") { item.Set("lookAt", ScenePlacer.VecJson(mover.Move(ScenePlacer.Vec(item.Get("lookAt"))))); }
      out.Push(item);
      i += 1;
    }
    json.Set(key, out);
  }

  // Only positions in the clip zone around the box's edge get pushed. Overhead shots go up, and nothing goes down
  private static func Clearance(json: ref<XUtilsJson>, key: String, center: Vector4, yaw: Float, measured: ref<GarageMeasure>) -> Void {
    let gap: Float = ScenePlacer.MinExterior();
    let cosY: Float = CosF(Deg2Rad(yaw));
    let sinY: Float = SinF(Deg2Rad(yaw));
    let half: Vector4 = measured.half;
    let list: ref<XUtilsJson> = json.Get(key);
    let out: ref<XUtilsJson> = XUtilsJson.NewArray();
    let i: Int32 = 0;
    while i < list.Size() {
      let item: ref<XUtilsJson> = list.At(i);
      let p: Vector4 = ScenePlacer.PointOf(item);
      let dx: Float = p.X - center.X;
      let dy: Float = p.Y - center.Y;
      let dz: Float = p.Z - center.Z;
      let lx: Float = dx * cosY + dy * sinY;
      let ly: Float = -dx * sinY + dy * cosY;
      let absX: Float = AbsF(lx);
      let absY: Float = AbsF(ly);
      if absX > half.X - gap && absX < half.X + gap { lx = lx > 0.0 ? half.X + gap : -(half.X + gap); }
      if absY > half.Y - gap && absY < half.Y + gap { ly = ly > 0.0 ? half.Y + gap : -(half.Y + gap); }
      if dz > half.Z - gap && dz < half.Z + gap && absX <= half.X && absY <= half.Y { dz = half.Z + gap; }
      ScenePlacer.WritePoint(item, new Vector4(center.X + lx * cosY - ly * sinY, center.Y + lx * sinY + ly * cosY, center.Z + dz, 1.0));
      out.Push(item);
      i += 1;
    }
    json.Set(key, out);
  }

  private static func SafeguardList(xu: ref<XUtilsMod>, json: ref<XUtilsJson>, key: String, center: Vector4, yaw: Float, geometry: ref<GarageMeasure>, mode: XUtilsSafeguardMode, keepAuthored: Bool) -> Void {
    let list: ref<XUtilsJson> = json.Get(key);
    let points: array<Vector4>;
    let i: Int32 = 0;
    while i < list.Size() {
      ArrayPush(points, ScenePlacer.PointOf(list.At(i)));
      i += 1;
    }
    let options: ref<XUtilsSafeguardOptions> = XUtilsSafeguardOptions.Create().Mode(mode).Clearance(ScenePlacer.WallClearance())
      .Box(geometry.half, yaw, geometry.offset).BoxClearance(ScenePlacer.MinExterior(), ScenePlacer.StandoffShare())
      .SkipBoxPush(keepAuthored).PreserveZ(Equals(mode, XUtilsSafeguardMode.Rigid));
    let result: XUtilsSafeguardResult = xu.Ray().Safeguard(points, center, options);
    let moved: array<Vector4> = result.points;
    if ArraySize(moved) != ArraySize(points) { return; }
    let out: ref<XUtilsJson> = XUtilsJson.NewArray();
    i = 0;
    while i < ArraySize(moved) {
      let item: ref<XUtilsJson> = list.At(i);
      ScenePlacer.WritePoint(item, moved[i]);
      out.Push(item);
      i += 1;
    }
    json.Set(key, out);
  }

  private static func ClampFloor(json: ref<XUtilsJson>, key: String, groundZ: Float) -> Void {
    let list: ref<XUtilsJson> = json.Get(key);
    let out: ref<XUtilsJson> = XUtilsJson.NewArray();
    let i: Int32 = 0;
    while i < list.Size() {
      let item: ref<XUtilsJson> = list.At(i);
      if item.GetFloat("z", 0.0) < groundZ { item.SetFloat("z", groundZ); }
      out.Push(item);
      i += 1;
    }
    json.Set(key, out);
  }

  private static func WriteFrame(json: ref<XUtilsJson>, center: Vector4, yaw: Float, measured: ref<GarageMeasure>) -> Void {
    json.Set("center", ScenePlacer.VecJson(center));
    let box: ref<XUtilsJson> = XUtilsJson.NewObject();
    box.Set("half", ScenePlacer.VecJson(measured.half));
    box.SetFloat("yaw", yaw);
    box.Set("offset", ScenePlacer.VecJson(new Vector4(0.0, 0.0, 0.0, 0.0)));
    json.Set("box", box);
  }

  // Static garage paths are always in. Car paths win over adaptive and default for the rest. Titles go first
  private static func Paths(xu: ref<XUtilsMod>, data: ref<GarageData>, location: ref<GarageLocation>, schema: ref<VehicleSchema>, frame: ref<GarageFrameInfo>, placed: ref<GaragePlacedScene>,
                            measured: ref<GarageMeasure>, geometry: ref<GarageMeasure>, center: Vector4, yaw: Float, isCar: Bool, larger: Bool, groundZ: Float, mover: ref<GarageMover>) -> Void {
    let seen: array<String>;
    let garagePaths: array<ref<XUtilsPath>> = data.GetGaragePaths(location.id);
    let adaptive: array<ref<XUtilsPath>>;
    for path in garagePaths {
      if ScenePlacer.AppGarage(path).GetBool("adaptive", false) {
        ArrayPush(adaptive, path);
      } else {
        ScenePlacer.AddEntry(xu, placed, seen, path, path.ToJson());
      }
    }
    let carPaths: array<ref<XUtilsPath>>;
    if IsDefined(schema) { carPaths = data.GetVehiclePaths(schema.id); }
    if ArraySize(carPaths) > 0 {
      for path in carPaths {
        let json: ref<XUtilsJson> = path.ToJson();
        let rigid: ref<GarageMover> = ScenePlacer.PathMover(json, frame, center, yaw, 1.0, 1.0, 1.0, groundZ, false);
        ScenePlacer.MoveList(json, "keys", rigid);
        ScenePlacer.FinishPath(xu, json, center, yaw, geometry, groundZ, true);
        ScenePlacer.AddEntry(xu, placed, seen, path, json, rigid);
      }
      return;
    }
    let generic: array<ref<XUtilsPath>> = adaptive;
    if ArraySize(generic) == 0 { generic = data.GetDefaultPaths(); }
    for path in generic {
      let json: ref<XUtilsJson> = path.ToJson();
      // A car's own cloud means no scaling, for paths that came from anywhere
      let pathMover: ref<GarageMover> = ScenePlacer.PathMover(json, frame, center, yaw, mover.scaleX, mover.scaleY, mover.scaleZ, groundZ, mover.scaled);
      ScenePlacer.MoveList(json, "keys", pathMover);
      if larger { ScenePlacer.Clearance(json, "keys", center, yaw, measured); }
      ScenePlacer.ClampFloor(json, "keys", groundZ);
      ScenePlacer.FinishPath(xu, json, center, yaw, geometry, groundZ, false);
      ScenePlacer.AddEntry(xu, placed, seen, path, json, pathMover);
    }
  }

  // Adaptive paths carry their own frame, not the resolved cloud's
  private static func PathMover(json: ref<XUtilsJson>, fallback: ref<GarageFrameInfo>, center: Vector4, yaw: Float, sx: Float, sy: Float, sz: Float, groundZ: Float, scaled: Bool) -> ref<GarageMover> {
    let frame: ref<GarageFrameInfo> = new GarageFrameInfo();
    frame.center = fallback.center;
    frame.yaw = fallback.yaw;
    frame.half = fallback.half;
    if json.Has("app") && json.Get("app").Has("garage") && json.Get("app").Get("garage").Has("frame") {
      ScenePlacer.ReadFrame(json.Get("app").Get("garage").Get("frame"), frame);
    }
    let mover: ref<GarageMover> = GarageMover.Make(frame, center, yaw);
    if scaled { mover.Scale(sx, sy, sz, groundZ); }
    return mover;
  }

  // PreserveZ keeps a path's arc height through the pull-in
  // A car's path skips the floor clamp, a bad ground reading isn't worth bending authored data for
  private static func FinishPath(xu: ref<XUtilsMod>, json: ref<XUtilsJson>, center: Vector4, yaw: Float, geometry: ref<GarageMeasure>, groundZ: Float, isCar: Bool) -> Void {
    ScenePlacer.SafeguardList(xu, json, "keys", center, yaw, geometry, XUtilsSafeguardMode.Rigid, false);
    if !isCar { ScenePlacer.ClampFloor(json, "keys", groundZ); }
  }

  private static func AppGarage(path: ref<XUtilsPath>) -> ref<XUtilsJson> {
    let app: ref<XUtilsJson> = path.GetApp();
    return IsDefined(app) && app.Has("garage") ? app.Get("garage") : XUtilsJson.NewObject();
  }

  private static func AddEntry(xu: ref<XUtilsMod>, placed: ref<GaragePlacedScene>, out seen: array<String>, source: ref<XUtilsPath>, json: ref<XUtilsJson>, opt mover: ref<GarageMover>) -> Void {
    let garage: ref<XUtilsJson> = ScenePlacer.AppGarage(source);
    let name: String = garage.GetString("name", "idle_" + IntToString(ArraySize(placed.entries)));
    if ArrayContains(seen, name) { return; }
    let path: ref<XUtilsPath> = xu.Motion().PathFromJson(json);
    if !IsDefined(path) { return; }
    ArrayPush(seen, name);
    let entry: ref<GarageIdleEntry> = new GarageIdleEntry();
    entry.name = name;
    entry.path = path;
    entry.title = garage.GetBool("title", false);
    if garage.Has("shake") {
      entry.shakeIntensity = garage.Get("shake").GetFloat("intensity", 1.0);
      entry.shakeFrequency = garage.Get("shake").GetFloat("frequency", 1.0);
    }
    if garage.Has("focus") { ScenePlacer.ReadFocus(garage.Get("focus"), entry, mover); }
    let at: Int32 = 0;
    if entry.title {
      while at < ArraySize(placed.entries) && placed.entries[at].title { at += 1; }
    } else {
      at = ArraySize(placed.entries);
    }
    ArrayInsert(placed.entries, at, entry);
  }

  private static func ReadFocus(focus: ref<XUtilsJson>, entry: ref<GarageIdleEntry>, mover: ref<GarageMover>) -> Void {
    if focus.Has("point") {
      let point: Vector4 = ScenePlacer.Vec(focus.Get("point"));
      entry.focusPoint = IsDefined(mover) ? mover.Move(point) : point;
      entry.hasFocusPoint = true;
    }
    if focus.Has("keys") {
      let keys: ref<XUtilsJson> = focus.Get("keys");
      let names: array<String> = keys.Keys();
      for name in names {
        let point: Vector4 = ScenePlacer.Vec(keys.Get(name));
        ArrayPush(entry.focusKeys, StringToInt(name));
        ArrayPush(entry.focusPoints, IsDefined(mover) ? mover.Move(point) : point);
      }
    }
  }
}
