import AVFoundation
import Foundation
import PressToSpeakCore

public enum RecorderError: LocalizedError {
    case microphonePermissionDenied
    case failedToCreateOutputDirectory
    case failedToPrepareRecording
    case failedToStartRecording
    case notRecording
    case outputFileMissing

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required. Allow microphone access in macOS Settings."
        case .failedToCreateOutputDirectory:
            return "Unable to prepare temporary audio output directory."
        case .failedToPrepareRecording:
            return "Unable to prepare audio recorder."
        case .failedToStartRecording:
            return "Unable to start recording audio."
        case .notRecording:
            return "Recording is not active."
        case .outputFileMissing:
            return "Recording finished but no audio file was found."
        }
    }
}

public final class AVAudioRecorderAdapter: AudioRecorder {
    private var recorder: AVAudioRecorder?
    private var currentRecordingURL: URL?

    public init() {}

    public func startRecording() throws {
        if recorder?.isRecording == true {
            return
        }

        guard try ensureMicrophonePermission() else {
            throw RecorderError.microphonePermissionDenied
        }

        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("PressToSpeak", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        } catch {
            throw RecorderError.failedToCreateOutputDirectory
        }

        let outputURL = tempDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("m4a")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        let recorder = try AVAudioRecorder(url: outputURL, settings: settings)
        guard recorder.prepareToRecord() else {
            throw RecorderError.failedToPrepareRecording
        }
        guard recorder.record() else {
            throw RecorderError.failedToStartRecording
        }

        self.recorder = recorder
        self.currentRecordingURL = outputURL
    }

    public func stopRecording() throws -> URL {
        guard let recorder, let outputURL = currentRecordingURL else {
            throw RecorderError.notRecording
        }

        recorder.stop()
        self.recorder = nil
        self.currentRecordingURL = nil

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw RecorderError.outputFileMissing
        }

        return outputURL
    }

    private func ensureMicrophonePermission() throws -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .denied, .restricted:
            return false
        case .notDetermined:
            let semaphore = DispatchSemaphore(value: 0)
            var granted = false
            AVCaptureDevice.requestAccess(for: .audio) { access in
                granted = access
                semaphore.signal()
            }
            semaphore.wait()
            return granted
        @unknown default:
            return false
        }
    }
}
