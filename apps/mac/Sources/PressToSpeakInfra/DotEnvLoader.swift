import Foundation

public enum DotEnvLoader {
    public static func load(url: URL) -> [String: String] {
        guard let data = try? Data(contentsOf: url),
              let file = String(data: data, encoding: .utf8) else {
            return [:]
        }

        var values: [String: String] = [:]

        for rawLine in file.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty || line.hasPrefix("#") {
                continue
            }

            let parts = line.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else {
                continue
            }

            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            var value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }

            values[key] = value
        }

        return values
    }

    public static func loadDefaultWorkingDirectoryEnv(fileManager: FileManager = .default) -> [String: String] {
        let url = URL(fileURLWithPath: fileManager.currentDirectoryPath)
            .appendingPathComponent(".env")
        return load(url: url)
    }
}
