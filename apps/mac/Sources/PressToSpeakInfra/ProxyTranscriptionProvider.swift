import Foundation
import PressToSpeakCore

public enum ProxyProviderError: LocalizedError {
    case missingProxyURL
    case failedToReadAudioFile
    case upstreamFailure(statusCode: Int, message: String)
    case invalidResponse

    public var errorDescription: String? {
        switch self {
        case .missingProxyURL:
            return "TRANSCRIPTION_PROXY_URL is not configured."
        case .failedToReadAudioFile:
            return "Unable to read recorded audio file for proxy upload."
        case .upstreamFailure(let statusCode, let message):
            return "Proxy transcription request failed (\(statusCode)): \(message)"
        case .invalidResponse:
            return "Proxy response did not contain transcription text."
        }
    }
}

public final class ProxyTranscriptionProvider: TranscriptionProvider {
    private let configuration: AppConfiguration
    private let session: URLSession

    public init(configuration: AppConfiguration, session: URLSession = .shared) {
        self.configuration = configuration
        self.session = session
    }

    public func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult {
        guard let proxyURL = configuration.proxyURL else {
            throw ProxyProviderError.missingProxyURL
        }

        var form = MultipartFormDataBuilder()
        form.addField(name: "model_id", value: configuration.elevenLabsModelID)
        form.addField(name: "system_prompt", value: request.systemPrompt)
        form.addField(name: "user_context", value: request.userContext)

        if let locale = request.locale?.trimmingCharacters(in: .whitespacesAndNewlines), !locale.isEmpty {
            form.addField(name: "locale", value: locale)
        }

        for hint in request.vocabularyHints where !hint.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            form.addField(name: "vocabulary_hints", value: hint)
        }

        do {
            try form.addFile(name: "file", fileURL: request.audioFileURL)
        } catch {
            throw ProxyProviderError.failedToReadAudioFile
        }

        let body = form.build()

        var urlRequest = URLRequest(url: proxyURL)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = configuration.requestTimeoutSeconds
        urlRequest.setValue("multipart/form-data; boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Accept")

        if let key = configuration.proxyAPIKey, !key.isEmpty {
            urlRequest.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            urlRequest.setValue(key, forHTTPHeaderField: "x-api-key")
        }

        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw ProxyProviderError.invalidResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let message = Self.extractErrorMessage(from: data)
            throw ProxyProviderError.upstreamFailure(statusCode: httpResponse.statusCode, message: message)
        }

        if let text = Self.extractTranscriptionText(from: data) {
            return TranscriptionResult(text: text)
        }

        throw ProxyProviderError.invalidResponse
    }

    private static func extractTranscriptionText(from data: Data) -> String? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        // New API contract: { "transcript": { "clean_text": "...", "raw_text": "..." } }
        if let transcript = object["transcript"] as? [String: Any] {
            let nestedCandidates = ["clean_text", "raw_text"]
            for key in nestedCandidates {
                if let value = transcript[key] as? String {
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        return trimmed
                    }
                }
            }
        }

        // Backward-compatible fallbacks.
        let candidates = ["text", "transcript", "result", "output", "content"]
        for key in candidates {
            if let value = object[key] as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    return trimmed
                }
            }
        }

        return nil
    }

    private static func extractErrorMessage(from data: Data) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let errorObject = object["error"] as? [String: Any] {
                if let message = errorObject["message"] as? String, !message.isEmpty {
                    return message
                }
                if let detail = errorObject["detail"] as? String, !detail.isEmpty {
                    return detail
                }
            }

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
