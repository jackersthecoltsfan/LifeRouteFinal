from pathlib import Path

path = Path("LifeRoute/Web/index.html")
html = path.read_text()

appearance = '''  <div class="section"><div class="sectionHead"><h2>Appearance</h2><span class="hint">customizable</span></div><div class="card">
    <div class="grid2">
      <div><label>Theme</label><select id="themeSelect" onchange="setTheme(this.value)"><option value="royal">Royal Blue + Gold</option><option value="daylight">Blue + Gold Light</option><option value="ocean">Ocean</option><option value="slate">Graphite</option></select></div>
      <div><label>Ideal max gap</label><select id="pGap" onchange="prefChanged()"><option value="60" selected>1 hour</option><option value="90">1.5 hours</option><option value="120">2 hours</option></select></div>
    </div>
  </div></div>
'''
planning = '''  <div class="section" id="lifeRoutePlanningPreferences"><div class="sectionHead"><h2>Planning</h2><span class="hint">day preferences</span></div><div class="card">
    <div><label>Ideal max gap</label><select id="pGap" onchange="prefChanged()"><option value="60" selected>1 hour</option><option value="90">1.5 hours</option><option value="120">2 hours</option></select></div>
  </div></div>
'''

if appearance in html:
    html = html.replace(appearance, planning, 1)
elif '<h2>Appearance</h2>' in html:
    raise SystemExit("Appearance section changed unexpectedly; refusing an unsafe partial theme patch")

old_set_theme = 'function setTheme(t){prefs.theme=t;document.documentElement.dataset.theme=t==="royal"?"":t;themeSelect.value=t;persist()}'
new_set_theme = 'function setTheme(t){prefs.theme=t;document.documentElement.dataset.theme=t==="royal"?"":t;const legacyThemeSelect=document.getElementById("themeSelect");if(legacyThemeSelect)legacyThemeSelect.value=t;persist()}'
if old_set_theme in html:
    html = html.replace(old_set_theme, new_set_theme, 1)
elif 'themeSelect.value=t' in html:
    raise SystemExit("setTheme changed unexpectedly; refusing an unsafe theme-select patch")

path.write_text(html)
print("Moved all appearance/theme selection into the top-right Settings sheet; Setup now keeps planning preferences only.")
