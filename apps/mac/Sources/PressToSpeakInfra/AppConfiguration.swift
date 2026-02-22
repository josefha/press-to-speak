import Foundation

public struct AppConfiguration {
    public let elevenLabsAPIKey: String?
    public let elevenLabsBaseURL: URL
    public let elevenLabsModelID: String
    public let proxyURL: URL?
    public let proxyAPIKey: String?
    public let supabaseURL: URL?
    public let supabasePublishableKey: String?
    public let requestTimeoutSeconds: TimeInterval

    public init(processInfo: ProcessInfo = .processInfo, fileManager: FileManager = .default) {
        var dotenv: [String: String] = [:]

        if let bundleEnvURL = Bundle.main.url(forResource: "app", withExtension: "env") {
            dotenv.merge(DotEnvLoader.load(url: bundleEnvURL)) { _, new in new }
        }

        if AppConfiguration.shouldLoadWorkingDirectoryEnv(processEnvironment: processInfo.environment) {
            let workingDirectoryEnv = DotEnvLoader.loadDefaultWorkingDirectoryEnv(fileManager: fileManager)
            dotenv.merge(workingDirectoryEnv) { _, new in new }
        }

        let env = AppConfiguration.resolveEnvironment(processEnvironment: processInfo.environment, dotenv: dotenv)

        self.elevenLabsAPIKey = env["ELEVENLABS_API_KEY"]
        self.elevenLabsBaseURL = URL(string: env["ELEVENLABS_API_BASE_URL"] ?? "https://api.elevenlabs.io")
            ?? URL(string: "https://api.elevenlabs.io")!
        self.elevenLabsModelID = env["ELEVENLABS_MODEL_ID"] ?? "scribe_v2"

        if let rawProxy = env["TRANSCRIPTION_PROXY_URL"], !rawProxy.isEmpty {
            self.proxyURL = URL(string: rawProxy)
        } else {
            self.proxyURL = nil
        }

        self.proxyAPIKey = env["TRANSCRIPTION_PROXY_API_KEY"]

        if let rawSupabaseURL = env["SUPABASE_URL"], !rawSupabaseURL.isEmpty {
            self.supabaseURL = URL(string: rawSupabaseURL)
        } else {
            self.supabaseURL = nil
        }

        self.supabasePublishableKey = AppConfiguration.normalized(env["SUPABASE_PUBLISHABLE_KEY"])

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

    private static func normalized(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func shouldLoadWorkingDirectoryEnv(processEnvironment: [String: String]) -> Bool {
        if let rawOverride = processEnvironment["PRESS_TO_SPEAK_LOAD_WORKING_DIR_ENV"] {
            let normalized = rawOverride.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if normalized == "1" || normalized == "true" || normalized == "yes" || normalized == "on" {
                return true
            }
            if normalized == "0" || normalized == "false" || normalized == "no" || normalized == "off" {
                return false
            }
        }

        // Bundled .app installs should avoid probing current working directory paths
        // (for example Desktop/Documents) to prevent unnecessary TCC file prompts.
        return !Bundle.main.bundlePath.hasSuffix(".app")
    }
}
