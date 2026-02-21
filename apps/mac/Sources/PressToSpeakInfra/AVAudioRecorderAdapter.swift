import AVFoundation
import Foundation
import PressToSpeakCore

public enum RecorderError: LocalizedError {
    case microphonePermissionDenied
    case failedToCreateOutputDirectory
    case failedToPrepareRecording(details: String)
    case failedToStartRecording(details: String)
    case notRecording
    case outputFileMissing

    public var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone permission is required. Allow microphone access in macOS Settings."
        case .failedToCreateOutputDirectory:
            return "Unable to prepare temporary audio output directory."
        case .failedToPrepareRecording(let details):
            return "Unable to prepare audio recorder. \(details)"
        case .failedToStartRecording(let details):
            return "Unable to start recording audio. \(details)"
        case .notRecording:
            return "Recording is not active."
        case .outputFileMissing:
            return "Recording finished but no audio file was found."
        }
    }
}

public final class AVAudioRecorderAdapter: AudioRecorder {
    private struct RecorderCandidate {
        let fileExtension: String
        let settings: [String: Any]
        let label: String
    }

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

        guard AVCaptureDevice.default(for: .audio) != nil else {
            throw RecorderError.failedToPrepareRecording(details: "No audio input device detected.")
        }

        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("PressToSpeak", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
        } catch {
            AppLogger.log("Recorder: failed to create temp dir at \(tempDirectory.path): \(error.localizedDescription)")
            throw RecorderError.failedToCreateOutputDirectory
        }

        let candidates: [RecorderCandidate] = [
            RecorderCandidate(
                fileExtension: "m4a",
                settings: [
                    AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                    AVSampleRateKey: 44_100,
                    AVNumberOfChannelsKey: 1,
                    AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
                ],
                label: "AAC/m4a@44.1k"
            ),
            RecorderCandidate(
                fileExtension: "wav",
                settings: [
                    AVFormatIDKey: Int(kAudioFormatLinearPCM),
                    AVSampleRateKey: 16_000,
                    AVNumberOfChannelsKey: 1,
                    AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false,
                    AVLinearPCMIsBigEndianKey: false
                ],
                label: "PCM16/wav@16k"
            )
        ]

        var attemptErrors: [String] = []

        for candidate in candidates {
            let outputURL = tempDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(candidate.fileExtension)

            do {
                let recorder = try AVAudioRecorder(url: outputURL, settings: candidate.settings)

                guard recorder.prepareToRecord() else {
                    attemptErrors.append("\(candidate.label): prepareToRecord=false")
                    AppLogger.log("Recorder: \(candidate.label) prepareToRecord failed")
                    continue
                }

                guard recorder.record() else {
                    attemptErrors.append("\(candidate.label): record()=false")
                    AppLogger.log("Recorder: \(candidate.label) record() failed")
                    continue
                }

                self.recorder = recorder
                self.currentRecordingURL = outputURL
                AppLogger.log("Recorder: started with \(candidate.label), output=\(outputURL.path)")
                return
            } catch {
                let message = "\(candidate.label): \(error.localizedDescription)"
                attemptErrors.append(message)
                AppLogger.log("Recorder: \(message)")
            }
        }

        throw RecorderError.failedToPrepareRecording(details: attemptErrors.joined(separator: " | "))
    }

    public func stopRecording() throws -> URL {
        guard let recorder, let outputURL = currentRecordingURL else {
            throw RecorderError.notRecording
        }

        recorder.stop()
        self.recorder = nil
        self.currentRecordingURL = nil

        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            AppLogger.log("Recorder: output file missing at \(outputURL.path)")
            throw RecorderError.outputFileMissing
        }

        AppLogger.log("Recorder: stopped successfully, output=\(outputURL.path)")
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

            // Prevent an indefinite block if macOS never returns the callback.
            _ = semaphore.wait(timeout: .now() + 10)
            return granted
        @unknown default:
            return false
        }
    }
}
