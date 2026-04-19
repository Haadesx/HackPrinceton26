import SwiftUI

@main
struct BrainBrewApp: App {
    @StateObject private var audio = AudioManager()

    init() {
        NotificationManager.shared.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootNavigationView()
                .environmentObject(audio)
                .environmentObject(APIClient.shared)
                .preferredColorScheme(.dark)
        }
    }
}
