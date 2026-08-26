from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
INDEX = WEB / "index.html"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"

index = INDEX.read_text()
delight = (WEB / "delight-ui-v1.js").read_text()
tail = (WEB / "delight-tail-v1.js").read_text()
stability = (WEB / "interaction-stability-v3.js").read_text()
toolbar = (WEB / "toolbar-cleanup-v1.js").read_text()
top_nav = (WEB / "top-nav-four-v1.js").read_text()
aesthetic = (WEB / "aesthetic-polish-v1.js").read_text()
timer = (WEB / "visual-timer-v2.js").read_text()
swift = SWIFT.read_text()

angles = {
    "1/4 Runtime pressure & freeze prevention": [],
    "2/4 Motion & touch responsiveness": [],
    "3/4 Scroll/lifecycle stability": [],
    "4/4 Release artifact & navigation contract": [],
}
notes = []


def require(angle: str, condition: bool, message: str) -> None:
    if not condition:
        angles[angle].append(message)


A1 = "1/4 Runtime pressure & freeze prevention"
A2 = "2/4 Motion & touch responsiveness"
A3 = "3/4 Scroll/lifecycle stability"
A4 = "4/4 Release artifact & navigation contract"

# ANGLE 1: main-thread/compositor pressure and observer-loop risks.
require(A1, 'observer.observe(appRoot, { childList:true, subtree:true });' in delight,
        'Delight runtime is not using the narrowed structural observer.')
require(A1, 'observer.observe(document.body, { childList:true, subtree:true, attributes:true' not in delight,
        'Delight runtime still observes class attributes across the whole document.')
require(A1, '[80,240,700,1500,2600]' not in delight,
        'Five-pass delight startup retry fanout remains.')
require(A1, '[0, 80, 250, 700, 1400]' not in toolbar,
        'Five-pass toolbar startup reconciliation remains.')
require(A1, 'let reconcileQueued = false;' in toolbar,
        'Toolbar mutations are not requestAnimationFrame-batched.')
require(A1, 'alreadyOrdered' in top_nav,
        'Top navigation enforcer is not idempotent before reordering children.')
require(A1, 'attributes: true' not in top_nav,
        'Top navigation still observes its own style/class writes.')
require(A1, "observe(tabs, { childList: true })" in top_nav,
        'Top navigation should observe child-list changes only.')
require(A1, '.card,.hero,.metric{backdrop-filter:none!important' in delight,
        'Long-page cards still carry live backdrop blur in the final delight layer.')
require(A1, 'setInterval(' not in delight and 'setInterval(' not in top_nav,
        'Interaction/navigation polish should not own recurring interval loops.')

# ANGLE 2: motion should feel fluid but stay transform/opacity based and responsive.
require(A2, 'will-change:auto' in delight,
        'Buttons still carry permanent transform compositor hints.')
require(A2, 'transition:transform .055s' in delight,
        'Fast touch-down response is missing.')
require(A2, 'animation:lrPageEnter .22s cubic-bezier(.16,1,.3,1) both;' in aesthetic,
        'Final page entry timing/easing is not the fluid v5 contract.')
require(A2, 'from{opacity:.38;transform:translate3d(0,5px,0) scale(.998)}' in aesthetic,
        'Page entry does not use the low-travel transform/opacity start state.')
require(A2, '@media(prefers-reduced-motion:reduce)' in aesthetic,
        'Reduced Motion fallback is missing from interaction polish.')
require(A2, 'html.lrInteractionBusy #lifeRouteDelightBackdrop>span' in delight,
        'Ambient background motion is not paused during finger interaction.')
require(A2, 'touch-action:manipulation' in delight or 'touch-action:manipulation' in aesthetic,
        'Touch controls are missing manipulation hinting for responsive taps.')
require(A2, 'backdrop-filter:blur(14px)' in delight,
        'Navigation glass should retain a lighter bounded blur instead of card-wide blur.')

# ANGLE 3: user owns scrolling; lifecycle work must stop or pause appropriately.
guard_tag = '<script src="interaction-stability-v3.js"></script>'
require(A3, guard_tag in index, 'Interaction stability runtime is not included in index.html.')
if guard_tag in index:
    guard_pos = index.find(guard_tag)
    first_feature = index.find('<script src="calendar-hub.js"></script>')
    require(A3, first_feature < 0 or guard_pos < first_feature,
            'No-scroll guard loads too late to protect startup.')

for marker in [
    'window.scrollTo = noProgrammaticScroll',
    'window.scrollBy = noProgrammaticScroll',
    'Element.prototype.scrollIntoView = noProgrammaticScroll',
    "history.scrollRestoration = 'manual'",
    'preventScroll: true',
    'window.__lifeRouteNoScroll = noProgrammaticScroll',
    'Element.prototype.__lifeRouteNoScrollIntoView = noProgrammaticScroll',
    'visibilitychange',
]:
    require(A3, marker in stability, f'Interaction stability guard missing marker: {marker}')

scroll_sites = []
for path in sorted(WEB.glob('*.js')):
    if path.name == 'interaction-stability-v3.js':
        continue
    text = path.read_text()
    hits = []
    for token in (
        'scrollIntoView(', 'scrollIntoView?.(', 'scrollIntoViewIfNeeded(',
        'window.scrollTo(', 'window.scrollTo?.(', 'window.scrollBy(', 'window.scrollBy?.('
    ):
        if token in text:
            hits.append(token[:-1])
    if hits:
        scroll_sites.append(f"{path.name}: {', '.join(hits)}")
require(A3, not scroll_sites,
        'Legacy programmatic-scroll calls remain: ' + '; '.join(scroll_sites))
require(A3, 'clearInterval' in timer,
        'Visual Timer does not expose interval cleanup in the prepared runtime.')
require(A3, 'html.lrInteractionBusy' in delight and 'document.hidden' in stability,
        'Interaction/visibility pausing contract is incomplete.')

# ANGLE 4: exact prepared release contract and major navigation/tactile invariants.
require(A4, index.count('<script src="top-nav-four-v1.js"></script>') == 1,
        'Final four-tab navigation enforcer must appear exactly once.')
require(A4, "const ORDER = ['today', 'tools', 'resources', 'setup'];" in top_nav,
        'Top navigation order is not exactly Schedule, Session Tools, Resources, Setup.')
require(A4, "repeat(4, minmax(0, 1fr))" in top_nav,
        'Top navigation is not locked to four equal tracks.')
require(A4, "role=\"tab\"" in toolbar and "activePlaceCategory = 'Home'" in toolbar,
        'Saved Places third-level tabs are missing from the prepared runtime.')
require(A4, "pane.querySelector(':scope > .hero')?.remove()" in toolbar,
        'Redundant Saved Places hero still survives preparation.')
require(A4, 'DIRECT SESSION TOOLKIT' not in (WEB / 'rbt-tools.js').read_text(),
        'Redundant Session Tools hero survived preparation.')
require(A4, 'let firstIntensity: CGFloat' in swift and '.now() + 0.055' in swift,
        'Deep two-stage native haptic contract is missing.')
require(A4, 'playGlassTone(frequency: Double, intensity: Double, boost: Double = 5.0)' in swift,
        'Native boosted timer/audio contract is missing.')
require(A4, '[120,320,800,1600,2800]' not in tail,
        'Legacy delight-tail retry fanout remains.')

combined = '\n'.join(path.read_text() for path in WEB.glob('*.js'))
notes.extend([
    f'MutationObserver references: {combined.count("MutationObserver")}',
    f'setInterval references: {combined.count("setInterval(")}',
    f'requestAnimationFrame references: {combined.count("requestAnimationFrame(")}',
    f'will-change references: {combined.count("will-change")}',
    f'backdrop-filter references: {combined.count("backdrop-filter")}',
    'Legacy programmatic-scroll sites: none' if not scroll_sites else f'Legacy scroll sites: {len(scroll_sites)}',
])

print('LifeRoute four-angle interaction/performance audit:')
for angle, failures in angles.items():
    if failures:
        print(f' - {angle}: FAIL ({len(failures)})')
        for failure in failures:
            print(f'   FAIL: {failure}')
    else:
        print(f' - {angle}: PASS')
for note in notes:
    print(' - ' + note)

all_failures = [failure for failures in angles.values() for failure in failures]
if all_failures:
    raise SystemExit(1)

print('LifeRoute four-angle audit passed: runtime pressure, motion/touch, scroll/lifecycle, and release artifact.')
