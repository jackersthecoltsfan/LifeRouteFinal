import SwiftUI
import UIKit
import Combine

struct VisualTimerView: View {
    @Environment(\.lifeRouteTheme) private var theme
    @EnvironmentObject private var visibility: LifeRouteVisibilityOwner
    @Environment(\.lifeRoutePresentation) private var visibilityScope
    @State private var hapticsActive = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var hero: VisualTimerHeroCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenicRoyalThemeStyle) private var style
    @Environment(\.scenePhase) private var scenePhase

    @ObservedObject var timer: VisualTimerCore

    @State private var minutes = 5
    @StateObject private var presentation: VisualTimerPresentationState
    @State private var isVisible = false
    @State private var hapticActivityID = UUID()
#if DEBUG
    @State private var didStartDebugFixture = false
    @State private var didApplyFullScreenFixture = false
#endif

    init(timer: VisualTimerCore) {
        self.timer = timer
        _presentation = StateObject(wrappedValue: VisualTimerPresentationState(timer: timer))
    }

    private var toneColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.compact)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: ScenicRoyalDesignSystem.Spacing.compact), count: 3)
    }

    private var durationColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 54), spacing: ScenicRoyalDesignSystem.Spacing.compact)]
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ScenicRoyalDesignSystem.Spacing.standard) {
                HStack {
                    UI01MarbleText(title: "Visual Timer", size: 30, relativeTo: .title)
                        .modifier(UI01ReadingZone())
                        .accessibilityAddTraits(.isHeader)
                    Spacer()
                    Image(systemName: "timer").foregroundStyle(style.accent)
                }

                ScenicRoyalTimerReadout(
                    timer: timer,
                    motionDriver: presentation.motionDriver,
                    isActive: isVisible && scenePhase == .active,
                    canvasSize: 252,
                    compact: true,
                    hero: hero,
                    announce: presentation.announceIfNeeded
                )
                .environment(\.scenicRoyalThemeStyle, theme.scenicRoyalStyle)
                durationCard
                if timer.isRunning {
                    ScenicRoyalTimerControls(timer: timer, reset: presentation.reset)
                } else {
                    Button { startTimer(minutes: minutes) } label: {
                        Label("Start \(minutes)-minute timer", systemImage: "play.fill")
                    }
                    .buttonStyle(ScenicRoyalPrimaryButtonStyle())
                    DisclosureGroup("Resume & adjust timer") {
                        ScenicRoyalTimerControls(timer: timer, reset: presentation.reset)
                    }
                    .foregroundStyle(style.contentPrimaryForeground)
                }
                feedbackCard
            }
            .padding(.horizontal, ScenicRoyalDesignSystem.Layout.pageHorizontal)
            .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            .padding(.bottom, ScenicRoyalDesignSystem.Spacing.spacious * 2)
            // Preserve the live anchor and timer ownership while the root Hero
            // owns presentation. Restore only after collapse/fallback settles.
            .opacity(hero.blocksNavigation ? 0 : 1)
            .allowsHitTesting(!hero.blocksNavigation)
            .accessibilityHidden(hero.blocksNavigation)
        }
        // Keep the timer's scrollable presentation below the NavigationStack's
        // live top safe area and retain a small, token-based breathing margin.
        // This avoids a device-specific navigation-bar height while leaving the
        // timer model and visual material unchanged.
        .safeAreaInset(edge: .top, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            Color.clear.frame(height: 0)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        // The system navigation bar owns the scroll-edge material for this deep
        // destination. Hiding it allowed scrolled timer content to remain
        // visibly behind the fixed back control despite the passing initial
        // safe-area inset above.
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    presentation.expand()
                } label: {
                    Label("Full screen", systemImage: "arrow.up.left.and.arrow.down.right")
                }
                .accessibilityLabel("Open timer full screen")
                .accessibilityHint("Expands the current timer without changing it")
                .accessibilityIdentifier("visualTimer.expand")
                .opacity(hero.blocksNavigation ? 0 : 1)
                .disabled(hero.blocksNavigation)
                .accessibilityHidden(hero.blocksNavigation)
            }
        }
        .navigationBarBackButtonHidden(hero.blocksNavigation)
        .onChange(of: minutes) { _ in bindHero() }
        .onAppear {
            bindHero()
            presentation.trace("embedded.appear")
#if DEBUG
            if !didApplyFullScreenFixture,
               ProcessInfo.processInfo.arguments.contains("-LifeRouteVisualTimerFullScreen") {
                didApplyFullScreenFixture = true
                presentation.expand()
            }

            guard !didStartDebugFixture,
                  ProcessInfo.processInfo.arguments.contains("-LifeRouteVisualTimerAutoStart") else { return }
            didStartDebugFixture = true
            minutes = 1
            timer.start(minutes: 1)
#endif
        }
        .lifeRouteReconcile { context in
            isVisible = context.active
            hero.setActive(context.active)
            // One logical owner in the existing presentation layer spans the
            // embedded/hero handoff. The scheduler stays shared.
            let active = visibility.timerActive(in: visibilityScope)
            if active != hapticsActive {
                hapticsActive = active
                presentation.setHapticsActive(active, owner: hapticActivityID)
            }
        }
        .onDisappear {
            presentation.trace("embedded.disappear")
        }
    }

    private var feedbackCard: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            DisclosureGroup("Sound, haptics & preferences") {
                VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
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
            .tint(style.selectedControlFill)
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

            Toggle("Open timer full screen when started", isOn: $presentation.opensFullScreenOnStart)
                .tint(style.selectedControlFill)
                .accessibilityHint("Applies to the next Start; closing full screen keeps the timer running")
                .accessibilityIdentifier("visualTimer.autoFullScreen")

            Toggle(
                "Timer haptics",
                isOn: Binding(
                    get: { timer.completionHapticsEnabled },
                    set: { timer.setCompletionHapticsEnabled($0) }
                )
                )
                .tint(style.selectedControlFill)
                .accessibilityHint("Adds escalating final fifteen second haptics and one distinct completion haptic")

            Label(
                "When Sound is on, timer audio stays audible even when the iPhone Ring/Silent switch is set to Silent.",
                systemImage: "iphone.radiowaves.left.and.right"
            )
            .font(.caption)
            .foregroundStyle(style.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, ScenicRoyalDesignSystem.Spacing.compact)
            }
            .foregroundStyle(style.contentPrimaryForeground)
        }
        .scenicRoyalCard(role: .readability)
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            Text("Duration · quick start")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(style.contentPrimaryForeground)

            LazyVGrid(columns: durationColumns, spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                ForEach([1, 2, 3, 5, 10], id: \.self) { preset in
                    Button {
                        startTimer(minutes: preset)
                    } label: {
                        Text("\(preset)m")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(minutes == preset ? style.selectedControlForeground : style.contentPrimaryForeground)
                            .frame(maxWidth: .infinity, minHeight: ScenicRoyalDesignSystem.Layout.minimumTouchTarget)
                            .background {
                                if minutes == preset {
                                    ScenicRoyalSelectedControlMaterial(
                                        shape: RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.compactControl, style: .continuous)
                                    )
                                }
                            }
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

            Stepper("Custom duration: \(minutes) minutes", value: $minutes, in: 1...VisualTimerDuration.maximumMinutes)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(style.contentPrimaryForeground)
        }
        .scenicRoyalCard(role: .readability)
    }

    private func bindHero() {
        hero.bind(presentation, minutes: minutes,
                  start: { startTimer(minutes: minutes) }, back: { dismiss() })
    }

    private func startTimer(minutes: Int) {
        self.minutes = minutes
        presentation.start(minutes: minutes)
        LifeRouteHaptics.primaryAction()
    }
}


/// UI-owned presentation state. SessionToolsCore remains the timer's lifetime
/// owner; this object retains that same instance, follows its shared beat for
/// bounded urgency haptics, and observes its completion edge exactly once. It
/// never owns a countdown or audio cadence.
@MainActor
final class VisualTimerPresentationState: ObservableObject {
    static let preferenceKey = "liferoute.visualTimer.openFullScreenOnStart.v1"

    let timer: VisualTimerCore
    let motionDriver = VisualTimerOrbPresentationDriver()
    @Published var isFullScreen = false {
        didSet {
            if oldValue != isFullScreen { trace(isFullScreen ? "expand" : "close") }
        }
    }
    @Published var opensFullScreenOnStart: Bool {
        didSet { preferenceStore.set(opensFullScreenOnStart, forKey: Self.preferenceKey) }
    }

    private let preferenceStore: UserDefaults
    private var completionSubscription: AnyCancellable?
    private var completionGenerationSubscription: AnyCancellable?
    private var beatSubscription: AnyCancellable?
    private var generationSubscription: AnyCancellable?
    private var announcedMilestones: Set<VisualTimerAccessibilityMilestone> = []
    private var urgencyHapticSubselector = VisualTimerUrgencyHapticSubselector()
    private var pendingUrgencyHaptics: [String: Task<Void, Never>] = [:]
    private var pendingCompletionHaptics: [Int: Task<Void, Never>] = [:]
    private var hapticActiveOwners: Set<UUID> = []
    private let completionHapticFeedback: @MainActor (Double) -> Void
    private let urgencyHapticFeedback: @MainActor (Double) -> Void

    init(
        timer: VisualTimerCore,
        preferenceStore: UserDefaults = .standard,
        completionHapticFeedback: @escaping @MainActor (Double) -> Void = { LifeRouteHaptics.timerCompletion(intensity: $0) },
        urgencyHapticFeedback: @escaping @MainActor (Double) -> Void = { LifeRouteHaptics.timerUrgency(intensity: $0) }
    ) {
        self.timer = timer
        self.preferenceStore = preferenceStore
        self.completionHapticFeedback = completionHapticFeedback
        self.urgencyHapticFeedback = urgencyHapticFeedback
        // UserDefaults.bool is false when unset. Reading does not reset a
        // previously stored choice or persist any timer/presentation state.
        opensFullScreenOnStart = preferenceStore.bool(forKey: Self.preferenceKey)
        completionGenerationSubscription = timer.completionGenerationPublisher.sink { [weak self] _ in
            self?.invalidateCompletionHaptics()
        }
        completionSubscription = timer.completionCuePublisher.sink { [weak self] event in
            self?.scheduleCompletionHaptics(for: event)
        }
        beatSubscription = timer.presentationBeatPublisher.sink { [weak self] beat in
            guard let self else { return }
            let uptime = ProcessInfo.processInfo.systemUptime
            self.motionDriver.register(beat, at: uptime)
            self.scheduleUrgencyHaptic(for: beat, at: uptime)
        }
        generationSubscription = timer.presentationGenerationPublisher.sink { [weak self] generation in
            self?.motionDriver.invalidate(before: generation)
            self?.invalidateUrgencyHaptics()
        }
    }

    func expand() { isFullScreen = true }
    func close() { isFullScreen = false }

    func setHapticsActive(_ active: Bool, owner: UUID) {
        let wasActive = !hapticActiveOwners.isEmpty
        if active {
            hapticActiveOwners.insert(owner)
        } else {
            hapticActiveOwners.remove(owner)
        }
        if wasActive && hapticActiveOwners.isEmpty {
            trace("urgency.invalidate inactive")
            invalidateUrgencyHaptics()
            invalidateCompletionHaptics()
        }
    }

    func start(minutes: Int, now: Date = Date()) {
        announcedMilestones.removeAll()
        invalidateCompletionHaptics()
        timer.start(minutes: minutes, now: now)
        // Only the explicit Start action consults the preference. Observed
        // running state, Resume, adjustments and lifecycle never open a cover.
        if opensFullScreenOnStart, timer.isRunning, !isFullScreen {
            isFullScreen = true
        }
        trace("start")
    }

    func reset() {
        invalidateCompletionHaptics()
        timer.reset()
        announcedMilestones.removeAll()
        trace("reset")
    }

    func announceIfNeeded(_ milestone: VisualTimerAccessibilityMilestone?) {
        guard let milestone,
              !announcedMilestones.contains(milestone),
              UIAccessibility.isVoiceOverRunning,
              timer.isRunning || milestone == .complete else { return }
        announcedMilestones.insert(milestone)
        UIAccessibility.post(notification: .announcement, argument: milestone.announcement)
    }

    func trace(_ event: String) {
#if DEBUG
        guard ProcessInfo.processInfo.arguments.contains("-LifeRouteVisualTimerDiagnostics") else { return }
        let deadline = timer.deadline.map { String($0.timeIntervalSince1970) } ?? "nil"
        print("PHASE1AH_TIMER event=\(event) owner=\(ObjectIdentifier(self)) timer=\(ObjectIdentifier(timer)) fullScreen=\(isFullScreen) running=\(timer.isRunning) deadline=\(deadline) remaining=\(timer.remainingSeconds()) duration=\(timer.durationSeconds)")
#endif
    }

    private func scheduleUrgencyHaptic(
        for beat: VisualTimerPresentationBeat,
        at uptime: TimeInterval
    ) {
        guard !hapticActiveOwners.isEmpty else {
            trace("urgency.suppressed no-active-owner beat=\(beat.generation):\(beat.index)")
            return
        }
        let delay = max(0, beat.plannedUptime - uptime)
        let remainingAtBeat = timer.remainingSeconds(
            at: Date().addingTimeInterval(delay)
        )
        guard let event = urgencyHapticSubselector.event(
            for: beat,
            remainingSeconds: remainingAtBeat
        ) else {
            trace("urgency.not-selected beat=\(beat.generation):\(beat.index) remaining=\(remainingAtBeat)")
            return
        }

        let key = "\(event.generation):\(event.index)"
        pendingUrgencyHaptics[key]?.cancel()
        trace("urgency.selected beat=\(key) plannedUptime=\(event.plannedUptime) remaining=\(remainingAtBeat) intensity=\(event.intensity) delay=\(delay)")
        pendingUrgencyHaptics[key] = Task { [weak self] in
            if delay > 0 {
                do {
                    try await Task.sleep(
                        nanoseconds: UInt64(delay * 1_000_000_000)
                    )
                } catch {
                    return
                }
            }
            guard let self else { return }
            guard !Task.isCancelled else {
                self.trace("urgency.cancelled beat=\(key)")
                return
            }
            guard !self.hapticActiveOwners.isEmpty else {
                self.trace("urgency.suppressed inactive-at-delivery beat=\(key)")
                return
            }
            guard self.timer.completionHapticsEnabled else {
                self.trace("urgency.suppressed preference-off beat=\(key)")
                return
            }
            guard self.timer.isRunning else {
                self.trace("urgency.suppressed timer-not-running beat=\(key)")
                return
            }
            let remaining = self.timer.remainingSeconds()
            guard remaining >= VisualTimerUrgencyHapticSubselector.completionSeparation,
                  remaining <= VisualTimerUrgencyHapticSubselector.window else {
                self.trace("urgency.suppressed window-at-delivery beat=\(key) remaining=\(remaining)")
                return
            }
            let requestUptime = ProcessInfo.processInfo.systemUptime
            self.trace("urgency.requested beat=\(key) plannedUptime=\(event.plannedUptime) requestUptime=\(requestUptime) lateness=\(requestUptime - event.plannedUptime) remaining=\(remaining) intensity=\(event.intensity)")
            self.urgencyHapticFeedback(event.intensity)
            self.pendingUrgencyHaptics.removeValue(forKey: key)
        }
    }

    private func invalidateUrgencyHaptics() {
        pendingUrgencyHaptics.values.forEach { $0.cancel() }
        pendingUrgencyHaptics.removeAll()
        urgencyHapticSubselector.invalidate()
    }

    private func scheduleCompletionHaptics(for event: VisualTimerCompletionCueEvent) {
        invalidateCompletionHaptics()
        guard timer.completionHapticsEnabled,
              !hapticActiveOwners.isEmpty else {
            trace("completion.suppressed preference-or-inactive")
            return
        }

        for (index, beat) in VisualTimerCompletionCue.hapticBeatMap.enumerated() {
            let elapsed = max(0, ProcessInfo.processInfo.systemUptime - event.cueStartUptime)
            let delay = max(0, beat.cueOffset - elapsed)
            trace("completion.beat=\(index) offset=\(beat.cueOffset) intensity=\(beat.intensity) delay=\(delay)")
            pendingCompletionHaptics[index] = Task { [weak self] in
                if delay > 0 {
                    do {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    } catch {
                        return
                    }
                }
                guard let self else { return }
                defer { self.pendingCompletionHaptics.removeValue(forKey: index) }
                guard !Task.isCancelled,
                      !self.hapticActiveOwners.isEmpty,
                      self.timer.completionHapticsEnabled,
                      self.timer.isCurrentCompletionCue(event),
                      ProcessInfo.processInfo.systemUptime - event.cueStartUptime
                        <= VisualTimerCompletionCue.duration + VisualTimerCompletionCue.playbackTail else {
                    self.trace("completion.suppressed stale-or-inactive beat=\(index)")
                    return
                }
                self.completionHapticFeedback(beat.intensity)
            }
        }
    }

    private func invalidateCompletionHaptics() {
        pendingCompletionHaptics.values.forEach { $0.cancel() }
        pendingCompletionHaptics.removeAll()
    }
}

// Kept as the existing fullscreen chrome seam; the Orb lives solely at root.
struct ScenicRoyalFullScreenTimerView: View {
    @Environment(\.scenicRoyalThemeStyle) private var style
    @ObservedObject var hero: VisualTimerHeroCoordinator

    var body: some View {
        HStack(spacing: 12) {
            Button { [hero] in
                hero.navigate { [weak hero] in hero?.back?() }
            } label: {
                Label("Back", systemImage: "chevron.left")
                    .frame(minHeight: 44)
            }
            .accessibilityIdentifier("visualTimer.back")
            Spacer(minLength: 0)
            UI01MarbleText(title: "Visual Timer", size: 22, relativeTo: .headline)
            Spacer(minLength: 0)
            Button { hero.presentation?.expand() } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Open timer full screen")
            .accessibilityIdentifier("visualTimer.heroExpand")
            Button { hero.presentation?.close() } label: {
                Image(systemName: "xmark").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Close full screen")
            .accessibilityHint("Returns to Visual Timer without stopping the countdown")
            .accessibilityIdentifier("visualTimer.close")
        }
        .buttonStyle(.plain)
        .foregroundStyle(UI01Material.silver)
        .modifier(UI01ReadingZone())
        .accessibilityAction(.escape) { hero.presentation?.close() }
    }
}

struct ScenicRoyalHeroOrbReadout: View {
    @ObservedObject var hero: VisualTimerHeroCoordinator
    let presentation: VisualTimerPresentationState
    var body: some View {
        ScenicRoyalTimerReadout(timer: presentation.timer, motionDriver: presentation.motionDriver,
            isActive: hero.orbActive, canvasSize: 340, compact: true, orbOnly: true,
            announce: presentation.announceIfNeeded)
    }
}

struct ScenicRoyalTimerReadout: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenicRoyalThemeStyle) private var style

    @ObservedObject var timer: VisualTimerCore
    let motionDriver: VisualTimerOrbPresentationDriver
    let isActive: Bool
    var canvasSize: CGFloat = 340
    var compact = false
    var orbOnly = false
    var hero: VisualTimerHeroCoordinator? = nil
    let announce: (VisualTimerAccessibilityMilestone?) -> Void

    var body: some View {
        // A stable schedule/view path keeps the sole Orb identity through activity changes.
        TimelineView(.periodic(from: .now, by: isActive ? VisualTimerFeedbackCurve.readoutInterval : 86_400)) { context in
            readout(at: context.date)
        }
    }

    @ViewBuilder
    private func readout(at date: Date) -> some View {
            let remaining = timer.remainingSeconds(at: date)
            let livePresentation = VisualTimerPresentationSnapshot(
                durationSeconds: timer.durationSeconds,
                remainingSeconds: remaining,
                remainingProgress: timer.progress(at: date),
                elapsedProgress: timer.normalizedElapsedProgress(forRemaining: remaining),
                urgency: timer.urgency(forRemaining: remaining),
                isRunning: timer.isRunning,
                isFinished: timer.isFinished(at: date)
            )
#if DEBUG
            let presentation = VisualTimerPresentationSnapshot.staticReviewFixture ?? livePresentation
#else
            let presentation = livePresentation
#endif
            let milestone = VisualTimerAccessibilityMilestone.forRemaining(remaining)

            VStack(spacing: compact ? ScenicRoyalDesignSystem.Spacing.compact : ScenicRoyalDesignSystem.Spacing.comfortable) {
                if !orbOnly && (!compact || timer.isRunning) {
                timerStatus(
                    text: statusText(at: date),
                    icon: statusIcon(at: date),
                    urgency: presentation.urgency
                )
                }

                if let hero {
                    VisualTimerHeroAnchor(hero: hero)
                        .frame(width: canvasSize, height: canvasSize)
                        .accessibilityHidden(true)
                } else {
                ScenicRoyalTimerOrb(
                    timer: timer,
                    motionDriver: motionDriver,
                    isActive: isActive,
                    snapshot: presentation,
                    remainingText: timerText(presentation.remainingSeconds),
                    reduceTransparency: reduceTransparency
                )
                // Scale the complete accepted 340-point canvas uniformly,
                // including its 932/1024 nominal sphere registration.
                .scaleEffect(canvasSize / 340)
                .frame(width: canvasSize, height: canvasSize)

                }

                if !compact && !orbOnly {
                ProgressView(value: presentation.remainingProgress)
                    .tint(style.accent)
                    .accessibilityLabel("Timer progress")
                    .accessibilityValue("\(Int((presentation.remainingProgress * 100).rounded())) percent remaining")
                }
            }
            .onChange(of: milestone) { newMilestone in
                if isActive { announce(newMilestone) }
            }
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
            .background(
                style.readabilityBase.opacity(reduceTransparency ? 0.92 : 0.16),
                in: Capsule()
            )
            .overlay {
                Capsule()
                    .stroke(style.accentReflection.opacity(0.20), lineWidth: 0.7)
            }

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
        let boundedSeconds = VisualTimerDuration.clamp(seconds)
        let total = Int(ceil(boundedSeconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

struct ScenicRoyalTimerControls: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ObservedObject var timer: VisualTimerCore
    let reset: () -> Void
    var start: (() -> Void)? = nil
    var startTitle: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: ScenicRoyalDesignSystem.Spacing.standard) {
            ScenicRoyalSectionHeader("Timer controls", systemImage: "slider.horizontal.3")

            if let start, !timer.isRunning {
                Button(action: start) {
                    Label(startTitle, systemImage: "play.fill")
                }
                .buttonStyle(ScenicRoyalPrimaryButtonStyle())
            }

            Group {
                if dynamicTypeSize.isAccessibilitySize {
                    VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        pauseResumeButton
                        quickAdjustmentButtons
                        addMinuteButton
                    }
                } else {
                    VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                        HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                            pauseResumeButton
                            addMinuteButton
                        }
                        quickAdjustmentButtons
                    }
                }
            }

            Button {
                reset()
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

    @ViewBuilder
    private var quickAdjustmentButtons: some View {
        if start != nil && dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                subtractSecondsButton
                addSecondsButton
            }
        } else {
            HStack(spacing: ScenicRoyalDesignSystem.Spacing.compact) {
                subtractSecondsButton
                addSecondsButton
            }
        }
    }

    private var subtractSecondsButton: some View {
        Button {
            timer.adjustRemainingSeconds(by: -VisualTimerAdjustment.quickAdjustmentSeconds)
        } label: {
            Label("−15 sec", systemImage: "minus.circle")
        }
        .buttonStyle(ScenicRoyalSecondaryButtonStyle())
        .disabled(timer.remainingSeconds() <= 0)
        .accessibilityLabel("Subtract 15 seconds")
        .accessibilityHint("Removes exactly 15 seconds from the timer")
    }

    private var addSecondsButton: some View {
        Button {
            timer.adjustRemainingSeconds(by: VisualTimerAdjustment.quickAdjustmentSeconds)
        } label: {
            Label("+15 sec", systemImage: "plus.circle")
        }
        .buttonStyle(ScenicRoyalSecondaryButtonStyle())
        .accessibilityLabel("Add 15 seconds")
        .accessibilityHint("Adds exactly 15 seconds to the timer")
    }
}

internal struct VisualTimerPresentationSnapshot: Equatable {
    let durationSeconds: TimeInterval
    let remainingSeconds: TimeInterval
    let remainingProgress: Double
    let elapsedProgress: Double
    let urgency: Double
    let isRunning: Bool
    let isFinished: Bool

#if DEBUG
    // Presentation-only static capture. No timer state, deadlines, preferences,
    // or completion side effects are overridden; Release contains no fixture.
    static let staticReviewFixture: Self? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-LifeRouteOrbStaticPercent"),
              arguments.indices.contains(index + 1),
              let percent = Double(arguments[index + 1]),
              [98.0, 75, 50, 25, 10, 5, 0].contains(percent) else { return nil }
        let remainingProgress = percent / 100
        let elapsedProgress = 1 - remainingProgress
        return Self(
            durationSeconds: 300,
            remainingSeconds: 300 * remainingProgress,
            remainingProgress: remainingProgress,
            elapsedProgress: elapsedProgress,
            urgency: VisualTimerFeedbackCurve.urgency(elapsedProgress),
            isRunning: false,
            isFinished: percent == 0
        )
    }()

    static let reviewHidesOrb = staticReviewFixture != nil
        && ProcessInfo.processInfo.arguments.contains("-LifeRouteOrbReviewBackground")

    // Fixed fill with live presentation motion, for bounded Simulator capture.
    // This opt-in never starts or adjusts the actual timer.
    static let reviewMovesLiquid = staticReviewFixture != nil
        && ProcessInfo.processInfo.arguments.contains("-LifeRouteOrbMotionReview")
#endif
}

private struct ScenicRoyalTimerOrb: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    @ObservedObject var timer: VisualTimerCore
    let motionDriver: VisualTimerOrbPresentationDriver
    let isActive: Bool
    let snapshot: VisualTimerPresentationSnapshot
    let remainingText: String
    let reduceTransparency: Bool

    private let canvasSize: CGFloat = 340

    var body: some View {
        ZStack {
            ScenicRoyalOrbMaterialStack(
                timer: timer,
                motionDriver: motionDriver,
                isActive: isActive,
                snapshot: snapshot,
                reduceTransparency: reduceTransparency
            )

            VStack(spacing: ScenicRoyalDesignSystem.Spacing.hairline) {
                Text(remainingText)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(style.primaryText)
                    .minimumScaleFactor(0.72)

                Text(snapshot.isFinished ? "TIME IS UP" : "REMAINING")
                    .font(.caption2.weight(.bold))
                    .tracking(1.3)
                    .foregroundStyle(style.primaryText.opacity(0.92))
            }
            .accessibilityHidden(true)
        }
        .frame(width: canvasSize, height: canvasSize)
#if DEBUG
        .opacity(VisualTimerPresentationSnapshot.reviewHidesOrb ? 0 : 1)
        .background {
            if VisualTimerPresentationSnapshot.staticReviewFixture != nil {
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        let bounds = proxy.frame(in: .global)
                        let image = UIImage(named: "orb_v04_accepted_material")?.cgImage
                        print("PHASE1AG_ORB bounds=\(bounds) asset=\(image?.width ?? 0)x\(image?.height ?? 0) colorspace=\(String(describing: image?.colorSpace?.name)) alpha=\(String(describing: image?.alphaInfo))")
                    }
                }
            }
        }
#endif
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(snapshot.isFinished ? "Timer complete" : "Time remaining")
        .accessibilityValue(remainingText)
    }
}

private struct ScenicRoyalOrbMaterialStack: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var timer: VisualTimerCore
    let motionDriver: VisualTimerOrbPresentationDriver
    @State private var activityID = UUID()
    @State private var isVisible = false

    let isActive: Bool
    let snapshot: VisualTimerPresentationSnapshot
    let reduceTransparency: Bool

    private let canvasSize: CGFloat = 340

    private var canAnimate: Bool {
#if DEBUG
        let running = timer.isRunning || VisualTimerPresentationSnapshot.reviewMovesLiquid
#else
        let running = timer.isRunning
#endif
        return isVisible && isActive && !reduceMotion && running && !timer.isFinished()
    }

    var body: some View {
        // One driver owns only the material composite. Text, scenery, controls
        // and layout stay outside this frame cadence.
        TimelineView(.animation(minimumInterval: VisualTimerOrbMotionFrame.interval, paused: !canAnimate)) { context in
            material(at: context.date)
        }
        .frame(width: canvasSize, height: canvasSize)
        // Keep V04's alpha-1 optical fringes outside the nominal sphere.
        // Canonical Canvas regions still clip all liquid to the existing well.
        .accessibilityHidden(true)
        .onAppear {
            isVisible = true
            updateMotionActivity()
        }
        .onChange(of: canAnimate) { active in
            // The delivered value is authoritative. Re-reading captured self
            // here used a stale readout snapshot and could unregister a live Orb.
            motionDriver.setActive(active, owner: activityID, at: ProcessInfo.processInfo.systemUptime)
        }
        .onDisappear {
            isVisible = false
            motionDriver.setActive(false, owner: activityID, at: ProcessInfo.processInfo.systemUptime)
        }
    }

    private func updateMotionActivity() {
        motionDriver.setActive(canAnimate, owner: activityID, at: ProcessInfo.processInfo.systemUptime)
    }

    private func material(at date: Date) -> some View {
        // Query the same core at the display date, so the surface drains smoothly
        // without interpolating, accumulating, or predicting timer progress.
        // A paused animation schedule retains its last date. The readout still
        // refreshes once per second under Reduce Motion using a fresh core query.
        let frameDate = canAnimate ? date : Date()
        let remaining = timer.remainingSeconds(at: frameDate)
        let liveSnapshot = VisualTimerPresentationSnapshot(
            durationSeconds: timer.durationSeconds,
            remainingSeconds: remaining,
            remainingProgress: timer.progress(at: frameDate),
            elapsedProgress: timer.normalizedElapsedProgress(forRemaining: remaining),
            urgency: timer.urgency(forRemaining: remaining),
            isRunning: timer.isRunning,
            isFinished: timer.isFinished(at: frameDate)
        )
#if DEBUG
        let snapshot = VisualTimerPresentationSnapshot.staticReviewFixture ?? liveSnapshot
#else
        let snapshot = liveSnapshot
#endif
        let progress = min(1, max(0, snapshot.remainingProgress))
        // Use the animation schedule's date for both material and beat phase.
        // TimelineView exposes a scheduled update date, not a photon timestamp;
        // do not invent a display-link advance or add audio latency twice.
        let uptime = ProcessInfo.processInfo.systemUptime
        let scheduledUptime = uptime + frameDate.timeIntervalSinceNow
        let timing = motionDriver.timing(at: canAnimate ? scheduledUptime : uptime)
        let motion = reduceMotion ? .still : VisualTimerOrbMotionFrame(
            elapsed: timing.elapsed,
            progress: snapshot.isFinished ? 0 : progress,
            urgency: snapshot.urgency,
            pulsePhase: timing.pulsePhase
        )
        let regions = VisualTimerOrbRegions(progress: snapshot.isFinished ? 0 : CGFloat(progress), motion: motion)
#if DEBUG
        motionDriver.traceFrame(scheduleDate: date, uptime: ProcessInfo.processInfo.systemUptime,
                                timing: timing, motion: motion, active: canAnimate)
#endif
        return ZStack {
            // The single accepted RGBA source is warped only inside the shell.
            // The native liquid is composited afterwards, using unwarped regions.
            livingMaterial(motion: motion)
            ScenicRoyalOrbCanvas(
                snapshot: snapshot,
                reduceTransparency: reduceTransparency,
                motion: motion,
                regions: regions
            )
        }
    }

    @ViewBuilder
    private func livingMaterial(motion: VisualTimerOrbMotionFrame) -> some View {
        let material = registeredMaterial("orb_v04_accepted_material")
        if #available(iOS 17.0, *) {
            material.distortionEffect(
                ShaderLibrary.livingOrbInterior(
                    .float(motion.crystalTime),
                    .float(motion.crystalEnergy),
                    .float(motion.alertness),
                    .float(motion.pulse)
                ),
                maxSampleOffset: CGSize(width: 40, height: 40),
                isEnabled: motion.crystalEnergy > 0
            )
        } else {
            // iOS 16 keeps accepted artwork; the shared Canvas still animates liquid.
            material
        }
    }

    private func registeredMaterial(_ name: String) -> some View {
        // Preserve the existing canvas registration: 1024 px -> 340 pt.
        // Nominal sphere diameter is 932 px -> 309.453125 pt, not 340 pt.
        // Its 154.7265625 pt radius surrounds the protected 146 pt liquid well.
        Image(name)
            .renderingMode(.original)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .scaledToFill()
            .frame(width: canvasSize, height: canvasSize)
            .clipped()
    }
}

private struct ScenicRoyalOrbAboveLiquidMask: Shape {
    let regions: VisualTimerOrbRegions

    func path(in rect: CGRect) -> Path {
        regions.unsubmerged.applying(
            CGAffineTransform(
                scaleX: rect.width / VisualTimerOrbRegions.canvasSize,
                y: rect.height / VisualTimerOrbRegions.canvasSize
            )
        )
    }
}

private struct ScenicRoyalOrbShellMask: View {
    var body: some View {
        AngularGradient(
            stops: [
                .init(color: .white.opacity(0.72), location: 0.00),
                .init(color: .white.opacity(0.62), location: 0.08),
                .init(color: .white.opacity(0.18), location: 0.18),
                .init(color: .white.opacity(0.14), location: 0.27),
                .init(color: .white.opacity(0.48), location: 0.34),
                .init(color: .white.opacity(0.68), location: 0.48),
                .init(color: .white.opacity(0.54), location: 0.58),
                .init(color: .white.opacity(0.16), location: 0.68),
                .init(color: .white.opacity(0.14), location: 0.77),
                .init(color: .white.opacity(0.50), location: 0.86),
                .init(color: .white.opacity(0.68), location: 0.93),
                .init(color: .white.opacity(0.72), location: 1.00),
            ],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }
}

private struct ScenicRoyalOrbCanvas: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let snapshot: VisualTimerPresentationSnapshot
    let reduceTransparency: Bool
    let motion: VisualTimerOrbMotionFrame
    let regions: VisualTimerOrbRegions

    private let canvasSize: CGFloat = 340

    var body: some View {
        Canvas(opaque: false, colorMode: .extendedLinear) { context, size in
            let scale = min(size.width, size.height) / canvasSize
            var canvas = context
            canvas.scaleBy(x: scale, y: scale)

            let environmentBoost = style.isBrightEnvironment ? 1.08 : 1.0
            let boost = (reduceTransparency ? 1.28 : 1.0) * environmentBoost
            let alpha: (Double) -> Double = { min(1, $0 * boost) }
            let progress = min(1, max(0, snapshot.remainingProgress))
            let light = style.accentReflection
            let gold = style.accent
            let crystalBlue = Color(red: 0.12, green: 0.43, blue: 0.72)
            let dark = style.readabilityBase
            let surfaceY = regions.surfaceY
            canvas.clip(to: regions.well)

            // A bounded internal pressure light shares the audible beat. It
            // remains inside the liquid well and never scales the Orb or moves
            // its shell, typography, scenery, or controls.
            if motion.pulse > 0 {
                canvas.fill(
                    regions.well,
                    with: .radialGradient(
                        Gradient(colors: [
                            light.opacity(alpha(0.075 * motion.pulse)),
                            gold.opacity(alpha(0.026 * motion.pulse)),
                            .clear,
                        ]),
                        center: CGPoint(x: 158 + motion.driftX * 0.25, y: 168 + motion.driftY * 0.20),
                        startRadius: 0,
                        endRadius: 134
                    )
                )
            }

            // Canvas owns only the progress-dependent liquid and localized optics.
            // The surface is mapped by circular segment area so the Orb itself
            // communicates full, half, near-empty, and empty states.
            if !regions.liquid.isEmpty {
                // This is the authoritative liquid body only: 25% relative
                // opacity increase, including its existing depth stop.
                let bodyOpacity = 0.300 + (progress * 0.04375)
                let depthOpacity = 0.2625 + (progress * 0.04375)
                canvas.fill(
                    regions.liquid,
                    with: .linearGradient(
                        Gradient(colors: [
                            light.opacity(alpha(bodyOpacity)),
                            crystalBlue.opacity(alpha(bodyOpacity + 0.060)),
                            gold.opacity(alpha(bodyOpacity + 0.100)),
                            dark.opacity(alpha(depthOpacity)),
                        ]),
                        startPoint: CGPoint(x: 140 + motion.driftX * 3, y: surfaceY - 8),
                        endPoint: CGPoint(x: 170 - motion.driftX * 2, y: 330 + motion.driftY * 2)
                    )
                )
                canvas.stroke(
                    regions.meniscus,
                    with: .color(light.opacity(alpha(0.095 + (progress * 0.025)))),
                    style: StrokeStyle(lineWidth: progress > 0.08 ? 2.8 : 2.1)
                )
                canvas.stroke(
                    regions.meniscus,
                    with: .color(light.opacity(alpha(0.30 + (progress * 0.08)))),
                    style: StrokeStyle(lineWidth: progress > 0.08 ? 1.15 : 0.78)
                )
                canvas.stroke(
                    regions.meniscus,
                    with: .radialGradient(
                        Gradient(colors: [light.opacity(alpha(motion.sheen)), .clear]),
                        center: CGPoint(x: motion.sheenX, y: surfaceY),
                        startRadius: 0,
                        endRadius: 85
                    ),
                    style: StrokeStyle(lineWidth: 1.15)
                )
                var submergedAccent = canvas
                submergedAccent.clip(to: regions.liquid)
                submergedAccent.stroke(
                    regions.meniscusLower,
                    with: .color(gold.opacity(alpha(0.15 + (progress * 0.08)))),
                    style: StrokeStyle(lineWidth: 0.66)
                )
            }

            if !regions.liquid.isEmpty {
                let causticOpacity = alpha((0.160 + (progress * 0.12)) * motion.causticGain)
                var liquidOptics = canvas
                liquidOptics.clip(to: regions.liquid)
                // A broad moving pool stays visible even in the 5% reservoir.
                // Its center follows the scalar level; clipping uses the actual wave.
                let pool = CGPoint(x: 170 + motion.driftX * 3.6,
                                   y: surfaceY + (316 - surfaceY) * 0.62 + motion.driftY * 0.4)
                liquidOptics.fill(
                    regions.liquid,
                    with: .radialGradient(
                        Gradient(colors: [light.opacity(alpha(motion.sheen * 0.78)), .clear]),
                        center: pool, startRadius: 0, endRadius: 76
                    )
                )
                // Move optics inside the already established liquid clip.
                // The shell, well and shared liquid boundary never drift.
                liquidOptics.translateBy(x: motion.driftX, y: motion.driftY)
                liquidOptics.fill(
                    ScenicRoyalOrbPath.causticOneBody,
                    with: .linearGradient(
                        Gradient(colors: [
                            gold.opacity(causticOpacity),
                            light.opacity(causticOpacity * 0.24),
                            .clear,
                        ]),
                        startPoint: CGPoint(x: 64, y: 273),
                        endPoint: CGPoint(x: 128, y: 239)
                    )
                )
                liquidOptics.fill(
                    ScenicRoyalOrbPath.causticTwoBody,
                    with: .linearGradient(
                        Gradient(colors: [
                            light.opacity(causticOpacity * 0.68),
                            .clear,
                        ]),
                        startPoint: CGPoint(x: 187, y: 295),
                        endPoint: CGPoint(x: 239, y: 283)
                    )
                )
                liquidOptics.stroke(
                    ScenicRoyalOrbPath.causticThree,
                    with: .color(Color.white.opacity(causticOpacity * 0.54)),
                    style: StrokeStyle(lineWidth: 0.6, lineCap: .round)
                )
            }
        }
        .frame(width: canvasSize, height: canvasSize)
        .accessibilityHidden(true)
    }
}

private enum ScenicRoyalOrbPath {
    static let causticOneBody = Path { path in
        path.move(to: CGPoint(x: 59, y: 275))
        path.addCurve(
            to: CGPoint(x: 104, y: 257),
            control1: CGPoint(x: 79, y: 271),
            control2: CGPoint(x: 92, y: 260)
        )
        path.addCurve(
            to: CGPoint(x: 129, y: 236),
            control1: CGPoint(x: 114, y: 253),
            control2: CGPoint(x: 121, y: 242)
        )
        path.addCurve(
            to: CGPoint(x: 120, y: 247),
            control1: CGPoint(x: 126, y: 240),
            control2: CGPoint(x: 124, y: 245)
        )
        path.addCurve(
            to: CGPoint(x: 101, y: 267),
            control1: CGPoint(x: 114, y: 253),
            control2: CGPoint(x: 108, y: 262)
        )
        path.addCurve(
            to: CGPoint(x: 65, y: 281),
            control1: CGPoint(x: 92, y: 272),
            control2: CGPoint(x: 78, y: 278)
        )
        path.closeSubpath()
    }

    static let causticTwoBody = Path { path in
        path.move(to: CGPoint(x: 184, y: 293))
        path.addCurve(
            to: CGPoint(x: 211, y: 278),
            control1: CGPoint(x: 195, y: 289),
            control2: CGPoint(x: 203, y: 281)
        )
        path.addCurve(
            to: CGPoint(x: 241, y: 284),
            control1: CGPoint(x: 221, y: 277),
            control2: CGPoint(x: 232, y: 283)
        )
        path.addCurve(
            to: CGPoint(x: 211, y: 288),
            control1: CGPoint(x: 232, y: 287),
            control2: CGPoint(x: 222, y: 286)
        )
        path.addCurve(
            to: CGPoint(x: 189, y: 300),
            control1: CGPoint(x: 203, y: 292),
            control2: CGPoint(x: 196, y: 297)
        )
        path.closeSubpath()
    }

    static let causticThree = Path { path in
        path.move(to: CGPoint(x: 252, y: 232))
        path.addCurve(
            to: CGPoint(x: 275, y: 225),
            control1: CGPoint(x: 260, y: 231),
            control2: CGPoint(x: 268, y: 224)
        )
        path.addCurve(
            to: CGPoint(x: 289, y: 212),
            control1: CGPoint(x: 281, y: 222),
            control2: CGPoint(x: 286, y: 215)
        )
    }
}

private struct ScenicRoyalToneChoice: View {
    @Environment(\.scenicRoyalThemeStyle) private var style

    let profile: VisualTimerToneProfile
    let isSelected: Bool

    var body: some View {
        Text(profile.title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isSelected ? style.selectedControlForeground : style.contentPrimaryForeground)
            .padding(ScenicRoyalDesignSystem.Spacing.compact)
            .frame(maxWidth: .infinity, minHeight: 44)
        .background {
            if isSelected {
                ScenicRoyalSelectedControlMaterial(
                    shape: RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous)
                )
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: ScenicRoyalDesignSystem.Radius.control, style: .continuous))
        .scenicRoyalInteractiveSurface(
            role: isSelected ? .selectedControl : .ambient,
            cornerRadius: ScenicRoyalDesignSystem.Radius.control
        )
    }
}
