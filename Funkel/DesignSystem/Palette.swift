import SwiftUI
import UIKit

/// The app's colour palette. Subject colours come from content manifests;
/// these are the shared UI colours. Text on coloured fills is always white
/// on a shade dark enough for WCAG AA at large sizes.
enum Palette {
    static let background = Color(light: 0xFFF8EE, dark: 0x1C1A24)
    static let card = Color(light: 0xFFFFFF, dark: 0x2A2733)
    static let ink = Color(light: 0x2B2540, dark: 0xF4F1FA)

    static let sun = Color(hex: "#FFB020")
    static let correct = Color(hex: "#2BB673")
    /// Used for the gentle reveal of the right answer — warm, never red.
    static let reveal = Color(hex: "#FFC94D")

    /// Avatar colours a grown-up can pick for a profile, keyed for storage.
    static let avatarColors: [(key: String, color: Color)] = [
        ("sun", Color(hex: "#FFB020")),
        ("sky", Color(hex: "#3DA5FF")),
        ("leaf", Color(hex: "#34C77B")),
        ("berry", Color(hex: "#E2558F")),
        ("grape", Color(hex: "#8A63F2")),
        ("coral", Color(hex: "#FF7A59")),
    ]

    static func avatarColor(_ key: String) -> Color {
        avatarColors.first { $0.key == key }?.color ?? sun
    }
}

extension Color {
    /// "#RRGGBB" or "RRGGBB". Invalid input yields the sun colour so bad
    /// content can't make a subject invisible.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = UInt32(cleaned, radix: 16) else {
            self.init(red: 1, green: 0.69, blue: 0.125)
            return
        }
        self.init(rgb: value)
    }

    init(rgb value: UInt32) {
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            let value = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(
                red: CGFloat((value >> 16) & 0xFF) / 255,
                green: CGFloat((value >> 8) & 0xFF) / 255,
                blue: CGFloat(value & 0xFF) / 255,
                alpha: 1
            )
        })
    }
}
