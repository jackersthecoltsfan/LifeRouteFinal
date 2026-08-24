from pathlib import Path

path = Path("LifeRoute/Web/sleek-ui.js")
text = path.read_text()

marker = '''    .provider{padding:11px!important}.provider .icon{font-size:18px!important;margin-bottom:5px!important}.integrationIcon{border-radius:11px!important}.chip,.badge{padding:5px 7px!important;font-size:9.5px!important}.weekday{padding:10px 0!important}.bar{height:6px!important}.notice{border-radius:12px!important;font-size:10.5px!important}
'''
replacement = '''    .provider{padding:11px!important;position:relative!important;overflow:hidden!important}.provider .icon{font-size:18px!important;margin-bottom:5px!important}.provider.active{border-color:color-mix(in srgb,var(--gold) 82%,var(--line))!important;background:linear-gradient(145deg,color-mix(in srgb,var(--gold) 8%,transparent),color-mix(in srgb,var(--blue) 5%,transparent)),var(--panel)!important;box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 72%,transparent),0 10px 28px rgba(0,0,0,.10)!important}.provider.active:after{content:"✓";position:absolute;top:8px;right:9px;width:20px;height:20px;border-radius:999px;display:grid;place-items:center;background:var(--gold);color:var(--bg);font-size:11px;font-weight:950}.integrationIcon{border-radius:11px!important}.chip,.badge{padding:5px 7px!important;font-size:9.5px!important}.weekday{padding:10px 0!important}.bar{height:6px!important}.notice{border-radius:12px!important;font-size:10.5px!important}
'''

if replacement in text:
    print("Provider selection styling already present.")
elif marker not in text:
    raise SystemExit("Could not patch provider selection styling: marker not found")
else:
    path.write_text(text.replace(marker, replacement, 1))
    print("Made the active maps provider visually explicit.")
