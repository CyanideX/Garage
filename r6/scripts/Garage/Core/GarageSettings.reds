module Garage

public enum GarageDofMode {
  Both = 0,
  FarOnly = 1,
}

public class GarageSettings extends ScriptableService {
  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Services")
  @runtimeProperty("ModSettings.category.order", "20")
  @runtimeProperty("ModSettings.displayName", "Aftermarket")
  @runtimeProperty("ModSettings.description", "Buy and fit aftermarket parts at garages.\nWhen off, it costs nothing.")
  public let aftermarketEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Services")
  @runtimeProperty("ModSettings.category.order", "20")
  @runtimeProperty("ModSettings.displayName", "Chop Shop")
  @runtimeProperty("ModSettings.description", "Sell vehicles at garages.\nWhen off, it costs nothing.")
  public let chopShopEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Services")
  @runtimeProperty("ModSettings.category.order", "20")
  @runtimeProperty("ModSettings.displayName", "Quick Service")
  @runtimeProperty("ModSettings.description", "Pull up to a garage for a quick service without going inside.\nWhen off, it costs nothing.")
  public let quickEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Services")
  @runtimeProperty("ModSettings.category.order", "20")
  @runtimeProperty("ModSettings.displayName", "Repair")
  @runtimeProperty("ModSettings.description", "Repair vehicles at garages.\nWhen off, it costs nothing.")
  public let repairEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Services")
  @runtimeProperty("ModSettings.category.order", "20")
  @runtimeProperty("ModSettings.displayName", "Swap")
  @runtimeProperty("ModSettings.description", "Swap vehicle appearances and paint at garages.\nWhen off, it costs nothing.")
  public let swapEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "10")
  @runtimeProperty("ModSettings.displayName", "Block Customization When Damaged")
  @runtimeProperty("ModSettings.description", "Also block customization when vehicle is too damaged and not just when blown up.")
  public let blockWhenDamaged: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "10")
  @runtimeProperty("ModSettings.displayName", "Switch Camera on Hover")
  @runtimeProperty("ModSettings.description", "Hovering subcategory buttons to preview parts camera angle.\nRestart for changes to take effect.")
  public let cameraOnHover: Bool = false;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "10")
  @runtimeProperty("ModSettings.displayName", "Enforce Garage Size Limits")
  @runtimeProperty("ModSettings.description", "Turn away vehicles that are too long, wide or tall for a garage.\nWhen disabled, any vehicle is accepted; oversized ones may clip through walls.")
  public let enforceSizeLimits: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Camera")
  @runtimeProperty("ModSettings.category.order", "30")
  @runtimeProperty("ModSettings.displayName", "Blend Camera on Enter/Exit")
  @runtimeProperty("ModSettings.description", "Smoothly blend camera when opening/closing garage.\nWhen disabled, camera cuts instantly on enter/exit.")
  public let cameraBlendEnabled: Bool = false;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Camera")
  @runtimeProperty("ModSettings.category.order", "30")
  @runtimeProperty("ModSettings.displayName", "Blend In Duration")
  @runtimeProperty("ModSettings.description", "Camera blend time when entering garage (seconds). Set to 0 for instant.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "3.0")
  public let cameraBlendInDuration: Float = 2.0;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Camera")
  @runtimeProperty("ModSettings.category.order", "30")
  @runtimeProperty("ModSettings.displayName", "Blend Out Duration")
  @runtimeProperty("ModSettings.description", "Camera blend time when exiting garage (seconds). Set to 0 for instant.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "3.0")
  public let cameraBlendOutDuration: Float = 0.0;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Camera")
  @runtimeProperty("ModSettings.category.order", "30")
  @runtimeProperty("ModSettings.displayName", "Cinematic Bars")
  @runtimeProperty("ModSettings.description", "Show letterbox cinematic bars during idle camera playback.")
  public let cinematicBarsEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Camera")
  @runtimeProperty("ModSettings.category.order", "30")
  @runtimeProperty("ModSettings.displayName", "Shuffle Idle Paths")
  @runtimeProperty("ModSettings.description", "Randomize the order of idle camera paths on each garage visit.")
  public let shufflePathsEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Camera")
  @runtimeProperty("ModSettings.category.order", "30")
  @runtimeProperty("ModSettings.displayName", "Depth of Field")
  @runtimeProperty("ModSettings.description", "Apply cinematic depth of field during garage camera sessions.")
  public let dofEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Camera")
  @runtimeProperty("ModSettings.category.order", "30")
  @runtimeProperty("ModSettings.displayName", "Focus Depth")
  @runtimeProperty("ModSettings.description", "How far behind the focus point stays sharp, in multiples of the focus distance. At 1.5, focusing at 3 m keeps everything out to 7.5 m sharp.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "5.0")
  public let dofFocusDepth: Float = 1.5;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Camera")
  @runtimeProperty("ModSettings.category.order", "30")
  @runtimeProperty("ModSettings.displayName", "Blur Falloff")
  @runtimeProperty("ModSettings.description", "How gradually the surroundings blur past the sharp area. Lower values blur them sooner.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.2")
  @runtimeProperty("ModSettings.max", "6.0")
  public let dofFalloff: Float = 1.5;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Camera")
  @runtimeProperty("ModSettings.category.order", "30")
  @runtimeProperty("ModSettings.displayName", "DOF Intensity")
  @runtimeProperty("ModSettings.description", "Strength of the foreground and background blur.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "3.0")
  public let dofIntensity: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Camera")
  @runtimeProperty("ModSettings.category.order", "30")
  @runtimeProperty("ModSettings.displayName", "DOF Mode")
  @runtimeProperty("ModSettings.displayValues.Both", "Both")
  @runtimeProperty("ModSettings.displayValues.FarOnly", "Far Only")
  public let dofMode: GarageDofMode = GarageDofMode.Both;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Shake")
  @runtimeProperty("ModSettings.category.order", "40")
  @runtimeProperty("ModSettings.displayName", "Part View Shake")
  @runtimeProperty("ModSettings.description", "Subtle camera shake when viewing individual parts.")
  public let shakeEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Shake")
  @runtimeProperty("ModSettings.category.order", "40")
  @runtimeProperty("ModSettings.displayName", "Cinematic Shake")
  @runtimeProperty("ModSettings.description", "Subtle camera shake during idle path playback.")
  public let cinematicShakeEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Shake")
  @runtimeProperty("ModSettings.category.order", "40")
  @runtimeProperty("ModSettings.displayName", "Perlin Noise Shake")
  @runtimeProperty("ModSettings.description", "Use Perlin noise for organic, non-repeating shake motion.\nWhen disabled, uses sine wave (smoother, more rhythmic).")
  public let perlinShakeEnabled: Bool = false;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Pricing")
  @runtimeProperty("ModSettings.category.order", "50")
  @runtimeProperty("ModSettings.displayName", "Custom Tier Multipliers")
  @runtimeProperty("ModSettings.description", "Enable per-tier fee multiplier overrides. When disabled, the default multipliers are used.")
  public let tierMultiplierEnabled: Bool = false;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Pricing")
  @runtimeProperty("ModSettings.category.order", "50")
  @runtimeProperty("ModSettings.displayName", "Classic Multiplier")
  @runtimeProperty("ModSettings.description", "Service fee multiplier for Classic tier vehicles.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "4.0")
  public let tierMultiplierClassic: Float = 0.80;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Pricing")
  @runtimeProperty("ModSettings.category.order", "50")
  @runtimeProperty("ModSettings.displayName", "Sport Multiplier")
  @runtimeProperty("ModSettings.description", "Service fee multiplier for Sport tier vehicles.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "4.0")
  public let tierMultiplierSport: Float = 0.90;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Pricing")
  @runtimeProperty("ModSettings.category.order", "50")
  @runtimeProperty("ModSettings.displayName", "Muscle Multiplier")
  @runtimeProperty("ModSettings.description", "Service fee multiplier for Muscle tier vehicles.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "4.0")
  public let tierMultiplierMuscle: Float = 1.00;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Pricing")
  @runtimeProperty("ModSettings.category.order", "50")
  @runtimeProperty("ModSettings.displayName", "Premium Multiplier")
  @runtimeProperty("ModSettings.description", "Service fee multiplier for Premium tier vehicles.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "4.0")
  public let tierMultiplierPremium: Float = 1.15;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Pricing")
  @runtimeProperty("ModSettings.category.order", "50")
  @runtimeProperty("ModSettings.displayName", "Exotic Multiplier")
  @runtimeProperty("ModSettings.description", "Service fee multiplier for Exotic tier vehicles.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "4.0")
  public let tierMultiplierExotic: Float = 1.35;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Pricing")
  @runtimeProperty("ModSettings.category.order", "50")
  @runtimeProperty("ModSettings.displayName", "Hyper Multiplier")
  @runtimeProperty("ModSettings.description", "Service fee multiplier for Hyper tier vehicles.")
  @runtimeProperty("ModSettings.step", "0.1")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "4.0")
  public let tierMultiplierHyper: Float = 1.60;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Economy")
  @runtimeProperty("ModSettings.category.order", "60")
  @runtimeProperty("ModSettings.displayName", "Disable Sale Delay")
  @runtimeProperty("ModSettings.description", "Sales complete in 1 game-second. Only affects future sales.")
  public let disableSaleDelay: Bool = false;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Economy")
  @runtimeProperty("ModSettings.category.order", "60")
  @runtimeProperty("ModSettings.displayName", "Sale Delay Multiplier")
  @runtimeProperty("ModSettings.description", "Scales how long a garage takes to clear a sold vehicle. Only affects future sales.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.1")
  @runtimeProperty("ModSettings.max", "2.0")
  public let saleDelayMultiplier: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Economy")
  @runtimeProperty("ModSettings.category.order", "60")
  @runtimeProperty("ModSettings.displayName", "Cooldown Multiplier")
  @runtimeProperty("ModSettings.description", "Scales garage cooldowns and lockdowns (after claiming a vehicle or a quick service). Set to 0 to disable them. Only affects future cooldowns.")
  @runtimeProperty("ModSettings.step", "0.05")
  @runtimeProperty("ModSettings.min", "0.0")
  @runtimeProperty("ModSettings.max", "2.0")
  public let cooldownMultiplier: Float = 1.0;

  @runtimeProperty("ModSettings.mod", "Garage")
  @runtimeProperty("ModSettings.category", "Debug")
  @runtimeProperty("ModSettings.category.order", "70")
  @runtimeProperty("ModSettings.displayName", "Debug Logging")
  @runtimeProperty("ModSettings.description", "Enable verbose debug logging. Restart required for changes to take effect.")
  public let debugLogging: Bool = false;

  public static func Get() -> ref<GarageSettings> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"Garage.GarageSettings") as GarageSettings;
  }

  private cb func OnInitialize() {
    XUtilsModSettings.Pull(this, n"Garage");
    this.Listen();
  }

  @if(ModuleExists("ModSettingsModule"))
  private func Listen() -> Void {
    ModSettings.RegisterListenerToClass(this);
    ModSettings.RegisterListenerToModifications(this);
  }

  @if(!ModuleExists("ModSettingsModule"))
  private func Listen() -> Void {}

  public cb func OnModSettingsChange() -> Void {
    let system: ref<GarageSystem> = GarageSystem.Get();
    if IsDefined(system) { system.OnSettingsChanged(); }
  }

  public func GetTierMultiplier(tier: String) -> Float {
    if Equals(tier, "Classic") { return this.tierMultiplierClassic; }
    if Equals(tier, "Sport") { return this.tierMultiplierSport; }
    if Equals(tier, "Muscle") { return this.tierMultiplierMuscle; }
    if Equals(tier, "Premium") { return this.tierMultiplierPremium; }
    if Equals(tier, "Exotic") { return this.tierMultiplierExotic; }
    if Equals(tier, "Hyper") { return this.tierMultiplierHyper; }
    return 1.0;
  }
}

// Its own class: with two Mod Settings pages on one class, only the last page's values reached user.ini
public class GarageMusicSettings extends ScriptableService {
  @runtimeProperty("ModSettings.mod", "Garage Music")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "10")
  @runtimeProperty("ModSettings.displayName", "Enable Garage Music")
  @runtimeProperty("ModSettings.description", "Play ambient music at garage locations.")
  public let musicEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage Music")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "10")
  @runtimeProperty("ModSettings.displayName", "Garage Music Volume")
  @runtimeProperty("ModSettings.description", "Adjust the volume of garage music.")
  @runtimeProperty("ModSettings.step", "1")
  @runtimeProperty("ModSettings.min", "1")
  @runtimeProperty("ModSettings.max", "100")
  public let musicVolume: Int32 = 45;

  @runtimeProperty("ModSettings.mod", "Garage Music")
  @runtimeProperty("ModSettings.category", "General")
  @runtimeProperty("ModSettings.category.order", "10")
  @runtimeProperty("ModSettings.displayName", "Follow Game Music Volume")
  @runtimeProperty("ModSettings.description", "Garage music follows the game's Music volume slider.\nWhen disabled, it follows the SFX slider instead.")
  public let musicOnMusicSlider: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage Music")
  @runtimeProperty("ModSettings.category", "Acoustics")
  @runtimeProperty("ModSettings.category.order", "20")
  @runtimeProperty("ModSettings.displayName", "Reverb Amount")
  @runtimeProperty("ModSettings.description", "Scale the reverb of every garage. 100 uses each garage's own amount, 0 turns reverb off.")
  @runtimeProperty("ModSettings.step", "5")
  @runtimeProperty("ModSettings.min", "0")
  @runtimeProperty("ModSettings.max", "150")
  public let musicReverbAmount: Int32 = 100;

  @runtimeProperty("ModSettings.mod", "Garage Music")
  @runtimeProperty("ModSettings.category", "Acoustics")
  @runtimeProperty("ModSettings.category.order", "20")
  @runtimeProperty("ModSettings.displayName", "Wall Occlusion")
  @runtimeProperty("ModSettings.description", "Muffle garage music when walls are between you and the garage.")
  public let musicOcclusionEnabled: Bool = true;

  @runtimeProperty("ModSettings.mod", "Garage Music")
  @runtimeProperty("ModSettings.category", "Acoustics")
  @runtimeProperty("ModSettings.category.order", "20")
  @runtimeProperty("ModSettings.displayName", "Garage EQ")
  @runtimeProperty("ModSettings.description", "Apply each garage's own low-pass and high-pass filtering to its music.")
  public let musicEqEnabled: Bool = true;

  public static func Get() -> ref<GarageMusicSettings> {
    return GameInstance.GetScriptableServiceContainer().GetService(n"Garage.GarageMusicSettings") as GarageMusicSettings;
  }

  private cb func OnInitialize() {
    XUtilsModSettings.Pull(this, n"Garage Music");
    this.Listen();
  }

  @if(ModuleExists("ModSettingsModule"))
  private func Listen() -> Void {
    ModSettings.RegisterListenerToClass(this);
  }

  @if(!ModuleExists("ModSettingsModule"))
  private func Listen() -> Void {}

  public func GetVolume() -> Float { return Cast<Float>(this.musicVolume) / 100.0; }

  public func GetReverbAmount() -> Float { return Cast<Float>(this.musicReverbAmount) / 100.0; }
}
