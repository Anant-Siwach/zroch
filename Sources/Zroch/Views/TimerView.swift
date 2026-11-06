import SwiftUI

struct TimerView: View {
    @EnvironmentObject var timer: TimerService
    @State private var mode = 0
    @State private var customMinutes = 20

    var body: some View {
        HStack(spacing: 14) {
            Card {
                if mode == 0 { countdown } else { stopwatch }
            }
            .frame(width: 300)

            VStack(alignment: .leading, spacing: 8) {
                Picker("", selection: $mode) {
                    Text("Timer").tag(0)
                    Text("Stopwatch").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if mode == 0 {
                    Text("Presets").font(.system(size: 10, weight: .semibold)).opacity(0.5)
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 4), spacing: 6) {
                        ForEach(timer.presets, id: \.self) { m in
                            Button { timer.start(seconds: Double(m) * 60) } label: {
                                Text(m >= 60 && m % 60 == 0 ? "\(m / 60)h" : "\(m)m")
                                    .font(.system(size: 12, weight: .semibold))
                                    .frame(maxWidth: .infinity, minHeight: 26)
                                    .background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    HStack {
                        Stepper("\(customMinutes) min", value: $customMinutes, in: 1...600)
                            .font(.system(size: 12))
                        Button("Start") { timer.start(seconds: Double(customMinutes) * 60) }
                            .controlSize(.small)
                    }
                } else {
                    Text("Laps").font(.system(size: 10, weight: .semibold)).opacity(0.5)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(timer.laps.enumerated()), id: \.offset) { i, lap in
                                HStack {
                                    Text("Lap \(timer.laps.count - i)").opacity(0.6)
                                    Spacer()
                                    Text(formatDuration(lap, showTenths: true))
                                }
                                .font(.system(size: 11).monospacedDigit())
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var countdown: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: timer.isRunning ? 1 - timer.progress : 0)
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: timer.remaining)
                Image(systemName: "timer").font(.system(size: 20)).foregroundStyle(.orange)
            }
            .frame(width: 84, height: 84)

            VStack(alignment: .leading, spacing: 8) {
                Text(formatDuration(timer.isRunning ? timer.remaining : 0))
                    .font(.system(size: 34, weight: .semibold, design: .rounded).monospacedDigit())
                if timer.isRunning {
                    HStack(spacing: 8) {
                        RoundButton(icon: timer.isPaused ? "play.fill" : "pause.fill", tint: .orange) { timer.togglePause() }
                        RoundButton(icon: "plus", tint: .gray) { timer.add(seconds: 60) }
                        RoundButton(icon: "xmark", tint: .gray) { timer.cancel() }
                    }
                } else {
                    Text("Pick a preset to start").font(.system(size: 11)).opacity(0.5)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var stopwatch: some View {
        VStack(spacing: 10) {
            Text(formatDuration(timer.swElapsed, showTenths: true))
                .font(.system(size: 38, weight: .semibold, design: .rounded).monospacedDigit())
            HStack(spacing: 10) {
                RoundButton(icon: timer.swRunning ? "pause.fill" : "play.fill", tint: .green) { timer.toggleStopwatch() }
                RoundButton(icon: "flag.fill", tint: .gray) { timer.lap() }
                RoundButton(icon: "arrow.counterclockwise", tint: .gray) { timer.resetStopwatch() }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct RoundButton: View {
    var icon: String
    var tint: Color
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.3), in: Circle())
                .foregroundStyle(tint == .gray ? .white : tint)
        }
        .buttonStyle(.plain)
    }
}
