from pathlib import Path

path = Path("LifeRoute/Web/route-times.js")
text = path.read_text()

# Store-comparison route requests use the same native routeTimes event as the
# main day/week commute engine. The main engine must ignore route results it
# did not request; otherwise it calls renderAll(), rebuilds the timeline, and
# collapses the open "What fits here?" / store chooser while the store search
# is still working.
marker = '''    if (evt.type === "routeTimes") {
      const results = Array.isArray(evt.results) ? evt.results : [];
      const meta = nativeState.routeSegmentMeta || {};
      let loaded = 0;
      let failed = 0;

      results.forEach(result => {
'''
replacement = '''    if (evt.type === "routeTimes") {
      const results = Array.isArray(evt.results) ? evt.results : [];
      const meta = nativeState.routeSegmentMeta || {};
      const ownedResults = results.filter(result =>
        Object.prototype.hasOwnProperty.call(meta, String(result.id || ""))
      );

      // A store detour comparison (or another feature) may also request native
      // route times. Leave those results to that feature and, critically, do
      // not rebuild the whole Today view while its chooser is open.
      if (!ownedResults.length) return;

      let loaded = 0;
      let failed = 0;

      ownedResults.forEach(result => {
'''

if replacement in text:
    print("Store-route ownership guard already applied.")
elif marker not in text:
    raise SystemExit("Could not patch store-route ownership guard: routeTimes handler marker not found")
else:
    text = text.replace(marker, replacement, 1)
    path.write_text(text)
    print("Patched route-time ownership so store comparisons stay open.")
