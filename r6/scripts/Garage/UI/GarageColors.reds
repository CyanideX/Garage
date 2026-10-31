module Garage.UI

// Named GarageColors to avoid collision with Codeware.UI.ThemeColors
public abstract class GarageColors {
    public static func AccentBlue() -> HDRColor {
        return new HDRColor(0.24, 0.77, 0.89, 1.0);
    }

    public static func Gold() -> HDRColor {
        return new HDRColor(1.0, 0.81, 0.06, 1.0);
    }

    public static func Error() -> HDRColor {
        return new HDRColor(1.0, 0.3, 0.3, 1.0);
    }

    public static func Success() -> HDRColor {
        return new HDRColor(0.2, 0.8, 0.2, 1.0);
    }

    public static func Warning() -> HDRColor {
        return new HDRColor(1.0, 0.361, 0.325, 1.0);
    }

    public static func Cyan() -> HDRColor {
        return new HDRColor(0.0, 0.9, 0.9, 1.0);
    }

    public static func Blue() -> HDRColor {
        return new HDRColor(0.3, 0.7, 1.0, 1.0);
    }

    public static func White() -> HDRColor {
        return new HDRColor(1.0, 1.0, 1.0, 1.0);
    }

    public static func BackgroundDark() -> HDRColor {
        return new HDRColor(0.02, 0.02, 0.03, 1.0);
    }

    public static func BackgroundDialog() -> HDRColor {
        return new HDRColor(0.1, 0.1, 0.15, 1.0);
    }

    public static func Overlay() -> HDRColor {
        return new HDRColor(0.0, 0.0, 0.0, 0.7);
    }

    // Muted text for contextually redundant buttons (#CB5C5CFF)
    public static func MutedText() -> HDRColor {
        return new HDRColor(0.796, 0.361, 0.361, 1.0);
    }

    // Muted background for contextually redundant buttons (#431616FF)
    public static func MutedBackground() -> HDRColor {
        return new HDRColor(0.263, 0.086, 0.086, 1.0);
    }

    public static func ResolveSwatch(rgb: String, colorId: String) -> HDRColor {
        if NotEquals(rgb, "") {
            let c = StrSplit(rgb, ",");
            if ArraySize(c) == 3 {
                return new HDRColor(StringToFloat(c[0]), StringToFloat(c[1]), StringToFloat(c[2]), 1.0);
            }
        }
        return GarageColors.GetPaintColor(colorId);
    }

    public static func GetPaintColor(colorName: String) -> HDRColor {
        let name = StrLower(colorName);

        // Matte paints
        if Equals(name, "matt_beige") { return new HDRColor(0.949, 0.914, 0.886, 1.0); }
        if Equals(name, "matt_black") { return new HDRColor(0.059, 0.063, 0.067, 1.0); }
        if Equals(name, "matt_blue") { return new HDRColor(0.373, 0.698, 0.949, 1.0); }
        if Equals(name, "matt_brown") { return new HDRColor(0.788, 0.631, 0.569, 1.0); }
        if Equals(name, "matt_charcoal") { return new HDRColor(0.506, 0.518, 0.529, 1.0); }
        if Equals(name, "matt_darkblue") { return new HDRColor(0.459, 0.463, 0.682, 1.0); }
        if Equals(name, "matt_darkbrown") { return new HDRColor(0.541, 0.384, 0.267, 1.0); }
        if Equals(name, "matt_darkgray") { return new HDRColor(0.553, 0.518, 0.525, 1.0); }
        if Equals(name, "matt_darkgreen") { return new HDRColor(0.494, 0.533, 0.333, 1.0); }
        if Equals(name, "matt_darkwasabi") { return new HDRColor(0.859, 0.702, 0.302, 1.0); }
        if Equals(name, "matt_gray") { return new HDRColor(0.851, 0.831, 0.827, 1.0); }
        if Equals(name, "matt_green") { return new HDRColor(0.518, 0.812, 0.275, 1.0); }
        if Equals(name, "matt_lime") { return new HDRColor(0.980, 0.925, 0.455, 1.0); }
        if Equals(name, "matt_orange") { return new HDRColor(0.976, 0.702, 0.306, 1.0); }
        if Equals(name, "matt_pearlwhite") { return new HDRColor(0.941, 0.914, 0.890, 1.0); }
        if Equals(name, "matt_pink") { return new HDRColor(0.980, 0.667, 0.953, 1.0); }
        if Equals(name, "matt_red") { return new HDRColor(1.0, 0.388, 0.286, 1.0); }
        if Equals(name, "matt_skyblue") { return new HDRColor(0.576, 0.824, 1.0, 1.0); }
        if Equals(name, "matt_slategray") { return new HDRColor(0.906, 0.906, 0.933, 1.0); }
        if Equals(name, "matt_white") { return new HDRColor(0.988, 0.984, 0.984, 1.0); }
        if Equals(name, "matt_workblue") { return new HDRColor(0.502, 0.675, 0.682, 1.0); }
        if Equals(name, "matt_yellow") { return new HDRColor(0.945, 0.812, 0.412, 1.0); }

        // Metallic paints
        if Equals(name, "metallic_beige") { return new HDRColor(0.878, 0.780, 0.675, 1.0); }
        if Equals(name, "metallic_blue") { return new HDRColor(0.239, 0.380, 0.702, 1.0); }
        if Equals(name, "metallic_bronze") { return new HDRColor(0.710, 0.502, 0.329, 1.0); }
        if Equals(name, "metallic_brown") { return new HDRColor(0.702, 0.392, 0.125, 1.0); }
        if Equals(name, "metallic_charcoal") { return new HDRColor(0.329, 0.353, 0.392, 1.0); }
        if Equals(name, "metallic_darkblue") { return new HDRColor(0.200, 0.220, 0.376, 1.0); }
        if Equals(name, "metallic_darkbrown") { return new HDRColor(0.392, 0.247, 0.059, 1.0); }
        if Equals(name, "metallic_darkgray") { return new HDRColor(0.275, 0.267, 0.302, 1.0); }
        if Equals(name, "metallic_darkgreen") { return new HDRColor(0.145, 0.380, 0.188, 1.0); }
        if Equals(name, "metallic_darkred") { return new HDRColor(0.580, 0.0, 0.0, 1.0); }
        if Equals(name, "metallic_darkwasabi") { return new HDRColor(0.627, 0.506, 0.133, 1.0); }
        if Equals(name, "metallic_gold") { return new HDRColor(0.820, 0.537, 0.169, 1.0); }
        if Equals(name, "metallic_green") { return new HDRColor(0.259, 0.565, 0.098, 1.0); }
        if Equals(name, "metallic_mintsky") { return new HDRColor(0.392, 0.714, 0.737, 1.0); }
        if Equals(name, "metallic_orange") { return new HDRColor(0.863, 0.451, 0.129, 1.0); }
        if Equals(name, "metallic_pearlwhite") { return new HDRColor(0.733, 0.647, 0.631, 1.0); }
        if Equals(name, "metallic_pink") { return new HDRColor(0.925, 0.549, 0.886, 1.0); }
        if Equals(name, "metallic_purple") { return new HDRColor(0.533, 0.341, 0.961, 1.0); }
        if Equals(name, "metallic_red") { return new HDRColor(0.757, 0.039, 0.039, 1.0); }
        if Equals(name, "metallic_silver") { return new HDRColor(0.600, 0.580, 0.592, 1.0); }
        if Equals(name, "metallic_skyblue") { return new HDRColor(0.400, 0.627, 0.788, 1.0); }
        if Equals(name, "metallic_workblue") { return new HDRColor(0.196, 0.396, 0.439, 1.0); }

        // Solid wheel/rim finishes
        if Equals(name, "bronze") { return new HDRColor(0.639, 0.435, 0.231, 1.0); }
        if Equals(name, "chrome") || Equals(name, "chrom") { return new HDRColor(0.604, 0.604, 0.604, 1.0); }
        if Equals(name, "copper") { return new HDRColor(0.788, 0.565, 0.369, 1.0); }
        if Equals(name, "gold") { return new HDRColor(0.812, 0.584, 0.224, 1.0); }
        if Equals(name, "silver") { return new HDRColor(0.753, 0.753, 0.753, 1.0); }
        if Equals(name, "mattbronze") { return new HDRColor(0.545, 0.412, 0.078, 1.0); }

        // Basic colors
        if Equals(name, "beige") { return new HDRColor(0.902, 0.851, 0.812, 1.0); }
        if Equals(name, "black") { return new HDRColor(0.078, 0.078, 0.078, 1.0); }
        if Equals(name, "blue") { return new HDRColor(0.329, 0.510, 0.765, 1.0); }
        if Equals(name, "brown") { return new HDRColor(0.655, 0.525, 0.490, 1.0); }
        if Equals(name, "charcoal") { return new HDRColor(0.427, 0.455, 0.475, 1.0); }
        if Equals(name, "darkblue") { return new HDRColor(0.267, 0.278, 0.431, 1.0); }
        if Equals(name, "darkbrown") { return new HDRColor(0.439, 0.353, 0.282, 1.0); }
        if Equals(name, "darkgray") { return new HDRColor(0.361, 0.357, 0.373, 1.0); }
        if Equals(name, "darkgreen") { return new HDRColor(0.329, 0.404, 0.239, 1.0); }
        if Equals(name, "darkwasabi") { return new HDRColor(0.710, 0.565, 0.259, 1.0); }
        if Equals(name, "darkred") { return new HDRColor(0.545, 0.0, 0.0, 1.0); }
        if Equals(name, "gray") { return new HDRColor(0.820, 0.776, 0.792, 1.0); }
        if Equals(name, "green") { return new HDRColor(0.271, 0.549, 0.129, 1.0); }
        if Equals(name, "lemon") { return new HDRColor(1.0, 0.980, 0.804, 1.0); }
        if Equals(name, "lime") { return new HDRColor(0.827, 0.839, 0.361, 1.0); }
        if Equals(name, "orange") { return new HDRColor(0.992, 0.620, 0.318, 1.0); }
        if Equals(name, "pearlwhite") { return new HDRColor(0.929, 0.898, 0.867, 1.0); }
        if Equals(name, "pink") { return new HDRColor(0.937, 0.655, 0.914, 1.0); }
        if Equals(name, "purple") { return new HDRColor(0.702, 0.349, 0.671, 1.0); }
        if Equals(name, "red") { return new HDRColor(0.937, 0.298, 0.263, 1.0); }
        if Equals(name, "skyblue") { return new HDRColor(0.471, 0.776, 0.969, 1.0); }
        if Equals(name, "slategray") { return new HDRColor(0.784, 0.788, 0.851, 1.0); }
        if Equals(name, "white") { return new HDRColor(0.992, 0.984, 0.988, 1.0); }
        if Equals(name, "workblue") { return new HDRColor(0.314, 0.451, 0.467, 1.0); }
        if Equals(name, "yellow") { return new HDRColor(0.894, 0.725, 0.212, 1.0); }

        // Substring fallback for unknown color names
        if StrContains(name, "black") { return new HDRColor(0.078, 0.078, 0.078, 1.0); }
        if StrContains(name, "white") { return new HDRColor(0.992, 0.984, 0.988, 1.0); }
        if StrContains(name, "red") { return new HDRColor(0.937, 0.298, 0.263, 1.0); }
        if StrContains(name, "blue") { return new HDRColor(0.329, 0.510, 0.765, 1.0); }
        if StrContains(name, "green") { return new HDRColor(0.271, 0.549, 0.129, 1.0); }
        if StrContains(name, "yellow") { return new HDRColor(0.894, 0.725, 0.212, 1.0); }
        if StrContains(name, "orange") { return new HDRColor(0.992, 0.620, 0.318, 1.0); }
        if StrContains(name, "pink") { return new HDRColor(0.937, 0.655, 0.914, 1.0); }
        if StrContains(name, "purple") { return new HDRColor(0.702, 0.349, 0.671, 1.0); }
        if StrContains(name, "brown") { return new HDRColor(0.655, 0.525, 0.490, 1.0); }
        if StrContains(name, "gray") || StrContains(name, "grey") { return new HDRColor(0.820, 0.776, 0.792, 1.0); }
        if StrContains(name, "silver") { return new HDRColor(0.753, 0.753, 0.753, 1.0); }
        if StrContains(name, "gold") { return new HDRColor(0.812, 0.584, 0.224, 1.0); }

        // Default fallback - medium gray
        return new HDRColor(0.5, 0.5, 0.5, 1.0);
    }

    public static func HasPaintFinishes(subcategory: String) -> Bool {
        if Equals(subcategory, "car_paint") { return true; }
        if Equals(subcategory, "car_secpaint") { return true; }
        return false;
    }

    public static func GetPaintType(colorId: String) -> String {
        let name = StrLower(colorId);
        if StrBeginsWith(name, "matt_") { return "matte"; }
        if StrBeginsWith(name, "metallic_") { return "metallic"; }
        return "standard";
    }
}
