module Garage.Audio

@if(ModuleExists("AudioXL"))
import AudioXL.*

import Garage.*
import Garage.Data.*

/// Garage's own sound effects. They do nothing without AudioXL.
public abstract class GarageSounds {
  public static func PlayInstall() -> Void { GarageSounds.Play("install", 5, 0.3); }
  public static func PlayPaint() -> Void { GarageSounds.Play("paint", 2, 0.3); }
  public static func PlayFabric() -> Void { GarageSounds.Play("fabric", 3, 0.4); }
  public static func PlayOpen() -> Void { GarageSounds.Play("open", 1, 0.55); }

  // No entity: a plain 2D play gets no zone reverb. Rows sit at gain 1, the level goes on the play
  @if(ModuleExists("AudioXL"))
  private static func Play(sound: String, variants: Int32, gain: Float) -> Void {
    let variant: Int32 = RandRange(1, variants + 1);
    let noEntity: EntityID;
    AudioXLAPI.Play(StringToName("garage_" + sound + (variant < 10 ? "_0" : "_") + IntToString(variant)), noEntity, gain);
  }

  @if(!ModuleExists("AudioXL"))
  private static func Play(sound: String, variants: Int32, gain: Float) -> Void {}
}

// What the rest of Garage calls, so it needn't care if AudioXL's there
public abstract class GarageMusic {
  @if(ModuleExists("AudioXL"))
  public static func Start(xu: ref<XUtilsMod>, data: ref<GarageData>) -> Void {
    let system: ref<GarageMusicSystem> = GarageMusicSystem.Get();
    if IsDefined(system) { system.Begin(xu, data); }
  }

  @if(ModuleExists("AudioXL"))
  public static func Stop() -> Void {
    let system: ref<GarageMusicSystem> = GarageMusicSystem.Get();
    if IsDefined(system) { system.End(); }
  }

  @if(ModuleExists("AudioXL"))
  public static func SettingsChanged() -> Void {
    let system: ref<GarageMusicSystem> = GarageMusicSystem.Get();
    if IsDefined(system) { system.OnSettingsChanged(); }
  }

  @if(ModuleExists("AudioXL"))
  public static func LocationSaved(id: CName, data: ref<GarageData>) -> Void {
    let system: ref<GarageMusicSystem> = GarageMusicSystem.Get();
    if IsDefined(system) { system.OnLocationSaved(id, data); }
  }

  @if(!ModuleExists("AudioXL"))
  public static func Start(xu: ref<XUtilsMod>, data: ref<GarageData>) -> Void {}

  @if(!ModuleExists("AudioXL"))
  public static func Stop() -> Void {}

  @if(!ModuleExists("AudioXL"))
  public static func SettingsChanged() -> Void {}

  @if(!ModuleExists("AudioXL"))
  public static func LocationSaved(id: CName, data: ref<GarageData>) -> Void {}
}

@if(ModuleExists("AudioXL"))
public class GaragePlaylist extends IScriptable {
  public let name: CName;
  public let count: Int32;
  public let weight: Float = 1.0;
  public let queue: array<Int32>;
}

// One per garage. Its own rings, kept apart from the world's: music plays at garages with events off and retired ones too
@if(ModuleExists("AudioXL"))
public class GarageMusicZone extends IScriptable {
  public let location: ref<GarageLocation>;
  public let emitter: CName;
  public let watcher: ref<XUtilsWatcher>;
  public let inRange: Bool;
  // garage_{playlist}_{XX} without the routing type, and the row playing it, n"" when silent
  public let track: CName;
  public let row: CName;
  public let playingType: CName;
  public let playingVolume: Float;
  public let timer: Uint64;
  public let endChecks: Int32;
  public let startRetries: Int32;
  public let system: wref<GarageMusicSystem>;

  // Ring 0 is the outer one. Start before it's audible, and the gap stops someone on the line restarting the track
  public func OnZoneEnter(e: ref<XUtilsEvent>) -> Void {
    if e.index == 1 && IsDefined(this.system) { this.system.EnterRange(this); }
  }

  public func OnZoneExit(e: ref<XUtilsEvent>) -> Void {
    if e.index == 0 && IsDefined(this.system) { this.system.LeaveRange(this); }
  }

  public func OnTrackEnd(e: ref<XUtilsEvent>) -> Void {
    this.timer = 0ul;
    if IsDefined(this.system) { this.system.OnTrackEnded(this); }
  }

  public func OnStartRetry(e: ref<XUtilsEvent>) -> Void {
    this.timer = 0ul;
    if IsDefined(this.system) { this.system.StartGarageMusic(this.location.id); }
  }
}

/// Garage music, one emitter per garage in range, playing from registered playlists through AudioXL.
/// A music pack calls RegisterPlaylist once its own settings say it's on, and again each session:
///   GarageMusicSystem.Get().RegisterPlaylist(n"mypack", 12);
/// Tracks are named {playlist}_{XX} from 01 up. Each needs an AudioXL row garage_{playlist}_{XX}_{type} for every routing
/// type it should play as, with axl_music_3d or mod_sfx_occlusion there as the fallback.
@if(ModuleExists("AudioXL"))
public class GarageMusicSystem extends ScriptableService {
  private let m_xu: ref<XUtilsMod>;
  private let m_log: ref<XUtilsLog>;
  private let m_zones: array<ref<GarageMusicZone>>;
  private let m_playlists: array<ref<GaragePlaylist>>;
  private let m_overrideGarages: array<CName>;
  private let m_overridePlaylists: array<CName>;
  private let m_restart: Uint64;
  private let m_defaultDuration: Float = 60.0;

  private static func EnterRadius() -> Float { return 80.0; }
  private static func ExitRadius() -> Float { return 95.0; }
  private static func FadeIn() -> Float { return 1.5; }
  private static func FadeOut() -> Float { return 1.0; }

  public static func Get() -> ref<GarageMusicSystem> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"Garage.Audio.GarageMusicSystem") as GarageMusicSystem;
  }

  // --- Session

  public func Begin(xu: ref<XUtilsMod>, data: ref<GarageData>) -> Void {
    this.End();
    this.m_xu = xu;
    this.m_log = xu.Log("Audio");
    let locations: array<ref<GarageLocation>> = data.GetLocations();
    for location in locations { this.AddZone(location); }
  }

  // No AudioXL calls here, it tears its own emitters down at session end
  public func End() -> Void {
    for zone in this.m_zones {
      this.CancelTimer(zone);
      if IsDefined(zone.watcher) { zone.watcher.Destroy(); }
    }
    ArrayClear(this.m_zones);
    ArrayClear(this.m_overrideGarages);
    ArrayClear(this.m_overridePlaylists);
    if this.m_restart != 0ul && IsDefined(this.m_xu) { this.m_xu.Cancel(this.m_restart); }
    this.m_restart = 0ul;
  }

  public func OnLocationSaved(id: CName, data: ref<GarageData>) -> Void {
    if !IsDefined(this.m_xu) { return; }
    let i: Int32 = 0;
    while i < ArraySize(this.m_zones) {
      if Equals(this.m_zones[i].location.id, id) {
        let zone: ref<GarageMusicZone> = this.m_zones[i];
        this.LeaveRange(zone);
        if IsDefined(zone.watcher) { zone.watcher.Destroy(); }
        ArrayErase(this.m_zones, i);
        break;
      }
      i += 1;
    }
    let location: ref<GarageLocation> = data.GetLocation(id);
    if IsDefined(location) { this.AddZone(location); }
  }

  private func AddZone(location: ref<GarageLocation>) -> Void {
    let zone: ref<GarageMusicZone> = new GarageMusicZone();
    zone.location = location;
    zone.system = this;
    zone.emitter = StringToName("garage_music_" + NameToString(location.id));
    let audio: ref<GarageAudio> = location.audio;
    let at: Vector4 = new Vector4(audio.x, audio.y, audio.z, 1.0);
    zone.watcher = this.m_xu.World().Watch(XUtilsZones.At(at).Flat(true).Ring(GarageMusicSystem.ExitRadius()).Ring(GarageMusicSystem.EnterRadius()),
                                           XUtilsWatchOptions.Create().Interval(0.5));
    zone.watcher.On(XUtilsEventType.ZoneEnter, zone, n"OnZoneEnter");
    zone.watcher.On(XUtilsEventType.ZoneExit, zone, n"OnZoneExit");
    ArrayPush(this.m_zones, zone);
  }

  private func Find(id: CName) -> ref<GarageMusicZone> {
    for zone in this.m_zones {
      if Equals(zone.location.id, id) { return zone; }
    }
    return null;
  }

  private func CancelTimer(zone: ref<GarageMusicZone>) -> Void {
    if zone.timer != 0ul { this.m_xu.Cancel(zone.timer); }
    zone.timer = 0ul;
  }

  public func EnterRange(zone: ref<GarageMusicZone>) -> Void {
    if zone.inRange { return; }
    zone.inRange = true;
    this.StartGarageMusic(zone.location.id);
  }

  public func LeaveRange(zone: ref<GarageMusicZone>) -> Void {
    if !zone.inRange { return; }
    zone.inRange = false;
    // Out of earshot by now, so no fade
    this.StopZone(zone, 0.0);
    AudioXLAPI.DestroyEmitter(zone.emitter);
  }

  // --- Playlists

  /// Adds a playlist, or changes its size. Reshuffles it either way.
  public func RegisterPlaylist(name: CName, trackCount: Int32) -> Void {
    if trackCount <= 0 { return; }
    let playlist: ref<GaragePlaylist> = this.FindPlaylist(name);
    if !IsDefined(playlist) {
      playlist = new GaragePlaylist();
      playlist.name = name;
      ArrayPush(this.m_playlists, playlist);
    }
    playlist.count = trackCount;
    this.Shuffle(playlist);
  }

  public func GetTrackCount(playlist: CName) -> Int32 {
    let found: ref<GaragePlaylist> = this.FindPlaylist(playlist);
    return IsDefined(found) ? found.count : 0;
  }

  public func GetTrackName(playlist: CName, trackNumber: Int32) -> CName {
    return StringToName(NameToString(playlist) + (trackNumber < 10 ? "_0" : "_") + IntToString(trackNumber));
  }

  /// How often the pool draws from this playlist against the others. 0 leaves it out, default 1.
  public func SetPlaylistWeight(name: CName, weight: Float) -> Void {
    let playlist: ref<GaragePlaylist> = this.FindPlaylist(name);
    if weight < 0.0 || !IsDefined(playlist) {
      this.Warn("SetPlaylistWeight refused " + NameToString(name));
      return;
    }
    playlist.weight = weight;
  }

  public func HasAnyActivePlaylist() -> Bool {
    for playlist in this.m_playlists {
      if playlist.count > 0 && playlist.weight > 0.0 { return true; }
    }
    return false;
  }

  /// Length assumed for a track AudioXL can't give a duration for. Default 60 s.
  public func SetDefaultDuration(seconds: Float) -> Void {
    if seconds > 0.0 { this.m_defaultDuration = seconds; }
  }

  /// The playlist script assigned to a garage, n"" for none.
  public func GetGaragePlaylist(garage: CName) -> CName {
    let i: Int32 = ArrayFindFirst(this.m_overrideGarages, garage);
    return i >= 0 ? this.m_overridePlaylists[i] : n"";
  }

  /// Makes a garage play one playlist. Wins over its file's own, lasts the session.
  public func SetGaragePlaylist(garage: CName, playlist: CName) -> Void {
    if !IsDefined(this.Find(garage)) || !IsDefined(this.FindPlaylist(playlist)) {
      this.Warn("SetGaragePlaylist refused " + NameToString(garage) + ", " + NameToString(playlist));
      return;
    }
    let i: Int32 = ArrayFindFirst(this.m_overrideGarages, garage);
    if i >= 0 {
      this.m_overridePlaylists[i] = playlist;
      return;
    }
    ArrayPush(this.m_overrideGarages, garage);
    ArrayPush(this.m_overridePlaylists, playlist);
  }

  private func FindPlaylist(name: CName) -> ref<GaragePlaylist> {
    for playlist in this.m_playlists {
      if Equals(playlist.name, name) { return playlist; }
    }
    return null;
  }

  private func Shuffle(playlist: ref<GaragePlaylist>) -> Void {
    ArrayClear(playlist.queue);
    let i: Int32 = 1;
    while i <= playlist.count {
      ArrayPush(playlist.queue, i);
      i += 1;
    }
    i = playlist.count - 1;
    while i > 0 {
      let j: Int32 = RandRange(0, i + 1);
      let swap: Int32 = playlist.queue[i];
      playlist.queue[i] = playlist.queue[j];
      playlist.queue[j] = swap;
      i -= 1;
    }
  }

  private func Draw(playlist: ref<GaragePlaylist>) -> CName {
    if ArraySize(playlist.queue) == 0 { this.Shuffle(playlist); }
    let track: Int32 = playlist.queue[0];
    ArrayErase(playlist.queue, 0);
    return this.GetTrackName(playlist.name, track);
  }

  private func DrawFromPool() -> CName {
    let total: Float = 0.0;
    for playlist in this.m_playlists {
      if playlist.count > 0 && playlist.weight > 0.0 { total += playlist.weight; }
    }
    if total <= 0.0 { return n""; }
    let roll: Float = Cast<Float>(RandRange(0, 100000)) / 100000.0 * total;
    let last: ref<GaragePlaylist>;
    for playlist in this.m_playlists {
      if playlist.count > 0 && playlist.weight > 0.0 {
        last = playlist;
        roll -= playlist.weight;
        if roll < 0.0 { return this.Draw(playlist); }
      }
    }
    return IsDefined(last) ? this.Draw(last) : n"";
  }

  // n"" draws from the pool
  private func PlaylistFor(zone: ref<GarageMusicZone>) -> ref<GaragePlaylist> {
    let assigned: CName = this.GetGaragePlaylist(zone.location.id);
    if IsNameValid(assigned) { return this.FindPlaylist(assigned); }
    let own: String = zone.location.audio.playlist;
    return Equals(own, "pool") ? null : this.FindPlaylist(StringToName(own));
  }

  // --- Emitters

  // Reverb, EQ and occlusion are all live, so this is safe while it plays
  private func ApplyEmitter(zone: ref<GarageMusicZone>) -> Void {
    if !AudioXLAPI.HasEmitter(zone.emitter) { return; }
    let audio: ref<GarageAudio> = zone.location.audio;
    let settings: ref<GarageMusicSettings> = GarageMusicSettings.Get();
    let reverb: Float = ClampF(audio.reverbLevel * settings.GetReverbAmount(), 0.0, 1.0);
    if reverb > 0.0 && StrLen(audio.reverb) > 0 {
      AudioXLAPI.SetEmitterReverb(zone.emitter, StringToName(audio.reverb), reverb);
    } else {
      AudioXLAPI.SetEmitterReverb(zone.emitter, n"None", 0.0);
    }
    if settings.musicEqEnabled {
      AudioXLAPI.SetEmitterFilter(zone.emitter, MaxF(audio.lowPass, 0.0), MaxF(audio.highPass, 0.0));
    } else {
      AudioXLAPI.SetEmitterFilter(zone.emitter, 0.0, 0.0);
    }
    AudioXLAPI.SetEmitterOcclusion(zone.emitter, audio.occlusion && settings.musicOcclusionEnabled, MaxF(audio.occlusionHz, 0.0), ClampF(audio.occlusionLevel, 0.0, 1.0));
  }

  private func RoutingType(zone: ref<GarageMusicZone>) -> CName {
    let type: String = zone.location.audio.type;
    if NotEquals(type, "auto") { return StringToName(type); }
    return GarageMusicSettings.Get().musicOnMusicSlider ? n"axl_music_3d" : n"mod_sfx_occlusion";
  }

  // The routing type belongs to the row, so a track has one row per type
  private func RowFor(track: CName, type: CName) -> CName {
    let prefix: String = "garage_" + NameToString(track) + "_";
    let rows: array<CName> = [StringToName(prefix + NameToString(type)), StringToName(prefix + "axl_music_3d"), StringToName(prefix + "mod_sfx_occlusion")];
    for row in rows {
      if AudioXLNative.Has(row) { return row; }
    }
    return n"";
  }

  // Volume goes on the row, which AudioXL applies live. A garage's own gain goes on the play, so two can share a track
  // Neither's ever 0, AudioXL reads that as "use the row's own"
  private func Volume() -> Float { return MaxF(GarageMusicSettings.Get().GetVolume(), 0.001); }

  // Above 1 would go over full scale with Volume at 100%, so a garage's gain only turns its music down
  private func Offset(zone: ref<GarageMusicZone>) -> Float {
    let gain: Float = zone.location.audio.gain;
    return gain <= 0.0 ? 1.0 : ClampF(gain, 0.001, 1.0);
  }

  // --- Playback

  public func IsMusicPlaying(garage: CName) -> Bool {
    let zone: ref<GarageMusicZone> = this.Find(garage);
    return IsDefined(zone) && IsNameValid(zone.row);
  }

  public func IsAnyMusicPlaying() -> Bool {
    for zone in this.m_zones {
      if IsNameValid(zone.row) { return true; }
    }
    return false;
  }

  /// Only garages V's in range of can play. True if it's playing after this.
  public func StartGarageMusic(garage: CName) -> Bool {
    let zone: ref<GarageMusicZone> = this.Find(garage);
    if !IsDefined(zone) || !zone.inRange || !GarageMusicSettings.Get().musicEnabled { return false; }
    if IsNameValid(zone.row) { return true; }
    let own: ref<GaragePlaylist> = this.PlaylistFor(zone);
    if IsDefined(own) ? own.count <= 0 : !this.HasAnyActivePlaylist() { return false; }

    // Rows have no engine slot until AudioXL's sound path is up
    if !AudioXLNative.Enabled() {
      this.CancelTimer(zone);
      if zone.startRetries < 30 {
        zone.startRetries += 1;
        zone.timer = this.m_xu.After(1.0, zone, n"OnStartRetry");
      } else {
        this.Warn("AudioXL isn't ready, " + NameToString(garage) + " stays silent");
      }
      return false;
    }
    zone.startRetries = 0;

    // A name that already exists just moves
    let audio: ref<GarageAudio> = zone.location.audio;
    if !AudioXLAPI.CreateEmitter(zone.emitter, new Vector4(audio.x, audio.y, audio.z, 1.0)) {
      this.Warn("couldn't create the emitter for " + NameToString(garage));
      return false;
    }
    this.ApplyEmitter(zone);
    this.PlayNext(zone);
    return IsNameValid(zone.row);
  }

  public func PlayNextTrack(garage: CName) -> Void {
    let zone: ref<GarageMusicZone> = this.Find(garage);
    if IsDefined(zone) { this.PlayNext(zone); }
  }

  private func PlayNext(zone: ref<GarageMusicZone>) -> Void {
    this.CancelTimer(zone);
    if IsNameValid(zone.row) {
      AudioXLAPI.StopOn(zone.emitter, zone.row, 0.0);
      zone.row = n"";
    }
    let own: ref<GaragePlaylist> = this.PlaylistFor(zone);
    let track: CName = IsDefined(own) ? this.Draw(own) : this.DrawFromPool();
    if !IsNameValid(track) { return; }
    let type: CName = this.RoutingType(zone);
    let row: CName = this.RowFor(track, type);
    if !IsNameValid(row) {
      this.Warn("no AudioXL row for track " + NameToString(track));
      return;
    }
    let volume: Float = this.Volume();
    AudioXLAPI.SetGain(row, volume);
    if !AudioXLAPI.PlayOn(zone.emitter, row, this.Offset(zone), 0.0, GarageMusicSystem.FadeIn()) {
      this.Warn("PlayOn failed for " + NameToString(row));
      return;
    }
    zone.track = track;
    zone.row = row;
    zone.playingType = type;
    zone.playingVolume = volume;
    zone.endChecks = 0;
    let duration: Float = AudioXLNative.Duration(row);
    if duration <= 0.0 {
      this.Warn("no duration for " + NameToString(row));
      duration = this.m_defaultDuration;
    }
    zone.timer = this.m_xu.After(duration + 1.0, zone, n"OnTrackEnd");
  }

  // The timer can run ahead of the audio. IsPlaying goes by row and not by emitter, so the wait's capped in case another
  // garage is on the same one
  public func OnTrackEnded(zone: ref<GarageMusicZone>) -> Void {
    if !IsNameValid(zone.row) { return; }
    if zone.endChecks < 10 && AudioXLAPI.IsPlaying(zone.row) {
      zone.endChecks += 1;
      zone.timer = this.m_xu.After(1.0, zone, n"OnTrackEnd");
      return;
    }
    this.PlayNext(zone);
  }

  private func StopZone(zone: ref<GarageMusicZone>, fadeOut: Float) -> Void {
    this.CancelTimer(zone);
    // n"" stops everything on the emitter
    if IsNameValid(zone.row) { AudioXLAPI.StopOn(zone.emitter, n"", fadeOut); }
    zone.row = n"";
    zone.track = n"";
    zone.startRetries = 0;
  }

  /// Stays in range, so StartGarageMusic can pick it back up.
  public func StopGarageMusic(garage: CName) -> Void {
    let zone: ref<GarageMusicZone> = this.Find(garage);
    if IsDefined(zone) { this.StopZone(zone, GarageMusicSystem.FadeOut()); }
  }

  public func StopAllGarageMusic() -> Void {
    for zone in this.m_zones { this.StopZone(zone, GarageMusicSystem.FadeOut()); }
  }

  public func StartAllGarageMusic() -> Void {
    for zone in this.m_zones {
      if zone.inRange && !IsNameValid(zone.row) { this.StartGarageMusic(zone.location.id); }
    }
  }

  public func SkipAllTracks() -> Void {
    for zone in this.m_zones {
      if IsNameValid(zone.row) { this.PlayNext(zone); }
    }
  }

  /// Starts the nearest garage in range, if it's quiet.
  public func StartNearestGarageMusic() -> Bool {
    let player: ref<PlayerPuppet> = GetPlayer(GetGameInstance());
    if !IsDefined(player) { return false; }
    let at: Vector4 = player.GetWorldPosition();
    let nearest: ref<GarageMusicZone>;
    let best: Float = 0.0;
    for zone in this.m_zones {
      if zone.inRange {
        let audio: ref<GarageAudio> = zone.location.audio;
        let dx: Float = audio.x - at.X;
        let dy: Float = audio.y - at.Y;
        let distance: Float = dx * dx + dy * dy;
        if !IsDefined(nearest) || distance < best {
          nearest = zone;
          best = distance;
        }
      }
    }
    return IsDefined(nearest) && this.StartGarageMusic(nearest.location.id);
  }

  // A volume change goes on the row while it plays. Only a different routing type needs another row, and a restart from
  // where the track is
  private func Refresh(zone: ref<GarageMusicZone>) -> Void {
    if !IsNameValid(zone.row) { return; }
    let type: CName = this.RoutingType(zone);
    let volume: Float = this.Volume();
    if Equals(type, zone.playingType) {
      if AbsF(volume - zone.playingVolume) >= 0.001 {
        AudioXLAPI.SetGain(zone.row, volume);
        zone.playingVolume = volume;
      }
      return;
    }
    let row: CName = this.RowFor(zone.track, type);
    if !IsNameValid(row) { return; }
    let position: Float = AudioXLAPI.Position(zone.row);
    AudioXLAPI.StopOn(zone.emitter, zone.row, 0.0);
    AudioXLAPI.SetGain(row, volume);
    if AudioXLAPI.PlayOn(zone.emitter, row, this.Offset(zone), position, 0.0) {
      zone.row = row;
      zone.playingType = type;
      zone.playingVolume = volume;
    } else {
      this.Warn("PlayOn failed for " + NameToString(row));
      this.PlayNext(zone);
    }
  }

  public func UpdateAllVolumes() -> Void {
    for zone in this.m_zones { this.Refresh(zone); }
  }

  public func OnSettingsChanged() -> Void {
    if !IsDefined(this.m_xu) { return; }
    if !GarageMusicSettings.Get().musicEnabled {
      this.StopAllGarageMusic();
      return;
    }
    for zone in this.m_zones { this.ApplyEmitter(zone); }
    this.UpdateAllVolumes();
    this.StartAllGarageMusic();
  }

  /// For a pack whose weights changed. Waits a moment, so every pack's had its say before the restart.
  public func RequestMusicRestart() -> Void {
    if !IsDefined(this.m_xu) { return; }
    if this.m_restart != 0ul { this.m_xu.Cancel(this.m_restart); }
    this.m_restart = this.m_xu.After(0.1, this, n"OnRestart");
  }

  public func OnRestart(e: ref<XUtilsEvent>) -> Void {
    this.m_restart = 0ul;
    // No fade, the next track starts on the same emitter straight away
    for zone in this.m_zones { this.StopZone(zone, 0.0); }
    if this.HasAnyActivePlaylist() { this.StartAllGarageMusic(); }
  }

  private func Warn(text: String) -> Void {
    if IsDefined(this.m_log) { this.m_log.Warn(text); }
  }
}
