import Foundation

public enum PressToSpeakAccountTier: String, Codable {
    case free
    case pro

    public var label: String {
        switch self {
        case .free:
            return "Free"
        case .pro:
            return "Pro"
        }
    }
}

public struct PressToSpeakAccountSession: Codable {
    public let accessToken: String
    public let refreshToken: String
    public let userID: String
    public let email: String?
    public let profileName: String?
    public let accountTier: PressToSpeakAccountTier?
    public let accessTokenExpiresAtEpochSeconds: Int?

    public init(
        accessToken: String,
        refreshToken: String,
        userID: String,
        email: String?,
        profileName: String?,
        accountTier: PressToSpeakAccountTier?,
        accessTokenExpiresAtEpochSeconds: Int?
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userID = userID
        self.email = email
        self.profileName = profileName
        self.accountTier = accountTier
        self.accessTokenExpiresAtEpochSeconds = accessTokenExpiresAtEpochSeconds
    }

    public var resolvedAccountTier: PressToSpeakAccountTier {
        accountTier ?? .free
    }

    public func shouldRefresh(leewaySeconds: Int = 60) -> Bool {
        guard let expiresAt = accessTokenExpiresAtEpochSeconds else {
            return false
        }

        let now = Int(Date().timeIntervalSince1970)
        return now + max(0, leewaySeconds) >= expiresAt
    }
}

public struct BringYourOwnProviderKeys {
    public let openAIAPIKey: String?
    public let elevenLabsAPIKey: String?

    public init(openAIAPIKey: String?, elevenLabsAPIKey: String?) {
        self.openAIAPIKey = openAIAPIKey
        self.elevenLabsAPIKey = elevenLabsAPIKey
    }
}

public final class CredentialVault {
    private enum Key {
        static let accountSession = "account.session"
        static let byokOpenAI = "byok.openai"
        static let byokElevenLabs = "byok.elevenlabs"
    }

    private let keychain: KeychainStore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(keychain: KeychainStore = KeychainStore()) {
        self.keychain = keychain
    }

    public func loadAccountSession() throws -> PressToSpeakAccountSession? {
        guard let raw = try keychain.get(Key.accountSession) else {
            return nil
        }

        guard let data = raw.data(using: .utf8) else {
            throw KeychainStoreError.invalidData
        }

        return try decoder.decode(PressToSpeakAccountSession.self, from: data)
    }

    public func saveAccountSession(_ session: PressToSpeakAccountSession) throws {
        let data = try encoder.encode(session)
        guard let payload = String(data: data, encoding: .utf8) else {
            throw KeychainStoreError.invalidData
        }

        try keychain.set(payload, for: Key.accountSession)
    }

    public func clearAccountSession() throws {
        try keychain.remove(Key.accountSession)
    }

    public func loadBringYourOwnProviderKeys() throws -> BringYourOwnProviderKeys {
        let openAI = try normalizeKeychainValue(keychain.get(Key.byokOpenAI))
        let elevenLabs = try normalizeKeychainValue(keychain.get(Key.byokElevenLabs))
        return BringYourOwnProviderKeys(openAIAPIKey: openAI, elevenLabsAPIKey: elevenLabs)
    }

    public func saveBringYourOwnProviderKeys(openAIAPIKey: String, elevenLabsAPIKey: String) throws {
        try keychain.set(openAIAPIKey, for: Key.byokOpenAI)
        try keychain.set(elevenLabsAPIKey, for: Key.byokElevenLabs)
    }

    public func clearBringYourOwnProviderKeys() throws {
        try keychain.remove(Key.byokOpenAI)
        try keychain.remove(Key.byokElevenLabs)
    }

    private func normalizeKeychainValue(_ value: String?) throws -> String? {
        guard let value else {
            return nil
        }

        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }
}
