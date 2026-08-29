from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
GUARD = "interaction-stability-v3.js"

replacements = [
    ("window.scrollTo?.(", "window.__lifeRouteNoScroll?.("),
    ("window.scrollTo(", "window.__lifeRouteNoScroll("),
    ("window.scrollBy?.(", "window.__lifeRouteNoScroll?.("),
    ("window.scrollBy(", "window.__lifeRouteNoScroll("),
    (".scrollIntoViewIfNeeded?.(", ".__lifeRouteNoScrollIntoView?.("),
    (".scrollIntoViewIfNeeded(", ".__lifeRouteNoScrollIntoView("),
    (".scrollIntoView?.(", ".__lifeRouteNoScrollIntoView?.("),
    (".scrollIntoView(", ".__lifeRouteNoScrollIntoView("),
]

changed = []
for path in sorted(WEB.glob("*.js")):
    if path.name == GUARD:
        continue
    text = path.read_text()
    original = text
    for old, new in replacements:
        text = text.replace(old, new)
    if text != original:
        path.write_text(text)
        changed.append(path.name)

index_path = WEB / "index.html"
index = index_path.read_text()
original_index = index
for old, new in replacements:
    index = index.replace(old, new)
if index != original_index:
    index_path.write_text(index)
    changed.append("index.html")

forbidden = (
    "window.scrollTo(",
    "window.scrollTo?.(",
    "window.scrollBy(",
    "window.scrollBy?.(",
    ".scrollIntoView(",
    ".scrollIntoView?.(",
    ".scrollIntoViewIfNeeded(",
    ".scrollIntoViewIfNeeded?.(",
)
violations = []
for path in sorted(WEB.glob("*.js")):
    if path.name == GUARD:
        continue
    text = path.read_text()
    for token in forbidden:
        if token in text:
            violations.append(f"{path.name}: {token}")
index = index_path.read_text()
for token in forbidden:
    if token in index:
        violations.append(f"index.html: {token}")

if violations:
    raise SystemExit("Programmatic scrolling survived final preparation: " + "; ".join(violations))

# Final performance/motion pass.
delight_path = WEB / "delight-ui-v1.js"
delight = delight_path.read_text()

delight = delight.replace(
    '.card,.hero,.metric,.lrContextTabs,.tabs{backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px)}',
    '.lrContextTabs,.tabs{backdrop-filter:blur(14px);-webkit-backdrop-filter:blur(14px)}\n    .card,.hero,.metric{backdrop-filter:none!important;-webkit-backdrop-filter:none!important}',
    1,
)

start_pattern = re.compile(
    r"  const start = \(\) => \{\n"
    r"    mountBackdrop\(\);\n"
    r"    syncContext\(\);\n"
    r"    \[80,240,700,1500,2600\]\.forEach\(delay => setTimeout\(syncContext, delay\)\);\n"
    r"    const observer = new MutationObserver\(queueSync\);\n"
    r"    observer\.observe\(document\.body, \{ childList:true, subtree:true, attributes:true, attributeFilter:\['class'\] \}\);\n"
    r"  \};"
)
start_replacement = '''  const start = () => {
    mountBackdrop();
    syncContext();
    setTimeout(syncContext, 220);
    const appRoot = document.querySelector('.app') || document.body;
    const observer = new MutationObserver(records => {
      const structuralChange = records.some(record => record.type === 'childList' && (record.addedNodes.length || record.removedNodes.length));
      if (structuralChange) queueSync();
    });
    observer.observe(appRoot, { childList:true, subtree:true });
    document.addEventListener('click', event => {
      if (event.target?.closest?.('.tab,.lrContextTab,.lrQuickAddButton,.lrSettingsButton,.lrPlaceCategory')) queueSync();
    }, true);
  };'''
delight, start_count = start_pattern.subn(start_replacement, delight, count=1)
if start_count != 1 and 'observer.observe(appRoot, { childList:true, subtree:true });' not in delight:
    raise SystemExit('delight observer narrowing marker missing')

delight_path.write_text(delight)

# Page-entry ownership: older builds used lrPageEnter in aesthetic-polish.
# Optimized builds intentionally remove that duplicate and use lrPremiumViewEnter
# from premium-interactions-v1.js. Never reintroduce a second page animation.
aesthetic_path = WEB / "aesthetic-polish-v1.js"
aesthetic = aesthetic_path.read_text()
premium_path = WEB / "premium-interactions-v1.js"
premium = premium_path.read_text()
legacy_page_entry = "lrPageEnter" in aesthetic
if legacy_page_entry:
    aesthetic = aesthetic.replace(
        'animation:lrPageEnter .20s cubic-bezier(.2,.8,.2,1) both;',
        'animation:lrPageEnter .22s cubic-bezier(.16,1,.3,1) both;',
        1,
    )
    aesthetic = aesthetic.replace(
        'from{opacity:.14;transform:translate3d(0,8px,0) scale(.995)}',
        'from{opacity:.38;transform:translate3d(0,5px,0) scale(.998)}',
        1,
    )
    aesthetic_path.write_text(aesthetic)
else:
    if "lrPremiumViewEnter" not in premium or "requestAnimationFrame" not in premium:
        raise SystemExit("smooth runtime verification failed: optimized premium page transition missing")

# Collapse old toolbar startup fanout and batch observer.
toolbar_path = WEB / "toolbar-cleanup-v1.js"
toolbar = toolbar_path.read_text()
toolbar = toolbar.replace(
    '    [0, 80, 250, 700, 1400].forEach(delay => setTimeout(reconcile, delay));',
    '    setTimeout(reconcile, 220);',
    1,
)
old_observer = '''    const tabs = document.querySelector('.tabs');
    if (tabs && !window.__lifeRouteToolbarCleanupObserver) {
      const observer = new MutationObserver(() => reconcile());
      observer.observe(tabs, { childList: true });
      window.__lifeRouteToolbarCleanupObserver = observer;
    }
'''
new_observer = '''    const tabs = document.querySelector('.tabs');
    if (tabs && !window.__lifeRouteToolbarCleanupObserver) {
      let reconcileQueued = false;
      const observer = new MutationObserver(() => {
        if (reconcileQueued) return;
        reconcileQueued = true;
        requestAnimationFrame(() => {
          reconcileQueued = false;
          reconcile();
        });
      });
      observer.observe(tabs, { childList: true });
      window.__lifeRouteToolbarCleanupObserver = observer;
    }
'''
if old_observer in toolbar:
    toolbar = toolbar.replace(old_observer, new_observer, 1)
elif 'let reconcileQueued = false;' not in toolbar:
    raise SystemExit('toolbar observer batching marker missing')
toolbar_path.write_text(toolbar)

nav_script = WEB / "top-nav-four-v1.js"
nav_text = nav_script.read_text() if nav_script.exists() else ''
for marker in ('alreadyOrdered', "observe(tabs, { childList: true })"):
    if marker not in nav_text:
        raise SystemExit(f"Top navigation performance enforcer missing: {marker}")
if 'attributes: true' in nav_text:
    raise SystemExit('Top navigation still observes style/class attributes')

index = index_path.read_text()
nav_tag = '<script src="top-nav-four-v1.js"></script>'
if nav_tag not in index:
    if "</body>" not in index:
        raise SystemExit("Could not inject final four-tab navigation enforcer")
    index = index.replace("</body>", nav_tag + "\n</body>", 1)
    index_path.write_text(index)

checks = {
    delight_path: [
        'observer.observe(appRoot, { childList:true, subtree:true });',
        '.card,.hero,.metric{backdrop-filter:none!important',
    ],
    toolbar_path: ['setTimeout(reconcile, 220);', 'let reconcileQueued = false;'],
}
if legacy_page_entry:
    checks[aesthetic_path] = ['animation:lrPageEnter .22s cubic-bezier(.16,1,.3,1) both;', 'translate3d(0,5px,0) scale(.998)']
else:
    checks[premium_path] = ['lrPremiumViewEnter', 'requestAnimationFrame']

for path, markers in checks.items():
    final = path.read_text()
    for marker in markers:
        if marker not in final:
            raise SystemExit(f"smooth runtime verification failed: {path.name} missing {marker}")

print("Removed legacy programmatic scrolling from: " + (", ".join(changed) if changed else "no remaining files"))
print("Applied final smoothness pass: narrow observers, cheaper glass cards, batched toolbar reconciliation, single compositor-friendly page transition system.")
print("Final four-tab navigation enforcer enabled without an attribute-mutation loop.")
