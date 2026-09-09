import SwiftUI

extension AppSection {
    var scenicRoyalToolbarTitle: String {
        title
    }

    var scenicRoyalToolbarSymbol: String {
        switch self {
        case .today: return "location.north.line"
        case .schedule: return "calendar"
        case .tools: return "wrench.and.screwdriver"
        case .resources: return "book.closed"
        case .setup: return "gearshape"
        }
    }
}

struct ScenicRoyalToolbar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenicRoyalThemeStyle) private var style

    @Binding var selection: AppSection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppSection.allCases) { section in
                toolbarButton(for: section)
            }
        }
        .padding(4)
        .scenicRoyalSurface(
            role: .toolbar,
            cornerRadius: ScenicRoyalDesignSystem.Radius.toolbar
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Main navigation")
        .animation(
            reduceMotion ? nil : ScenicRoyalDesignSystem.Motion.selection,
            value: selection
        )
    }

    private func toolbarButton(for section: AppSection) -> some View {
        let isSelected = selection == section

        return Button {
            selection = section
        } label: {
            VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 3 : 2) {
                Image(systemName: section.scenicRoyalToolbarSymbol)
                    .font(.system(.body, design: .rounded, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.monochrome)
                    .frame(height: 22)

                Text(section.scenicRoyalToolbarTitle)
                    .font(.system(.caption2, design: .rounded, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .multilineTextAlignment(.center)
            }
            // All five root destinations must remain simultaneously available. Keep the
            // compact navigation label readable while the surrounding hit target grows.
            .dynamicTypeSize(.xSmall ... .xxxLarge)
            .foregroundStyle(isSelected ? style.selectedControlForeground : style.contentSecondaryForeground)
            .frame(
                maxWidth: .infinity,
                minHeight: dynamicTypeSize.isAccessibilitySize
                    ? ScenicRoyalDesignSystem.Layout.accessibilityToolbarHeight
                    : ScenicRoyalDesignSystem.Layout.standardToolbarHeight
            )
            .padding(.horizontal, 2)
            .background {
                if isSelected {
                    ScenicRoyalSelectedControlMaterial(
                        shape: RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous)
                    )
                        .overlay(alignment: .top) {
                            Capsule()
                                .fill(style.selectedControlIndicator)
                                .frame(width: 16, height: 2)
                                .padding(.top, 3)
                        }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minWidth: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
        .accessibilityLabel(section.scenicRoyalToolbarTitle)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityHint(isSelected ? "Current section" : "Opens the \(section.scenicRoyalToolbarTitle) section")
    }
}
