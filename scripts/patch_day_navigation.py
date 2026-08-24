from pathlib import Path

path = Path("LifeRoute/Web/index.html")
html = path.read_text()

old_section = '<div class="section"><div class="sectionHead"><h2 id="todayLabel">Today</h2><span class="hint" id="mapProviderLabel">Apple Maps</span></div><div id="timeline"></div></div>'
new_section = '''<div class="section"><div class="sectionHead"><h2 id="todayLabel">Today</h2><span class="hint" id="mapProviderLabel">Apple Maps</span></div><div class="lrDayPager" aria-label="Day navigation"><button type="button" class="secondary" onclick="shiftSelectedDay(-1)" aria-label="Previous day">← <span>Previous</span></button><button type="button" class="secondary lrDayToday" onclick="jumpSelectedDayToToday()">Today</button><button type="button" class="secondary" onclick="shiftSelectedDay(1)" aria-label="Next day"><span>Next</span> →</button></div><div id="timeline"></div></div>'''

if 'class="lrDayPager"' not in html:
    if old_section not in html:
        raise SystemExit("Could not add day pager: Today section marker not found")
    html = html.replace(old_section, new_section, 1)

style_marker = '</style>'
style = '''
.lrDayPager{display:grid;grid-template-columns:1fr auto 1fr;gap:7px;margin:0 0 11px}.lrDayPager button{min-height:40px;border-radius:13px!important;display:flex;align-items:center;justify-content:center;gap:6px;font-size:11px}.lrDayPager button:first-child{justify-content:flex-start}.lrDayPager button:last-child{justify-content:flex-end}.lrDayToday{padding-left:16px!important;padding-right:16px!important;color:var(--gold)!important;border-color:color-mix(in srgb,var(--gold) 38%,var(--line))!important}@media(max-width:420px){.lrDayPager button span{display:none}.lrDayPager button:first-child,.lrDayPager button:last-child{justify-content:center}.lrDayPager{grid-template-columns:1fr 1.15fr 1fr}}
'''
if '.lrDayPager{' not in html:
    if style_marker not in html:
        raise SystemExit("Could not add day pager styles")
    html = html.replace(style_marker, style + style_marker, 1)

js_marker = 'function dayName(k){return DAYS[dateFromKey(k).getDay()]}'
js = '''function dayName(k){return DAYS[dateFromKey(k).getDay()]}
function shiftSelectedDay(delta){
  const d=dateFromKey(selectedDate);
  d.setDate(d.getDate()+Number(delta||0));
  selectedDate=localDateKey(d);
  renderAll();
  try{window.scrollTo({top:0,behavior:"smooth"})}catch(_){window.scrollTo(0,0)}
}
function jumpSelectedDayToToday(){
  selectedDate=localDateKey(new Date());
  renderAll();
  try{window.scrollTo({top:0,behavior:"smooth"})}catch(_){window.scrollTo(0,0)}
}'''
if 'function shiftSelectedDay(delta)' not in html:
    if js_marker not in html:
        raise SystemExit("Could not add day pager functions: date helper marker not found")
    html = html.replace(js_marker, js, 1)

path.write_text(html)
print("Previous / Today / Next day navigation enabled.")
