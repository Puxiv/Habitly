import Foundation

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let role: Role
    let content: String
    let timestamp = Date()
    var toolActions: [ToolAction] = []

    enum Role {
        case user
        case assistant
    }

    // MARK: - Tool Action (confirmation card data)

    struct ToolAction: Identifiable {
        let id = UUID()
        let type: ActionType
        let title: String
        let emoji: String
        let subtitle: String

        enum ActionType {
            case reminderCreated
            case noteCreated
            case habitCreated
        }
    }
}
