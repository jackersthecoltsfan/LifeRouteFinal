from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SYNC = (ROOT / "LifeRoute/Web/client-picker-sync-v1.js").read_text()
TOOLS = (ROOT / "LifeRoute/Web/rbt-tools.js").read_text()
SMART = (ROOT / "LifeRoute/Web/smart-context.js").read_text()
INDEX = (ROOT / "LifeRoute/Web/index.html").read_text()

checks = []

def check(name, condition):
    checks.append((name, bool(condition)))

# Same saved-client source used by Setup and both field-tool selectors.
check("setup owns prefs.clients", "prefs.clients = Array.isArray(prefs.clients)" in SMART)
check("setup saves clients", "prefs.clients.push({ first2, last2, address })" in SMART)
check("quick note client selector exists", 'id="quickNoteClient"' in TOOLS)
check("session plan client selector exists", 'id="sessionPlanClient"' in TOOLS)
check("sync targets quick notes", '"quickNoteClient"' in SYNC)
check("sync targets session plan", '"sessionPlanClient"' in SYNC)
check("sync reads live prefs clients", 'Array.isArray(prefs.clients)' in SYNC)
check("sync has persisted client fallback", 'saved?.prefs?.clients' in SYNC)
check("sync uses production local store", 'const STORE = "liferoute_v3"' in SYNC)
check("sync normalizes ABA first pair", "first2: formatPair" in SYNC)
check("sync normalizes ABA last pair", "last2: formatPair" in SYNC)
check("sync requires 4-letter codes", "code.length !== 4" in SYNC)
check("sync deduplicates saved clients", "seen.has(key)" in SYNC)
check("general option retained", "General / no client" in SYNC)
check("sync preserves selection", "const current = String(select.value" in SYNC)
check("save client triggers resync", "#saveClientButton" in SYNC)
check("remove client triggers resync", "removeLifeRouteClient" in SYNC)
check("tools tab triggers resync", "[data-view='tools']" in SYNC)
check("manual refresh still works", "#refreshToolClients" in SYNC)
check("storage event resyncs web tabs", 'event.key === STORE' in SYNC)
check("public refresh hook exists", "window.refreshLifeRouteToolClients = sync" in SYNC)

# Performance/stability: no permanent page-wide mutation observer or polling loop.
check("no interval polling", "setInterval(" not in SYNC)
check("observers scoped to setup/tools roots", 'document.getElementById("setup")' in SYNC and 'document.getElementById("tools")' in SYNC)
check("observer does not watch document body", "observer.observe(document" not in SYNC and "observer.observe(document.body" not in SYNC)
check("sync module included in prepared app", '<script src="client-picker-sync-v1.js"></script>' in INDEX)

failed = [name for name, ok in checks if not ok]
print(f"LifeRoute client picker audit: {len(checks) - len(failed)} passed, {len(failed)} failed")
if failed:
    for name in failed:
        print(f"FAIL: {name}")
    raise SystemExit(1)
print("LifeRoute saved-client picker audit passed.")
