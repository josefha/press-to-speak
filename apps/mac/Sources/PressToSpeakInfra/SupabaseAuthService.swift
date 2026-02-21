import Foundation

public enum SupabaseAuthError: LocalizedError {
    case missingConfiguration
    case insecureConfiguration
    case invalidCredentials
    case upstreamFailure(statusCode: Int, message: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Account auth configuration is missing. Set TRANSCRIPTION_PROXY_URL."
        case .insecureConfiguration:
            return "Proxy URL must use HTTPS in non-local environments."
        case .invalidCredentials:
            return "Email and password are required."
        case .upstreamFailure(let statusCode, let message):
            return "Account auth failed (\(statusCode)): \(message)"
        case .invalidResponse:
            return "Account auth response was invalid."
        }
    }
}

public struct SupabaseAuthSession {
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
}

public enum SupabaseSignUpResult {
    case signedIn(SupabaseAuthSession)
    case requiresEmailConfirmation
}

public protocol PressToSpeakAccountAuthServicing {
    func signUp(email: String, password: String) async throws -> SupabaseSignUpResult
    func signIn(email: String, password: String) async throws -> SupabaseAuthSession
    func refreshSession(refreshToken: String) async throws -> SupabaseAuthSession
    func signOut(accessToken: String) async
}

public final class SupabaseAuthService: PressToSpeakAccountAuthServicing {
    private let configuration: AppConfiguration
    private let session: URLSession

    public init(configuration: AppConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func signUp(email: String, password: String) async throws -> SupabaseSignUpResult {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            throw SupabaseAuthError.invalidCredentials
        }

        let payload = try await request(
            method: "POST",
            path: "auth/signup",
            body: [
                "email": normalizedEmail,
                "password": password
            ]
        )

        let authPayload = try decodeAuthPayload(payload)
        if let session = makeSession(from: authPayload) {
            return .signedIn(session)
        }

        if authPayload.requiresEmailConfirmation == true {
            return .requiresEmailConfirmation
        }

        throw SupabaseAuthError.invalidResponse
    }

    public func signIn(email: String, password: String) async throws -> SupabaseAuthSession {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            throw SupabaseAuthError.invalidCredentials
        }

        let payload = try await request(
            method: "POST",
            path: "auth/login",
            body: [
                "email": normalizedEmail,
                "password": password
            ]
        )

        let authPayload = try decodeAuthPayload(payload)
        guard let session = makeSession(from: authPayload) else {
            throw SupabaseAuthError.invalidResponse
        }

        return session
    }

    public func refreshSession(refreshToken: String) async throws -> SupabaseAuthSession {
        let normalizedRefreshToken = refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedRefreshToken.isEmpty else {
            throw SupabaseAuthError.invalidResponse
        }

        let payload = try await request(
            method: "POST",
            path: "auth/refresh",
            body: [
                "refresh_token": normalizedRefreshToken
            ]
        )

        let authPayload = try decodeAuthPayload(payload)
        guard let session = makeSession(from: authPayload) else {
            throw SupabaseAuthError.invalidResponse
        }

        return session
    }

    public func signOut(accessToken: String) async {
        let token = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            return
        }

        _ = try? await request(method: "POST", path: "auth/logout", bearerToken: token)
    }

    private func request(
        method: String,
        path: String,
        body: [String: Any]? = nil,
        bearerToken: String? = nil
    ) async throws -> Data {
        let url = try makeProxyAuthURL(path: path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = configuration.requestTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let proxyKey = normalize(configuration.proxyAPIKey) {
            request.setValue(proxyKey, forHTTPHeaderField: "x-api-key")
        }

        if let bearerToken = normalize(bearerToken) {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw SupabaseAuthError.invalidResponse
        }

        guard (200...299).contains(http.statusCode) else {
            throw SupabaseAuthError.upstreamFailure(
                statusCode: http.statusCode,
                message: extractErrorMessage(from: data)
            )
        }

        return data
    }

    private func makeProxyAuthURL(path: String) throws -> URL {
        guard let proxyURL = configuration.proxyURL else {
            throw SupabaseAuthError.missingConfiguration
        }

        if !isSecureProxyURL(proxyURL) {
            throw SupabaseAuthError.insecureConfiguration
        }

        guard var components = URLComponents(url: proxyURL, resolvingAgainstBaseURL: false) else {
            throw SupabaseAuthError.missingConfiguration
        }

        components.query = nil
        components.fragment = nil

        var basePath = components.path
        while basePath.count > 1, basePath.hasSuffix("/") {
            basePath.removeLast()
        }

        if basePath.hasSuffix("/voice-to-text") {
            basePath.removeLast("/voice-to-text".count)
        }

        if basePath.isEmpty {
            basePath = "/"
        }

        let endpointPath = normalizePath(path)
        if endpointPath.isEmpty {
            throw SupabaseAuthError.missingConfiguration
        }

        if basePath == "/" {
            components.path = "/\(endpointPath)"
        } else {
            components.path = "\(basePath)/\(endpointPath)"
        }

        guard let endpointURL = components.url else {
            throw SupabaseAuthError.missingConfiguration
        }

        return endpointURL
    }

    private func extractErrorMessage(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                return text
            }
            return "Unknown account auth error"
        }

        if let errorObject = object["error"] as? [String: Any] {
            let nestedKeys = ["message", "detail", "reason"]
            for key in nestedKeys {
                if let value = errorObject[key] as? String, !value.isEmpty {
                    return value
                }
            }
        }

        let keys = ["message", "detail", "error", "msg"]
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
        }

        return "Unknown account auth error"
    }

    private func decodeAuthPayload(_ payload: Data) throws -> ProxyAuthResponse {
        let decoder = JSONDecoder()
        return try decoder.decode(ProxyAuthResponse.self, from: payload)
    }

    private func makeSession(from payload: ProxyAuthResponse) -> SupabaseAuthSession? {
        guard
            let account = payload.account,
            let tokenSession = payload.session,
            let accessToken = normalize(tokenSession.accessToken),
            let refreshToken = normalize(tokenSession.refreshToken),
            let userID = normalize(account.userID)
        else {
            return nil
        }

        return SupabaseAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userID: userID,
            email: normalize(account.email),
            profileName: normalize(account.profileName),
            accountTier: normalizeTier(account.tier),
            accessTokenExpiresAtEpochSeconds: tokenSession.expiresAt
        )
    }

    private func normalize(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizePath(_ path: String) -> String {
        path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func normalizeTier(_ value: String?) -> PressToSpeakAccountTier? {
        guard let value else {
            return nil
        }

        switch value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "pro":
            return .pro
        case "free":
            return .free
        default:
            return nil
        }
    }

    private func isSecureProxyURL(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else {
            return false
        }

        if scheme == "https" {
            return true
        }

        if scheme == "http" {
            let host = (url.host ?? "").lowercased()
            return host == "localhost" || host == "127.0.0.1" || host == "::1"
        }

        return false
    }
}

private struct ProxyAuthResponse: Decodable {
    let account: ProxyAuthAccount?
    let session: ProxyAuthSessionPayload?
    let requiresEmailConfirmation: Bool?

    enum CodingKeys: String, CodingKey {
        case account
        case session
        case requiresEmailConfirmation = "requires_email_confirmation"
    }
}

private struct ProxyAuthAccount: Decodable {
    let userID: String?
    let email: String?
    let profileName: String?
    let tier: String?

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case email
        case profileName = "profile_name"
        case tier
    }
}

private struct ProxyAuthSessionPayload: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresAt: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresAt = "expires_at"
    }
}
