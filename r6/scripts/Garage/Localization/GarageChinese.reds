module Garage.Localization
import Codeware.Localization.*

public class GarageChinese extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    this.Text("Garage-Prompt-Enter", "进入车库");
    this.Text("Garage-Map-Description", "车辆服务");

    this.Text("Garage-Category-Title", "选择类别");
    this.Text("Garage-Category-Subtitle", "选择调校类别以浏览可用零件");
    this.Text("Garage-Hint-Select", "选择");
    this.Text("Garage-Category-Body", "车身");
    this.Text("Garage-Category-Interior", "内饰");
    this.Text("Garage-Category-Paint", "喷漆");
    this.Text("Garage-Category-Wheels", "轮毂");
    this.Text("Garage-Category-Misc", "其他");
    this.Text("Garage-Category-Restore", "恢复");
    this.Text("Garage-Category-Explode", "爆炸视图");
    this.Text("Garage-Category-Reset", "重置");
    this.Text("Garage-Category-Checkout", "结账");

    this.Text("Garage-Subcategory-Title", "选择子类别");
    this.Text("Garage-Subcategory-Subtitle", "选择零件类型");

    this.Text("Garage-PaintType-Title", "选择喷漆类型");
    this.Text("Garage-PaintType-Subtitle", "选择漆面效果");
    this.Text("Garage-PaintType-Standard", "标准");
    this.Text("Garage-PaintType-Metallic", "金属漆");
    this.Text("Garage-PaintType-Matte", "哑光");

    this.Text("Garage-PartsList-Installed", "已安装");
    this.Text("Garage-PartsList-Stock", "原厂");
    this.Text("Garage-PartsList-Owned", "已拥有");
    this.Text("Garage-PartsList-FactoryOriginal", "原厂出厂");
    this.Text("Garage-PartsList-PreviouslyPurchased", "之前已购买");
    this.Text("Garage-PartsList-Aftermarket", "改装件");
    this.Text("Garage-PartsList-Upgrade", "升级");

    this.Text("Garage-Confirm-Title", "确认购买");
    this.Text("Garage-Confirm-PriceLabel", "价格：");
    this.Text("Garage-Confirm-BalanceLabel", "你的艾迪：");
    this.Text("Garage-Confirm-ServiceFee", "服务费");
    this.Text("Garage-Confirm-Service", "工时");
    this.Text("Garage-Confirm-Required", "必需部件");
    this.Text("Garage-Confirm-Equip", "装备");
    this.Text("Garage-Confirm-Install", "安装");
    this.Text("Garage-Confirm-BuyNow", "立即购买");
    this.Text("Garage-Confirm-AddToCart", "加入购物车");
    this.Text("Garage-Confirm-Remove", "移除");
    this.Text("Garage-Confirm-Installed", "已安装");
    this.Text("Garage-Confirm-CurrentlyEquipped", "当前已装备");
    this.Text("Garage-Confirm-Hint", "确认");

    this.Text("Garage-Checkout-Title", "结账");
    this.Text("Garage-Checkout-Subtitle", "购买前请确认购物车");
    this.Text("Garage-Checkout-PartsLabel", "零件：");
    this.Text("Garage-Checkout-ServiceLabel", "工时：");
    this.Text("Garage-Checkout-TotalLabel", "总计：");
    this.Text("Garage-Checkout-BalanceLabel", "你的艾迪：");
    this.Text("Garage-Checkout-EmptyCart", "购物车为空");
    this.Text("Garage-Checkout-Cancel", "取消");
    this.Text("Garage-Checkout-Confirm", "确认");
    this.Text("Garage-Checkout-CartEmpty", "购物车为空");
    this.Text("Garage-Checkout-CantAfford", "余额不足");
    this.Text("Garage-Checkout-Hint", "确认");

    this.Text("Garage-ExitWarning-Title", "放弃购物车？");
    this.Text("Garage-ExitWarning-YouHave", "你有");
    this.Text("Garage-ExitWarning-ItemsWorth", "件商品，价值");
    this.Text("Garage-ExitWarning-NoStay", "不，留下");
    this.Text("Garage-ExitWarning-YesExit", "是，离开");
    this.Text("Garage-ExitWarning-YesDiscard", "是，放弃");

    this.Text("Garage-Constraint-Title", "需要更新购物车");
    this.Text("Garage-Constraint-DefaultMessage", "此零件需要更改购物车内容。");
    this.Text("Garage-Constraint-ReplaceMessage", "这将替换购物车中的商品");
    this.Text("Garage-Constraint-AdditionalMessage", "安装此零件需要额外更改");
    this.Text("Garage-Constraint-WillUpdate", "将更新：");
    this.Text("Garage-Constraint-Cancel", "取消");
    this.Text("Garage-Constraint-Update", "更新");
    this.Text("Garage-Constraint-VirtualSplitMessage", "添加此项将拆分已分组的购物车条目。");
    this.Text("Garage-Constraint-SplitAndContinue", "更新");
    this.Text("Garage-Constraint-SplitWillPreserve", "将单独保留：");

    this.Text("Garage-ChopShop-ClaimVehicle", "认领车辆");
    this.Text("Garage-ChopShop-SellVehicle", "出售车辆");
    this.Text("Garage-ChopShop-Confirm", "确认");

    this.Text("Garage-MapFilter-Garages", "车库");

    // ServiceHubScreen
    this.Text("Garage-Hub-Title", "选择服务");
    this.Text("Garage-Hub-Subtitle", "选择此车库提供的服务");
    this.Text("Garage-Hub-NoServices", "暂无可用服务");
    this.Text("Garage-Hub-Checkout", "结账");

    // CartWidget
    this.Text("Garage-Cart-Header", "购物车");
    this.Text("Garage-Cart-Empty", "购物车为空");
    this.Text("Garage-Cart-TotalLabel", "总计：");
    this.Text("Garage-Cart-Clear", "清空");
    this.Text("Garage-Cart-Checkout", "结账");

    // UnavailableScreen
    this.Text("Garage-Unavailable-DefaultMessage", "服务不可用");

    // ChopShopConfirmScreen
    this.Text("Garage-ChopShop-ClaimPriceLabel", "认领价格：");
    this.Text("Garage-ChopShop-SellPriceLabel", "出售价格：");
    this.Text("Garage-ChopShop-ClaimBalanceLabel", "你的艾迪：");
    this.Text("Garage-ChopShop-SellBalanceLabel", "你的艾迪（出售后）：");
    this.Text("Garage-ChopShop-TierTooHigh", "车辆等级过高");
    this.Text("Garage-ChopShop-GarageCantAfford", "车库余额不足");
    this.Text("Garage-ChopShop-AlreadyOwned", "已在名下");
    this.Text("Garage-ChopShop-CannotBeSold", "该车辆无法出售");
    this.Text("Garage-ChopShop-CannotBeClaimed", "该车辆无法认领");
    this.Text("Garage-ChopShop-OneOfAKind", "独一无二，不予出售");
    this.Text("Garage-ChopShop-HeatBlocked", "被通缉时无法交易");
    this.Text("Garage-ChopShop-ConditionLabel", "状况：");

    // QuickConfirmScreen
    this.Text("Garage-Quick-Title", "快速服务");
    this.Text("Garage-Quick-AppearanceLabel", "外观：");
    this.Text("Garage-Quick-RushFeeLabel", "加急费：");
    this.Text("Garage-Quick-TotalLabel", "总计：");
    this.Text("Garage-Quick-BalanceLabel", "你的艾迪：");
    this.Text("Garage-Quick-Cancel", "取消");
    this.Text("Garage-Quick-Confirm", "确认");

    // RepairConfirmScreen
    this.Text("Garage-Repair-Title", "维修车辆");
    this.Text("Garage-Repair-QuickDesc", "恢复耐久并修复轻微损伤");
    this.Text("Garage-Repair-FullDesc", "完整恢复耐久及外观");
    this.Text("Garage-Repair-BalanceLabel", "你的艾迪：");
    this.Text("Garage-Repair-HeatWarning", "检测到警察追捕 - 完整维修不可用");
    this.Text("Garage-Repair-HealthSuffix", "耐久");
    this.Text("Garage-Repair-NoDamage", "无损伤");
    this.Text("Garage-Repair-Cancel", "取消");

    // PaintScreen
    this.Text("Garage-Paint-Title", "喷漆");
    this.Text("Garage-Paint-PriceLabel", "更换价格：");
    this.Text("Garage-Paint-AppearanceLabel", "外观：");
    this.Text("Garage-Paint-BalanceLabel", "你的艾迪（购买后）：");
    this.Text("Garage-Paint-NoAppearances", "暂无可用外观");
    this.Text("Garage-Paint-Owned", "已拥有");
    this.Text("Garage-Paint-Active", "已启用");
    this.Text("Garage-Paint-ClaimFirst", "未拥有");
    this.Text("Garage-Paint-ClaimToSwap", "认领车辆后才能更换外观");
    this.Text("Garage-Paint-LookNotSaved", "此车辆的外观无法保存");
    this.Text("Garage-Repair-ClaimForFull", "认领车辆后才能完整修复");
    this.Text("Garage-Paint-OneOfAKind", "独一无二，外观不可更改");
    this.Text("Garage-Paint-Cancel", "取消");
    this.Text("Garage-Paint-Confirm", "确认");

    // Service Descriptor Labels
    this.Text("Garage-Desc-Claim", "认领");
    this.Text("Garage-Desc-Sell", "出售");
    this.Text("Garage-Desc-Parts", "零件");
    this.Text("Garage-Desc-Quick", "快速");
    this.Text("Garage-Desc-Repair", "维修");
    this.Text("Garage-Desc-Swap", "更换");

    // Unavailable Messages
    this.Text("Garage-Unavailable-QuickTitle", "快速服务");
    this.Text("Garage-Unavailable-QuickMessage", "你没有通缉等级");
    this.Text("Garage-Unavailable-SwapTitle", "更换");
    this.Text("Garage-Unavailable-SwapMessage", "该车辆没有可用外观");
    this.Text("Garage-Unavailable-PartsTitle", "零件");
    this.Text("Garage-Unavailable-PartsMessage", "该车辆没有可用零件");

    // Frame
    this.Text("Garage-Frame-Title", "车库");
    this.Text("Garage-Frame-FluffRight", "改装工坊");
    this.Text("Garage-Frame-GarageSystem", "车库系统");

    // Repair (breakdown labels)
    this.Text("Garage-Repair-BaseLabel", "基础：");
    this.Text("Garage-Repair-FeeLabel", "手续费：");
    this.Text("Garage-Repair-TotalLabel", "总计：");
    this.Text("Garage-Repair-Repairing", "维修中...");
    this.Text("Garage-Repair-QuickPriceLabel", "快速修复价格:");
    this.Text("Garage-Repair-FullPriceLabel", "完整修复价格:");
    this.Text("Garage-Repair-QuickTier", "快速修复");
    this.Text("Garage-Repair-FullTier", "完整修复");
    this.Text("Garage-Repair-CompleteQuick", "快速修复完成");
    this.Text("Garage-Repair-CompleteFull", "完整修复完成");
    this.Text("Garage-Repair-RefundedUnavailable", "修复失败：车辆不可用。已退款 €$%s。");
    this.Text("Garage-Repair-RefundedAlreadyFixed", "车辆已修复。已退款 €$%s。");
    this.Text("Garage-Repair-RefundedFailed", "完整修复失败（%s）。已退款 €$%s。");
    this.Text("Garage-Repair-Blocked", "已拦截");

    // ChopShop (breakdown labels)
    this.Text("Garage-ChopShop-BaseLabel", "基础：");
    this.Text("Garage-ChopShop-ClaimRateLabel", "认领费率：");
    this.Text("Garage-ChopShop-VinScrubLabel", "VIN 清洗：");
    this.Text("Garage-ChopShop-TotalLabel", "总计：");
    this.Text("Garage-ChopShop-GradeLabel", "品级：");
    this.Text("Garage-ChopShop-RiskLabel", "风险：");
    this.Text("Garage-ChopShop-TypeLabel", "类型：");
    this.Text("Garage-ChopShop-FactionLabel", "势力：");
    this.Text("Garage-ChopShop-SpecialLabel", "特殊：");
    this.Text("Garage-ChopShop-AppearanceLabel", "外观：");
    this.Text("Garage-ChopShop-DamageLabel", "损伤：");
    this.Text("Garage-ChopShop-TierLabel", "等级：");
    this.Text("Garage-ChopShop-MarketLabel", "市场：");
    this.Text("Garage-ChopShop-PartsLabel", "零件：");
    this.Text("Garage-ChopShop-SaleFloorLabel", "售价下限：");
    this.Text("Garage-Price-LoyaltyLabel", "忠诚折扣：");
    this.Text("Garage-Price-RateLabel", "车库费率：");

    // Notify
    this.Text("Garage-Notify-UseTerminal", "靠近车辆开始改装");
    this.Text("Garage-Notify-NearestGaragePrefix", "你最近的 CYX 车库在 ");
    this.Text("Garage-Notify-NearestGarageInfix", "，位于 ");
    this.Text("Garage-Notify-StandUp", "想做生意就站起来。");
    this.Text("Garage-Notify-HolsterWeapon", "想做生意就收起武器。");
    this.Text("Garage-Notify-HeatTooHigh", "通缉等级太高，你自生自灭吧！");
    this.Text("Garage-Notify-Banned", "你已被该车库永久封禁。");
    this.Text("Garage-Sale-NotCleared", "车辆还没处理完。处理好后我们会联系你。");
    this.Text("Garage-Sale-Cancelled", "交易取消。你已被该车库永久封禁。");
    this.Text("Garage-Sale-FellThrough", "%s 的交易告吹。车库付不起这笔钱，车辆已退还。");
    this.Text("Garage-Sale-Cleared", "%s 已处理完毕。合作愉快。");
    this.Text("Garage-Sale-Started", "等 %s 的手续办妥，我们就把钱打给你。");
    this.Text("Garage-Notify-DependencyOutdated", "车库需要 %s %s 或更高版本（已安装：%s）。");
    this.Text("Garage-Notify-NamesMissing", "车库不可用：游戏记录名称加载失败。请重启游戏。");
    this.Text("Garage-Notify-LockdownFallback", "封锁");
    this.Text("Garage-Notify-ComeBackIn", "。请在 ");
    this.Text("Garage-Notify-ExitVehicle", "下车后开始改装。");
    this.Text("Garage-Notify-NoVehicles", "附近没有车辆。我们不接隐形车。");
    this.Text("Garage-Notify-BeyondRepair", "这车改装也救不了...");
    this.Text("Garage-Notify-TooDamaged", "车辆损伤过重，请先维修。");
    this.Text("Garage-Notify-ParkOnDeckPrefix", "请将车辆停在服务区。（");
    this.Text("Garage-Notify-ParkOnDeckSuffix", "m）");
    this.Text("Garage-Notify-UnsupportedVehicle", "我们不接这类车辆。");
    this.Text("Garage-Notify-TooBig", "车辆超出此车库的尺寸限制：%s");
    this.Text("Garage-Notify-TooBigWidth", "宽度 %s 米（上限 %s 米）");
    this.Text("Garage-Notify-TooBigLength", "长度 %s 米（上限 %s 米）");
    this.Text("Garage-Notify-TooBigHeight", "高度 %s 米（上限 %s 米）");

    // Transaction
    this.Text("Garage-Transaction-ClaimInvalid", "认领失败：车辆或数据无效。");
    this.Text("Garage-Transaction-InsufficientFunds", "艾迪不足，无法认领该车辆。");
    this.Text("Garage-Transaction-DeductFailed", "交易失败：无法扣除艾迪。");
    this.Text("Garage-Transaction-UnlockFailed", "认领失败：无法解锁车辆，已退款。");
    this.Text("Garage-Transaction-ClaimSuccess", "已认领 %s，花费 €$%s。");
    this.Text("Garage-Transaction-InsufficientFundsState", "余额不足");
    this.Text("Garage-Transaction-ClaimFailedState", "认领失败");

    // Map
    this.Text("Garage-Map-ClosedSuffix", "（已关闭）");
    this.Text("Garage-Map-BannedIndefinitely", "永久封禁");
    this.Text("Garage-Map-LockedDown", "已封锁");
    this.Text("Garage-Map-SalePending", "待售");
    this.Text("Garage-Map-Cooldown", "冷却中");

    // Quick (notifications)
    this.Text("Garage-Quick-HeatTooHigh", "通缉等级太高");
    this.Text("Garage-Quick-AlreadyPaid", "已经付过了，快走！");
    this.Text("Garage-Quick-PostPurchase", "外观已更改");

    // Miscellaneous
    this.Text("Garage-Format-StandardAppearance", "标准");
    this.Text("Garage-PartsList-PagePrefix", "第 ");
    this.Text("Garage-PartsList-PageSeparator", "/");
    this.Text("Garage-PartsList-DefaultOption", "默认选项");
    this.Text("Garage-PartsList-NoCustomization", "无可用改装");

    // Confirm (placeholders)
    this.Text("Garage-Confirm-PartNamePlaceholder", "零件名称");
    this.Text("Garage-Confirm-PartDescPlaceholder", "零件描述");

    // HUD
    this.Text("Garage-HUD-Cash", "现金");
    this.Text("Garage-HUD-Tier", "等级");
    this.Text("Garage-HUD-CountdownHeader", "快速服务");
    this.Text("Garage-HUD-CountdownTime", "时间");
    this.Text("Garage-HUD-ExitVehicle", "请下车");

    // Tier Display Names
    this.Text("Garage-Tier-Standard", "标准");
    this.Text("Garage-Tier-Classic", "经典");
    this.Text("Garage-Tier-Sport", "运动");
    this.Text("Garage-Tier-Premium", "豪华");
    this.Text("Garage-Tier-Exotic", "超豪华");
    this.Text("Garage-Tier-Hyper", "极限");
    this.Text("Garage-Tier-Economy", "经济");

    // Notifications (Lua)
    this.Text("Garage-Notify-ClaimLockdown", "太慢了。该车库已封锁 24 小时。");
    this.Text("Garage-Notify-InsufficientFunds", "艾迪不足！");
    this.Text("Garage-Notify-TransactionFailed", "交易失败！");
    this.Text("Garage-Notify-HeatCleared", "通缉已清除。别这么快回来。");
    this.Text("Garage-Notify-PaidGetOut", "已支付 €$%s，现在滚吧！");
    this.Text("Garage-Notify-NoVehicleDetected", "未检测到车辆");
    this.Text("Garage-Notify-NoSchemaFound", "未找到数据结构");
    this.Text("Garage-Notify-NoPaintColors", "无可用喷漆颜色");
    this.Text("Garage-Notify-NoCustomization", "无可用改装");
    this.Text("Garage-Notify-RestoreToStock", "恢复原厂");
    this.Text("Garage-Notify-RimColorAll", "轮毂颜色（全部）");
    this.Text("Garage-Notify-WheelsAll", "轮毂（全部）");
    this.Text("Garage-Notify-SinglePartPurchased", "已购买 1 件零件，花费 €$%s");
    this.Text("Garage-Notify-MultiPartPurchased", "已购买 %d 件零件，花费 €$%s");
    this.Text("Garage-Notify-RepairService", "维修服务：€$%s");
    this.Text("Garage-Notify-ServiceDone", "%s - €$%s");
    this.Text("Garage-Notify-ServiceDetail", "%s：%s");
    this.Text("Garage-Notify-DesignApplied", "外观已应用");
    this.Text("Garage-Paint-RefundedFailed", "无法更改外观。已退款 €$%s。");
    this.Text("Garage-Notify-TierBlocked", "该车库无法服务此等级车辆");
  }
}
