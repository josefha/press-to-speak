import Foundation

public enum AppUpdateServiceError: LocalizedError {
    case missingConfiguration
    case insecureConfiguration
    case invalidResponse
    case upstreamFailure(statusCode: Int, message: String)

    public var errorDescription: String? {
        switch self {
        case .missingConfiguration:
            return "Update check configuration is missing. Set TRANSCRIPTION_PROXY_URL."
        case .insecureConfiguration:
            return "Proxy URL must use HTTPS in non-local environments."
        case .invalidResponse:
            return "Update check response was invalid."
        case .upstreamFailure(let statusCode, let message):
            return "Update check failed (\(statusCode)): \(message)"
        }
    }
}

public struct AppUpdateInfo {
    public let latestVersion: String
    public let minimumSupportedVersion: String
    public let updateAvailable: Bool?
    public let updateRequired: Bool?
    public let downloadURL: URL?
    public let releaseNotesURL: URL?

    public init(
        latestVersion: String,
        minimumSupportedVersion: String,
        updateAvailable: Bool?,
        updateRequired: Bool?,
        downloadURL: URL?,
        releaseNotesURL: URL?
    ) {
        self.latestVersion = latestVersion
        self.minimumSupportedVersion = minimumSupportedVersion
        self.updateAvailable = updateAvailable
        self.updateRequired = updateRequired
        self.downloadURL = downloadURL
        self.releaseNotesURL = releaseNotesURL
    }
}

public protocol AppUpdateChecking {
    func fetchLatestUpdate(currentVersion: String?) async throws -> AppUpdateInfo
}

public final class AppUpdateService: AppUpdateChecking {
    private let configuration: AppConfiguration
    private let session: URLSession

    public init(configuration: AppConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func fetchLatestUpdate(currentVersion: String?) async throws -> AppUpdateInfo {
        let endpointURL = try makeUpdateURL(currentVersion: currentVersion)

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "GET"
        request.timeoutInterval = configuration.requestTimeoutSeconds
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        if let proxyAPIKey = normalize(configuration.proxyAPIKey) {
            request.setValue(proxyAPIKey, forHTTPHeaderField: "x-api-key")
        }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdateServiceError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppUpdateServiceError.upstreamFailure(
                statusCode: httpResponse.statusCode,
                message: extractErrorMessage(from: data)
            )
        }

        let decoder = JSONDecoder()
        guard let payload = try? decoder.decode(ProxyAppUpdateResponse.self, from: data) else {
            throw AppUpdateServiceError.invalidResponse
        }

        guard
            let latestVersion = normalize(payload.latestVersion),
            let minimumSupportedVersion = normalize(payload.minimumSupportedVersion)
        else {
            throw AppUpdateServiceError.invalidResponse
        }

        return AppUpdateInfo(
            latestVersion: latestVersion,
            minimumSupportedVersion: minimumSupportedVersion,
            updateAvailable: payload.updateAvailable,
            updateRequired: payload.updateRequired,
            downloadURL: normalizeSafeHTTPURL(payload.downloadURL),
            releaseNotesURL: normalizeSafeHTTPURL(payload.releaseNotesURL)
        )
    }

    private func makeUpdateURL(currentVersion: String?) throws -> URL {
        guard let proxyURL = configuration.proxyURL else {
            throw AppUpdateServiceError.missingConfiguration
        }

        if !isSecureProxyURL(proxyURL) {
            throw AppUpdateServiceError.insecureConfiguration
        }

        guard var components = URLComponents(url: proxyURL, resolvingAgainstBaseURL: false) else {
            throw AppUpdateServiceError.missingConfiguration
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

        let updatePath = "v1/app-updates/macos"
        if basePath == "/" {
            components.path = "/\(updatePath)"
        } else {
            components.path = "\(basePath)/\(updatePath)"
        }

        if let currentVersion = normalizeVersion(currentVersion) {
            components.queryItems = [URLQueryItem(name: "current_version", value: currentVersion)]
        } else {
            components.queryItems = nil
        }

        guard let endpointURL = components.url else {
            throw AppUpdateServiceError.missingConfiguration
        }

        return endpointURL
    }

    private func normalize(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return normalized.isEmpty ? nil : normalized
    }

    private func normalizeVersion(_ value: String?) -> String? {
        guard let normalized = normalize(value) else {
            return nil
        }

        if normalized.count > 32 {
            return nil
        }

        let allowed = CharacterSet(charactersIn: "0123456789.")
        if normalized.rangeOfCharacter(from: allowed.inverted) != nil {
            return nil
        }

        return normalized
    }

    private func normalizeSafeHTTPURL(_ value: String?) -> URL? {
        guard let normalized = normalize(value) else {
            return nil
        }

        guard let url = URL(string: normalized), isSecureProxyURL(url) else {
            return nil
        }

        return url
    }

    private func extractErrorMessage(from data: Data) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                return text
            }
            return "Unknown update check error"
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

        return "Unknown update check error"
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

private struct ProxyAppUpdateResponse: Decodable {
    let latestVersion: String?
    let minimumSupportedVersion: String?
    let updateAvailable: Bool?
    let updateRequired: Bool?
    let downloadURL: String?
    let releaseNotesURL: String?

    enum CodingKeys: String, CodingKey {
        case latestVersion = "latest_version"
        case minimumSupportedVersion = "minimum_supported_version"
        case updateAvailable = "update_available"
        case updateRequired = "update_required"
        case downloadURL = "download_url"
        case releaseNotesURL = "release_notes_url"
    }
}
