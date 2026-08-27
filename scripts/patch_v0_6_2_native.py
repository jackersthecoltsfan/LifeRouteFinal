#!/usr/bin/env python3
from __future__ import annotations

from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def write(path: str, text: str) -> None:
    (ROOT / path).write_text(text, encoding="utf-8")


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(f"v0.6.2 patch failed: {label} expected once, found {count}")
    return text.replace(old, new, 1)


def patch_intelligence() -> None:
    path = "LifeRoute/LifeRouteIntelligenceCore.swift"
    text = read(path)
    if "compactSessionNoteClientContext" in text:
        return

    old = '''        let clientCode = client?.code ?? "General / no client"
        let targets = client?.currentTargets.joined(separator: "; ") ?? "none"
        let behaviors = client?.behaviorsOfConcern.joined(separator: "; ") ?? "none"
        let communication = client?.communicationNotes ?? "none"
        let prompting = client?.promptingNotes ?? "none"
'''
    new = '''        let clientCode = client?.code ?? "General / no client"
        let clientContext = compactSessionNoteClientContext(client)
'''
    text = replace_once(text, old, new, "session-note client variables")

    old = '''        CLIENT IDENTIFIER — context only: \\(clientCode)
        SAVED TARGETS — context only: \\(targets)
        SAVED BEHAVIORS — context only: \\(behaviors)
        SAVED COMMUNICATION/FCT CONTEXT — context only: \\(communication)
        SAVED PROMPTING/REINFORCEMENT CONTEXT — context only: \\(prompting)

        SESSION NARRATIVE:
'''
    new = '''        CLIENT IDENTIFIER — context only: \\(clientCode)
        SAVED CLIENT CONTEXT — terminology only, compacted to protect the on-device model context window: \\(clientContext)

        SESSION NARRATIVE:
'''
    text = replace_once(text, old, new, "session-note client prompt fields")

    marker = '''    private static func sanitizeVisualScheduleLine(_ value: String) -> String {
'''
    helper = '''    private static func compactSessionNoteClientContext(_ client: LifeRouteClientProfile?) -> String {
        guard let client else { return "none" }

        func compactList(_ values: [String], limit: Int) -> String {
            let cleaned = values
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            guard !cleaned.isEmpty else { return "none" }
            return cleaned.prefix(limit).joined(separator: "; ")
        }

        func compactText(_ value: String, limit: Int) -> String {
            let clean = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !clean.isEmpty else { return "none" }
            return String(clean.prefix(limit))
        }

        let summary = [
            "targets: \\(compactList(client.currentTargets, limit: 5))",
            "behaviors: \\(compactList(client.behaviorsOfConcern, limit: 5))",
            "communication: \\(compactText(client.communicationNotes, limit: 180))",
            "prompting/reinforcement: \\(compactText(client.promptingNotes, limit: 180))",
        ].joined(separator: " | ")

        // Saved profile data is terminology context only. Keep it small so selecting a client
        // cannot crowd the user's actual session facts out of Apple's on-device model window.
        return String(summary.prefix(720))
    }

'''
    text = replace_once(text, marker, helper + marker, "compact client context helper insertion")
    write(path, text)


def patch_timer_domain() -> None:
    path = "LifeRoute/SessionToolsDomain.swift"
    text = read(path)
    if "pulsesPerSecond(forRemaining" in text:
        return

    text = replace_once(
        text,
        "    func playPulse(frequency: Double) {\n        guard prepareIfNeeded(), let buffer = pulseBuffer(frequency: frequency) else { return }\n        player.scheduleBuffer(buffer, at: nil, options: [])",
        "    func playPulse(frequency: Double, gain: Float) {\n        guard prepareIfNeeded(), let buffer = pulseBuffer(frequency: frequency) else { return }\n        player.volume = max(0, min(1, gain))\n        player.scheduleBuffer(buffer, at: nil, options: [])",
        "timer pulse gain",
    )
    text = replace_once(
        text,
        "    func playCompletion() {\n        guard prepareIfNeeded(), let buffer = completionBuffer() else { return }\n        player.scheduleBuffer(buffer, at: nil, options: [])",
        "    func playCompletion(gain: Float) {\n        guard prepareIfNeeded(), let buffer = completionBuffer() else { return }\n        player.volume = max(0, min(1, gain))\n        player.scheduleBuffer(buffer, at: nil, options: [])",
        "timer completion gain",
    )
    text = replace_once(text, "    private static let pulseDuration = 0.10", "    private static let pulseDuration = 0.11", "pulse duration")
    text = replace_once(
        text,
        "            let decay = exp(-28 * t)\n            let fundamental = sin(2 * Double.pi * frequency * t)\n            let shimmer = 0.20 * sin(2 * Double.pi * frequency * 2.01 * t)\n            samples[frame] = Float((fundamental + shimmer) * attack * decay * 0.60)",
        "            let decay = exp(-24 * t)\n            let fundamental = sin(2 * Double.pi * frequency * t)\n            let bellSecond = 0.20 * sin(2 * Double.pi * frequency * 2.0 * t)\n            let bellThird = 0.07 * sin(2 * Double.pi * frequency * 3.01 * t)\n            let softDetune = 0.06 * sin(2 * Double.pi * frequency * 1.006 * t)\n            samples[frame] = Float((fundamental + bellSecond + bellThird + softDetune) * attack * decay * 0.60)",
        "gentle chime synthesis",
    )
    text = replace_once(
        text,
        "        let notes: [(start: Double, frequency: Double)] = [\n            (0.00, 950),\n            (0.14, 1_160),\n            (0.29, 1_430),\n        ]",
        "        let notes: [(start: Double, frequency: Double)] = [\n            (0.00, 864),\n            (0.14, 1_296),\n            (0.29, 1_728),\n        ]",
        "completion chime notes",
    )
    text = replace_once(
        text,
        "    private static let audioPulseNanoseconds: UInt64 = 250_000_000\n    private static let startFrequency = 220.0\n    private static let endFrequency = 1_320.0",
        "    private static let startFrequency = 432.0\n    private static let endFrequency = 1_728.0\n    private static let startGainForFiveDecibelCrescendo = pow(10.0, -5.0 / 20.0)",
        "timer cadence constants",
    )
    text = replace_once(
        text,
        "    @Published private(set) var pausedRemainingSeconds: TimeInterval = 5 * 60",
        "    @Published private(set) var pausedRemainingSeconds: TimeInterval = 5 * 60\n    @Published private(set) var volume: Double = 0.86",
        "timer volume state",
    )
    text = replace_once(
        text,
        "    func reset() {\n        deadline = nil\n        pausedRemainingSeconds = durationSeconds\n        stopAudioLoop()\n    }",
        '''    func setVolume(_ value: Double) {
        volume = min(1, max(0, value))
    }

    func pulsesPerSecond(forRemaining remaining: TimeInterval) -> Double {
        if remaining <= 5 { return 5 }
        if remaining <= 10 { return 4 }
        if remaining <= 30 { return 3 }
        return 2
    }

    func reset() {
        deadline = nil
        pausedRemainingSeconds = durationSeconds
        stopAudioLoop()
    }''',
        "timer public sound controls",
    )
    text = replace_once(
        text,
        "                    self.toneEngine.playCompletion()",
        "                    self.toneEngine.playCompletion(gain: Float(self.volume))",
        "timer completion volume",
    )
    text = replace_once(
        text,
        '''                self.toneEngine.playPulse(frequency: self.frequency(forRemaining: remaining))
                do {
                    try await Task.sleep(nanoseconds: Self.audioPulseNanoseconds)
                } catch {
                    return
                }''',
        '''                self.toneEngine.playPulse(
                    frequency: self.frequency(forRemaining: remaining),
                    gain: Float(self.signalGain(forRemaining: remaining))
                )
                let interval = 1.0 / self.pulsesPerSecond(forRemaining: remaining)
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    return
                }''',
        "timer variable cadence loop",
    )
    text = replace_once(
        text,
        '''        let elapsedFraction = 1 - remainingFraction
        let eased = pow(elapsedFraction, 1.18)
        return Self.startFrequency * pow(Self.endFrequency / Self.startFrequency, eased)
    }
}''',
        '''        let elapsedFraction = 1 - remainingFraction
        return Self.startFrequency * pow(Self.endFrequency / Self.startFrequency, elapsedFraction)
    }

    private func signalGain(forRemaining remaining: TimeInterval) -> Double {
        guard durationSeconds > 0 else { return volume * Self.startGainForFiveDecibelCrescendo }
        let elapsed = min(1, max(0, 1 - remaining / durationSeconds))
        let crescendo = Self.startGainForFiveDecibelCrescendo + (1 - Self.startGainForFiveDecibelCrescendo) * elapsed
        return min(1, max(0, volume * crescendo))
    }
}''',
        "timer pitch and crescendo",
    )
    write(path, text)


def patch_timer_view() -> None:
    path = "LifeRoute/SessionToolsViews.swift"
    text = read(path)
    if "The chime follows a 5 dB digital crescendo" in text:
        return

    text = replace_once(
        text,
        "                TimelineView(.periodic(from: .now, by: 1)) { context in\n                    let remaining = timer.remainingSeconds(at: context.date)\n                    let progress = timer.progress(at: context.date)",
        '''                TimelineView(.periodic(from: .now, by: 0.10)) { context in
                    let remaining = timer.remainingSeconds(at: context.date)
                    let progress = timer.progress(at: context.date)
                    let tempo = timer.pulsesPerSecond(forRemaining: remaining)
                    let interval = 1.0 / tempo
                    let pulsePhase = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: interval) / interval''',
        "timer visual timeline",
    )
    text = replace_once(
        text,
        '''                            Circle()
                                .stroke(Color.white.opacity(0.07), lineWidth: 15)
                            Circle()
                                .trim(from: 0, to: progress)''',
        '''                            Circle()
                                .stroke(Color.white.opacity(0.07), lineWidth: 15)
                            if timer.isRunning {
                                Circle()
                                    .stroke(palette.accentSecondary.opacity(0.42 * (1 - pulsePhase)), lineWidth: 4)
                                    .scaleEffect(0.92 + 0.12 * pulsePhase)
                            }
                            Circle()
                                .trim(from: 0, to: progress)''',
        "timer visual pulse",
    )
    text = replace_once(
        text,
        '''                            Text("\\(minutes) MIN")
                                .font(.caption2.weight(.black))
                                .tracking(1.2)
                                .foregroundStyle(palette.accent)''',
        '''                            Text("\\(Int(tempo))× / SEC")
                                .font(.caption2.weight(.black))
                                .tracking(1.2)
                                .foregroundStyle(palette.accent)''',
        "timer tempo badge",
    )
    insertion = '''
                VStack(alignment: .leading, spacing: 12) {
                    Text("Timer sound")
                        .font(.headline)
                        .foregroundStyle(palette.textPrimary)

                    HStack {
                        Label("Volume", systemImage: "speaker.wave.2.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.textPrimary)
                        Spacer()
                        Text("\\(Int(timer.volume * 100))%")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.accent)
                    }

                    Slider(
                        value: Binding(
                            get: { timer.volume },
                            set: { timer.setVolume($0) }
                        ),
                        in: 0...1
                    )
                    .tint(palette.accent)

                    Text("The chime follows a 5 dB digital crescendo across the interval. Actual acoustic dB varies by iPhone model, speaker, case, room, and system media volume.")
                        .font(.caption2)
                        .foregroundStyle(palette.textSecondary)
                }
                .lifeRouteCard()

'''
    anchor = '''                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick duration")'''
    text = replace_once(text, anchor, insertion + anchor, "timer volume card")
    text = replace_once(
        text,
        '''                Text("The timer stays accurate from its absolute deadline. Its rising pulse and completion chime use the playback audio category so they remain clearly audible while respecting the device’s media volume.")''',
        '''                Text("Tempo: 2 ticks/sec normally · 3 ticks/sec from 30–10 seconds · 4 ticks/sec from 10–5 seconds · 5 ticks/sec for the final 5 seconds. Pitch rises from 432 Hz to 1728 Hz while the visual pulse accelerates with the sound. Absolute-deadline timing and device media-volume behavior are preserved.")''',
        "timer explanatory copy",
    )
    write(path, text)


def patch_theme_model() -> None:
    path = "LifeRoute/LifeRouteApp.swift"
    text = read(path)
    if "case mountain, space, desert, sunshine" in text:
        return

    text = replace_once(
        text,
        "    case sapphireTide\n",
        "    case sapphireTide\n    case mountain, space, desert, sunshine\n",
        "new scenery enum cases",
    )
    text = replace_once(
        text,
        '''        case .sapphireTide: return "Sapphire Tide"
        }''',
        '''        case .sapphireTide: return "Sapphire Tide"
        case .mountain: return "Mountain"
        case .space: return "Space"
        case .desert: return "Desert"
        case .sunshine: return "Sunshine"
        }''',
        "new scenery names",
    )
    text = replace_once(
        text,
        '''        case .ocean, .aurora, .forest, .plum, .ember: return .scenery
        case .solarFlare, .electricStorm, .ultraviolet, .arcticPulse: return .dynamic
        case .sapphireTide: return .fluid''',
        '''        case .ocean, .forest, .plum, .ember, .mountain, .space, .desert, .sunshine: return .scenery
        case .solarFlare, .electricStorm, .ultraviolet, .arcticPulse, .aurora, .sapphireTide: return .dynamic''',
        "v0.6.2 theme categories",
    )
    text = replace_once(
        text,
        '''        case .sapphireTide: return ("drop.fill", "water.waves")
        }''',
        '''        case .sapphireTide: return ("drop.fill", "water.waves")
        case .mountain: return ("mountain.2.fill", "sun.horizon.fill")
        case .space: return ("sparkles", "moon.stars.fill")
        case .desert: return ("sun.max.fill", "wind")
        case .sunshine: return ("sun.max.fill", "sun.horizon.fill")
        }''',
        "new scenery artwork symbols",
    )
    text = replace_once(
        text,
        '''        case .sapphireTide: return makeThemePalette(0x00142a, 0x00506b, 0x00283f, 0x055163, 0x0782ff, 0x59f0d2)
        }''',
        '''        case .sapphireTide: return makeThemePalette(0x00142a, 0x00506b, 0x00283f, 0x055163, 0x0782ff, 0x59f0d2)
        case .mountain: return makeThemePalette(0x041326, 0x0a2340, 0x0a1b2d, 0x183b58, 0xe6a642, 0xffd77a)
        case .space: return makeThemePalette(0x03050f, 0x101438, 0x0b1025, 0x202b55, 0x8aa7ff, 0xe0d2ff)
        case .desert: return makeThemePalette(0x261207, 0x5a2d0e, 0x32190a, 0x68401b, 0xe9a94d, 0xffdc8f)
        case .sunshine: return makeThemePalette(0x10243b, 0x3b6a79, 0x173149, 0x426678, 0xffc44f, 0xffef9a)
        }''',
        "new scenery palettes",
    )
    write(path, text)


def patch_theme_center() -> None:
    path = "LifeRoute/V054ThemeCenterView.swift"
    text = read(path)
    if "case core = \"Core\"\n        case dynamic = \"Dynamic\"\n        case scenery = \"Scenery\"" in text:
        return

    pattern = r'''    private enum ThemeFilter: String, CaseIterable, Identifiable \{.*?\n    \}\n\n    private let columns'''
    replacement = '''    private enum ThemeFilter: String, CaseIterable, Identifiable {
        case core = "Core"
        case dynamic = "Dynamic"
        case scenery = "Scenery"

        var id: String { rawValue }

        func matches(_ theme: LifeRouteTheme) -> Bool {
            switch self {
            case .core:
                return [.royal, .obsidian, .carbon, .midnight, .navyNoir, .titanium, .slate, .moltenGold, .phantomSilver].contains(theme)
            case .dynamic:
                return [.solarFlare, .electricStorm, .ultraviolet, .arcticPulse, .aurora, .sapphireTide].contains(theme)
            case .scenery:
                return [.mountain, .ocean, .space, .desert, .forest, .sunshine].contains(theme)
            }
        }
    }

    private let columns'''
    text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit("v0.6.2 patch failed: theme filter block")
    text = replace_once(text, "    @State private var selectedCategory: ThemeFilter = .all", "    @State private var selectedCategory: ThemeFilter = .core", "default theme category")
    text = replace_once(
        text,
        '''                Text("Core stays premium and dark. Scenery is environment-led. Metallic themes use material depth, Dynamic themes use energy treatments, and Fluid themes emphasize water, aurora, and flowing light. Every category now has at least three distinct choices.")''',
        '''                Text("Core combines the original LifeRoute and metallic color systems. Dynamic themes use animated shimmering light waves across every screen. Scenery contains six persistent cinematic environments: Mountain, Ocean, Space, Desert, Forest, and Sunshine.")''',
        "theme center description",
    )
    text = text.replace('''                            if filter != .all {
                                Text("\\(LifeRouteTheme.allCases.filter(filter.matches).count)")
                                    .font(.caption2.weight(.black))
                                    .opacity(0.72)
                            }
''', '''                            Text("\\(LifeRouteTheme.allCases.filter(filter.matches).count)")
                                .font(.caption2.weight(.black))
                                .opacity(0.72)
''')
    write(path, text)


def patch_cinematic_themes() -> None:
    path = "LifeRoute/CinematicThemeViews.swift"
    text = read(path)
    if "LifeRouteDynamicWaveBackdrop" in text:
        return

    pattern = r'''        switch self \{.*?        \}\n        return value\.flatMap\(URL\.init\(string:\)\)'''
    replacement = '''        switch self {
        case .mountain:
            value = "https://images.unsplash.com/photo-1501785888041-af3ef285b470?auto=format&fit=crop&w=1800&q=90"
        case .ocean:
            value = "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1800&q=90"
        case .space:
            value = "https://images.unsplash.com/photo-1444703686981-a3abbc4d4fe3?auto=format&fit=crop&w=1800&q=90"
        case .desert:
            value = "https://images.unsplash.com/photo-1500534314209-a25ddb2bd429?auto=format&fit=crop&w=1800&q=90"
        case .forest:
            value = "https://images.unsplash.com/photo-1448375240586-882707db888b?auto=format&fit=crop&w=1800&q=90"
        case .sunshine:
            value = "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?auto=format&fit=crop&w=1800&q=90"
        default:
            value = nil
        }
        return value.flatMap(URL.init(string:))'''
    text, count = re.subn(pattern, replacement, text, count=1, flags=re.S)
    if count != 1:
        raise SystemExit("v0.6.2 patch failed: cinematic image map")

    text = replace_once(text, ".saturation(1.05)\n                                .contrast(1.08)", ".saturation(1.12)\n                                .contrast(1.18)", "scenery contrast")

    old_dynamic = '''        case .dynamic:
            ZStack {
                RadialGradient(
                    colors: [palette.accent.opacity(0.48), .clear],
                    center: .topTrailing,
                    startRadius: 4,
                    endRadius: max(size.width, size.height) * 0.85
                )
                palette.backgroundGradient.opacity(0.72)
                ForEach(0..<5, id: \\.self) { index in
                    Capsule()
                        .fill(index.isMultiple(of: 2) ? palette.accent : palette.accentSecondary)
                        .opacity(0.12)
                        .frame(width: size.width * 0.9, height: CGFloat(12 + index * 5))
                        .blur(radius: CGFloat(8 + index))
                        .rotationEffect(.degrees(-36))
                        .offset(x: CGFloat(index - 2) * 44, y: CGFloat(index - 2) * 105)
                }
            }
        case .fluid:
            ZStack {
                palette.backgroundGradient
                Ellipse()
                    .fill(palette.accent.opacity(0.24))
                    .frame(width: size.width * 1.1, height: size.height * 0.5)
                    .blur(radius: 32)
                    .rotationEffect(.degrees(-18))
                    .offset(x: size.width * 0.26, y: -size.height * 0.18)
                Ellipse()
                    .stroke(palette.accentSecondary.opacity(0.18), lineWidth: 24)
                    .frame(width: size.width * 1.15, height: size.height * 0.55)
                    .blur(radius: 12)
                    .rotationEffect(.degrees(18))
                    .offset(x: -size.width * 0.30, y: size.height * 0.25)
            }'''
    new_dynamic = '''        case .dynamic, .fluid:
            LifeRouteDynamicWaveBackdrop(palette: palette, compact: compact)'''
    text = replace_once(text, old_dynamic, new_dynamic, "dynamic/fluid backdrop")

    anchor = '''struct LifeRouteCinematicThemeThumbnail: View {'''
    dynamic_view = '''struct LifeRouteDynamicWaveBackdrop: View {
    let palette: LifeRouteThemePalette
    var compact = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: compact ? 0.16 : 0.06)) { context in
            GeometryReader { proxy in
                let t = context.date.timeIntervalSinceReferenceDate
                ZStack {
                    palette.backgroundGradient
                    RadialGradient(
                        colors: [palette.accent.opacity(0.44), .clear],
                        center: .topTrailing,
                        startRadius: 4,
                        endRadius: max(proxy.size.width, proxy.size.height) * 0.90
                    )
                    ForEach(0..<7, id: \\.self) { index in
                        let phase = t * (0.42 + Double(index) * 0.035) + Double(index) * 0.78
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        palette.accent.opacity(index.isMultiple(of: 2) ? 0.30 : 0.12),
                                        palette.accentSecondary.opacity(index.isMultiple(of: 2) ? 0.13 : 0.32),
                                        Color.white.opacity(0.07),
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: proxy.size.width * 1.25, height: CGFloat(14 + index * 6))
                            .blur(radius: CGFloat(10 + index * 1))
                            .rotationEffect(.degrees(-31 + sin(phase * 0.55) * 7))
                            .offset(
                                x: CGFloat(sin(phase) * 70) + CGFloat(index - 3) * 18,
                                y: CGFloat(cos(phase * 0.82) * 82) + CGFloat(index - 3) * 94
                            )
                    }
                    LinearGradient(
                        colors: [Color.white.opacity(0.08), .clear, palette.accentSecondary.opacity(0.07)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }
                .clipped()
            }
        }
    }
}

'''
    text = replace_once(text, anchor, dynamic_view + anchor, "dynamic wave view insertion")
    write(path, text)


def patch_icon_generator() -> None:
    path = "scripts/generate_v0_6_1_app_icon.swift"
    text = read(path)
    if "v0.6.2 safe-area refinement" in text:
        return

    text = replace_once(text, "let outer = NSBezierPath(roundedRect: full.insetBy(dx: 20, dy: 20), xRadius: 118, yRadius: 118)", "// v0.6.2 safe-area refinement: keep the complete mark comfortably inside iOS's final icon mask.\nlet outer = NSBezierPath(roundedRect: full.insetBy(dx: 58, dy: 58), xRadius: 164, yRadius: 164)", "icon outer shape")
    text = replace_once(text, "let border = NSBezierPath(roundedRect: full.insetBy(dx: 34, dy: 34), xRadius: 104, yRadius: 104)\nborder.lineWidth = 24", "let border = NSBezierPath(roundedRect: full.insetBy(dx: 72, dy: 72), xRadius: 150, yRadius: 150)\nborder.lineWidth = 20", "icon border")
    text = replace_once(text, "let innerBorder = NSBezierPath(roundedRect: full.insetBy(dx: 48, dy: 48), xRadius: 92, yRadius: 92)", "let innerBorder = NSBezierPath(roundedRect: full.insetBy(dx: 86, dy: 86), xRadius: 138, yRadius: 138)", "icon inner border")
    text = replace_once(text, "let font = NSFont(name: \"Times New Roman Bold\", size: 500) ?? NSFont.systemFont(ofSize: 500, weight: .black)", "let font = NSFont(name: \"Times New Roman Bold\", size: 450) ?? NSFont.systemFont(ofSize: 450, weight: .black)", "icon lettering scale")
    text = replace_once(text, "drawLetter(\"L\", rect: NSRect(x: 105, y: 220, width: 370, height: 610))\ndrawLetter(\"R\", rect: NSRect(x: 520, y: 205, width: 410, height: 610))", "drawLetter(\"L\", rect: NSRect(x: 130, y: 236, width: 350, height: 560))\ndrawLetter(\"R\", rect: NSRect(x: 512, y: 228, width: 372, height: 560))", "icon letter centering")
    text = replace_once(text, "road.lineWidth = 48", "road.lineWidth = 42", "icon route width")
    write(path, text)


def main() -> None:
    patch_intelligence()
    patch_timer_domain()
    patch_timer_view()
    patch_theme_model()
    patch_theme_center()
    patch_cinematic_themes()
    patch_icon_generator()
    print("LifeRoute v0.6.2 native patch applied: timer crescendo/tempo, compact client note context, three-category themes, animated dynamic waves, six scenery themes, and refined icon safe area.")


if __name__ == "__main__":
    main()
