import AVFoundation
import Foundation

enum AudioPlaybackState {
    case idle, loading, playing, paused, error(String)
}

@MainActor
final class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {

    @Published var state: AudioPlaybackState = .idle
    private var player: AVAudioPlayer?
    private var currentText: String?

    override init() {
        super.init()
        configureSession()
    }

    private func configureSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    // Fetch audio from backend TTS then play
    func speak(_ text: String) {
        guard !text.isEmpty else { return }
        currentText = text
        state = .loading
        Task {
            do {
                let data = try await APIClient.shared.textToSpeech(text: text)
                play(data: data)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    func play(data: Data) {
        do {
            player = try AVAudioPlayer(data: data)
            player?.delegate = self
            player?.prepareToPlay()
            player?.play()
            state = .playing
        } catch {
            state = .error("Playback error: \(error.localizedDescription)")
        }
    }

    func pause() {
        player?.pause()
        state = .paused
    }

    func resume() {
        player?.play()
        state = .playing
    }

    func stop() {
        player?.stop()
        player = nil
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
        Task { @MainActor in self.state = .idle }
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor in self.state = .error(error?.localizedDescription ?? "Decode error") }
    }
}
