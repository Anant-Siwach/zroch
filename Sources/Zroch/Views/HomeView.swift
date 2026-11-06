import EventKit
import SwiftUI

struct HomeView: View {
    @EnvironmentObject var vm: NotchViewModel
    @AppStorage(Prefs.showCalendar) private var showCalendar = true
    @AppStorage(Prefs.showReminders) private var showReminders = true

    var body: some View {
        ZStack(alignment: .bottom) {
            if vm.homePage == 0 {
                HStack(spacing: 10) {
                    MusicCard().frame(width: 270)
                    if showCalendar || showReminders { CalendarCard() }
                    WeatherCard().frame(width: 130)
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            } else {
                CameraCard()
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
            PageDots(page: $vm.homePage)
                .offset(y: 12)
        }
    }
}

private struct PageDots: View {
    @Binding var page: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(page == i ? 0.9 : 0.3))
                    .frame(width: 5, height: 5)
                    .onTapGesture { withAnimation(.spring) { page = i } }
            }
        }
        .help("Swipe left to see Camera")
    }
}

// MARK: Music

struct MusicCard: View {
    @EnvironmentObject var music: MusicService
    @State private var scrubbing: Double?

    var body: some View {
        Card {
            if music.player == nil {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        AlbumArt(image: nil, size: 54, corner: 12).opacity(0.5)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Nothing playing").font(.system(size: 13, weight: .semibold))
                            Text("Open a player to start").font(.system(size: 11)).opacity(0.6)
                        }
                    }
                    HStack {
                        Button("Apple Music") { music.launch(.music) }
                        Button("Spotify") { music.launch(.spotify) }
                    }
                    .controlSize(.small)
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        AlbumArt(image: music.artwork, size: 54, corner: 12)
                            .onTapGesture { music.activatePlayer() }
                        VStack(alignment: .leading, spacing: 2) {
                            Text(music.title).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                            Text(music.artist).font(.system(size: 11)).opacity(0.65).lineLimit(1)
                            Text(music.player?.rawValue ?? "").font(.system(size: 9, weight: .medium)).opacity(0.4)
                        }
                        Spacer(minLength: 0)
                    }
                    VStack(spacing: 2) {
                        Slider(value: Binding(
                            get: { scrubbing ?? music.position },
                            set: { scrubbing = $0 }
                        ), in: 0...max(music.duration, 1)) { editing in
                            if !editing, let v = scrubbing { music.seek(to: v); scrubbing = nil }
                        }
                        .controlSize(.mini)
                        .tint(.white)
                        HStack {
                            Text(formatDuration(scrubbing ?? music.position))
                            Spacer()
                            Text("-" + formatDuration(music.duration - (scrubbing ?? music.position)))
                        }
                        .font(.system(size: 9).monospacedDigit())
                        .opacity(0.5)
                    }
                    HStack(spacing: 18) {
                        Spacer()
                        IconButton(icon: "backward.fill", size: 13) { music.previous() }
                        IconButton(icon: music.isPlaying ? "pause.fill" : "play.fill", size: 17) { music.playPause() }
                        IconButton(icon: "forward.fill", size: 13) { music.next() }
                        Spacer()
                    }
                }
            }
        }
    }
}

// MARK: Calendar & reminders

struct CalendarCard: View {
    @EnvironmentObject var cal: CalendarService
    @AppStorage(Prefs.showCalendar) private var showCalendar = true
    @AppStorage(Prefs.showReminders) private var showReminders = true
    @State private var newReminder = ""

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(Date(), format: .dateTime.weekday(.abbreviated)).font(.system(size: 12, weight: .semibold)).foregroundStyle(.red)
                    Text(Date(), format: .dateTime.day()).font(.system(size: 20, weight: .bold))
                    Text(Date(), format: .dateTime.month(.wide)).font(.system(size: 11)).opacity(0.6)
                }
                if !cal.eventsAuthorized && !cal.remindersAuthorized {
                    Spacer()
                    Text("See your events and reminders here.").font(.system(size: 11)).opacity(0.6)
                    Button("Grant Access") { cal.requestAccess() }.controlSize(.small)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 5) {
                            if showCalendar && cal.eventsAuthorized {
                                if cal.events.isEmpty {
                                    Text("No upcoming events").font(.system(size: 11)).opacity(0.5)
                                }
                                ForEach(cal.events, id: \.eventIdentifier) { event in
                                    EventRow(event: event)
                                }
                            }
                            if showReminders && cal.remindersAuthorized {
                                ForEach(cal.reminders, id: \.calendarItemIdentifier) { r in
                                    HStack(spacing: 6) {
                                        Button { withAnimation { cal.complete(r) } } label: {
                                            Image(systemName: "circle").font(.system(size: 11))
                                        }
                                        .buttonStyle(.plain)
                                        Text(r.title ?? "").font(.system(size: 11)).lineLimit(1)
                                    }
                                }
                                TextField("Add reminder", text: $newReminder)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 11))
                                    .onSubmit {
                                        cal.addReminder(newReminder)
                                        newReminder = ""
                                    }
                            }
                        }
                    }
                }
            }
        }
    }
}

private struct EventRow: View {
    let event: EKEvent

    var body: some View {
        HStack(spacing: 6) {
            Capsule().fill(Color(nsColor: event.calendar.color)).frame(width: 3, height: 22)
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title ?? "").font(.system(size: 11, weight: .medium)).lineLimit(1)
                Text(timeText).font(.system(size: 9)).opacity(0.55)
            }
        }
    }

    private var timeText: String {
        if event.isAllDay { return Calendar.current.isDateInToday(event.startDate) ? "All day" : "Tomorrow · All day" }
        let f = DateFormatter()
        f.timeStyle = .short
        let prefix = Calendar.current.isDateInToday(event.startDate) ? "" : "Tomorrow · "
        return prefix + f.string(from: event.startDate) + " – " + f.string(from: event.endDate)
    }
}

// MARK: Weather

struct WeatherCard: View {
    @EnvironmentObject var weather: WeatherService
    @AppStorage(Prefs.weatherUnit) private var unit = "C"

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(weather.city.isEmpty ? "Weather" : weather.city)
                    .font(.system(size: 11, weight: .semibold)).lineLimit(1).opacity(0.8)
                if let t = weather.temperature {
                    Image(systemName: weather.symbol)
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 26))
                    Text("\(Int(t.rounded()))°").font(.system(size: 26, weight: .semibold, design: .rounded))
                    Text(weather.summary).font(.system(size: 10)).opacity(0.6)
                    if let h = weather.high, let l = weather.low {
                        Text("H:\(Int(h.rounded()))° L:\(Int(l.rounded()))°").font(.system(size: 10)).opacity(0.6)
                    }
                } else {
                    Spacer()
                    Text(weather.error ?? "Loading…").font(.system(size: 10)).opacity(0.6)
                    Button("Retry") { weather.refresh() }.controlSize(.mini)
                    Spacer()
                }
            }
        }
        .onTapGesture { weather.refresh() }
    }
}

// MARK: Camera

struct CameraCard: View {
    @EnvironmentObject var camera: CameraService

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.07))
            if camera.denied {
                VStack(spacing: 6) {
                    Image(systemName: "video.slash.fill").font(.title2)
                    Text("Camera access is off").font(.system(size: 12))
                    Button("Open Privacy Settings") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
                    }
                    .controlSize(.small)
                }
            } else if camera.noCamera {
                Text("No camera found").font(.system(size: 12)).opacity(0.6)
            } else {
                CameraPreview(session: camera.session)
                    .scaleEffect(x: -1, y: 1)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
        .frame(maxWidth: 300)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }
}
