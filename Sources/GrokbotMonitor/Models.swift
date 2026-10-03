import AppKit
import Foundation

enum BotState: String, Codable, Sendable {
    case active
    case needsYou
    case finished
    case failed
    case unread
    case idle

    var label: String {
        switch self {
        case .active: "Working"
        case .needsYou: "Needs you"
        case .finished: "Finished"
        case .failed: "Failed"
        case .unread: "Updated"
        case .idle: "Idle"
        }
    }
}

enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer()
        if value.decodeNil() { self = .null }
        else if let item = try? value.decode(Bool.self) { self = .bool(item) }
        else if let item = try? value.decode(Double.self) { self = .number(item) }
        else if let item = try? value.decode(String.self) { self = .string(item) }
        else if let item = try? value.decode([String: JSONValue].self) { self = .object(item) }
        else { self = .array(try value.decode([JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var value = encoder.singleValueContainer()
        switch self {
        case .string(let item): try value.encode(item)
        case .number(let item): try value.encode(item)
        case .bool(let item): try value.encode(item)
        case .object(let item): try value.encode(item)
        case .array(let item): try value.encode(item)
        case .null: try value.encodeNil()
        }
    }
}

struct RosterEnvelope: Decodable, Sendable {
    let schemaVersion: Int
    let value: RosterValue
}

struct RosterValue: Decodable, Sendable {
    let rows: [Grokbot]
}

struct Grokbot: Decodable, Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    let description: String?
    let title: String?
    let avatarShape: String?
    let avatarColor: String?
    let createdAt: Double?
    let updatedAt: Double?
    let lastActivityAt: Double?
    let localActivityAt: Double?
    let awaitingUserResponse: JSONValue?
    let hasUnread: Bool?
    let unreadCount: Int?
    let isHiddenFromSidebar: Bool?

    var activityDate: Date? {
        let timestamp = max(lastActivityAt ?? 0, localActivityAt ?? 0)
        guard timestamp > 0 else { return nil }
        return Date(timeIntervalSince1970: timestamp > 10_000_000_000 ? timestamp / 1_000 : timestamp)
    }

    var color: NSColor { AvatarPalette.color(named: avatarColor) }
}

struct BotPresentation: Identifiable, Equatable, Sendable {
    let bot: Grokbot
    var state: BotState
    var detail: String?
    var id: String { bot.id }
}

struct ActivityEvent: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let botID: String
    let botName: String
    let avatarColor: String?
    let avatarShape: String?
    let state: BotState
    let date: Date
    let detail: String?
}

struct UsageSnapshot: Codable, Equatable, Sendable {
    var percentUsed: Double
    var plan: String?
    var resetDescription: String?
    var resetDateDescription: String?
    var onDemandLimit: String?
    var capturedAt: Date

    var fractionUsed: Double { min(max(percentUsed / 100, 0), 1) }
    var percentLabel: String {
        percentUsed.formatted(.number.precision(.fractionLength(percentUsed < 10 ? 2 : 1))) + "%"
    }
}

enum AvatarPalette {
    static func color(named name: String?) -> NSColor {
        switch name?.lowercased() {
        case "red": .systemRed
        case "brown": NSColor(red: 0.61, green: 0.35, blue: 0.20, alpha: 1)
        case "orange": .systemOrange
        case "yellow": .systemYellow
        case "green": .systemGreen
        case "blue": .systemBlue
        case "purple": .systemPurple
        case "pink": .systemPink
        case "gray", "grey": .systemGray
        default: .black
        }
    }
}
