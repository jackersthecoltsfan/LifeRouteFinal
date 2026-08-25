from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{label}: source marker missing")
    path.write_text(text.replace(old, new, 1))


# Session Tools should never force the document to jump to whichever card was selected.
# The user controls vertical position; switching Timer / Visuals / Docs only changes content.
toolbar = WEB / "toolbar-cleanup-v1.js"
replace_once(
    toolbar,
    """    const first = definition?.targets.map(id => document.getElementById(id)).find(Boolean) || grid;\n    first?.scrollIntoView({ behavior: 'smooth', block: 'start' });\n""",
    """    // Preserve the user's scroll position when switching Session Tools groups.\n    // Do not call scrollIntoView here; WKWebView can otherwise jump deep into the toolkit.\n""",
    "Session Tools forced scroll removal",
)


# Tighten the top-right appointment/settings controls into one compact action group.
delight = WEB / "delight-ui-v1.js"
replace_once(
    delight,
    ".lrHeaderActions{display:flex;align-items:center;gap:7px;margin-left:auto}",
    ".lrHeaderActions{display:flex;align-items:center;gap:0;margin-left:auto}",
    "top-right action gap",
)
replace_once(
    delight,
    "@media(max-width:560px){.lrHeaderActions{gap:6px}",
    "@media(max-width:560px){.lrHeaderActions{gap:0}",
    "mobile top-right action gap",
)


# Browser/Web Audio path: raise the timer bell gain fivefold and lengthen the audible body.
visual_timer = WEB / "visual-timer-v2.js"
replace_once(
    visual_timer,
    "master.gain.exponentialRampToValueAtTime(0.052 * gainScale, now + 0.009);",
    "master.gain.exponentialRampToValueAtTime(0.26 * gainScale, now + 0.006);",
    "Visual Timer Web Audio gain boost",
)
replace_once(
    visual_timer,
    "master.gain.exponentialRampToValueAtTime(0.0001, now + 0.115);",
    "master.gain.exponentialRampToValueAtTime(0.0001, now + 0.24);",
    "Visual Timer Web Audio sustain",
)
replace_once(
    visual_timer,
    "fundamental.stop(now + 0.12);\n    shimmer.stop(now + 0.08);",
    "fundamental.stop(now + 0.25);\n    shimmer.stop(now + 0.16);",
    "Visual Timer Web Audio tone length",
)


# Native iPhone timer companion asks the AVAudioEngine for maximum alarm emphasis.
timer_native = WEB / "timer-native-audio-v1.js"
replace_once(
    timer_native,
    "const playTone = (frequency, intensity = .96) => post({ action:'playTimerTone', frequency, intensity });",
    "const playTone = (frequency, intensity = 1.0) => post({ action:'playTimerTone', frequency, intensity, boost:5 });",
    "native timer boost request",
)


# patch_day_navigation.py installs the native bridge earlier in preparation. Upgrade its
# generated timer synthesizer here so the TestFlight build gets a much denser, longer,
# near-full-scale glass tone while still using AVAudioSession.playback in silent mode.
swift = SWIFT.read_text()
old_call = '''            case "playTimerTone":
                let frequency = (body["frequency"] as? NSNumber)?.doubleValue ?? 720.0
                let intensity = (body["intensity"] as? NSNumber)?.doubleValue ?? 0.95
                lifeRouteTimerAudio.playGlassTone(frequency: frequency, intensity: intensity)
'''
new_call = '''            case "playTimerTone":
                let frequency = (body["frequency"] as? NSNumber)?.doubleValue ?? 720.0
                let intensity = (body["intensity"] as? NSNumber)?.doubleValue ?? 1.0
                let boost = (body["boost"] as? NSNumber)?.doubleValue ?? 5.0
                lifeRouteTimerAudio.playGlassTone(frequency: frequency, intensity: intensity, boost: boost)
'''
if old_call in swift:
    swift = swift.replace(old_call, new_call, 1)
elif new_call not in swift:
    raise SystemExit("native timer bridge boost: playTimerTone marker missing")

start = swift.find("private final class LifeRouteTimerAudio {")
if start < 0:
    raise SystemExit("native timer loudness: LifeRouteTimerAudio class missing")

loud_class = r'''private final class LifeRouteTimerAudio {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1.0
    }

    func playGlassTone(frequency: Double, intensity: Double, boost: Double = 5.0) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
        if !engine.isRunning { try? engine.start() }

        let safeFrequency = max(160.0, min(2_600.0, frequency))
        let safeIntensity = max(0.25, min(1.0, intensity))
        let safeBoost = max(1.0, min(5.0, boost))
        let duration = 0.34
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames

        for frame in 0..<Int(frames) {
            let t = Double(frame) / format.sampleRate
            let attack = min(1.0, t / 0.004)
            let decay = exp(-3.25 * t / duration)
            let envelope = attack * decay
            let fundamental = sin(2.0 * Double.pi * safeFrequency * t)
            let shimmer = 0.68 * sin(2.0 * Double.pi * safeFrequency * 2.01 * t)
            let presence = 0.42 * sin(2.0 * Double.pi * safeFrequency * 2.98 * t)
            let sparkle = 0.24 * sin(2.0 * Double.pi * safeFrequency * 4.03 * t)
            let dense = (fundamental + shimmer + presence + sparkle) * envelope
            let driven = tanh(dense * (1.15 + safeBoost * 0.42))
            channel[frame] = Float(max(-0.99, min(0.99, driven * 0.99 * safeIntensity)))
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}
'''
# patch_day_navigation appends this helper at end of file; replace that tail deterministically.
swift = swift[:start] + loud_class + "\n"
SWIFT.write_text(swift)

verified = SWIFT.read_text()
for marker in [
    'let boost = (body["boost"] as? NSNumber)?.doubleValue ?? 5.0',
    'func playGlassTone(frequency: Double, intensity: Double, boost: Double = 5.0)',
    'session.setCategory(.playback, mode: .default, options: [])',
    'engine.mainMixerNode.outputVolume = 1.0',
]:
    if marker not in verified:
        raise SystemExit(f"interaction hotfix verification failed: missing {marker}")

print("Session Tools no longer auto-scroll; header actions tightened; Visual Timer loudness boosted.")
