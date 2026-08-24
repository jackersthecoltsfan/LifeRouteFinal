// LifeRoute web resource launch hub: payroll/HR, ABA clinical platforms, and common work portals.
(() => {
  if (window.__lifeRouteResourcesHubLoaded) return;
  window.__lifeRouteResourcesHubLoaded = true;

  const CUSTOM_KEY = "liferoute_custom_resources_v1";
  const RESOURCE_GROUPS = [
    {
      id: "finance",
      title: "Finance & HR",
      subtitle: "Payroll, paystubs, HR, benefits, and employee self-service.",
      items: [
        { name: "ADP", note: "Payroll, paystubs, W-2s and HR", url: "https://my.adp.com/" },
        { name: "BambooHR", note: "HR, time off and employee records", url: "https://app.bamboohr.com/login/" },
        { name: "Gusto", note: "Payroll, benefits and employee account", url: "https://app.gusto.com/login" },
        { name: "Paycom", note: "Payroll and employee self-service", url: "https://www.paycomonline.net/v4/ee/web.php/app/login" },
        { name: "Paylocity", note: "Payroll, HR and employee portal", url: "https://access.paylocity.com/" },
        { name: "UKG", note: "Workforce, payroll and employee login", url: "https://www.ukg.com/solutions/employee-login" },
        { name: "Rippling", note: "Payroll, HR and workforce apps", url: "https://app.rippling.com/" },
        { name: "Workday", note: "HR and payroll; sign-in may be employer-specific", url: "https://www.workday.com/" },
        { name: "QuickBooks Workforce", note: "Paychecks, W-2s and time", url: "https://workforce.intuit.com/" },
        { name: "Viventium", note: "Payroll and HR used by healthcare/ABA employers", url: "https://www.viventium.com/" }
      ]
    },
    {
      id: "clinical",
      title: "ABA Data & Clinical",
      subtitle: "Launch common ABA data collection, notes, scheduling and practice platforms.",
      items: [
        { name: "CentralReach", note: "Clinical data, schedules, notes and practice management", url: "https://members.centralreach.com/" },
        { name: "RethinkBH", note: "ABA data collection and practice management", url: "https://webapp.rethinkbehavioralhealth.com/Home/Login" },
        { name: "Theralytics", note: "ABA data collection, documentation, billing and scheduling", url: "https://www.theralytics.net/" },
        { name: "Ensora Data Collection", note: "ABA data collection — formerly Catalyst", url: "https://secure.datafinch.com/" },
        { name: "Motivity", note: "Real-time ABA data collection and practice management", url: "https://www.motivity.net/" },
        { name: "Hi Rasmus", note: "ABA clinical platform, sessions and data collection", url: "https://app.hirasmus.com/" },
        { name: "AlohaABA", note: "ABA practice management and data collection", url: "https://alohaaba.com/" }
      ]
    },
    {
      id: "other",
      title: "Other ABA Work Portals",
      subtitle: "Credentials, training, EVV and general workplace tools commonly encountered in behavioral healthcare.",
      items: [
        { name: "BACB Portal", note: "Certification, renewal and credential account", url: "https://portal.bacb.com/" },
        { name: "Relias", note: "Employer training and learning management", url: "https://login.reliaslearning.com/" },
        { name: "HHAeXchange", note: "EVV and home-care workforce portal", url: "https://hhaexchange.com/" },
        { name: "Sandata", note: "EVV and home/community care technology", url: "https://www.sandata.com/" },
        { name: "Microsoft 365", note: "Outlook, Teams and workplace documents", url: "https://www.office.com/" },
        { name: "Google Workspace", note: "Gmail, Drive, Docs and workplace tools", url: "https://workspace.google.com/" },
        { name: "Slack", note: "Workplace messaging", url: "https://app.slack.com/" },
        { name: "Microsoft Teams", note: "Meetings and workplace communication", url: "https://teams.microsoft.com/" }
      ]
    }
  ];

  const safe = value => String(value ?? "").replace(/[&<>"']/g, c => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[c]));
  const readCustom = () => {
    try {
      const value = JSON.parse(localStorage.getItem(CUSTOM_KEY) || "[]");
      return Array.isArray(value) ? value.filter(item => item?.name && item?.url) : [];
    } catch (_) { return []; }
  };
  const saveCustom = items => { try { localStorage.setItem(CUSTOM_KEY, JSON.stringify(items)); } catch (_) {} };
  const normalizeURL = raw => {
    const text = String(raw || "").trim();
    if (!text) return "";
    try {
      const url = new URL(/^https?:\/\//i.test(text) ? text : `https://${text}`);
      return /^https?:$/.test(url.protocol) ? url.href : "";
    } catch (_) { return ""; }
  };
  const launch = url => {
    const safeURL = normalizeURL(url);
    if (!safeURL) return;
    const opened = window.open(safeURL, "_blank", "noopener,noreferrer");
    if (!opened) window.location.href = safeURL;
  };

  const styles = document.createElement("style");
  styles.id = "lifeRouteResourceHubStyles";
  styles.textContent = `
    .tabs{grid-template-columns:repeat(4,1fr)!important}.resourceHero{margin-bottom:14px}.resourceSearch{display:grid;grid-template-columns:1fr auto;gap:8px;margin-top:12px}.resourceGroup{margin-top:18px}.resourceGrid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:9px}.resourceCard{margin:0!important;display:grid;grid-template-columns:42px 1fr auto;gap:10px;align-items:center}.resourceMark{width:42px;height:42px;border-radius:13px;display:grid;place-items:center;background:color-mix(in srgb,var(--blue) 8%,var(--panel2));border:1px solid var(--line);font-size:12px;font-weight:1000;color:var(--gold)}.resourceCard .title{font-size:13px}.resourceCard .meta{font-size:9px}.resourceLaunch{padding:8px 10px!important;white-space:nowrap}.resourceCustom{margin-top:18px}.resourceCustomForm{display:grid;grid-template-columns:1fr 1.4fr auto;gap:8px;align-items:end}.resourceEmpty{grid-column:1/-1;padding:18px;text-align:center;color:var(--muted);border:1px dashed var(--line);border-radius:15px}.resourceRemove{padding:7px 9px!important}.resourcePill{font-size:8px;text-transform:uppercase;letter-spacing:.08em;color:var(--gold);font-weight:950;margin-bottom:3px}
    @media(max-width:680px){.tabs{grid-template-columns:repeat(4,minmax(0,1fr))!important}.tab{font-size:10px!important;padding:9px 4px!important}.resourceGrid{grid-template-columns:1fr}.resourceCard{grid-template-columns:38px 1fr auto}.resourceMark{width:38px;height:38px}.resourceCustomForm{grid-template-columns:1fr}.resourceCustomForm button{width:100%}}
  `;
  document.head.appendChild(styles);

  const ensureView = () => {
    const tabs = document.querySelector(".tabs");
    const setupTab = tabs?.querySelector('.tab[data-view="setup"]');
    if (tabs && !tabs.querySelector('.tab[data-view="resources"]')) {
      const button = document.createElement("button");
      button.className = "tab";
      button.dataset.view = "resources";
      button.textContent = "Resources";
      if (setupTab) tabs.insertBefore(button, setupTab); else tabs.appendChild(button);
      button.onclick = () => typeof window.showView === "function" ? window.showView("resources") : null;
    }

    if (document.getElementById("resources")) return;
    const setup = document.getElementById("setup");
    if (!setup?.parentNode) return;
    const section = document.createElement("section");
    section.id = "resources";
    section.className = "view";
    section.innerHTML = `
      <div class="hero resourceHero">
        <div class="small" style="color:var(--gold);font-weight:950;letter-spacing:.11em">WORK RESOURCE HUB</div>
        <h2>Open the portal you need.</h2>
        <p>LifeRoute does not sign in to these services or store their credentials. These buttons simply launch the official portal or website.</p>
        <div class="resourceSearch"><input id="resourceSearch" type="search" placeholder="Search payroll, data collection, EVV…"><button class="secondary" id="resourceClear">Clear</button></div>
      </div>
      <div id="resourceGroups"></div>
      <div class="card resourceCustom">
        <div class="title">Add your own resource</div>
        <div class="meta">Save a company-specific portal or subdomain on this device.</div>
        <div class="resourceCustomForm" style="margin-top:10px">
          <div><label>Name</label><input id="customResourceName" placeholder="Company portal"></div>
          <div><label>Web address</label><input id="customResourceURL" inputmode="url" placeholder="https://…"></div>
          <button class="goldButton" id="addCustomResource" type="button">Add</button>
        </div>
      </div>`;
    setup.parentNode.insertBefore(section, setup);
  };

  const initials = name => String(name || "LR").split(/\s+/).filter(Boolean).slice(0,2).map(part => part[0]).join("").toUpperCase();
  const render = () => {
    ensureView();
    const host = document.getElementById("resourceGroups");
    if (!host) return;
    const query = String(document.getElementById("resourceSearch")?.value || "").trim().toLowerCase();
    const custom = readCustom();
    const groups = [...RESOURCE_GROUPS, ...(custom.length ? [{ id:"custom", title:"My Resources", subtitle:"Links you saved on this device.", items:custom.map(item => ({...item, custom:true})) }] : [])];
    host.innerHTML = groups.map(group => {
      const matches = group.items.filter(item => !query || `${item.name} ${item.note || ""} ${group.title}`.toLowerCase().includes(query));
      if (!matches.length && query) return "";
      return `<div class="resourceGroup"><div class="sectionHead"><div><h2>${safe(group.title)}</h2><div class="hint">${safe(group.subtitle)}</div></div></div><div class="resourceGrid">${matches.length ? matches.map(item => `
        <div class="card resourceCard" data-resource-url="${safe(item.url)}">
          <div class="resourceMark">${safe(initials(item.name))}</div>
          <div class="grow"><div class="resourcePill">${safe(group.id === "finance" ? "Finance / HR" : group.id === "clinical" ? "Clinical" : group.id === "other" ? "Work portal" : "Saved")}</div><div class="title">${safe(item.name)}</div><div class="meta">${safe(item.note || "Saved resource")}</div></div>
          <div style="display:grid;gap:5px"><button class="secondary resourceLaunch" type="button" data-launch-resource="${safe(item.url)}">Launch ↗</button>${item.custom ? `<button class="danger resourceRemove" type="button" data-remove-resource="${safe(item.id || item.url)}">Remove</button>` : ""}</div>
        </div>`).join("") : '<div class="resourceEmpty">No matching resources.</div>'}</div></div>`;
    }).join("") || '<div class="resourceEmpty">No resources match that search.</div>';

    host.querySelectorAll("[data-launch-resource]").forEach(button => button.onclick = () => launch(button.dataset.launchResource));
    host.querySelectorAll("[data-remove-resource]").forEach(button => button.onclick = () => {
      const key = button.dataset.removeResource;
      saveCustom(readCustom().filter(item => String(item.id || item.url) !== key));
      render();
    });
  };

  const wire = () => {
    ensureView();
    const search = document.getElementById("resourceSearch");
    if (search && search.dataset.wired !== "1") {
      search.dataset.wired = "1";
      search.addEventListener("input", render);
    }
    const clear = document.getElementById("resourceClear");
    if (clear && clear.dataset.wired !== "1") {
      clear.dataset.wired = "1";
      clear.onclick = () => { if (search) search.value = ""; render(); };
    }
    const add = document.getElementById("addCustomResource");
    if (add && add.dataset.wired !== "1") {
      add.dataset.wired = "1";
      add.onclick = () => {
        const name = String(document.getElementById("customResourceName")?.value || "").trim();
        const url = normalizeURL(document.getElementById("customResourceURL")?.value || "");
        if (!name || !url) return alert("Add a resource name and a valid web address.");
        const items = readCustom();
        items.push({ id:`custom-${Date.now()}`, name, note:"Custom company resource", url });
        saveCustom(items);
        document.getElementById("customResourceName").value = "";
        document.getElementById("customResourceURL").value = "";
        render();
      };
    }
    render();
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", () => setTimeout(wire, 300), { once:true });
  else setTimeout(wire, 300);
  [700, 1400, 2600].forEach(delay => setTimeout(wire, delay));
})();