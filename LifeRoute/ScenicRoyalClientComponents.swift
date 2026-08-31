import SwiftUI

struct ScenicRoyalClientHeader: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let clientCount: Int

    var body: some View {
        ScenicRoyalCard(role: .card) {
            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        titleBlock
                        statusBlock
                    }
                } else {
                    HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                        titleBlock
                        Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)
                        statusBlock
                    }
                }
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
            Text("Clients")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(style.primaryText)

            Text("ABA-style client codes and practical session context.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(style.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    private var statusBlock: some View {
        VStack(
            alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .trailing,
            spacing: ScenicRoyalDesignSystem.Spacing.hairline
        ) {
            Label(
                "\(clientCount) saved",
                systemImage: "person.crop.circle.fill"
            )
            Label("Local-first", systemImage: "lock.fill")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(style.accentReflection)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(clientCount) saved client profile\(clientCount == 1 ? "" : "s"), local-first storage"
        )
    }
}

struct ScenicRoyalClientAddRow<Destination: View>: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    private let destination: Destination

    init(@ViewBuilder destination: () -> Destination) {
        self.destination = destination()
    }

    var body: some View {
        NavigationLink {
            destination
        } label: {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                ScenicRoyalIconBadge(systemImage: "person.crop.circle.badge.plus")

                VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                    Text("Add Client")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(style.primaryText)
                    Text("Use first two + last two initials only")
                        .font(.subheadline)
                        .foregroundStyle(style.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(style.accent)
                    .accessibilityHidden(true)
            }
            .padding(ScenicRoyalDesignSystem.Spacing.standard)
            .contentShape(
                RoundedRectangle(
                    cornerRadius: ScenicRoyalDesignSystem.Radius.control,
                    style: .continuous
                )
            )
            .scenicRoyalInteractiveSurface(role: .selectedControl)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add client")
        .accessibilityHint("Opens a private client-code editor")
    }
}

struct ScenicRoyalClientEmptyState: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    var body: some View {
        ScenicRoyalCard(role: .readability) {
            VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.title2)
                    .foregroundStyle(style.accent)
                    .accessibilityHidden(true)

                Text("No client profiles yet")
                    .font(.headline)
                    .foregroundStyle(style.primaryText)

                Text("General session and visual tools still work without a client profile.")
                    .font(.subheadline)
                    .foregroundStyle(style.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }
}

struct ScenicRoyalClientSummaryCard<Destination: View>: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let profile: LifeRouteClientProfile
    private let destination: Destination
    let onRemove: () -> Void

    init(
        profile: LifeRouteClientProfile,
        @ViewBuilder destination: () -> Destination,
        onRemove: @escaping () -> Void
    ) {
        self.profile = profile
        self.destination = destination()
        self.onRemove = onRemove
    }

    var body: some View {
        ScenicRoyalCard(role: .readability) {
            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                identityBlock
                metricsBlock
                actions
            }
        }
    }

    private var identityBlock: some View {
        HStack(alignment: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            Text(profile.code)
                .font(.title3.weight(.bold))
                .foregroundStyle(style.accent)
                .frame(minWidth: 64, minHeight: 48)
                .scenicRoyalSurface(
                    role: .selectedControl,
                    cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(profile.code)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(style.primaryText)

                Label(
                    profile.address.isEmpty ? "No service address" : profile.address,
                    systemImage: "mappin.and.ellipse"
                )
                .font(.subheadline)
                .foregroundStyle(style.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)

            Spacer(minLength: 0)
        }
    }

    @ViewBuilder
    private var metricsBlock: some View {
        let metrics = [
            (profile.currentTargets.count, "Targets"),
            (profile.preferredActivities.count, "Preferred activities"),
            (profile.behaviorsOfConcern.count, "Behaviors"),
        ]

        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                ForEach(metrics, id: \.1) { metric in
                    ScenicRoyalClientMetric(value: metric.0, label: metric.1)
                }
            }
        } else {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                ForEach(metrics, id: \.1) { metric in
                    ScenicRoyalClientMetric(value: metric.0, label: metric.1)
                }
            }
        }
    }

    private var actions: some View {
        HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            NavigationLink {
                destination
            } label: {
                Label("Edit", systemImage: "pencil")
                    .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(style.accent)
            .accessibilityLabel("Edit client \(profile.code)")
            .accessibilityHint("Opens this client profile for editing")

            Button(role: .destructive, action: onRemove) {
                Label("Remove", systemImage: "trash")
                    .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove client \(profile.code)")
            .accessibilityHint("Immediately deletes this client profile and its saved associations")
        }
        .font(.subheadline.weight(.semibold))
    }
}

private struct ScenicRoyalClientMetric: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
            Text("\(value)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(style.primaryText)
            Text(label)
                .font(.caption)
                .foregroundStyle(style.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.compact)
        .scenicRoyalSurface(
            role: .ambient,
            cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(value) \(label.lowercased())")
    }
}

struct ScenicRoyalClientPrivacyNote: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    var body: some View {
        Label(
            "Store only the minimum client context needed for LifeRoute workflows. Avoid full names or unnecessary identifying information.",
            systemImage: "lock.shield.fill"
        )
        .font(.footnote)
        .foregroundStyle(style.secondaryText)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.hairline)
    }
}

struct ScenicRoyalClientTextEditor: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let title: String
    @Binding var text: String
    let minimumHeight: CGFloat

    var body: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(style.accentReflection)

            TextEditor(text: $text)
                .frame(minHeight: minimumHeight)
                .scrollContentBackground(.hidden)
                .padding(ScenicRoyalDesignSystem.Spacing.compact)
                .scenicRoyalInteractiveSurface(
                    role: .ambient,
                    cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
                )
                .accessibilityLabel(title)
        }
    }
}

struct ScenicRoyalClientSaveBar: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenicRoyalThemeStyle) private var style

    let isSaving: Bool
    let message: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
            Button(action: action) {
                Label(isSaving ? "Saving…" : "Save Client", systemImage: "checkmark.circle.fill")
            }
            .buttonStyle(ScenicRoyalPrimaryButtonStyle())
            .disabled(isSaving)

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Unable to save client. \(message)")
            }
        }
        .padding(.horizontal, LifeRouteDesign.Layout.pageHorizontal)
        .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
        .padding(.bottom, ScenicRoyalDesignSystem.Spacing.hairline)
        .background {
            if reduceTransparency {
                style.readabilityBase.opacity(0.98)
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
}
