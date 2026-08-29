from pathlib import Path
import runpy

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

# These follow-up patches intentionally execute at this deterministic point: the
# native CoreLocation bridge and shared web sources already exist, while later
# release/location hardening can still validate and refine the prepared result.
runpy.run_path("scripts/patch_live_location_reliability_v2.py", run_name="__main__")
runpy.run_path("scripts/patch_experience_release_v1.py", run_name="__main__")

print("Home/location UI simplified; live-location acquisition and unified experience hardening applied.")
