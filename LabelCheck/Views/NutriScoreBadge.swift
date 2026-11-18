import SwiftUI

/// The Nutri-Score A-E badge colour, shared by the product card and the
/// history rows so the same grade always shows the same colour in both
/// places. Grey is only the fallback for an unknown grade.
func nutriScoreColor(_ letter: String) -> Color {
    switch letter {
    case "A": return .green
    case "B": return Color(red: 0.55, green: 0.75, blue: 0.25)
    case "C": return .yellow
    case "D": return .orange
    case "E": return .red
    default: return .gray
    }
}
