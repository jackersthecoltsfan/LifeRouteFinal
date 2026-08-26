from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
GUARD = "interaction-stability-v3.js"

# Rewrite legacy viewport-moving APIs to the inert guard aliases. This is deliberately
# done as the final source-preparation pass so older feature patches cannot reintroduce
# automatic page movement after this point.
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

# Final hard gate: prepared runtime files may not contain direct programmatic
# viewport-scrolling calls. The guard file itself owns the disabled native methods.
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

if violations:
    raise SystemExit("Programmatic scrolling survived final preparation: " + "; ".join(violations))

# The top navigation is finalized by a tiny runtime enforcer. It removes any
# legacy/hidden fifth child and forces the four canonical destinations into four
# equal full-width columns. Keep this tag outside the normalized core list so its
# scoped observer can reconcile any later toolbar mutation during startup.
nav_script = WEB / "top-nav-four-v1.js"
if not nav_script.exists() or not nav_script.read_text().strip():
    raise SystemExit("Missing final four-tab navigation enforcer")

index_path = WEB / "index.html"
index = index_path.read_text()
nav_tag = '<script src="top-nav-four-v1.js"></script>'
if nav_tag not in index:
    if "</body>" not in index:
        raise SystemExit("Could not inject final four-tab navigation enforcer")
    index = index.replace("</body>", nav_tag + "\n</body>", 1)
    index_path.write_text(index)

print("Removed legacy programmatic scrolling from: " + (", ".join(changed) if changed else "no remaining files"))
print("Final four-tab navigation enforcer enabled.")
