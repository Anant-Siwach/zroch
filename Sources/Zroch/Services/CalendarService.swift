import EventKit
import Foundation

/// Upcoming calendar events and due reminders via EventKit.
final class CalendarService: ObservableObject {
    static let shared = CalendarService()

    let store = EKEventStore()
    @Published var events: [EKEvent] = []
    @Published var reminders: [EKReminder] = []
    @Published var eventsAuthorized = false
    @Published var remindersAuthorized = false

    func start() {
        updateStatus()
        fetch()
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            self?.fetch()
        }
        Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in self?.fetch() }
    }

    var needsAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .notDetermined
            || EKEventStore.authorizationStatus(for: .reminder) == .notDetermined
    }

    private func updateStatus() {
        eventsAuthorized = EKEventStore.authorizationStatus(for: .event) == .fullAccess
        remindersAuthorized = EKEventStore.authorizationStatus(for: .reminder) == .fullAccess
    }

    func requestAccess() {
        store.requestFullAccessToEvents { [weak self] _, _ in
            self?.store.requestFullAccessToReminders { _, _ in
                DispatchQueue.main.async {
                    self?.updateStatus()
                    self?.fetch()
                }
            }
        }
    }

    func fetch() {
        updateStatus()
        let cal = Calendar.current
        let now = Date()
        let endOfTomorrow = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: now))!
        if eventsAuthorized {
            let pred = store.predicateForEvents(withStart: now, end: endOfTomorrow, calendars: nil)
            events = Array(store.events(matching: pred).sorted { $0.startDate < $1.startDate }.prefix(8))
        }
        if remindersAuthorized {
            let endOfToday = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: now))
            let pred = store.predicateForIncompleteReminders(withDueDateStarting: nil, ending: endOfToday, calendars: nil)
            store.fetchReminders(matching: pred) { [weak self] result in
                DispatchQueue.main.async { self?.reminders = Array((result ?? []).prefix(8)) }
            }
        }
    }

    func complete(_ reminder: EKReminder) {
        reminder.isCompleted = true
        try? store.save(reminder, commit: true)
        reminders.removeAll { $0.calendarItemIdentifier == reminder.calendarItemIdentifier }
    }

    func addReminder(_ title: String) {
        guard remindersAuthorized, let list = store.defaultCalendarForNewReminders() else { return }
        let r = EKReminder(eventStore: store)
        r.title = title
        r.calendar = list
        r.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        try? store.save(r, commit: true)
        fetch()
    }
}
