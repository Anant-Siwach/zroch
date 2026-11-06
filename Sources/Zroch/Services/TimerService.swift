import AppKit
import Combine
import UserNotifications

/// Countdown timer and stopwatch.
final class TimerService: ObservableObject {
    static let shared = TimerService()

    // Countdown
    @Published var total: TimeInterval = 0
    @Published var remaining: TimeInterval = 0
    @Published var isRunning = false
    @Published var isPaused = false
    @Published var label = ""
    let finished = PassthroughSubject<Void, Never>()
    private var endDate: Date?

    // Stopwatch
    @Published var swElapsed: TimeInterval = 0
    @Published var swRunning = false
    @Published var laps: [TimeInterval] = []
    private var swStart: Date?
    private var swAccumulated: TimeInterval = 0

    private var ticker: Timer?

    func start() {
        ticker = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
    }

    var presets: [Int] {
        (UserDefaults.standard.string(forKey: Prefs.timerPresets) ?? "")
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
            .filter { $0 > 0 }
    }

    var progress: Double { total > 0 ? 1 - remaining / total : 0 }

    func start(seconds: TimeInterval, label: String = "") {
        guard seconds > 0 else { return }
        total = seconds
        remaining = seconds
        endDate = Date().addingTimeInterval(seconds)
        self.label = label
        isPaused = false
        isRunning = true
    }

    func togglePause() {
        guard isRunning else { return }
        if isPaused {
            endDate = Date().addingTimeInterval(remaining)
            isPaused = false
        } else {
            remaining = max(0, endDate?.timeIntervalSinceNow ?? 0)
            endDate = nil
            isPaused = true
        }
    }

    func cancel() {
        isRunning = false
        isPaused = false
        endDate = nil
        remaining = 0
        total = 0
    }

    func add(seconds: TimeInterval) {
        guard isRunning else { return }
        total += seconds
        remaining += seconds
        endDate = endDate?.addingTimeInterval(seconds)
    }

    private func tick() {
        if isRunning, !isPaused, let end = endDate {
            remaining = max(0, end.timeIntervalSinceNow)
            if remaining <= 0 { finish() }
        }
        if swRunning, let s = swStart {
            swElapsed = swAccumulated + Date().timeIntervalSince(s)
        }
    }

    private func finish() {
        isRunning = false
        endDate = nil
        for i in 0..<3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.9) { NSSound(named: "Glass")?.play() }
        }
        let content = UNMutableNotificationContent()
        content.title = "Timer done"
        content.body = label.isEmpty ? "Your \(formatDuration(total)) timer finished." : label
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        finished.send()
    }

    // MARK: Stopwatch

    func toggleStopwatch() {
        if swRunning {
            swAccumulated += Date().timeIntervalSince(swStart ?? Date())
            swStart = nil
            swRunning = false
            swElapsed = swAccumulated
        } else {
            swStart = Date()
            swRunning = true
        }
    }

    func lap() {
        guard swRunning else { return }
        laps.insert(swElapsed, at: 0)
    }

    func resetStopwatch() {
        swRunning = false
        swStart = nil
        swAccumulated = 0
        swElapsed = 0
        laps = []
    }
}
