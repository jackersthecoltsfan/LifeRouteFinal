from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
WELCOME_PATH = WEB / "welcome.js"
PBX = ROOT / "LifeRoute.xcodeproj" / "project.pbxproj"

# First-run startup is deliberately cheap. The previous welcome layer observed the
# whole document and scheduled work on every mutation while the rest of LifeRoute
# was still mounting. In WKWebView that could starve taps on the welcome buttons.
WELCOME = r'''// LifeRoute welcome + guided walkthrough v2.1 — v0.4.0 startup-safe.
// The first-run overlay is intentionally static and observer-free. Tour geometry
// is created only after the user explicitly asks to start the walkthrough.
(() => {
  if (window.__lifeRouteWelcomeTourV2Loaded) return;
  window.__lifeRouteWelcomeTourV2Loaded = true;
  window.__lifeRouteWelcomePerformanceV040 = true;

  const SEEN_KEY = 'liferoute_welcome_tour_v2_seen';
  const WELCOME_RETRY_DELAYS = [0, 500, 1500, 3500];
  let tourIndex = 0;
  let tourActive = false;
  let repositionTimer = 0;
  let welcomeTimer = 0;
  let welcomeScheduled = false;

  const seen = () => { try { return localStorage.getItem(SEEN_KEY) === '1'; } catch (_) { return false; } };
  const markSeen = () => { try { localStorage.setItem(SEEN_KEY, '1'); } catch (_) {} };
  const haptic = style => window.LifeRouteLiquidInteractionV4?.haptic?.(style || 'selection');
  const setWelcomeActive = active => {
    if (active) document.documentElement.dataset.lifeRouteWelcomeActive = '1';
    else delete document.documentElement.dataset.lifeRouteWelcomeActive;
  };

  const style = document.createElement('style');
  style.id = 'lifeRouteWelcomeTourStyles';
  style.textContent = `
    html[data-life-route-welcome-active="1"] .app{visibility:hidden!important}
    html[data-life-route-welcome-active="1"] #lifeRouteDelightBackdrop,
    html[data-life-route-welcome-active="1"] #webPreviewBadge{display:none!important}
    .lrWelcomeOverlay{position:fixed;inset:0;z-index:47000;display:none;align-items:center;justify-content:center;padding:calc(18px + env(safe-area-inset-top)) 16px calc(18px + env(safe-area-inset-bottom));background:rgba(3,8,17,.94);pointer-events:auto;contain:layout paint style}
    .lrWelcomeOverlay.show{display:flex}
    .lrWelcomeCard{width:min(92vw,540px);border-radius:30px;padding:22px;background:linear-gradient(155deg,color-mix(in srgb,var(--panel) 96%,#0a1730),color-mix(in srgb,var(--panel2) 94%,#07111f));border:1px solid color-mix(in srgb,var(--gold) 30%,var(--line));box-shadow:inset 0 1px rgba(255,255,255,.07),0 20px 54px rgba(0,0,0,.32);color:var(--text);overflow:hidden;position:relative;touch-action:manipulation}
    .lrWelcomeCard::before{content:"";position:absolute;width:190px;height:190px;right:-100px;top:-100px;border-radius:50%;background:radial-gradient(circle,color-mix(in srgb,var(--blue) 16%,transparent),transparent 70%);pointer-events:none}
    .lrWelcomeBrand{display:flex;align-items:center;gap:12px;position:relative}.lrWelcomeMark{width:50px;height:50px;border-radius:16px;display:grid;place-items:center;font-weight:1000;font-size:18px;letter-spacing:-1px;color:#0c1728;background:linear-gradient(145deg,#f5dc91,#d8ae4f);box-shadow:0 8px 20px rgba(218,177,80,.18)}.lrWelcomeEyebrow{font-size:8.5px;font-weight:950;letter-spacing:.15em;text-transform:uppercase;color:var(--gold)}.lrWelcomeTitle{font-size:clamp(27px,6vw,36px);line-height:1.02;font-weight:950;letter-spacing:-1.2px;margin-top:2px}.lrWelcomeIntro{font-size:12px;line-height:1.5;color:var(--muted);margin:13px 0}
    .lrWelcomeRoute{height:78px;border-radius:18px;background:linear-gradient(145deg,color-mix(in srgb,var(--blue) 8%,var(--panel2)),color-mix(in srgb,var(--gold) 5%,var(--panel2)));border:1px solid var(--line);position:relative;overflow:hidden;margin:11px 0 15px}.lrWelcomeRoutePath{position:absolute;left:8%;right:8%;top:50%;height:2px;background:linear-gradient(90deg,var(--blue),var(--gold));transform:translateY(-50%);opacity:.62}.lrWelcomeRoutePath::before,.lrWelcomeRoutePath::after{content:"";position:absolute;top:50%;width:11px;height:11px;border-radius:50%;transform:translateY(-50%);background:var(--gold)}.lrWelcomeRoutePath::before{left:0}.lrWelcomeRoutePath::after{right:0}.lrWelcomeTraveler{position:absolute;top:50%;left:50%;width:38px;height:38px;margin:-19px 0 0 -19px;border-radius:14px;display:grid;place-items:center;color:#07111f;font-size:17px;background:linear-gradient(145deg,var(--blue),#dff0ff);box-shadow:0 7px 18px rgba(0,0,0,.16)}
    .lrWelcomeGrid{display:grid;grid-template-columns:repeat(4,1fr);gap:6px;margin-bottom:14px}.lrWelcomeItem{padding:9px 6px;border-radius:13px;background:color-mix(in srgb,var(--panel2) 74%,transparent);border:1px solid var(--line);text-align:center}.lrWelcomeItem b{display:block;font-size:9px}.lrWelcomeIcon{font-size:17px;margin-bottom:4px}.lrWelcomeActions{display:grid;grid-template-columns:1.3fr 1fr;gap:7px}.lrWelcomeStart,.lrWelcomeSkip{min-height:46px!important;border-radius:14px!important;touch-action:manipulation!important}.lrWelcomeStart{background:linear-gradient(145deg,#f5dc91,#dfb858)!important;color:#111820!important}.lrWelcomeSkip{background:color-mix(in srgb,var(--panel2) 82%,#081426)!important;color:var(--text)!important;border:1px solid var(--line)!important}
    .lrTourLayer{position:fixed;inset:0;z-index:46950;pointer-events:none;display:none}.lrTourLayer.show{display:block}.lrTourSpotlight{position:fixed;border-radius:18px;border:2px solid color-mix(in srgb,var(--gold) 78%,white);box-shadow:0 0 0 9999px rgba(3,8,17,.64),0 0 0 5px color-mix(in srgb,var(--gold) 12%,transparent),0 12px 38px rgba(0,0,0,.24);transition:left .28s cubic-bezier(.2,.82,.2,1),top .28s cubic-bezier(.2,.82,.2,1),width .28s cubic-bezier(.2,.82,.2,1),height .28s cubic-bezier(.2,.82,.2,1);pointer-events:none}.lrTourGuide{position:fixed;width:38px;height:38px;border-radius:14px;display:grid;place-items:center;background:linear-gradient(145deg,var(--blue),var(--gold));color:#07111f;font-size:16px;font-weight:1000;box-shadow:0 10px 26px rgba(0,0,0,.24);transition:left .28s cubic-bezier(.2,.82,.2,1),top .28s cubic-bezier(.2,.82,.2,1);z-index:2}.lrTourCoach{position:fixed;left:12px;right:12px;bottom:calc(12px + env(safe-area-inset-bottom));max-width:500px;margin:auto;padding:14px;border-radius:20px;background:linear-gradient(155deg,color-mix(in srgb,var(--panel) 98%,#07111f),color-mix(in srgb,var(--panel2) 96%,#07111f));border:1px solid color-mix(in srgb,var(--gold) 27%,var(--line));box-shadow:inset 0 1px rgba(255,255,255,.07),0 20px 60px rgba(0,0,0,.38);pointer-events:auto}.lrTourStep{font-size:8px;font-weight:950;letter-spacing:.12em;color:var(--gold);text-transform:uppercase}.lrTourCoach h3{margin:3px 0 5px;font-size:18px}.lrTourCoach p{margin:0;color:var(--muted);font-size:10px;line-height:1.45}.lrTourActions{display:grid;grid-template-columns:auto 1fr auto;gap:7px;margin-top:11px}.lrTourActions button{min-height:40px!important;touch-action:manipulation!important}.lrTourDots{display:flex;justify-content:center;align-items:center;gap:4px}.lrTourDots span{width:5px;height:5px;border-radius:50%;background:var(--line)}.lrTourDots span.active{width:14px;border-radius:99px;background:var(--gold)}
    .lrReplayTourRow{display:flex;align-items:center;justify-content:space-between;gap:10px}.lrReplayTourRow .meta{max-width:260px}
    @media(max-width:520px){.lrWelcomeCard{padding:19px;border-radius:25px}.lrWelcomeGrid{grid-template-columns:1fr 1fr}.lrWelcomeActions{grid-template-columns:1fr}.lrWelcomeRoute{height:68px}.lrTourSpotlight{border-radius:15px}.lrTourCoach{border-radius:18px}.lrTourGuide{width:34px;height:34px;border-radius:12px}}
    @media(prefers-reduced-motion:reduce){.lrTourSpotlight,.lrTourGuide{transition:none!important}}
  `;
  document.head.appendChild(style);

  const hideWelcome = () => {
    clearTimeout(welcomeTimer);
    welcomeTimer = 0;
    welcomeScheduled = false;
    document.getElementById('lifeRouteWelcome')?.classList.remove('show');
    setWelcomeActive(false);
  };

  const ensureWelcome = () => {
    let overlay = document.getElementById('lifeRouteWelcome');
    if (overlay) return overlay;
    overlay = document.createElement('div');
    overlay.id = 'lifeRouteWelcome';
    overlay.className = 'lrWelcomeOverlay';
    overlay.setAttribute('role', 'dialog');
    overlay.setAttribute('aria-modal', 'true');
    overlay.innerHTML = `<div class="lrWelcomeCard"><div class="lrWelcomeBrand"><div class="lrWelcomeMark">LR</div><div><div class="lrWelcomeEyebrow">Welcome to LifeRoute</div><div class="lrWelcomeTitle">Make the day flow.</div></div></div><div class="lrWelcomeIntro">See where you are going, when to leave, what can fit into the gaps, and the tools you need during the day — all in one route.</div><div class="lrWelcomeRoute"><div class="lrWelcomeRoutePath"></div><div class="lrWelcomeTraveler">◎</div></div><div class="lrWelcomeGrid"><div class="lrWelcomeItem"><div class="lrWelcomeIcon">◫</div><b>Schedule</b></div><div class="lrWelcomeItem"><div class="lrWelcomeIcon">◈</div><b>Tools</b></div><div class="lrWelcomeItem"><div class="lrWelcomeIcon">▤</div><b>Resources</b></div><div class="lrWelcomeItem"><div class="lrWelcomeIcon">◎</div><b>Setup</b></div></div><div class="lrWelcomeActions"><button class="lrWelcomeStart" type="button" id="lrWelcomeTourStart">Show me around</button><button class="lrWelcomeSkip" type="button" id="lrWelcomeExplore">Explore on my own</button></div></div>`;
    document.body.appendChild(overlay);
    overlay.querySelector('#lrWelcomeTourStart').onclick = () => { hideWelcome(); startTour(); };
    overlay.querySelector('#lrWelcomeExplore').onclick = () => { markSeen(); hideWelcome(); haptic('selection'); };
    return overlay;
  };

  const steps = [
    { title:'Your day starts here', copy:'Schedule is the command center: appointments, route timing, open gaps, and what comes next.', prepare:()=>document.querySelector('.tabs .tab[data-view="today"]')?.click(), target:()=>document.querySelector('.tabs .tab[data-view="today"]') },
    { title:'See the day in sequence', copy:'The timeline keeps commitments and travel context together so the next move is obvious.', target:()=>document.querySelector('#today .lrDayPager,#today .hero,#timeline') },
    { title:'Session tools stay close', copy:'Visual supports, timers, documentation helpers, and the Visual Schedule live under Session Tools.', prepare:()=>document.querySelector('.tabs .tab[data-view="tools"]')?.click(), target:()=>document.querySelector('.tabs .tab[data-view="tools"]') },
    { title:'Visual tools in one place', copy:'Open Visuals for First/Then, choice boards, visual icons, and the Visual Schedule sequence builder.', prepare:()=>document.querySelector('#lifeRouteToolTabsV1 .lrContextTab[data-key="visuals"]')?.click(), target:()=>document.querySelector('#lifeRouteToolTabsV1 .lrContextTab[data-key="visuals"],#visualScheduleTool') },
    { title:'Find work resources fast', copy:'Resources keeps common work portals together with search and live suggestions.', prepare:()=>document.querySelector('.tabs .tab[data-view="resources"]')?.click(), target:()=>document.querySelector('.tabs .tab[data-view="resources"]') },
    { title:'Search beyond the saved list', copy:'Start typing a portal, service, or resource to find what you need.', target:()=>document.getElementById('resourceSearch') || document.querySelector('#resources .resourceHero') },
    { title:'Make LifeRoute yours', copy:'Setup holds Home, live location, saved places, clients, tasks, and service connections.', prepare:()=>document.querySelector('.tabs .tab[data-view="setup"]')?.click(), target:()=>document.querySelector('.tabs .tab[data-view="setup"]') },
    { title:'Themes and preferences', copy:'The Settings button opens the categorized theme browser and app preferences.', target:()=>document.getElementById('lifeRouteSettingsButton') || document.querySelector('.lrSettingsButton') }
  ];

  const ensureTour = () => {
    let layer = document.getElementById('lifeRouteTourLayer');
    if (layer) return layer;
    layer = document.createElement('div');
    layer.id = 'lifeRouteTourLayer';
    layer.className = 'lrTourLayer';
    layer.innerHTML = `<div class="lrTourSpotlight" aria-hidden="true"></div><div class="lrTourGuide" aria-hidden="true">◎</div><div class="lrTourCoach"><div class="lrTourStep"></div><h3></h3><p></p><div class="lrTourActions"><button class="secondary" type="button" data-lr-tour-skip>Skip</button><div class="lrTourDots"></div><button class="goldButton" type="button" data-lr-tour-next>Next</button></div></div>`;
    document.body.appendChild(layer);
    layer.querySelector('[data-lr-tour-skip]').onclick = finishTour;
    layer.querySelector('[data-lr-tour-next]').onclick = () => {
      if (tourIndex >= steps.length - 1) finishTour();
      else { tourIndex += 1; showTourStep(); }
    };
    return layer;
  };

  const positionTour = target => {
    const layer = ensureTour();
    const spot = layer.querySelector('.lrTourSpotlight');
    const guide = layer.querySelector('.lrTourGuide');
    if (!(target instanceof HTMLElement) || !target.isConnected) {
      spot.style.left = '12px'; spot.style.top = '88px'; spot.style.width = `${Math.max(100, window.innerWidth - 24)}px`; spot.style.height = '64px';
      guide.style.left = '22px'; guide.style.top = '98px'; return;
    }
    const rect = target.getBoundingClientRect();
    const pad = 6;
    const left = Math.max(6, rect.left - pad);
    const top = Math.max(6, rect.top - pad);
    const width = Math.min(window.innerWidth - left - 6, rect.width + pad * 2);
    const height = Math.min(window.innerHeight - top - 6, rect.height + pad * 2);
    spot.style.left = `${left}px`; spot.style.top = `${top}px`; spot.style.width = `${Math.max(42, width)}px`; spot.style.height = `${Math.max(42, height)}px`;
    guide.style.left = `${Math.max(8, Math.min(window.innerWidth - 46, left + width - 18))}px`;
    guide.style.top = `${Math.max(8, Math.min(window.innerHeight - 46, top - 16))}px`;
  };

  const showTourStep = () => {
    if (!tourActive) return;
    const step = steps[tourIndex];
    step.prepare?.();
    const layer = ensureTour();
    layer.classList.add('show');
    layer.querySelector('.lrTourStep').textContent = `Step ${tourIndex + 1} of ${steps.length}`;
    layer.querySelector('h3').textContent = step.title;
    layer.querySelector('p').textContent = step.copy;
    layer.querySelector('[data-lr-tour-next]').textContent = tourIndex === steps.length - 1 ? 'Finish' : 'Next';
    layer.querySelector('.lrTourDots').innerHTML = steps.map((_, index) => `<span class="${index === tourIndex ? 'active' : ''}"></span>`).join('');
    clearTimeout(repositionTimer);
    repositionTimer = setTimeout(() => positionTour(step.target?.()), 120);
    haptic(tourIndex ? 'selection' : 'rigid');
  };

  function startTour() {
    hideWelcome();
    tourIndex = 0;
    tourActive = true;
    showTourStep();
  }

  function finishTour() {
    tourActive = false;
    markSeen();
    document.getElementById('lifeRouteTourLayer')?.classList.remove('show');
    haptic('success');
  }

  const showWelcome = (force = false) => {
    if (!force && seen()) return;
    const overlay = ensureWelcome();
    setWelcomeActive(true);
    overlay.classList.add('show');
  };

  const installReplay = () => {
    const sheet = document.querySelector('#lifeRouteSettingsOverlay .lrSettingsSheet');
    if (!sheet || document.getElementById('lrReplayTourSection')) return false;
    const section = document.createElement('div');
    section.id = 'lrReplayTourSection';
    section.className = 'lrSettingsSection';
    section.innerHTML = `<div class="lrReplayTourRow"><div><div class="title">LifeRoute walkthrough</div><div class="meta">Replay the guided tour of Schedule, tools, Resources, Setup, and themes.</div></div><button class="secondary" type="button" id="lrReplayTourButton">Replay</button></div>`;
    sheet.appendChild(section);
    section.querySelector('#lrReplayTourButton').onclick = () => {
      document.getElementById('lifeRouteSettingsOverlay')?.classList.remove('show');
      startTour();
    };
    return true;
  };

  const maybeShow = () => {
    if (seen() || welcomeScheduled) return;
    welcomeScheduled = true;
    welcomeTimer = setTimeout(() => {
      welcomeScheduled = false;
      welcomeTimer = 0;
      showWelcome(false);
    }, 160);
  };

  document.addEventListener('liferoute-auth-unlocked', maybeShow, { once: true });
  document.addEventListener('liferoute-settings-opened', installReplay);
  document.addEventListener('click', event => {
    if (event.target?.closest?.('#lifeRouteSettingsButton,.lrSettingsButton')) setTimeout(installReplay, 0);
  }, true);
  window.addEventListener('resize', () => {
    if (tourActive) positionTour(steps[tourIndex]?.target?.());
  }, { passive: true });

  const start = () => {
    ensureWelcome();
    installReplay();
    setTimeout(maybeShow, 220);
    WELCOME_RETRY_DELAYS.slice(1).forEach(delay => setTimeout(installReplay, delay));
  };

  window.LifeRouteWelcome = {
    show: () => showWelcome(true),
    hide: hideWelcome,
    tour: startTour,
    reset: () => { try { localStorage.removeItem(SEEN_KEY); } catch (_) {} showWelcome(true); },
    version: '2.1.0'
  };

  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once: true });
  else start();
})();
'''

WELCOME_PATH.write_text(WELCOME, encoding="utf-8")

# Apple/TestFlight marketing version: build number remains the GitHub run number,
# but the user-facing version must be 0.4.0 for both the app and Live Activity.
pbx = PBX.read_text(encoding="utf-8")
pbx, version_count = re.subn(
    r"MARKETING_VERSION = [0-9]+(?:\.[0-9]+){1,2};",
    "MARKETING_VERSION = 0.4.0;",
    pbx,
)
if version_count < 2:
    raise SystemExit(f"Expected at least two MARKETING_VERSION settings, found {version_count}")
PBX.write_text(pbx, encoding="utf-8")

print("v0.4.0 startup freeze fix applied: observer-free welcome, cheap static overlay, deferred tour, and marketing version 0.4.0.")
