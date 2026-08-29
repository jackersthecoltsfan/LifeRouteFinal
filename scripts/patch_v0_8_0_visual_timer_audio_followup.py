from pathlib import Path


DOMAIN_PATH = Path("LifeRoute/SessionToolsDomain.swift")
VIEW_PATH = Path("LifeRoute/SessionToolsViews.swift")
MARKER = "v0.8.0 follow-up visual timer audio sweep"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    count = text.count(old)
    if count != 1:
        raise SystemExit(
            f"v0.8.0 timer-audio follow-up failed: expected one {label}, found {count}"
        )
    return text.replace(old, new, 1)


domain = DOMAIN_PATH.read_text(encoding="utf-8")
view = VIEW_PATH.read_text(encoding="utf-8")

if MARKER in domain and MARKER in view:
    print("LifeRoute v0.8.0 visual-timer audio follow-up is already materialized.")
    raise SystemExit(0)
if MARKER in domain or MARKER in view:
    raise SystemExit("v0.8.0 visual-timer audio follow-up is only partially materialized")


domain = replace_once(
    domain,
    "    private static let pulseDuration = 0.14",
    "    private static let pulseDuration = 0.085",
    "gentle pulse duration",
)
domain = replace_once(
    domain,
    "samples[frame] = Float((fundamental + softSecond + softDetune) * attack * decay * release * 0.46)",
    "samples[frame] = Float((fundamental + softSecond + softDetune) * attack * decay * release * 0.30)",
    "gentle pulse amplitude",
)

domain = replace_once(
    domain,
    '''@MainActor
final class VisualTimerCore: ObservableObject {
    private static let startFrequency = 432.0
    private static let endFrequency = 1_728.0
    private static let startGainForFiveDecibelCrescendo = pow(10.0, -5.0 / 20.0)''',
    '''// v0.8.0 follow-up visual timer audio sweep:
// Normalized elapsed progress owns both the perceptual octave sweep and linear rate ramp.
@MainActor
final class VisualTimerCore: ObservableObject {
    private static let startFrequency = 432.0
    private static let endFrequency = 864.0
    private static let startPulsesPerSecond = 1.0
    private static let endPulsesPerSecond = 6.0
    private static let startGainForFiveDecibelCrescendo = pow(10.0, -5.0 / 20.0)''',
    "timer sweep constants",
)

domain = replace_once(
    domain,
    "    @Published private(set) var volume: Double = 0.86",
    "    @Published private(set) var volume: Double = 0.48",
    "gentle default volume",
)

domain = replace_once(
    domain,
    '''    func pulsesPerSecond(forRemaining remaining: TimeInterval) -> Double {
        if remaining <= 5 { return 5 }
        if remaining <= 10 { return 4 }
        if remaining <= 30 { return 3 }
        return 2
    }''',
    '''    func normalizedElapsedProgress(forRemaining remaining: TimeInterval) -> Double {
        guard durationSeconds > 0 else { return 0 }
        return min(1, max(0, 1 - remaining / durationSeconds))
    }

    func pulsesPerSecond(forRemaining remaining: TimeInterval) -> Double {
        let progress = normalizedElapsedProgress(forRemaining: remaining)
        return Self.startPulsesPerSecond
            + (Self.endPulsesPerSecond - Self.startPulsesPerSecond) * progress
    }

    func toneFrequency(forRemaining remaining: TimeInterval) -> Double {
        let progress = normalizedElapsedProgress(forRemaining: remaining)
        return Self.startFrequency * pow(Self.endFrequency / Self.startFrequency, progress)
    }''',
    "continuous rate and frequency mapping",
)

domain = replace_once(
    domain,
    "frequency: self.frequency(forRemaining: remaining),",
    "frequency: self.toneFrequency(forRemaining: remaining),",
    "audio loop frequency mapping",
)

domain = replace_once(
    domain,
    '''    private func frequency(forRemaining remaining: TimeInterval) -> Double {
        guard durationSeconds > 0 else { return Self.startFrequency }
        let remainingFraction = min(1, max(0, remaining / durationSeconds))
        let elapsedFraction = 1 - remainingFraction
        return Self.startFrequency * pow(Self.endFrequency / Self.startFrequency, elapsedFraction)
    }

    private func signalGain(forRemaining remaining: TimeInterval) -> Double {
        guard durationSeconds > 0 else { return volume * Self.startGainForFiveDecibelCrescendo }
        let elapsed = min(1, max(0, 1 - remaining / durationSeconds))''',
    '''    private func signalGain(forRemaining remaining: TimeInterval) -> Double {
        let elapsed = normalizedElapsedProgress(forRemaining: remaining)''',
    "shared normalized gain progress",
)


view = replace_once(
    view,
    '''struct VisualTimerView: View {
    // v0.7.0 Build D timer presentation: compact visual hierarchy; timer/audio engine remains untouched.''',
    '''struct VisualTimerView: View {
    // v0.8.0 follow-up visual timer audio sweep: gentle 432–864 Hz and 1–6 pulse/sec mapping.
    // v0.7.0 Build D timer presentation: compact visual hierarchy; timer/audio engine remains untouched.''',
    "timer view marker",
)

view = replace_once(
    view,
    '''                    subtitle: "Fast, dependable session timing with the validated crescendo and completion audio.",''',
    '''                    subtitle: "Gentle session timing with a smooth rising pulse, visual countdown, and completion audio.",''',
    "timer header copy",
)

view = replace_once(
    view,
    '''                    let tempo = timer.pulsesPerSecond(forRemaining: remaining)
                    let interval = 1.0 / tempo''',
    '''                    let tempo = timer.pulsesPerSecond(forRemaining: remaining)
                    let toneFrequency = timer.toneFrequency(forRemaining: remaining)
                    let interval = 1.0 / tempo''',
    "visible tone frequency",
)

view = replace_once(
    view,
    r'''                            Text("\(Int(tempo))× / SEC")
                                .font(.caption2.weight(.black))
                                .tracking(1.2)
                                .foregroundStyle(palette.accent)''',
    r'''                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f× / SEC", tempo))
                                Text("\(Int(toneFrequency.rounded())) HZ")
                            }
                            .font(.caption2.weight(.black))
                            .tracking(1.0)
                            .foregroundStyle(palette.accent)''',
    "visible continuous tempo and tone",
)

view = replace_once(
    view,
    '''                    Text("The chime follows a 5 dB digital crescendo across the interval. Actual acoustic dB varies by iPhone model, speaker, case, room, and system media volume.")''',
    '''                    Text("The gentle pulse keeps the existing 5 dB digital gain ramp while pitch and tick rate rise smoothly. Set Volume to 0% for a visual-only timer. Actual acoustic dB varies by iPhone model, case, room, and system media volume.")''',
    "sound character and mute copy",
)

view = replace_once(
    view,
    '''                Text("Tempo: 2 ticks/sec normally · 3 ticks/sec from 30–10 seconds · 4 ticks/sec from 10–5 seconds · 5 ticks/sec for the final 5 seconds. Pitch rises from 432 Hz to 1728 Hz while the visual pulse accelerates with the sound. Absolute-deadline timing and device media-volume behavior are preserved.")''',
    '''                Text("The pulse starts at 432 Hz and 1 tick/sec, then rises continuously with elapsed timer progress to 864 Hz and 6 ticks/sec. The same normalized mapping scales across every duration; absolute-deadline timing, pause/resume, mute, and device media-volume behavior are preserved.")''',
    "timer mapping explanation",
)


DOMAIN_PATH.write_text(domain, encoding="utf-8")
VIEW_PATH.write_text(view, encoding="utf-8")

print(
    "LifeRoute v0.8.0 visual-timer follow-up applied: a gentler 0.085-second pulse sweeps "
    "perceptually from 432 to 864 Hz while its rate rises continuously from 1 to 6 ticks/sec "
    "across normalized countdown progress."
)
