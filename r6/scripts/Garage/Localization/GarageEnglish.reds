module Garage.Localization
import Codeware.Localization.*

public class GarageEnglish extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    this.Text("Garage-Category-Title", "SELECT CATEGORY");
    this.Text("Garage-Category-Subtitle", "Choose a tuning category to browse available parts");
    this.Text("Garage-Category-Hint", "Select Category");
    this.Text("Garage-Category-Body", "BODY");
    this.Text("Garage-Category-Interior", "INTERIOR");
    this.Text("Garage-Category-Paint", "PAINT");
    this.Text("Garage-Category-Wheels", "WHEELS");
    this.Text("Garage-Category-Misc", "MISC");
    this.Text("Garage-Category-Restore", "RESTORE");
    this.Text("Garage-Category-Explode", "EXPLODE");
    this.Text("Garage-Category-Reset", "RESET");
    this.Text("Garage-Category-Checkout", "CHECKOUT");

    this.Text("Garage-Subcategory-Title", "SELECT SUBCATEGORY");
    this.Text("Garage-Subcategory-Subtitle", "Choose a part type");
    this.Text("Garage-Subcategory-Hint", "Select Subcategory");

    this.Text("Garage-PaintType-Title", "SELECT PAINT TYPE");
    this.Text("Garage-PaintType-Subtitle", "Choose a paint finish");
    this.Text("Garage-PaintType-Hint", "Select Paint Type");
    this.Text("Garage-PaintType-Standard", "Standard");
    this.Text("Garage-PaintType-Metallic", "Metallic");
    this.Text("Garage-PaintType-Matte", "Matte");

    this.Text("Garage-PartsList-Hint", "Select Part");
    this.Text("Garage-PartsList-Installed", "INSTALLED");
    this.Text("Garage-PartsList-Stock", "STOCK");
    this.Text("Garage-PartsList-Owned", "OWNED");
    this.Text("Garage-PartsList-FactoryOriginal", "Factory original");
    this.Text("Garage-PartsList-PreviouslyPurchased", "Previously purchased");
    this.Text("Garage-PartsList-Aftermarket", "Aftermarket");
    this.Text("Garage-PartsList-Upgrade", "upgrade");

    this.Text("Garage-Confirm-Title", "CONFIRM PURCHASE");
    this.Text("Garage-Confirm-PriceLabel", "PRICE:");
    this.Text("Garage-Confirm-BalanceLabel", "YOUR EDDIES:");
    this.Text("Garage-Confirm-ServiceFee", "Service Fee");
    this.Text("Garage-Confirm-Service", "service");
    this.Text("Garage-Confirm-Equip", "EQUIP");
    this.Text("Garage-Confirm-Install", "INSTALL");
    this.Text("Garage-Confirm-BuyNow", "BUY NOW");
    this.Text("Garage-Confirm-AddToCart", "ADD TO CART");
    this.Text("Garage-Confirm-Remove", "REMOVE");
    this.Text("Garage-Confirm-Installed", "INSTALLED");
    this.Text("Garage-Confirm-CurrentlyEquipped", "Currently Equipped");
    this.Text("Garage-Confirm-Hint", "Confirm");

    this.Text("Garage-Checkout-Title", "CHECKOUT");
    this.Text("Garage-Checkout-Subtitle", "Review your cart before purchasing");
    this.Text("Garage-Checkout-PartsLabel", "PARTS:");
    this.Text("Garage-Checkout-ServiceLabel", "SERVICE:");
    this.Text("Garage-Checkout-TotalLabel", "TOTAL:");
    this.Text("Garage-Checkout-BalanceLabel", "YOUR EDDIES:");
    this.Text("Garage-Checkout-EmptyCart", "Your cart is empty");
    this.Text("Garage-Checkout-Cancel", "CANCEL");
    this.Text("Garage-Checkout-Confirm", "CONFIRM");
    this.Text("Garage-Checkout-CartEmpty", "CART EMPTY");
    this.Text("Garage-Checkout-CantAfford", "CAN'T AFFORD");
    this.Text("Garage-Checkout-Hint", "Confirm");

    this.Text("Garage-ExitWarning-Title", "DISCARD CART?");
    this.Text("Garage-ExitWarning-YouHave", "You have");
    this.Text("Garage-ExitWarning-ItemsWorth", "item(s) worth");
    this.Text("Garage-ExitWarning-NoStay", "NO, STAY");
    this.Text("Garage-ExitWarning-YesExit", "YES, EXIT");
    this.Text("Garage-ExitWarning-YesDiscard", "YES, DISCARD");

    this.Text("Garage-Constraint-Title", "CART UPDATE REQUIRED");
    this.Text("Garage-Constraint-DefaultMessage", "This part requires changes to your cart.");
    this.Text("Garage-Constraint-ReplaceMessage", "This will replace items in your cart");
    this.Text("Garage-Constraint-AdditionalMessage", "This part requires additional changes to install");
    this.Text("Garage-Constraint-WillUpdate", "Will update:");
    this.Text("Garage-Constraint-Cancel", "CANCEL");
    this.Text("Garage-Constraint-Update", "UPDATE");
    this.Text("Garage-Constraint-VirtualSplitMessage", "Adding this will split your grouped cart entry.");
    this.Text("Garage-Constraint-SplitAndContinue", "UPDATE");
    this.Text("Garage-Constraint-SplitWillPreserve", "Will keep separately:");

    this.Text("Garage-ChopShop-ClaimVehicle", "CLAIM VEHICLE");
    this.Text("Garage-ChopShop-SellVehicle", "SELL VEHICLE");
    this.Text("Garage-ChopShop-Confirm", "CONFIRM");

    this.Text("Garage-MapFilter-Garages", "Garages");

    // ServiceHubScreen
    this.Text("Garage-Hub-Title", "SELECT SERVICE");
    this.Text("Garage-Hub-Subtitle", "Choose a service from this garage location");
    this.Text("Garage-Hub-NoServices", "No Services Available");
    this.Text("Garage-Hub-Checkout", "CHECKOUT");

    // CartWidget
    this.Text("Garage-Cart-Header", "SHOPPING CART");
    this.Text("Garage-Cart-Empty", "Cart is empty");
    this.Text("Garage-Cart-TotalLabel", "TOTAL:");
    this.Text("Garage-Cart-Clear", "CLEAR");
    this.Text("Garage-Cart-Checkout", "CHECKOUT");

    // UnavailableScreen
    this.Text("Garage-Unavailable-DefaultMessage", "Service unavailable");

    // ChopShopConfirmScreen
    this.Text("Garage-ChopShop-ClaimPriceLabel", "CLAIM PRICE:");
    this.Text("Garage-ChopShop-SellPriceLabel", "SELL PRICE:");
    this.Text("Garage-ChopShop-ClaimBalanceLabel", "YOUR EDDIES:");
    this.Text("Garage-ChopShop-SellBalanceLabel", "YOUR EDDIES (AFTER SALE):");
    this.Text("Garage-ChopShop-TierTooHigh", "VEHICLE CLASS TOO HIGH");
    this.Text("Garage-ChopShop-GarageCantAfford", "GARAGE CAN'T AFFORD");
    this.Text("Garage-ChopShop-AlreadyOwned", "ALREADY ON YOUR TITLE");
    this.Text("Garage-ChopShop-CannotBeSold", "VEHICLE CANNOT BE SOLD");
    this.Text("Garage-ChopShop-CannotBeClaimed", "VEHICLE CANNOT BE CLAIMED");
    this.Text("Garage-ChopShop-ConditionLabel", "Condition:");

    // QuickConfirmScreen
    this.Text("Garage-Quick-Title", "QUICK SERVICE");
    this.Text("Garage-Quick-AppearanceLabel", "APPEARANCE:");
    this.Text("Garage-Quick-RushFeeLabel", "RUSH FEE:");
    this.Text("Garage-Quick-TotalLabel", "TOTAL:");
    this.Text("Garage-Quick-BalanceLabel", "YOUR EDDIES:");
    this.Text("Garage-Quick-Cancel", "CANCEL");
    this.Text("Garage-Quick-Confirm", "CONFIRM");

    // RepairConfirmScreen
    this.Text("Garage-Repair-Title", "REPAIR VEHICLE");
    this.Text("Garage-Repair-QuickDesc", "Restore health and fix minor damage");
    this.Text("Garage-Repair-FullDesc", "Complete health and cosmetic restoration");
    this.Text("Garage-Repair-BalanceLabel", "YOUR EDDIES:");
    this.Text("Garage-Repair-HeatWarning", "POLICE ATTENTION DETECTED - Full Repair unavailable");
    this.Text("Garage-Repair-HealthSuffix", "HEALTH");
    this.Text("Garage-Repair-NoDamage", "NO DAMAGE");
    this.Text("Garage-Repair-Cancel", "CANCEL");

    // PaintScreen
    this.Text("Garage-Paint-Title", "PAINT");
    this.Text("Garage-Paint-PriceLabel", "SWAP PRICE:");
    this.Text("Garage-Paint-AppearanceLabel", "APPEARANCE:");
    this.Text("Garage-Paint-BalanceLabel", "YOUR EDDIES (AFTER PURCHASE):");
    this.Text("Garage-Paint-NoAppearances", "No appearances available");
    this.Text("Garage-Paint-Owned", "OWNED");
    this.Text("Garage-Paint-Active", "ACTIVE");
    this.Text("Garage-Paint-ClaimFirst", "UNOWNED");
    this.Text("Garage-Paint-Cancel", "CANCEL");
    this.Text("Garage-Paint-Confirm", "CONFIRM");

    // Service Descriptor Labels
    this.Text("Garage-Desc-Claim", "CLAIM");
    this.Text("Garage-Desc-Sell", "SELL");
    this.Text("Garage-Desc-Parts", "PARTS");
    this.Text("Garage-Desc-Quick", "QUICK");
    this.Text("Garage-Desc-Repair", "REPAIR");
    this.Text("Garage-Desc-Swap", "SWAP");

    // Unavailable Messages
    this.Text("Garage-Unavailable-QuickTitle", "Quick Service");
    this.Text("Garage-Unavailable-QuickMessage", "You don't have any heat");
    this.Text("Garage-Unavailable-SwapTitle", "Swap");
    this.Text("Garage-Unavailable-SwapMessage", "No valid appearances available for this vehicle");
    this.Text("Garage-Unavailable-PartsTitle", "Parts");
    this.Text("Garage-Unavailable-PartsMessage", "This vehicle doesn't have any parts");

    // Frame
    this.Text("Garage-Frame-Title", "GARAGE");
    this.Text("Garage-Frame-FluffRight", "TUNING SHOP");
    this.Text("Garage-Frame-GarageSystem", "GARAGE SYSTEM");

    // Repair
    this.Text("Garage-Repair-BaseLabel", "Base: ");
    this.Text("Garage-Repair-FeeLabel", "Fee: ");
    this.Text("Garage-Repair-TotalLabel", "Total: ");
    this.Text("Garage-Repair-Repairing", "REPAIRING...");
    this.Text("Garage-Repair-QuickPriceLabel", "QUICK REPAIR PRICE:");
    this.Text("Garage-Repair-FullPriceLabel", "FULL REPAIR PRICE:");
    this.Text("Garage-Repair-QuickTier", "Quick Repair");
    this.Text("Garage-Repair-FullTier", "Full Repair");
    this.Text("Garage-Repair-CompleteQuick", "Quick Repair complete");
    this.Text("Garage-Repair-CompleteFull", "Full Repair complete");
    this.Text("Garage-Repair-RefundedUnavailable", "Repair failed: vehicle unavailable. Refunded €$%s.");
    this.Text("Garage-Repair-RefundedAlreadyFixed", "Vehicle already repaired. Refunded €$%s.");
    this.Text("Garage-Repair-RefundedFailed", "Full Repair failed (%s). Refunded €$%s.");
    this.Text("Garage-Repair-Blocked", "BLOCKED");

    // ChopShop
    this.Text("Garage-ChopShop-BaseLabel", "Base: ");
    this.Text("Garage-ChopShop-ClaimRateLabel", "Claim Rate: ");
    this.Text("Garage-ChopShop-VinScrubLabel", "Vin Scrub: ");
    this.Text("Garage-ChopShop-TotalLabel", "Total: ");
    this.Text("Garage-ChopShop-GradeLabel", "Grade: ");
    this.Text("Garage-ChopShop-RiskLabel", "Risk: ");
    this.Text("Garage-ChopShop-TypeLabel", "Type: ");
    this.Text("Garage-ChopShop-FactionLabel", "Faction: ");
    this.Text("Garage-ChopShop-SpecialLabel", "Special: ");
    this.Text("Garage-ChopShop-AppearanceLabel", "Appearance: ");
    this.Text("Garage-ChopShop-DamageLabel", "Damage: ");
    this.Text("Garage-ChopShop-TierLabel", "Tier: ");
    this.Text("Garage-ChopShop-PartsLabel", "Parts: ");

    // Notify
    this.Text("Garage-Notify-UseTerminal", "Approach the vehicle to begin customization");
    this.Text("Garage-Notify-NearestGaragePrefix", "Your nearest CYX Garage is ");
    this.Text("Garage-Notify-NearestGarageInfix", " in ");
    this.Text("Garage-Notify-StandUp", "Stand up if you want to do business here.");
    this.Text("Garage-Notify-HolsterWeapon", "Holster your weapon if you want to do business.");
    this.Text("Garage-Notify-HeatTooHigh", "Heat level too high. You're on your own!");
    this.Text("Garage-Notify-Banned", "You've been permanently banned from this garage.");
    this.Text("Garage-Notify-DependencyOutdated", "Garage needs %s %s or newer (installed: %s).");
    this.Text("Garage-Notify-NamesMissing", "Garage unavailable: the game's record names failed to load. Restart the game.");
    this.Text("Garage-Notify-LockdownFallback", "Lockdown");
    this.Text("Garage-Notify-ComeBackIn", ". Come back in ");
    this.Text("Garage-Notify-ExitVehicle", "Exit your vehicle to begin customization.");
    this.Text("Garage-Notify-NoVehicles", "No vehicles nearby. We don't work on Wonder Woman's jet.");
    this.Text("Garage-Notify-BeyondRepair", "No amount of customization is going to fix that...");
    this.Text("Garage-Notify-TooDamaged", "Vehicle is too damaged for customization. Repair it first.");
    this.Text("Garage-Notify-ParkOnDeckPrefix", "Park your vehicle on the service deck. (");
    this.Text("Garage-Notify-ParkOnDeckSuffix", "m)");
    this.Text("Garage-Notify-UnsupportedVehicle", "We don't work on those kinds of vehicles.");
    this.Text("Garage-Notify-TooBig", "Too big for this garage: %s");
    this.Text("Garage-Notify-TooBigWidth", "width %s m (max %s m)");
    this.Text("Garage-Notify-TooBigLength", "length %s m (max %s m)");
    this.Text("Garage-Notify-TooBigHeight", "height %s m (max %s m)");

    // Transaction
    this.Text("Garage-Transaction-ClaimInvalid", "Claim failed: invalid vehicle or data.");
    this.Text("Garage-Transaction-InsufficientFunds", "Insufficient funds to claim this vehicle.");
    this.Text("Garage-Transaction-DeductFailed", "Transaction failed: could not deduct funds.");
    this.Text("Garage-Transaction-UnlockFailed", "Claim failed: could not unlock vehicle. You have been refunded.");
    this.Text("Garage-Transaction-ClaimSuccess", "Claimed");
    this.Text("Garage-Transaction-InsufficientFundsState", "Insufficient funds");
    this.Text("Garage-Transaction-ClaimFailedState", "Claim failed");

    // Map
    this.Text("Garage-Map-ClosedSuffix", "(Closed)");
    this.Text("Garage-Map-BannedIndefinitely", "Banned indefinitely");
    this.Text("Garage-Map-LockedDown", "Locked Down");
    this.Text("Garage-Map-SalePending", "Sale pending");
    this.Text("Garage-Map-Cooldown", "Cooldown");

    // Quick
    this.Text("Garage-Quick-HeatTooHigh", "Heat level too high");
    this.Text("Garage-Quick-PostPurchase", "Appearance changed");

    // Format
    this.Text("Garage-Format-StandardAppearance", "Standard");

    // PartsList
    this.Text("Garage-PartsList-PagePrefix", "Page ");
    this.Text("Garage-PartsList-PageSeparator", "/");
    this.Text("Garage-PartsList-DefaultOption", "Default Option");
    this.Text("Garage-PartsList-NoCustomization", "No customization available");

    // Confirm
    this.Text("Garage-Confirm-PartNamePlaceholder", "Part Name");
    this.Text("Garage-Confirm-PartDescPlaceholder", "Part description here");

    // HUD
    this.Text("Garage-HUD-Cash", "Cash");
    this.Text("Garage-HUD-Tier", "Tier");
    this.Text("Garage-HUD-CountdownHeader", "QUICK SERVICE");
    this.Text("Garage-HUD-CountdownTime", "Time");
    this.Text("Garage-HUD-ExitVehicle", "Exit Vehicle");

    // Tier Display Names
    this.Text("Garage-Tier-Standard", "Standard");
    this.Text("Garage-Tier-Classic", "Classic");
    this.Text("Garage-Tier-Sport", "Sport");
    this.Text("Garage-Tier-Premium", "Premium");
    this.Text("Garage-Tier-Exotic", "Exotic");
    this.Text("Garage-Tier-Hyper", "Hyper");
    this.Text("Garage-Tier-Economy", "Economy");

    // Notifications (Lua)
    this.Text("Garage-Notify-ClaimLockdown", "Too slow. This garage is locked for 24 hours.");
    this.Text("Garage-Notify-InsufficientFunds", "Insufficient funds!");
    this.Text("Garage-Notify-TransactionFailed", "Transaction failed!");
    this.Text("Garage-Notify-HeatCleared", "Heat cleared. Don't come back anytime soon.");
    this.Text("Garage-Notify-PaidGetOut", "Paid €$%s, now get the hell out of here!");
    this.Text("Garage-Notify-NoVehicleDetected", "No vehicle detected");
    this.Text("Garage-Notify-NoSchemaFound", "No schema found");
    this.Text("Garage-Notify-NoPaintColors", "No paint colors available");
    this.Text("Garage-Notify-NoCustomization", "No customization available");
    this.Text("Garage-Notify-RestoreToStock", "RESTORE TO STOCK");
    this.Text("Garage-Notify-RimColorAll", "Rim Color (All)");
    this.Text("Garage-Notify-WheelsAll", "Wheels (All)");
    this.Text("Garage-Notify-SinglePartPurchased", "1 part purchased for €$%s");
    this.Text("Garage-Notify-MultiPartPurchased", "%d parts purchased for €$%s");
    this.Text("Garage-Notify-RepairService", "Repair service: €$%s");
    this.Text("Garage-Notify-ServiceDone", "%s - €$%s");
    this.Text("Garage-Notify-ServiceDetail", "%s: %s");
    this.Text("Garage-Notify-DesignApplied", "Design applied");
    this.Text("Garage-Notify-TierBlocked", "This garage cannot service this vehicle tier");
  }
}
