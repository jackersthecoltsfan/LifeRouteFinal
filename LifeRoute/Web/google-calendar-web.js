// LifeRoute web-only Google Calendar OAuth + read-only sync.
// Uses Google Identity Services access tokens in memory. The OAuth client ID is
// public configuration and may be stored locally; access tokens are never
// persisted to localStorage.
(() => {
  if (window.__lifeRouteGoogleCalendarWebLoaded) return;
  window.__lifeRouteGoogleCalendarWebLoaded = true;

  const CLIENT_KEY = "liferoute_google_web_client_id_v1";
  const SCOPES = "https://www.googleapis.com/auth/calendar.readonly";
  const GOOGLE_SCRIPT = "https://accounts.google.com/gsi/client";
  const ORIGIN = "https://jackersthecoltsfan.github.io";

  let accessToken = "";
  let tokenExpiresAt = 0;
  let tokenClient = null;
  let googleScriptPromise = null;
  let connectedEmail = "";
  let syncInFlight = false;

  const esc = value => String(value ?? "").replace(/[&<>"']/g, ch => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;"
  })[ch]);

  const hasValidToken = () => !!accessToken && Date.now() < tokenExpiresAt - 30000;

  const savedClientID = () => {
    const configured = String(window.LifeRouteConfig?.googleCalendar?.clientId || "").trim();
    if (configured) return configured;
    try { return String(localStorage.getItem(CLIENT_KEY) || "").trim(); } catch (_) { return ""; }
  };

  const saveClientID = value => {
    try {
      if (value) localStorage.setItem(CLIENT_KEY, value);
      else localStorage.removeItem(CLIENT_KEY);
    } catch (_) {}
  };

  const clientIDLooksValid = value => /^[0-9]+-[a-z0-9._-]+\.apps\.googleusercontent\.com$/i.test(String(value || "").trim());

  const setStatus = (message, kind = "") => {
    const host = document.getElementById("googleWebStatus");
    if (host) {
      host.textContent = message;
      host.dataset.kind = kind;
    }
    const badge = document.getElementById("googleStatus");
    if (badge) {
      badge.textContent = kind === "connected" ? "CONNECTED" : kind === "loading" ? "SYNCING" : "READY";
      badge.className = `badge ${kind === "connected" ? "green" : kind === "loading" ? "gold" : ""}`;
    }
  };

  const loadGoogleScript = () => {
    if (window.google?.accounts?.oauth2) return Promise.resolve();
    if (googleScriptPromise) return googleScriptPromise;
    googleScriptPromise = new Promise((resolve, reject) => {
      const existing = document.querySelector(`script[src^="${GOOGLE_SCRIPT}"]`);
      if (existing) {
        const timer = setInterval(() => {
          if (window.google?.accounts?.oauth2) {
            clearInterval(timer);
            resolve();
          }
        }, 100);
        setTimeout(() => {
          clearInterval(timer);
          if (window.google?.accounts?.oauth2) resolve();
          else reject(new Error("Google sign-in library did not finish loading."));
        }, 10000);
        return;
      }
      const script = document.createElement("script");
      script.src = GOOGLE_SCRIPT;
      script.async = true;
      script.defer = true;
      script.onload = () => window.google?.accounts?.oauth2 ? resolve() : reject(new Error("Google sign-in library is unavailable."));
      script.onerror = () => reject(new Error("Could not load Google sign-in."));
      document.head.appendChild(script);
    });
    return googleScriptPromise;
  };

  const api = async path => {
    if (!hasValidToken()) throw new Error("Google authorization has expired. Connect again.");
    const response = await fetch(`https://www.googleapis.com/calendar/v3${path}`, {
      headers: { Authorization: `Bearer ${accessToken}` },
      cache: "no-store"
    });
    if (response.status === 401) {
      accessToken = "";
      tokenExpiresAt = 0;
      throw new Error("Google authorization expired. Connect again.");
    }
    if (!response.ok) {
      let detail = "";
      try { detail = (await response.json())?.error?.message || ""; } catch (_) {}
      throw new Error(detail || `Google Calendar returned HTTP ${response.status}.`);
    }
    return response.json();
  };

  const fetchProfile = async () => {
    try {
      const response = await fetch("https://www.googleapis.com/oauth2/v3/userinfo", {
        headers: { Authorization: `Bearer ${accessToken}` },
        cache: "no-store"
      });
      if (!response.ok) return "";
      const profile = await response.json();
      return String(profile.email || "");
    } catch (_) {
      return "";
    }
  };

  const eventRange = () => {
    const now = new Date();
    const min = new Date(now);
    const max = new Date(now);
    min.setDate(min.getDate() - 60);
    max.setFullYear(max.getFullYear() + 1);
    return { timeMin: min.toISOString(), timeMax: max.toISOString() };
  };

  const fetchCalendarEvents = async calendar => {
    const { timeMin, timeMax } = eventRange();
    const items = [];
    let pageToken = "";
    let pages = 0;
    do {
      const params = new URLSearchParams({
        singleEvents: "true",
        orderBy: "startTime",
        showDeleted: "false",
        timeMin,
        timeMax,
        maxResults: "2500"
      });
      if (pageToken) params.set("pageToken", pageToken);
      const data = await api(`/calendars/${encodeURIComponent(calendar.id)}/events?${params}`);
      (data.items || []).forEach(item => {
        if (!item || item.status === "cancelled") return;
        const start = item.start?.dateTime || item.start?.date;
        const end = item.end?.dateTime || item.end?.date || start;
        if (!start || !end) return;
        items.push({
          id: `${calendar.id}:${item.id}`,
          title: item.summary || "Calendar event",
          start,
          end,
          location: item.location || "",
          calendarTitle: calendar.summaryOverride || calendar.summary || "Google Calendar",
          isAllDay: !!item.start?.date && !item.start?.dateTime
        });
      });
      pageToken = String(data.nextPageToken || "");
      pages += 1;
    } while (pageToken && pages < 8);
    return items;
  };

  const syncGoogle = async () => {
    if (syncInFlight) return;
    if (!hasValidToken()) {
      setStatus("Connect Google Calendar to refresh events.");
      return;
    }
    syncInFlight = true;
    setStatus("Reading your Google calendars…", "loading");
    try {
      const list = await api("/users/me/calendarList?showHidden=false&minAccessRole=reader&maxResults=250");
      let calendars = (list.items || []).filter(calendar => calendar && !calendar.deleted && calendar.accessRole !== "freeBusyReader");
      const selected = calendars.filter(calendar => calendar.primary || calendar.selected !== false);
      if (selected.length) calendars = selected;
      calendars = calendars.slice(0, 40);

      const results = await Promise.allSettled(calendars.map(fetchCalendarEvents));
      const incoming = results.flatMap(result => result.status === "fulfilled" ? result.value : []);
      const failed = results.filter(result => result.status === "rejected").length;

      if (typeof window.receiveProviderEvents === "function") {
        window.receiveProviderEvents("google", incoming);
      }
      if (window.prefs?.sources) prefs.sources.google = true;
      try { window.persist?.(); } catch (_) {}
      try { window.renderAll?.(); } catch (_) {}
      cleanWebSources();

      const account = connectedEmail ? ` · ${connectedEmail}` : "";
      setStatus(`${incoming.length} Google event${incoming.length === 1 ? "" : "s"} synced${account}${failed ? ` · ${failed} calendar${failed === 1 ? "" : "s"} unavailable` : ""}.`, "connected");
    } catch (error) {
      setStatus(error?.message || "Could not sync Google Calendar.", "error");
    } finally {
      syncInFlight = false;
    }
  };

  const requestGoogleToken = async ({ forceConsent = false } = {}) => {
    const input = document.getElementById("googleWebClientID");
    const clientId = String(input?.value || savedClientID()).trim();
    if (!clientIDLooksValid(clientId)) {
      setStatus("Add a valid Google OAuth Web Client ID first.", "error");
      document.getElementById("googleWebSetup")?.setAttribute("open", "");
      input?.focus();
      return;
    }
    saveClientID(clientId);
    await loadGoogleScript();

    return new Promise((resolve, reject) => {
      tokenClient = window.google.accounts.oauth2.initTokenClient({
        client_id: clientId,
        scope: SCOPES,
        include_granted_scopes: true,
        callback: async response => {
          if (!response || response.error) {
            const err = new Error(response?.error_description || response?.error || "Google sign-in was cancelled.");
            setStatus(err.message, "error");
            reject(err);
            return;
          }
          accessToken = String(response.access_token || "");
          tokenExpiresAt = Date.now() + Math.max(60, Number(response.expires_in || 3600)) * 1000;
          connectedEmail = await fetchProfile();
          setStatus(`Google connected${connectedEmail ? ` · ${connectedEmail}` : ""}. Syncing events…`, "loading");
          await syncGoogle();
          resolve(response);
        }
      });
      setStatus("Opening Google sign-in…", "loading");
      tokenClient.requestAccessToken({ prompt: forceConsent ? "consent" : "" });
    });
  };

  const disconnectGoogle = () => {
    const oldToken = accessToken;
    accessToken = "";
    tokenExpiresAt = 0;
    connectedEmail = "";
    if (oldToken && window.google?.accounts?.oauth2?.revoke) {
      try { window.google.accounts.oauth2.revoke(oldToken, () => {}); } catch (_) {}
    }
    try { window.receiveProviderEvents?.("google", []); } catch (_) {}
    setStatus("Google Calendar disconnected.");
    cleanWebSources();
  };

  const hideNativeAppleCalendar = () => {
    // Keep Apple/iCloud calendar-link instructions. Hide only the native
    // EventKit integration and native Apple source toggle in the web preview.
    document.querySelectorAll("#setup .integration").forEach(integration => {
      const title = integration.querySelector(".title")?.textContent?.trim() || "";
      if (title === "Apple Calendar") {
        const card = integration.closest(".card");
        if (card) card.style.display = "none";
      }
    });
    const appleToggle = document.getElementById("srcApple")?.closest(".toggleRow");
    if (appleToggle) appleToggle.style.display = "none";
    if (document.getElementById("srcApple")) document.getElementById("srcApple").checked = false;
    if (window.prefs?.sources) prefs.sources.apple = false;

    const inputsHeading = Array.from(document.querySelectorAll("#setup .sectionHead h2")).find(node => /calendar inputs/i.test(node.textContent || ""));
    const hint = inputsHeading?.closest(".sectionHead")?.querySelector(".hint");
    if (hint) hint.textContent = "Google + read-only calendar links";
  };

  const cleanWebSources = () => {
    hideNativeAppleCalendar();
    const source = document.getElementById("activeSources");
    if (source) {
      source.querySelectorAll(".chip").forEach(chip => {
        if (/apple calendar|centralreach/i.test(chip.textContent || "")) chip.remove();
      });
    }
  };

  const mountGoogleCard = () => {
    const googleStatus = document.getElementById("googleStatus");
    const card = googleStatus?.closest(".card");
    if (!card) return false;
    if (card.dataset.googleWebMounted === "1") {
      cleanWebSources();
      return true;
    }
    card.dataset.googleWebMounted = "1";

    const clientId = savedClientID();
    card.innerHTML = `
      <div class="integration">
        <div class="integrationIcon googleWebMark" aria-hidden="true">G</div>
        <div>
          <div class="title">Google Calendar</div>
          <div class="meta">Sign in with Google and sync your calendars directly into the web version. LifeRoute requests read-only Calendar access.</div>
        </div>
        <span class="badge" id="googleStatus">READY</span>
      </div>
      <div class="googleWebActions">
        <button class="primary" type="button" id="googleWebConnect">Connect Google Calendar</button>
        <button class="secondary" type="button" id="googleWebRefresh">Refresh Google</button>
        <button class="secondary" type="button" id="googleWebDisconnect">Disconnect</button>
      </div>
      <div class="googleWebStatus" id="googleWebStatus">${clientId ? "OAuth client saved · ready to connect." : "One-time Google setup is required before the first connection."}</div>
      <details class="googleWebSetup" id="googleWebSetup"${clientId ? "" : " open"}>
        <summary>One-time Google connection setup</summary>
        <div class="googleWebSetupBody">
          <p>Google requires a Web OAuth Client ID for browser calendar access. The Client ID is public configuration; <b>do not create or paste a client secret</b>.</p>
          <ol>
            <li>Open <b>Google Cloud Console</b> and create or select a project.</li>
            <li>Enable the <b>Google Calendar API</b>.</li>
            <li>Configure the OAuth consent screen. If the app is in Testing, add the Google accounts that will test LifeRoute.</li>
            <li>Create <b>Credentials → OAuth client ID → Web application</b>.</li>
            <li>Add this exact Authorized JavaScript origin:<br><code>${ORIGIN}</code></li>
            <li>Copy the Client ID ending in <b>.apps.googleusercontent.com</b> and paste it below.</li>
          </ol>
          <label for="googleWebClientID">Google OAuth Web Client ID</label>
          <input id="googleWebClientID" inputmode="url" autocapitalize="none" autocomplete="off" spellcheck="false" placeholder="1234567890-…apps.googleusercontent.com" value="${esc(clientId)}">
          <div class="googleWebSetupActions">
            <button class="secondary" type="button" id="googleWebSaveClient">Save Client ID</button>
            <button class="secondary" type="button" id="googleWebOpenCloud">Open Google Cloud Console</button>
          </div>
        </div>
      </details>
      <div class="tiny googleWebPrivacy"><b>Read-only:</b> LifeRoute can read event titles, times, locations, and calendar names. It cannot create, edit, or delete Google Calendar events with this connection. Access tokens stay in memory and are cleared when the page session ends.</div>
    `;

    document.getElementById("googleWebConnect")?.addEventListener("click", () => requestGoogleToken({ forceConsent: !hasValidToken() }).catch(() => {}));
    document.getElementById("googleWebRefresh")?.addEventListener("click", async () => {
      if (hasValidToken()) await syncGoogle();
      else requestGoogleToken({ forceConsent: false }).catch(() => {});
    });
    document.getElementById("googleWebDisconnect")?.addEventListener("click", disconnectGoogle);
    document.getElementById("googleWebSaveClient")?.addEventListener("click", () => {
      const value = String(document.getElementById("googleWebClientID")?.value || "").trim();
      if (!clientIDLooksValid(value)) {
        setStatus("That does not look like a Google OAuth Web Client ID.", "error");
        return;
      }
      saveClientID(value);
      tokenClient = null;
      setStatus("Google OAuth Client ID saved · ready to connect.");
    });
    document.getElementById("googleWebOpenCloud")?.addEventListener("click", () => {
      window.open("https://console.cloud.google.com/apis/credentials", "_blank", "noopener,noreferrer");
    });

    // Replace the old scaffold function with the working browser flow.
    window.connectGoogle = () => requestGoogleToken({ forceConsent: !hasValidToken() }).catch(() => {});
    cleanWebSources();
    return true;
  };

  const installStyles = () => {
    if (document.getElementById("googleCalendarWebStyles")) return;
    const style = document.createElement("style");
    style.id = "googleCalendarWebStyles";
    style.textContent = `
      .googleWebMark{font-weight:1000;color:#fff;background:linear-gradient(135deg,#4285f4 0 28%,#34a853 28% 52%,#fbbc05 52% 74%,#ea4335 74% 100%)}
      .googleWebActions,.googleWebSetupActions{display:flex;gap:7px;flex-wrap:wrap;margin-top:11px}.googleWebActions button,.googleWebSetupActions button{font-size:11px;padding:9px 11px}.googleWebStatus{margin-top:10px;padding:9px 10px;border-radius:12px;background:color-mix(in srgb,var(--blue) 7%,var(--panel2));border:1px solid color-mix(in srgb,var(--blue) 18%,var(--line));font-size:10px;line-height:1.45;color:var(--muted)}.googleWebStatus[data-kind="connected"]{color:var(--green);border-color:color-mix(in srgb,var(--green) 35%,var(--line))}.googleWebStatus[data-kind="loading"]{color:var(--gold)}.googleWebStatus[data-kind="error"]{color:var(--red)}
      .googleWebSetup{margin-top:10px;border:1px solid var(--line);border-radius:13px;background:color-mix(in srgb,var(--panel2) 74%,transparent);overflow:hidden}.googleWebSetup summary{cursor:pointer;padding:10px 11px;font-size:10px;font-weight:900;color:var(--text)}.googleWebSetupBody{padding:0 11px 12px;color:var(--muted);font-size:10px;line-height:1.55}.googleWebSetupBody p{margin:0 0 9px}.googleWebSetupBody ol{margin:0 0 11px;padding-left:19px}.googleWebSetupBody li{margin:4px 0}.googleWebSetupBody code{display:inline-block;margin-top:4px;padding:5px 7px;border-radius:7px;background:var(--bg);color:var(--gold);font-size:9px;word-break:break-all}.googleWebPrivacy{margin-top:10px}.googleWebPrivacy b{color:var(--text)}
    `;
    document.head.appendChild(style);
  };

  const wrapRefreshCalendars = () => {
    if (window.refreshCalendars?._lifeRouteGoogleWebWrapped) return;
    const previous = window.refreshCalendars;
    const wrapped = function refreshCalendarsWithGoogleWeb(...args) {
      const result = typeof previous === "function" ? previous.apply(this, args) : undefined;
      if (hasValidToken()) setTimeout(syncGoogle, 140);
      return result;
    };
    wrapped._lifeRouteGoogleWebWrapped = true;
    window.refreshCalendars = wrapped;
  };

  const watchSourceChips = () => {
    const host = document.getElementById("activeSources");
    if (!host || window.__lifeRouteGoogleSourceObserver) return;
    const observer = new MutationObserver(cleanWebSources);
    observer.observe(host, { childList: true, subtree: true });
    window.__lifeRouteGoogleSourceObserver = observer;
  };

  const start = () => {
    installStyles();
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      hideNativeAppleCalendar();
      if (mountGoogleCard()) {
        wrapRefreshCalendars();
        watchSourceChips();
        clearInterval(timer);
      } else if (attempts > 100) {
        clearInterval(timer);
      }
    }, 100);

    [0, 150, 500, 1200].forEach(delay => setTimeout(() => {
      hideNativeAppleCalendar();
      mountGoogleCard();
      cleanWebSources();
      wrapRefreshCalendars();
      watchSourceChips();
    }, delay));
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
