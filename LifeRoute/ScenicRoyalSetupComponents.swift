import SwiftUI

struct ScenicRoyalSetupHeader: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let savedPlaceCount: Int

    var body: some View {
        ScenicRoyalCard(role: .card) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        titleBlock
                        placeCount
                    }
                } else {
                    HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        titleBlock
                        Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)
                        placeCount
                    }
                }
            }
        }
    }

    private var titleBlock: some View {
        HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            LifeRouteBrandMark(variant: .small)
                .frame(width: 48, height: 48)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text("Setup")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(style.primaryText)

                Text("Your LifeRoute control center.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var placeCount: some View {
        VStack(
            alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing,
            spacing: ScenicRoyalDesignSystem.Spacing.hairline
        ) {
            Text("\(savedPlaceCount)")
                .font(.title2.weight(.bold))
                .foregroundStyle(style.accent)
            Text("saved place\(savedPlaceCount == 1 ? "" : "s")")
                .font(.caption.weight(.semibold))
                .foregroundStyle(style.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ScenicRoyalSetupDisclosureGroup<Content: View>: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let title: String
    let subtitle: String
    let systemImage: String
    @Binding var isExpanded: Bool
    private let content: Content

    init(
        title: String,
        subtitle: String,
        systemImage: String,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button(action: toggle) {
                HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                    Image(systemName: systemImage)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isExpanded ? style.accentReflection : style.accent)
                        .frame(
                            width: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
                            height: ScenicRoyalDesignSystem.Layout.minimumTouchTarget
                        )
                        .scenicRoyalSurface(
                            role: isExpanded ? .selectedControl : .ambient,
                            cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
                        )
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(style.primaryText)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(style.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(style.accent)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                        .padding(.top, ScenicRoyalDesignSystem.Spacing.standard)
                        .accessibilityHidden(true)
                }
                .padding(ScenicRoyalDesignSystem.Spacing.standard)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
            .accessibilityLabel(title)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityHint(isExpanded ? "Collapses this Setup group" : "Expands this Setup group")

            if isExpanded {
                VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    content
                }
                .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.compact)
                .padding(.bottom, ScenicRoyalDesignSystem.Spacing.compact)
                .transition(reduceMotion ? .identity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .scenicRoyalSurface(role: isExpanded ? .card : .ambient)
    }

    private func toggle() {
        withAnimation(reduceMotion ? nil : ScenicRoyalDesignSystem.Motion.selection) {
            isExpanded.toggle()
        }
        LifeRouteHaptics.selection()
    }
}

struct ScenicRoyalSetupNavigationRow: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let title: String
    let subtitle: String
    let detail: String?
    let systemImage: String

    var body: some View {
        HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            ScenicRoyalIconBadge(systemImage: systemImage)

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(style.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.accentReflection)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(style.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(style.secondaryText)
                .padding(.top, ScenicRoyalDesignSystem.Spacing.standard)
                .accessibilityHidden(true)
        }
        .frame(minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct ScenicRoyalSavedPlaceRow: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let place: LifeRouteSavedPlace
    let systemImage: String
    let onRemove: () -> Void

    var body: some View {
        ScenicRoyalInsetRow(role: .readability) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        placeDetails
                        removeButton(expanded: true)
                    }
                } else {
                    HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        placeDetails
                        removeButton(expanded: false)
                    }
                }
            }
        }
    }

    private var placeDetails: some View {
        HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            ScenicRoyalIconBadge(systemImage: systemImage)

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(place.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(style.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text(place.address)
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(place.kind.rawValue) · \(place.minimumVisitMinutes) min visit")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if place.useInGapSuggestions {
                    Label("Eligible for gap suggestions", systemImage: "sparkles")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(style.accentReflection)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func removeButton(expanded: Bool) -> some View {
        Button(role: .destructive, action: onRemove) {
            Group {
                if expanded {
                    Label("Remove saved place", systemImage: "trash")
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Image(systemName: "trash")
                        .frame(
                            width: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
                            height: ScenicRoyalDesignSystem.Layout.minimumTouchTarget
                        )
                }
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(.red)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
        .accessibilityLabel("Remove \(place.name)")
        .accessibilityHint("Deletes this saved place from LifeRoute")
    }
}

struct ScenicRoyalTodoRow: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let todo: LifeRouteTodo
    let onComplete: () -> Void
    let onDelete: () -> Void

    var body: some View {
        ScenicRoyalInsetRow(role: .readability) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        todoDetails
                        VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                            completeButton(expanded: true)
                            deleteButton(expanded: true)
                        }
                    }
                } else {
                    HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        todoDetails
                        VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                            completeButton(expanded: false)
                            deleteButton(expanded: false)
                        }
                    }
                }
            }
        }
    }

    private var todoDetails: some View {
        HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            ScenicRoyalIconBadge(systemImage: todo.category.systemImage)

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(todo.title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(style.primaryText)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(todo.category.rawValue) · \(todo.durationMinutes) min · due \(todo.dueDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                if !todo.address.isEmpty {
                    Label(todo.address, systemImage: "mappin.and.ellipse")
                        .font(.caption2)
                        .foregroundStyle(style.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if todo.priority == .high {
                    Label("High priority", systemImage: "exclamationmark.circle.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(style.accentReflection)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private func completeButton(expanded: Bool) -> some View {
        Button(action: onComplete) {
            actionLabel("Complete", systemImage: "checkmark.circle.fill", expanded: expanded)
                .foregroundStyle(style.accentReflection)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: expanded ? .infinity : nil, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
        .accessibilityLabel("Complete \(todo.title)")
        .accessibilityHint("Marks this weekly to-do completed")
    }

    private func deleteButton(expanded: Bool) -> some View {
        Button(role: .destructive, action: onDelete) {
            actionLabel("Delete", systemImage: "trash", expanded: expanded)
                .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: expanded ? .infinity : nil, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
        .accessibilityLabel("Delete \(todo.title)")
        .accessibilityHint("Deletes this weekly to-do")
    }

    private func actionLabel(_ title: String, systemImage: String, expanded: Bool) -> some View {
        Group {
            if expanded {
                Label(title, systemImage: systemImage)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.compact)
                    .scenicRoyalInteractiveSurface(role: .ambient)
            } else {
                Image(systemName: systemImage)
                    .frame(
                        width: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
                        height: ScenicRoyalDesignSystem.Layout.minimumTouchTarget
                    )
            }
        }
        .font(.caption.weight(.bold))
        .contentShape(Rectangle())
    }
}

struct ScenicRoyalCompletedTodoRow: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let todo: LifeRouteTodo
    let onUndo: () -> Void

    var body: some View {
        ScenicRoyalInsetRow(role: .ambient) {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(style.accentReflection)
                    .accessibilityHidden(true)
                Text(todo.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(style.secondaryText)
                    .strikethrough()
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)
                Button("Undo", action: onUndo)
                    .font(.caption.weight(.bold))
                    .frame(minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
                    .accessibilityLabel("Restore \(todo.title)")
                    .accessibilityHint("Marks this weekly to-do open")
            }
        }
    }
}

struct ScenicRoyalSetupStatusText: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let message: String

    var body: some View {
        Label(message, systemImage: "info.circle.fill")
            .font(.caption.weight(.medium))
            .foregroundStyle(style.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityLabel("Status: \(message)")
    }
}
