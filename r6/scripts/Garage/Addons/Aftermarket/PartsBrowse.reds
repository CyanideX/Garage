module Garage.Aftermarket

import Codeware.UI.*
import Garage.*
import Garage.Scene.*
import Garage.UI.*
import Garage.Vehicle.*

/// A button that knows what it stands for and tells its screen.
public class PartsButton extends SimpleButton {
  public let id: CName;
  public let info: ref<GarageCategoryInfo>;
  private let m_owner: wref<AftermarketScreen>;

  public static func Make(owner: ref<AftermarketScreen>, width: Float, parent: ref<inkCompoundWidget>) -> ref<PartsButton> {
    let btn: ref<PartsButton> = new PartsButton();
    btn.m_owner = owner;
    btn.CreateInstance();
    btn.SetWidth(width);
    btn.ToggleAnimations(true);
    btn.ToggleSounds(true);
    btn.Reparent(parent);
    btn.RegisterToCallback(n"OnBtnClick", btn, n"OnPicked");
    return btn;
  }

  protected cb func OnPicked(widget: wref<inkWidget>) -> Bool {
    let owner: ref<AftermarketScreen> = this.m_owner;
    if IsDefined(owner) { owner.OnPartsButtonClick(this.id); }
    return false;
  }

  protected cb func OnHoverOver(evt: ref<inkPointerEvent>) {
    super.OnHoverOver(evt);
    let owner: ref<AftermarketScreen> = this.m_owner;
    if IsDefined(owner) { owner.OnPartsButtonHover(this.id); }
  }
}

public class CategoryScreen extends AftermarketScreen {
  private let m_buttons: wref<inkVerticalPanel>;
  private let m_sectionButtons: array<ref<PartsButton>>;
  private let m_checkoutRow: wref<inkHorizontalPanel>;
  private let m_checkoutBtn: wref<SimpleButton>;
  private let m_explodeBtn: wref<SimpleButton>;
  private let m_isExploded: Bool;

  protected cb func OnCreate() {
    super.OnCreate();
    let root: ref<inkCanvas> = this.GetRootWidget() as inkCanvas;
    this.CreateTitle(root, GarageText.Get(n"Garage-Category-Title"), 60.0);
    this.CreateSubtitle(root, GarageText.Get(n"Garage-Category-Subtitle"), 32, 120.0);

    let buttons: ref<inkVerticalPanel> = new inkVerticalPanel();
    buttons.SetName(n"buttonContainer");
    buttons.SetAnchor(inkEAnchor.TopCenter);
    buttons.SetAnchorPoint(new Vector2(0.5, 0.0));
    buttons.SetMargin(new inkMargin(0.0, 200.0, 0.0, 0.0));
    buttons.SetChildMargin(new inkMargin(0.0, 10.0, 0.0, 10.0));
    buttons.Reparent(root);
    this.m_buttons = buttons;

    let checkoutRow: ref<inkHorizontalPanel> = this.CreateBottomRow(root, n"checkoutRow", 1);
    checkoutRow.SetVisible(false);
    this.m_checkoutRow = checkoutRow;
    this.m_checkoutBtn = this.CreateStandardButton(n"checkoutBtn", "", 700.0, checkoutRow, n"OnCheckoutClick");

    let actionRow: ref<inkHorizontalPanel> = this.CreateBottomRow(root, n"actionRow", 0);
    this.CreateStandardButton(n"restoreBtn", GarageText.Get(n"Garage-Category-Restore"), 340.0, actionRow, n"OnRestoreClick");
    this.m_explodeBtn = this.CreateStandardButton(n"explodeBtn", GarageText.Get(n"Garage-Category-Explode"), 340.0, actionRow, n"OnExplodeClick");
    this.BuildButtons();
  }

  public func Show() {
    super.Show();
    this.m_flow.LeaveSlot();
    this.UpdateCheckoutButton();
    this.UpdateHint(n"click", GarageText.Get(n"Garage-Hint-Select"), true);
  }

  // Nothing else has an Explode button, so the car can't be left exploded once we're gone
  public func Hide() {
    super.Hide();
    this.RemoveHint(n"click");
    if this.m_isExploded { this.SetExploded(false); }
  }

  public func WarnsOnBack() -> Bool { return true; }

  public func RefreshAfterCartChange() -> Void { this.UpdateCheckoutButton(); }

  // Modded cars don't all have every section, and an empty one only leads to an empty list.
  // Built here since the visit's car is known by now, and a button made once we're on screen gets no click sound.
  // A lone button in the last row sits centered
  private func BuildButtons() -> Void {
    let sections: array<CName> = [n"body", n"interior", n"paint", n"wheels", n"misc"];
    let keys: array<CName> = [n"Garage-Category-Body", n"Garage-Category-Interior", n"Garage-Category-Paint", n"Garage-Category-Wheels", n"Garage-Category-Misc"];
    let parts: ref<GarageParts> = this.Parts();
    let row: ref<inkHorizontalPanel>;
    let placed: Int32 = 0;
    let i: Int32 = 0;
    while i < ArraySize(sections) {
      let categories: array<ref<GarageCategoryInfo>> = parts.CategoriesIn(sections[i]);
      if ArraySize(categories) > 0 {
        if placed % 2 == 0 {
          row = new inkHorizontalPanel();
          row.SetHAlign(inkEHorizontalAlign.Center);
          row.SetChildMargin(new inkMargin(10.0, 0.0, 10.0, 0.0));
          row.Reparent(this.m_buttons);
        }
        let btn: ref<PartsButton> = PartsButton.Make(this, 300.0, row);
        btn.id = sections[i];
        SetButtonText(btn, GarageText.Get(keys[i]));
        ArrayPush(this.m_sectionButtons, btn);
        placed += 1;
      }
      i += 1;
    }
  }

  private func UpdateCheckoutButton() -> Void {
    let cart: ref<GarageCart> = this.Parts().Cart();
    this.m_checkoutRow.SetVisible(cart.Count() > 0);
    if cart.Count() > 0 {
      SetButtonText(this.m_checkoutBtn, FormatCheckoutLabel(GarageText.Get(n"Garage-Category-Checkout"), cart.Count(), cart.Total()));
    }
  }

  public func OnPartsButtonClick(id: CName) -> Void { this.m_flow.OpenSection(id); }

  protected cb func OnExplodeClick(widget: wref<inkWidget>) -> Bool {
    this.SetExploded(!this.m_isExploded);
    return false;
  }

  private func SetExploded(exploded: Bool) -> Void {
    let vehicle: wref<VehicleObject> = this.Vehicle();
    if !IsDefined(vehicle) { return; }
    if exploded {
      VehicleStateHelper.ExplodeView(vehicle);
      SetButtonText(this.m_explodeBtn, GarageText.Get(n"Garage-Category-Reset"));
      GarageSystem.Get().Scene().Explode();
    } else {
      VehicleStateHelper.ResetView(vehicle);
      SetButtonText(this.m_explodeBtn, GarageText.Get(n"Garage-Category-Explode"));
    }
    this.m_isExploded = exploded;
  }

  protected cb func OnCheckoutClick(widget: wref<inkWidget>) -> Bool {
    this.m_flow.Show(n"parts_checkout");
    return false;
  }

  protected cb func OnRestoreClick(widget: wref<inkWidget>) -> Bool {
    this.Parts().AddAllStockToCart();
    this.m_garageFrame.TriggerCartChanged();
    this.m_flow.Show(n"parts_checkout");
    return false;
  }
}

public class SubcategoryScreen extends AftermarketScreen {
  private let m_shown: array<ref<PartsButton>>;
  private let m_categories: array<ref<GarageCategoryInfo>>;
  private let m_section: CName;
  private let m_pagination: ref<PaginationHelper>;

  protected cb func OnCreate() {
    super.OnCreate();
    let root: ref<inkCanvas> = this.GetRootWidget() as inkCanvas;
    this.CreateBackButton(root);
    this.CreateTitle(root, GarageText.Get(n"Garage-Subcategory-Title"), 60.0);
    this.CreateSubtitle(root, GarageText.Get(n"Garage-Subcategory-Subtitle"), 24, 100.0);
    let column: ref<inkVerticalPanel> = this.CreateColumn(root, n"buttonContainer");
    this.m_pagination = this.CreatePagination(root, 5);
    let i: Int32 = 0;
    while i < this.m_pagination.GetItemsPerPage() {
      ArrayPush(this.m_shown, PartsButton.Make(this, 600.0, column));
      i += 1;
    }
  }

  public func Show() {
    super.Show();
    this.m_flow.LeaveSlot();
    this.m_flow.ForgetHover();
    this.UpdateHint(n"click", GarageText.Get(n"Garage-Hint-Select"), true);
    if !Equals(this.m_flow.section, this.m_section) {
      this.m_pagination.SetCurrentPage(0);
      this.m_section = this.m_flow.section;
      this.m_categories = this.Parts().CategoriesIn(this.m_section);
    }
    this.DisplayCurrentPage();
  }

  public func Hide() {
    super.Hide();
    this.RemoveHint(n"click");
  }

  private func DisplayCurrentPage() -> Void {
    this.m_pagination.SetTotalItems(ArraySize(this.m_categories));
    let start: Int32 = this.m_pagination.GetStartIndex();
    let end: Int32 = this.m_pagination.GetEndIndex();
    let i: Int32 = 0;
    while i < ArraySize(this.m_shown) {
      let btn: ref<PartsButton> = this.m_shown[i];
      if start + i < end {
        btn.info = this.m_categories[start + i];
        btn.id = btn.info.id;
        SetButtonText(btn, btn.info.name);
        btn.GetRootWidget().SetVisible(true);
      } else {
        btn.GetRootWidget().SetVisible(false);
      }
      i += 1;
    }
    this.m_pagination.UpdateWidgets();
  }

  public func NextPage() -> Void {
    if this.m_pagination.NextPage() { this.DisplayCurrentPage(); }
  }

  public func PrevPage() -> Void {
    if this.m_pagination.PrevPage() { this.DisplayCurrentPage(); }
  }

  public func OnPartsButtonHover(id: CName) -> Void { this.m_flow.Hover(id); }

  public func OnPartsButtonClick(id: CName) -> Void {
    for btn in this.m_shown {
      if Equals(btn.id, id) {
        this.m_flow.OpenSlot(btn.info);
        return;
      }
    }
  }
}

public class PaintTypeScreen extends AftermarketScreen {
  protected cb func OnCreate() {
    super.OnCreate();
    let root: ref<inkCanvas> = this.GetRootWidget() as inkCanvas;
    this.CreateBackButton(root);
    this.CreateTitle(root, GarageText.Get(n"Garage-PaintType-Title"), 60.0);
    this.CreateSubtitle(root, GarageText.Get(n"Garage-PaintType-Subtitle"), 24, 100.0);
    let buttons: ref<inkVerticalPanel> = this.CreateColumn(root, n"buttonContainer");
    this.CreateStandardButton(n"standardBtn", GarageText.Get(n"Garage-PaintType-Standard"), 600.0, buttons, n"OnStandardClick");
    this.CreateStandardButton(n"metallicBtn", GarageText.Get(n"Garage-PaintType-Metallic"), 600.0, buttons, n"OnMetallicClick");
    this.CreateStandardButton(n"matteBtn", GarageText.Get(n"Garage-PaintType-Matte"), 600.0, buttons, n"OnMatteClick");
  }

  public func Show() {
    super.Show();
    this.UpdateHint(n"click", GarageText.Get(n"Garage-Hint-Select"), true);
  }

  public func Hide() {
    super.Hide();
    this.RemoveHint(n"click");
  }

  protected cb func OnStandardClick(widget: wref<inkWidget>) -> Bool {
    this.m_flow.OpenFinish(n"standard");
    return false;
  }

  protected cb func OnMetallicClick(widget: wref<inkWidget>) -> Bool {
    this.m_flow.OpenFinish(n"metallic");
    return false;
  }

  protected cb func OnMatteClick(widget: wref<inkWidget>) -> Bool {
    this.m_flow.OpenFinish(n"matte");
    return false;
  }
}

/// One row on the parts list. The widgets stay, a new page only rebinds them.
public class PartRow extends inkCustomController {
  private let m_owner: wref<PartsListScreen>;
  private let m_row: ref<GaragePartRow>;
  private let m_swatch: wref<inkImage>;
  private let m_button: ref<SimpleButton>;
  private let m_warningBg: wref<inkImage>;
  private let m_warningIcon: wref<inkImage>;
  private let m_cartHolder: wref<inkHorizontalPanel>;
  private let m_cartIcon: wref<inkImage>;
  private let m_badge: wref<inkText>;
  private let m_priceRow: wref<inkHorizontalPanel>;
  private let m_priceIcon: wref<inkImage>;
  private let m_priceText: wref<inkText>;
  private let m_width: Float;
  private let m_swatchReady: Bool;
  private let m_warningReady: Bool;
  private let m_cartReady: Bool;
  private let m_priceReady: Bool;

  public func SetOwner(owner: ref<PartsListScreen>) -> Void { this.m_owner = owner; }

  protected cb func OnCreate() {
    let row: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    row.SetName(n"partRow");
    row.SetChildMargin(new inkMargin(10.0, 0.0, 10.0, 0.0));
    row.SetVisible(false);
    this.SetRootWidget(row);

    let swatch: ref<inkImage> = new inkImage();
    swatch.SetName(n"colorSwatch");
    swatch.SetSize(new Vector2(36.0, 98.0));
    swatch.SetScale(new Vector2(0.66, 1.0));
    swatch.SetFitToContent(false);
    swatch.SetVAlign(inkEVerticalAlign.Center);
    swatch.SetMargin(new inkMargin(0.0, 0.0, -24.0, 0.0));
    swatch.SetVisible(false);
    swatch.Reparent(row);
    this.m_swatch = swatch;

    this.m_button = SimpleButton.Create();
    this.m_button.ToggleAnimations(true);
    this.m_button.ToggleSounds(true);
    this.m_button.Reparent(row);
    this.m_button.RegisterToCallback(n"OnBtnClick", this, n"OnClick");
    this.CreateWarning();

    let holder: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    holder.SetName(n"cartIconContainer");
    holder.SetMargin(new inkMargin(20.0, 18.0, 0.0, 0.0));
    holder.SetVisible(false);
    holder.Reparent(row);
    this.m_cartHolder = holder;
    let cartIcon: ref<inkImage> = new inkImage();
    cartIcon.SetName(n"cartIcon");
    cartIcon.SetSize(new Vector2(50.0, 50.0));
    cartIcon.SetFitToContent(true);
    cartIcon.SetScale(new Vector2(0.82, 0.82));
    cartIcon.SetMargin(new inkMargin(40.0, -10.0, 0.0, 0.0));
    cartIcon.SetTintColor(GarageColors.Gold());
    cartIcon.SetVAlign(inkEVerticalAlign.Top);
    cartIcon.Reparent(holder);
    this.m_cartIcon = cartIcon;

    let badge: ref<inkText> = PartsLabel(n"status", "", n"Bold", 36, GarageColors.Blue(), row);
    badge.SetMargin(new inkMargin(20.0, 18.0, 0.0, 0.0));
    badge.SetVisible(false);
    this.m_badge = badge;

    let priceRow: ref<inkHorizontalPanel> = new inkHorizontalPanel();
    priceRow.SetName(n"priceRow");
    priceRow.SetMargin(new inkMargin(20.0, 18.0, 0.0, 0.0));
    priceRow.SetVisible(false);
    priceRow.Reparent(row);
    this.m_priceRow = priceRow;
    let priceIcon: ref<inkImage> = CreateMoneyIconForFont(36, 0.5, GarageColors.Gold());
    priceIcon.SetMargin(new inkMargin(0.0, -38.0, 30.0, 0.0));
    priceIcon.Reparent(priceRow);
    this.m_priceIcon = priceIcon;
    this.m_priceText = PartsLabel(n"priceText", "", n"Bold", 36, GarageColors.Gold(), priceRow);
  }

  // Sits between the button's own background and its hover fill, so turning it off leaves the button as it was
  private func CreateWarning() -> Void {
    let root: ref<inkCompoundWidget> = this.m_button.GetRootWidget() as inkCompoundWidget;
    let bg: ref<inkImage> = new inkImage();
    bg.SetName(n"constraintBg");
    bg.SetAnchor(inkEAnchor.Fill);
    bg.SetNineSliceScale(true);
    bg.SetNineSliceGrid(new inkMargin(0.0, 0.0, 10.0, 0.0));
    bg.SetTintColor(new HDRColor(0.191, 0.117, 0.059, 1.0));
    bg.SetOpacity(0.8);
    bg.SetVisible(false);
    bg.Reparent(root);
    root.ReorderChild(bg, 1);
    this.m_warningBg = bg;

    let icon: ref<inkImage> = new inkImage();
    icon.SetName(n"constraintWarning");
    icon.SetSize(new Vector2(32.0, 32.0));
    icon.SetFitToContent(true);
    icon.SetScale(new Vector2(0.8, 0.8));
    icon.SetTintColor(new HDRColor(0.749, 0.514, 0.078, 1.0));
    icon.SetMargin(new inkMargin(22.0, 22.0, 0.0, 0.0));
    icon.SetVisible(false);
    icon.Reparent(root);
    this.m_warningIcon = icon;
  }

  public func Bind(row: ref<GaragePartRow>, isColor: Bool) -> Void {
    this.m_row = row;
    this.GetRootWidget().SetVisible(true);
    this.SetColorMode(isColor);
    if isColor { this.m_swatch.SetTintColor(row.part.tint); }
    this.m_button.SetDisabled(false);
    this.SetLabel(row.part.name);
    this.SetWarning(row.forcesOthers);
    if Equals(row.badge, EGaragePartBadge.Installed) {
      this.ShowBadge(n"Garage-PartsList-Installed", GarageColors.Cyan());
    } else if Equals(row.badge, EGaragePartBadge.Stock) {
      this.ShowBadge(n"Garage-PartsList-Stock", GarageColors.Blue());
    } else if Equals(row.badge, EGaragePartBadge.Owned) {
      this.ShowBadge(n"Garage-PartsList-Owned", GarageColors.Success());
    } else {
      this.m_badge.SetVisible(false);
    }
    this.ShowCartIcon(Equals(row.badge, EGaragePartBadge.Cart));
    this.ShowPrice(Equals(row.badge, EGaragePartBadge.Price), row.part.price);
  }

  /// The row a slot with no choices gets, there's nothing to click on it.
  public func BindEmpty() -> Void {
    this.m_row = null;
    this.GetRootWidget().SetVisible(true);
    this.SetColorMode(false);
    this.m_button.SetDisabled(true);
    this.SetLabel(GarageText.Get(n"Garage-PartsList-DefaultOption"));
    this.SetWarning(false);
    this.ShowBadge(n"Garage-PartsList-Stock", GarageColors.Blue());
    this.ShowCartIcon(false);
    this.ShowPrice(false, 0);
  }

  public func Clear() -> Void {
    this.m_row = null;
    this.GetRootWidget().SetVisible(false);
  }

  private func SetColorMode(isColor: Bool) -> Void {
    this.m_swatch.SetVisible(isColor);
    if isColor && !this.m_swatchReady {
      this.m_swatchReady = true;
      this.m_swatch.SetAtlasResource(r"base\\gameplay\\gui\\widgets\\custom_garage\\custom_swatch.inkatlas");
      this.m_swatch.SetTexturePart(n"swatch");
    }
    let width: Float = isColor ? 484.0 : 520.0;
    if NotEquals(width, this.m_width) {
      this.m_width = width;
      this.m_button.SetWidth(width);
    }
  }

  private func SetLabel(name: String) -> Void {
    this.m_button.SetText(name);
    FitButtonText(this.m_button, name, this.m_width);
  }

  // Atlases only load on a widget that's showing, so each one waits for the first time it's needed
  private func SetWarning(on: Bool) -> Void {
    this.m_warningBg.SetVisible(on);
    this.m_warningIcon.SetVisible(on);
    if on && !this.m_warningReady {
      this.m_warningReady = true;
      this.m_warningBg.SetAtlasResource(r"base\\gameplay\\gui\\common\\shapes\\atlas_shapes_sync.inkatlas");
      this.m_warningBg.SetTexturePart(n"cell_bg");
      this.m_warningIcon.SetAtlasResource(r"base\\gameplay\\gui\\widgets\\scanning\\scanner_tooltip\\atlas_scanner.inkatlas");
      this.m_warningIcon.SetTexturePart(n"fluff_triangle2");
    }
  }

  private func ShowBadge(key: CName, tint: HDRColor) -> Void {
    this.m_badge.SetText(GarageText.Get(key));
    this.m_badge.SetTintColor(tint);
    this.m_badge.SetVisible(true);
  }

  private func ShowCartIcon(on: Bool) -> Void {
    this.m_cartHolder.SetVisible(on);
    if on && !this.m_cartReady {
      this.m_cartReady = true;
      this.m_cartIcon.SetAtlasResource(r"base\\gameplay\\gui\\common\\icons\\mappin_icons.inkatlas");
      this.m_cartIcon.SetTexturePart(n"wandering_merchant");
    }
  }

  private func ShowPrice(on: Bool, price: Int32) -> Void {
    this.m_priceRow.SetVisible(on);
    if !on { return; }
    this.m_priceText.SetText(GarageText.Price(price));
    if !this.m_priceReady {
      this.m_priceReady = true;
      InitMoneyIcon(this.m_priceIcon);
    }
  }

  protected cb func OnClick(widget: wref<inkWidget>) -> Bool {
    let owner: ref<PartsListScreen> = this.m_owner;
    if IsDefined(owner) && IsDefined(this.m_row) { owner.OnRowClicked(this.m_row); }
    return false;
  }
}

public class PartsListScreen extends AftermarketScreen {
  private let m_pagination: ref<PaginationHelper>;
  private let m_rows: array<ref<PartRow>>;

  protected cb func OnCreate() {
    super.OnCreate();
    let root: ref<inkCanvas> = this.GetRootWidget() as inkCanvas;
    this.CreateBackButton(root);
    this.CreateTitle(root, GarageText.Get(n"Garage-Desc-Parts"), 60.0);
    let list: ref<inkVerticalPanel> = this.CreateColumn(root, n"listPanel");
    this.m_pagination = this.CreatePagination(root, 5);
    let i: Int32 = 0;
    while i < this.m_pagination.GetItemsPerPage() {
      let row: ref<PartRow> = new PartRow();
      row.SetOwner(this);
      row.Reparent(list);
      ArrayPush(this.m_rows, row);
      i += 1;
    }
  }

  public func Show() {
    super.Show();
    this.m_flow.Mark("list show begin");
    this.m_flow.EnterSlot();
    this.m_titleText.SetText(this.Title());
    this.m_pagination.SetCurrentPage(this.m_flow.ListPage());
    this.m_pagination.SetTotalItems(this.Parts().RowCount(this.m_flow.slot, this.m_flow.finish));
    this.m_pagination.ClampPage();
    this.m_flow.SaveListPage(this.m_pagination.GetCurrentPage());
    this.DisplayCurrentPage();
    this.UpdateHint(n"click", GarageText.Get(n"Garage-Hint-Select"), true);
    this.m_flow.Mark("list show done");
  }

  public func Hide() {
    super.Hide();
    this.RemoveHint(n"click");
  }

  private func Title() -> String {
    let flow: ref<PartsFlow> = this.m_flow;
    let title: String = StrUpper(StrLen(flow.slotName) > 0 ? flow.slotName : NameToString(flow.slot));
    if !flow.isColor { return title; }
    if Equals(flow.finish, n"standard") { return title + " - " + StrUpper(GarageText.Get(n"Garage-PaintType-Standard")); }
    if Equals(flow.finish, n"metallic") { return title + " - " + StrUpper(GarageText.Get(n"Garage-PaintType-Metallic")); }
    if Equals(flow.finish, n"matte") { return title + " - " + StrUpper(GarageText.Get(n"Garage-PaintType-Matte")); }
    return title;
  }

  private func DisplayCurrentPage() -> Void {
    let flow: ref<PartsFlow> = this.m_flow;
    let start: Int32 = this.m_pagination.GetStartIndex();
    let rows: array<ref<GaragePartRow>> = this.Parts().Rows(flow.slot, flow.finish, start, ArraySize(this.m_rows));
    let i: Int32 = 0;
    while i < ArraySize(this.m_rows) {
      if i < ArraySize(rows) {
        this.m_rows[i].Bind(rows[i], flow.isColor);
      } else if i == 0 && !IsNameValid(flow.finish) {
        this.m_rows[i].BindEmpty();
      } else {
        this.m_rows[i].Clear();
      }
      i += 1;
    }
    this.m_pagination.UpdateWidgets();
  }

  public func OnRowClicked(row: ref<GaragePartRow>) -> Void { this.m_flow.ChoosePart(row.part.id); }

  public func NextPage() -> Void {
    if this.m_pagination.NextPage() { this.ShowPage(); }
  }

  public func PrevPage() -> Void {
    if this.m_pagination.PrevPage() { this.ShowPage(); }
  }

  private func ShowPage() -> Void {
    this.m_flow.Mark("list page begin");
    this.m_flow.SaveListPage(this.m_pagination.GetCurrentPage());
    this.DisplayCurrentPage();
    this.m_flow.Mark("list page done");
  }

  public func RefreshAfterCartChange() -> Void { this.DisplayCurrentPage(); }
}
