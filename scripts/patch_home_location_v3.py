from pathlib import Path
import re

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

# The old smart strip duplicated information already visible in the schedule and
# created a stray "smart"-style status area. Remove it completely.
pattern = re.compile(r'    const renderSmartStrip = \(\) => \{.*?\n    \};\n\n    buildSetupPanels\(\);', re.S)
replacement = '''    const renderSmartStrip = () => {\n      document.getElementById("smartContextStrip")?.remove();\n    };\n\n    buildSetupPanels();'''
text, count = pattern.subn(replacement, text, count=1)
if count != 1 and "document.getElementById(\"smartContextStrip\")?.remove();" not in text:
    raise SystemExit("Could not remove redundant smart context strip")

path.write_text(text)
print("Home/location UI simplified; MapKit/smart badges removed.")
