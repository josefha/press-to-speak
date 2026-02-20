import Foundation

public final class TranscriptionOrchestrator {
    private let recorder: AudioRecorder
    private let provider: TranscriptionProvider
    private let paster: TextPaster
    private let promptBuilder: PromptBuilding

    public init(
        recorder: AudioRecorder,
        provider: TranscriptionProvider,
        paster: TextPaster,
        promptBuilder: PromptBuilding = DefaultPromptBuilder()
    ) {
        self.recorder = recorder
        self.provider = provider
        self.paster = paster
        self.promptBuilder = promptBuilder
    }

    public func startCapture() throws {
        try recorder.startRecording()
    }

    @discardableResult
    public func finishCapture(
        defaultPrompt: String,
        userContext: String,
        vocabularyHints: [String],
        locale: String?,
        providerOverride: TranscriptionProvider? = nil
    ) async throws -> String {
        let audioURL = try recorder.stopRecording()
        defer {
            try? FileManager.default.removeItem(at: audioURL)
        }

        let mergedPrompt = promptBuilder.buildSystemPrompt(
            defaultPrompt: defaultPrompt,
            userContext: userContext,
            vocabularyHints: vocabularyHints
        )

        let request = TranscriptionRequest(
            audioFileURL: audioURL,
            systemPrompt: mergedPrompt,
            userContext: userContext,
            vocabularyHints: vocabularyHints,
            locale: locale
        )

        let activeProvider = providerOverride ?? provider
        let result = try await activeProvider.transcribe(request)
        try paster.paste(text: result.text)
        return result.text
    }
}

public struct DefaultPromptBuilder: PromptBuilding {
    public init() {}

    public func buildSystemPrompt(defaultPrompt: String, userContext: String, vocabularyHints: [String]) -> String {
        var sections: [String] = [defaultPrompt]

        let trimmedContext = userContext.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedContext.isEmpty {
            sections.append("User context:\n\(trimmedContext)")
        }

        let hints = vocabularyHints
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !hints.isEmpty {
            sections.append("Preferred vocabulary:\n- \(hints.joined(separator: "\n- "))")
        }

        return sections.joined(separator: "\n\n")
    }
}
