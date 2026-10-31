module Garage.Localization
import Codeware.Localization.*

public class GarageGerman extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    this.Text("Garage-Prompt-Enter", "Garage betreten");
    this.Text("Garage-Map-Description", "Fahrzeugservice");

    this.Text("Garage-Category-Title", "KATEGORIE WÄHLEN");
    this.Text("Garage-Category-Subtitle", "Wähle eine Tuning-Kategorie, um verfügbare Teile zu durchsuchen");
    this.Text("Garage-Category-Hint", "Kategorie wählen");
    this.Text("Garage-Category-Body", "KAROSSERIE");
    this.Text("Garage-Category-Interior", "INNENRAUM");
    this.Text("Garage-Category-Paint", "LACK");
    this.Text("Garage-Category-Wheels", "RÄDER");
    this.Text("Garage-Category-Misc", "SONSTIGES");
    this.Text("Garage-Category-Restore", "WIEDERHERSTELLEN");
    this.Text("Garage-Category-Explode", "ZERLEGEN");
    this.Text("Garage-Category-Reset", "ZURÜCKS.");
    this.Text("Garage-Category-Checkout", "KASSE");

    this.Text("Garage-Subcategory-Title", "UNTERKATEGORIE WÄHLEN");
    this.Text("Garage-Subcategory-Subtitle", "Wähle einen Teiletyp");
    this.Text("Garage-Subcategory-Hint", "Unterkategorie wählen");

    this.Text("Garage-PaintType-Title", "LACKART WÄHLEN");
    this.Text("Garage-PaintType-Subtitle", "Wähle eine Lackierung");
    this.Text("Garage-PaintType-Hint", "Lackart wählen");
    this.Text("Garage-PaintType-Standard", "Standard");
    this.Text("Garage-PaintType-Metallic", "Metallic");
    this.Text("Garage-PaintType-Matte", "Matt");

    this.Text("Garage-PartsList-Hint", "Teil wählen");
    this.Text("Garage-PartsList-Installed", "EINGEBAUT");
    this.Text("Garage-PartsList-Stock", "SERIE");
    this.Text("Garage-PartsList-Owned", "IM BESITZ");
    this.Text("Garage-PartsList-FactoryOriginal", "Werksoriginal");
    this.Text("Garage-PartsList-PreviouslyPurchased", "Zuvor gekauft");
    this.Text("Garage-PartsList-Aftermarket", "Aftermarket");
    this.Text("Garage-PartsList-Upgrade", "Upgrade");

    this.Text("Garage-Confirm-Title", "KAUF BESTÄTIGEN");
    this.Text("Garage-Confirm-PriceLabel", "PREIS:");
    this.Text("Garage-Confirm-BalanceLabel", "DEINE EDDIES:");
    this.Text("Garage-Confirm-ServiceFee", "Servicegebühr");
    this.Text("Garage-Confirm-Service", "Service");
    this.Text("Garage-Confirm-Equip", "AUSRÜSTEN");
    this.Text("Garage-Confirm-Install", "EINBAUEN");
    this.Text("Garage-Confirm-BuyNow", "KAUFEN");
    this.Text("Garage-Confirm-AddToCart", "HINZUFÜGEN");
    this.Text("Garage-Confirm-Remove", "ENTFERNEN");
    this.Text("Garage-Confirm-Installed", "EINGEBAUT");
    this.Text("Garage-Confirm-CurrentlyEquipped", "Aktuell eingebaut");
    this.Text("Garage-Confirm-Hint", "Bestätigen");

    this.Text("Garage-Checkout-Title", "KASSE");
    this.Text("Garage-Checkout-Subtitle", "Warenkorb prüfen");
    this.Text("Garage-Checkout-PartsLabel", "TEILE:");
    this.Text("Garage-Checkout-ServiceLabel", "SERVICE:");
    this.Text("Garage-Checkout-TotalLabel", "GESAMT:");
    this.Text("Garage-Checkout-BalanceLabel", "DEINE EDDIES:");
    this.Text("Garage-Checkout-EmptyCart", "Dein Warenkorb ist leer");
    this.Text("Garage-Checkout-Cancel", "ABBRECHEN");
    this.Text("Garage-Checkout-Confirm", "BESTÄTIGEN");
    this.Text("Garage-Checkout-CartEmpty", "LEER");
    this.Text("Garage-Checkout-CantAfford", "ZU TEUER");
    this.Text("Garage-Checkout-Hint", "Bestätigen");

    this.Text("Garage-ExitWarning-Title", "VERWERFEN?");
    this.Text("Garage-ExitWarning-YouHave", "Du hast");
    this.Text("Garage-ExitWarning-ItemsWorth", "Artikel im Wert von");
    this.Text("Garage-ExitWarning-NoStay", "BLEIBEN");
    this.Text("Garage-ExitWarning-YesExit", "VERLASSEN");
    this.Text("Garage-ExitWarning-YesDiscard", "JA, VERWERFEN");

    this.Text("Garage-Constraint-Title", "ÄNDERUNG NÖTIG");
    this.Text("Garage-Constraint-DefaultMessage", "Dieses Teil erfordert Änderungen an deinem Warenkorb.");
    this.Text("Garage-Constraint-ReplaceMessage", "Dies ersetzt Artikel in deinem Warenkorb");
    this.Text("Garage-Constraint-AdditionalMessage", "Dieses Teil erfordert zusätzliche Änderungen zum Einbau");
    this.Text("Garage-Constraint-WillUpdate", "Wird aktualisiert:");
    this.Text("Garage-Constraint-Cancel", "ABBRECHEN");
    this.Text("Garage-Constraint-Update", "ÄNDERN");
    this.Text("Garage-Constraint-VirtualSplitMessage", "Dies teilt deinen gruppierten Warenkorbposten.");
    this.Text("Garage-Constraint-SplitAndContinue", "ÄNDERN");
    this.Text("Garage-Constraint-SplitWillPreserve", "Wird einzeln behalten:");

    this.Text("Garage-ChopShop-ClaimVehicle", "FAHRZEUG BEANSPRUCHEN");
    this.Text("Garage-ChopShop-SellVehicle", "FAHRZEUG VERKAUFEN");
    this.Text("Garage-ChopShop-Confirm", "BESTÄTIGEN");

    this.Text("Garage-MapFilter-Garages", "Garagen");

    // ServiceHubScreen
    this.Text("Garage-Hub-Title", "SERVICE WÄHLEN");
    this.Text("Garage-Hub-Subtitle", "Wähle einen Service an diesem Garagenstandort");
    this.Text("Garage-Hub-NoServices", "Keine Services verfügbar");
    this.Text("Garage-Hub-Checkout", "KASSE");

    // CartWidget
    this.Text("Garage-Cart-Header", "WARENKORB");
    this.Text("Garage-Cart-Empty", "Warenkorb ist leer");
    this.Text("Garage-Cart-TotalLabel", "GESAMT:");
    this.Text("Garage-Cart-Clear", "LEEREN");
    this.Text("Garage-Cart-Checkout", "KASSE");

    // UnavailableScreen
    this.Text("Garage-Unavailable-DefaultMessage", "Service nicht verfügbar");

    // ChopShopConfirmScreen
    this.Text("Garage-ChopShop-ClaimPriceLabel", "KAUFPREIS:");
    this.Text("Garage-ChopShop-SellPriceLabel", "VERKAUFSPREIS:");
    this.Text("Garage-ChopShop-ClaimBalanceLabel", "DEINE EDDIES:");
    this.Text("Garage-ChopShop-SellBalanceLabel", "DEINE EDDIES (NACH VERKAUF):");
    this.Text("Garage-ChopShop-TierTooHigh", "FAHRZEUGKLASSE ZU HOCH");
    this.Text("Garage-ChopShop-GarageCantAfford", "GARAGE KANN NICHT BEZAHLEN");
    this.Text("Garage-ChopShop-AlreadyOwned", "BEREITS IN DEINEM BESITZ");
    this.Text("Garage-ChopShop-CannotBeSold", "FAHRZEUG KANN NICHT VERKAUFT WERDEN");
    this.Text("Garage-ChopShop-CannotBeClaimed", "FAHRZEUG KANN NICHT BEANSPRUCHT WERDEN");
    this.Text("Garage-ChopShop-ConditionLabel", "Zustand:");

    // QuickConfirmScreen
    this.Text("Garage-Quick-Title", "SCHNELLSERVICE");
    this.Text("Garage-Quick-AppearanceLabel", "AUSSEHEN:");
    this.Text("Garage-Quick-RushFeeLabel", "EILGEBÜHR:");
    this.Text("Garage-Quick-TotalLabel", "GESAMT:");
    this.Text("Garage-Quick-BalanceLabel", "DEINE EDDIES:");
    this.Text("Garage-Quick-Cancel", "ABBRECHEN");
    this.Text("Garage-Quick-Confirm", "BESTÄTIGEN");

    // RepairConfirmScreen
    this.Text("Garage-Repair-Title", "FAHRZEUGREPARATUR");
    this.Text("Garage-Repair-QuickDesc", "Zustand wiederherstellen und kleinere Schäden beheben");
    this.Text("Garage-Repair-FullDesc", "Vollständige Zustands- und Optikwiederherstellung");
    this.Text("Garage-Repair-BalanceLabel", "DEINE EDDIES:");
    this.Text("Garage-Repair-HeatWarning", "POLIZEIAUFMERKSAMKEIT ERKANNT - Vollreparatur nicht verfügbar");
    this.Text("Garage-Repair-HealthSuffix", "ZUSTAND");
    this.Text("Garage-Repair-NoDamage", "KEIN SCHADEN");
    this.Text("Garage-Repair-Cancel", "ABBRECHEN");

    // PaintScreen
    this.Text("Garage-Paint-Title", "LACK");
    this.Text("Garage-Paint-PriceLabel", "WECHSELPREIS:");
    this.Text("Garage-Paint-AppearanceLabel", "AUSSEHEN:");
    this.Text("Garage-Paint-BalanceLabel", "DEINE EDDIES (NACH KAUF):");
    this.Text("Garage-Paint-NoAppearances", "Keine Designs verfügbar");
    this.Text("Garage-Paint-Owned", "IM BESITZ");
    this.Text("Garage-Paint-Active", "AKTIV");
    this.Text("Garage-Paint-ClaimFirst", "FREMD");
    this.Text("Garage-Paint-Cancel", "ABBRECHEN");
    this.Text("Garage-Paint-Confirm", "BESTÄTIGEN");

    // Service Descriptor Labels
    this.Text("Garage-Desc-Claim", "BEANSPRUCHEN");
    this.Text("Garage-Desc-Sell", "VERKAUFEN");
    this.Text("Garage-Desc-Parts", "TEILE");
    this.Text("Garage-Desc-Quick", "SCHNELL");
    this.Text("Garage-Desc-Repair", "REPARATUR");
    this.Text("Garage-Desc-Swap", "TAUSCH");

    // Unavailable Messages
    this.Text("Garage-Unavailable-QuickTitle", "Schnellservice");
    this.Text("Garage-Unavailable-QuickMessage", "Du hast keine Fahndungsstufe");
    this.Text("Garage-Unavailable-SwapTitle", "Tausch");
    this.Text("Garage-Unavailable-SwapMessage", "Keine gültigen Designs für dieses Fahrzeug verfügbar");
    this.Text("Garage-Unavailable-PartsTitle", "Teile");
    this.Text("Garage-Unavailable-PartsMessage", "Dieses Fahrzeug hat keine Teile");

    // Frame
    this.Text("Garage-Frame-Title", "GARAGE");
    this.Text("Garage-Frame-FluffRight", "TUNING-WERKSTATT");
    this.Text("Garage-Frame-GarageSystem", "GARAGENSYSTEM");

    // Repair (new)
    this.Text("Garage-Repair-BaseLabel", "Basis: ");
    this.Text("Garage-Repair-FeeLabel", "Gebühr: ");
    this.Text("Garage-Repair-TotalLabel", "Gesamt: ");
    this.Text("Garage-Repair-Repairing", "REPARIERE...");
    this.Text("Garage-Repair-QuickPriceLabel", "SCHNELLREPARATUR PREIS:");
    this.Text("Garage-Repair-FullPriceLabel", "VOLLREPARATUR PREIS:");
    this.Text("Garage-Repair-QuickTier", "Schnellreparatur");
    this.Text("Garage-Repair-FullTier", "Vollreparatur");
    this.Text("Garage-Repair-CompleteQuick", "Schnellreparatur abgeschlossen");
    this.Text("Garage-Repair-CompleteFull", "Vollreparatur abgeschlossen");
    this.Text("Garage-Repair-RefundedUnavailable", "Reparatur fehlgeschlagen: Fahrzeug nicht verfügbar. €$%s erstattet.");
    this.Text("Garage-Repair-RefundedAlreadyFixed", "Fahrzeug bereits repariert. €$%s erstattet.");
    this.Text("Garage-Repair-RefundedFailed", "Vollreparatur fehlgeschlagen (%s). €$%s erstattet.");
    this.Text("Garage-Repair-Blocked", "GESPERRT");

    // ChopShop (new)
    this.Text("Garage-ChopShop-BaseLabel", "Basis: ");
    this.Text("Garage-ChopShop-ClaimRateLabel", "Beanspruchungsrate: ");
    this.Text("Garage-ChopShop-VinScrubLabel", "FIN-Bereinigung: ");
    this.Text("Garage-ChopShop-TotalLabel", "Gesamt: ");
    this.Text("Garage-ChopShop-GradeLabel", "Klasse: ");
    this.Text("Garage-ChopShop-RiskLabel", "Risiko: ");
    this.Text("Garage-ChopShop-TypeLabel", "Typ: ");
    this.Text("Garage-ChopShop-FactionLabel", "Fraktion: ");
    this.Text("Garage-ChopShop-SpecialLabel", "Besonderheit: ");
    this.Text("Garage-ChopShop-AppearanceLabel", "Aussehen: ");
    this.Text("Garage-ChopShop-DamageLabel", "Schaden: ");
    this.Text("Garage-ChopShop-TierLabel", "Stufe: ");
    this.Text("Garage-ChopShop-PartsLabel", "Teile: ");

    // Notify
    this.Text("Garage-Notify-UseTerminal", "Nutze das Terminal, um die Anpassung zu starten");
    this.Text("Garage-Notify-NearestGaragePrefix", "Deine nächste CYX-Garage ist ");
    this.Text("Garage-Notify-NearestGarageInfix", " in ");
    this.Text("Garage-Notify-StandUp", "Steh auf, wenn du hier Geschäfte machen willst.");
    this.Text("Garage-Notify-HolsterWeapon", "Steck deine Waffe weg, wenn du Geschäfte machen willst.");
    this.Text("Garage-Notify-HeatTooHigh", "Fahndungsstufe zu hoch. Du bist auf dich allein gestellt!");
    this.Text("Garage-Notify-Banned", "Du wurdest dauerhaft aus dieser Garage verbannt.");
    this.Text("Garage-Sale-NotCleared", "Wir haben das Fahrzeug noch nicht abgewickelt. Wir melden uns, sobald es erledigt ist.");
    this.Text("Garage-Sale-Cancelled", "Verkauf abgebrochen. Du hast in dieser Garage dauerhaft Hausverbot.");
    this.Text("Garage-Sale-FellThrough", "Verkauf von %s geplatzt. Die Garage konnte nicht zahlen. Fahrzeug zurückgegeben.");
    this.Text("Garage-Sale-Cleared", "%s abgewickelt. War nett, mit dir Geschäfte zu machen.");
    this.Text("Garage-Notify-DependencyOutdated", "Die Garage braucht %s %s oder neuer (installiert: %s).");
    this.Text("Garage-Notify-NamesMissing", "Garage nicht verfügbar: Die Datensatznamen des Spiels wurden nicht geladen. Starte das Spiel neu.");
    this.Text("Garage-Notify-LockdownFallback", "Sperrung");
    this.Text("Garage-Notify-ComeBackIn", ". Komm zurück in ");
    this.Text("Garage-Notify-ExitVehicle", "Steig aus deinem Fahrzeug aus, um die Anpassung zu starten.");
    this.Text("Garage-Notify-NoVehicles", "Keine Fahrzeuge in der Nähe. Unsichtbare bearbeiten wir nicht.");
    this.Text("Garage-Notify-BeyondRepair", "Keine Anpassung der Welt kann das retten...");
    this.Text("Garage-Notify-TooDamaged", "Fahrzeug zu stark beschädigt. Erst reparieren.");
    this.Text("Garage-Notify-ParkOnDeckPrefix", "Parke dein Fahrzeug auf der Servicefläche. (");
    this.Text("Garage-Notify-ParkOnDeckSuffix", "m)");
    this.Text("Garage-Notify-UnsupportedVehicle", "Solche Fahrzeuge bearbeiten wir nicht.");
    this.Text("Garage-Notify-TooBig", "Zu groß für diese Garage: %s");
    this.Text("Garage-Notify-TooBigWidth", "Breite %s m (max. %s m)");
    this.Text("Garage-Notify-TooBigLength", "Länge %s m (max. %s m)");
    this.Text("Garage-Notify-TooBigHeight", "Höhe %s m (max. %s m)");

    // Transaction
    this.Text("Garage-Transaction-ClaimInvalid", "Beanspruchung fehlgeschlagen: ungültiges Fahrzeug oder ungültige Daten.");
    this.Text("Garage-Transaction-InsufficientFunds", "Nicht genug Eddies, um dieses Fahrzeug zu beanspruchen.");
    this.Text("Garage-Transaction-DeductFailed", "Transaktion fehlgeschlagen: Eddies konnten nicht abgebucht werden.");
    this.Text("Garage-Transaction-UnlockFailed", "Beanspruchung fehlgeschlagen: Fahrzeug konnte nicht freigeschaltet werden. Erstattung erfolgt.");
    this.Text("Garage-Transaction-ClaimSuccess", "Beansprucht");
    this.Text("Garage-Transaction-InsufficientFundsState", "Nicht genug Eddies");
    this.Text("Garage-Transaction-ClaimFailedState", "Beanspruchung fehlgeschlagen");

    // Map
    this.Text("Garage-Map-ClosedSuffix", "(Geschlossen)");
    this.Text("Garage-Map-BannedIndefinitely", "Dauerhaft gesperrt");
    this.Text("Garage-Map-LockedDown", "Gesperrt");
    this.Text("Garage-Map-SalePending", "Verkauf ausstehend");
    this.Text("Garage-Map-Cooldown", "Abklingzeit");

    // Quick (new)
    this.Text("Garage-Quick-HeatTooHigh", "Fahndungsstufe zu hoch");
    this.Text("Garage-Quick-PostPurchase", "Aussehen geändert");

    // Miscellaneous
    this.Text("Garage-Format-StandardAppearance", "Standard");
    this.Text("Garage-PartsList-PagePrefix", "Seite ");
    this.Text("Garage-PartsList-PageSeparator", "/");
    this.Text("Garage-PartsList-DefaultOption", "Standardoption");
    this.Text("Garage-PartsList-NoCustomization", "Keine Anpassung verfügbar");

    // Confirm (new)
    this.Text("Garage-Confirm-PartNamePlaceholder", "Teilename");
    this.Text("Garage-Confirm-PartDescPlaceholder", "Teilebeschreibung hier");

    // HUD
    this.Text("Garage-HUD-Cash", "Bargeld");
    this.Text("Garage-HUD-Tier", "Stufe");
    this.Text("Garage-HUD-CountdownHeader", "SCHNELLSERVICE");
    this.Text("Garage-HUD-CountdownTime", "Zeit");
    this.Text("Garage-HUD-ExitVehicle", "Fahrzeug verlassen");

    // Tier Display Names
    this.Text("Garage-Tier-Standard", "Standard");
    this.Text("Garage-Tier-Classic", "Klassik");
    this.Text("Garage-Tier-Sport", "Sport");
    this.Text("Garage-Tier-Premium", "Premium");
    this.Text("Garage-Tier-Exotic", "Exotisch");
    this.Text("Garage-Tier-Hyper", "Hyper");
    this.Text("Garage-Tier-Economy", "Wirtschaft");

    // Notifications (Lua)
    this.Text("Garage-Notify-ClaimLockdown", "Zu langsam. Diese Garage ist für 24 Stunden gesperrt.");
    this.Text("Garage-Notify-InsufficientFunds", "Nicht genug Eddies!");
    this.Text("Garage-Notify-TransactionFailed", "Transaktion fehlgeschlagen!");
    this.Text("Garage-Notify-HeatCleared", "Fahndung gelöscht. Komm nicht so bald wieder.");
    this.Text("Garage-Notify-PaidGetOut", "€$%s bezahlt, jetzt verschwinde!");
    this.Text("Garage-Notify-NoVehicleDetected", "Kein Fahrzeug erkannt");
    this.Text("Garage-Notify-NoSchemaFound", "Kein Schema gefunden");
    this.Text("Garage-Notify-NoPaintColors", "Keine Lackfarben verfügbar");
    this.Text("Garage-Notify-NoCustomization", "Keine Anpassung verfügbar");
    this.Text("Garage-Notify-RestoreToStock", "AUF SERIE ZURÜCKSETZEN");
    this.Text("Garage-Notify-RimColorAll", "Felgenfarbe (Alle)");
    this.Text("Garage-Notify-WheelsAll", "Räder (Alle)");
    this.Text("Garage-Notify-SinglePartPurchased", "1 Teil für €$%s gekauft");
    this.Text("Garage-Notify-MultiPartPurchased", "%d Teile für €$%s gekauft");
    this.Text("Garage-Notify-RepairService", "Reparaturservice: €$%s");
    this.Text("Garage-Notify-ServiceDone", "%s - €$%s");
    this.Text("Garage-Notify-ServiceDetail", "%s: %s");
    this.Text("Garage-Notify-DesignApplied", "Design übernommen");
    this.Text("Garage-Notify-TierBlocked", "Diese Garage kann diese Fahrzeugklasse nicht bedienen");
  }
}
