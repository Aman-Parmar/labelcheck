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

/// One shared Nutri-Score badge: the grade letter in a coloured circle.
/// Renders nothing when the grade is unknown, so callers never repeat the
/// letter-or-nothing check. Size and font are parameters because the product
/// card shows a large badge and the rows show a small one.
struct NutriScoreBadge: View {
    let grade: String?
    let size: CGFloat
    let font: Font

    var body: some View {
        if let letter = NutriScore(grade: grade ?? "").badgeLetter {
            Text(letter)
                .font(font)
                .foregroundStyle(.white)
                .frame(width: size, height: size)
                .background(nutriScoreColor(letter), in: Circle())
        }
    }
}
