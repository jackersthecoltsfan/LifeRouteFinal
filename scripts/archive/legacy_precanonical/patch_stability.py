from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"
INDEX = ROOT / "LifeRoute" / "Web" / "index.html"
THEMES = ROOT / "LifeRoute" / "Web" / "live-themes.js"
REFINED = ROOT / "LifeRoute" / "Web" / "refined-ui-v2.js"
LIVE_DAY = ROOT / "LifeRoute" / "Web" / "live-day.js"
DAY_NAV = ROOT / "LifeRoute" / "Web" / "day-navigation-runtime.js"
BOUNDARY = ROOT / "LifeRoute" / "Web" / "boundary-stop-planner.js"
PHOTO = ROOT / "LifeRoute" / "Web" / "photoreal-nature-web.js"


def write(path: Path, value: str) -> None:
    path.write_text(value, encoding="utf-8")


def replace_once(value: str, old: str, new: str, label: str) -> str:
    if old not in value:
        raise SystemExit(f"Stability patch could not find {label}")
    return value.replace(old, new, 1)


# Native WKWebView: stop iOS rubber-band overscroll from exposing the transparent
# backing view, improve tap delivery, and mark native mode before app JS starts.
swift = SWIFT.read_text(encoding="utf-8")
if "lifeRouteNativeRuntimeBootstrap" not in swift:
    needle = '        configuration.userContentController.add(context.coordinator, name: "lifeRoute")\n'
    bootstrap = needle + '''

        let lifeRouteNativeRuntimeBootstrap = WKUserScript(
            source: """
            window.LifeRouteRuntime = Object.assign({}, window.LifeRouteRuntime || {}, { native: true, platform: 'ios' });
            document.documentElement.dataset.lifeRouteRuntime = 'native';
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        configuration.userContentController.addUserScript(lifeRouteNativeRuntimeBootstrap)
'''
    swift = replace_once(swift, needle, bootstrap, "native runtime bootstrap insertion point")

if "webView.scrollView.bounces = false" not in swift:
    needle = "        webView.scrollView.contentInsetAdjustmentBehavior = .never\n"
    scroll_guard = needle + '''        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.delaysContentTouches = false
        webView.scrollView.canCancelContentTouches = true
        webView.scrollView.isDirectionalLockEnabled = true
        webView.scrollView.scrollsToTop = true
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.allowsLinkPreview = false
'''
    swift = replace_once(swift, needle, scroll_guard, "WKWebView scroll configuration")
write(SWIFT, swift)


# Base actions: the shipped markup referenced refreshCalendars() even though the
# function did not exist. Keep a functional base implementation even before the
# final stability runtime binds the buttons.
index = INDEX.read_text(encoding="utf-8")
if "function refreshCalendars(){" not in index:
    needle = 'function optimizeWeek(){renderWeek();showView("week");weekInsight.scrollIntoView({behavior:"smooth",block:"center"})}'
    replacement = '''function refreshCalendars(){
  const native=!!window.webkit?.messageHandlers?.lifeRoute;
  let requested=false;
  if(native){
    if(prefs?.sources?.apple!==false)requested=postNative({action:"refreshAppleCalendar"})||requested;
    if(prefs?.sources?.google!==false)requested=postNative({action:"refreshGoogleCalendar"})||requested;
  }else{
    const googleRefresh=document.getElementById("googleWebRefresh");
    if(googleRefresh&&!googleRefresh.disabled){googleRefresh.click();requested=true}
  }
  try{if(typeof window.refreshLifeRouteCalendarFeeds==="function"){window.refreshLifeRouteCalendarFeeds();requested=true}}catch(_){}
  setStatus(requested?"Refreshing calendars…":"Calendars are up to date");
  setTimeout(()=>{try{renderAll()}catch(_){}},250);
  return requested
}
function optimizeWeek(){
  renderWeek();
  showView("week");
  setStatus("Showing this week’s best gaps");
  requestAnimationFrame(()=>{try{weekInsight.scrollIntoView({behavior:"smooth",block:"center"})}catch(_){}})
}'''
    index = replace_once(index, needle, replacement, "base bottom action functions")
write(INDEX, index)


# The old metallic backdrop queried the DOM and rewrote four large blurred layers
# at 60 FPS forever. On native it is now static; on web it runs at a restrained
# 20 FPS and caches the layer references.
themes = THEMES.read_text(encoding="utf-8")
if "__lifeRouteThemePerformanceV2" not in themes:
    pattern = re.compile(
        r"  let raf = 0;\n  let startedAt = 0;\n  const animate = timestamp => \{.*?\n  \};\n\n  const mount = \(\) => \{",
        re.S,
    )
    replacement = '''  const __lifeRouteThemePerformanceV2 = true;
  let raf = 0;
  let startedAt = 0;
  let lastFrame = 0;
  let layers = { one:null, two:null, three:null, shine:null };
  const nativeRuntime = !!window.LifeRouteRuntime?.native || !!window.webkit?.messageHandlers?.lifeRoute;
  const reducedMotion = () => window.matchMedia?.("(prefers-reduced-motion: reduce)")?.matches === true;
  const shouldAnimate = () => !nativeRuntime && !reducedMotion();
  const captureLayers = () => {
    layers = {
      one: document.querySelector("#lifeRouteMetalBackdrop .waveOne"),
      two: document.querySelector("#lifeRouteMetalBackdrop .waveTwo"),
      three: document.querySelector("#lifeRouteMetalBackdrop .waveThree"),
      shine: document.querySelector("#lifeRouteMetalBackdrop .specular")
    };
  };
  const applyStatic = () => {
    if (layers.one) layers.one.style.transform = "translate3d(0,0,0) rotate(-6deg) scale(1.08)";
    if (layers.two) layers.two.style.transform = "translate3d(0,0,0) rotate(5deg) scale(1.10)";
    if (layers.three) layers.three.style.transform = "translate3d(0,0,0) rotate(-3deg) scale(1.08)";
    if (layers.shine) layers.shine.style.transform = "translate3d(0,0,0) scale(1.04)";
  };
  const animate = timestamp => {
    if (!shouldAnimate()) { raf = 0; applyStatic(); return; }
    if (!startedAt) startedAt = timestamp;
    if (timestamp - lastFrame < 50) { raf = requestAnimationFrame(animate); return; }
    lastFrame = timestamp;
    const t = (timestamp - startedAt) / 1000;
    const { one, two, three, shine } = layers;

    if (one) one.style.transform = `translate3d(${Math.sin(t*.17)*7}%,${Math.cos(t*.12)*4}%,0) rotate(${(-8 + Math.sin(t*.11)*5).toFixed(2)}deg) scaleX(${(1.07 + Math.sin(t*.09)*.07).toFixed(3)}) scaleY(${(1 + Math.cos(t*.13)*.05).toFixed(3)})`;
    if (two) two.style.transform = `translate3d(${Math.cos(t*.13)*8}%,${Math.sin(t*.15)*5}%,0) rotate(${(6 + Math.cos(t*.10)*6).toFixed(2)}deg) scaleX(${(1.10 + Math.cos(t*.08)*.08).toFixed(3)}) scaleY(${(1 + Math.sin(t*.12)*.06).toFixed(3)})`;
    if (three) three.style.transform = `translate3d(${Math.sin(t*.11+1.8)*7}%,${Math.cos(t*.14+1.2)*4}%,0) rotate(${(-4 + Math.sin(t*.09+1)*5).toFixed(2)}deg) scaleX(${(1.08 + Math.sin(t*.075)*.09).toFixed(3)}) scaleY(${(1 + Math.cos(t*.11)*.05).toFixed(3)})`;
    if (shine) shine.style.transform = `translate3d(${Math.sin(t*.07)*5}%,${Math.cos(t*.06)*4}%,0) rotate(${(Math.sin(t*.05)*3).toFixed(2)}deg) scale(${(1.03 + Math.sin(t*.08)*.04).toFixed(3)})`;

    raf = requestAnimationFrame(animate);
  };

  const mount = () => {'''
    themes, count = pattern.subn(replacement, themes, count=1)
    if count != 1:
        raise SystemExit("Stability patch could not replace metallic animation loop")

    old = '''    if (raf) cancelAnimationFrame(raf);
    startedAt = 0;
    raf = requestAnimationFrame(animate);'''
    new = '''    captureLayers();
    if (raf) cancelAnimationFrame(raf);
    raf = 0;
    startedAt = 0;
    lastFrame = 0;
    if (shouldAnimate()) raf = requestAnimationFrame(animate);
    else applyStatic();'''
    themes = replace_once(themes, old, new, "metallic mount animation start")

    old = '''    } else if (!raf) {
      startedAt = 0;
      raf = requestAnimationFrame(animate);
    }'''
    new = '''    } else if (!raf) {
      startedAt = 0;
      lastFrame = 0;
      if (shouldAnimate()) raf = requestAnimationFrame(animate);
      else applyStatic();
    }'''
    themes = replace_once(themes, old, new, "metallic visibility resume")
write(THEMES, themes)


# Coalesce global DOM mutation polishing into one animation-frame pass instead of
# synchronously walking the UI for every node mutation.
refined = REFINED.read_text(encoding="utf-8")
if "queuePolish" not in refined:
    old = '''  const start = () => {
    polish();
    const observer = new MutationObserver(polish);
    observer.observe(document.body, { childList: true, subtree: true });
    [120, 420, 1000, 2200].forEach(delay => setTimeout(polish, delay));
  };'''
    new = '''  const start = () => {
    let polishQueued = false;
    const queuePolish = () => {
      if (polishQueued) return;
      polishQueued = true;
      requestAnimationFrame(() => {
        polishQueued = false;
        polish();
      });
    };
    polish();
    const observer = new MutationObserver(queuePolish);
    observer.observe(document.body, { childList: true, subtree: true });
    [150, 500, 1200, 2400].forEach(delay => setTimeout(queuePolish, delay));
  };'''
    refined = replace_once(refined, old, new, "refined UI mutation observer")
write(REFINED, refined)


# Do not wake the JS engine every second when Live Day has no visible countdown.
live_day = LIVE_DAY.read_text(encoding="utf-8")
old = "  ticker = setInterval(updateCountdown, 1000);"
new = '''  ticker = setInterval(() => {
    if (document.hidden || !document.querySelector("[data-live-day-countdown]")) return;
    updateCountdown();
  }, 1000);'''
if old in live_day:
    live_day = live_day.replace(old, new, 1)
write(LIVE_DAY, live_day)


# Deterministic core loading means Day controls and boundary planner no longer
# need to poll the DOM dozens of times after launch. Use a few bounded fallbacks.
day_nav = DAY_NAV.read_text(encoding="utf-8")
old = '''  const start = () => {
    bind();
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      if (bind() || attempts > 80) clearInterval(timer);
    }, 100);
  };'''
new = '''  const start = () => {
    if (bind()) return;
    [100, 300, 800].forEach(delay => setTimeout(bind, delay));
  };'''
if old in day_nav:
    day_nav = day_nav.replace(old, new, 1)
write(DAY_NAV, day_nav)

boundary = BOUNDARY.read_text(encoding="utf-8")
old = '''  const start = () => {
    installEventHook();
    decorateBoundaryCards();
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      installEventHook();
      decorateBoundaryCards();
      if (attempts >= 30) clearInterval(timer);
    }, 350);
  };'''
new = '''  const start = () => {
    installEventHook();
    decorateBoundaryCards();
    [180, 550, 1400].forEach(delay => setTimeout(() => {
      installEventHook();
      decorateBoundaryCards();
    }, delay));
  };'''
if old in boundary:
    boundary = boundary.replace(old, new, 1)
write(BOUNDARY, boundary)


# Browser scenery remains high-resolution but avoids downloading oversized 2400px
# photos on phones where they add latency and memory pressure without visible gain.
photo = PHOTO.read_text(encoding="utf-8")
photo = photo.replace('download?force=true&w=2400', 'download?force=true&w=1800')
write(PHOTO, photo)

print("LifeRoute native/web stability patch applied.")
