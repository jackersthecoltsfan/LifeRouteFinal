from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
TAIL = WEB / "delight-tail-v1.js"
STABILITY = WEB / "stability-runtime.js"
INDEX = WEB / "index.html"
WELCOME = WEB / "welcome.js"

# Never rewrite top-nav button children after initial mounting unless an icon is truly
# absent. A delayed innerHTML assignment can invalidate WebKit's in-flight tap target.
tail = TAIL.read_text()
old_assignment = """      button.dataset.lrDelightIcon = '1';
      button.innerHTML = `${window.lifeRouteIcon(item[0],18)}<span>${item[1]}</span>`;
"""
new_assignment = """      button.dataset.lrDelightIcon = '1';
      const hasVector = !!button.querySelector('.lrIcon');
      const label = String(button.querySelector('span:last-child')?.textContent || button.textContent || '').trim();
      if (!hasVector || label !== item[1]) {
        button.innerHTML = `${window.lifeRouteIcon(item[0],18)}<span>${item[1]}</span>`;
      }
"""
if new_assignment not in tail:
    if old_assignment not in tail:
        raise SystemExit("delight-tail icon assignment marker missing")
    tail = tail.replace(old_assignment, new_assignment, 1)
# patch_interaction_performance_v3 adds this one delayed retry. The deterministic
# toolbar build is ready at DOMContentLoaded, so a later rewrite is unnecessary.
tail = tail.replace("  setTimeout(finalize, 280);\n", "", 1)
TAIL.write_text(tail)

# The fixed bottom action bar is present in the static document. Keep one scoped
# observer for actual replacement, but remove four speculative rebinding timers.
stability = STABILITY.read_text()
stability = stability.replace(
    "    [100, 350, 900, 1800].forEach(delay => setTimeout(bindBottomActions, delay));\n",
    "",
    1,
)
STABILITY.write_text(stability)

# Explicitly strip retired global interaction systems from the startup document if
# an older generated source ever reintroduces their script tags. They remain in the
# repository for reference/audits but are not allowed to own taps in v0.4.0.
index = INDEX.read_text()
for retired in [
    "touch-playground-v1.js",
    "interaction-liquid-v4.js",
    "premium-interactions-v1.js",
    "nav-portal-v1.js",
]:
    index = index.replace(f'<script src="{retired}"></script>', '')
INDEX.write_text(index)

# The generated first-run overlay is display:none when inactive; make pointer ownership
# explicit as an additional defense against invisible hit-testing layers.
welcome = WELCOME.read_text()
welcome = welcome.replace(
    '.lrWelcomeOverlay{position:fixed;inset:0;z-index:47000;display:none;',
    '.lrWelcomeOverlay{position:fixed;inset:0;z-index:47000;display:none;pointer-events:none;',
    1,
)
welcome = welcome.replace(
    'background:rgba(3,8,17,.94);pointer-events:auto;contain:layout paint style}',
    'background:rgba(3,8,17,.94);contain:layout paint style}',
    1,
)
welcome = welcome.replace(
    '.lrWelcomeOverlay.show{display:flex}',
    '.lrWelcomeOverlay.show{display:flex;pointer-events:auto}',
    1,
)
WELCOME.write_text(welcome)

verified_tail = TAIL.read_text()
if 'setTimeout(finalize, 280)' in verified_tail:
    raise SystemExit("stability pass failed: delayed nav rewrite remains")
if "if (!hasVector || label !== item[1])" not in verified_tail:
    raise SystemExit("stability pass failed: nav icon rewrite is not guarded")
if '[100, 350, 900, 1800]' in STABILITY.read_text():
    raise SystemExit("stability pass failed: speculative bottom-action timers remain")
final_index = INDEX.read_text()
for retired in ["touch-playground-v1.js", "interaction-liquid-v4.js", "premium-interactions-v1.js", "nav-portal-v1.js"]:
    if f'<script src="{retired}"></script>' in final_index:
        raise SystemExit(f"stability pass failed: retired interaction owner loaded: {retired}")
final_welcome = WELCOME.read_text()
for required in ['display:none;pointer-events:none', '.lrWelcomeOverlay.show{display:flex;pointer-events:auto}']:
    if required not in final_welcome:
        raise SystemExit(f"stability pass failed: welcome pointer contract missing {required}")

print("v0.4.0 stability pass: no delayed nav rewrites, no speculative rebinding timers, and hidden overlays cannot intercept taps.")
