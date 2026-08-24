// LifeRoute first-visit welcome.
(() => {
  const SEEN_KEY = "liferoute_welcome_seen_v1";

  const shouldForce = () => {
    try {
      return new URLSearchParams(location.search).get("welcome") === "1";
    } catch (_) {
      return false;
    }
  };

  const hasSeen = () => {
    try {
      return localStorage.getItem(SEEN_KEY) === "1";
    } catch (_) {
      return false;
    }
  };

  const markSeen = () => {
    try { localStorage.setItem(SEEN_KEY, "1"); } catch (_) {}
  };

  const addStyles = () => {
    if (document.getElementById("lifeRouteWelcomeStyles")) return;
    const style = document.createElement("style");
    style.id = "lifeRouteWelcomeStyles";
    style.textContent = `
      .lrWelcomeOverlay{position:fixed;inset:0;z-index:20000;display:none;align-items:center;justify-content:center;padding:calc(18px + env(safe-area-inset-top)) 16px calc(18px + env(safe-area-inset-bottom));background:rgba(4,10,20,.72);backdrop-filter:blur(18px) saturate(120%);-webkit-backdrop-filter:blur(18px) saturate(120%)}
      .lrWelcomeOverlay.show{display:flex}
      .lrWelcomeCard{width:min(92vw,520px);max-height:min(86vh,760px);overflow:auto;border-radius:28px;padding:24px;background:linear-gradient(155deg,color-mix(in srgb,var(--panel) 96%,#0a1730),color-mix(in srgb,var(--panel2) 94%,#07111f));border:1px solid color-mix(in srgb,var(--gold) 32%,var(--line));box-shadow:0 34px 110px rgba(0,0,0,.46);color:var(--text)}
      .lrWelcomeBrand{display:flex;align-items:center;gap:12px;margin-bottom:14px}.lrWelcomeMark{width:48px;height:48px;border-radius:15px;display:grid;place-items:center;font-weight:1000;font-size:18px;letter-spacing:-1px;color:#0c1728;background:linear-gradient(145deg,#f5dc91,#d8ae4f);box-shadow:0 12px 28px rgba(218,177,80,.22)}
      .lrWelcomeEyebrow{font-size:9px;font-weight:950;letter-spacing:.15em;text-transform:uppercase;color:var(--gold);margin-bottom:2px}.lrWelcomeTitle{font-size:clamp(25px,6vw,34px);line-height:1.03;font-weight:950;letter-spacing:-1.1px}.lrWelcomeIntro{font-size:13px;line-height:1.55;color:var(--muted);margin:4px 0 17px}
      .lrWelcomeGrid{display:grid;grid-template-columns:1fr 1fr;gap:9px}.lrWelcomeItem{border:1px solid color-mix(in srgb,var(--line) 78%,transparent);border-radius:17px;padding:13px;background:color-mix(in srgb,var(--panel2) 78%,transparent)}.lrWelcomeIcon{font-size:20px;line-height:1;margin-bottom:8px}.lrWelcomeItem b{display:block;font-size:12px;margin-bottom:3px}.lrWelcomeItem span{display:block;font-size:10px;line-height:1.42;color:var(--muted)}
      .lrWelcomeNote{margin:14px 0 16px;padding:10px 12px;border-radius:13px;background:color-mix(in srgb,var(--blue) 8%,var(--panel2));border:1px solid color-mix(in srgb,var(--blue) 22%,var(--line));font-size:9px;line-height:1.45;color:var(--muted)}
      .lrWelcomeActions{display:grid;grid-template-columns:1fr;gap:8px}.lrWelcomeStart{border:0;border-radius:14px;padding:13px 16px;font-weight:950;font-size:13px;color:#111820;background:linear-gradient(145deg,#f5dc91,#dfb858);box-shadow:0 12px 30px rgba(218,177,80,.18)}.lrWelcomeAgain{border:0;background:transparent;color:var(--muted);font-size:9px;padding:4px 8px}
      @media(max-width:520px){.lrWelcomeCard{padding:20px;border-radius:24px}.lrWelcomeGrid{grid-template-columns:1fr}.lrWelcomeItem{display:grid;grid-template-columns:30px 1fr;column-gap:8px;align-items:start}.lrWelcomeIcon{grid-row:1/3;margin:1px 0 0}.lrWelcomeItem b{margin:0 0 2px}}
    `;
    document.head.appendChild(style);
  };

  const ensureModal = () => {
    let overlay = document.getElementById("lifeRouteWelcome");
    if (overlay) return overlay;

    addStyles();
    overlay = document.createElement("div");
    overlay.id = "lifeRouteWelcome";
    overlay.className = "lrWelcomeOverlay";
    overlay.setAttribute("role", "dialog");
    overlay.setAttribute("aria-modal", "true");
    overlay.setAttribute("aria-labelledby", "lifeRouteWelcomeTitle");
    overlay.innerHTML = `
      <div class="lrWelcomeCard">
        <div class="lrWelcomeBrand">
          <div class="lrWelcomeMark">LR</div>
          <div>
            <div class="lrWelcomeEyebrow">Welcome to LifeRoute</div>
            <div class="lrWelcomeTitle" id="lifeRouteWelcomeTitle">Plan the day around real life.</div>
          </div>
        </div>
        <div class="lrWelcomeIntro">LifeRoute brings your schedule, travel time, open gaps, errands, saved places, and visual-support tools into one streamlined daily planner.</div>
        <div class="lrWelcomeGrid">
          <div class="lrWelcomeItem"><div class="lrWelcomeIcon">🗓️</div><b>See your day clearly</b><span>View calendar events, commute time, and usable gaps in one place.</span></div>
          <div class="lrWelcomeItem"><div class="lrWelcomeIcon">✨</div><b>Make gaps useful</b><span>Find errands, saved places, and stops that can realistically fit between events.</span></div>
          <div class="lrWelcomeItem"><div class="lrWelcomeIcon">🧭</div><b>Plan smarter routes</b><span>Compare travel options and build a practical route through the day.</span></div>
          <div class="lrWelcomeItem"><div class="lrWelcomeIcon">▦</div><b>Use visual supports</b><span>Create First / Then boards, visual timers, visual cards, and choice boards.</span></div>
        </div>
        <div class="lrWelcomeNote">Web preview: the interface and web tools are interactive. Live Apple Calendar, GPS, notifications, and MapKit actions require the iPhone build.</div>
        <div class="lrWelcomeActions">
          <button class="lrWelcomeStart" type="button" id="lifeRouteWelcomeStart">Start exploring</button>
          <button class="lrWelcomeAgain" type="button" id="lifeRouteWelcomeAgain">Show this welcome again next visit</button>
        </div>
      </div>
    `;
    document.body.appendChild(overlay);

    overlay.querySelector("#lifeRouteWelcomeStart")?.addEventListener("click", () => {
      markSeen();
      overlay.classList.remove("show");
    });

    overlay.querySelector("#lifeRouteWelcomeAgain")?.addEventListener("click", () => {
      try { localStorage.removeItem(SEEN_KEY); } catch (_) {}
      overlay.classList.remove("show");
    });

    overlay.addEventListener("click", event => {
      if (event.target === overlay) {
        markSeen();
        overlay.classList.remove("show");
      }
    });

    document.addEventListener("keydown", event => {
      if (event.key === "Escape" && overlay.classList.contains("show")) {
        markSeen();
        overlay.classList.remove("show");
      }
    });

    return overlay;
  };

  const showWelcome = () => {
    const overlay = ensureModal();
    requestAnimationFrame(() => overlay.classList.add("show"));
  };

  const start = () => {
    if (shouldForce() || !hasSeen()) {
      setTimeout(showWelcome, 220);
    }
  };

  window.LifeRouteWelcome = {
    show: showWelcome,
    reset: () => { try { localStorage.removeItem(SEEN_KEY); } catch (_) {} },
    version: "1.0.0"
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once:true });
  else start();
})();
