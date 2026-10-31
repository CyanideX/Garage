module Garage.Localization
import Codeware.Localization.*

public class GarageKorean extends ModLocalizationPackage {
  protected func DefineTexts() -> Void {
    this.Text("Garage-Prompt-Enter", "차고 들어가기");
    this.Text("Garage-Map-Description", "차량 서비스");

    this.Text("Garage-Category-Title", "카테고리 선택");
    this.Text("Garage-Category-Subtitle", "튜닝 카테고리를 선택하여 사용 가능한 부품을 둘러보세요");
    this.Text("Garage-Category-Hint", "카테고리 선택");
    this.Text("Garage-Category-Body", "바디");
    this.Text("Garage-Category-Interior", "실내");
    this.Text("Garage-Category-Paint", "도장");
    this.Text("Garage-Category-Wheels", "휠");
    this.Text("Garage-Category-Misc", "기타");
    this.Text("Garage-Category-Restore", "리스토어");
    this.Text("Garage-Category-Explode", "분해 보기");
    this.Text("Garage-Category-Reset", "초기화");
    this.Text("Garage-Category-Checkout", "결제");

    this.Text("Garage-Subcategory-Title", "하위 카테고리 선택");
    this.Text("Garage-Subcategory-Subtitle", "부품 유형을 선택하세요");
    this.Text("Garage-Subcategory-Hint", "하위 카테고리 선택");

    this.Text("Garage-PaintType-Title", "도장 유형 선택");
    this.Text("Garage-PaintType-Subtitle", "도장 마감을 선택하세요");
    this.Text("Garage-PaintType-Hint", "도장 유형 선택");
    this.Text("Garage-PaintType-Standard", "기본");
    this.Text("Garage-PaintType-Metallic", "메탈릭");
    this.Text("Garage-PaintType-Matte", "매트");

    this.Text("Garage-PartsList-Hint", "부품 선택");
    this.Text("Garage-PartsList-Installed", "장착됨");
    this.Text("Garage-PartsList-Stock", "순정");
    this.Text("Garage-PartsList-Owned", "보유");
    this.Text("Garage-PartsList-FactoryOriginal", "공장 출고");
    this.Text("Garage-PartsList-PreviouslyPurchased", "이전 구매");
    this.Text("Garage-PartsList-Aftermarket", "애프터마켓");
    this.Text("Garage-PartsList-Upgrade", "업그레이드");

    this.Text("Garage-Confirm-Title", "구매 확인");
    this.Text("Garage-Confirm-PriceLabel", "가격:");
    this.Text("Garage-Confirm-BalanceLabel", "보유 에디:");
    this.Text("Garage-Confirm-ServiceFee", "서비스 수수료");
    this.Text("Garage-Confirm-Service", "인건비");
    this.Text("Garage-Confirm-Equip", "장착");
    this.Text("Garage-Confirm-Install", "설치");
    this.Text("Garage-Confirm-BuyNow", "즉시 구매");
    this.Text("Garage-Confirm-AddToCart", "장바구니에 추가");
    this.Text("Garage-Confirm-Remove", "제거");
    this.Text("Garage-Confirm-Installed", "장착됨");
    this.Text("Garage-Confirm-CurrentlyEquipped", "현재 장착됨");
    this.Text("Garage-Confirm-Hint", "확인");

    this.Text("Garage-Checkout-Title", "결제");
    this.Text("Garage-Checkout-Subtitle", "구매 전 장바구니를 확인하세요");
    this.Text("Garage-Checkout-PartsLabel", "부품:");
    this.Text("Garage-Checkout-ServiceLabel", "인건비:");
    this.Text("Garage-Checkout-TotalLabel", "합계:");
    this.Text("Garage-Checkout-BalanceLabel", "보유 에디:");
    this.Text("Garage-Checkout-EmptyCart", "장바구니가 비어 있습니다");
    this.Text("Garage-Checkout-Cancel", "취소");
    this.Text("Garage-Checkout-Confirm", "확인");
    this.Text("Garage-Checkout-CartEmpty", "장바구니 비어 있음");
    this.Text("Garage-Checkout-CantAfford", "잔액 부족");
    this.Text("Garage-Checkout-Hint", "확인");

    this.Text("Garage-ExitWarning-Title", "장바구니를 버리시겠습니까?");
    this.Text("Garage-ExitWarning-YouHave", "장바구니에");
    this.Text("Garage-ExitWarning-ItemsWorth", "개 항목, 가치");
    this.Text("Garage-ExitWarning-NoStay", "아니오, 머물기");
    this.Text("Garage-ExitWarning-YesExit", "예, 나가기");
    this.Text("Garage-ExitWarning-YesDiscard", "예, 버리기");

    this.Text("Garage-Constraint-Title", "장바구니 업데이트 필요");
    this.Text("Garage-Constraint-DefaultMessage", "이 부품은 장바구니 변경이 필요합니다.");
    this.Text("Garage-Constraint-ReplaceMessage", "장바구니의 항목이 교체됩니다");
    this.Text("Garage-Constraint-AdditionalMessage", "이 부품을 설치하려면 추가 변경이 필요합니다");
    this.Text("Garage-Constraint-WillUpdate", "업데이트 대상:");
    this.Text("Garage-Constraint-Cancel", "취소");
    this.Text("Garage-Constraint-Update", "업데이트");
    this.Text("Garage-Constraint-VirtualSplitMessage", "이 항목을 추가하면 그룹 장바구니 항목이 분리됩니다.");
    this.Text("Garage-Constraint-SplitAndContinue", "업데이트");
    this.Text("Garage-Constraint-SplitWillPreserve", "개별 유지:");

    this.Text("Garage-ChopShop-ClaimVehicle", "차량 인수");
    this.Text("Garage-ChopShop-SellVehicle", "차량 판매");
    this.Text("Garage-ChopShop-Confirm", "확인");

    this.Text("Garage-MapFilter-Garages", "차고");

    // ServiceHubScreen
    this.Text("Garage-Hub-Title", "서비스 선택");
    this.Text("Garage-Hub-Subtitle", "이 차고에서 이용할 서비스를 선택하세요");
    this.Text("Garage-Hub-NoServices", "이용 가능한 서비스 없음");
    this.Text("Garage-Hub-Checkout", "결제");

    // CartWidget
    this.Text("Garage-Cart-Header", "장바구니");
    this.Text("Garage-Cart-Empty", "장바구니가 비어 있습니다");
    this.Text("Garage-Cart-TotalLabel", "합계:");
    this.Text("Garage-Cart-Clear", "비우기");
    this.Text("Garage-Cart-Checkout", "결제");

    // UnavailableScreen
    this.Text("Garage-Unavailable-DefaultMessage", "서비스를 이용할 수 없습니다");

    // ChopShopConfirmScreen
    this.Text("Garage-ChopShop-ClaimPriceLabel", "인수 가격:");
    this.Text("Garage-ChopShop-SellPriceLabel", "판매 가격:");
    this.Text("Garage-ChopShop-ClaimBalanceLabel", "보유 에디:");
    this.Text("Garage-ChopShop-SellBalanceLabel", "보유 에디 (판매 후):");
    this.Text("Garage-ChopShop-TierTooHigh", "차량 등급이 너무 높음");
    this.Text("Garage-ChopShop-GarageCantAfford", "차고 잔액 부족");
    this.Text("Garage-ChopShop-AlreadyOwned", "이미 보유 중인 차량");
    this.Text("Garage-ChopShop-CannotBeSold", "판매할 수 없는 차량");
    this.Text("Garage-ChopShop-CannotBeClaimed", "인수할 수 없는 차량");
    this.Text("Garage-ChopShop-ConditionLabel", "상태:");

    // QuickConfirmScreen
    this.Text("Garage-Quick-Title", "빠른 서비스");
    this.Text("Garage-Quick-AppearanceLabel", "외형:");
    this.Text("Garage-Quick-RushFeeLabel", "긴급 수수료:");
    this.Text("Garage-Quick-TotalLabel", "합계:");
    this.Text("Garage-Quick-BalanceLabel", "보유 에디:");
    this.Text("Garage-Quick-Cancel", "취소");
    this.Text("Garage-Quick-Confirm", "확인");

    // RepairConfirmScreen
    this.Text("Garage-Repair-Title", "차량 수리");
    this.Text("Garage-Repair-QuickDesc", "체력을 회복하고 경미한 손상을 수리합니다");
    this.Text("Garage-Repair-FullDesc", "체력과 외형을 완전히 복원합니다");
    this.Text("Garage-Repair-BalanceLabel", "보유 에디:");
    this.Text("Garage-Repair-HeatWarning", "경찰 주의 감지됨 - 완전 수리 불가");
    this.Text("Garage-Repair-HealthSuffix", "체력");
    this.Text("Garage-Repair-NoDamage", "손상 없음");
    this.Text("Garage-Repair-Cancel", "취소");

    // PaintScreen
    this.Text("Garage-Paint-Title", "도장");
    this.Text("Garage-Paint-PriceLabel", "교환 가격:");
    this.Text("Garage-Paint-AppearanceLabel", "외형:");
    this.Text("Garage-Paint-BalanceLabel", "보유 에디 (구매 후):");
    this.Text("Garage-Paint-NoAppearances", "이용 가능한 외형 없음");
    this.Text("Garage-Paint-Owned", "보유 중");
    this.Text("Garage-Paint-Active", "활성");
    this.Text("Garage-Paint-ClaimFirst", "미등록");
    this.Text("Garage-Paint-Cancel", "취소");
    this.Text("Garage-Paint-Confirm", "확인");

    // Service Descriptor Labels
    this.Text("Garage-Desc-Claim", "인수");
    this.Text("Garage-Desc-Sell", "판매");
    this.Text("Garage-Desc-Parts", "부품");
    this.Text("Garage-Desc-Quick", "빠른 서비스");
    this.Text("Garage-Desc-Repair", "수리");
    this.Text("Garage-Desc-Swap", "교환");

    // Unavailable Messages
    this.Text("Garage-Unavailable-QuickTitle", "빠른 서비스");
    this.Text("Garage-Unavailable-QuickMessage", "수배 단계가 없습니다");
    this.Text("Garage-Unavailable-SwapTitle", "교환");
    this.Text("Garage-Unavailable-SwapMessage", "이 차량에 사용 가능한 외형이 없습니다");
    this.Text("Garage-Unavailable-PartsTitle", "부품");
    this.Text("Garage-Unavailable-PartsMessage", "이 차량에는 부품이 없습니다");

    // Frame
    this.Text("Garage-Frame-Title", "차고");
    this.Text("Garage-Frame-FluffRight", "튜닝 공방");
    this.Text("Garage-Frame-GarageSystem", "차고 시스템");

    // Repair (breakdown labels)
    this.Text("Garage-Repair-BaseLabel", "기본: ");
    this.Text("Garage-Repair-FeeLabel", "수수료: ");
    this.Text("Garage-Repair-TotalLabel", "합계: ");
    this.Text("Garage-Repair-Repairing", "수리 중...");
    this.Text("Garage-Repair-QuickPriceLabel", "빠른 수리 가격:");
    this.Text("Garage-Repair-FullPriceLabel", "완전 수리 가격:");
    this.Text("Garage-Repair-QuickTier", "빠른 수리");
    this.Text("Garage-Repair-FullTier", "완전 수리");
    this.Text("Garage-Repair-CompleteQuick", "빠른 수리 완료");
    this.Text("Garage-Repair-CompleteFull", "완전 수리 완료");
    this.Text("Garage-Repair-RefundedUnavailable", "수리 실패: 차량을 사용할 수 없습니다. €$%s 환불되었습니다.");
    this.Text("Garage-Repair-RefundedAlreadyFixed", "차량이 이미 수리되었습니다. €$%s 환불되었습니다.");
    this.Text("Garage-Repair-RefundedFailed", "완전 수리 실패 (%s). €$%s 환불되었습니다.");
    this.Text("Garage-Repair-Blocked", "차단됨");

    // ChopShop (breakdown labels)
    this.Text("Garage-ChopShop-BaseLabel", "기본: ");
    this.Text("Garage-ChopShop-ClaimRateLabel", "인수율: ");
    this.Text("Garage-ChopShop-VinScrubLabel", "차대번호 세척: ");
    this.Text("Garage-ChopShop-TotalLabel", "합계: ");
    this.Text("Garage-ChopShop-GradeLabel", "등급: ");
    this.Text("Garage-ChopShop-RiskLabel", "위험도: ");
    this.Text("Garage-ChopShop-TypeLabel", "유형: ");
    this.Text("Garage-ChopShop-FactionLabel", "세력: ");
    this.Text("Garage-ChopShop-SpecialLabel", "특수: ");
    this.Text("Garage-ChopShop-AppearanceLabel", "외형: ");
    this.Text("Garage-ChopShop-DamageLabel", "손상: ");
    this.Text("Garage-ChopShop-TierLabel", "등급: ");
    this.Text("Garage-ChopShop-PartsLabel", "부품: ");

    // Notify
    this.Text("Garage-Notify-UseTerminal", "터미널에 접근하여 커스터마이징을 시작하세요");
    this.Text("Garage-Notify-NearestGaragePrefix", "가장 가까운 CYX 차고: ");
    this.Text("Garage-Notify-NearestGarageInfix", ", 위치: ");
    this.Text("Garage-Notify-StandUp", "거래하려면 일어서세요.");
    this.Text("Garage-Notify-HolsterWeapon", "거래하려면 무기를 넣으세요.");
    this.Text("Garage-Notify-HeatTooHigh", "수배 단계가 너무 높음. 니 알아서 하세요~");
    this.Text("Garage-Notify-Banned", "이 차고에서 영구 차단되었습니다.");
    this.Text("Garage-Notify-DependencyOutdated", "차고를 이용하려면 %s %s 이상이 필요합니다 (설치됨: %s).");
    this.Text("Garage-Notify-NamesMissing", "차고를 사용할 수 없습니다: 게임 레코드 이름을 불러오지 못했습니다. 게임을 다시 시작하세요.");
    this.Text("Garage-Notify-LockdownFallback", "봉쇄");
    this.Text("Garage-Notify-ComeBackIn", ". 다시 오세요: ");
    this.Text("Garage-Notify-ExitVehicle", "커스터마이징을 시작하려면 차에서 내리세요.");
    this.Text("Garage-Notify-NoVehicles", "근처에 차량이 없습니다. 투명 차량은 취급하지 않습니다.");
    this.Text("Garage-Notify-BeyondRepair", "어떤 작업으로도 고칠 수 없습니다...");
    this.Text("Garage-Notify-TooDamaged", "차량 손상이 너무 심합니다. 먼저 수리하세요.");
    this.Text("Garage-Notify-ParkOnDeckPrefix", "서비스 구역에 차량을 주차하세요. (");
    this.Text("Garage-Notify-ParkOnDeckSuffix", "m)");
    this.Text("Garage-Notify-UnsupportedVehicle", "이런 차량은 취급하지 않습니다.");
    this.Text("Garage-Notify-TooBig", "이 차고에 들어가기엔 차량이 너무 큽니다: %s");
    this.Text("Garage-Notify-TooBigWidth", "폭 %s m (최대 %s m)");
    this.Text("Garage-Notify-TooBigLength", "길이 %s m (최대 %s m)");
    this.Text("Garage-Notify-TooBigHeight", "높이 %s m (최대 %s m)");

    // Transaction
    this.Text("Garage-Transaction-ClaimInvalid", "인수 실패: 잘못된 차량 또는 데이터.");
    this.Text("Garage-Transaction-InsufficientFunds", "이 차량을 인수할 자금이 부족합니다.");
    this.Text("Garage-Transaction-DeductFailed", "거래 실패: 자금을 차감할 수 없습니다.");
    this.Text("Garage-Transaction-UnlockFailed", "인수 실패: 차량 잠금을 해제할 수 없습니다. 환불되었습니다.");
    this.Text("Garage-Transaction-ClaimSuccess", "인수 완료");
    this.Text("Garage-Transaction-InsufficientFundsState", "잔액 부족");
    this.Text("Garage-Transaction-ClaimFailedState", "인수 실패");

    // Map
    this.Text("Garage-Map-ClosedSuffix", "(폐쇄)");
    this.Text("Garage-Map-BannedIndefinitely", "무기한 차단");
    this.Text("Garage-Map-LockedDown", "봉쇄됨");
    this.Text("Garage-Map-SalePending", "판매 대기 중");
    this.Text("Garage-Map-Cooldown", "대기 시간");

    // Quick (notifications)
    this.Text("Garage-Quick-HeatTooHigh", "수배 단계가 너무 높음");
    this.Text("Garage-Quick-PostPurchase", "외형이 변경되었습니다");

    // Miscellaneous
    this.Text("Garage-Format-StandardAppearance", "기본");
    this.Text("Garage-PartsList-PagePrefix", "페이지 ");
    this.Text("Garage-PartsList-PageSeparator", "/");
    this.Text("Garage-PartsList-DefaultOption", "기본 옵션");
    this.Text("Garage-PartsList-NoCustomization", "커스터마이징 불가");

    // Confirm (placeholders)
    this.Text("Garage-Confirm-PartNamePlaceholder", "부품명");
    this.Text("Garage-Confirm-PartDescPlaceholder", "부품 설명");

    // HUD
    this.Text("Garage-HUD-Cash", "현금");
    this.Text("Garage-HUD-Tier", "등급");
    this.Text("Garage-HUD-CountdownHeader", "빠른 서비스");
    this.Text("Garage-HUD-CountdownTime", "시간");
    this.Text("Garage-HUD-ExitVehicle", "차에서 내리세요");

    // Tier Display Names
    this.Text("Garage-Tier-Standard", "기본");
    this.Text("Garage-Tier-Classic", "클래식");
    this.Text("Garage-Tier-Sport", "스포츠");
    this.Text("Garage-Tier-Premium", "프리미엄");
    this.Text("Garage-Tier-Exotic", "희귀한");
    this.Text("Garage-Tier-Hyper", "하이퍼");
    this.Text("Garage-Tier-Economy", "보급형");

    // Notifications (Lua)
    this.Text("Garage-Notify-ClaimLockdown", "너무 느려. 이 차고는 24시간 동안 잠김");
    this.Text("Garage-Notify-InsufficientFunds", "잔액 부족!");
    this.Text("Garage-Notify-TransactionFailed", "거래 실패!");
    this.Text("Garage-Notify-HeatCleared", "수배레벨 해제 완료. 당분간 오지 마");
    this.Text("Garage-Notify-PaidGetOut", "€$%s 지불 완료, 이제 꺼져!");
    this.Text("Garage-Notify-NoVehicleDetected", "감지된 차량 없음");
    this.Text("Garage-Notify-NoSchemaFound", "요청한 데이터 구조 정의가 존재하지 않음");
    this.Text("Garage-Notify-NoPaintColors", "사용 가능한 도장 색상 없음");
    this.Text("Garage-Notify-NoCustomization", "사용 가능한 커스터마이징 없음");
    this.Text("Garage-Notify-RestoreToStock", "순정으로 복원");
    this.Text("Garage-Notify-RimColorAll", "림 색상 (전체)");
    this.Text("Garage-Notify-WheelsAll", "휠 (전체)");
    this.Text("Garage-Notify-SinglePartPurchased", "1개 부품 €$%s에 구매");
    this.Text("Garage-Notify-MultiPartPurchased", "%d개 부품 €$%s에 구매");
    this.Text("Garage-Notify-RepairService", "수리 서비스: €$%s");
    this.Text("Garage-Notify-ServiceDone", "%s - €$%s");
    this.Text("Garage-Notify-ServiceDetail", "%s: %s");
    this.Text("Garage-Notify-DesignApplied", "디자인 적용 완료");
    this.Text("Garage-Notify-TierBlocked", "이 차고에서는 이 차량 등급을 정비할 수 없습니다");
  }
}
