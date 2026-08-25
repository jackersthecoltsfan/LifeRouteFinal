from pathlib import Path


def replace_once(path: Path, old: str, new: str, label: str):
    text = path.read_text()
    if old not in text:
        raise SystemExit(f"Could not harden {label}: expected source not found")
    path.write_text(text.replace(old, new, 1))


# Browser/native truthfulness: the base bridge must return false when there is no
# WKWebView message handler. Otherwise browser fallbacks can be suppressed.
index = Path("LifeRoute/Web/index.html")
replace_once(
    index,
    'function postNative(payload){try{window.webkit?.messageHandlers?.lifeRoute?.postMessage(payload);return true}catch(e){return false}}',
    'function postNative(payload){try{const handler=window.webkit?.messageHandlers?.lifeRoute;if(!handler||typeof handler.postMessage!=="function")return false;handler.postMessage(payload);return true}catch(e){return false}}',
    "truthful native bridge fallback",
)

# The Live Day control strip only depends on mutations inside #today. Watching
# the whole document makes theme/tool/overlay changes wake an unrelated pass.
controls = Path("LifeRoute/Web/day-controls-v5.js")
replace_once(
    controls,
    '''  const observer = new MutationObserver(install);
  const start = () => {
    observer.observe(document.body, { childList: true, subtree: true });
    install();
''',
    '''  const observer = new MutationObserver(install);
  const start = () => {
    const todayRoot = document.getElementById("today");
    if (todayRoot) observer.observe(todayRoot, { childList: true, subtree: true });
    install();
''',
    "Live Day observer scope",
)

# A gap-duration prompt should only appear after the selected route actually
# changes. If the user cancels route-origin choice, unrelated rerenders must not
# open the duration sheet later.
duration = Path("LifeRoute/Web/stop-duration-v1.js")
replace_once(
    duration,
    '''  let state = null;
  let pendingGapPrompt = false;
  let promptedGapKey = "";
''',
    '''  let state = null;
  let pendingGapPrompt = false;
  let pendingGapSnapshot = {};
''',
    "gap prompt state",
)
replace_once(
    duration,
    '''      if (pendingGapPrompt && key !== promptedGapKey) {
        pendingGapPrompt = false;
        promptedGapKey = key;
        setTimeout(() => open("gap", key), 35);
      }
''',
    '''      if (pendingGapPrompt) {
        const previous = pendingGapSnapshot[key];
        const changed = !previous || clean(previous.selectedAt) !== clean(selection.selectedAt);
        if (changed) {
          pendingGapPrompt = false;
          pendingGapSnapshot = {};
          setTimeout(() => open("gap", key), 35);
        }
      }
''',
    "gap prompt commit detection",
)
replace_once(
    duration,
    '''    const wrapped = function() {
      pendingGapPrompt = true;
      return original.apply(this, arguments);
    };
''',
    '''    const wrapped = function() {
      pendingGapSnapshot = readObject(GAP_STORE);
      pendingGapPrompt = true;
      return original.apply(this, arguments);
    };
''',
    "gap prompt snapshot",
)

# Blank or invalid custom duration input must not silently turn into a 1-minute
# stop. Only finite positive values are accepted, then clamped to 1–240 minutes.
replace_once(
    duration,
    '''    const minutes = Math.max(1, Math.min(240, Math.round(Number(value || 0))));
    if (!minutes) return;
''',
    '''    const numeric = Number(value);
    if (!Number.isFinite(numeric) || numeric < 1) return;
    const minutes = Math.max(1, Math.min(240, Math.round(numeric)));
''',
    "stop duration custom input validation",
)

print("Release hardening applied: truthful browser bridge, scoped Live Day observer, commit-aware stop-duration prompt, validated custom duration.")
