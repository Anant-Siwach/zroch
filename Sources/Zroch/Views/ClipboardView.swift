import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject var clip: ClipboardService
    @State private var mode = 0
    @State private var search = ""
    @State private var adding = false
    @State private var newTitle = ""
    @State private var newText = ""
    @State private var copiedID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("", selection: $mode) {
                    Text("History").tag(0)
                    Text("Snippets").tag(1)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 180)
                TextField("Search", text: $search)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                Spacer()
                if mode == 0 {
                    Button("Clear") { clip.clearHistory() }.controlSize(.small)
                } else {
                    Button { adding.toggle() } label: { Image(systemName: adding ? "xmark" : "plus") }
                        .controlSize(.small)
                }
            }

            if mode == 1 && adding {
                HStack(alignment: .top) {
                    TextField("Title", text: $newTitle).textFieldStyle(.roundedBorder).frame(width: 120)
                    TextField("Snippet text", text: $newText, axis: .vertical).textFieldStyle(.roundedBorder).lineLimit(1...3)
                    Button("Save") {
                        clip.addSnippet(title: newTitle, text: newText)
                        newTitle = ""; newText = ""; adding = false
                    }
                    .disabled(newText.isEmpty)
                }
                .controlSize(.small)
            }

            ScrollView {
                LazyVStack(spacing: 4) {
                    if mode == 0 {
                        ForEach(filteredHistory) { item in
                            ClipRow(text: item.text, subtitle: item.date.formatted(.relative(presentation: .named)),
                                    pinned: item.pinned, copied: copiedID == item.id) {
                                copy(item.text, id: item.id)
                            } onPin: {
                                clip.togglePin(item)
                            } onDelete: {
                                clip.delete(item)
                            }
                        }
                        if clip.history.isEmpty { empty("Copy some text and it will show up here.") }
                    } else {
                        ForEach(filteredSnippets) { s in
                            ClipRow(text: s.title, subtitle: s.text, pinned: nil, copied: copiedID == s.id) {
                                copy(s.text, id: s.id)
                            } onPin: {} onDelete: {
                                clip.deleteSnippet(s)
                            }
                        }
                        if clip.snippets.isEmpty { empty("Save text you use often, like addresses or replies.") }
                    }
                }
            }
        }
    }

    private var filteredHistory: [ClipItem] {
        let all = clip.sortedHistory
        return search.isEmpty ? all : all.filter { $0.text.localizedCaseInsensitiveContains(search) }
    }

    private var filteredSnippets: [Snippet] {
        search.isEmpty ? clip.snippets : clip.snippets.filter {
            $0.title.localizedCaseInsensitiveContains(search) || $0.text.localizedCaseInsensitiveContains(search)
        }
    }

    private func copy(_ text: String, id: UUID) {
        clip.copy(text)
        copiedID = id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { if copiedID == id { copiedID = nil } }
    }

    private func empty(_ msg: String) -> some View {
        Text(msg).font(.system(size: 11)).opacity(0.5).padding(.top, 20)
    }
}

private struct ClipRow: View {
    var text: String
    var subtitle: String
    var pinned: Bool?
    var copied: Bool
    var onCopy: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void
    @State private var hover = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(text.trimmingCharacters(in: .whitespacesAndNewlines))
                    .font(.system(size: 12)).lineLimit(1)
                Text(subtitle).font(.system(size: 9)).opacity(0.45).lineLimit(1)
            }
            Spacer()
            if copied {
                Label("Copied", systemImage: "checkmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(.green)
            } else if hover {
                if let pinned {
                    IconButton(icon: pinned ? "pin.slash" : "pin", size: 10, action: onPin)
                }
                IconButton(icon: "trash", size: 10, action: onDelete)
            } else if pinned == true {
                Image(systemName: "pin.fill").font(.system(size: 9)).opacity(0.6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.white.opacity(hover ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 8))
        .contentShape(Rectangle())
        .onHover { hover = $0 }
        .onTapGesture(perform: onCopy)
    }
}
