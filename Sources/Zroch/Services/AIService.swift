import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

/// On-device chat with Apple Intelligence (Foundation Models, macOS 26+).
final class AIService: ObservableObject {
    static let shared = AIService()

    struct Message: Identifiable, Hashable {
        enum Role { case user, assistant, error }
        let id = UUID()
        let role: Role
        var text: String
    }

    @Published var messages: [Message] = []
    @Published var busy = false
    private var session: AnyObject?

    private let instructions = """
    You are Zroch, a friendly assistant that lives in the Mac's notch. \
    Answer concisely, in a few sentences unless the user asks for more.
    """

    /// nil when the model is ready, otherwise a human-readable reason.
    var unavailableReason: String? {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available: return nil
            case .unavailable(let reason):
                switch reason {
                case .deviceNotEligible: return "This Mac doesn't support Apple Intelligence."
                case .appleIntelligenceNotEnabled: return "Turn on Apple Intelligence in System Settings to chat."
                case .modelNotReady: return "Apple Intelligence is still downloading. Try again soon."
                @unknown default: return "Apple Intelligence is unavailable."
                }
            }
        }
        #endif
        return "AI chat needs macOS 26 with Apple Intelligence."
    }

    func send(_ text: String) {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, !busy else { return }
        messages.append(Message(role: .user, text: prompt))
        if let reason = unavailableReason {
            messages.append(Message(role: .error, text: reason))
            return
        }
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            busy = true
            let s = (session as? LanguageModelSession) ?? LanguageModelSession(instructions: instructions)
            session = s
            Task { @MainActor in
                do {
                    let response = try await s.respond(to: prompt)
                    messages.append(Message(role: .assistant, text: response.content))
                } catch {
                    messages.append(Message(role: .error, text: error.localizedDescription))
                    session = nil
                }
                busy = false
            }
        }
        #endif
    }

    func reset() {
        messages.removeAll()
        session = nil
    }
}
