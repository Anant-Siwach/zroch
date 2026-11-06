import AppKit

struct Note: Codable, Identifiable, Hashable {
    var id = UUID()
    var rtf: Data
    var updated = Date()

    var plainText: String {
        NSAttributedString(rtf: rtf, documentAttributes: nil)?.string ?? ""
    }

    var title: String {
        let first = plainText.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let t = first.trimmingCharacters(in: .whitespaces)
        return t.isEmpty ? "New Note" : t
    }
}

/// Rich-text notes persisted as RTF.
final class NotesStore: ObservableObject {
    static let shared = NotesStore()

    @Published var notes: [Note]
    @Published var selectedID: UUID?
    private var saveWork: DispatchWorkItem?

    init() {
        notes = Storage.load([Note].self, from: "notes.json") ?? []
        if notes.isEmpty { notes = [Note(rtf: Self.emptyRTF)] }
        selectedID = notes.first?.id
    }

    static var emptyRTF: Data {
        let s = NSAttributedString(string: "")
        return s.rtf(from: NSRange(location: 0, length: 0), documentAttributes: [:]) ?? Data()
    }

    var selected: Note? { notes.first { $0.id == selectedID } }

    func add() {
        let note = Note(rtf: Self.emptyRTF)
        notes.insert(note, at: 0)
        selectedID = note.id
        save()
    }

    func delete(_ note: Note) {
        notes.removeAll { $0.id == note.id }
        if notes.isEmpty { notes = [Note(rtf: Self.emptyRTF)] }
        if selectedID == note.id { selectedID = notes.first?.id }
        save()
    }

    func update(id: UUID, rtf: Data) {
        guard let i = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[i].rtf = rtf
        notes[i].updated = Date()
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func save() { Storage.save(notes, to: "notes.json") }
}
