from pathlib import Path

path = Path("LifeRoute/Web/index.html")
html = path.read_text()

old_section = '<div class="section"><div class="sectionHead"><h2 id="todayLabel">Today</h2><span class="hint" id="mapProviderLabel">Apple Maps</span></div><div id="timeline"></div></div>'
new_section = '''<div class="section"><div class="sectionHead"><h2 id="todayLabel">Today</h2><span class="hint" id="mapProviderLabel">Apple Maps</span></div><div class="lrDayPager" aria-label="Day navigation"><button type="button" class="secondary" id="dayPrevButton" aria-label="Previous day">← <span>Previous</span></button><button type="button" class="secondary lrDayToday" id="dayTodayButton">Today</button><button type="button" class="secondary" id="dayNextButton" aria-label="Next day"><span>Next</span> →</button></div><div id="timeline"></div></div>'''

if 'class="lrDayPager"' not in html:
    if old_section not in html:
        raise SystemExit("Could not add day pager: Today section marker not found")
    html = html.replace(old_section, new_section, 1)
else:
    # Upgrade an older inline-handler pager to the stable runtime-bound markup.
    import re
    html = re.sub(
        r'<div class="lrDayPager" aria-label="Day navigation">.*?</div><div id="timeline"></div>',
        new_section.split('</div><div id="timeline">')[0] + '</div><div id="timeline"></div>',
        html,
        count=1,
        flags=re.S,
    )

style_marker = '</style>'
style = '''
.lrDayPager{display:grid;grid-template-columns:1fr auto 1fr;gap:7px;margin:0 0 11px}.lrDayPager button{min-height:40px;border-radius:13px!important;display:flex;align-items:center;justify-content:center;gap:6px;font-size:11px;touch-action:manipulation}.lrDayPager button:first-child{justify-content:flex-start}.lrDayPager button:last-child{justify-content:flex-end}.lrDayToday{padding-left:16px!important;padding-right:16px!important;color:var(--gold)!important;border-color:color-mix(in srgb,var(--gold) 38%,var(--line))!important}@media(max-width:420px){.lrDayPager button span{display:none}.lrDayPager button:first-child,.lrDayPager button:last-child{justify-content:center}.lrDayPager{grid-template-columns:1fr 1.15fr 1fr}}
'''
if '.lrDayPager{' not in html:
    if style_marker not in html:
        raise SystemExit("Could not add day pager styles")
    html = html.replace(style_marker, style + style_marker, 1)

# Saved Places are a first-class option in ordinary between-appointment gaps.
# Load this lightweight timeline enhancement in both the web preview and native
# WKWebView. It retries until the To-Do gap engine is mounted, so it is safe to
# place before the final deterministic feature-script block.
saved_place_tag = '<script src="saved-place-gap-options.js"></script>'
if saved_place_tag not in html:
    if "</body>" not in html:
        raise SystemExit("Could not enable Saved Places gap options: </body> not found")
    html = html.replace("</body>", saved_place_tag + "\n</body>", 1)

path.write_text(html)

# The WebView runtime owns the visible button layer, so bridge button presses to
# native UIKit haptics. Keep this in the deterministic preparation path so the
# exact source shipped to TestFlight always contains the feedback contract.
swift_path = Path("LifeRoute/LifeRouteWebView.swift")
swift = swift_path.read_text()
if 'case "haptic":' not in swift:
    marker = '            case "openRoute":\n'
    haptic_case = '''            case "haptic":
                let requestedStyle = (body["style"] as? String ?? "light").lowercased()
                let feedbackStyle: UIImpactFeedbackGenerator.FeedbackStyle
                switch requestedStyle {
                case "medium":
                    feedbackStyle = .medium
                case "heavy":
                    feedbackStyle = .heavy
                default:
                    feedbackStyle = .light
                }
                let generator = UIImpactFeedbackGenerator(style: feedbackStyle)
                generator.prepare()
                generator.impactOccurred()
            case "openRoute":
'''
    if marker not in swift:
        raise SystemExit("Could not add native button haptics: openRoute bridge marker not found")
    swift = swift.replace(marker, haptic_case, 1)
    swift_path.write_text(swift)

if 'case "haptic":' not in swift_path.read_text() or "UIImpactFeedbackGenerator" not in swift_path.read_text():
    raise SystemExit("Native button haptic bridge verification failed")

print("Previous / Today / Next navigation, Saved Places gap options, and native button haptics enabled.")
