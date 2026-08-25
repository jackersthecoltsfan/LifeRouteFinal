from pathlib import Path

path = Path("LifeRoute/Web/index.html")
html = path.read_text()

old_section = '<div class="section"><div class="sectionHead"><h2 id="todayLabel">Today</h2><span class="hint" id="mapProviderLabel">Apple Maps</span></div><div id="timeline"></div></div>'
new_section = '''<div class="section"><div class="sectionHead"><h2 id="todayLabel">Today</h2><span class="hint" id="mapProviderLabel">Apple Maps</span></div><div class="lrDayPager" aria-label="Day navigation"><button type="button" class="secondary" id="dayPrevButton" aria-label="Previous day">← <span>Previous</span></button><button type="button" class="secondary lrDayToday" id="dayTodayButton">Today</button><button type="button" class="secondary" id="dayNextButton" aria-label="Next day"><span>Next</span> →</button></div><div id="timeline"></div></div>'''

if 'class="lrDayPager"' not in html:
    if old_section not in html:
        raise SystemExit("Could not add day pager: Today section marker not found")
    html = html.replace(old_section, new_section, 1)
else:
    import re
    html = re.sub(
        r'<div class="lrDayPager" aria-label="Day navigation">.*?</div><div id="timeline"></div>',
        new_section.split('</div><div id="timeline">')[0] + '</div><div id="timeline"></div>',
        html,
        count=1,
        flags=re.S,
    )

style_marker = '</style>'
style = '''
.lrDayPager{display:grid;grid-template-columns:1fr auto 1fr;gap:7px;margin:0 0 11px}.lrDayPager button{min-height:40px;border-radius:13px!important;display:flex;align-items:center;justify-content:center;gap:6px;font-size:11px;touch-action:manipulation}.lrDayPager button:first-child{justify-content:flex-start}.lrDayPager button:last-child{justify-content:flex-end}.lrDayToday{padding-left:16px!important;padding-right:16px!important;color:var(--gold)!important;border-color:color-mix(in srgb,var(--gold) 38%,var(--line))!important}@media(max-width:420px){.lrDayPager button span{display:none}.lrDayPager button:first-child,.lrDayPager button:last-child{justify-content:center}.lrDayPager{grid-template-columns:1fr 1.15fr 1fr}}
'''
if '.lrDayPager{' not in html:
    if style_marker not in html:
        raise SystemExit("Could not add day pager styles")
    html = html.replace(style_marker, style + style_marker, 1)

# These shared enhancement scripts intentionally self-delay/reconcile until the
# rest of the deterministic runtime is available. This keeps them compatible
# with both the checked-in web preview and the prepared native bundle.
for script_name in [
    "saved-place-gap-options.js",
    "delight-ui-v1.js",
    "timer-native-audio-v1.js",
    "delight-tail-v1.js",
]:
    tag = f'<script src="{script_name}"></script>'
    if tag not in html:
        if "</body>" not in html:
            raise SystemExit(f"Could not enable {script_name}: </body> not found")
        html = html.replace("</body>", tag + "\n</body>", 1)

path.write_text(html)

# Native tactile feedback and timer audio. Timer tones use AVAudioSession.playback
# so the Visual Timer remains audible when the iPhone silent switch is enabled.
swift_path = Path("LifeRoute/LifeRouteWebView.swift")
swift = swift_path.read_text()

if "import AVFoundation" not in swift:
    if "import UIKit\n" not in swift:
        raise SystemExit("Could not add AVFoundation import: UIKit import marker not found")
    swift = swift.replace("import UIKit\n", "import UIKit\nimport AVFoundation\n", 1)

old_haptic = '''            case "haptic":
                let requestedStyle = (body["style"] as? String ?? "light").lowercased()
                let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle = requestedStyle == "heavy" ? .heavy : (requestedStyle == "medium" ? .medium : .light)
                let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
                generator.prepare()
                generator.impactOccurred()
'''
new_haptic = '''            case "haptic":
                let requestedStyle = (body["style"] as? String ?? "medium").lowercased()
                if requestedStyle == "success" {
                    let generator = UINotificationFeedbackGenerator()
                    generator.prepare()
                    generator.notificationOccurred(.success)
                } else if requestedStyle == "selection" {
                    let generator = UISelectionFeedbackGenerator()
                    generator.prepare()
                    generator.selectionChanged()
                } else {
                    let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
                    switch requestedStyle {
                    case "heavy": feedbackStyle = .heavy
                    case "rigid": feedbackStyle = .rigid
                    case "soft": feedbackStyle = .soft
                    case "light": feedbackStyle = .light
                    default: feedbackStyle = .medium
                    }
                    let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
                    generator.prepare()
                    generator.impactOccurred(intensity: requestedStyle == "heavy" ? 1.0 : 0.88)
                }
'''
if old_haptic in swift:
    swift = swift.replace(old_haptic, new_haptic, 1)
elif 'case "haptic":' not in swift:
    marker = '            case "openRoute":\n'
    if marker not in swift:
        raise SystemExit("Could not add native button haptics: openRoute bridge marker not found")
    swift = swift.replace(marker, new_haptic + marker, 1)

if "private let lifeRouteTimerAudio" not in swift:
    marker = "        private let eventStore = EKEventStore()\n"
    if marker not in swift:
        raise SystemExit("Could not add timer audio engine: coordinator property marker not found")
    swift = swift.replace(marker, marker + "        private let lifeRouteTimerAudio = LifeRouteTimerAudio()\n", 1)

if 'case "playTimerTone":' not in swift:
    marker = '            case "openRoute":\n'
    audio_case = '''            case "playTimerTone":
                let frequency = (body["frequency"] as? NSNumber)?.doubleValue ?? 720.0
                let intensity = (body["intensity"] as? NSNumber)?.doubleValue ?? 0.95
                lifeRouteTimerAudio.playGlassTone(frequency: frequency, intensity: intensity)
'''
    if marker not in swift:
        raise SystemExit("Could not add native timer sound: openRoute bridge marker not found")
    swift = swift.replace(marker, audio_case + marker, 1)

if "final class LifeRouteTimerAudio" not in swift:
    swift += '''

private final class LifeRouteTimerAudio {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func playGlassTone(frequency: Double, intensity: Double) {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)
        if !engine.isRunning { try? engine.start() }

        let safeFrequency = max(110.0, min(2_600.0, frequency))
        let safeIntensity = max(0.2, min(1.0, intensity))
        let duration = 0.17
        let frames = AVAudioFrameCount(format.sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channel = buffer.floatChannelData?[0] else { return }
        buffer.frameLength = frames

        for frame in 0..<Int(frames) {
            let t = Double(frame) / format.sampleRate
            let attack = min(1.0, t / 0.008)
            let decay = exp(-7.2 * t / duration)
            let fundamental = sin(2.0 * Double.pi * safeFrequency * t)
            let shimmer = 0.28 * sin(2.0 * Double.pi * safeFrequency * 2.01 * t)
            let sparkle = 0.10 * sin(2.0 * Double.pi * safeFrequency * 3.98 * t)
            let value = (fundamental + shimmer + sparkle) * attack * decay * (0.72 * safeIntensity)
            channel[frame] = Float(max(-0.98, min(0.98, value)))
        }

        player.scheduleBuffer(buffer, completionHandler: nil)
        if !player.isPlaying { player.play() }
    }
}
'''

swift_path.write_text(swift)
verified = swift_path.read_text()
for marker in ['case "haptic":', "UIImpactFeedbackGenerator", 'case "playTimerTone":', "AVAudioSession", "LifeRouteTimerAudio"]:
    if marker not in verified:
        raise SystemExit(f"Native interaction bridge verification failed: missing {marker}")

print("Day navigation, contextual delight UI, strong haptics, and silent-mode timer audio enabled.")
