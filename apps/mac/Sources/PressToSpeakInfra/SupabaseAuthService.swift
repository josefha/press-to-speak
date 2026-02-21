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
            return "Supabase configuration is missing. Set SUPABASE_URL and SUPABASE_PUBLISHABLE_KEY (or SUPABASE_ANON_KEY)."
        case .insecureConfiguration:
            return "Supabase URL must use HTTPS in non-local environments."
        case .invalidCredentials:
            return "Email and password are required."
        case .upstreamFailure(let statusCode, let message):
            return "Supabase auth failed (\(statusCode)): \(message)"
        case .invalidResponse:
            return "Supabase auth response was invalid."
        }
    }
}

public struct SupabaseAuthSession {
    public let accessToken: String
    public let refreshToken: String
    public let userID: String
    public let email: String?
    public let accessTokenExpiresAtEpochSeconds: Int?

    public init(
        accessToken: String,
        refreshToken: String,
        userID: String,
        email: String?,
        accessTokenExpiresAtEpochSeconds: Int?
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.userID = userID
        self.email = email
        self.accessTokenExpiresAtEpochSeconds = accessTokenExpiresAtEpochSeconds
    }
}

public enum SupabaseSignUpResult {
    case signedIn(SupabaseAuthSession)
    case requiresEmailConfirmation
}

private enum SupabaseTokenGrantType: String {
    case password
    case refreshToken = "refresh_token"
}

private extension SupabaseTokenGrantType {
    var queryItem: URLQueryItem {
        URLQueryItem(name: "grant_type", value: rawValue)
    }
}

public final class SupabaseAuthService {
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
            path: "/auth/v1/signup",
            body: [
                "email": normalizedEmail,
                "password": password
            ]
        )

        let authPayload = try decodeAuthPayload(payload)
        if let session = makeSession(from: authPayload) {
            return .signedIn(session)
        }

        return .requiresEmailConfirmation
    }

    public func signIn(email: String, password: String) async throws -> SupabaseAuthSession {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedEmail.isEmpty, !password.isEmpty else {
            throw SupabaseAuthError.invalidCredentials
        }

        let payload = try await request(
            method: "POST",
            path: "/auth/v1/token",
            queryItems: [SupabaseTokenGrantType.password.queryItem],
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
            path: "/auth/v1/token",
            queryItems: [SupabaseTokenGrantType.refreshToken.queryItem],
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

        _ = try? await request(method: "POST", path: "/auth/v1/logout", bearerToken: token)
    }

    private func request(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: [String: Any]? = nil,
        bearerToken: String? = nil
    ) async throws -> Data {
        guard
            let baseURL = configuration.supabaseURL,
            let clientKey = normalize(configuration.supabaseClientKey)
        else {
            throw SupabaseAuthError.missingConfiguration
        }

        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))),
            resolvingAgainstBaseURL: false
        ) else {
            throw SupabaseAuthError.missingConfiguration
        }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else {
            throw SupabaseAuthError.missingConfiguration
        }

        if !isSecureSupabaseURL(url) {
            throw SupabaseAuthError.insecureConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = configuration.requestTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue(clientKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(bearerToken ?? clientKey)", forHTTPHeaderField: "Authorization")

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

    private func extractErrorMessage(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                return text
            }
            return "Unknown Supabase auth error"
        }

        let keys = ["msg", "message", "error_description", "error"]
        for key in keys {
            if let value = object[key] as? String, !value.isEmpty {
                return value
            }
        }

        return "Unknown Supabase auth error"
    }

    private func decodeAuthPayload(_ payload: Data) throws -> SupabaseAuthResponse {
        let decoder = JSONDecoder()
        return try decoder.decode(SupabaseAuthResponse.self, from: payload)
    }

    private func makeSession(from payload: SupabaseAuthResponse) -> SupabaseAuthSession? {
        guard
            let accessToken = normalize(payload.accessToken),
            let refreshToken = normalize(payload.refreshToken),
            let userID = normalize(payload.user?.id)
        else {
            return nil
        }

        let expiresAtEpochSeconds: Int?
        if let explicitExpiry = payload.expiresAt, explicitExpiry > 0 {
            expiresAtEpochSeconds = explicitExpiry
        } else if let expiresIn = payload.expiresIn, expiresIn > 0 {
            let nowEpochSeconds = Int(Date().timeIntervalSince1970)
            expiresAtEpochSeconds = nowEpochSeconds + expiresIn
        } else {
            expiresAtEpochSeconds = nil
        }

        return SupabaseAuthSession(
            accessToken: accessToken,
            refreshToken: refreshToken,
            userID: userID,
            email: normalize(payload.user?.email),
            accessTokenExpiresAtEpochSeconds: expiresAtEpochSeconds
        )
    }

    private func normalize(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func isSecureSupabaseURL(_ url: URL) -> Bool {
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

private struct SupabaseAuthResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?
    let expiresAt: Int?
    let user: SupabaseUser?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case expiresAt = "expires_at"
        case user
    }
}

private struct SupabaseUser: Decodable {
    let id: String?
    let email: String?
}
