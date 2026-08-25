from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if old in text:
        path.write_text(text.replace(old, new, 1))
        return
    if new and new in text:
        return
    raise SystemExit(f"{label}: expected pattern not found in {path}")

# These mature helpers no longer need multiple delayed installation attempts.
replace_once(
    WEB / "end-home-route-web.js",
    '  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => setTimeout(install, 250), { once: true });\n  else setTimeout(install, 250);\n  [600, 1200, 2400].forEach(delay => setTimeout(install, delay));',
    '  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", install, { once: true });\n  else install();',
    "End-home startup cleanup",
)
replace_once(
    WEB / "mileage-tracker-web.js",
    '  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => setTimeout(install,500), {once:true});\n  else setTimeout(install,500);\n  [1000,2000,4000].forEach(delay => setTimeout(install,delay));',
    '  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", install, {once:true});\n  else install();',
    "Mileage startup cleanup",
)
replace_once(
    WEB / "resources-hub-web.js",
    '  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => setTimeout(wire, 300), { once:true });\n  else setTimeout(wire, 300);\n  [700, 1400, 2600].forEach(delay => setTimeout(wire, delay));',
    '  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", wire, { once:true });\n  else wire();',
    "Resources startup cleanup",
)
replace_once(
    WEB / "visual-quality-web.js",
    '  let attempts = 0;\n  const timer = setInterval(() => {\n    attempts += 1;\n    if (install() || attempts > 100) clearInterval(timer);\n  }, 80);\n  install();',
    '  install();',
    "Visual quality polling cleanup",
)

# UI simplification only cares about Today and Settings; do not wake it for
# unrelated Tools/Resources/overlay DOM changes.
replace_once(
    WEB / "ui-simplify-v4.js",
    '  const observer = new MutationObserver(polish);\n  const start = () => {\n    observer.observe(document.body, { childList: true, subtree: true });\n    polish();\n  };',
    '  const observer = new MutationObserver(polish);\n  const start = () => {\n    [document.getElementById("today"), document.getElementById("lifeRouteSettingsOverlay")]\n      .filter(Boolean)\n      .forEach(root => observer.observe(root, { childList: true, subtree: true }));\n    polish();\n  };',
    "UI simplifier observer scope",
)

# patch_stability.py already frame-coalesces refined-ui before this patch runs.
# Tighten its remaining page-wide observer and remove the delayed retry fanout.
refined_path = WEB / "refined-ui-v2.js"
refined = refined_path.read_text()
prepared_old = '''  const start = () => {
    let polishQueued = false;
    const queuePolish = () => {
      if (polishQueued) return;
      polishQueued = true;
      requestAnimationFrame(() => {
        polishQueued = false;
        polish();
      });
    };
    polish();
    const observer = new MutationObserver(queuePolish);
    observer.observe(document.body, { childList: true, subtree: true });
    [150, 500, 1200, 2400].forEach(delay => setTimeout(queuePolish, delay));
  };'''
desired = '''  const start = () => {
    let polishQueued = false;
    const queuePolish = () => {
      if (polishQueued) return;
      polishQueued = true;
      requestAnimationFrame(() => {
        polishQueued = false;
        polish();
      });
    };
    polish();
    const today = document.getElementById("today");
    if (today) new MutationObserver(queuePolish).observe(today, { childList: true, subtree: true });
  };'''
if desired not in refined:
    if prepared_old not in refined:
        raise SystemExit(f"Refined UI observer scope: expected post-stability pattern not found in {refined_path}")
    refined = refined.replace(prepared_old, desired, 1)
    refined_path.write_text(refined)

# Native WKWebView: preserve the premium identity but stop compositing a blurred
# layer behind every card. This is one of the highest-cost effects on long
# scrolling Day/Tools screens. Navigation glass remains intentionally intact.
stability_path = WEB / "stability-runtime.js"
stability = stability_path.read_text()
native_perf_marker = 'html[data-life-route-runtime="native"] .lrNativePerfSolid'
if native_perf_marker not in stability:
    needle = '    /* Native WKWebView gets the same visual identity with less compositing work. */\n'
    rules = '''    /* Native WKWebView gets the same visual identity with less compositing work. */
    html[data-life-route-runtime="native"] body{background-attachment:scroll!important}
    html[data-life-route-runtime="native"] .card,
    html[data-life-route-runtime="native"] .metric,
    html[data-life-route-runtime="native"] .todoMetric,
    html[data-life-route-runtime="native"] .monthMetric,
    html[data-life-route-runtime="native"] .hero{backdrop-filter:none!important;-webkit-backdrop-filter:none!important}
    html[data-life-route-runtime="native"] .lrNativePerfSolid{backdrop-filter:none!important;-webkit-backdrop-filter:none!important}
'''
    if needle not in stability:
        raise SystemExit("Native compositing cleanup: stability style marker not found")
    stability = stability.replace(needle, rules, 1)

old_start = '''  const start = () => {
    bindBottomActions();
    const bar = document.querySelector(".bottomin");
    if (bar) new MutationObserver(bindBottomActions).observe(bar, { childList: true, subtree: true });
    [100, 350, 900, 1800].forEach(delay => setTimeout(bindBottomActions, delay));
  };'''
new_start = '''  const start = () => {
    bindBottomActions();
    const bar = document.querySelector(".bottomin");
    if (bar) new MutationObserver(bindBottomActions).observe(bar, { childList: true, subtree: true });
  };'''
if new_start not in stability:
    if old_start not in stability:
        raise SystemExit("Bottom action startup cleanup: expected stability start block not found")
    stability = stability.replace(old_start, new_start, 1)
stability_path.write_text(stability)

# Browser preview should not dynamically reload modules that are already in the
# shared core. Load guards prevent correctness bugs, but the duplicate requests
# still add startup/network work.
preview = ROOT / "scripts" / "web-preview.js"
text = preview.read_text()
for name in [
    "first-then-back.js", "visual-quality-web.js", "photo-source-picker-web.js",
    "end-home-route-web.js", "mileage-tracker-web.js", "resources-hub-web.js",
    "nature-settings-web.js", "settings-classic-themes-web.js",
    "photoreal-nature-web.js", "dynamic-themes-web.js",
]:
    text = text.replace(f'    loadPreviewScript("{name}");\n', "")
preview.write_text(text)

print("Runtime performance cleanup applied: startup retries removed, observers scoped, native card compositing reduced, duplicate preview loads removed.")
