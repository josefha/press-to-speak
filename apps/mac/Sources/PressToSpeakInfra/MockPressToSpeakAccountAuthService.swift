import Foundation

public final class MockPressToSpeakAccountAuthService: PressToSpeakAccountAuthServicing {
    private let simulatedLatencyNanoseconds: UInt64

    public init(simulatedLatencyNanoseconds: UInt64 = 200_000_000) {
        self.simulatedLatencyNanoseconds = simulatedLatencyNanoseconds
    }

    public func signUp(email: String, password: String) async throws -> SupabaseSignUpResult {
        try validateCredentials(email: email, password: password)
        try await Task.sleep(nanoseconds: simulatedLatencyNanoseconds)
        return .signedIn(makeSession(email: email))
    }

    public func signIn(email: String, password: String) async throws -> SupabaseAuthSession {
        try validateCredentials(email: email, password: password)
        try await Task.sleep(nanoseconds: simulatedLatencyNanoseconds)
        return makeSession(email: email)
    }

    public func refreshSession(refreshToken: String) async throws -> SupabaseAuthSession {
        let normalizedRefreshToken = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRefreshToken.isEmpty else {
            throw SupabaseAuthError.invalidResponse
        }

        try await Task.sleep(nanoseconds: simulatedLatencyNanoseconds)
        return makeSession(email: nil)
    }

    public func signOut(accessToken: String) async {
        _ = accessToken
    }

    private func validateCredentials(email: String, password: String) throws {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalizedEmail.contains("@"), normalizedEmail.contains("."), password.count >= 8 else {
            throw SupabaseAuthError.invalidCredentials
        }
    }

    private func makeSession(email: String?) -> SupabaseAuthSession {
        let now = Int(Date().timeIntervalSince1970)
        let userID = "mock-user-\(UUID().uuidString.lowercased())"
        let profileName = deriveProfileName(from: email)
        let tier = deriveTier(from: email)

        return SupabaseAuthSession(
            accessToken: "mock-access-\(UUID().uuidString.lowercased())",
            refreshToken: "mock-refresh-\(UUID().uuidString.lowercased())",
            userID: userID,
            email: email,
            profileName: profileName,
            accountTier: tier,
            accessTokenExpiresAtEpochSeconds: now + (30 * 24 * 3600)
        )
    }

    private func deriveProfileName(from email: String?) -> String? {
        guard let email else {
            return "PressToSpeak User"
        }

        let localPart = email.split(separator: "@").first.map(String.init) ?? email
        let normalized = localPart.replacingOccurrences(of: ".", with: " ")
        let trimmed = normalized.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "PressToSpeak User"
        }

        return trimmed
            .split(separator: " ")
            .map { segment in
                segment.prefix(1).uppercased() + segment.dropFirst().lowercased()
            }
            .joined(separator: " ")
    }

    private func deriveTier(from email: String?) -> PressToSpeakAccountTier {
        let normalized = email?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if normalized.contains("+pro@") || normalized.hasSuffix(".pro") {
            return .pro
        }

        return .free
    }
}
