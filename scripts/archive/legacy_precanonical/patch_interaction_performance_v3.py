from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"{label}: source marker missing")
    return text.replace(old, new, 1)


# --- Center the top-level navigation with exactly four equal destinations. ---
delight_path = WEB / "delight-ui-v1.js"
delight = delight_path.read_text()
delight = replace_once(
    delight,
    '.tabs{width:min(100%,590px)!important;',
    '.tabs{width:min(100%,590px)!important;grid-template-columns:repeat(4,minmax(0,1fr))!important;',
    'four-column centered top navigation',
)

# --- Faster touch-down, smoother spring-back, fewer permanent compositor layers. ---
old_button = 'button,[role="button"]{transform-origin:center;will-change:transform;transition:transform .125s cubic-bezier(.2,.92,.24,1.18),filter .125s ease,box-shadow .16s ease,background .16s ease!important;-webkit-tap-highlight-color:transparent}'
new_button = 'button,[role="button"]{transform-origin:center;will-change:auto;touch-action:manipulation;transition:transform .145s cubic-bezier(.18,.89,.26,1.22),filter .12s ease,box-shadow .145s ease,background .145s ease!important;-webkit-tap-highlight-color:transparent}'
delight = replace_once(delight, old_button, new_button, 'responsive button compositor cleanup')

pressed_marker = 'button:active,[role="button"]:active,.lrTouchPressed{transform:translate3d(0,2px,0) scale(.945)!important;filter:brightness(1.10) saturate(1.08)!important;box-shadow:inset 0 2px 8px rgba(0,0,0,.20),inset 0 0 0 1px rgba(255,255,255,.10),0 3px 10px rgba(0,0,0,.10)!important}'
pressed_replacement = pressed_marker + '\n    .lrTouchPressed{transition:transform .055s cubic-bezier(.18,.92,.22,1),filter .055s ease,box-shadow .075s ease!important}'
if '.lrTouchPressed{transition:transform .055s' not in delight:
    if pressed_marker not in delight:
        raise SystemExit('fast touch-down marker missing')
    delight = delight.replace(pressed_marker, pressed_replacement, 1)

# Primary actions feel deeper; nav is crisp/rigid; ordinary controls remain medium.
delight = delight.replace(
    "if (control.matches('.goldButton,.primary,[data-lr-setup-pane],[data-lr-tool-group]')) return 'rigid';",
    "if (control.matches('.goldButton,.primary,[data-lr-setup-pane],[data-lr-tool-group]')) return 'heavy';",
    1,
)
delight = delight.replace(
    "if (control.matches('.tab,.lrContextTab,.lrSettingsButton,.lrQuickAddButton')) return 'medium';",
    "if (control.matches('.tab,.lrContextTab,.lrSettingsButton,.lrQuickAddButton')) return 'rigid';",
    1,
)

# --- Native WKWebView performance budget. ---
# Keep the living backgrounds, but slow their compositor workload and pause them while
# a finger is down. Keep glass on navigation, at a lower blur radius than before.
perf_anchor = '    .card,.hero,.metric{box-shadow:inset 0 1px rgba(255,255,255,.045),0 10px 30px rgba(0,0,0,.08)!important}\n'
perf_rules = '''    .card,.hero,.metric{box-shadow:inset 0 1px rgba(255,255,255,.045),0 10px 30px rgba(0,0,0,.08)!important}
    html.lrInteractionBusy #lifeRouteDelightBackdrop>span{animation-play-state:paused!important}
    html[data-life-route-runtime="native"] #lifeRouteDelightBackdrop{opacity:.30!important}
    html[data-life-route-runtime="native"] #lifeRouteDelightBackdrop>span{animation-duration:52s!important}
    html[data-life-route-runtime="native"] .tabs{backdrop-filter:blur(12px)!important;-webkit-backdrop-filter:blur(12px)!important}
    html[data-life-route-runtime="native"] .lrContextTabs{backdrop-filter:blur(10px)!important;-webkit-backdrop-filter:blur(10px)!important}
    html[data-life-route-runtime="native"] .lrQuickAddButton,
    html[data-life-route-runtime="native"] .lrSettingsButton{backdrop-filter:blur(10px)!important;-webkit-backdrop-filter:blur(10px)!important}
'''
if 'html.lrInteractionBusy #lifeRouteDelightBackdrop>span' not in delight:
    if perf_anchor not in delight:
        raise SystemExit('native performance CSS anchor missing')
    delight = delight.replace(perf_anchor, perf_rules, 1)

delight_path.write_text(delight)

# --- Remove repeated startup reconciliation work from the delight tail. ---
tail_path = WEB / "delight-tail-v1.js"
tail = tail_path.read_text()
old_tail = '  [120,320,800,1600,2800].forEach(delay => setTimeout(finalize, delay));'
new_tail = '''  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => requestAnimationFrame(finalize), { once:true });
  } else {
    requestAnimationFrame(finalize);
  }
  setTimeout(finalize, 280);'''
tail = replace_once(tail, old_tail, new_tail, 'delight startup retry cleanup')
tail_path.write_text(tail)

# --- Longer/deeper native haptics without a CoreHaptics engine or background loop. ---
# Heavy/rigid interactions get a short second impulse; normal taps stay one-shot.
swift = SWIFT.read_text()
old_haptic = '''            case "haptic":
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
                    let firstIntensity: CGFloat = requestedStyle == "heavy" ? 1.0 : (requestedStyle == "rigid" ? 0.98 : 0.94)
                    generator.impactOccurred(intensity: firstIntensity)
                    if requestedStyle == "heavy" || requestedStyle == "rigid" {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.055) {
                            let follow = UIImpactFeedbackGenerator(style: feedbackStyle)
                            follow.prepare()
                            follow.impactOccurred(intensity: requestedStyle == "heavy" ? 0.72 : 0.48)
                        }
                    }
                }
'''
if 'let firstIntensity: CGFloat' not in swift:
    if old_haptic not in swift:
        raise SystemExit('native deep haptic marker missing')
    swift = swift.replace(old_haptic, new_haptic, 1)
SWIFT.write_text(swift)

# Verification markers for this final polish layer.
checks = {
    delight_path: [
        'grid-template-columns:repeat(4,minmax(0,1fr))!important',
        'will-change:auto',
        'transition:transform .055s',
        "return 'heavy';",
        'html.lrInteractionBusy #lifeRouteDelightBackdrop>span',
    ],
    tail_path: ['setTimeout(finalize, 280)'],
    SWIFT: ['let firstIntensity: CGFloat', '.now() + 0.055'],
}
for path, markers in checks.items():
    text = path.read_text()
    for marker in markers:
        if marker not in text:
            raise SystemExit(f'interaction performance verification failed: {path.name} missing {marker}')

print('Centered four-tab nav, responsive buttons, deeper haptics, and WKWebView performance polish applied.')
