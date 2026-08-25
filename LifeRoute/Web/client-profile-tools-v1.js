// Connect saved Client Profiles to field tools without changing the underlying
// note/plan storage model. Choosing a client preloads that client's saved
// targets and preferred activities while still allowing session-specific edits.
(() => {
  if (window.__lifeRouteClientProfileToolsV1Loaded) return;
  window.__lifeRouteClientProfileToolsV1Loaded = true;

  const STORE = "liferoute_v3";
  let selectedCode = "";
  const clean = value => String(value ?? "").trim();
  const pair = value => {
    const letters = clean(value).replace(/[^a-z]/gi, "").slice(0, 2);
    return letters ? letters.charAt(0).toUpperCase() + letters.slice(1).toLowerCase() : "";
  };
  const codeFor = client => `${pair(client?.first2)}${pair(client?.last2)}`;
  const listFrom = value => Array.isArray(value)
    ? value.map(clean).filter(Boolean)
    : clean(value).split(/[\n;,]+/).map(clean).filter(Boolean);

  const readClients = () => {
    try {
      if (window.LifeRouteClientProfilesV1?.list) return window.LifeRouteClientProfilesV1.list();
      if (typeof prefs !== "undefined" && Array.isArray(prefs.clients)) return prefs.clients;
    } catch (_) {}
    try {
      const saved = JSON.parse(localStorage.getItem(STORE) || "{}");
      return Array.isArray(saved?.prefs?.clients) ? saved.prefs.clients : [];
    } catch (_) { return []; }
  };

  const profileFor = code => readClients().find(client => codeFor(client).toLowerCase() === clean(code).toLowerCase()) || null;

  const ensureContext = () => {
    const select = document.getElementById("sessionPlanClient");
    if (!select) return null;
    let host = document.getElementById("sessionPlanClientContext");
    if (!host) {
      host = document.createElement("div");
      host.id = "sessionPlanClientContext";
      host.className = "sessionPlanClientContext";
      select.closest(".grid2")?.after(host);
    }
    return host;
  };

  const renderContext = profile => {
    const host = ensureContext();
    if (!host) return;
    if (!profile) {
      host.innerHTML = '<span class="tiny">Choose a saved client to load profile targets and preferred activities.</span>';
      host.classList.remove("show");
      return;
    }
    const targets = listFrom(profile.currentTargets || profile.targets);
    const preferred = listFrom(profile.preferredActivities || profile.reinforcers);
    const behaviors = listFrom(profile.behaviorsOfConcern || profile.behaviors);
    host.classList.add("show");
    host.innerHTML = `<div class="sessionPlanProfileLabel">CLIENT PROFILE</div><div class="sessionPlanProfileStats"><span>${targets.length} target${targets.length === 1 ? "" : "s"}</span><span>${preferred.length} preferred activit${preferred.length === 1 ? "y" : "ies"}</span><span>${behaviors.length} behavior${behaviors.length === 1 ? "" : "s"}</span></div>`;
  };

  const mayAutofill = (field, force) => force || !clean(field?.value) || field?.dataset?.profileAutofill === "1";
  const setAutofill = (field, value, force = false) => {
    if (!field || !mayAutofill(field, force)) return;
    field.value = value;
    field.dataset.profileAutofill = value ? "1" : "0";
  };

  const applyProfile = (code, { force = false } = {}) => {
    const normalizedCode = clean(code);
    const profile = profileFor(normalizedCode);
    const targets = document.getElementById("sessionPlanTargets");
    const reinforcers = document.getElementById("sessionPlanReinforcers");
    renderContext(profile);
    if (!profile) {
      if (force || targets?.dataset.profileAutofill === "1") { if (targets) targets.value = ""; if (targets) targets.dataset.profileAutofill = "0"; }
      if (force || reinforcers?.dataset.profileAutofill === "1") { if (reinforcers) reinforcers.value = ""; if (reinforcers) reinforcers.dataset.profileAutofill = "0"; }
      selectedCode = normalizedCode;
      return;
    }
    setAutofill(targets, listFrom(profile.currentTargets || profile.targets).join("; "), force);
    setAutofill(reinforcers, listFrom(profile.preferredActivities || profile.reinforcers).join("; "), force);
    selectedCode = normalizedCode;
  };

  const installStyles = () => {
    if (document.getElementById("lifeRouteClientProfileToolsV1Styles")) return;
    const style = document.createElement("style");
    style.id = "lifeRouteClientProfileToolsV1Styles";
    style.textContent = `
      .sessionPlanClientContext{display:none;margin:8px 0 2px;padding:8px 9px;border-radius:11px;border:1px solid var(--line);background:color-mix(in srgb,var(--panel2) 62%,transparent)}.sessionPlanClientContext.show{display:block}.sessionPlanProfileLabel{font-size:8px;letter-spacing:.09em;font-weight:950;color:var(--gold);margin-bottom:5px}.sessionPlanProfileStats{display:flex;gap:5px;flex-wrap:wrap}.sessionPlanProfileStats span{font-size:8px;font-weight:800;color:var(--muted);padding:4px 6px;border-radius:999px;background:color-mix(in srgb,var(--panel) 70%,transparent);border:1px solid var(--line)}
    `;
    document.head.appendChild(style);
  };

  const bind = () => {
    const select = document.getElementById("sessionPlanClient");
    if (!select || select.dataset.clientProfileToolsV1 === "1") return false;
    select.dataset.clientProfileToolsV1 = "1";
    select.addEventListener("change", () => {
      const nextCode = clean(select.value);
      applyProfile(nextCode, { force: nextCode !== selectedCode });
    });

    ["sessionPlanTargets", "sessionPlanReinforcers"].forEach(id => {
      const field = document.getElementById(id);
      field?.addEventListener("input", event => {
        if (event.isTrusted) field.dataset.profileAutofill = "0";
      });
    });

    applyProfile(select.value, { force: true });
    return true;
  };

  window.applyLifeRouteClientProfileToTools = code => applyProfile(
    code ?? document.getElementById("sessionPlanClient")?.value ?? "",
    { force: false }
  );

  const start = () => {
    installStyles();
    bind();
    [60, 180, 480, 1000].forEach(delay => setTimeout(bind, delay));
    window.addEventListener("liferoute:clients-changed", () => {
      window.refreshLifeRouteToolClients?.();
      setTimeout(() => applyProfile(document.getElementById("sessionPlanClient")?.value || "", { force: false }), 30);
    });
    window.addEventListener("storage", event => {
      if (event.key === STORE) setTimeout(() => applyProfile(document.getElementById("sessionPlanClient")?.value || "", { force: false }), 30);
    });
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
