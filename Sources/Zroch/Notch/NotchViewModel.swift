import AppKit
import Combine
import SwiftUI

enum NotchTab: String, CaseIterable, Identifiable {
    case home, tray, timer, clipboard, notes, chat
    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .tray: "Tray"
        case .timer: "Timer"
        case .clipboard: "Clipboard"
        case .notes: "Notes"
        case .chat: "AI Chat"
        }
    }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .tray: "tray.full.fill"
        case .timer: "timer"
        case .clipboard: "doc.on.clipboard.fill"
        case .notes: "note.text"
        case .chat: "sparkles"
        }
    }
}

enum LiveActivity: Equatable {
    case none, music, timer
}

final class NotchViewModel: ObservableObject {
    enum Status { case closed, open }

    @Published var status: Status = .closed
    @Published var tab: NotchTab = .home
    @Published var hovering = false
    @Published var pinned = false
    @Published var dropTargeted = false
    @Published var homePage = 0
    @Published var liveActivity: LiveActivity = .none
    @Published var notchSize = CGSize(width: 190, height: 32)
    @Published var hasPhysicalNotch = false
    @Published var enabledTabs: [NotchTab] = Prefs.enabledTabs

    var screenFrame: NSRect = .zero
    let openSize = CGSize(width: 680, height: 250)
    private var cancellables = Set<AnyCancellable>()

    init() {
        Publishers.CombineLatest(MusicService.shared.$isPlaying, TimerService.shared.$isRunning)
            .receive(on: RunLoop.main)
            .sink { [weak self] playing, timerRunning in
                guard UserDefaults.standard.bool(forKey: Prefs.showLiveActivities) else {
                    self?.liveActivity = .none; return
                }
                self?.liveActivity = timerRunning ? .timer : (playing ? .music : .none)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                guard let self else { return }
                let tabs = Prefs.enabledTabs
                if tabs != self.enabledTabs { self.enabledTabs = tabs }
                if !tabs.contains(self.tab), let first = tabs.first { self.tab = first }
            }
            .store(in: &cancellables)
    }

    func configure(for screen: NSScreen) {
        screenFrame = screen.frame
        let top = screen.safeAreaInsets.top
        if top > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            hasPhysicalNotch = true
            notchSize = CGSize(width: screen.frame.width - left.width - right.width, height: top)
        } else {
            hasPhysicalNotch = false
            let d = UserDefaults.standard
            notchSize = CGSize(width: d.double(forKey: Prefs.fakeNotchWidth),
                               height: d.double(forKey: Prefs.fakeNotchHeight))
        }
    }

    var activityWing: CGFloat {
        switch liveActivity {
        case .none: 0
        case .music: 38
        case .timer: 56
        }
    }

    var closedSize: CGSize {
        CGSize(width: notchSize.width + activityWing * 2, height: notchSize.height)
    }

    var currentSize: CGSize { status == .open ? openSize : closedSize }

    var hideWhenClosed: Bool {
        !hasPhysicalNotch && liveActivity == .none
            && UserDefaults.standard.bool(forKey: Prefs.hideClosedOnNonNotch)
    }

    /// The area (in screen coordinates) that should capture the mouse.
    var hotRect: NSRect {
        let size = currentSize
        let pad: CGFloat = status == .open ? 4 : 10
        return NSRect(x: screenFrame.midX - size.width / 2 - pad,
                      y: screenFrame.maxY - size.height - pad,
                      width: size.width + pad * 2,
                      height: size.height + pad)
    }

    func open(tab: NotchTab? = nil) {
        if let tab, enabledTabs.contains(tab) { self.tab = tab }
        guard status != .open else { return }
        status = .open
        if UserDefaults.standard.bool(forKey: Prefs.haptics) {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
    }

    func close() {
        guard status != .closed, !pinned, !dropTargeted else { return }
        status = .closed
        homePage = 0
    }
}
