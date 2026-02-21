import Foundation

public enum AppLogger {
    private static let queue = DispatchQueue(label: "PressToSpeak.AppLogger")
    private static let dateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    public static var logFileURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library")
            .appendingPathComponent("Logs")
            .appendingPathComponent("PressToSpeak")
            .appendingPathComponent("app.log")
    }

    public static func log(_ message: String) {
        queue.async {
            let timestamp = dateFormatter.string(from: Date())
            let line = "[\(timestamp)] \(message)\n"

            let url = logFileURL
            let directory = url.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

                let data = Data(line.utf8)
                if FileManager.default.fileExists(atPath: url.path) {
                    let handle = try FileHandle(forWritingTo: url)
                    try handle.seekToEnd()
                    handle.write(data)
                    try handle.close()
                } else {
                    try data.write(to: url)
                }
            } catch {
                // Intentionally swallow logging errors.
            }
        }
    }
}
