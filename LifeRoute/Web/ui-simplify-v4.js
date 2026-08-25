// LifeRoute UI simplification pass.
// Keeps the interface concise without changing the underlying route/calendar data.
(() => {
  if (window.__lifeRouteUISimplifyV4Loaded) return;
  window.__lifeRouteUISimplifyV4Loaded = true;

  const style = document.createElement("style");
  style.id = "lifeRouteUISimplifyV4Styles";
  style.textContent = `
    #connectionStatus{display:none!important}
    #today .hero{padding:14px!important}
    #today .hero h2{font-size:20px!important;line-height:1.18!important;margin-bottom:3px!important}
    #today .hero>p{font-size:11px!important;line-height:1.3!important;margin-top:0!important}
    #today .sourceLine{gap:5px!important;margin-top:7px!important}
    #today .sourceLine .chip{font-size:8.5px!important;padding:4px 7px!important}
    .lrRoutingCredit{font-size:7.5px;color:var(--muted);opacity:.72;margin-top:5px}
    #liveDayControls{gap:6px!important;margin-top:9px!important}
    #liveDayControls button{min-height:38px!important;padding:8px 11px!important;font-size:10px!important}
    .lrThemeCard{position:relative!important}
    .lrThemeCard.active:after,.lrThemeCard[aria-pressed="true"]:after{content:"✓";position:absolute;right:8px;top:8px;width:22px;height:22px;display:grid;place-items:center;border-radius:999px;background:var(--gold);color:#07111f;font-size:13px;font-weight:1000;box-shadow:0 4px 14px rgba(0,0,0,.28);z-index:7}
    .lrThemeSelectedMark{display:inline-grid;place-items:center;width:19px;height:19px;margin-left:7px;border-radius:999px;background:var(--gold);color:#07111f;font-size:11px;font-weight:1000;vertical-align:middle}
    @media(max-width:520px){#today .hero{padding:13px!important}.lrThemeCard.active:after,.lrThemeCard[aria-pressed="true"]:after{right:6px;top:6px;width:20px;height:20px}}
  `;
  document.head.appendChild(style);

  const setTextIfDifferent = (node, text) => {
    if (node && node.textContent !== text) node.textContent = text;
  };

  const simplifyHero = () => {
    const hero = document.querySelector("#today .hero");
    if (!hero) return;
    const title = hero.querySelector("h2");
    const paragraph = hero.querySelector(":scope > p");
    const raw = String(title?.textContent || "");
    const match = raw.match(/(\d+)\s+commitment/i);
    if (match) {
      const count = Number(match[1]);
      setTextIfDifferent(title, `${count} commitment${count === 1 ? "" : "s"}`);
    } else if (/clear day|no timed events/i.test(raw)) {
      setTextIfDifferent(title, "No commitments");
    }
    if (paragraph) setTextIfDifferent(paragraph, "Appointments, travel & stops.");

    const sourceLine = hero.querySelector("#activeSources,.sourceLine");
    if (sourceLine) {
      let sawWebRouting = false;
      sourceLine.querySelectorAll(".chip").forEach(chip => {
        const text = String(chip.textContent || "").trim();
        if (/Google Calendar/i.test(text)) chip.textContent = text.replace(/Google Calendar/i, "Google");
        else if (/Calendar Links/i.test(text)) chip.textContent = text.replace(/Calendar Links/i, "Links");
        else if (/Web routing/i.test(text)) {
          sawWebRouting = true;
          chip.title = text;
          chip.textContent = "Web routing";
        }
      });
      if (sawWebRouting && !hero.querySelector(".lrRoutingCredit")) {
        const credit = document.createElement("div");
        credit.className = "lrRoutingCredit";
        credit.textContent = "© OpenStreetMap contributors · OSRM";
        sourceLine.after(credit);
      }
    }
  };

  const simplifyLiveDay = () => {
    const generate = document.querySelector(".liveDayGenerate");
    if (generate) {
      const text = String(generate.textContent || "");
      if (/Regenerate day/i.test(text)) generate.textContent = "Update day";
      else if (/Generate day/i.test(text)) generate.textContent = "Generate day";
    }
    const end = document.querySelector(".liveDayEnd");
    if (end) setTextIfDifferent(end, "End");

    document.querySelectorAll("#today .chip,#today .badge").forEach(node => {
      const text = String(node.textContent || "").trim();
      if (/Live commute start/i.test(text)) node.textContent = text.replace(/Live commute start/i, "Live start");
      else if (/clients saved/i.test(text)) node.textContent = text.replace(/\s*saved/i, "");
      else if (/calendar location linked/i.test(text)) node.textContent = text.replace(/calendar location linked/i, "linked location");
    });

    document.querySelectorAll("#today .title").forEach(node => {
      if (/^End day at Home$/i.test(node.textContent.trim())) node.textContent = "End at Home";
    });
    document.querySelectorAll("#today .meta").forEach(node => {
      if (/Add last appointment.*Home as the final route leg/i.test(node.textContent)) node.textContent = "Route home after last appointment.";
    });
  };

  const syncThemeMarks = () => {
    document.querySelectorAll("#lifeRouteSettingsOverlay .lrSettingsSection").forEach(section => {
      const select = section.querySelector("select");
      const head = section.querySelector(".lrSettingsSectionHead b");
      if (!select || !head) return;
      let mark = head.querySelector(".lrThemeSelectedMark");
      if (select.value) {
        if (!mark) {
          mark = document.createElement("span");
          mark.className = "lrThemeSelectedMark";
          mark.textContent = "✓";
          head.appendChild(mark);
        }
      } else mark?.remove();
    });
  };

  let queued = false;
  const polish = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      simplifyHero();
      simplifyLiveDay();
      syncThemeMarks();
    });
  };

  document.addEventListener("change", event => {
    if (event.target?.matches?.("select")) setTimeout(polish, 0);
  }, true);
  const observer = new MutationObserver(polish);
  const start = () => {
    observer.observe(document.body, { childList: true, subtree: true, characterData: true });
    polish();
  };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
