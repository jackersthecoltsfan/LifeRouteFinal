from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
TOOLBAR = WEB / "toolbar-cleanup-v1.js"

text = TOOLBAR.read_text()

old_top = """  const TOP_NAV = [
    { view: 'today', label: 'Schedule', icon: () => icon('calendar', '▣') },
    { view: 'tools', label: 'Session Tools', icon: () => '<span class=\"lrPuzzleIcon\" aria-hidden=\"true\">🧩</span>' },
    { view: 'resources', label: 'Resources', icon: () => icon('book', '▤') },
    { view: 'setup', label: 'Setup', icon: () => icon('person', '◎') }
  ];
"""
new_top = """  const TOP_NAV = [
    { view: 'today', label: 'Schedule', icon: () => icon('calendar', '▣', 19) },
    { view: 'tools', label: 'Session Tools', icon: () => icon('briefcase', '◈', 19) },
    { view: 'resources', label: 'Resources', icon: () => icon('package', '▤', 19) },
    { view: 'setup', label: 'Setup', icon: () => icon('settings', '◎', 19) }
  ];
"""
if new_top not in text:
    if old_top not in text:
        raise SystemExit("top navigation icon source marker missing")
    text = text.replace(old_top, new_top, 1)

old_setup = """      <button class=\"lrHubCard\" type=\"button\" data-lr-setup-pane=\"places\"><span class=\"lrHubIcon\">⌂</span><span><b>Saved Places</b><span class=\"lrHubMeta\">Home, relaxation, errands, and other locations.</span></span><span class=\"lrHubChevron\">›</span></button>
      <button class=\"lrHubCard\" type=\"button\" data-lr-setup-pane=\"clients\"><span class=\"lrHubIcon\">◎</span><span><b>Clients</b><span class=\"lrHubMeta\">ABA-style client profiles and service locations.</span></span><span class=\"lrHubChevron\">›</span></button>
      <button class=\"lrHubCard\" type=\"button\" data-lr-setup-pane=\"tasks\"><span class=\"lrHubIcon\">✓</span><span><b>Personal Tasks</b><span class=\"lrHubMeta\">Flexible tasks and errands to fit into open gaps.</span></span><span class=\"lrHubChevron\">›</span></button>
      <button class=\"lrHubCard\" type=\"button\" data-lr-setup-pane=\"connections\"><span class=\"lrHubIcon\">↗</span><span><b>Connections</b><span class=\"lrHubMeta\">Connect calendars and choose your navigation app.</span></span><span class=\"lrHubChevron\">›</span></button>
"""
new_setup = """      <button class=\"lrHubCard\" type=\"button\" data-lr-setup-pane=\"places\"><span class=\"lrHubIcon\">${icon('pin','⌂',20)}</span><span><b>Saved Places</b><span class=\"lrHubMeta\">Home, relaxation, errands, and other locations.</span></span><span class=\"lrHubChevron\">›</span></button>
      <button class=\"lrHubCard\" type=\"button\" data-lr-setup-pane=\"clients\"><span class=\"lrHubIcon\">${icon('user','◎',20)}</span><span><b>Clients</b><span class=\"lrHubMeta\">ABA-style client profiles and service locations.</span></span><span class=\"lrHubChevron\">›</span></button>
      <button class=\"lrHubCard\" type=\"button\" data-lr-setup-pane=\"tasks\"><span class=\"lrHubIcon\">${icon('check','✓',20)}</span><span><b>Personal Tasks</b><span class=\"lrHubMeta\">Flexible tasks and errands to fit into open gaps.</span></span><span class=\"lrHubChevron\">›</span></button>
      <button class=\"lrHubCard\" type=\"button\" data-lr-setup-pane=\"connections\"><span class=\"lrHubIcon\">${icon('route','↗',20)}</span><span><b>Connections</b><span class=\"lrHubMeta\">Connect calendars and choose your navigation app.</span></span><span class=\"lrHubChevron\">›</span></button>
"""
if new_setup not in text:
    if old_setup not in text:
        raise SystemExit("setup hub icon marker missing")
    text = text.replace(old_setup, new_setup, 1)

old_tools = """  const toolDefinitions = [
    { key: 'timer', label: 'Visual Timer', glyph: '◴', meta: 'A large, session-friendly visual countdown.', targets: ['visualTimerTool'] },
    { key: 'visuals', label: 'Visuals Generator', glyph: '▧', meta: 'Create visual supports, First/Then boards, and choice boards.', targets: ['visualIconTool','choiceBoardTool','firstThenTool'] },
    { key: 'docs', label: 'Documentation Tools', glyph: '▤', meta: 'Quick notes, session planning, and documentation helpers.', targets: ['quickNotesTool','sessionPlanTool'] }
  ];
"""
new_tools = """  const toolDefinitions = [
    { key: 'timer', label: 'Visual Timer', iconName: 'clock', glyph: '◴', meta: 'A large, session-friendly visual countdown.', targets: ['visualTimerTool'] },
    { key: 'visuals', label: 'Visuals Generator', iconName: 'sparkles', glyph: '▧', meta: 'Create visual supports, First/Then boards, and choice boards.', targets: ['visualIconTool','choiceBoardTool','firstThenTool'] },
    { key: 'docs', label: 'Documentation Tools', iconName: 'briefcase', glyph: '▤', meta: 'Quick notes, session planning, and documentation helpers.', targets: ['quickNotesTool','sessionPlanTool'] }
  ];
"""
if new_tools not in text:
    if old_tools not in text:
        raise SystemExit("session tools icon definitions marker missing")
    text = text.replace(old_tools, new_tools, 1)

old_hub = """      hub.innerHTML = toolDefinitions.map(tool => `<button class=\"lrHubCard\" type=\"button\" data-lr-tool-group=\"${tool.key}\"><span class=\"lrHubIcon\">${tool.glyph}</span><span><b>${tool.label}</b><span class=\"lrHubMeta\">${tool.meta}</span></span><span class=\"lrHubChevron\">›</span></button>`).join('');
"""
new_hub = """      hub.innerHTML = toolDefinitions.map(tool => `<button class=\"lrHubCard\" type=\"button\" data-lr-tool-group=\"${tool.key}\"><span class=\"lrHubIcon\">${icon(tool.iconName,tool.glyph,20)}</span><span><b>${tool.label}</b><span class=\"lrHubMeta\">${tool.meta}</span></span><span class=\"lrHubChevron\">›</span></button>`).join('');
"""
if new_hub not in text:
    if old_hub not in text:
        raise SystemExit("session tools hub icon renderer marker missing")
    text = text.replace(old_hub, new_hub, 1)

css_old = ".lrHubIcon{width:38px;height:38px;border-radius:13px;display:grid;place-items:center;background:color-mix(in srgb,var(--blue) 8%,var(--panel2));border:1px solid var(--line);color:var(--gold);font-size:20px}"
css_new = css_old + ".lrHubIcon .lrIcon{width:20px!important;height:20px!important;stroke-width:1.9}.tabs .tab .lrIcon{width:19px!important;height:19px!important;stroke-width:1.9}"
if css_new not in text:
    if css_old not in text:
        raise SystemExit("hub icon CSS marker missing")
    text = text.replace(css_old, css_new, 1)

TOOLBAR.write_text(text)

verified = TOOLBAR.read_text()
for marker in [
    "icon('briefcase', '◈', 19)",
    "icon('package', '▤', 19)",
    "icon('settings', '◎', 19)",
    "icon('pin','⌂',20)",
    "iconName: 'sparkles'",
    "icon(tool.iconName,tool.glyph,20)",
]:
    if marker not in verified:
        raise SystemExit(f"cosmetic icon verification failed: missing {marker}")
if "🧩" in verified:
    raise SystemExit("cosmetic icon verification failed: emoji puzzle icon remains")

print("v0.4.0 cosmetic pass: top navigation and major hub buttons use consistent crisp vector icons.")
