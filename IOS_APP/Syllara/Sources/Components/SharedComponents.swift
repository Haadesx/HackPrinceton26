import SwiftUI

// MARK: - Card

struct BrainBrewCard<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        content
            .background(Color.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.white.opacity(0.06), lineWidth: 1))
    }
}

// MARK: - Priority Badge

struct PriorityBadge: View {
    let priority: String

    var body: some View {
        Text(priority.uppercased())
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(priorityColor(priority))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(priorityColor(priority).opacity(0.15))
            .clipShape(Capsule())
    }
}

// MARK: - Loading

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.scarlet)
                .scaleEffect(1.2)
            Text(message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
    }
}

// MARK: - Error

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 36))
                .foregroundColor(.scarlet)
            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Retry") { retry() }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.scarlet)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.scarletMuted)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.bgBase)
    }
}

// MARK: - Section Header

struct SectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundColor(.textTertiary)
                .textCase(.uppercase)
                .tracking(1.5)
            if let sub = subtitle {
                Text(sub)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

// MARK: - TTS Playback Controls

struct TTSPlaybackBar: View {
    @ObservedObject var audio: AudioManager
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Button {
                switch audio.state {
                case .idle: audio.speak(text)
                case .playing: audio.pause()
                case .paused: audio.resume()
                case .loading: break
                case .error: audio.speak(text)
                }
            } label: {
                Image(systemName: playIcon)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.scarlet)
                    .frame(width: 36, height: 36)
                    .background(Color.scarletMuted)
                    .clipShape(Circle())
            }

            if case .playing = audio.state {
                Button { audio.stop() } label: {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                        .frame(width: 30, height: 30)
                        .background(Color.bgSurface)
                        .clipShape(Circle())
                }
            }

            stateLabel
            Spacer()
        }
    }

    private var playIcon: String {
        switch audio.state {
        case .playing: return "pause.fill"
        case .loading: return "ellipsis"
        default: return "play.fill"
        }
    }

    @ViewBuilder
    private var stateLabel: some View {
        switch audio.state {
        case .loading:
            HStack(spacing: 4) {
                ProgressView().progressViewStyle(.circular).scaleEffect(0.6).tint(.textSecondary)
                Text("Generating audio…").font(.system(size: 12)).foregroundColor(.textSecondary)
            }
        case .playing:
            Text("Playing").font(.system(size: 12)).foregroundColor(.textSecondary)
        case .paused:
            Text("Paused").font(.system(size: 12)).foregroundColor(.textSecondary)
        case .error(let msg):
            Text("Error: \(msg)").font(.system(size: 12)).foregroundColor(.priorityCritical).lineLimit(1)
        default:
            Text("Read aloud").font(.system(size: 12)).foregroundColor(.textTertiary)
        }
    }
}

// MARK: - Course Color Dot

struct CourseColorDot: View {
    let colorHex: String
    var size: CGFloat = 8

    var body: some View {
        Circle()
            .fill(Color(hex: colorHex) ?? .scarlet)
            .frame(width: size, height: size)
    }
}

extension Color {
    init?(hex: String) {
        let h = hex.trimmingCharacters(in: .alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r, g, b: Double
        switch h.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255
            g = Double((int >> 8) & 0xFF) / 255
            b = Double(int & 0xFF) / 255
        default: return nil
        }
        self.init(red: r, green: g, blue: b)
    }
}
