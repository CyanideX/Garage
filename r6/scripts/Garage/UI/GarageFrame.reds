module Garage.UI

import Codeware.UI.*
import Garage.*
import Garage.Data.*
import Garage.Economy.*
import Garage.Services.*
import Garage.Vehicle.*
import Garage.World.*
import VehicleCore.*
import VehicleCore.Features.*

// Insets for widgets anchored to a screen edge. HUD Lens Distortion bows the corners outward, so
// anything hugging an edge ends up off-screen at ultrawide; these keep it clear.
public abstract class GarageLayout {
    public static func EdgeInsetTop() -> Float {
        return 120.0;
    }

    public static func EdgeInsetSide() -> Float {
        return 60.0;
    }
}

public class GarageFrame extends inkCustomController {
    protected let m_root: wref<inkFlex>;
    protected let m_container: wref<inkCanvas>;
    protected let m_background: wref<inkRectangle>;
    protected let m_pattern: wref<inkImage>;
    protected let m_frame: wref<inkImage>;
    protected let m_buttonHints: wref<ButtonHintsEx>;
    protected let m_areaSize: Vector2;
    protected let m_gameInstance: GameInstance;

    protected cb func OnCreate() {
        let accentColor = new HDRColor(0.24, 0.77, 0.89, 1.0);

        let frame = new inkFlex();
        frame.SetName(n"garageFrame");
        frame.SetAnchor(inkEAnchor.Fill);

        let background = new inkRectangle();
        background.SetAnchor(inkEAnchor.Fill);
        background.SetMargin(new inkMargin(8.0, 8.0, 8.0, 8.0));
        background.SetTintColor(ThemeColors.PureBlack());
        background.SetOpacity(0.6);
        background.Reparent(frame);
        this.m_background = background;

        let pattern = new inkImage();
        pattern.SetName(n"pattern");
        pattern.SetAtlasResource(r"base\\gameplay\\gui\\fullscreen\\inventory\\atlas_inventory.inkatlas");
        pattern.SetTexturePart(n"BLUEPRINT_3slot");
        pattern.SetBrushTileType(inkBrushTileType.Both);
        pattern.SetTileHAlign(inkEHorizontalAlign.Center);
        pattern.SetTileVAlign(inkEVerticalAlign.Center);
        pattern.SetAnchor(inkEAnchor.Fill);
        pattern.SetOpacity(0.021);
        pattern.SetTintColor(accentColor);
        pattern.SetMargin(new inkMargin(8.0, 4.0, 8.0, 2.0));
        pattern.Reparent(frame);
        this.m_pattern = pattern;

        let frameBorder = new inkImage();
        frameBorder.SetName(n"frame");
        frameBorder.SetAtlasResource(r"base\\gameplay\\gui\\fullscreen\\inventory\\inventory4_atlas.inkatlas");
        frameBorder.SetTexturePart(n"itemGridFrame3Big");
        frameBorder.SetNineSliceScale(true);
        frameBorder.SetNineSliceGrid(new inkMargin(24, 24, 24, 24));
        frameBorder.SetAnchor(inkEAnchor.Fill);
        frameBorder.SetOpacity(1.0);
        frameBorder.SetTintColor(accentColor);
        frameBorder.Reparent(frame);
        this.m_frame = frameBorder;

        let container = new inkCanvas();
        container.SetName(n"container");
        container.SetAnchor(inkEAnchor.Fill);
        container.Reparent(frame);

        this.m_root = frame;
        this.m_container = container;

        this.SetRootWidget(frame);
        this.SetContainerWidget(container);
    }

    public func GetContainer() -> wref<inkCanvas> {
        return this.m_container;
    }

    public func GetHints() -> wref<ButtonHintsEx> {
        return this.m_buttonHints;
    }

    public func GetSize() -> Vector2 {
        return this.m_areaSize;
    }

    public func SetSize(areaSize: Vector2) {
        this.m_areaSize = areaSize;
    }

    public func SetHints(buttonHints: wref<ButtonHintsEx>) {
        this.m_buttonHints = buttonHints;
    }

    public func SetGameInstance(gi: GameInstance) {
        this.m_gameInstance = gi;
    }

    public func GetGameInstance() -> GameInstance {
        return this.m_gameInstance;
    }

    public func AddScreen(screen: ref<GarageScreen>) {
        screen.Assign(this);
    }

    // Trigger cart changed callback (notifies popup to refresh cart widget)
    public func TriggerCartChanged() {
        this.CallCustomCallback(n"OnCartChanged");
    }

    // Trigger screen error recovery (navigates back to hub and logs error)
    public func TriggerScreenError() {
        this.CallCustomCallback(n"OnScreenError");
    }

    public static func Create() -> ref<GarageFrame> {
        let self = new GarageFrame();
        self.CreateInstance();
        return self;
    }
}
