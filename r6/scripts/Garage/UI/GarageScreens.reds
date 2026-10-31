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

public class ScreenEntry {
    public let name: CName;
    public let screen: ref<GarageScreen>;
}

/// Which screen's showing, and how to get back. Register an addon's screens with it in GarageAddon.RegisterScreens.
public class ScreenManager {
    private let m_garageFrame: wref<GarageFrame>;
    private let m_screens: array<ref<ScreenEntry>>;
    private let m_currentScreen: CName;
    private let m_screenHistory: array<CName>;

    public static func Create(garageFrame: ref<GarageFrame>) -> ref<ScreenManager> {
        let manager = new ScreenManager();
        manager.m_garageFrame = garageFrame;
        manager.m_currentScreen = n"";
        return manager;
    }

    public func RegisterScreen(name: CName, screen: ref<GarageScreen>) -> Bool {
        let i: Int32 = 0;
        while i < ArraySize(this.m_screens) {
            if Equals(this.m_screens[i].name, name) {
                XUtils.Mod("Garage").Log("UI").Warn(s"Duplicate screen name: \(NameToString(name))");
                return false;
            }
            i += 1;
        }
        let entry = new ScreenEntry();
        entry.name = name;
        entry.screen = screen;
        ArrayPush(this.m_screens, entry);
        return true;
    }

    public func ShowScreen(name: CName) -> Void {
        if Equals(name, this.m_currentScreen) {
            return;
        }
        // Showing a name nobody registered would hide everything and leave an empty panel
        if !IsDefined(this.GetScreen(name)) {
            XUtils.Mod("Garage").Log("UI").Warn("no screen called " + NameToString(name));
            return;
        }

        if NotEquals(this.m_currentScreen, n"") {
            ArrayPush(this.m_screenHistory, this.m_currentScreen);
        }

        this.ShowScreenInternal(name);
    }

    // Navigate without pushing to history (used by GoBack)
    private func ShowScreenInternal(name: CName) -> Void {
        let i: Int32 = 0;
        while i < ArraySize(this.m_screens) {
            this.m_screens[i].screen.Hide();
            i += 1;
        }

        i = 0;
        while i < ArraySize(this.m_screens) {
            if Equals(this.m_screens[i].name, name) {
                this.m_screens[i].screen.Show();
                this.m_currentScreen = name;
                return;
            }
            i += 1;
        }

        XUtils.Mod("Garage").Log("UI").Warn(s"Screen not found: \(NameToString(name))");
    }

    public func GoBack() -> Void {
        let historySize = ArraySize(this.m_screenHistory);
        if historySize == 0 {
            return;
        }

        let previousScreen = this.m_screenHistory[historySize - 1];
        ArrayErase(this.m_screenHistory, historySize - 1);

        this.ShowScreenInternal(previousScreen);
    }

    public func CanGoBack() -> Bool {
        return ArraySize(this.m_screenHistory) > 0;
    }

    public func GetCurrentScreen() -> CName {
        return this.m_currentScreen;
    }

    public func GetScreen(name: CName) -> ref<GarageScreen> {
        let i: Int32 = 0;
        while i < ArraySize(this.m_screens) {
            if Equals(this.m_screens[i].name, name) {
                return this.m_screens[i].screen;
            }
            i += 1;
        }
        return null;
    }

    public func GetGarageFrame() -> ref<GarageFrame> {
        return this.m_garageFrame;
    }

    /// The shared "can't do that here" screen. title and message are already localized.
    public func ShowUnavailable(title: String, message: String) -> Void {
        let screen = this.GetScreen(n"unavailable") as UnavailableScreen;
        if IsDefined(screen) { screen.SetMessage(title, message); }
        this.ShowScreen(n"unavailable");
    }

    public func ClearHistory() -> Void {
        ArrayClear(this.m_screenHistory);
    }

    public func RecoverToHub() -> Void {
        ArrayClear(this.m_screenHistory);
        this.ShowScreenInternal(n"hub");
    }

    public func ScrollUp() -> Void {
        let i: Int32 = 0;
        while i < ArraySize(this.m_screens) {
            if Equals(this.m_screens[i].name, this.m_currentScreen) {
                this.m_screens[i].screen.PrevPage();
                return;
            }
            i += 1;
        }
    }

    public func ScrollDown() -> Void {
        let i: Int32 = 0;
        while i < ArraySize(this.m_screens) {
            if Equals(this.m_screens[i].name, this.m_currentScreen) {
                this.m_screens[i].screen.NextPage();
                return;
            }
            i += 1;
        }
    }
}

public class PaginationHelper {
    private let m_currentPage: Int32;
    private let m_itemsPerPage: Int32;
    private let m_totalItems: Int32;
    private let m_prevPageBtn: wref<SimpleButton>;
    private let m_nextPageBtn: wref<SimpleButton>;
    private let m_pageText: wref<inkText>;

    public static func Create(itemsPerPage: Int32) -> ref<PaginationHelper> {
        let helper = new PaginationHelper();
        helper.m_currentPage = 0;
        helper.m_itemsPerPage = itemsPerPage;
        helper.m_totalItems = 0;
        return helper;
    }

    public func SetWidgets(prevBtn: ref<SimpleButton>, nextBtn: ref<SimpleButton>, pageText: ref<inkText>) -> Void {
        this.m_prevPageBtn = prevBtn;
        this.m_nextPageBtn = nextBtn;
        this.m_pageText = pageText;
    }

    public func SetTotalItems(total: Int32) -> Void {
        this.m_totalItems = total;
    }

    public func GetCurrentPage() -> Int32 { return this.m_currentPage; }
    public func SetCurrentPage(page: Int32) -> Void { this.m_currentPage = page; }
    public func GetItemsPerPage() -> Int32 { return this.m_itemsPerPage; }

    public func GetTotalPages() -> Int32 {
        let pages = (this.m_totalItems + this.m_itemsPerPage - 1) / this.m_itemsPerPage;
        return pages < 1 ? 1 : pages;
    }

    public func GetStartIndex() -> Int32 {
        return this.m_currentPage * this.m_itemsPerPage;
    }

    public func GetEndIndex() -> Int32 {
        let end = this.GetStartIndex() + this.m_itemsPerPage;
        return end > this.m_totalItems ? this.m_totalItems : end;
    }

    public func ClampPage() -> Void {
        let totalPages = this.GetTotalPages();
        if this.m_currentPage >= totalPages {
            this.m_currentPage = 0;
        }
    }

    public func UpdateWidgets() -> Void {
        let totalPages = this.GetTotalPages();
        if IsDefined(this.m_pageText) {
            this.m_pageText.SetText(GetLocalizedTextByKey(n"Garage-PartsList-PagePrefix") + IntToString(this.m_currentPage + 1) + GetLocalizedTextByKey(n"Garage-PartsList-PageSeparator") + IntToString(totalPages));
        }
        if IsDefined(this.m_prevPageBtn) {
            this.m_prevPageBtn.SetDisabled(this.m_currentPage <= 0);
        }
        if IsDefined(this.m_nextPageBtn) {
            this.m_nextPageBtn.SetDisabled(this.m_currentPage >= totalPages - 1);
        }
    }

    public func NextPage() -> Bool {
        if this.m_currentPage < this.GetTotalPages() - 1 {
            this.m_currentPage += 1;
            return true;
        }
        return false;
    }

    public func PrevPage() -> Bool {
        if this.m_currentPage > 0 {
            this.m_currentPage -= 1;
            return true;
        }
        return false;
    }
}
