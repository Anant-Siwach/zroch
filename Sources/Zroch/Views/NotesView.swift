import AppKit
import SwiftUI

struct NotesView: View {
    @EnvironmentObject var store: NotesStore
    @StateObject private var editor = RichTextController()

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Notes").font(.system(size: 11, weight: .semibold)).opacity(0.6)
                    Spacer()
                    IconButton(icon: "square.and.pencil", size: 10) { store.add() }
                }
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(store.notes) { note in
                            Text(note.title)
                                .font(.system(size: 11))
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(store.selectedID == note.id ? Color.white.opacity(0.14) : .clear,
                                            in: RoundedRectangle(cornerRadius: 6))
                                .contentShape(Rectangle())
                                .onTapGesture { store.selectedID = note.id }
                                .contextMenu { Button("Delete Note") { store.delete(note) } }
                        }
                    }
                }
            }
            .frame(width: 140)

            VStack(spacing: 6) {
                HStack(spacing: 2) {
                    FormatButton(icon: "bold", help: "Bold (⌘B)") { editor.toggleTrait(.boldFontMask) }
                    FormatButton(icon: "italic", help: "Italic (⌘I)") { editor.toggleTrait(.italicFontMask) }
                    FormatButton(icon: "underline", help: "Underline (⌘U)") { editor.toggle(.underlineStyle) }
                    FormatButton(icon: "strikethrough", help: "Strikethrough") { editor.toggle(.strikethroughStyle) }
                    FormatButton(icon: "list.bullet", help: "Bulleted list") { editor.insertBullet() }
                    Spacer()
                    if let note = store.selected {
                        FormatButton(icon: "doc.on.doc", help: "Copy note") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(note.plainText, forType: .string)
                        }
                        FormatButton(icon: "trash", help: "Delete note") { store.delete(note) }
                    }
                }
                if let note = store.selected {
                    RichTextEditor(noteID: note.id, rtf: note.rtf, controller: editor) { data in
                        store.update(id: note.id, rtf: data)
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}

private struct FormatButton: View {
    var icon: String
    var help: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 11, weight: .semibold)).frame(width: 24, height: 20)
        }
        .buttonStyle(.plain)
        .opacity(0.8)
        .help(help)
    }
}

/// Holds the live NSTextView so toolbar buttons can format the selection.
final class RichTextController: ObservableObject {
    weak var textView: FormattingTextView?

    func toggleTrait(_ trait: NSFontTraitMask) { textView?.toggleTrait(trait) }
    func toggle(_ key: NSAttributedString.Key) { textView?.toggleLine(key) }
    func insertBullet() { textView?.insertText("• ", replacementRange: textView?.selectedRange() ?? NSRange()) }
}

final class FormattingTextView: NSTextView {
    static let baseFont = NSFont.systemFont(ofSize: 13)

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard flags == .command, window?.firstResponder === self else { return super.performKeyEquivalent(with: event) }
        switch event.charactersIgnoringModifiers {
        case "b": toggleTrait(.boldFontMask); return true
        case "i": toggleTrait(.italicFontMask); return true
        case "u": toggleLine(.underlineStyle); return true
        default: return super.performKeyEquivalent(with: event)
        }
    }

    func toggleTrait(_ trait: NSFontTraitMask) {
        let fm = NSFontManager.shared
        let range = selectedRange()
        guard let storage = textStorage else { return }
        if range.length == 0 {
            let font = typingAttributes[.font] as? NSFont ?? Self.baseFont
            let has = fm.traits(of: font).contains(trait)
            typingAttributes[.font] = has ? fm.convert(font, toNotHaveTrait: trait) : fm.convert(font, toHaveTrait: trait)
            return
        }
        let first = storage.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont ?? Self.baseFont
        let has = fm.traits(of: first).contains(trait)
        guard shouldChangeText(in: range, replacementString: nil) else { return }
        storage.beginEditing()
        storage.enumerateAttribute(.font, in: range) { value, sub, _ in
            let f = value as? NSFont ?? Self.baseFont
            storage.addAttribute(.font, value: has ? fm.convert(f, toNotHaveTrait: trait) : fm.convert(f, toHaveTrait: trait), range: sub)
        }
        storage.endEditing()
        didChangeText()
    }

    func toggleLine(_ key: NSAttributedString.Key) {
        let range = selectedRange()
        guard let storage = textStorage else { return }
        if range.length == 0 {
            let on = (typingAttributes[key] as? Int ?? 0) != 0
            typingAttributes[key] = on ? 0 : NSUnderlineStyle.single.rawValue
            return
        }
        let on = (storage.attribute(key, at: range.location, effectiveRange: nil) as? Int ?? 0) != 0
        guard shouldChangeText(in: range, replacementString: nil) else { return }
        if on {
            storage.removeAttribute(key, range: range)
        } else {
            storage.addAttribute(key, value: NSUnderlineStyle.single.rawValue, range: range)
        }
        didChangeText()
    }
}

struct RichTextEditor: NSViewRepresentable {
    let noteID: UUID
    let rtf: Data
    let controller: RichTextController
    let onChange: (Data) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true

        let tv = FormattingTextView()
        tv.isRichText = true
        tv.allowsUndo = true
        tv.drawsBackground = false
        tv.textColor = .white
        tv.insertionPointColor = .white
        tv.font = FormattingTextView.baseFont
        tv.typingAttributes = [.font: FormattingTextView.baseFont, .foregroundColor: NSColor.white]
        tv.isVerticallyResizable = true
        tv.isHorizontallyResizable = false
        tv.autoresizingMask = [.width]
        tv.textContainer?.widthTracksTextView = true
        tv.textContainerInset = NSSize(width: 0, height: 2)
        tv.delegate = context.coordinator
        scroll.documentView = tv
        controller.textView = tv
        context.coordinator.load(tv)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let tv = scroll.documentView as? FormattingTextView else { return }
        controller.textView = tv
        if context.coordinator.loadedID != noteID { context.coordinator.load(tv) }
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: RichTextEditor
        var loadedID: UUID?

        init(_ parent: RichTextEditor) { self.parent = parent }

        func load(_ tv: NSTextView) {
            loadedID = parent.noteID
            let attr = NSMutableAttributedString(rtf: parent.rtf, documentAttributes: nil) ?? NSMutableAttributedString()
            let full = NSRange(location: 0, length: attr.length)
            attr.addAttribute(.foregroundColor, value: NSColor.white, range: full)
            tv.textStorage?.setAttributedString(attr)
            tv.typingAttributes = [.font: FormattingTextView.baseFont, .foregroundColor: NSColor.white]
        }

        func textDidChange(_ notification: Notification) {
            guard let tv = notification.object as? NSTextView, let storage = tv.textStorage else { return }
            let range = NSRange(location: 0, length: storage.length)
            if let data = storage.rtf(from: range, documentAttributes: [:]) { parent.onChange(data) }
        }
    }
}
