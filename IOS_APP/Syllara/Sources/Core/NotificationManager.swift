import SwiftUI
import UIKit
import UserNotifications

@MainActor
final class NotificationManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    func configure() {
        UNUserNotificationCenter.current().delegate = self
    }

    func notifyStudyLabReady(artifact: StudyArtifact, topic: String) {
        Task {
            guard await requestAuthorizationIfNeeded() else { return }

            let content = UNMutableNotificationContent()
            content.title = "Brain Brew Ready"
            content.body = "\(artifact.rawValue) for \(topic) is ready in Brain Brew."
            content.sound = .default
            if let attachment = makeLogoAttachment() {
                content.attachments = [attachment]
            }

            let request = UNNotificationRequest(
                identifier: "study-lab-\(UUID().uuidString)",
                content: content,
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            )

            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .badge, .sound])) ?? false
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    private func makeLogoAttachment() -> UNNotificationAttachment? {
        guard let image = UIImage(named: "BrainBrewLogo"),
              let data = image.pngData() else {
            return nil
        }

        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("brain-brew-notification-\(UUID().uuidString).png")
        do {
            try data.write(to: fileURL, options: [.atomic])
            return try UNNotificationAttachment(identifier: "BrainBrewLogo", url: fileURL)
        } catch {
            return nil
        }
    }
}
