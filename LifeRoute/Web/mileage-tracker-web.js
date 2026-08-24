// LifeRoute mileage tracker: persist known route mileage and summarize it week by week.
(() => {
  if (window.__lifeRouteMileageTrackerLoaded) return;
  window.__lifeRouteMileageTrackerLoaded = true;

  const AUTO_KEY = "liferoute_mileage_auto_v1";
  const MANUAL_KEY = "liferoute_mileage_manual_v1";
  const SETTINGS_KEY = "liferoute_mileage_settings_v1";
  let weekAnchor = startOfWeek(new Date());

  function startOfWeek(value) {
    const d = new Date(value);
    d.setHours(0,0,0,0);
    const offset = (d.getDay() + 6) % 7;
    d.setDate(d.getDate() - offset);
    return d;
  }
  const dateKey = d => `${d.getFullYear()}-${String(d.getMonth()+1).padStart(2,"0")}-${String(d.getDate()).padStart(2,"0")}`;
  const addDays = (d, days) => { const x = new Date(d); x.setDate(x.getDate()+days); return x; };
  const weekKeys = anchor => Array.from({length:7}, (_,i) => dateKey(addDays(startOfWeek(anchor), i)));
  const milesFromMeters = value => Number(value || 0) / 1609.344;
  const safe = value => String(value ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[c]));
  const fmtMiles = value => `${Number(value || 0).toFixed(1)} mi`;

  const readJSON = (key, fallback) => { try { const value = JSON.parse(localStorage.getItem(key) || "null"); return value ?? fallback; } catch (_) { return fallback; } };
  const writeJSON = (key, value) => { try { localStorage.setItem(key, JSON.stringify(value)); } catch (_) {} };
  const readAuto = () => { const value = readJSON(AUTO_KEY, {}); return value && typeof value === "object" && !Array.isArray(value) ? value : {}; };
  const readManual = () => { const value = readJSON(MANUAL_KEY, []); return Array.isArray(value) ? value : []; };
  const readSettings = () => Object.assign({ reimbursementRate:"" }, readJSON(SETTINGS_KEY, {}));

  const homeAddress = () => String(window.prefs?.homeAddress || "").trim() || String((window.places || []).find(place => String(place?.type || "").toLowerCase() === "home")?.address || "").trim();

  const selectedGap = (date, previous, next) => typeof window.lifeRouteSelectedGapFor === "function"
    ? window.lifeRouteSelectedGapFor(date, String(previous?.id || ""), String(next?.id || ""))
    : null;

  const gapMiles = selection => {
    if (!selection) return 0;
    const split = Number(selection.outDistanceMeters || 0) + Number(selection.backDistanceMeters || 0);
    return milesFromMeters(split > 0 ? split : Number(selection.distanceMeters || 0));
  };

  const discoverDate = date => {
    const list = typeof window.dayEvents === "function" ? window.dayEvents(date) : [];
    const legs = [];
    const unknown = [];
    list.forEach((event, index) => {
      if (!String(event?.address || "").trim()) return;
      if (index > 0) {
        const previous = list[index - 1];
        const selection = selectedGap(date, previous, event);
        const selectedMiles = gapMiles(selection);
        if (selectedMiles > 0) {
          legs.push({
            id:`gap:${date}:${previous.id}:${event.id}`,
            date,
            from: previous.title || "Previous appointment",
            to: `${selection.label || "Selected stop"} → ${event.title || "Next appointment"}`,
            miles:selectedMiles,
            purpose:"Business / client travel",
            source:"planned gap route"
          });
          return;
        }
      }
      const miles = Number(event.routeDistanceMiles || 0);
      if (miles > 0) {
        legs.push({
          id:`event:${date}:${event.id}:in`,
          date,
          from:event.routeOriginLabel || (index === 0 ? "Start" : list[index-1]?.title || "Previous appointment"),
          to:event.title || "Appointment",
          miles,
          purpose:"Business / client travel",
          source:event.routeTimeSource || "LifeRoute route"
        });
      } else {
        unknown.push({ date, label:`${index === 0 ? "Start" : list[index-1]?.title || "Previous appointment"} → ${event.title || "Appointment"}` });
      }
    });

    if (window.prefs?.endDayAtHome && list.length && homeAddress()) {
      const last = list[list.length - 1];
      const known = Number(last.returnHomeDistanceMiles || window.nativeState?.endHomeRouteDistanceMilesByDate?.[date] || 0);
      if (known > 0) {
        legs.push({ id:`home:${date}:${last.id}`, date, from:last.title || "Last appointment", to:"Home", miles:known, purpose:"Business / client travel", source:"LifeRoute final route" });
      } else if (String(last.address || "").trim()) {
        unknown.push({ date, label:`${last.title || "Last appointment"} → Home` });
      }
    }
    return { legs, unknown };
  };

  const refreshSnapshots = keys => {
    const auto = readAuto();
    const unknown = [];
    keys.forEach(date => {
      const found = discoverDate(date);
      found.legs.forEach(leg => {
        auto[leg.id] = Object.assign({}, auto[leg.id] || {}, leg, { updatedAt:new Date().toISOString() });
      });
      unknown.push(...found.unknown);
    });
    writeJSON(AUTO_KEY, auto);
    return unknown;
  };

  const recordsForWeek = anchor => {
    const keys = weekKeys(anchor);
    const keySet = new Set(keys);
    const unknown = refreshSnapshots(keys);
    const auto = Object.values(readAuto()).filter(item => keySet.has(String(item.date || "")) && Number(item.miles || 0) > 0);
    const manual = readManual().filter(item => keySet.has(String(item.date || "")) && Number(item.miles || 0) > 0);
    const records = [...auto.map(item => ({...item, kind:"auto"})), ...manual.map(item => ({...item, kind:"manual"}))]
      .sort((a,b) => String(a.date).localeCompare(String(b.date)) || String(a.from || a.note || "").localeCompare(String(b.from || b.note || "")));
    return { keys, records, unknown };
  };

  const totalMiles = records => records.reduce((sum, item) => sum + Number(item.miles || 0), 0);
  const rateValue = () => Number(readSettings().reimbursementRate || 0);

  const styles = document.createElement("style");
  styles.id = "lifeRouteMileageStyles";
  styles.textContent = `
    .mileageToolCard .mileageMini{display:grid;grid-template-columns:1fr 1fr;gap:7px;margin:9px 0}.mileageMini div,.mileageMetric{padding:10px;border-radius:13px;background:var(--panel2);border:1px solid var(--line)}.mileageMini b,.mileageMetric b{display:block;font-size:18px}.mileageMini span,.mileageMetric span{font-size:9px;color:var(--muted)}
    .mileageOverlay{position:fixed;inset:0;z-index:18000;display:none;background:var(--bg);color:var(--text);overflow:auto;padding:calc(16px + env(safe-area-inset-top)) 14px calc(24px + env(safe-area-inset-bottom))}.mileageOverlay.show{display:block}.mileageShell{max-width:900px;margin:auto}.mileageTop{position:sticky;top:0;z-index:2;display:flex;justify-content:space-between;align-items:center;gap:10px;padding:7px 0 12px;background:linear-gradient(var(--bg) 72%,transparent)}.mileageBack{border-radius:999px!important}.mileageWeekNav{display:grid;grid-template-columns:auto 1fr auto;gap:8px;align-items:center}.mileageWeekLabel{text-align:center;font-weight:950}.mileageMetrics{display:grid;grid-template-columns:repeat(3,1fr);gap:8px;margin:12px 0}.mileageDay{margin-top:9px}.mileageLeg{display:grid;grid-template-columns:90px 1fr auto;gap:10px;align-items:center;padding:9px 0;border-bottom:1px solid var(--line)}.mileageLeg:last-child{border-bottom:0}.mileageMiles{font-weight:950;color:var(--gold);white-space:nowrap}.mileageUnknown{margin-top:10px;padding:10px;border-radius:13px;border:1px dashed color-mix(in srgb,var(--gold) 45%,var(--line));color:var(--muted);font-size:10px;line-height:1.45}.mileageForm{display:grid;grid-template-columns:1fr 1fr 1.5fr auto;gap:8px;align-items:end}.mileageRecent{display:grid;gap:7px}.mileageRecentRow{display:grid;grid-template-columns:1fr auto;gap:8px;padding:10px;border-radius:13px;background:var(--panel2);border:1px solid var(--line)}
    @media(max-width:680px){.mileageMetrics{grid-template-columns:1fr 1fr}.mileageMetrics .mileageMetric:last-child{grid-column:1/-1}.mileageLeg{grid-template-columns:70px 1fr auto}.mileageForm{grid-template-columns:1fr}.mileageForm button{width:100%}}
  `;
  document.head.appendChild(styles);

  const ensureToolsCard = () => {
    const grid = document.querySelector("#tools .toolGrid");
    if (!grid || document.getElementById("mileageToolCard")) return false;
    const card = document.createElement("div");
    card.id = "mileageToolCard";
    card.className = "card toolCard mileageToolCard";
    card.innerHTML = `
      <div class="toolHead"><div class="toolIcon">MI</div><div class="grow"><div class="title">Mileage tracker</div><div class="meta">Automatically log route miles LifeRoute already knows and keep weekly records for reimbursement or tax documentation.</div></div></div>
      <div class="mileageMini"><div><b id="mileageMiniTotal">0.0 mi</b><span>this week</span></div><div><b id="mileageMiniLegs">0</b><span>measured route legs</span></div></div>
      <div class="toolActions"><button class="goldButton" id="openMileageTracker" type="button">Open mileage tracker</button></div>`;
    grid.appendChild(card);
    card.querySelector("#openMileageTracker").onclick = () => openOverlay();
    return true;
  };

  const ensureOverlay = () => {
    let overlay = document.getElementById("mileageOverlay");
    if (overlay) return overlay;
    overlay = document.createElement("div");
    overlay.id = "mileageOverlay";
    overlay.className = "mileageOverlay";
    overlay.innerHTML = `<div class="mileageShell">
      <div class="mileageTop"><button class="secondary mileageBack" id="mileageBack">← Back</button><div><div class="small" style="color:var(--gold);font-weight:950">MILEAGE</div><div class="title">Weekly mileage record</div></div><button class="secondary" id="mileageRefresh">Update routes</button></div>
      <div class="card">
        <div class="mileageWeekNav"><button class="secondary" id="mileagePrev">‹</button><div class="mileageWeekLabel" id="mileageWeekLabel"></div><button class="secondary" id="mileageNext">›</button></div>
        <div class="mileageMetrics"><div class="mileageMetric"><b id="mileageTotal">0.0 mi</b><span>tracked miles</span></div><div class="mileageMetric"><b id="mileageAuto">0.0 mi</b><span>automatic route miles</span></div><div class="mileageMetric"><b id="mileageValue">—</b><span>reimbursement estimate</span></div></div>
        <div class="grid2"><div><label>Reimbursement rate per mile</label><input id="mileageRate" type="number" min="0" step="0.001" inputmode="decimal" placeholder="Optional"></div><div style="display:flex;align-items:end"><button class="secondary" id="mileageExport" style="width:100%">Export week CSV</button></div></div>
        <div class="tiny" style="margin-top:9px">Mileage is based on route distances available in LifeRoute. Review your records before submitting them to an employer or using them for tax documentation.</div>
      </div>
      <div id="mileageDays"></div>
      <div class="card"><div class="title">Add a manual trip</div><div class="meta">Use this when a route was not measured automatically.</div><div class="mileageForm" style="margin-top:9px"><div><label>Date</label><input id="mileageManualDate" type="date"></div><div><label>Miles</label><input id="mileageManualMiles" type="number" min="0" step="0.1" inputmode="decimal" placeholder="0.0"></div><div><label>Purpose / note</label><input id="mileageManualNote" placeholder="Client travel, meeting…"></div><button class="goldButton" id="mileageManualAdd">Add trip</button></div></div>
      <div class="section"><div class="sectionHead"><h2>Recent weeks</h2><span class="hint">saved on this device</span></div><div id="mileageRecent" class="mileageRecent"></div></div>
    </div>`;
    document.body.appendChild(overlay);
    overlay.querySelector("#mileageBack").onclick = () => overlay.classList.remove("show");
    overlay.querySelector("#mileagePrev").onclick = () => { weekAnchor = addDays(weekAnchor,-7); renderOverlay(); };
    overlay.querySelector("#mileageNext").onclick = () => { weekAnchor = addDays(weekAnchor,7); renderOverlay(); };
    overlay.querySelector("#mileageRefresh").onclick = () => {
      if (typeof window.refreshRouteTimes === "function") window.refreshRouteTimes();
      setTimeout(renderOverlay, 800);
    };
    overlay.querySelector("#mileageRate").addEventListener("input", event => {
      const settings = readSettings(); settings.reimbursementRate = event.target.value; writeJSON(SETTINGS_KEY, settings); renderOverlay(false);
    });
    overlay.querySelector("#mileageExport").onclick = exportCSV;
    overlay.querySelector("#mileageManualAdd").onclick = addManualTrip;
    return overlay;
  };

  const weekLabel = anchor => {
    const start = startOfWeek(anchor), end = addDays(start,6);
    const a = start.toLocaleDateString("en-US",{month:"short",day:"numeric"});
    const b = end.toLocaleDateString("en-US",{month:"short",day:"numeric",year:"numeric"});
    return `${a} – ${b}`;
  };

  const renderRecent = () => {
    const host = document.getElementById("mileageRecent");
    if (!host) return;
    host.innerHTML = Array.from({length:8},(_,i) => addDays(startOfWeek(new Date()), -7*i)).map(anchor => {
      const data = recordsForWeek(anchor); const total = totalMiles(data.records);
      return `<button type="button" class="mileageRecentRow secondary" data-week="${dateKey(anchor)}"><span style="text-align:left"><b>${safe(weekLabel(anchor))}</b><span class="tiny" style="display:block">${data.records.length} recorded leg${data.records.length===1?"":"s"}</span></span><b>${fmtMiles(total)}</b></button>`;
    }).join("");
    host.querySelectorAll("[data-week]").forEach(button => button.onclick = () => { weekAnchor = startOfWeek(new Date(`${button.dataset.week}T12:00:00`)); renderOverlay(); document.getElementById("mileageOverlay")?.scrollTo({top:0,behavior:"smooth"}); });
  };

  const renderOverlay = (full = true) => {
    const overlay = ensureOverlay();
    const data = recordsForWeek(weekAnchor);
    const total = totalMiles(data.records);
    const autoTotal = totalMiles(data.records.filter(item => item.kind === "auto"));
    const rate = rateValue();
    document.getElementById("mileageWeekLabel").textContent = weekLabel(weekAnchor);
    document.getElementById("mileageTotal").textContent = fmtMiles(total);
    document.getElementById("mileageAuto").textContent = fmtMiles(autoTotal);
    document.getElementById("mileageValue").textContent = rate > 0 ? `$${(total*rate).toFixed(2)}` : "—";
    const rateInput = document.getElementById("mileageRate"); if (rateInput && document.activeElement !== rateInput) rateInput.value = readSettings().reimbursementRate || "";
    const manualDate = document.getElementById("mileageManualDate"); if (manualDate && !manualDate.value) manualDate.value = data.keys[0];

    if (full) {
      const days = document.getElementById("mileageDays");
      days.innerHTML = data.keys.map(key => {
        const dateRecords = data.records.filter(item => item.date === key);
        const dayUnknown = data.unknown.filter(item => item.date === key);
        if (!dateRecords.length && !dayUnknown.length) return "";
        const d = new Date(`${key}T12:00:00`);
        return `<div class="card mileageDay"><div class="row"><div><div class="title">${d.toLocaleDateString("en-US",{weekday:"long",month:"short",day:"numeric"})}</div><div class="meta">${fmtMiles(totalMiles(dateRecords))}</div></div></div>${dateRecords.map(item => `<div class="mileageLeg"><div class="small">${item.kind === "auto" ? "AUTO" : "MANUAL"}</div><div><b>${safe(item.kind === "auto" ? `${item.from} → ${item.to}` : item.note || "Manual business trip")}</b><div class="tiny">${safe(item.purpose || item.source || "Business mileage")}</div></div><div class="mileageMiles">${fmtMiles(item.miles)}${item.kind === "manual" ? `<button class="danger" style="display:block;margin-top:4px;padding:4px 7px;font-size:8px" data-delete-mileage="${safe(item.id)}">Remove</button>` : ""}</div></div>`).join("")}${dayUnknown.length ? `<div class="mileageUnknown"><b>${dayUnknown.length} route leg${dayUnknown.length===1?"":"s"} not measured yet:</b><br>${dayUnknown.map(item => safe(item.label)).join("<br>")}</div>` : ""}</div>`;
      }).join("") || '<div class="card empty">No mileage records for this week yet.</div>';
      days.querySelectorAll("[data-delete-mileage]").forEach(button => button.onclick = () => { writeJSON(MANUAL_KEY, readManual().filter(item => item.id !== button.dataset.deleteMileage)); renderOverlay(); });
      renderRecent();
    }
    updateMini();
    return overlay;
  };

  const openOverlay = () => { weekAnchor = startOfWeek(new Date()); const overlay = renderOverlay(); overlay.classList.add("show"); overlay.scrollTop = 0; };

  const addManualTrip = () => {
    const date = document.getElementById("mileageManualDate")?.value || "";
    const miles = Number(document.getElementById("mileageManualMiles")?.value || 0);
    const note = String(document.getElementById("mileageManualNote")?.value || "").trim();
    if (!date || !(miles > 0)) return alert("Choose a date and enter the trip miles.");
    const items = readManual();
    items.push({ id:`manual-mile-${Date.now()}`, date, miles, note:note || "Manual business trip", purpose:"Business mileage", createdAt:new Date().toISOString() });
    writeJSON(MANUAL_KEY, items);
    document.getElementById("mileageManualMiles").value = "";
    document.getElementById("mileageManualNote").value = "";
    renderOverlay();
  };

  function exportCSV() {
    const data = recordsForWeek(weekAnchor);
    const rows = [["Date","Type","From","To / Note","Purpose","Miles","Source"]];
    data.records.forEach(item => rows.push([item.date,item.kind,item.from || "",item.to || item.note || "",item.purpose || "",Number(item.miles||0).toFixed(2),item.source || "manual"]));
    data.unknown.forEach(item => rows.push([item.date,"unmeasured","",item.label,"","","distance pending"]));
    const csv = rows.map(row => row.map(value => `"${String(value ?? "").replace(/"/g,'""')}"`).join(",")).join("\n");
    const blob = new Blob([csv], {type:"text/csv;charset=utf-8"});
    const url = URL.createObjectURL(blob); const link = document.createElement("a");
    link.href = url; link.download = `LifeRoute-mileage-${dateKey(startOfWeek(weekAnchor))}.csv`; document.body.appendChild(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url),1000);
  }

  const updateMini = () => {
    ensureToolsCard();
    const data = recordsForWeek(startOfWeek(new Date()));
    const total = totalMiles(data.records);
    const totalNode = document.getElementById("mileageMiniTotal"); const legsNode = document.getElementById("mileageMiniLegs");
    if (totalNode) totalNode.textContent = fmtMiles(total);
    if (legsNode) legsNode.textContent = String(data.records.filter(item => item.kind === "auto").length);
  };

  const install = () => {
    ensureToolsCard();
    updateMini();
    const previous = window.lifeRouteNativeEvent;
    if (typeof previous === "function" && !previous.__mileageWrapped) {
      const wrapped = function(evt) { const result = previous.apply(this, arguments); if (evt?.type === "routeTimes") setTimeout(updateMini,80); return result; };
      wrapped.__mileageWrapped = true; window.lifeRouteNativeEvent = wrapped;
    }
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => setTimeout(install,500), {once:true});
  else setTimeout(install,500);
  [1000,2000,4000].forEach(delay => setTimeout(install,delay));
})();