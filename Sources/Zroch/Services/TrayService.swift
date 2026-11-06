import AppKit
import UniformTypeIdentifiers

struct TrayItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var path: String
    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
}

/// A shelf of files dropped onto the notch. Holds references; files are not moved.
final class TrayService: ObservableObject {
    static let shared = TrayService()

    @Published var items: [TrayItem] = (Storage.load([TrayItem].self, from: "tray.json") ?? [])
        .filter { FileManager.default.fileExists(atPath: $0.path) }

    func add(providers: [NSItemProvider]) {
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                guard let url else { return }
                DispatchQueue.main.async { self?.add(url) }
            }
        }
    }

    func add(_ url: URL) {
        guard !items.contains(where: { $0.path == url.path }) else { return }
        items.append(TrayItem(path: url.path))
        save()
    }

    func remove(_ item: TrayItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items.removeAll()
        save()
    }

    func open(_ item: TrayItem) { NSWorkspace.shared.open(item.url) }
    func reveal(_ item: TrayItem) { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }

    func airDrop(_ items: [TrayItem]) {
        NSSharingService(named: .sendViaAirDrop)?.perform(withItems: items.map(\.url))
    }

    func icon(for item: TrayItem) -> NSImage { NSWorkspace.shared.icon(forFile: item.path) }

    private func save() { Storage.save(items, to: "tray.json") }
}
