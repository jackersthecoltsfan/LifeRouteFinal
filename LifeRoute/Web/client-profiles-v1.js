// LifeRoute full client profiles.
// Enhances the existing Setup > Clients pane while preserving the four-letter
// ABA-style code/address model used by routing and calendar matching.
(() => {
  if (window.__lifeRouteClientProfilesV1Loaded) return;
  window.__lifeRouteClientProfilesV1Loaded = true;

  const STORE = "liferoute_v3";
  let editingCode = "";

  const clean = value => String(value ?? "").trim();
  const formatPair = value => {
    const letters = clean(value).replace(/[^a-z]/gi, "").slice(0, 2);
    return letters ? letters.charAt(0).toUpperCase() + letters.slice(1).toLowerCase() : "";
  };
  const codeFor = client => `${formatPair(client?.first2)}${formatPair(client?.last2)}`;
  const esc = value => clean(value).replace(/[&<>"']/g, char => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;"
  })[char]);
  const listFrom = value => {
    const source = Array.isArray(value) ? value : clean(value).split(/[\n;,]+/);
    const seen = new Set();
    return source.map(clean).filter(item => {
      const key = item.toLowerCase();
      if (!item || seen.has(key)) return false;
      seen.add(key);
      return true;
    }).slice(0, 60);
  };
  const listText = value => listFrom(value).join("\n");

  const normalizeClient = client => ({
    ...(client && typeof client === "object" ? client : {}),
    first2: formatPair(client?.first2),
    last2: formatPair(client?.last2),
    address: clean(client?.address),
    preferredActivities: listFrom(client?.preferredActivities || client?.reinforcers),
    currentTargets: listFrom(client?.currentTargets || client?.targets),
    behaviorsOfConcern: listFrom(client?.behaviorsOfConcern || client?.behaviors),
    communicationNotes: clean(client?.communicationNotes || client?.fctNotes),
    promptingNotes: clean(client?.promptingNotes || client?.reinforcementNotes),
    caregiverNotes: clean(client?.caregiverNotes || client?.settingNotes),
    clinicalNotes: clean(client?.clinicalNotes || client?.notes),
    updatedAt: clean(client?.updatedAt)
  });

  const persistedClients = () => {
    try {
      const saved = JSON.parse(localStorage.getItem(STORE) || "{}");
      return Array.isArray(saved?.prefs?.clients) ? saved.prefs.clients.map(normalizeClient) : [];
    } catch (_) { return []; }
  };

  const clients = () => {
    try {
      if (typeof prefs !== "undefined" && Array.isArray(prefs.clients)) return prefs.clients.map(normalizeClient);
    } catch (_) {}
    return persistedClients();
  };

  const commitClients = next => {
    const normalized = next.map(normalizeClient).filter(client => codeFor(client).length === 4);
    try {
      if (typeof prefs !== "undefined") prefs.clients = normalized;
    } catch (_) {}

    if (typeof window.persist === "function") {
      try { window.persist(); } catch (_) {}
    } else {
      try {
        const saved = JSON.parse(localStorage.getItem(STORE) || "{}");
        saved.prefs = Object.assign({}, saved.prefs || {}, { clients: normalized });
        localStorage.setItem(STORE, JSON.stringify(saved));
      } catch (_) {}
    }

    try { window.applyLifeRouteClientLocations?.(); } catch (_) {}
    try { window.refreshLifeRouteToolClients?.(); } catch (_) {}
    try { window.renderAll?.(); } catch (_) {}
    try { window.refreshRouteTimes?.(); } catch (_) {}
    window.dispatchEvent(new CustomEvent("liferoute:clients-changed", { detail: { clients: normalized } }));
    return normalized;
  };

  const profileFields = () => ({
    first2: document.getElementById("clientFirst2"),
    last2: document.getElementById("clientLast2"),
    address: document.getElementById("clientAddress"),
    preferredActivities: document.getElementById("clientPreferredActivities"),
    currentTargets: document.getElementById("clientCurrentTargets"),
    behaviorsOfConcern: document.getElementById("clientBehaviorsOfConcern"),
    communicationNotes: document.getElementById("clientCommunicationNotes"),
    promptingNotes: document.getElementById("clientPromptingNotes"),
    caregiverNotes: document.getElementById("clientCaregiverNotes"),
    clinicalNotes: document.getElementById("clientClinicalNotes")
  });

  const updatePreview = () => {
    const fields = profileFields();
    if (fields.first2) fields.first2.value = formatPair(fields.first2.value);
    if (fields.last2) fields.last2.value = formatPair(fields.last2.value);
    const code = `${fields.first2?.value || ""}${fields.last2?.value || ""}`;
    const preview = document.getElementById("clientCodePreview");
    if (preview) preview.textContent = code.length === 4 ? code : "—";
    const mode = document.getElementById("clientProfileMode");
    if (mode) mode.textContent = editingCode ? `Editing ${editingCode}` : "New client";
  };

  const clearEditor = () => {
    editingCode = "";
    const fields = profileFields();
    Object.values(fields).forEach(field => { if (field) field.value = ""; });
    updatePreview();
    document.getElementById("clientFirst2")?.focus({ preventScroll: true });
  };

  const fillEditor = client => {
    const normalized = normalizeClient(client);
    editingCode = codeFor(normalized);
    const fields = profileFields();
    if (fields.first2) fields.first2.value = normalized.first2;
    if (fields.last2) fields.last2.value = normalized.last2;
    if (fields.address) fields.address.value = normalized.address;
    if (fields.preferredActivities) fields.preferredActivities.value = listText(normalized.preferredActivities);
    if (fields.currentTargets) fields.currentTargets.value = listText(normalized.currentTargets);
    if (fields.behaviorsOfConcern) fields.behaviorsOfConcern.value = listText(normalized.behaviorsOfConcern);
    if (fields.communicationNotes) fields.communicationNotes.value = normalized.communicationNotes;
    if (fields.promptingNotes) fields.promptingNotes.value = normalized.promptingNotes;
    if (fields.caregiverNotes) fields.caregiverNotes.value = normalized.caregiverNotes;
    if (fields.clinicalNotes) fields.clinicalNotes.value = normalized.clinicalNotes;
    updatePreview();
    document.getElementById("clientProfileEditor")?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  const renderClients = () => {
    const list = document.getElementById("clientList");
    const count = document.getElementById("clientCount");
    if (!list || !count) return;
    const all = clients();
    count.textContent = `${all.length} client${all.length === 1 ? "" : "s"}`;
    if (!all.length) {
      list.innerHTML = '<div class="card empty">No client profiles yet. Add a four-letter ABA-style code, then save the client’s useful session information.</div>';
      return;
    }
    list.innerHTML = all.map(client => {
      const code = codeFor(client);
      const targetCount = client.currentTargets.length;
      const prefCount = client.preferredActivities.length;
      const behaviorCount = client.behaviorsOfConcern.length;
      return `<div class="card clientCard lrClientProfileCard" data-client-code="${esc(code)}">
        <div class="clientCodePreview">${esc(code)}</div>
        <div class="grow">
          <div class="title">${esc(code)}</div>
          <div class="meta">${esc(client.address || "No service location saved")}</div>
          <div class="lrClientProfileStats">
            <span>${targetCount} target${targetCount === 1 ? "" : "s"}</span>
            <span>${prefCount} preferred activit${prefCount === 1 ? "y" : "ies"}</span>
            <span>${behaviorCount} behavior${behaviorCount === 1 ? "" : "s"}</span>
          </div>
        </div>
        <div class="lrClientProfileActions">
          <button class="secondary" type="button" data-edit-client="${encodeURIComponent(code)}">Edit profile</button>
          <button class="danger" type="button" data-remove-client="${encodeURIComponent(code)}">Remove</button>
        </div>
      </div>`;
    }).join("");

    list.querySelectorAll("[data-edit-client]").forEach(button => {
      button.addEventListener("click", () => {
        const code = decodeURIComponent(button.dataset.editClient || "");
        const client = clients().find(item => codeFor(item).toLowerCase() === code.toLowerCase());
        if (client) fillEditor(client);
      });
    });
    list.querySelectorAll("[data-remove-client]").forEach(button => {
      button.addEventListener("click", () => {
        const code = decodeURIComponent(button.dataset.removeClient || "");
        if (!window.confirm(`Remove ${code} from LifeRoute?`)) return;
        commitClients(clients().filter(item => codeFor(item).toLowerCase() !== code.toLowerCase()));
        if (editingCode.toLowerCase() === code.toLowerCase()) clearEditor();
        renderClients();
        try { window.setStatus?.(`${code} removed`); } catch (_) {}
      });
    });
  };

  const saveProfile = () => {
    const fields = profileFields();
    const first2 = formatPair(fields.first2?.value);
    const last2 = formatPair(fields.last2?.value);
    if (first2.length !== 2 || last2.length !== 2) {
      window.alert("Add exactly two first-name letters and two last-name letters for the client code.");
      return;
    }
    const code = `${first2}${last2}`;
    const all = clients();
    const editingIndex = editingCode ? all.findIndex(item => codeFor(item).toLowerCase() === editingCode.toLowerCase()) : -1;
    const duplicateIndex = all.findIndex(item => codeFor(item).toLowerCase() === code.toLowerCase());
    if (duplicateIndex >= 0 && editingIndex >= 0 && duplicateIndex !== editingIndex) {
      window.alert(`${code} is already saved as another client.`);
      return;
    }

    const previous = editingIndex >= 0 ? all[editingIndex] : duplicateIndex >= 0 ? all[duplicateIndex] : {};
    const nextClient = normalizeClient({
      ...previous,
      first2,
      last2,
      address: clean(fields.address?.value),
      preferredActivities: listFrom(fields.preferredActivities?.value),
      currentTargets: listFrom(fields.currentTargets?.value),
      behaviorsOfConcern: listFrom(fields.behaviorsOfConcern?.value),
      communicationNotes: clean(fields.communicationNotes?.value),
      promptingNotes: clean(fields.promptingNotes?.value),
      caregiverNotes: clean(fields.caregiverNotes?.value),
      clinicalNotes: clean(fields.clinicalNotes?.value),
      updatedAt: new Date().toISOString()
    });

    if (editingIndex >= 0) all.splice(editingIndex, 1, nextClient);
    else if (duplicateIndex >= 0) all.splice(duplicateIndex, 1, nextClient);
    else all.push(nextClient);

    commitClients(all);
    editingCode = code;
    renderClients();
    updatePreview();
    try { window.setStatus?.(`${code} profile saved`); } catch (_) {}
  };

  const installStyles = () => {
    if (document.getElementById("lifeRouteClientProfilesV1Styles")) return;
    const style = document.createElement("style");
    style.id = "lifeRouteClientProfilesV1Styles";
    style.textContent = `
      #clientProfileEditor{scroll-margin-top:80px}.lrClientProfileIntro{display:flex;justify-content:space-between;align-items:center;gap:10px;margin-bottom:10px}.lrClientProfileMode{font-size:9px;font-weight:900;letter-spacing:.08em;text-transform:uppercase;color:var(--gold)}
      .lrClientProfileGrid{display:grid;grid-template-columns:1fr 1fr;gap:9px}.lrClientProfileGrid .full{grid-column:1/-1}.lrClientProfileGrid textarea{width:100%;resize:vertical;min-height:82px;background:color-mix(in srgb,var(--panel2) 86%,transparent);color:var(--text);border:1px solid var(--line);border-radius:11px;padding:10px 11px;font:inherit;font-size:11px;line-height:1.45;outline:none}.lrClientProfileGrid textarea:focus{border-color:var(--blue);box-shadow:0 0 0 3px color-mix(in srgb,var(--blue) 13%,transparent)}
      .lrClientProfileFooter{display:flex;align-items:center;justify-content:space-between;gap:10px;margin-top:11px}.lrClientProfileFooterActions{display:flex;gap:7px;flex-wrap:wrap}.lrClientProfileStats{display:flex;gap:5px;flex-wrap:wrap;margin-top:6px}.lrClientProfileStats span{display:inline-flex;padding:4px 6px;border-radius:999px;background:color-mix(in srgb,var(--panel2) 76%,transparent);border:1px solid var(--line);font-size:8px;color:var(--muted);font-weight:800}
      .lrClientProfileCard{grid-template-columns:auto minmax(0,1fr) auto!important}.lrClientProfileActions{display:flex;gap:6px;align-items:center;flex-wrap:wrap;justify-content:flex-end}.lrClientProfileActions button{font-size:9px;min-height:36px}.lrClientPrivacy{margin-top:11px;padding-top:9px;border-top:1px solid var(--line);font-size:9px;line-height:1.45;color:var(--muted)}
      @media(max-width:620px){.lrClientProfileGrid{grid-template-columns:1fr}.lrClientProfileGrid .full{grid-column:auto}.lrClientProfileCard{grid-template-columns:auto 1fr!important}.lrClientProfileActions{grid-column:1/-1;justify-content:stretch}.lrClientProfileActions button{flex:1;min-height:44px}.lrClientProfileFooter{align-items:flex-start;flex-direction:column}.lrClientProfileFooterActions{width:100%}.lrClientProfileFooterActions button{flex:1;min-height:44px}}
    `;
    document.head.appendChild(style);
  };

  const installEditor = () => {
    const pane = document.getElementById("setupClients");
    if (!pane || pane.dataset.clientProfilesV1 === "1") return false;
    const legacySave = pane.querySelector("#saveClientButton");
    const legacySection = legacySave?.closest(".section") || pane.querySelector(".section");
    if (!legacySection) return false;

    pane.dataset.clientProfilesV1 = "1";
    legacySection.id = "clientProfileEditor";
    legacySection.innerHTML = `
      <div class="sectionHead"><h2>Client profile</h2><span class="hint">local to this device</span></div>
      <div class="card">
        <div class="lrClientProfileIntro"><div><div class="lrClientProfileMode" id="clientProfileMode">New client</div><div class="tiny">Save the information you actually use during sessions.</div></div><button class="secondary" type="button" id="newClientProfile">New profile</button></div>
        <div class="lrClientProfileGrid">
          <div><label>First 2 initials</label><input id="clientFirst2" maxlength="2" autocapitalize="none" autocomplete="off"></div>
          <div><label>Last 2 initials</label><input id="clientLast2" maxlength="2" autocapitalize="none" autocomplete="off"></div>
          <div class="full"><label>Client address / service location <span class="tiny">optional</span></label><input id="clientAddress" placeholder="Street address or searchable place"></div>
          <div><label>Preferred activities / reinforcers</label><textarea id="clientPreferredActivities" placeholder="Outside, music, swing, water play…\nOne per line or separated by commas"></textarea></div>
          <div><label>Current targets / programs</label><textarea id="clientCurrentTargets" placeholder="Manding, waiting, transitions, responding to name…"></textarea></div>
          <div><label>Behaviors of concern</label><textarea id="clientBehaviorsOfConcern" placeholder="Refusal, elopement, aggression…"></textarea></div>
          <div><label>Communication / FCT notes</label><textarea id="clientCommunicationNotes" placeholder="Communication mode, current mand forms, prompt level…"></textarea></div>
          <div><label>Prompting / reinforcement notes</label><textarea id="clientPromptingNotes" placeholder="Approved prompting hierarchy, reinforcement details, useful supports…"></textarea></div>
          <div><label>Caregiver / setting notes</label><textarea id="clientCaregiverNotes" placeholder="Caregiver preferences, common settings, transition considerations…"></textarea></div>
          <div class="full"><label>Other client notes</label><textarea id="clientClinicalNotes" placeholder="Useful context to remember during sessions. Keep this concise and relevant."></textarea></div>
        </div>
        <div class="lrClientProfileFooter">
          <div><div class="tiny">ABA-style client code</div><div class="clientCodePreview" id="clientCodePreview">—</div></div>
          <div class="lrClientProfileFooterActions"><button class="secondary" type="button" id="clearClientProfile">Clear</button><button class="goldButton" type="button" id="saveClientButton">Save profile</button></div>
        </div>
        <div class="lrClientPrivacy">Client profile data stays in LifeRoute’s local device storage. LifeRoute only uses the four-letter code and service location for calendar/route matching; profile details are used locally by session tools and are not sent to calendar or routing providers.</div>
      </div>`;

    const fields = profileFields();
    fields.first2?.addEventListener("input", updatePreview);
    fields.last2?.addEventListener("input", updatePreview);
    document.getElementById("newClientProfile")?.addEventListener("click", clearEditor);
    document.getElementById("clearClientProfile")?.addEventListener("click", clearEditor);
    document.getElementById("saveClientButton")?.addEventListener("click", saveProfile);

    renderClients();
    updatePreview();
    return true;
  };

  window.LifeRouteClientProfilesV1 = {
    list: clients,
    get: code => clients().find(client => codeFor(client).toLowerCase() === clean(code).toLowerCase()) || null,
    edit: code => {
      const client = clients().find(item => codeFor(item).toLowerCase() === clean(code).toLowerCase());
      if (client) fillEditor(client);
    },
    newProfile: clearEditor,
    render: renderClients
  };

  const start = () => {
    installStyles();
    if (installEditor()) return;
    // Setup is constructed during DOMContentLoaded by smart-context. These short
    // retries are bounded and stop as soon as the Clients pane exists.
    [40, 120, 320, 800].forEach(delay => setTimeout(() => installEditor(), delay));
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
