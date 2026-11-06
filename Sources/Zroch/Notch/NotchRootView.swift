import SwiftUI
import UniformTypeIdentifiers

struct NotchRootView: View {
    @EnvironmentObject var vm: NotchViewModel
    @EnvironmentObject var tray: TrayService

    private var isOpen: Bool { vm.status == .open }

    var body: some View {
        let size = vm.currentSize
        let shape = NotchShape(topRadius: isOpen ? 12 : 6, bottomRadius: isOpen ? 24 : 12)

        VStack(spacing: 0) {
            ZStack(alignment: .top) {
                shape.fill(Color.black)
                if isOpen {
                    OpenNotchView()
                        .transition(.opacity.combined(with: .scale(scale: 0.92, anchor: .top)))
                } else {
                    ClosedNotchView()
                        .transition(.opacity)
                }
            }
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay {
                if vm.dropTargeted {
                    shape.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6]))
                }
            }
            .shadow(color: .black.opacity(isOpen ? 0.55 : 0), radius: 14, y: 6)
            .opacity(!isOpen && vm.hideWhenClosed && !vm.hovering ? 0 : 1)
            .onTapGesture {
                if !isOpen {
                    withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) { vm.open() }
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $vm.dropTargeted) { providers in
                tray.add(providers: providers)
                withAnimation(.spring) { vm.open(tab: .tray) }
                return true
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.42, dampingFraction: 0.78), value: vm.status)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: vm.liveActivity)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Closed state (live activities)

struct ClosedNotchView: View {
    @EnvironmentObject var vm: NotchViewModel
    @EnvironmentObject var music: MusicService
    @EnvironmentObject var timer: TimerService

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(width: vm.activityWing, height: vm.notchSize.height)
            Color.clear.frame(width: vm.notchSize.width)
            trailing.frame(width: vm.activityWing, height: vm.notchSize.height)
        }
    }

    @ViewBuilder private var leading: some View {
        switch vm.liveActivity {
        case .music:
            AlbumArt(image: music.artwork, size: 20, corner: 5)
        case .timer:
            Image(systemName: "timer")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.orange)
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder private var trailing: some View {
        switch vm.liveActivity {
        case .music:
            MusicBars(playing: music.isPlaying)
                .frame(width: 16, height: 12)
        case .timer:
            Text(formatDuration(timer.remaining))
                .font(.system(size: 12, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.orange)
        case .none:
            EmptyView()
        }
    }
}

struct MusicBars: View {
    var playing: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: !playing)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<4, id: \.self) { i in
                    let phase = sin(t * (5 + Double(i) * 1.7) + Double(i))
                    Capsule()
                        .fill(Color.white)
                        .frame(width: 2.5, height: playing ? 4 + 8 * CGFloat(abs(phase)) : 3)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }
}

// MARK: - Open state

struct OpenNotchView: View {
    @EnvironmentObject var vm: NotchViewModel

    var body: some View {
        VStack(spacing: 0) {
            header.frame(height: max(vm.notchSize.height, 30))
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 22)
                .padding(.bottom, 14)
                .padding(.top, 6)
        }
        .foregroundStyle(.white)
    }

    private var header: some View {
        HStack(spacing: 4) {
            ForEach(vm.enabledTabs) { tab in
                Button {
                    withAnimation(.snappy) { vm.tab = tab }
                } label: {
                    Image(systemName: tab.icon)
                        .font(.system(size: 12, weight: .semibold))
                        .frame(width: 28, height: 22)
                        .background(vm.tab == tab ? Color.white.opacity(0.16) : .clear, in: Capsule())
                        .foregroundStyle(vm.tab == tab ? .white : .white.opacity(0.55))
                }
                .buttonStyle(.plain)
                .help(tab.title)
            }
            Spacer(minLength: vm.hasPhysicalNotch ? vm.notchSize.width + 12 : 12)
            if !vm.hasPhysicalNotch {
                Text(vm.tab.title).font(.system(size: 12, weight: .semibold)).opacity(0.7)
                Spacer(minLength: 12)
            }
            HeaderButton(icon: vm.pinned ? "pin.fill" : "pin", active: vm.pinned, help: vm.pinned ? "Unpin" : "Keep open") {
                vm.pinned.toggle()
            }
            HeaderButton(icon: "gearshape.fill", help: "Settings") {
                (NSApp.delegate as? AppDelegate)?.openSettings()
            }
        }
        .padding(.horizontal, 22)
    }

    @ViewBuilder private var content: some View {
        switch vm.tab {
        case .home: HomeView()
        case .tray: TrayView()
        case .timer: TimerView()
        case .clipboard: ClipboardView()
        case .notes: NotesView()
        case .chat: ChatView()
        }
    }
}

struct HeaderButton: View {
    var icon: String
    var active = false
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .frame(width: 24, height: 22)
                .foregroundStyle(active ? Color.accentColor : .white.opacity(0.6))
        }
        .buttonStyle(.plain)
        .help(help)
    }
}

// MARK: - Shared bits

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct AlbumArt: View {
    var image: NSImage?
    var size: CGFloat
    var corner: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(colors: [.pink, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
                    Image(systemName: "music.note").font(.system(size: size * 0.45, weight: .bold))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }
}

struct IconButton: View {
    var icon: String
    var size: CGFloat = 14
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size, weight: .semibold))
                .frame(width: size * 2, height: size * 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
