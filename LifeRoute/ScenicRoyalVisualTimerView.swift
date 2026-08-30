import SwiftUI
import UIKit

struct VisualTimerView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenicRoyalThemeStyle) private var style

    @ObservedObject var timer: VisualTimerCore

    @State private var minutes = 5
    @State private var announcedMilestones: Set<VisualTimerAccessibilityMilestone> = []
#if DEBUG
    @State private var didStartDebugFixture = false
#endif

    private var toneColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.compact)]
        }
        return [
            GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.compact),
            GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.compact),
        ]
    }

    private var durationColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 54), spacing: ScenicRoyalDesignSystem.Spacing.compact)]
    }

    var body: some View {
        ScrollView {
            LazyVStack(spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                ScenicRoyalScreenHeader(
                    title: "Visual Timer",
                    subtitle: "A calm countdown that becomes clearer as time runs out."
                ) {
                    ScenicRoyalIconBadge(systemImage: "timer")
                }

                timerCard
                feedbackCard
                durationCard
                controlsCard

                Text("Timer preferences stay on this iPhone. The countdown uses its absolute deadline, so visual and audio feedback never own elapsed time.")
                    .font(.caption)
                    .foregroundStyle(style.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.hairline)
            }
            .padding(.horizontal, ScenicRoyalDesignSystem.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious * 2)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .onAppear {
#if DEBUG
            guard !didStartDebugFixture,
                  ProcessInfo.processInfo.arguments.contains("-LifeRouteVisualTimerAutoStart") else { return }
            didStartDebugFixture = true
            minutes = 1
            timer.start(minutes: 1)
#endif
        }
        .onReceive(timer.$deadline) { deadline in
            guard deadline == nil, timer.remainingSeconds() <= 0 else { return }
            if timer.completionHapticsEnabled {
                LifeRouteHaptics.success()
            }
        }
    }

    private var timerCard: some View {
        TimelineView(.periodic(from: .now, by: reduceMotion ? 1.0 : 0.10)) { context in
            let remaining = timer.remainingSeconds(at: context.date)
            let remainingProgress = timer.progress(at: context.date)
            let urgency = timer.urgency(forRemaining: remaining)
            let tempo = timer.pulsesPerSecond(forRemaining: remaining)
            let interval = 1.0 / tempo
            let pulsePhase = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: interval) / interval
            let milestone = VisualTimerAccessibilityMilestone.forRemaining(remaining)

            VStack(spacing: ScenicRoyalDesignSystem.Spacing.comfortable) {
                timerStatus(
                    text: statusText(at: context.date),
                    icon: statusIcon(at: context.date),
                    urgency: urgency
                )

                ScenicRoyalTimerDial(
                    remainingText: timerText(remaining),
                    remainingProgress: remainingProgress,
                    urgency: urgency,
                    pulsePhase: pulsePhase,
                    isRunning: timer.isRunning,
                    isFinished: timer.isFinished(at: context.date),
                    reduceMotion: reduceMotion
                )

                ProgressView(value: remainingProgress)
                    .tint(style.accent)
                    .accessibilityLabel("Timer progress")
                    .accessibilityValue("\(Int((remainingProgress * 100).rounded())) percent remaining")
            }
            .onChange(of: milestone) { newMilestone in
                announceIfNeeded(newMilestone)
            }
        }
        .scenicRoyalCard(role: .readability)
    }

    @ViewBuilder
    private func timerStatus(text: String, icon: String, urgency: Double) -> some View {
        let status = Label(text, systemImage: icon)
            .font(.caption.weight(.bold))
            .foregroundStyle(timer.isRunning ? style.accent : style.secondaryText)
        let urgencyStatus = Text(urgencyLabel(urgency))
            .font(.caption2.weight(.bold))
            .foregroundStyle(style.accentReflection)
            .padding(.horizontal, ScenicRoyalDesignSystem.Spacing.standard)
            .frame(minHeight: 32)
            .scenicRoyalSurface(
                role: .ambient,
                cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
            )

        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                status
                urgencyStatus
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                status
                Spacer(minLength: ScenicRoyalDesignSystem.Spacing.compact)
                urgencyStatus
            }
        }
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            ScenicRoyalSectionHeader(
                "Feedback",
                subtitle: "Choose an audible tone, then control sound independently.",
                systemImage: "waveform.path"
            )

            ScenicRoyalGlassEffectContainer(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                LazyVGrid(columns: toneColumns, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                    ForEach(VisualTimerToneProfile.allCases) { profile in
                        Button {
                            timer.setToneProfile(profile)
                            LifeRouteHaptics.selection()
                        } label: {
                            ScenicRoyalToneChoice(
                                profile: profile,
                                isSelected: timer.toneProfile == profile
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(profile.title)
                        .accessibilityValue(timer.toneProfile == profile ? "Selected" : profile.detail)
                        .accessibilityHint("Selects the \(profile.title) timer feedback")
                    }
                }
            }

            Toggle(
                "Sound",
                isOn: Binding(
                    get: { timer.soundEnabled },
                    set: { timer.setSoundEnabled($0) }
                )
            )
            .tint(style.accent)
            .accessibilityHint("Turns timer tones on or off without changing the selected tone")

            VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                HStack {
                    Label("Volume", systemImage: timer.soundEnabled ? "speaker.wave.2" : "speaker.slash")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(style.primaryText)
                    Spacer()
                    Text(timer.soundEnabled ? "\(Int((timer.volume * 100).rounded()))%" : "Silent")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(style.accent)
                }

                Slider(
                    value: Binding(
                        get: { timer.volume },
                        set: { timer.setVolume($0) }
                    ),
                    in: 0...1
                )
                .tint(style.accent)
                .disabled(!timer.soundEnabled)
                .accessibilityLabel("Timer tone volume")
                .accessibilityValue(timer.soundEnabled ? "\(Int((timer.volume * 100).rounded())) percent" : "Silent")
            }
            .padding(.top, ScenicRoyalDesignSystem.Spacing.hairline)

            Toggle(
                "Completion haptic",
                isOn: Binding(
                    get: { timer.completionHapticsEnabled },
                    set: { timer.setCompletionHapticsEnabled($0) }
                )
            )
            .tint(style.accent)
            .accessibilityHint("Adds one optional haptic when the timer completes")

            Label(
                "Timer audio mixes with other audio and follows the iPhone Ring/Silent switch.",
                systemImage: "iphone.radiowaves.left.and.right"
            )
            .font(.caption)
            .foregroundStyle(style.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
        }
        .scenicRoyalCard(role: .readability)
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            ScenicRoyalSectionHeader(
                "Duration",
                subtitle: "Start quickly or choose a custom session length.",
                systemImage: "clock"
            )

            LazyVGrid(columns: durationColumns, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                ForEach([1, 2, 3, 5, 10], id: \.self) { preset in
                    Button {
                        startTimer(minutes: preset)
                    } label: {
                        Text("\(preset)m")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(minutes == preset ? ScenicRoyalDesignSystem.ColorToken.brandNavyDeep : style.primaryText)
                            .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
                            .background(
                                minutes == preset ? style.accent : Color.clear,
                                in: RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl, style: .continuous)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .scenicRoyalInteractiveSurface(
                        role: minutes == preset ? .selectedControl : .ambient,
                        cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl
                    )
                    .accessibilityLabel("Start \(preset)-minute timer")
                }
            }

            Stepper("Custom duration: \(minutes) minutes", value: $minutes, in: 1...180)
                .font(.subheadline.weight(.semibold))

            Button {
                startTimer(minutes: minutes)
            } label: {
                Label("Start \(minutes)-minute timer", systemImage: "play.fill")
            }
            .buttonStyle(ScenicRoyalPrimaryButtonStyle())
        }
        .scenicRoyalCard(role: .readability)
    }

    private var controlsCard: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            ScenicRoyalSectionHeader("Timer controls", systemImage: "slider.horizontal.3")

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        pauseResumeButton
                        addMinuteButton
                    }
                } else {
                    HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        pauseResumeButton
                        addMinuteButton
                    }
                }
            }

            Button {
                timer.reset()
                announcedMilestones.removeAll()
            } label: {
                Label("Reset timer", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(ScenicRoyalSecondaryButtonStyle())
        }
        .scenicRoyalCard(role: .readability)
    }

    private var pauseResumeButton: some View {
        Button {
            if timer.isRunning {
                timer.pause()
            } else {
                timer.resume()
            }
        } label: {
            Label(
                timer.isRunning ? "Pause" : "Resume",
                systemImage: timer.isRunning ? "pause.fill" : "play.fill"
            )
        }
        .buttonStyle(ScenicRoyalSecondaryButtonStyle())
        .disabled(!timer.isRunning && timer.remainingSeconds() <= 0)
    }

    private var addMinuteButton: some View {
        Button {
            timer.addMinute()
        } label: {
            Label("Add 1 minute", systemImage: "plus.circle")
        }
        .buttonStyle(ScenicRoyalSecondaryButtonStyle())
    }

    private func startTimer(minutes: Int) {
        self.minutes = minutes
        announcedMilestones.removeAll()
        timer.start(minutes: minutes)
        LifeRouteHaptics.primaryAction()
    }

    private func announceIfNeeded(_ milestone: VisualTimerAccessibilityMilestone?) {
        guard let milestone,
              !announcedMilestones.contains(milestone),
              UIAccessibility.isVoiceOverRunning,
              timer.isRunning || milestone == .complete else { return }

        announcedMilestones.insert(milestone)
        UIAccessibility.post(notification: .announcement, argument: milestone.announcement)
    }

    private func statusText(at date: Date) -> String {
        if timer.isFinished(at: date) { return "Finished" }
        return timer.isRunning ? "Running" : "Paused / ready"
    }

    private func statusIcon(at date: Date) -> String {
        if timer.isFinished(at: date) { return "checkmark.circle.fill" }
        return timer.isRunning ? "circle.fill" : "pause.circle"
    }

    private func urgencyLabel(_ urgency: Double) -> String {
        if urgency >= 0.72 { return "Closing moments" }
        if urgency >= 0.32 { return "Time getting close" }
        return "Calm pace"
    }

    private func timerText(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(ceil(seconds)))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct ScenicRoyalTimerDial: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let remainingText: String
    let remainingProgress: Double
    let urgency: Double
    let pulsePhase: Double
    let isRunning: Bool
    let isFinished: Bool
    let reduceMotion: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 15)

            if isRunning && !reduceMotion {
                Circle()
                    .stroke(
                        style.accentReflection.opacity((0.18 + urgency * 0.44) * (1 - pulsePhase)),
                        lineWidth: 3 + urgency * 3
                    )
                    .scaleEffect(0.92 + pulsePhase * (0.08 + urgency * 0.08))
            }

            Circle()
                .trim(from: 0, to: remainingProgress)
                .stroke(
                    AngularGradient(
                        colors: [style.accent, style.accentReflection, style.accent],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: 15, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(remainingText)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(style.primaryText)
                    .minimumScaleFactor(0.72)

                Text(isFinished ? "TIME IS UP" : "REMAINING")
                    .font(.caption2.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(style.secondaryText)
            }
        }
        .frame(maxWidth: 238, maxHeight: 238)
        .aspectRatio(1, contentMode: .fit)
        .shadow(color: style.accent.opacity(0.10 + urgency * 0.16), radius: 18 + urgency * 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isFinished ? "Timer complete" : "Time remaining")
        .accessibilityValue(remainingText)
    }
}

private struct ScenicRoyalToneChoice: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let profile: VisualTimerToneProfile
    let isSelected: Bool

    var body: some View {
        HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
            Image(systemName: profile.systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(isSelected ? ScenicRoyalDesignSystem.ColorToken.brandNavyDeep : style.accent)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(profile.title)
                    .font(.subheadline.weight(.semibold))
                Text(profile.detail)
                    .font(.caption2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(isSelected ? ScenicRoyalDesignSystem.ColorToken.brandNavyDeep : style.primaryText)

            Spacer(minLength: ScenicRoyalDesignSystem.Spacing.hairline)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(ScenicRoyalDesignSystem.ColorToken.brandNavyDeep)
                    .accessibilityHidden(true)
            }
        }
        .padding(ScenicRoyalDesignSystem.Spacing.standard)
        .frame(maxWidth: .infinity, minHeight: 66, alignment: .leading)
        .background(
            isSelected ? style.accent : Color.clear,
            in: RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous)
        )
        .contentShape(RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous))
        .scenicRoyalInteractiveSurface(
            role: isSelected ? .selectedControl : .ambient,
            cornerRadius: ScenicRoyalDesignSystem.Radius.control
        )
    }
}
