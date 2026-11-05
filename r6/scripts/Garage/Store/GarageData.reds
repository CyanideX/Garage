module Garage.Data

import Garage.*
import VehicleCore.Schema.*

/// Garage's data, for Garage itself and for tools like GLC. Get it with GarageData.Get().
/// Files live in two places with the same layout: what ships in r6/scripts/Garage/data, and the user's in XU's
/// data/Garage. The user's wins by id. Locations load once a session, clouds and paths the first time they're asked for.
public class GarageData extends IScriptable {
  private let m_xu: ref<XUtilsMod>;
  private let m_log: ref<XUtilsLog>;
  private let m_locations: array<ref<GarageLocation>>;
  private let m_raw: array<ref<XUtilsJson>>;
  private let m_user: array<Bool>;
  private let m_broken: Int32;
  private let m_boxIds: array<TweakDBID>;
  private let m_boxes: array<ref<GarageBox>>;
  private let m_cloudKeys: array<String>;
  private let m_clouds: array<ref<XUtilsPointCloud>>;
  private let m_pathKeys: array<String>;
  private let m_paths: array<ref<XUtilsPath>>;

  public static func Get() -> ref<GarageData> {
    let system: ref<GarageSystem> = GarageSystem.Get();
    return IsDefined(system) ? system.Data() : null;
  }

  public func Setup(xu: ref<XUtilsMod>) -> Void {
    this.m_xu = xu;
    this.m_log = xu.Log("Data");
  }

  // --- Locations

  public func Reload() -> Void {
    ArrayClear(this.m_locations);
    ArrayClear(this.m_raw);
    ArrayClear(this.m_user);
    this.m_broken = 0;
    this.InvalidateCache();
    let files: ref<XUtilsFiles> = this.m_xu.Files();
    let shipped: array<String> = files.ListModResource("data/garages/locations", ".json");
    for name in shipped {
      this.AddLocation(XUtilsJson.Parse(files.ReadModResource("data/garages/locations/" + name)), "shipped " + name, false);
    }
    let own: array<String> = files.List("garages/locations", ".json");
    for name in own {
      this.AddLocation(files.ReadJson("garages/locations/" + name), name, true);
    }
    this.LoadBoxes();
  }

  private func AddLocation(json: ref<XUtilsJson>, where: String, user: Bool) -> Void {
    let location: ref<GarageLocation> = new GarageLocation();
    if !IsDefined(json) {
      this.Broken(where, XUtilsJson.LastParseError());
      return;
    }
    let missing: String = GarageData.MissingField(json);
    if StrLen(missing) > 0 {
      this.Broken(where, "it has no " + missing);
      return;
    }
    if !json.ToObject(location) || !IsDefined(location.deck) || !IsNameValid(location.id) {
      this.Broken(where, "not a location");
      return;
    }
    this.FillDefaults(location, json);
    let at: Int32 = this.IndexOf(location.id);
    if at < 0 {
      ArrayPush(this.m_locations, location);
      ArrayPush(this.m_raw, json);
      ArrayPush(this.m_user, user);
      return;
    }
    if user {
      this.m_log.Info("your " + where + " replaces the shipped " + NameToString(location.id));
    } else {
      this.m_log.Warn("location " + where + " repeats the id " + NameToString(location.id) + ", the later file wins");
    }
    this.m_locations[at] = location;
    this.m_raw[at] = json;
    this.m_user[at] = user;
  }

  private static func MissingField(json: ref<XUtilsJson>) -> String {
    let required: array<String> = ["id", "name", "region", "deck"];
    for key in required {
      if !json.Has(key) { return key; }
    }
    let deck: ref<XUtilsJson> = json.Get("deck");
    let fields: array<String> = ["x", "y", "z", "yaw"];
    for field in fields {
      if !deck.Has(field) { return "deck." + field; }
    }
    return "";
  }

  // Everyone past here can count on zone, audio, camera and economy being there
  private func FillDefaults(location: ref<GarageLocation>, json: ref<XUtilsJson>) -> Void {
    if !IsDefined(location.zone) { location.zone = new GarageZone(); }
    if !IsDefined(location.camera) { location.camera = new GarageCameraData(); }
    if !IsDefined(location.audio) { location.audio = new GarageAudio(); }
    if !IsDefined(location.economy) { location.economy = new GarageEconomyData(); }
    let audio: ref<XUtilsJson> = json.Has("audio") ? json.Get("audio") : null;
    let deck: ref<GarageSpot> = location.deck;
    if !IsDefined(audio) || !audio.Has("x") { location.audio.x = deck.x; }
    if !IsDefined(audio) || !audio.Has("y") { location.audio.y = deck.y; }
    if !IsDefined(audio) || !audio.Has("z") { location.audio.z = deck.z; }
    // Half a spawn is no spawn
    if IsDefined(location.playerSpawn) {
      let spawn: ref<XUtilsJson> = json.Get("playerSpawn");
      if !spawn.Has("x") || !spawn.Has("y") || !spawn.Has("z") || !spawn.Has("yaw") { location.playerSpawn = null; }
    }
    let limits: ref<GarageLimits> = location.limits;
    if IsDefined(limits) && (limits.width < 0.0 || limits.length < 0.0 || limits.height < 0.0) {
      this.m_log.Warn("a size limit of " + NameToString(location.id) + " is negative, so it's ignored");
    }
  }

  private func Broken(where: String, why: String) -> Void {
    this.m_broken += 1;
    this.m_log.Warn("skipping " + where + ": " + why);
  }

  private func IndexOf(id: CName) -> Int32 {
    let i: Int32 = 0;
    while i < ArraySize(this.m_locations) {
      if Equals(this.m_locations[i].id, id) { return i; }
      i += 1;
    }
    return -1;
  }

  public func GetLocations() -> array<ref<GarageLocation>> { return this.m_locations; }

  public func GetLocation(id: CName) -> ref<GarageLocation> {
    let at: Int32 = this.IndexOf(id);
    return at >= 0 ? this.m_locations[at] : null;
  }

  /// The closest garage to pos, measured to its deck. Give maxDistance to limit how far it looks. Null when there's none.
  public func FindNearest(pos: Vector4, opt maxDistance: Float) -> ref<GarageLocation> {
    let best: ref<GarageLocation>;
    let bestDistance: Float = 0.0;
    for location in this.m_locations {
      let distance: Float = Vector4.Distance(pos, location.deck.Position());
      if (maxDistance <= 0.0 || distance <= maxDistance) && (!IsDefined(best) || distance < bestDistance) {
        bestDistance = distance;
        best = location;
      }
    }
    return best;
  }

  /// A part of the file with no class, like app. Null when it isn't there.
  public func Section(id: CName, key: String) -> ref<XUtilsJson> {
    let at: Int32 = this.IndexOf(id);
    return at >= 0 && this.m_raw[at].Has(key) ? this.m_raw[at].Get(key) : null;
  }

  public func LocationCount() -> Int32 { return ArraySize(this.m_locations); }

  public func UserLocationCount() -> Int32 {
    let n: Int32 = 0;
    for user in this.m_user { if user { n += 1; } }
    return n;
  }

  public func BrokenCount() -> Int32 { return this.m_broken; }

  // Debug Logging on only: it reads every cloud and path
  public func LogContents() -> Void {
    if !this.m_log.IsEnabled(XUtilsLogLevel.Debug) { return; }
    let clouds: Int32 = 0;
    let paths: Int32 = 0;
    for location in this.m_locations {
      if IsDefined(this.GetGarageCloud(location.id)) { clouds += 1; }
      let own: array<ref<XUtilsPath>> = this.GetGaragePaths(location.id);
      paths += ArraySize(own);
    }
    this.m_log.Debug("garages: " + IntToString(clouds) + " with their own cloud, " + IntToString(paths) + " paths");
    let schemas: array<ref<VehicleSchema>> = VehicleSchemas.Get().GetSchemas();
    for schema in schemas {
      let carPaths: array<ref<XUtilsPath>> = this.GetVehiclePaths(schema.id);
      this.m_log.Debug("car " + NameToString(schema.id) + " in " + schema.dataFolder + ": cloud " + ToString(IsDefined(this.GetVehicleCloud(schema.id)))
                       + ", " + IntToString(ArraySize(carPaths)) + " paths");
    }
  }

  /// Writes it to the user's folder and reloads, then the rings and pins catch up and Garage.LocationImported goes out.
  /// A garage already within 10 m on the map keeps its id, so a re-export replaces it. source is passed on in the event.
  public func SaveLocation(location: ref<GarageLocation>, opt source: String) -> ref<GarageSaveResult> {
    if !IsDefined(location) || !IsDefined(location.deck) { return GarageSaveResult.Failed("no deck"); }
    if StrLen(location.name) == 0 { return GarageSaveResult.Failed("no name"); }
    let replaced: CName = this.GarageWithin10m(location);
    if IsNameValid(replaced) { location.id = replaced; }
    if !IsNameValid(location.id) { return GarageSaveResult.Failed("no id"); }
    let json: ref<XUtilsJson> = XUtilsJson.FromObject(location);
    if !IsDefined(json) { return GarageSaveResult.Failed("couldn't write it as JSON"); }
    let at: Int32 = this.IndexOf(location.id);
    if at >= 0 { GarageData.KeepMissing(json, this.m_raw[at]); }
    let path: String = "garages/locations/" + NameToString(location.id) + ".json";
    let result: ref<GarageSaveResult> = this.Write(path, json);
    if result.ok {
      result.id = location.id;
      result.replaced = replaced;
      this.Reload();
      GarageSystem.Get().OnLocationSaved(location.id, at >= 0, source);
    }
    return result;
  }

  // Flat, so a garage stacked above another one still counts
  private func GarageWithin10m(location: ref<GarageLocation>) -> CName {
    for other in this.m_locations {
      let dx: Float = other.deck.x - location.deck.x;
      let dy: Float = other.deck.y - location.deck.y;
      if dx * dx + dy * dy < 100.0 && !Equals(other.id, location.id) { return other.id; }
    }
    return n"";
  }

  // Sections with no class yet (economy, app) come through a save from the file they were read from
  private static func KeepMissing(json: ref<XUtilsJson>, raw: ref<XUtilsJson>) -> Void {
    let keys: array<String> = raw.Keys();
    for key in keys {
      if !json.Has(key) { json.Set(key, raw.Get(key)); }
    }
  }

  private func Write(path: String, json: ref<XUtilsJson>) -> ref<GarageSaveResult> {
    let files: ref<XUtilsFiles> = this.m_xu.Files();
    files.Backup(path, 3);
    return files.WriteJson(path, json) ? GarageSaveResult.Saved(path) : GarageSaveResult.Failed("couldn't write " + path);
  }

  /// Drops what's been read, for one garage or car or for all of them. They're read again when next asked for.
  public func InvalidateCache(opt id: CName) -> Void {
    if !IsNameValid(id) {
      ArrayClear(this.m_cloudKeys);
      ArrayClear(this.m_clouds);
      ArrayClear(this.m_pathKeys);
      ArrayClear(this.m_paths);
      return;
    }
    let text: String = NameToString(id);
    let i: Int32 = ArraySize(this.m_cloudKeys) - 1;
    while i >= 0 {
      if StrEndsWith(this.m_cloudKeys[i], "/" + text) {
        ArrayErase(this.m_cloudKeys, i);
        ArrayErase(this.m_clouds, i);
      }
      i -= 1;
    }
    i = ArraySize(this.m_pathKeys) - 1;
    while i >= 0 {
      if StrContains(this.m_pathKeys[i], "/" + text + "/") {
        ArrayErase(this.m_pathKeys, i);
        ArrayErase(this.m_paths, i);
      }
      i -= 1;
    }
  }

  // --- Clouds

  public func GetGarageCloud(id: CName) -> ref<XUtilsPointCloud> {
    let text: String = NameToString(id);
    return this.Cloud("garage/" + text, "garages/clouds/" + text + ".json", "Garage", "data/garages/clouds/" + text + ".json");
  }

  /// What a garage with no cloud of its own gets.
  public func GetDefaultCloud() -> ref<XUtilsPointCloud> {
    return this.Cloud("default", "", "Garage", "data/defaults/cloud.json");
  }

  /// The user's capture, else the one the car's mod ships. Null when it has neither.
  public func GetVehicleCloud(vehicleId: CName) -> ref<XUtilsPointCloud> {
    let text: String = NameToString(vehicleId);
    return this.Cloud("vehicle/" + text, "vehicles/" + text + "/cloud.json", GarageData.CarFolder(vehicleId), "data/cloud.json");
  }

  private func Cloud(key: String, userPath: String, mod: String, shippedPath: String) -> ref<XUtilsPointCloud> {
    let i: Int32 = 0;
    while i < ArraySize(this.m_cloudKeys) {
      if Equals(this.m_cloudKeys[i], key) { return this.m_clouds[i]; }
      i += 1;
    }
    let motion: ref<XUtilsMotion> = this.m_xu.Motion();
    let cloud: ref<XUtilsPointCloud>;
    if StrLen(userPath) > 0 && this.m_xu.Files().Exists(userPath) {
      cloud = motion.LoadPointCloud(userPath);
    }
    if !IsDefined(cloud) && StrLen(mod) > 0 {
      let text: String = this.m_xu.Files().ReadShared(mod, shippedPath);
      if StrLen(text) > 0 { cloud = motion.PointCloudFromJson(XUtilsJson.Parse(text)); }
      if StrLen(text) == 0 && StrLen(this.m_xu.Files().ReadShared(mod, "data/pointCloud.json")) > 0 {
        this.m_log.Warn(mod + " still has the old pointCloud.json, so it gets the generic camera. Run it through convert_garage_data");
      }
    }
    if IsDefined(cloud) {
      ArrayPush(this.m_cloudKeys, key);
      ArrayPush(this.m_clouds, cloud);
    }
    return cloud;
  }

  public func SaveVehicleCloud(vehicleId: CName, cloud: ref<XUtilsPointCloud>) -> ref<GarageSaveResult> {
    if !IsDefined(cloud) { return GarageSaveResult.Failed("no cloud"); }
    let result: ref<GarageSaveResult> = this.Write("vehicles/" + NameToString(vehicleId) + "/cloud.json", cloud.ToJson());
    if result.ok { this.InvalidateCache(vehicleId); }
    return result;
  }

  // --- Paths

  public func GetGaragePaths(id: CName) -> array<ref<XUtilsPath>> {
    let text: String = NameToString(id);
    return this.Paths("garage/" + text + "/", "garages/paths/" + text, "Garage", "data/garages/paths/" + text);
  }

  /// What a garage and car with no paths of their own get.
  public func GetDefaultPaths() -> array<ref<XUtilsPath>> {
    return this.Paths("default/", "", "Garage", "data/defaults/paths");
  }

  /// The user's paths if there are any, else what the car's mod ships.
  public func GetVehiclePaths(vehicleId: CName) -> array<ref<XUtilsPath>> {
    let text: String = NameToString(vehicleId);
    return this.Paths("vehicle/" + text + "/", "vehicles/" + text + "/paths", GarageData.CarFolder(vehicleId), "data/paths");
  }

  private func Paths(key: String, userFolder: String, mod: String, shippedFolder: String) -> array<ref<XUtilsPath>> {
    let found: array<ref<XUtilsPath>>;
    let i: Int32 = 0;
    while i < ArraySize(this.m_pathKeys) {
      if StrBeginsWith(this.m_pathKeys[i], key) { ArrayPush(found, this.m_paths[i]); }
      i += 1;
    }
    if ArraySize(found) > 0 { return found; }
    let files: ref<XUtilsFiles> = this.m_xu.Files();
    let motion: ref<XUtilsMotion> = this.m_xu.Motion();
    if StrLen(userFolder) > 0 {
      let own: array<String> = files.List(userFolder, ".json");
      for name in own {
        this.AddPath(found, key, name, motion.LoadPath(userFolder + "/" + name));
      }
    }
    if ArraySize(found) > 0 || StrLen(mod) == 0 { return found; }
    let shipped: array<String> = files.ListShared(mod, shippedFolder, ".json");
    for name in shipped {
      this.AddPath(found, key, name, motion.PathFromJson(XUtilsJson.Parse(files.ReadShared(mod, shippedFolder + "/" + name))));
    }
    return found;
  }

  private func AddPath(out found: array<ref<XUtilsPath>>, key: String, file: String, path: ref<XUtilsPath>) -> Void {
    if !IsDefined(path) { return; }
    // The file's name is the path's name, so a save writes it back there
    let app: ref<XUtilsJson> = path.GetApp();
    let garage: ref<XUtilsJson> = app.Has("garage") ? app.Get("garage") : XUtilsJson.NewObject();
    garage.SetString("name", StrBeforeFirst(file, ".json"));
    app.Set("garage", garage);
    path.SetApp(app);
    ArrayPush(found, path);
    ArrayPush(this.m_pathKeys, key + file);
    ArrayPush(this.m_paths, path);
  }

  public func SaveGaragePaths(id: CName, paths: array<ref<XUtilsPath>>) -> ref<GarageSaveResult> {
    return this.WritePaths(id, "garages/paths/" + NameToString(id), paths);
  }

  public func SaveVehiclePaths(vehicleId: CName, paths: array<ref<XUtilsPath>>) -> ref<GarageSaveResult> {
    return this.WritePaths(vehicleId, "vehicles/" + NameToString(vehicleId) + "/paths", paths);
  }

  private func WritePaths(id: CName, folder: String, paths: array<ref<XUtilsPath>>) -> ref<GarageSaveResult> {
    let result: ref<GarageSaveResult> = GarageSaveResult.Failed("no paths");
    let i: Int32 = 0;
    for path in paths {
      let app: ref<XUtilsJson> = path.GetApp();
      let name: String = app.Get("garage").GetString("name", "path_" + IntToString(i));
      result = this.Write(folder + "/" + name + ".json", path.ToJson());
      if !result.ok { return result; }
      i += 1;
    }
    this.InvalidateCache(id);
    return result;
  }

  private static func CarFolder(vehicleId: CName) -> String {
    let schemas: ref<VehicleSchemas> = VehicleSchemas.Get();
    let schema: ref<VehicleSchema> = IsDefined(schemas) ? schemas.GetSchema(vehicleId) : null;
    return IsDefined(schema) ? schema.dataFolder : "";
  }

  // --- Boxes

  private func LoadBoxes() -> Void {
    ArrayClear(this.m_boxIds);
    ArrayClear(this.m_boxes);
    let json: ref<XUtilsJson> = XUtilsJson.Parse(this.m_xu.Files().ReadModResource("data/defaults/bbox.json"));
    if !IsDefined(json) { return; }
    let keys: array<String> = json.Keys();
    for key in keys {
      let box: ref<GarageBox> = new GarageBox();
      if json.Get(key).ToObject(box) {
        let record: String = StrBeginsWith(key, "model:") ? StrAfterFirst(key, "model:") : key;
        ArrayPush(this.m_boxIds, TDBID.Create(record));
        ArrayPush(this.m_boxes, box);
      }
    }
  }

  /// A car's box from defaults/bbox.json: its own record first, then its model, which its variants share. Null when
  /// neither has one, and the car gets measured. Matched by id, since without CET an id can't turn back into a name.
  public func GetBox(record: TweakDBID) -> ref<GarageBox> {
    let box: ref<GarageBox> = this.BoxFor(record);
    if IsDefined(box) { return box; }
    let vehicle: wref<Vehicle_Record> = TweakDBInterface.GetVehicleRecord(record);
    if !IsDefined(vehicle) { return null; }
    let model: wref<VehicleModel_Record> = vehicle.Model();
    return IsDefined(model) ? this.BoxFor(model.GetID()) : null;
  }

  private func BoxFor(id: TweakDBID) -> ref<GarageBox> {
    let i: Int32 = 0;
    while i < ArraySize(this.m_boxIds) {
      if this.m_boxIds[i] == id { return this.m_boxes[i]; }
      i += 1;
    }
    return null;
  }

  public func BoxCount() -> Int32 { return ArraySize(this.m_boxes); }
}
