import AVFoundation
import Foundation

enum AudioPlaybackState {
    case idle, loading, playing, paused, error(String)
}

@MainActor
final class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate, AVSpeechSynthesizerDelegate {

    @Published var state: AudioPlaybackState = .idle
    private var player: AVAudioPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()
    private var currentText: String?
    private var playbackMode: PlaybackMode = .none

    private enum PlaybackMode {
        case none
        case serverAudio
        case onDeviceSpeech
    }

    override init() {
        super.init()
        speechSynthesizer.delegate = self
        configureSession()
    }

    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // Fetch audio from backend TTS then play
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        stop()
        currentText = text
        state = .loading
        Task {
            do {
                let data = try await APIClient.shared.textToSpeech(text: text)
                play(data: data)
            } catch {
                speakOnDevice(text)
            }
        }
    }

    func play(data: Data) {
        do {
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            playbackMode = .serverAudio
            state = .playing
        } catch {
            if let currentText {
                speakOnDevice(currentText)
            } else {
                state = .error("Playback error: \(error.localizedDescription)")
            }
        }
    }

    func pause() {
        switch playbackMode {
        case .serverAudio:
            player?.pause()
            state = .paused
        case .onDeviceSpeech:
            guard speechSynthesizer.isSpeaking else { return }
            speechSynthesizer.pauseSpeaking(at: .word)
            state = .paused
        case .none:
            break
        }
    }

    func resume() {
        switch playbackMode {
        case .serverAudio:
            player?.play()
            state = .playing
        case .onDeviceSpeech:
            guard speechSynthesizer.isPaused else { return }
            speechSynthesizer.continueSpeaking()
            state = .playing
        case .none:
            break
        }
    }

    func stop() {
        player?.stop()
        player = nil
        if speechSynthesizer.isSpeaking || speechSynthesizer.isPaused {
            speechSynthesizer.stopSpeaking(at: .immediate)
        }
        playbackMode = .none
        state = .idle
    }

    func togglePlayPause() {
        switch state {
        case .playing: pause()
        case .paused: resume()
        default: break
        }
    }

    // MARK: - AVAudioPlayerDelegate

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
            self.playbackMode = .none
            self.state = .idle
        }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in
            self.player = nil
            if let currentText = self.currentText {
                self.speakOnDevice(currentText)
            } else {
                self.playbackMode = .none
                self.state = .error(error?.localizedDescription ?? "Decode error")
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.playbackMode = .onDeviceSpeech
            self.state = .playing
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.playbackMode = .onDeviceSpeech
            self.state = .paused
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.playbackMode = .onDeviceSpeech
            self.state = .playing
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.playbackMode = .none
            self.state = .idle
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.playbackMode = .none
            self.state = .idle
        }
    }

    private func speakOnDevice(_ text: String) {
        configureSession()
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        utterance.pitchMultiplier = 1.0
        utterance.prefersAssistiveTechnologySettings = true
        playbackMode = .onDeviceSpeech
        speechSynthesizer.speak(utterance)
    }
}
