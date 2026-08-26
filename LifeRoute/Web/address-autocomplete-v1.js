// App-wide address autocomplete for LifeRoute.
// Native builds use MapKit via the WKWebView bridge. Browser preview falls back to Nominatim.
(() => {
  if (window.__lifeRouteAddressAutocompleteV1Loaded) return;
  window.__lifeRouteAddressAutocompleteV1Loaded = true;

  let sequence = 0;
  let activeInput = null;
  let activeRequestID = "";
  let debounceTimer = 0;
  let webController = null;
  let overlay = null;
  let lastQuery = "";

  const clean = value => String(value || "").trim();
  const isNative = () => !!window.webkit?.messageHandlers?.lifeRoute;
  const looksLikeAddress = input => {
    if (!(input instanceof HTMLInputElement)) return false;
    const type = String(input.type || "text").toLowerCase();
    if (!["text", "search", "url"].includes(type)) return false;
    if (input.closest?.("#lifeRouteAuthGate")) return false;
    const signal = [input.id, input.name, input.placeholder, input.getAttribute("aria-label"), input.getAttribute("autocomplete")].filter(Boolean).join(" ");
    return /\b(address|street|location|destination|origin|searchable place|service location)\b/i.test(signal);
  };

  const ensureOverlay = () => {
    if (overlay) return overlay;
    overlay = document.createElement("div");
    overlay.id = "lifeRouteAddressAutocomplete";
    overlay.className = "lrAddressAutocomplete";
    overlay.hidden = true;
    document.body.appendChild(overlay);
    return overlay;
  };

  const installStyles = () => {
    if (document.getElementById("lifeRouteAddressAutocompleteStyles")) return;
    const style = document.createElement("style");
    style.id = "lifeRouteAddressAutocompleteStyles";
    style.textContent = `
      .lrAddressAutocomplete{position:fixed;z-index:45000;max-height:min(300px,42vh);overflow:auto;padding:6px;border-radius:15px;background:color-mix(in srgb,var(--panel) 96%,#07111f 4%);border:1px solid color-mix(in srgb,var(--blue) 24%,var(--line));box-shadow:0 22px 60px rgba(0,0,0,.34);backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px)}
      .lrAddressAutocomplete[hidden]{display:none!important}.lrAddressSuggestion{width:100%;display:block;text-align:left;background:transparent;color:var(--text);border:0;border-radius:11px;padding:10px 11px;min-height:44px}.lrAddressSuggestion:active,.lrAddressSuggestion:hover{background:color-mix(in srgb,var(--blue) 10%,var(--panel2))}.lrAddressSuggestion b{display:block;font-size:12px;line-height:1.3}.lrAddressSuggestion span{display:block;margin-top:2px;font-size:9px;line-height:1.35;color:var(--muted)}.lrAddressEmpty{padding:10px 11px;font-size:10px;color:var(--muted)}
    `;
    document.head.appendChild(style);
  };

  const hide = () => {
    if (overlay) overlay.hidden = true;
    activeRequestID = "";
  };

  const position = () => {
    if (!activeInput || !overlay || overlay.hidden) return;
    const rect = activeInput.getBoundingClientRect();
    const pad = 8;
    const width = Math.max(220, Math.min(rect.width, window.innerWidth - pad * 2));
    let left = Math.max(pad, Math.min(rect.left, window.innerWidth - width - pad));
    let top = rect.bottom + 6;
    overlay.style.width = `${width}px`;
    overlay.style.left = `${left}px`;
    overlay.style.top = `${top}px`;
    const after = window.innerHeight - top - pad;
    const before = rect.top - pad;
    if (after < 150 && before > after) {
      overlay.style.top = "auto";
      overlay.style.bottom = `${Math.max(pad, window.innerHeight - rect.top + 6)}px`;
    } else {
      overlay.style.bottom = "auto";
    }
  };

  const choose = item => {
    if (!activeInput) return;
    const value = clean(item?.address || item?.title || item?.label);
    if (!value) return;
    activeInput.value = value;
    activeInput.dataset.lrAutocompleteSelected = "1";
    activeInput.dispatchEvent(new Event("input", { bubbles: true }));
    activeInput.dispatchEvent(new Event("change", { bubbles: true }));
    setTimeout(() => { if (activeInput) delete activeInput.dataset.lrAutocompleteSelected; }, 0);
    hide();
  };

  const render = items => {
    const host = ensureOverlay();
    const list = Array.isArray(items) ? items.filter(item => clean(item?.address || item?.title || item?.label)).slice(0, 6) : [];
    if (!activeInput || !list.length) return hide();
    host.innerHTML = "";
    list.forEach(item => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "lrAddressSuggestion";
      const title = clean(item.title || item.address || item.label);
      const subtitle = clean(item.subtitle || (item.address && item.address !== title ? item.address : ""));
      const b = document.createElement("b");
      b.textContent = title;
      button.appendChild(b);
      if (subtitle) {
        const span = document.createElement("span");
        span.textContent = subtitle;
        button.appendChild(span);
      }
      button.addEventListener("pointerdown", event => {
        event.preventDefault();
        choose(item);
      });
      host.appendChild(button);
    });
    host.hidden = false;
    position();
  };

  const browserSearch = async (query, requestID) => {
    if (webController) webController.abort();
    webController = new AbortController();
    const timer = setTimeout(() => webController?.abort(), 7000);
    try {
      const url = `https://nominatim.openstreetmap.org/search?format=jsonv2&addressdetails=1&limit=6&countrycodes=us&q=${encodeURIComponent(query)}`;
      const response = await fetch(url, { signal: webController.signal, headers: { "Accept-Language": "en-US,en;q=0.9" } });
      if (!response.ok) throw new Error(`HTTP ${response.status}`);
      const data = await response.json();
      if (requestID !== activeRequestID) return;
      render((Array.isArray(data) ? data : []).map(item => ({
        title: clean(item?.name || String(item?.display_name || "").split(",")[0]),
        subtitle: clean(item?.display_name),
        address: clean(item?.display_name)
      })));
    } catch (_) {
      if (requestID === activeRequestID) hide();
    } finally {
      clearTimeout(timer);
    }
  };

  const search = input => {
    const query = clean(input.value);
    activeInput = input;
    lastQuery = query;
    clearTimeout(debounceTimer);
    if (query.length < 3) return hide();
    debounceTimer = setTimeout(() => {
      const requestID = `addr-${Date.now()}-${++sequence}`;
      activeRequestID = requestID;
      if (isNative() && typeof window.postNative === "function" && window.postNative({ action: "addressAutocomplete", query, requestID })) return;
      browserSearch(query, requestID);
    }, 180);
  };

  const attach = input => {
    if (!looksLikeAddress(input) || input.dataset.lrAddressAutocomplete === "1") return;
    input.dataset.lrAddressAutocomplete = "1";
    input.setAttribute("autocomplete", "street-address");
    input.addEventListener("input", () => search(input));
    input.addEventListener("focus", () => {
      activeInput = input;
      if (clean(input.value).length >= 3 && clean(input.value) !== lastQuery) search(input);
    });
    input.addEventListener("blur", () => setTimeout(() => {
      if (document.activeElement !== input) hide();
    }, 120));
  };

  const scan = root => {
    if (root instanceof HTMLInputElement) attach(root);
    root?.querySelectorAll?.("input").forEach(attach);
  };

  const previousNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithAddressAutocomplete(evt) {
    if (typeof previousNativeEvent === "function") previousNativeEvent(evt);
    if (evt?.type !== "addressAutocompleteResults") return;
    if (String(evt.requestID || "") !== activeRequestID) return;
    render(evt.results || []);
  };

  document.addEventListener("keydown", event => { if (event.key === "Escape") hide(); }, true);
  window.addEventListener("resize", position, { passive: true });
  window.addEventListener("scroll", position, { passive: true, capture: true });

  let scanQueued = false;
  const queueScan = () => {
    if (scanQueued) return;
    scanQueued = true;
    requestAnimationFrame(() => {
      scanQueued = false;
      scan(document);
    });
  };

  const start = () => {
    installStyles();
    ensureOverlay();
    scan(document);
    new MutationObserver(queueScan).observe(document.body, { childList: true, subtree: true });
  };

  window.LifeRouteAddressAutocompleteV1 = { scan, hide };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();