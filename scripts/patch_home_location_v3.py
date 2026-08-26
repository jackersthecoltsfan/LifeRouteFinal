from pathlib import Path

path = Path("LifeRoute/Web/smart-context.js")
text = path.read_text()

text = text.replace(
    '<div class="sectionHead"><h2>Commute intelligence</h2><span class="hint">live start + home fallback</span></div>',
    '<div class="sectionHead"><h2>Home & location</h2></div>'
)
text = text.replace(
    '<div class="tiny" style="margin-top:9px">For today, LifeRoute starts your first commute from your live location. Home is the fallback and the smarter anchor for future-day planning when your current position would be misleading.</div>',
    ''
)
text = text.replace(
    '<span class="contextPill">MapKit route intelligence</span>',
    ''
)

# Keep renderSmartStrip structurally intact here because a later location-safety
# patch hardens its live-location freshness logic. The visible strip is removed
# by home-location-v3.js / schedule-simplify-v1.js after all safety patches run.
path.write_text(text)
print("Home/location UI simplified; obsolete MapKit badge removed while smart-context safety hooks remain patchable.")
