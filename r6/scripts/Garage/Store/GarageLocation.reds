module Garage.Data

/// A spot with a heading, for the deck and where V stands.
public class GarageSpot extends IScriptable {
  public let x: Float;
  public let y: Float;
  public let z: Float;
  public let yaw: Float;

  public func Position() -> Vector4 { return new Vector4(this.x, this.y, this.z, 1.0); }
}

public class GarageZone extends IScriptable {
  public let enter: Float = 30.0;
  public let exit: Float = 15.0;
  /// 0 is 80% of exit
  public let service: Float;
  public let arrival: Float;
  public let events: Bool = true;
}

public class GarageDoor extends IScriptable {
  public let nodeRef: String;
  /// Text, since a hash won't fit a JSON number
  public let entityHash: String;
}

/// 0 is no limit.
public class GarageLimits extends IScriptable {
  public let width: Float;
  public let length: Float;
  public let height: Float;
}

public class GarageAudio extends IScriptable {
  public let x: Float;
  public let y: Float;
  public let z: Float;
  public let type: String = "auto";
  public let gain: Float = 1.0;
  public let reverb: String = "revb_interior_factory_medium__medium";
  public let reverbLevel: Float = 0.35;
  public let lowPass: Float;
  public let highPass: Float;
  public let occlusion: Bool = true;
  public let occlusionHz: Float = 1200.0;
  public let occlusionLevel: Float = 0.9;
  public let playlist: String = "pool";
}

public class GarageCameraData extends IScriptable {
  public let idleShake: String = "timeline";
  public let partViewShake: String = "showroom";
  public let maxIdleSeconds: Float = 6.0;
}

/// One garage, as its file has it. Economy has no class until phase 6: GarageData keeps the file's JSON, so it survives a save.
public class GarageLocation extends IScriptable {
  public let format: String = "garage.location";
  public let version: Int32 = 1;
  public let id: CName;
  public let name: String;
  public let region: String;
  public let deck: ref<GarageSpot>;
  public let zone: ref<GarageZone>;
  public let door: ref<GarageDoor>;
  public let limits: ref<GarageLimits>;
  public let playerSpawn: ref<GarageSpot>;
  public let audio: ref<GarageAudio>;
  public let camera: ref<GarageCameraData>;
}

/// What a save did. path and id are set when it worked, error when it didn't. replaced is the garage within 10 m it took over.
public class GarageSaveResult extends IScriptable {
  public let ok: Bool;
  public let path: String;
  public let error: String;
  public let id: CName;
  public let replaced: CName;

  public static func Failed(error: String) -> ref<GarageSaveResult> {
    let result: ref<GarageSaveResult> = new GarageSaveResult();
    result.error = error;
    return result;
  }

  public static func Saved(path: String) -> ref<GarageSaveResult> {
    let result: ref<GarageSaveResult> = new GarageSaveResult();
    result.ok = true;
    result.path = path;
    return result;
  }
}

/// A car's box when it can't be measured, half sizes in metres.
public class GarageBox extends IScriptable {
  public let half: Vector3;
  public let offset: Vector3;
}
