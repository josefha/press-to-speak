import Foundation
import PressToSpeakCore

public enum ElevenLabsProviderError: LocalizedError {
    case missingAPIKey
    case invalidEndpoint
    case failedToReadAudioFile
    case upstreamFailure(statusCode: Int, message: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Missing ELEVENLABS_API_KEY. Add it to your environment or .env file."
        case .invalidEndpoint:
            return "Invalid ElevenLabs API base URL."
        case .failedToReadAudioFile:
            return "Unable to read recorded audio file for upload."
        case .upstreamFailure(let statusCode, let message):
            return "ElevenLabs request failed (\(statusCode)): \(message)"
        case .invalidResponse:
            return "ElevenLabs response did not contain a transcription text payload."
        }
    }
}

public final class ElevenLabsTranscriptionProvider: TranscriptionProvider {
    private let configuration: AppConfiguration
    private let session: URLSession

    public init(configuration: AppConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        guard let key = configuration.elevenLabsAPIKey, !key.isEmpty else {
            throw ElevenLabsProviderError.missingAPIKey
        }

        let endpoint = configuration.elevenLabsBaseURL.appending(path: "v1/speech-to-text")
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw ElevenLabsProviderError.invalidEndpoint
        }

        components.queryItems = [
            URLQueryItem(name: "enable_logging", value: "true")
        ]

        guard let url = components.url else {
            throw ElevenLabsProviderError.invalidEndpoint
        }

        var form = MultipartFormDataBuilder()
        form.addField(name: "model_id", value: configuration.elevenLabsModelID)

        if let languageCode = normalizedLanguageCode(request.locale) {
            form.addField(name: "language_code", value: languageCode)
        }

        let keyterms = Array(Set(request.vocabularyHints))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(100)

        for keyterm in keyterms {
            form.addField(name: "keyterms", value: keyterm)
        }

        form.addField(name: "timestamps_granularity", value: "none")
        form.addField(name: "tag_audio_events", value: "false")

        do {
            try form.addFile(name: "file", fileURL: request.audioFileURL)
        } catch {
            throw ElevenLabsProviderError.failedToReadAudioFile
        }

        let body = form.build()

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.requestTimeoutSeconds
        urlRequest.setValue(key, forHTTPHeaderField: "xi-api-key")
        urlRequest.setValue("multipart/form-data; boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")
        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ElevenLabsProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = Self.extractErrorMessage(from: data)
            throw ElevenLabsProviderError.upstreamFailure(statusCode: httpResponse.statusCode, message: message)
        }

        if httpResponse.statusCode == 202 {
            throw ElevenLabsProviderError.invalidResponse
        }

        let decoder = JSONDecoder()
        if let single = try? decoder.decode(SingleChannelSpeechResponse.self, from: data) {
            return TranscriptionResult(text: single.text)
        }

        if let multi = try? decoder.decode(MultiChannelSpeechResponse.self, from: data) {
            let text = multi.transcripts
                .map(\.text)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            if !text.isEmpty {
                return TranscriptionResult(text: text)
            }
        }

        throw ElevenLabsProviderError.invalidResponse
    }

    private func normalizedLanguageCode(_ value: String?) -> String? {
        guard let value else {
            return nil
        }

        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        // ElevenLabs accepts ISO-639 codes. If the user provides "en-US", use "en".
        if let first = trimmed.split(separator: "-").first {
            return String(first)
        }

        return trimmed
    }

    private static func extractErrorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = object["message"] as? String, !message.isEmpty {
                return message
            }
            if let detail = object["detail"] as? String, !detail.isEmpty {
                return detail
            }
            if let error = object["error"] as? String, !error.isEmpty {
                return error
            }
        }

        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }

        return "Unknown upstream error"
    }
}

private struct SingleChannelSpeechResponse: Decodable {
    let text: String
}

private struct MultiChannelSpeechResponse: Decodable {
    let transcripts: [SingleChannelSpeechResponse]
}
