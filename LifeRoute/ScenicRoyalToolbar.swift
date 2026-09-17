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

    @Binding var selection: AppSection

    var body: some View {
        HStack(spacing: 2) {
            ForEach(AppSection.allCases) { section in
                if section != .today {
                    UI01DockDivider()
                }
                toolbarButton(for: section)
            }
        }
        .padding(4)
        .modifier(UI01DockSurface())
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
            UI01DockLabel(section: section, selected: isSelected)
                .modifier(UI01DockSelectionSurface(selected: isSelected))
                .frame(minHeight: dynamicTypeSize.isAccessibilitySize
                    ? ScenicRoyalDesignSystem.Layout.accessibilityToolbarHeight
                    : ScenicRoyalDesignSystem.Layout.standardToolbarHeight)

        }
        .buttonStyle(.plain)
        .frame(minWidth: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
        .accessibilityLabel(section.scenicRoyalToolbarTitle)
        .accessibilityValue(isSelected ? "Selected" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isSelected ? "Current section" : "Opens the \(section.scenicRoyalToolbarTitle) section")
    }
}
