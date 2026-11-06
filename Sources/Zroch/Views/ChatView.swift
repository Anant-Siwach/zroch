import SwiftUI

struct ChatView: View {
    @EnvironmentObject var ai: AIService
    @State private var input = ""

    var body: some View {
        VStack(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        if ai.messages.isEmpty {
                            VStack(spacing: 6) {
                                Image(systemName: "sparkles").font(.system(size: 22))
                                Text("Chat with Apple Intelligence").font(.system(size: 13, weight: .semibold))
                                Text(ai.unavailableReason ?? "Runs on-device. Private, and no internet needed.")
                                    .font(.system(size: 11)).opacity(0.55)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 14)
                        }
                        ForEach(ai.messages) { msg in
                            Bubble(message: msg).id(msg.id)
                        }
                        if ai.busy {
                            ProgressView().controlSize(.small).padding(.leading, 6).id("busy")
                        }
                    }
                }
                .onChange(of: ai.messages) { _, msgs in
                    if let last = msgs.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            HStack(spacing: 8) {
                TextField("Ask anything…", text: $input)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08), in: Capsule())
                    .onSubmit(send)
                IconButton(icon: "arrow.up.circle.fill", size: 14, action: send)
                    .disabled(input.isEmpty || ai.busy)
                if !ai.messages.isEmpty {
                    IconButton(icon: "arrow.counterclockwise", size: 11) { ai.reset() }
                        .help("New chat")
                }
            }
        }
    }

    private func send() {
        ai.send(input)
        input = ""
    }
}

private struct Bubble: View {
    let message: AIService.Message

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }
            Text(message.text)
                .font(.system(size: 12))
                .textSelection(.enabled)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(background, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            if message.role != .user { Spacer(minLength: 60) }
        }
    }

    private var background: Color {
        switch message.role {
        case .user: .accentColor.opacity(0.75)
        case .assistant: .white.opacity(0.1)
        case .error: .red.opacity(0.35)
        }
    }
}
