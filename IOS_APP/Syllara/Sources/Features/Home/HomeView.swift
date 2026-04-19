import SwiftUI

struct HomeView: View {
    let onLaunch: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.bgBase.ignoresSafeArea()

            // Subtle scarlet glow
            RadialGradient(
                colors: [Color.scarlet.opacity(0.18), Color.clear],
                center: .init(x: 0.5, y: 0.35),
                startRadius: 10,
                endRadius: 280
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo mark
                Image("BrainBrewLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 108, height: 108)
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .stroke(Color.scarlet.opacity(0.22), lineWidth: 1)
                    )
                    .shadow(color: Color.scarlet.opacity(0.18), radius: 22, x: 0, y: 12)
                .opacity(appear ? 1 : 0)
                .scaleEffect(appear ? 1 : 0.7)

                Spacer().frame(height: 28)

                Text("Brain Brew")
                    .font(.system(size: 44, weight: .black, design: .default))
                    .foregroundColor(.textPrimary)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 10)

                Spacer().frame(height: 10)

                Text("Academic mission control\nfor Rutgers MSCS.")
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .opacity(appear ? 1 : 0)
                    .offset(y: appear ? 0 : 8)

                Spacer().frame(height: 48)

                Button(action: onLaunch) {
                    HStack(spacing: 10) {
                        Text("Open Command Center")
                            .font(.system(size: 16, weight: .semibold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 16)
                    .background(Color.scarlet)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .opacity(appear ? 1 : 0)
                .offset(y: appear ? 0 : 12)

                Spacer().frame(height: 12)

                Text("Spring 2026 · 4 courses loaded")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(.textTertiary)
                    .opacity(appear ? 1 : 0)

                Spacer()
            }
            .padding(.horizontal, 32)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
                appear = true
            }
        }
    }
}
