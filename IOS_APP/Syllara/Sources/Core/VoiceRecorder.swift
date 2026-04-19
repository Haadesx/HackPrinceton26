import AVFoundation
import Foundation
import Speech

enum RecordingState: Equatable {
    case idle, recording, processing, done(String), error(String)
}

@MainActor
final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {

    @Published var state: RecordingState = .idle
    private var recorder: AVAudioRecorder?
    private var outputURL: URL?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    override init() {
        super.init()
    }

    func requestPermissionAndRecord() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            let micGranted = await requestMicrophonePermission()
            guard micGranted else {
                state = .error("Microphone permission denied")
                return
            }

            let speechStatus = await requestSpeechAuthorization()
            if speechStatus == .restricted {
                state = .error("Speech recognition is restricted on this device")
                return
            }

            startRecording()
        }
    }

    private func startRecording() {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice_\(UUID().uuidString).m4a")
        outputURL = url
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            recorder = try AVAudioRecorder(url: url, settings: settings)
            recorder?.delegate = self
            recorder?.record()
            state = .recording
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    func stopAndTranscribe() {
        recorder?.stop()
        recorder = nil
        guard let url = outputURL else {
            state = .error("No recording found")
            return
        }
        state = .processing
        Task {
            do {
                let text = try await transcribe(url: url)
                state = .done(text)
                try? FileManager.default.removeItem(at: url)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func cancel() {
        recorder?.stop()
        recorder = nil
        if let url = outputURL { try? FileManager.default.removeItem(at: url) }
        state = .idle
    }

    nonisolated func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {
        if !flag { Task { @MainActor in self.state = .error("Recording failed") } }
    }

    private func transcribe(url: URL) async throws -> String {
        if let localText = try? await transcribeOnDevice(url: url) {
            return localText
        }

        let data = try Data(contentsOf: url)
        return try await APIClient.shared.transcribeAudio(fileData: data, fileName: url.lastPathComponent)
    }

    private func transcribeOnDevice(url: URL) async throws -> String? {
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            return nil
        }

        guard let recognizer = speechRecognizer, recognizer.supportsOnDeviceRecognition, recognizer.isAvailable else {
            return nil
        }

        return try await withCheckedThrowingContinuation { continuation in
            var didResume = false
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.requiresOnDeviceRecognition = true
            request.shouldReportPartialResults = false

            var recognitionTask: SFSpeechRecognitionTask?
            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                guard !didResume else { return }

                if let error {
                    didResume = true
                    continuation.resume(throwing: error)
                    return
                }

                guard let result else { return }
                if result.isFinal {
                    didResume = true
                    let text = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                    recognitionTask?.cancel()
                    continuation.resume(returning: text.isEmpty ? nil : text)
                }
            }
        }
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}
