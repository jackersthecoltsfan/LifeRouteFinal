from pathlib import Path

web = Path("LifeRoute/Web")
stability = (web / "interaction-stability-v3.js").read_text()

for marker in [
    'window.scrollTo = noProgrammaticScroll',
    'window.scrollBy = noProgrammaticScroll',
    'Element.prototype.scrollIntoView = noProgrammaticScroll',
    'window.__lifeRouteNoScroll = noProgrammaticScroll',
    'Element.prototype.__lifeRouteNoScrollIntoView = noProgrammaticScroll',
]:
    if marker not in stability:
        raise SystemExit(f"FAIL: no-scroll guard missing {marker}")

forbidden = [
    'scrollIntoView(',
    'scrollIntoView?.(',
    'scrollIntoViewIfNeeded(',
    'window.scrollTo(',
    'window.scrollTo?.(',
    'window.scrollBy(',
    'window.scrollBy?.(',
]

failures = []
for path in sorted(web.glob("*.js")):
    if path.name == "interaction-stability-v3.js":
        continue
    text = path.read_text()
    hits = [token for token in forbidden if token in text]
    if hits:
        failures.append(f"{path.name}: {', '.join(hits)}")

index = (web / "index.html").read_text()
inline_hits = [token for token in forbidden if token in index]
if inline_hits:
    failures.append(f"index.html: {', '.join(inline_hits)}")

print(f"LifeRoute no-programmatic-scroll audit: {0 if failures else 1} passed, {len(failures)} failed")
if failures:
    for failure in failures: print("FAIL:", failure)
    raise SystemExit(1)
print("Prepared runtime contains no document auto-scroll calls; the user's finger remains the only document-scroll driver.")
