module Garage.ChopShop

import Garage.*
import Garage.Data.*
import Garage.Economy.*
import Garage.Services.*
import Garage.UI.*
import Garage.Vehicle.*
import VehicleCore.Schema.*

public class ChopShopAddon extends GarageAddon {
  public func Id() -> CName { return n"chopshop"; }
  public func IsEnabled(settings: ref<GarageSettings>) -> Bool { return settings.chopShopEnabled; }

  public func Services() -> array<ref<GarageService>> {
    let list: array<ref<GarageService>>;
    ArrayPush(list, new ClaimService());
    ArrayPush(list, new SellService());
    return list;
  }

  public func RegisterScreens(screens: ref<ScreenManager>, frame: ref<GarageFrame>) -> Void {
    let screen: ref<ChopShopScreen> = new ChopShopScreen();
    screen.CreateInstance();
    frame.AddScreen(screen);
    screens.RegisterScreen(n"chopshop_confirm", screen);
  }
}

public class ClaimService extends GarageService {
  public func Id() -> CName { return n"claim"; }
  public func Label() -> String { return GarageText.Get(n"Garage-Desc-Claim"); }
  public func Priority() -> Int32 { return 10; }
  public func IsMuted(ctx: ref<GarageContext>) -> Bool { return StrLen(ChopShopDeal.Refusal(ctx, true)) > 0; }
  public func Open(ctx: ref<GarageContext>) -> Void { ChopShopDeal.Open(ctx, true); }
}

public class SellService extends GarageService {
  public func Id() -> CName { return n"sell"; }
  public func Label() -> String { return GarageText.Get(n"Garage-Desc-Sell"); }
  public func Priority() -> Int32 { return 50; }
  public func IsMuted(ctx: ref<GarageContext>) -> Bool { return StrLen(ChopShopDeal.Refusal(ctx, false)) > 0; }
  public func Open(ctx: ref<GarageContext>) -> Void { ChopShopDeal.Open(ctx, false); }
}

public abstract class ChopShopDeal {
  public static func Open(ctx: ref<GarageContext>, claiming: Bool) -> Void {
    let manager: ref<ScreenManager> = ctx.screens;
    let screen: ref<ChopShopScreen> = manager.GetScreen(n"chopshop_confirm") as ChopShopScreen;
    if !IsDefined(screen) { return; }
    screen.SetMode(claiming);
    manager.ShowScreen(n"chopshop_confirm");
  }

  public static func Tier() -> CName {
    let schema: ref<VehicleSchema> = GarageSystem.Get().Parts().Schema();
    return IsDefined(schema) ? schema.tier : n"";
  }

  public static func ClaimQuote(ctx: ref<GarageContext>) -> ref<GarageClaimQuote> {
    let vehicle: wref<VehicleObject> = ctx.vehicle;
    return GarageSystem.Get().Pricing().QuoteClaim(ctx.vehicleRecord, vehicle.GetCurrentAppearanceName(), ChopShopDeal.Tier());
  }

  public static func SaleQuote(ctx: ref<GarageContext>) -> ref<GarageSaleQuote> {
    let vehicle: wref<VehicleObject> = ctx.vehicle;
    let system: ref<GarageSystem> = GarageSystem.Get();
    return system.Pricing().QuoteSale(ctx.vehicleRecord, vehicle.GetCurrentAppearanceName(), ChopShopDeal.Tier(), GarageVehicles.HealthShown(vehicle), system.Parts().InstalledValue());
  }

  /// Why this deal's off, "" if it isn't. Being short on eddies for a claim isn't one, the screen still shows the price.
  public static func Refusal(ctx: ref<GarageContext>, claiming: Bool) -> String {
    let vehicle: wref<VehicleObject> = ctx.vehicle;
    if !IsDefined(vehicle) { return GarageText.Get(n"Garage-Unavailable-DefaultMessage"); }
    let system: ref<GarageSystem> = GarageSystem.Get();
    let pricing: ref<GaragePricing> = system.Pricing();
    let engine: ref<EconomyEngine> = EconomyEngine.Get();
    if claiming {
      if ctx.isOwned { return GarageText.Get(n"Garage-ChopShop-AlreadyOwned"); }
      if !pricing.CanClaim(ctx.vehicleRecord) { return GarageText.Get(n"Garage-ChopShop-CannotBeClaimed"); }
    } else {
      if !pricing.CanSell(ctx.vehicleRecord) { return GarageText.Get(n"Garage-ChopShop-CannotBeSold"); }
    }
    let settings: ref<GarageSettings> = GarageSettings.Get();
    if IsDefined(settings) && settings.chopShopBlockAnyHeat && system.Xu().State().Get(XUtilsStateField.WantedLevel) > 0 {
      return GarageText.Get(n"Garage-ChopShop-HeatBlocked");
    }
    if engine.IsVehicleClassBlocked(ctx.locationId, ChopShopDeal.Tier()) { return GarageText.Get(n"Garage-ChopShop-TierTooHigh"); }
    if !claiming {
      let quote: ref<GarageSaleQuote> = ChopShopDeal.SaleQuote(ctx);
      if quote.total <= 0 { return GarageText.Get(n"Garage-ChopShop-CannotBeSold"); }
      if !engine.CanAfford(ctx.locationId, quote.total) { return GarageText.Get(n"Garage-ChopShop-GarageCantAfford"); }
    }
    return "";
  }
}

public class ChopShopScreen extends GarageConfirmScreen {
  private let m_claiming: Bool;

  public func SetMode(claiming: Bool) -> Void { this.m_claiming = claiming; }

  protected func Fill() -> Void {
    let ctx: ref<GarageContext> = GarageSystem.Get().Parts().Context();
    this.SetTitle(GarageText.Get(this.m_claiming ? n"Garage-ChopShop-ClaimVehicle" : n"Garage-ChopShop-SellVehicle"));
    this.SetCar(ctx.vehicleDisplayName);
    let vehicle: wref<VehicleObject> = ctx.vehicle;
    if !this.m_claiming && IsDefined(vehicle) {
      let health: Float = GarageVehicles.HealthShown(vehicle);
      this.SetStatus(GarageText.Get(n"Garage-ChopShop-ConditionLabel") + " " + IntToString(RoundF(health * 100.0)) + "%", this.ConditionTint(health));
    }
    let refusal: String = ChopShopDeal.Refusal(ctx, this.m_claiming);
    if StrLen(refusal) > 0 {
      this.Refuse(refusal);
      return;
    }
    let balance: Int32 = GarageTransactions.Balance();
    if this.m_claiming {
      let claim: ref<GarageClaimQuote> = ChopShopDeal.ClaimQuote(ctx);
      this.SetPrice(GarageText.Get(n"Garage-ChopShop-ClaimPriceLabel"), claim.total, this.ClaimLines(claim));
      this.SetBalance(GarageText.Get(n"Garage-ChopShop-ClaimBalanceLabel"), balance, balance >= claim.total);
      this.SetCanConfirm(balance >= claim.total);
    } else {
      let sale: ref<GarageSaleQuote> = ChopShopDeal.SaleQuote(ctx);
      this.SetPrice(GarageText.Get(n"Garage-ChopShop-SellPriceLabel"), sale.total, this.SaleLines(sale));
      this.SetBalance(GarageText.Get(n"Garage-ChopShop-SellBalanceLabel"), balance + sale.total, true);
    }
  }

  private func ClaimLines(quote: ref<GarageClaimQuote>) -> String {
    let lines: String = this.AmountLine(n"Garage-ChopShop-BaseLabel", "", quote.base);
    lines += "\n" + this.TimesLine(n"Garage-ChopShop-ClaimRateLabel", quote.rate);
    lines += "\n" + this.AmountLine(n"Garage-ChopShop-VinScrubLabel", "+", quote.scrub);
    if quote.scrubMultiplier != 1.0 { lines += " (x" + FloatToStringPrec(quote.scrubMultiplier, 2) + ")"; }
    if quote.market != 1.0 { lines += "\n" + this.TimesLine(n"Garage-ChopShop-MarketLabel", quote.market); }
    lines += "\n" + this.AmountLine(n"Garage-ChopShop-TotalLabel", "", quote.total);
    return lines;
  }

  private func SaleLines(quote: ref<GarageSaleQuote>) -> String {
    let lines: String = this.AmountLine(n"Garage-ChopShop-BaseLabel", "", quote.base);
    if quote.risk != 1.0 { lines += "\n" + this.TimesLine(n"Garage-ChopShop-RiskLabel", quote.risk); }
    if quote.appearance != 1.0 { lines += "\n" + this.TimesLine(n"Garage-ChopShop-AppearanceLabel", quote.appearance); }
    if quote.grade != 1.0 { lines += "\n" + this.TimesLine(n"Garage-ChopShop-GradeLabel", quote.grade); }
    if quote.type != 1.0 { lines += "\n" + this.TimesLine(n"Garage-ChopShop-TypeLabel", quote.type); }
    if quote.special != 1.0 { lines += "\n" + this.TimesLine(n"Garage-ChopShop-SpecialLabel", quote.special); }
    if quote.parts > 0 { lines += "\n" + this.AmountLine(n"Garage-ChopShop-PartsLabel", "+", quote.parts); }
    if quote.condition < 1.0 { lines += "\n" + this.TimesLine(n"Garage-ChopShop-DamageLabel", quote.condition); }
    lines += "\n" + this.TimesLine(n"Garage-ChopShop-TierLabel", quote.tier);
    if quote.market != 1.0 { lines += "\n" + this.TimesLine(n"Garage-ChopShop-MarketLabel", quote.market); }
    return lines;
  }

  private func AmountLine(key: CName, sign: String, amount: Int32) -> String {
    return GarageText.Get(key) + sign + GarageText.Price(amount);
  }

  private func TimesLine(key: CName, value: Float) -> String {
    return GarageText.Get(key) + "x" + FloatToStringPrec(value, 2);
  }

  protected func OnConfirmed() -> Void {
    let ctx: ref<GarageContext> = GarageSystem.Get().Parts().Context();
    // The pool can have moved since this was drawn
    if StrLen(ChopShopDeal.Refusal(ctx, this.m_claiming)) > 0 {
      this.Refresh();
      return;
    }
    if this.m_claiming {
      this.Claim(ctx);
    } else {
      this.Sell(ctx);
    }
  }

  private func Claim(ctx: ref<GarageContext>) -> Void {
    let vehicle: wref<VehicleObject> = ctx.vehicle;
    let system: ref<GarageSystem> = GarageSystem.Get();
    let xu: ref<XUtilsMod> = system.Xu();
    let quote: ref<GarageClaimQuote> = ChopShopDeal.ClaimQuote(ctx);
    let price: Int32 = quote.total;
    let receipt: ref<GarageReceipt> = this.Charge(ctx.locationId, price, EGarageTxKind.Claim, n"chopshop");
    if !IsDefined(receipt) { return; }
    if !GarageVehicles.Unlock(ctx.vehicleRecord, vehicle.GetCurrentAppearanceName()) {
      GarageTransactions.Refund(receipt);
      xu.Screen().Notify(GarageText.Get(n"Garage-Transaction-UnlockFailed"), SimpleMessageType.Negative, 4.0, true);
      this.Refresh();
      return;
    }
    xu.Screen().Notify(GarageText.Format(n"Garage-Transaction-ClaimSuccess", [ctx.vehicleDisplayName, GarageText.Price(price)]), SimpleMessageType.Money, 5.0, true);
    let location: ref<GarageLocation> = system.Data().GetLocation(ctx.locationId);
    if IsDefined(location) {
      let deck: Vector4 = location.deck.Position();
      system.ClaimTimer().Start(ctx.vehicleRecord, deck, ctx.locationId);
    }
    EconomyEngine.Get().LockGarage(ctx.locationId, GarageLocks.Day(), GarageLockReason.Cooldown());
    this.Trigger(n"OnClosePopup");
  }

  // The pool pays when the sale clears, so a theft or a drained pool costs nobody anything
  private func Sell(ctx: ref<GarageContext>) -> Void {
    let vehicle: wref<VehicleObject> = ctx.vehicle;
    let system: ref<GarageSystem> = GarageSystem.Get();
    let quote: ref<GarageSaleQuote> = ChopShopDeal.SaleQuote(ctx);
    system.Sales().Start(ctx.vehicleRecord, quote.total, ctx.vehicleDisplayName, ctx.locationId, vehicle.GetEntityID(), ChopShopDeal.Tier());
    let ps: ref<VehicleComponentPS> = vehicle.GetVehiclePS();
    if IsDefined(ps) { ps.LockAllVehDoors(); }
    vehicle.TurnEngineOn(false);
    system.Xu().Screen().Notify(GarageText.Format(n"Garage-Sale-Started", [ctx.vehicleDisplayName]), SimpleMessageType.Money, 4.0, true);
    this.Trigger(n"OnClosePopup");
  }
}
