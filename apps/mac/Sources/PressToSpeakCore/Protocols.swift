import Foundation

public protocol AudioRecorder {
    func startRecording() throws
    func stopRecording() throws -> URL
}

public protocol TranscriptionProvider {
    func transcribe(_ request: TranscriptionRequest) async throws -> TranscriptionResult
}

public protocol TextPaster {
    func paste(text: String) throws
}

public protocol PromptBuilding {
    func buildSystemPrompt(defaultPrompt: String, userContext: String, vocabularyHints: [String]) -> String
}
