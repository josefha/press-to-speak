import Combine
import Foundation

public struct TranscriptionHistoryItem: Codable, Identifiable, Equatable {
    public let id: UUID
    public let text: String
    public let createdAt: Date

    public init(id: UUID = UUID(), text: String, createdAt: Date = Date()) {
        self.id = id
        self.text = text
        self.createdAt = createdAt
    }
}

@MainActor
public final class TranscriptionHistoryStore: ObservableObject {
    @Published public private(set) var items: [TranscriptionHistoryItem]

    private let defaults: UserDefaults
    private let key = "pressToSpeak.transcriptionHistory"
    private let maxItems = 100

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: key),
           let decoded = try? JSONDecoder().decode([TranscriptionHistoryItem].self, from: data) {
            self.items = decoded
        } else {
            self.items = []
        }
    }

    public func add(text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return
        }

        items.insert(TranscriptionHistoryItem(text: trimmed), at: 0)

        if items.count > maxItems {
            items = Array(items.prefix(maxItems))
        }

        save()
    }

    public func clear() {
        items = []
        save()
    }

    private func save() {
        guard let encoded = try? JSONEncoder().encode(items) else {
            return
        }

        defaults.set(encoded, forKey: key)
    }
}
