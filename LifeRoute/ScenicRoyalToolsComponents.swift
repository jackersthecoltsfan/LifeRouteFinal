import SwiftUI

struct ScenicRoyalToolTile: View {
    let title: String
    let subtitle: String
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: 18) {
            Image(systemName: systemImage)
                .font(.system(size: title == "Visual Timer" ? 38 : 25, weight: .light))
                .foregroundStyle(UI01Material.goldGradient)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                UI01MarbleText(title: title, size: title == "Visual Timer" ? 30 : 25, relativeTo: .title2)
                Text(subtitle)
                    .font(.custom("Baskerville", size: 17, relativeTo: .body))
                    .foregroundStyle(UI01Material.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .foregroundStyle(UI01Material.silver)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(.vertical, title == "Visual Timer" ? 20 : 14)
        .ui01ScenicText()
        .overlay(alignment: .bottom) { UI01Hairline().opacity(0.5) }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(subtitle)")
        .accessibilityHint("Opens \(title)")
    }
}
