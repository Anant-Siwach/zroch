import SwiftUI

struct TrayView: View {
    @EnvironmentObject var tray: TrayService
    @EnvironmentObject var vm: NotchViewModel

    var body: some View {
        if tray.items.isEmpty {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                .foregroundStyle(.white.opacity(vm.dropTargeted ? 0.8 : 0.3))
                .overlay {
                    VStack(spacing: 6) {
                        Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 26))
                        Text("Drop files here").font(.system(size: 13, weight: .semibold))
                        Text("Keep files handy, then drag them out wherever you need them.")
                            .font(.system(size: 11)).opacity(0.55)
                    }
                }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(tray.items.count) item\(tray.items.count == 1 ? "" : "s")").font(.system(size: 11)).opacity(0.6)
                    Spacer()
                    Button { tray.airDrop(tray.items) } label: { Label("AirDrop All", systemImage: "airplayaudio") }
                    Button(role: .destructive) { withAnimation { tray.clear() } } label: { Label("Clear", systemImage: "trash") }
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(tray.items) { item in
                            TrayTile(item: item)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct TrayTile: View {
    @EnvironmentObject var tray: TrayService
    let item: TrayItem
    @State private var hover = false

    var body: some View {
        VStack(spacing: 6) {
            Image(nsImage: tray.icon(for: item))
                .resizable()
                .frame(width: 56, height: 56)
            Text(item.name)
                .font(.system(size: 10))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 84)
        }
        .padding(8)
        .background(Color.white.opacity(hover ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if hover {
                Button { withAnimation { tray.remove(item) } } label: {
                    Image(systemName: "xmark.circle.fill").font(.system(size: 14))
                }
                .buttonStyle(.plain)
                .offset(x: 4, y: -4)
            }
        }
        .onHover { hover = $0 }
        .onTapGesture(count: 2) { tray.open(item) }
        .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
        .contextMenu {
            Button("Open") { tray.open(item) }
            Button("Show in Finder") { tray.reveal(item) }
            Button("AirDrop") { tray.airDrop([item]) }
            Divider()
            Button("Remove from Tray") { tray.remove(item) }
        }
        .help(item.path)
    }
}
