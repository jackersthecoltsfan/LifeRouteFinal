from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
INDEX = WEB / "index.html"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"

failures = []
notes = []

index = INDEX.read_text()
delight = (WEB / "delight-ui-v1.js").read_text()
tail = (WEB / "delight-tail-v1.js").read_text()
stability = (WEB / "interaction-stability-v3.js").read_text()
swift = SWIFT.read_text()


def require(condition: bool, message: str) -> None:
    if not condition:
        failures.append(message)


# Navigation/layout correctness.
require('grid-template-columns:repeat(4,minmax(0,1fr))!important' in delight,
        'Top navigation is not locked to four equal centered columns.')

# Touch-response / compositor budget.
require('will-change:auto' in delight,
        'Buttons still carry permanent transform compositor hints.')
require('transition:transform .055s' in delight,
        'Fast touch-down response is missing.')
require('html.lrInteractionBusy #lifeRouteDelightBackdrop>span' in delight,
        'Ambient motion is not paused during touch/scroll interaction.')
require('[120,320,800,1600,2800]' not in tail,
        'Legacy five-pass delight startup retry fanout is still present.')

# Haptic contract.
require('let firstIntensity: CGFloat' in swift and '.now() + 0.055' in swift,
        'Deep two-stage native haptic contract is missing.')

# Programmatic scrolling must be blocked before feature modules initialize.
guard_tag = '<script src="interaction-stability-v3.js"></script>'
require(guard_tag in index, 'Interaction stability runtime is not included in index.html.')
if guard_tag in index:
    guard_pos = index.find(guard_tag)
    first_feature = index.find('<script src="calendar-hub.js"></script>')
    require(first_feature < 0 or guard_pos < first_feature,
            'Interaction stability runtime loads too late to block startup scroll behavior.')

for marker in [
    'window.scrollTo = noProgrammaticScroll',
    'window.scrollBy = noProgrammaticScroll',
    'Element.prototype.scrollIntoView = noProgrammaticScroll',
    "history.scrollRestoration = 'manual'",
    'preventScroll: true',
]:
    require(marker in stability, f'No-auto-scroll guard missing marker: {marker}')

# Report remaining programmatic-scroll call sites. These are inert because the guard
# is installed first, but the list identifies legacy code worth deleting later.
scroll_sites = []
for path in sorted(WEB.glob('*.js')):
    if path.name == 'interaction-stability-v3.js':
        continue
    text = path.read_text()
    hits = []
    for token in ('scrollIntoView(', 'window.scrollTo(', 'window.scrollBy('):
        if token in text:
            hits.append(token[:-1])
    if hits:
        scroll_sites.append(f"{path.name}: {', '.join(hits)}")

# Static workload inventory for regression tracking.
combined = '\n'.join(path.read_text() for path in WEB.glob('*.js'))
observer_count = combined.count('MutationObserver')
interval_count = combined.count('setInterval(')
raf_count = combined.count('requestAnimationFrame(')
will_change_count = combined.count('will-change')
backdrop_count = combined.count('backdrop-filter')

notes.append(f'MutationObserver references: {observer_count}')
notes.append(f'setInterval references: {interval_count}')
notes.append(f'requestAnimationFrame references: {raf_count}')
notes.append(f'will-change references: {will_change_count}')
notes.append(f'backdrop-filter references: {backdrop_count}')
notes.append('Remaining blocked programmatic-scroll sites: ' + (('; '.join(scroll_sites)) if scroll_sites else 'none'))

# The new delight layer must not restore permanent transform layers to every control.
require('will-change:transform;transition:transform .125s' not in delight,
        'Old permanent button compositing rule survived final performance patch.')

print('LifeRoute interaction/performance audit:')
for note in notes:
    print(' - ' + note)

if failures:
    for failure in failures:
        print('FAIL: ' + failure)
    raise SystemExit(1)

print('Focused interaction performance audit passed.')
