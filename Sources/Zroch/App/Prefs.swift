import Foundation

/// UserDefaults keys and their default values.
enum Prefs {
    static let openOnHover = "openOnHover"
    static let openDelay = "openDelay"
    static let haptics = "haptics"
    static let showMenuBarIcon = "showMenuBarIcon"
    static let hideClosedOnNonNotch = "hideClosedOnNonNotch"
    static let fakeNotchWidth = "fakeNotchWidth"
    static let fakeNotchHeight = "fakeNotchHeight"
    static let autoOpenTrayOnDrag = "autoOpenTrayOnDrag"
    static let showLiveActivities = "showLiveActivities"
    static let weatherUnit = "weatherUnit"
    static let weatherCity = "weatherCity"
    static let showCalendar = "showCalendar"
    static let showReminders = "showReminders"
    static let timerPresets = "timerPresets"
    static let clipboardLimit = "clipboardLimit"

    static func tabKey(_ tab: NotchTab) -> String { "tab.\(tab.rawValue)" }

    static var defaults: [String: Any] {
        var d: [String: Any] = [
            openOnHover: true,
            openDelay: 0.15,
            haptics: true,
            showMenuBarIcon: true,
            hideClosedOnNonNotch: false,
            fakeNotchWidth: 190.0,
            fakeNotchHeight: 32.0,
            autoOpenTrayOnDrag: true,
            showLiveActivities: true,
            weatherUnit: "C",
            weatherCity: "",
            showCalendar: true,
            showReminders: true,
            timerPresets: "1, 5, 10, 15, 25, 45, 60",
            clipboardLimit: 50,
        ]
        for tab in NotchTab.allCases { d[tabKey(tab)] = true }
        return d
    }

    static var enabledTabs: [NotchTab] {
        NotchTab.allCases.filter { UserDefaults.standard.bool(forKey: tabKey($0)) }
    }
}

/// Small JSON persistence helper under ~/Library/Application Support/Zroch.
enum Storage {
    static var directory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Zroch", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static func save<T: Encodable>(_ value: T, to name: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        try? data.write(to: directory.appendingPathComponent(name), options: .atomic)
    }

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T? {
        guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}

func formatDuration(_ t: TimeInterval, showTenths: Bool = false) -> String {
    let total = max(0, t)
    let h = Int(total) / 3600, m = (Int(total) % 3600) / 60, s = Int(total) % 60
    var str = h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    if showTenths { str += String(format: ".%d", Int((total - floor(total)) * 10)) }
    return str
}
