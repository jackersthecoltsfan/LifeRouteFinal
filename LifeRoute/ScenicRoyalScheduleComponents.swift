import SwiftUI

struct ScenicRoyalCalendarDateChip: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let date: Date
    let eventCount: Int
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(date.formatted(.dateTime.weekday(dynamicTypeSize.isAccessibilitySize ? .abbreviated : .narrow)))
                    .font(.caption2.weight(.bold))
                    .lineLimit(1)

                Text(date.formatted(.dateTime.day()))
                    .font(.headline.weight(.bold))
                    .lineLimit(1)

                Circle()
                    .fill(eventCount > 0 ? eventIndicatorColor : .clear)
                    .frame(width: 5, height: 5)
            }
            .foregroundStyle(isSelected ? selectedTextColor : style.primaryText)
            .frame(
                width: dynamicTypeSize.isAccessibilitySize ? 88 : 44,
                height: dynamicTypeSize.isAccessibilitySize ? 96 : 58
            )
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl, style: .continuous)
                        .fill(style.accent)
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl, style: .continuous)
                    .stroke(
                        isToday && !isSelected ? style.accent.opacity(0.72) : Color.clear,
                        lineWidth: ScenicRoyalDesignSystem.Stroke.selected
                    )
            }
            .contentShape(RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl, style: .continuous))
            .scenicRoyalInteractiveSurface(
                role: isSelected ? .selectedControl : .ambient,
                cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue("\(eventCount) event\(eventCount == 1 ? "" : "s")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var selectedTextColor: Color {
        ScenicRoyalDesignSystem.ColorToken.brandNavyDeep
    }

    private var eventIndicatorColor: Color {
        isSelected ? selectedTextColor.opacity(0.72) : style.accent
    }
}

struct ScenicRoyalCalendarMonthDay: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let date: Date
    let eventCount: Int
    let isSelected: Bool
    let isToday: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                Text(date.formatted(.dateTime.day()))
                    .font(.caption.weight(isSelected ? .bold : .semibold))
                    .foregroundStyle(isSelected ? selectedTextColor : style.primaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                Circle()
                    .fill(eventCount > 0 ? eventIndicatorColor : .clear)
                    .frame(width: 4, height: 4)
                    .padding(.bottom, 3)
            }
            .frame(minHeight: 40)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? style.accent : (isToday ? style.accent.opacity(0.14) : .clear))
            }
            .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(date.formatted(date: .complete, time: .omitted))
        .accessibilityValue("\(eventCount) event\(eventCount == 1 ? "" : "s")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
    }

    private var selectedTextColor: Color {
        ScenicRoyalDesignSystem.ColorToken.brandNavyDeep
    }

    private var eventIndicatorColor: Color {
        isSelected ? selectedTextColor.opacity(0.72) : style.accent
    }
}

struct ScenicRoyalScheduleEventRow: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let event: LifeRouteCalendarEvent
    let sourceLabel: String
    let sourceIcon: String
    let sourceAccent: Color
    let onDelete: (() -> Void)?

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                compactLayout
            }
        }
        .scenicRoyalCard(
            role: .readability,
            cornerRadius: ScenicRoyalDesignSystem.Radius.control,
            padding: ScenicRoyalDesignSystem.Spacing.standard
        )
        .accessibilityElement(children: .contain)
    }

    private var compactLayout: some View {
        HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            timeBlock
                .frame(width: 68, alignment: .leading)

            sourceAccent
                .frame(width: 3)
                .clipShape(Capsule())

            eventDetails
            deleteButton
        }
    }

    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            HStack(alignment: .firstTextBaseline) {
                timeBlock
                Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)
                deleteButton
            }

            Rectangle()
                .fill(sourceAccent)
                .frame(height: 3)
                .clipShape(Capsule())

            eventDetails
        }
    }

    private var timeBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(event.isAllDay ? "All day" : event.start.formatted(date: .omitted, time: .shortened))
                .font(.caption.weight(.bold))
                .foregroundStyle(event.isAllDay ? sourceAccent : style.primaryText)
                .lineLimit(1)

            if !event.isAllDay {
                Text(event.end.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(style.secondaryText)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var eventDetails: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
            Text(event.title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(style.primaryText)
                .fixedSize(horizontal: false, vertical: true)

            if !event.location.isEmpty {
                Label(event.location, systemImage: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Label(sourceDescription, systemImage: sourceIcon)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(sourceAccent)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var deleteButton: some View {
        if let onDelete {
            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .font(.caption.weight(.bold))
                    .frame(
                        width: ScenicRoyalDesignSystem.Layout.minimumTouchTarget,
                        height: ScenicRoyalDesignSystem.Layout.minimumTouchTarget
                    )
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
            .accessibilityLabel("Delete \(event.title)")
            .accessibilityHint("Removes this LifeRoute appointment")
        }
    }

    private var sourceDescription: String {
        if event.calendarTitle.isEmpty
            || event.calendarTitle.compare(sourceLabel, options: .caseInsensitive) == .orderedSame {
            return sourceLabel
        }
        return "\(sourceLabel), \(event.calendarTitle)"
    }
}

struct ScenicRoyalTravelPlanLabel: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let detail: String
    let summary: String

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                    heading
                    actionLabel
                }
            } else {
                HStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                    heading
                    Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)
                    actionLabel
                }
            }
        }
        .padding(ScenicRoyalDesignSystem.Spacing.standard)
        .contentShape(RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.card, style: .continuous))
        .scenicRoyalInteractiveSurface(role: .selectedControl, cornerRadius: ScenicRoyalDesignSystem.Radius.card)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Travel plan")
        .accessibilityValue(accessibilityValue)
        .accessibilityHint("Opens full-day route planning")
    }

    private var heading: some View {
        HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            Image(systemName: "car.side.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(style.accent)
                .frame(width: 42, height: 42)
                .scenicRoyalSurface(role: .ambient, cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                HStack(spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                    Text("Travel plan")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(style.primaryText)
                    if !summary.isEmpty {
                        Text(summary)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(style.accentReflection)
                    }
                }

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var actionLabel: some View {
        HStack(spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
            Text("Plan route")
                .font(.caption.weight(.bold))
                .foregroundStyle(style.accent)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(style.secondaryText)
        }
    }

    private var accessibilityValue: String {
        summary.isEmpty ? detail : "\(summary). \(detail)"
    }
}

struct ScenicRoyalCalendarConnectionLabel: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let summary: String

    var body: some View {
        HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(style.accent)
                .accessibilityHidden(true)

            Text("Connected calendars")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(style.primaryText)

            Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)

            Text(summary)
                .font(.caption.weight(.semibold))
                .foregroundStyle(style.secondaryText)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(style.secondaryText)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.standard)
        .frame(minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
        .contentShape(RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous))
        .scenicRoyalInteractiveSurface(role: .ambient, cornerRadius: ScenicRoyalDesignSystem.Radius.control)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Connected calendars")
        .accessibilityValue(summary)
        .accessibilityHint("Opens calendar connection settings")
    }
}

struct ScenicRoyalRouteLegRow: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let leg: LifeRouteDayRouteLeg

    var body: some View {
        ScenicRoyalInsetRow(role: .ambient) {
            HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                Text("\(leg.sequence)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ScenicRoyalDesignSystem.ColorToken.brandNavyDeep)
                    .frame(width: 30, height: 30)
                    .background(style.accent, in: Circle())
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                    Text("\(leg.fromTitle) → \(leg.toTitle)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(style.primaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(leg.durationLabel) · \(leg.distanceLabel)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(style.accentReflection)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Leg \(leg.sequence), from \(leg.fromTitle) to \(leg.toTitle)")
        .accessibilityValue("\(leg.durationLabel), \(leg.distanceLabel)")
    }
}
