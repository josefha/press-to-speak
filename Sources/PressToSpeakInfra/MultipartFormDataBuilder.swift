import Foundation

struct MultipartFormDataBuilder {
    let boundary: String
    private(set) var body = Data()

    init(boundary: String = "Boundary-\(UUID().uuidString)") {
        self.boundary = boundary
    }

    mutating func addField(name: String, value: String) {
        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        append(value)
        append("\r\n")
    }

    mutating func addFile(name: String, fileURL: URL, fileName: String? = nil, mimeType: String? = nil) throws {
        let data = try Data(contentsOf: fileURL)
        let resolvedFileName = fileName ?? fileURL.lastPathComponent
        let resolvedMimeType = mimeType ?? Self.mimeType(for: fileURL)

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(resolvedFileName)\"\r\n")
        append("Content-Type: \(resolvedMimeType)\r\n\r\n")
        body.append(data)
        append("\r\n")
    }

    mutating func build() -> Data {
        append("--\(boundary)--\r\n")
        return body
    }

    private mutating func append(_ value: String) {
        guard let data = value.data(using: .utf8) else {
            return
        }
        body.append(data)
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "m4a":
            return "audio/mp4"
        case "wav":
            return "audio/wav"
        case "mp3":
            return "audio/mpeg"
        case "aac":
            return "audio/aac"
        case "mp4":
            return "video/mp4"
        default:
            return "application/octet-stream"
        }
    }
}
