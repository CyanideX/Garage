module Garage.Vehicle

// Back-slot animation modes -- determines what the back window slots control per vehicle
public enum GarageBackSlotMode {
    Windows = 0,
    Roof = 1,
    Popup = 2
}

public class VehicleSavedState {
    public let engineOn: Bool;
    public let headlightMode: vehicleELightMode;
}

public abstract class VehicleStateHelper {

    public static func SaveState(vehicle: ref<VehicleObject>) -> ref<VehicleSavedState> {
        let state = new VehicleSavedState();
        state.engineOn = vehicle.IsEngineTurnedOn();

        let vehPS = vehicle.GetVehiclePS();
        if IsDefined(vehPS) {
            let ctrlPS = vehPS.GetVehicleControllerPS();
            if IsDefined(ctrlPS) {
                state.headlightMode = ctrlPS.GetHeadLightMode();
            }
        }

        return state;
    }

    public static func RestoreState(vehicle: ref<VehicleObject>, state: ref<VehicleSavedState>) {
        if !IsDefined(vehicle) || !IsDefined(state) {
            return;
        }

        vehicle.TurnEngineOn(state.engineOn);

        let vehPS = vehicle.GetVehiclePS();
        if IsDefined(vehPS) {
            let ctrlPS = vehPS.GetVehicleControllerPS();
            if IsDefined(ctrlPS) {
                ctrlPS.SetHeadLightMode(state.headlightMode);
            }
        }
    }

    public static func SetupForGarage(vehicle: ref<VehicleObject>) {
        if !IsDefined(vehicle) {
            return;
        }

        vehicle.TurnEngineOn(true);

        VehicleStateHelper.PreventShutdown(vehicle);
        VehicleStateHelper.SetHeadlightMode(vehicle, vehicleELightMode.On);
    }

    public static func SetHeadlightMode(vehicle: ref<VehicleObject>, mode: vehicleELightMode) {
        if !IsDefined(vehicle) {
            return;
        }

        let vehPS = vehicle.GetVehiclePS();
        if IsDefined(vehPS) {
            let ctrlPS = vehPS.GetVehicleControllerPS();
            if IsDefined(ctrlPS) {
                ctrlPS.SetHeadLightMode(mode);
            }
        }
    }

    public static func EnableHighBeams(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.SetHeadlightMode(vehicle, vehicleELightMode.HighBeams);
    }

    // Default garage state
    public static func EnableLowBeams(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.SetHeadlightMode(vehicle, vehicleELightMode.On);
    }

    public static func DisableHeadlights(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.SetHeadlightMode(vehicle, vehicleELightMode.Off);
    }

    // --- Private helpers ---

    private static func OpenDoorBySlot(vehicle: ref<VehicleObject>, slotName: CName) {
        if !IsDefined(vehicle) { return; }
        let slotID: MountingSlotId;
        slotID.id = slotName;
        VehicleComponent.OpenDoor(vehicle, slotID);
    }

    private static func CloseDoorBySlot(vehicle: ref<VehicleObject>, slotName: CName) {
        if !IsDefined(vehicle) { return; }
        let vc = vehicle.GetVehicleComponent();
        if !IsDefined(vc) { return; }
        let ps = vc.GetPS();
        if !IsDefined(ps) { return; }
        let evt = new VehicleDoorClose();
        evt.slotID = slotName;
        GameInstance.GetPersistencySystem(vehicle.GetGame()).QueuePSEvent(ps.GetID(), ps.GetClassName(), evt);
    }

    private static func ApplyPartAnimation(vehicle: ref<VehicleObject>, slot: CName, state: Int32, duration: Float) {
        if !IsDefined(vehicle) { return; }
        let animFeature = new AnimFeature_PartData();
        animFeature.state = state;
        animFeature.duration = duration;
        AnimationControllerComponent.ApplyFeatureToReplicate(vehicle, slot, animFeature);
    }

    // --- Back-slot vehicle lookup ---

    private static func GetBackSlotMode(vehicle: ref<VehicleObject>) -> GarageBackSlotMode {
        if !IsDefined(vehicle) { return GarageBackSlotMode.Windows; }
        let id = vehicle.GetRecordID();

        // Roof vehicles (targa/convertible)
        if Equals(id, t"Vehicle.targa_gts_base")
        || Equals(id, t"Vehicle.ferrari_458sp_base")
        || Equals(id, t"Vehicle.ferrari_458sp_wbk_base") {
            return GarageBackSlotMode.Roof;
        }

        // Popup headlight vehicles
        if Equals(id, t"Vehicle.f40_zephyr_base")
        || Equals(id, t"Vehicle.mazda_rx7_base")
        || Equals(id, t"Vehicle.mazda_rx7_stage5_base")
        || Equals(id, t"Vehicle.mazda_rx7_wbk_base") {
            return GarageBackSlotMode.Popup;
        }

        return GarageBackSlotMode.Windows;
    }

    // --- Hood ---

    public static func OpenHood(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.OpenDoorBySlot(vehicle, n"hood");
    }

    public static func CloseHood(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.CloseDoorBySlot(vehicle, n"hood");
    }

    // --- Trunk ---

    public static func OpenTrunk(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.OpenDoorBySlot(vehicle, n"trunk");
    }

    public static func CloseTrunk(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.CloseDoorBySlot(vehicle, n"trunk");
    }

    // --- Doors (left/right front) ---

    public static func OpenDoorLeft(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.OpenDoorBySlot(vehicle, n"seat_front_left");
    }

    public static func CloseDoorLeft(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.CloseDoorBySlot(vehicle, n"seat_front_left");
    }

    public static func OpenDoorRight(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.OpenDoorBySlot(vehicle, n"seat_front_right");
    }

    public static func CloseDoorRight(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.CloseDoorBySlot(vehicle, n"seat_front_right");
    }

    // --- Roof (animation-based, per-vehicle timing) ---

    public static func OpenRoof(vehicle: ref<VehicleObject>) {
        let record = TweakDBInterface.GetVehicleRecord(vehicle.GetRecordID());
        if !IsDefined(record) { return; }
        let id = record.GetID();
        if Equals(id, t"Vehicle.ferrari_458sp_base")
        || Equals(id, t"Vehicle.ferrari_458sp_wbk_base") {
            VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_left_window", 1, 2.5);
            VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_right_window", 1, 2.5);
            return;
        }
        // Targa default: asymmetric
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_left_window", 1, 4.0);
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_right_window", 1, 2.5);
    }

    public static func CloseRoof(vehicle: ref<VehicleObject>) {
        let record = TweakDBInterface.GetVehicleRecord(vehicle.GetRecordID());
        if !IsDefined(record) { return; }
        let id = record.GetID();
        if Equals(id, t"Vehicle.ferrari_458sp_base")
        || Equals(id, t"Vehicle.ferrari_458sp_wbk_base") {
            VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_left_window", 3, 1.0);
            VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_right_window", 3, 1.0);
            return;
        }
        // Targa default: asymmetric
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_left_window", 3, 4.0);
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_right_window", 3, 1.0);
    }

    // --- Windows (animation-based, front only) ---
    // Only front windows -- back slots conflict with roof/popup headlight animations

    public static func OpenWindows(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_front_left_window", 1, 1.3);
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_front_right_window", 1, 1.3);
    }

    public static func CloseWindows(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_front_left_window", 3, 1.3);
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_front_right_window", 3, 1.3);
    }

    // --- Back Windows (standard vehicles only) ---

    public static func OpenBackWindows(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_left_window", 1, 1.3);
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_right_window", 1, 1.3);
    }

    public static func CloseBackWindows(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_left_window", 3, 1.3);
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_right_window", 3, 1.3);
    }

    // --- Popup Headlights (animation-based, e.g. Ferrari F40) ---

    public static func RaisePopupHeadlights(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_left_window", 1, 1.0);
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_right_window", 1, 1.0);
    }

    public static func LowerPopupHeadlights(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_left_window", 3, 0.5);
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"seat_back_right_window", 3, 0.5);
    }

    // --- Back-slot dispatch (vehicle-aware) ---

    public static func OpenBackSlots(vehicle: ref<VehicleObject>) {
        let mode = VehicleStateHelper.GetBackSlotMode(vehicle);
        if Equals(mode, GarageBackSlotMode.Roof) {
            VehicleStateHelper.OpenRoof(vehicle);
        } else if Equals(mode, GarageBackSlotMode.Popup) {
            VehicleStateHelper.RaisePopupHeadlights(vehicle);
        } else {
            VehicleStateHelper.OpenBackWindows(vehicle);
        }
    }

    public static func CloseBackSlots(vehicle: ref<VehicleObject>) {
        let mode = VehicleStateHelper.GetBackSlotMode(vehicle);
        if Equals(mode, GarageBackSlotMode.Roof) {
            VehicleStateHelper.CloseRoof(vehicle);
        } else if Equals(mode, GarageBackSlotMode.Popup) {
            VehicleStateHelper.LowerPopupHeadlights(vehicle);
        } else {
            VehicleStateHelper.CloseBackWindows(vehicle);
        }
    }

    // --- Spoiler (animation-based) ---

    public static func DeploySpoiler(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"spoiler", 1, 0.75);
    }

    public static func RetractSpoiler(vehicle: ref<VehicleObject>) {
        VehicleStateHelper.ApplyPartAnimation(vehicle, n"spoiler", 3, 0.75);
    }

    // --- Explode / Reset view ---

    public static func ExplodeView(vehicle: ref<VehicleObject>) {
        if !IsDefined(vehicle) { return; }
        VehicleStateHelper.OpenHood(vehicle);
        VehicleStateHelper.OpenTrunk(vehicle);
        VehicleStateHelper.OpenDoorLeft(vehicle);
        VehicleStateHelper.OpenDoorRight(vehicle);
        VehicleStateHelper.OpenWindows(vehicle);
        VehicleStateHelper.OpenBackSlots(vehicle);
        VehicleStateHelper.DeploySpoiler(vehicle);
        VehicleStateHelper.EnableHighBeams(vehicle);
    }

    public static func ResetView(vehicle: ref<VehicleObject>) {
        if !IsDefined(vehicle) { return; }
        VehicleStateHelper.CloseHood(vehicle);
        VehicleStateHelper.CloseTrunk(vehicle);
        VehicleStateHelper.CloseDoorLeft(vehicle);
        VehicleStateHelper.CloseDoorRight(vehicle);
        VehicleStateHelper.CloseWindows(vehicle);
        VehicleStateHelper.CloseBackSlots(vehicle);
        VehicleStateHelper.RetractSpoiler(vehicle);
        VehicleStateHelper.EnableLowBeams(vehicle);
    }

    // --- Subcategory checks (extension points for vehicle mods) ---
    // Convention: subcategory names ending in _ext trigger panel opening.
    // "hood" and "trunk" refer to vehicle animation SLOTS (not physical position).
    // The vehicle .ent determines which panel opens for each slot.
    //
    // Trigger subcategory names:
    //   trunk_ext   -> opens trunk slot (cargo inside trunk, regardless of front/rear)
    //   trunk_cargo -> opens trunk slot (alternate name for cargo)
    //   hood_ext    -> opens hood slot (engine bay access, cargo inside hood)
    //   engine      -> opens hood slot (engine modifications)
    //
    // Do NOT trigger for: trunk (lid itself), hood (scoop), wing (on top of trunk)

    public static func ShouldOpenHood(subcategory: String) -> Bool {
        if Equals(subcategory, "hood_ext") { return true; }
        if Equals(subcategory, "engine") { return true; }
        return false;
    }

    public static func ShouldOpenTrunk(subcategory: String) -> Bool {
        if Equals(subcategory, "trunk_ext") { return true; }
        if Equals(subcategory, "trunk_cargo") { return true; }
        return false;
    }

    // Tricks the game into thinking the car's already in its default running state
    public static func PreventShutdown(vehicle: ref<VehicleObject>) {
        if !IsDefined(vehicle) {
            return;
        }

        let vehPS = vehicle.GetVehiclePS();
        if IsDefined(vehPS) {
            let ctrlPS = vehPS.GetVehicleControllerPS();
            if IsDefined(ctrlPS) {
                if NotEquals(ctrlPS.GetState(), vehicleEState.Default) {
                    ctrlPS.SetState(vehicleEState.Default);
                }
            }
        }
    }
}
