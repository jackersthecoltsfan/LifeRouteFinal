from pathlib import Path
import os
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "LifeRoute" / "Web"
DIST = ROOT / "dist"
PREVIEW = ROOT / "scripts" / "web-preview.js"

if not SOURCE.is_dir():
    raise SystemExit("LifeRoute/Web is missing")
if not PREVIEW.is_file():
    raise SystemExit("scripts/web-preview.js is missing")

if DIST.exists():
    shutil.rmtree(DIST)
shutil.copytree(SOURCE, DIST)
shutil.copy2(PREVIEW, DIST / "web-preview.js")
(DIST / ".nojekyll").touch()

sha = (os.environ.get("GITHUB_SHA") or os.environ.get("BUILD_SHA") or "local")[:8]
index = DIST / "index.html"
html = index.read_text()

preview_tag = '<script src="web-preview.js"></script>'
if preview_tag not in html:
    if "</body>" not in html:
        raise SystemExit("Could not build Pages preview: </body> not found")
    html = html.replace("</body>", preview_tag + "\n</body>", 1)

# Every local JS reference gets the same exact build version. This prevents
# mobile Safari from mixing a new HTML shell with an older runtime module.
html = re.sub(
    r'<script src="([^"]+\.js)(?:\?[^"]*)?"></script>',
    lambda match: f'<script src="{match.group(1)}?v={sha}"></script>',
    html,
)

marker = f'<meta name="liferoute-web-build" content="{sha}">'
if "liferoute-web-build" in html:
    html = re.sub(
        r'<meta name="liferoute-web-build" content="[^"]*">',
        marker,
        html,
        count=1,
    )
elif "</head>" in html:
    html = html.replace("</head>", marker + "\n</head>", 1)
else:
    raise SystemExit("Could not add LifeRoute web build marker: </head> not found")

index.write_text(html)
print(f"LifeRoute browser preview built for {sha} at {DIST}")
