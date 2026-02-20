import Foundation

public struct AppConfiguration {
    public let elevenLabsAPIKey: String?
    public let elevenLabsBaseURL: URL
    public let elevenLabsModelID: String
    public let proxyURL: URL?
    public let proxyAPIKey: String?
    public let requestTimeoutSeconds: TimeInterval

    public init(processInfo: ProcessInfo = .processInfo, fileManager: FileManager = .default) {
        var dotenv: [String: String] = [:]

        if let bundleEnvURL = Bundle.main.url(forResource: "app", withExtension: "env") {
            dotenv.merge(DotEnvLoader.load(url: bundleEnvURL)) { _, new in new }
        }

        let workingDirectoryEnv = DotEnvLoader.loadDefaultWorkingDirectoryEnv(fileManager: fileManager)
        dotenv.merge(workingDirectoryEnv) { _, new in new }

        let env = AppConfiguration.resolveEnvironment(processEnvironment: processInfo.environment, dotenv: dotenv)

        self.elevenLabsAPIKey = env["ELEVENLABS_API_KEY"]
        self.elevenLabsBaseURL = URL(string: env["ELEVENLABS_API_BASE_URL"] ?? "https://api.elevenlabs.io")
            ?? URL(string: "https://api.elevenlabs.io")!
        self.elevenLabsModelID = env["ELEVENLABS_MODEL_ID"] ?? "scribe_v1"

        if let rawProxy = env["TRANSCRIPTION_PROXY_URL"], !rawProxy.isEmpty {
            self.proxyURL = URL(string: rawProxy)
        } else {
            self.proxyURL = nil
        }

        self.proxyAPIKey = env["TRANSCRIPTION_PROXY_API_KEY"]
        if let timeoutRaw = env["TRANSCRIPTION_REQUEST_TIMEOUT_SECONDS"],
           let timeout = TimeInterval(timeoutRaw),
           timeout > 0 {
            self.requestTimeoutSeconds = timeout
        } else {
            self.requestTimeoutSeconds = 45
        }
    }

    private static func resolveEnvironment(processEnvironment: [String: String], dotenv: [String: String]) -> [String: String] {
        var merged = dotenv
        for (key, value) in processEnvironment {
            merged[key] = value
        }
        return merged
    }
}
