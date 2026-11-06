import ServiceManagement
import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
            TabsSettings().tabItem { Label("Tabs", systemImage: "square.grid.2x2") }
            HomeSettings().tabItem { Label("Home", systemImage: "house") }
            ToolsSettings().tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
            NonNotchSettings().tabItem { Label("Non-Notch", systemImage: "menubar.rectangle") }
            AboutSettings().tabItem { Label("About", systemImage: "info.circle") }
        }
        .padding(20)
        .frame(width: 560, height: 460)
    }
}

private struct GeneralSettings: View {
    @AppStorage(Prefs.openOnHover) private var openOnHover = true
    @AppStorage(Prefs.openDelay) private var openDelay = 0.15
    @AppStorage(Prefs.haptics) private var haptics = true
    @AppStorage(Prefs.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(Prefs.showLiveActivities) private var liveActivities = true
    @AppStorage(Prefs.autoOpenTrayOnDrag) private var autoTray = true
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Toggle("Launch at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, on in
                    do {
                        if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
                    } catch {
                        launchAtLogin = SMAppService.mainApp.status == .enabled
                    }
                }
            Toggle("Open notch on hover", isOn: $openOnHover)
            if openOnHover {
                Slider(value: $openDelay, in: 0...1, step: 0.05) {
                    Text("Hover delay: \(openDelay, specifier: "%.2f")s")
                }
            }
            Toggle("Haptic feedback on open", isOn: $haptics)
            Toggle("Show live activities (music, timer) in closed notch", isOn: $liveActivities)
            Toggle("Open Tray when dragging files to the notch", isOn: $autoTray)
            Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
            if !showMenuBarIcon {
                Text("Open Zroch again from Finder or Spotlight to get back to Settings.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct TabsSettings: View {
    var body: some View {
        Form {
            Section("Tab Management") {
                ForEach(NotchTab.allCases) { tab in
                    TabToggle(tab: tab)
                }
            }
        }
        .formStyle(.grouped)
    }
}

private struct TabToggle: View {
    let tab: NotchTab
    @AppStorage private var enabled: Bool

    init(tab: NotchTab) {
        self.tab = tab
        _enabled = AppStorage(wrappedValue: true, Prefs.tabKey(tab))
    }

    var body: some View {
        Toggle(isOn: $enabled) { Label(tab.title, systemImage: tab.icon) }
            .disabled(enabled && Prefs.enabledTabs.count == 1)
    }
}

private struct HomeSettings: View {
    @AppStorage(Prefs.weatherUnit) private var unit = "C"
    @AppStorage(Prefs.weatherCity) private var city = ""
    @AppStorage(Prefs.showCalendar) private var showCalendar = true
    @AppStorage(Prefs.showReminders) private var showReminders = true
    @State private var cityDraft = ""

    var body: some View {
        Form {
            Section("Weather Widget") {
                Picker("Units", selection: $unit) {
                    Text("Celsius").tag("C")
                    Text("Fahrenheit").tag("F")
                }
                HStack {
                    TextField("City (leave empty to use location)", text: $cityDraft)
                    Button("Save") { city = cityDraft }
                }
                Text("Weather data provided by Open-Meteo.com").font(.caption).foregroundStyle(.secondary)
            }
            Section("Calendar") {
                Toggle("Show calendar events", isOn: $showCalendar)
                Toggle("Show reminders", isOn: $showReminders)
                Button("Grant Calendar & Reminders Access") { CalendarService.shared.requestAccess() }
            }
        }
        .formStyle(.grouped)
        .onAppear { cityDraft = city }
    }
}

private struct ToolsSettings: View {
    @AppStorage(Prefs.timerPresets) private var presets = ""
    @AppStorage(Prefs.clipboardLimit) private var limit = 50

    var body: some View {
        Form {
            Section("Timer Settings") {
                TextField("Presets (minutes, comma-separated)", text: $presets)
            }
            Section("Clipboard") {
                Stepper("Keep \(limit) history items", value: $limit, in: 10...500, step: 10)
                Button("Clear Clipboard History") { ClipboardService.shared.clearHistory() }
            }
            Section("Tray Settings") {
                Button("Clear Tray") { TrayService.shared.clear() }
            }
        }
        .formStyle(.grouped)
    }
}

private struct NonNotchSettings: View {
    @AppStorage(Prefs.hideClosedOnNonNotch) private var hideClosed = false
    @AppStorage(Prefs.fakeNotchWidth) private var width = 190.0
    @AppStorage(Prefs.fakeNotchHeight) private var height = 32.0

    var body: some View {
        Form {
            Text("These settings optimize Zroch for Macs without a notch display. If your Mac has a notch, you can leave them alone.")
                .font(.callout).foregroundStyle(.secondary)
            Toggle("Hide the closed notch until hovered", isOn: $hideClosed)
            Slider(value: $width, in: 120...320, step: 5) { Text("Notch width: \(Int(width))") }
            Slider(value: $height, in: 22...40, step: 1) { Text("Notch height: \(Int(height))") }
            Button("Apply") {
                NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettings: View {
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "capsule.fill").font(.system(size: 44))
            Text("Zroch").font(.title.bold())
            Text("Turn your notch into a productivity powerhouse").foregroundStyle(.secondary)
            Text("Version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
                .font(.caption).foregroundStyle(.tertiary)
            Button("Quit Zroch") { NSApp.terminate(nil) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
