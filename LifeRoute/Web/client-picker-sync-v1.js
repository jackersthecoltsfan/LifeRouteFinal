// LifeRoute saved-client picker sync.
// Keeps every field-tool client selector tied to the same locally saved Setup clients.
(() => {
  const STORE = "liferoute_v3";
  const TARGET_IDS = ["quickNoteClient", "sessionPlanClient"];

  const formatPair = value => {
    const letters = String(value || "").replace(/[^a-z]/gi, "").slice(0, 2);
    return letters ? letters.charAt(0).toUpperCase() + letters.slice(1).toLowerCase() : "";
  };

  const clientCode = client => `${formatPair(client?.first2)}${formatPair(client?.last2)}`;

  const readPersistedClients = () => {
    try {
      const saved = JSON.parse(localStorage.getItem(STORE) || "{}");
      return Array.isArray(saved?.prefs?.clients) ? saved.prefs.clients : [];
    } catch (_) {
      return [];
    }
  };

  const readClients = () => {
    let live = [];
    try {
      if (typeof prefs !== "undefined" && Array.isArray(prefs.clients)) live = prefs.clients;
    } catch (_) {}
    const source = live.length ? live : readPersistedClients();
    const seen = new Set();
    return source
      .map(client => ({
        first2: formatPair(client?.first2),
        last2: formatPair(client?.last2),
        address: String(client?.address || "").trim()
      }))
      .filter(client => {
        const code = clientCode(client);
        const key = code.toLowerCase();
        if (code.length !== 4 || seen.has(key)) return false;
        seen.add(key);
        return true;
      });
  };

  const escapeHtml = value => String(value || "").replace(/[&<>"']/g, char => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;"
  })[char]);

  const renderSelect = select => {
    if (!select) return;
    const current = String(select.value || "");
    const clients = readClients();
    select.innerHTML = [
      '<option value="">General / no client</option>',
      ...clients.map(client => {
        const code = clientCode(client);
        return `<option value="${escapeHtml(code)}">${escapeHtml(code)}</option>`;
      })
    ].join("");
    if (current && clients.some(client => clientCode(client) === current)) select.value = current;
    else if (!current) select.value = "";
    select.dataset.lifeRouteClientCount = String(clients.length);
  };

  const sync = () => {
    TARGET_IDS.forEach(id => renderSelect(document.getElementById(id)));
    const refresh = document.getElementById("refreshToolClients");
    if (refresh) {
      const count = readClients().length;
      refresh.textContent = count ? `Refresh clients · ${count}` : "Refresh clients";
      refresh.setAttribute("aria-label", count ? `Refresh ${count} saved clients` : "Refresh saved clients");
    }
  };

  window.refreshLifeRouteToolClients = sync;

  const scheduleSync = () => {
    requestAnimationFrame(() => {
      sync();
      setTimeout(sync, 80);
    });
  };

  const start = () => {
    scheduleSync();

    document.addEventListener("click", event => {
      const target = event.target?.closest?.("#saveClientButton,#refreshToolClients,[data-view='tools'],#setupSubnav button,[onclick*='removeLifeRouteClient']");
      if (target) scheduleSync();
    }, true);

    document.addEventListener("change", event => {
      if (TARGET_IDS.includes(event.target?.id)) {
        event.target.dataset.lifeRouteChosenClient = String(event.target.value || "");
      }
    }, true);

    window.addEventListener("storage", event => {
      if (event.key === STORE) scheduleSync();
    });

    // Only observe the Setup/Tools roots so this synchronization adds no page-wide mutation cost.
    const roots = [document.getElementById("setup"), document.getElementById("tools")].filter(Boolean);
    roots.forEach(root => {
      const observer = new MutationObserver(records => {
        if (records.some(record => Array.from(record.addedNodes || []).some(node => node.nodeType === 1 && (
          TARGET_IDS.some(id => node.id === id || node.querySelector?.(`#${id}`)) ||
          node.id === "clientList" || node.querySelector?.("#clientList")
        )))) scheduleSync();
      });
      observer.observe(root, { childList: true, subtree: true });
    });
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
