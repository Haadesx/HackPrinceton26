import SwiftUI

extension Color {
    // Brand
    static let scarlet = Color(red: 0.80, green: 0.00, blue: 0.20)          // #CC0033
    static let scarletDeep = Color(red: 0.70, green: 0.00, blue: 0.18)      // #B3002D
    static let scarletMuted = Color(red: 0.80, green: 0.00, blue: 0.20).opacity(0.15)

    // Backgrounds
    static let bgBase = Color(red: 0.067, green: 0.067, blue: 0.067)        // #111111
    static let bgCard = Color(red: 0.094, green: 0.094, blue: 0.094)        // #181818
    static let bgElevated = Color(red: 0.118, green: 0.118, blue: 0.118)    // #1E1E1E
    static let bgSurface = Color(red: 0.141, green: 0.141, blue: 0.141)     // #242424

    // Text
    static let textPrimary = Color(red: 0.961, green: 0.941, blue: 0.910)   // #F5F0E8 warm off-white
    static let textSecondary = Color(red: 0.60, green: 0.58, blue: 0.55)    // #999490
    static let textTertiary = Color(red: 0.40, green: 0.38, blue: 0.36)     // #666259

    // Priority
    static let priorityCritical = Color(red: 1.0, green: 0.23, blue: 0.19)
    static let priorityHigh = Color(red: 1.0, green: 0.58, blue: 0.00)
    static let priorityMedium = Color(red: 1.0, green: 0.84, blue: 0.00)
    static let priorityLow = Color(red: 0.20, green: 0.78, blue: 0.35)
}

extension ShapeStyle where Self == Color {
    static var bgBase: Color { .bgBase }
    static var bgCard: Color { .bgCard }
}

// Priority color helper
func priorityColor(_ priority: String) -> Color {
    switch priority.lowercased() {
    case "critical": return .priorityCritical
    case "high": return .priorityHigh
    case "medium": return .priorityMedium
    default: return .priorityLow
    }
}
