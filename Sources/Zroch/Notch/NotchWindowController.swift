import AppKit
import Combine
import SwiftUI

/// Borderless panel that floats over the menu bar. It can become key so text fields work,
/// and forwards standard editing shortcuts since an accessory app has no Edit menu.
final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags.contains(.command), let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        let action: Selector? = switch (key, flags.contains(.shift)) {
        case ("x", false): #selector(NSText.cut(_:))
        case ("c", false): #selector(NSText.copy(_:))
        case ("v", false): #selector(NSText.paste(_:))
        case ("a", false): #selector(NSText.selectAll(_:))
        case ("z", false): Selector(("undo:"))
        case ("z", true): Selector(("redo:"))
        default: nil
        }
        if let action, NSApp.sendAction(action, to: nil, from: self) { return true }
        return super.performKeyEquivalent(with: event)
    }
}

final class NotchWindowController {
    let vm = NotchViewModel()
    private var panel: NotchPanel!
    private var tracker: Timer?
    private var openWork: DispatchWorkItem?
    private var closeWork: DispatchWorkItem?
    private var scrollMonitor: Any?
    private var scrollAccum: CGFloat = 0
    private var cancellables = Set<AnyCancellable>()
    private let windowSize = CGSize(width: 760, height: 340)

    init() {
        panel = NotchPanel(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.mainMenu.rawValue + 3)
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.ignoresMouseEvents = true

        let root = NotchRootView()
            .environmentObject(vm)
            .environmentObject(MusicService.shared)
            .environmentObject(WeatherService.shared)
            .environmentObject(CalendarService.shared)
            .environmentObject(ClipboardService.shared)
            .environmentObject(TrayService.shared)
            .environmentObject(TimerService.shared)
            .environmentObject(NotesStore.shared)
            .environmentObject(AIService.shared)
            .environmentObject(CameraService.shared)
        let host = NSHostingView(rootView: root)
        host.sizingOptions = []
        panel.contentView = host

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.reposition() }

        // Pop the notch open briefly when a timer finishes.
        TimerService.shared.finished
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.flash(.timer) }
            .store(in: &cancellables)

        // Horizontal swipe on Home switches between widgets and the camera mirror.
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            self?.handleScroll(event)
            return event
        }
    }

    func show() {
        reposition()
        panel.orderFrontRegardless()
        tracker = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func reposition() {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main ?? NSScreen.screens[0]
        vm.configure(for: screen)
        let frame = NSRect(x: screen.frame.midX - windowSize.width / 2,
                           y: screen.frame.maxY - windowSize.height,
                           width: windowSize.width, height: windowSize.height)
        panel.setFrame(frame, display: true)
    }

    private func tick() {
        let inside = vm.hotRect.contains(NSEvent.mouseLocation)
        panel.ignoresMouseEvents = !inside
        guard inside != vm.hovering else { return }
        vm.hovering = inside
        if inside {
            closeWork?.cancel()
            let dragging = NSEvent.pressedMouseButtons & 1 != 0
            if dragging, UserDefaults.standard.bool(forKey: Prefs.autoOpenTrayOnDrag) {
                schedule(open: true, tab: .tray, delay: 0.05)
            } else if UserDefaults.standard.bool(forKey: Prefs.openOnHover) {
                schedule(open: true, tab: nil, delay: UserDefaults.standard.double(forKey: Prefs.openDelay))
            }
        } else {
            openWork?.cancel()
            schedule(open: false, tab: nil, delay: 0.25)
        }
    }

    private func schedule(open: Bool, tab: NotchTab?, delay: Double) {
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
                if open {
                    self.vm.open(tab: tab)
                } else {
                    self.vm.close()
                }
            }
            if open { self.panel.makeKey() } else if self.vm.status == .closed { self.panel.resignKey() }
        }
        if open { openWork = work } else { closeWork = work }
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func flash(_ tab: NotchTab) {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { vm.open(tab: tab) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) { [weak self] in
            guard let self, !self.vm.hovering else { return }
            withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { self.vm.close() }
        }
    }

    private func handleScroll(_ event: NSEvent) {
        guard vm.status == .open, vm.tab == .home, abs(event.scrollingDeltaX) > abs(event.scrollingDeltaY) else { return }
        if event.phase == .began { scrollAccum = 0 }
        scrollAccum += event.scrollingDeltaX
        if scrollAccum < -50, vm.homePage == 0 {
            withAnimation(.spring) { vm.homePage = 1 }
            scrollAccum = 0
        } else if scrollAccum > 50, vm.homePage == 1 {
            withAnimation(.spring) { vm.homePage = 0 }
            scrollAccum = 0
        }
    }
}
