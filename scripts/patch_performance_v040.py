from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
DELIGHT = WEB / "delight-ui-v1.js"
ICONS = WEB / "icons.js"

# On native iPhone, retain the themed color field but make it static while removing
# extra blur work from the persistent navigation surfaces.
delight = DELIGHT.read_text()
delight = delight.replace(
    'html[data-life-route-runtime="native"] #lifeRouteDelightBackdrop>span{animation-duration:52s!important}',
    'html[data-life-route-runtime="native"] #lifeRouteDelightBackdrop>span{animation:none!important;will-change:auto!important}',
    1,
)
delight = delight.replace(
    'html[data-life-route-runtime="native"] .tabs{backdrop-filter:blur(12px)!important;-webkit-backdrop-filter:blur(12px)!important}',
    'html[data-life-route-runtime="native"] .tabs{backdrop-filter:blur(6px)!important;-webkit-backdrop-filter:blur(6px)!important}',
    1,
)
delight = delight.replace(
    'html[data-life-route-runtime="native"] .lrContextTabs{backdrop-filter:blur(10px)!important;-webkit-backdrop-filter:blur(10px)!important}',
    'html[data-life-route-runtime="native"] .lrContextTabs{backdrop-filter:blur(6px)!important;-webkit-backdrop-filter:blur(6px)!important}',
    1,
)
delight = delight.replace(
    'html[data-life-route-runtime="native"] .lrQuickAddButton,\n    html[data-life-route-runtime="native"] .lrSettingsButton{backdrop-filter:blur(10px)!important;-webkit-backdrop-filter:blur(10px)!important}',
    'html[data-life-route-runtime="native"] .lrQuickAddButton,\n    html[data-life-route-runtime="native"] .lrSettingsButton{backdrop-filter:blur(6px)!important;-webkit-backdrop-filter:blur(6px)!important}',
    1,
)
DELIGHT.write_text(delight)

# The icon layer used to watch document.body and then rescan static document regions
# for every mutation. Observe only dynamic product surfaces and decorate only added
# button subtrees. This preserves dynamic button icons without a whole-document scan.
icons = ICONS.read_text()
old_start = '''  const start = () => {
    decorateStatic(document);
    const observer = new MutationObserver(records => {
      records.forEach(record => record.addedNodes.forEach(node => {
        if (node.nodeType !== 1) return;
        decorateStatic(node);
      }));
    });
    observer.observe(document.body, { childList: true, subtree: true });
  };
'''
new_start = '''  const decorateAdded = node => {
    if (!(node instanceof Element)) return;
    if (node.matches('button')) decorateButton(node);
    node.querySelectorAll?.('button').forEach(decorateButton);
  };

  const start = () => {
    decorateStatic(document);
    const roots = [
      document.getElementById('timeline'),
      document.getElementById('placesList'),
      document.getElementById('resources'),
      document.getElementById('tools'),
      document.getElementById('setup')
    ].filter(Boolean);
    if (!roots.length) return;
    const observer = new MutationObserver(records => {
      records.forEach(record => record.addedNodes.forEach(decorateAdded));
    });
    roots.forEach(root => observer.observe(root, { childList:true, subtree:true }));
    window.__lifeRouteIconObserver = observer;
  };
'''
if new_start not in icons:
    if old_start not in icons:
        raise SystemExit("icon whole-document observer marker missing")
    icons = icons.replace(old_start, new_start, 1)
ICONS.write_text(icons)

for required in [
    'animation:none!important;will-change:auto!important',
    'blur(6px)!important',
]:
    if required not in DELIGHT.read_text():
        raise SystemExit(f"performance pass missing delight marker: {required}")
verified_icons = ICONS.read_text()
if 'observer.observe(document.body' in verified_icons:
    raise SystemExit("performance pass failed: icon layer still observes document.body")
for required in ["const decorateAdded = node =>", "roots.forEach(root => observer.observe(root", "window.__lifeRouteIconObserver"]:
    if required not in verified_icons:
        raise SystemExit(f"performance pass missing scoped icon marker: {required}")

print("v0.4.0 performance pass: native ambient motion is static, blur is reduced, and icon updates use scoped observers only.")
