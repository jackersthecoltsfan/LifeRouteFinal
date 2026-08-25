from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{label}: source marker missing")
    path.write_text(text.replace(old, new, 1))


def replace_between(path: Path, start: str, end: str, replacement: str, label: str) -> None:
    text = path.read_text()
    start_i = text.find(start)
    if start_i < 0:
        if replacement in text:
            return
        raise SystemExit(f"{label}: start marker missing")
    end_i = text.find(end, start_i)
    if end_i < 0:
        raise SystemExit(f"{label}: end marker missing")
    path.write_text(text[:start_i] + replacement + text[end_i:])


# ---------------------------------------------------------------------------
# 1) Settings themes: Metallic Wave uses the exact same preview-card grammar
#    as Dynamic / Fluid instead of the old full-width text rows.
# ---------------------------------------------------------------------------
catalog = WEB / "theme-catalog-v3.js"
replace_once(
    catalog,
    '        grid.className = "lrMetallicThemeGrid";',
    '        grid.className = "lrThemeGrid lrMetallicThemeGrid";',
    "metallic theme grid class",
)
replace_once(
    catalog,
    '        grid.innerHTML = METALLIC_ITEMS.map(([key,name]) => `<button type="button" class="lrThemeCard lrMetallicThemeCard" data-metallic-key="${key}"><b>${name}</b><span>Metallic Wave</span></button>`).join("");',
    '        grid.innerHTML = METALLIC_ITEMS.map(([key,name]) => `<button type="button" class="lrThemeCard lrMetallicThemeCard" data-metallic-key="${key}"><span class="lrMetallicPreview"></span><span class="lrThemeName">${name}</span></button>`).join("");',
    "metallic theme preview-card markup",
)
old_theme_style = '''  simplifiedStyle.textContent = `.lrMetallicThemeGrid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-top:8px}.lrMetallicThemeCard{min-height:58px;text-align:left;padding:10px 11px;border-radius:13px}.lrMetallicThemeCard b{display:block;font-size:11px}.lrMetallicThemeCard span{display:block;margin-top:3px;font-size:8px;color:var(--muted)}.lrMetallicThemeCard.active{border-color:var(--gold);box-shadow:inset 0 0 0 1px var(--gold),0 8px 24px rgba(0,0,0,.12)}@media(max-width:560px){.lrMetallicThemeGrid{grid-template-columns:1fr}}`;'''
new_theme_style = '''  simplifiedStyle.textContent = `.lrMetallicThemeGrid{margin-top:8px}.lrMetallicThemeCard{position:relative;overflow:hidden}.lrMetallicPreview{position:absolute;inset:0;background:linear-gradient(135deg,var(--mw-a,#0b1730),var(--mw-b,#496b95) 48%,var(--mw-c,#e0bd66));filter:saturate(1.08)}.lrMetallicPreview:before{content:"";position:absolute;inset:-35%;background:linear-gradient(112deg,transparent 24%,rgba(255,255,255,.34) 43%,transparent 58%);transform:rotate(-7deg);filter:blur(7px);opacity:.7}.lrMetallicThemeCard .lrThemeName{color:#fff!important;text-shadow:0 2px 9px rgba(0,0,0,.72)}.lrMetallicThemeCard.active{border-color:var(--gold)!important;box-shadow:inset 0 0 0 2px var(--gold),0 10px 28px rgba(0,0,0,.18)}.lrMetallicThemeCard[data-metallic-key="solar-flare"]{--mw-a:#361007;--mw-b:#b64319;--mw-c:#ffd36d}.lrMetallicThemeCard[data-metallic-key="electric-storm"]{--mw-a:#031426;--mw-b:#1264b4;--mw-c:#79d4ff}.lrMetallicThemeCard[data-metallic-key="ultraviolet"]{--mw-a:#100420;--mw-b:#7028b6;--mw-c:#d46cff}.lrMetallicThemeCard[data-metallic-key="molten-gold"]{--mw-a:#241606;--mw-b:#ad7420;--mw-c:#ffe28a}.lrMetallicThemeCard[data-metallic-key="arctic-pulse"]{--mw-a:#06141b;--mw-b:#5d91ae;--mw-c:#e8f8ff}.lrMetallicThemeCard[data-metallic-key="emerald-tempest"]{--mw-a:#03120d;--mw-b:#157251;--mw-c:#74e0ae}.lrMetallicThemeCard[data-metallic-key="rose-nebula"]{--mw-a:#180810;--mw-b:#9e4868;--mw-c:#f2a9ba}.lrMetallicThemeCard[data-metallic-key="royal-cosmos"]{--mw-a:#09061b;--mw-b:#3f36a2;--mw-c:#d9bc6e}.lrMetallicThemeCard[data-metallic-key="sapphire-tide"]{--mw-a:#031225;--mw-b:#155aa7;--mw-c:#6cb9ff}.lrMetallicThemeCard[data-metallic-key="phantom-silver"]{--mw-a:#090c10;--mw-b:#657283;--mw-c:#eef4fa}`;'''
replace_once(catalog, old_theme_style, new_theme_style, "metallic theme card styling")


# ---------------------------------------------------------------------------
# 2) Generate Day: only localized verified LifeRoute facts go to Foundation
#    Models. No ISO timestamps, saved-place suggestions, cafes, lunches, etc.
#    Route insight is deterministic from LifeRoute/MapKit data.
# ---------------------------------------------------------------------------
assistant = WEB / "ai-assistant-v1.js"
start = '  const dayBrief = async payload => {'
end = '  const routeBrief = async payload => {'
new_day_brief = '''  const dayBrief = async payload => {
    const date = clean(payload?.date || "");
    const events = Array.isArray(payload?.events) ? payload.events.slice(0, 16) : [];
    const prompt = `Return JSON only in exactly this shape: {"dayBrief":"2-3 concise natural-language sentences"}. This is a factual schedule summary, not a suggestion engine. Use ONLY the localized display facts supplied below. Never infer, invent, recommend, or add meals, breaks, cafes, errands, locations, appointments, activities, route facts, or times. Never calculate new times. Never convert time zones. If a fact is not explicitly listed, do not mention it. Keep every client/event label exactly as supplied. Do not expose JSON, field names, ISO timestamps, markdown, or code fences. Selected local date: ${date}. Verified LifeRoute display facts: ${JSON.stringify(events)}.`;
    const result = await request("day-plan", prompt, { timeoutMs: 7500 });
    if (!result?.success || !result.text) return null;
    const parsed = parseJSON(result.text);
    const text = clean(parsed?.dayBrief || "").slice(0, 1000);
    return text ? { text, engine: result.engine || "apple-foundation-model" } : null;
  };

'''
replace_between(assistant, start, end, new_day_brief, "factual localized Day AI prompt")

planning = WEB / "ai-planning-v1.js"
old_compact = '''  const compactEvents = plan => (plan?.blocks || []).map(block => ({
    type: block.type,
    title: block.title,
    start: block.start instanceof Date ? block.start.toISOString() : block.start,
    end: block.end instanceof Date ? block.end.toISOString() : block.end,
    address: block.address || "",
    leaveAt: block.leaveAt instanceof Date ? block.leaveAt.toISOString() : block.leaveAt,
    travelMinutes: Number(block.travelMinutes || block.travelIn || 0),
    travelOut: Number(block.travelOut || 0),
    stopMinutes: block.type === "stop" ? Math.max(0, Math.round((new Date(block.end) - new Date(block.start)) / 60000)) : 0
  }));'''
new_compact = '''  const friendlyTime = value => {
    const date = value instanceof Date ? value : new Date(value);
    if (Number.isNaN(date.getTime())) return "";
    return date.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
  };
  const compactEvents = plan => (plan?.blocks || []).map(block => ({
    type: block.type,
    title: block.title,
    startTime: friendlyTime(block.start),
    endTime: friendlyTime(block.end),
    address: block.address || "",
    leaveTime: block.leaveAt ? friendlyTime(block.leaveAt) : "",
    travelMinutes: Number(block.travelMinutes || block.travelIn || 0),
    travelOutMinutes: Number(block.travelOut || 0),
    stopMinutes: block.type === "stop" ? Math.max(0, Math.round((new Date(block.end) - new Date(block.start)) / 60000)) : 0
  }));'''
replace_once(planning, old_compact, new_compact, "localized Day AI facts")

old_request_region = '''    const places = (Array.isArray(window.places) ? window.places : []).filter(place => place?.member !== "no").slice(0, 14).map(place => ({
      name: place.name,
      type: place.type,
      minMinutes: Number(place.min || 0)
    }));
    const fixed = compactEvents(plan);
    const nextAction = (plan.leaveActions || []).find(action => new Date(action.time).getTime() > Date.now()) || plan.leaveActions?.[0] || null;
    const routeFacts = nextAction ? {
      title: nextAction.title,
      leaveAt: nextAction.time instanceof Date ? nextAction.time.toISOString() : nextAction.time,
      destination: nextAction.destination,
      detail: nextAction.detail,
      plannedStops: fixed.filter(item => item.type === "stop")
    } : { plannedStops: fixed.filter(item => item.type === "stop") };

    const [day, route] = await Promise.all([
      window.LifeRouteAI?.dayBrief?.({ date, events: fixed, places }),
      window.LifeRouteAI?.routeBrief?.(routeFacts)
    ]);
    if (token !== dayRequestToken) return;
'''
new_request_region = '''    const fixed = compactEvents(plan);
    const nextAction = (plan.leaveActions || []).find(action => new Date(action.time).getTime() > Date.now()) || plan.leaveActions?.[0] || null;
    const day = await window.LifeRouteAI?.dayBrief?.({ date, events: fixed });
    if (token !== dayRequestToken) return;
    const deterministicRoute = nextAction
      ? `${String(nextAction.title || "Next departure")} at ${friendlyTime(nextAction.time)}${nextAction.detail ? `. ${String(nextAction.detail)}` : ""}.`
      : "";
'''
replace_once(planning, old_request_region, new_request_region, "deterministic Day route insight")
replace_once(
    planning,
    '    const routeText = scrubDisplayText(route?.text || "");',
    '    const routeText = scrubDisplayText(deterministicRoute);',
    "deterministic route display",
)


# ---------------------------------------------------------------------------
# 3) Prevent WKWebView / iOS input focus from leaving LifeRoute stuck zoomed.
# ---------------------------------------------------------------------------
index = WEB / "index.html"
replace_once(
    index,
    '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">',
    '<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover">',
    "fixed app viewport scale",
)
replace_once(
    index,
    'button,input,select{font:inherit} button{cursor:pointer}',
    'button,input,select,textarea{font:inherit} html,body{touch-action:pan-x pan-y} button{cursor:pointer}',
    "touch zoom prevention",
)
replace_once(
    index,
    '@media(max-width:680px){.metrics{grid-template-columns:1fr 1fr}',
    '@media(max-width:680px){input,select,textarea{font-size:16px!important}.metrics{grid-template-columns:1fr 1fr}',
    "iOS input focus zoom prevention",
)

swift_text = SWIFT.read_text()
if "pinchGestureRecognizer?.isEnabled = false" not in swift_text:
    marker = '        webView.allowsBackForwardNavigationGestures = false\n'
    addition = '''        webView.allowsBackForwardNavigationGestures = false
        webView.scrollView.minimumZoomScale = 1.0
        webView.scrollView.maximumZoomScale = 1.0
        webView.scrollView.zoomScale = 1.0
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
'''
    if marker not in swift_text:
        raise SystemExit("WKWebView zoom guard: makeUIView marker missing")
    swift_text = swift_text.replace(marker, addition, 1)
if "setZoomScale(1.0, animated: false)" not in swift_text:
    marker = '''        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            emitNativeStatus()
'''
    addition = '''        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.scrollView.setZoomScale(1.0, animated: false)
            emitNativeStatus()
'''
    if marker not in swift_text:
        raise SystemExit("WKWebView zoom reset: didFinish marker missing")
    swift_text = swift_text.replace(marker, addition, 1)
SWIFT.write_text(swift_text)


# ---------------------------------------------------------------------------
# 4) Clear Day is finalized earlier in patch_feature_regressions_v2.py. Here we
#    only add date-scoped in-memory clearing helpers and verify the final contract.
# ---------------------------------------------------------------------------
selected = WEB / "selected-gap-routes.js"
marker = '''  window.clearLifeRouteGapRoute = encodedKey => {'''
if "window.clearLifeRouteGapRoutesForDay" not in selected.read_text():
    helper = '''  window.clearLifeRouteGapRoutesForDay = day => {
    const prefix = `${String(day || "").trim()}|`;
    if (!prefix || prefix === "|") return;
    Object.keys(selections).forEach(key => { if (key.startsWith(prefix)) delete selections[key]; });
    save();
    renderNow();
  };

'''
    text = selected.read_text()
    if marker not in text:
        raise SystemExit("selected-gap day clear marker missing")
    selected.write_text(text.replace(marker, helper + marker, 1))

boundary = WEB / "boundary-stop-planner.js"
marker = '''  window.lifeRouteSaveBoundaryStop = saveBoundaryStop;
'''
if "window.clearLifeRouteBoundaryStopsForDay" not in boundary.read_text():
    helper = '''  window.lifeRouteSaveBoundaryStop = saveBoundaryStop;
  window.clearLifeRouteBoundaryStopsForDay = day => {
    const prefix = `${clean(day)}|`;
    if (!clean(day)) return;
    Object.keys(selections).forEach(key => { if (key.startsWith(prefix)) delete selections[key]; });
    save();
    try { window.renderToday?.(); } catch (_) {}
  };
'''
    text = boundary.read_text()
    if marker not in text:
        raise SystemExit("boundary day clear marker missing")
    boundary.write_text(text.replace(marker, helper, 1))

controls_text = (WEB / "day-controls-v5.js").read_text()
required_clear_markers = [
    'clearDateKeys(GENERATED_STORE, day)',
    'clearLifeRouteGapRoutesForDay(day)',
    'clearLifeRouteBoundaryStopsForDay(day)',
    'Cleared this day\'s routes · appointments and saved data kept',
]
if not all(marker in controls_text for marker in required_clear_markers):
    raise SystemExit("route-scoped Clear day: finalized contract missing")
clear_region = controls_text.split("const clearDay = () => {", 1)[1].split("const clearAll = () => {", 1)[0]
if "window.events = window.events.filter" in clear_region or "window.persist?.()" in clear_region:
    raise SystemExit("route-scoped Clear day: unrelated event persistence still present")

print("LifeRoute Day/UI reliability patch applied: matched Metallic cards, factual local-time Day AI, zoom lock prevention, and route-scoped Clear day.")
