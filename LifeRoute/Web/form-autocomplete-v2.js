// LifeRoute context-aware form autocomplete v2.
// Adds suggestions to safe text/search fields across the app. Address fields stay
// owned by MapKit address-autocomplete-v1. Sensitive clinical/auth free text is never
// persisted into suggestion history. Resource search can also request live web suggestions.
(() => {
  if (window.__lifeRouteFormAutocompleteV2Loaded) return;
  window.__lifeRouteFormAutocompleteV2Loaded = true;

  const STORE = 'liferoute_form_suggestions_v2';
  const WEB_FIELDS = new Set(['resourceSearch']);
  const SAFE_TYPES = new Set(['text','search','url','email','tel']);
  const SENSITIVE = /\b(pin|password|passcode|secret|note|notes|documentation|clinical|behavior|session note|comment|message|description|first2|last2)\b/i;
  const ADDRESS = /\b(address|street|location|destination|origin|searchable place|service location)\b/i;
  let overlay = null;
  let activeInput = null;
  let debounceTimer = 0;
  let requestSerial = 0;
  let activeRequestID = '';
  let remoteItems = [];
  let browserController = null;

  const clean = value => String(value ?? '').trim();
  const signal = input => [input.id,input.name,input.placeholder,input.getAttribute('aria-label'),input.closest('label')?.textContent,input.parentElement?.querySelector(':scope > label')?.textContent].filter(Boolean).join(' ');
  const fieldKey = input => clean(input.id || input.name || signal(input)).toLowerCase().replace(/[^a-z0-9]+/g,'-').replace(/^-|-$/g,'').slice(0,64) || 'field';
  const isSensitive = input => input.closest?.('#lifeRouteAuthGate') || SENSITIVE.test(signal(input)) || input.matches?.('[autocomplete="one-time-code"],[autocomplete="current-password"],[autocomplete="new-password"]');
  const isAddress = input => input.dataset.lrAddressAutocomplete === '1' || ADDRESS.test(signal(input));

  const loadRecent = () => {
    try {
      const parsed = JSON.parse(localStorage.getItem(STORE) || '{}');
      return parsed && typeof parsed === 'object' ? parsed : {};
    } catch (_) { return {}; }
  };
  let recent = loadRecent();
  const saveRecent = () => { try { localStorage.setItem(STORE, JSON.stringify(recent)); } catch (_) {} };

  const remember = input => {
    if (!input || isSensitive(input) || isAddress(input)) return;
    const value = clean(input.value);
    if (value.length < 2 || value.length > 100) return;
    const key = fieldKey(input);
    const values = Array.isArray(recent[key]) ? recent[key] : [];
    recent[key] = [value, ...values.filter(item => item.toLowerCase() !== value.toLowerCase())].slice(0,8);
    saveRecent();
  };

  const visualLabels = () => {
    try {
      const state = JSON.parse(localStorage.getItem('liferoute_visual_tools_v2') || '{}');
      return Array.isArray(state.icons) ? state.icons.map(item => clean(item?.label)).filter(Boolean) : [];
    } catch (_) { return []; }
  };
  const customResourceNames = () => {
    try {
      const items = JSON.parse(localStorage.getItem('liferoute_custom_resources_v1') || '[]');
      return Array.isArray(items) ? items.map(item => clean(item?.name)).filter(Boolean) : [];
    } catch (_) { return []; }
  };
  const semanticCandidates = input => {
    const id = input.id || '';
    const values = [];
    if (/placeName/i.test(id)) values.push(...(Array.isArray(window.places) ? window.places.map(item => clean(item?.name)) : []));
    if (/fTitle|appointment.*title|event.*title/i.test(id)) values.push(...(Array.isArray(window.events) ? window.events.map(item => clean(item?.title)) : []));
    if (/visualIconLabel|firstThenFirst|firstThenThen|visualScheduleStepText/i.test(id)) values.push(...visualLabels());
    if (/resource/i.test(id)) {
      document.querySelectorAll('.resourceCard .title').forEach(node => values.push(clean(node.textContent)));
      values.push(...customResourceNames(), 'ADP','CentralReach','RethinkBH','Theralytics','Motivity','Workday','Paycom','Paylocity','UKG','Relias','HHAeXchange','Sandata');
    }
    return values.filter(Boolean);
  };

  const candidates = input => {
    const key = fieldKey(input);
    const combined = [...semanticCandidates(input), ...(Array.isArray(recent[key]) ? recent[key] : [])];
    const seen = new Set();
    return combined.filter(value => {
      const lowered = value.toLowerCase();
      if (!value || seen.has(lowered)) return false;
      seen.add(lowered);
      return true;
    });
  };

  const ensureOverlay = () => {
    if (overlay) return overlay;
    overlay = document.createElement('div');
    overlay.id = 'lifeRouteFormAutocomplete';
    overlay.className = 'lrFormAutocomplete';
    overlay.hidden = true;
    document.body.appendChild(overlay);
    return overlay;
  };

  const installStyles = () => {
    if (document.getElementById('lifeRouteFormAutocompleteV2Styles')) return;
    const style = document.createElement('style');
    style.id = 'lifeRouteFormAutocompleteV2Styles';
    style.textContent = `
      .lrFormAutocomplete{position:fixed;z-index:44980;max-height:min(310px,44vh);overflow:auto;padding:6px;border-radius:16px;background:color-mix(in srgb,var(--panel) 94%,#07111f 6%);border:1px solid color-mix(in srgb,var(--blue) 22%,var(--line));box-shadow:inset 0 1px rgba(255,255,255,.08),0 22px 60px rgba(0,0,0,.34);backdrop-filter:blur(18px) saturate(118%);-webkit-backdrop-filter:blur(18px) saturate(118%)}
      .lrResourceWebSearchBar{display:none;margin-top:7px}.lrResourceWebSearchBar.show{display:block}.lrResourceWebSearchButton{width:100%;min-height:40px!important;text-align:left!important;display:flex!important;align-items:center!important;justify-content:space-between!important;background:color-mix(in srgb,var(--panel2) 62%,transparent)!important;border:1px solid var(--line)!important}
      .lrFormAutocomplete[hidden]{display:none!important}.lrFormSuggestion{width:100%;min-height:43px!important;padding:9px 10px!important;border-radius:11px!important;background:transparent!important;color:var(--text)!important;border:0!important;text-align:left!important;display:flex!important;align-items:center;justify-content:space-between;gap:10px}.lrFormSuggestion:active{background:color-mix(in srgb,var(--blue) 10%,var(--panel2))!important}.lrFormSuggestionText{min-width:0}.lrFormSuggestionText b{display:block;font-size:11px;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}.lrFormSuggestionText span{display:block;font-size:8.5px;color:var(--muted);margin-top:2px}.lrFormSuggestionGlyph{font-size:14px;color:var(--gold);flex:0 0 auto}.lrFormSuggestion.webSearch{margin-top:3px;border-top:1px solid var(--line)!important;border-radius:0 0 11px 11px!important}.lrFormAutocompleteEmpty{padding:10px;font-size:9px;color:var(--muted)}
    `;
    document.head.appendChild(style);
  };

  const hide = () => {
    if (overlay) overlay.hidden = true;
    activeRequestID = '';
    remoteItems = [];
  };
  const position = () => {
    if (!activeInput || !overlay || overlay.hidden) return;
    const rect = activeInput.getBoundingClientRect();
    const pad = 8;
    const width = Math.max(220, Math.min(Math.max(rect.width,260), window.innerWidth - pad * 2));
    overlay.style.width = `${width}px`;
    overlay.style.left = `${Math.max(pad, Math.min(rect.left, window.innerWidth - width - pad))}px`;
    const below = window.innerHeight - rect.bottom - pad;
    if (below >= 150 || rect.top < below) {
      overlay.style.top = `${rect.bottom + 6}px`;
      overlay.style.bottom = 'auto';
    } else {
      overlay.style.top = 'auto';
      overlay.style.bottom = `${Math.max(pad, window.innerHeight - rect.top + 6)}px`;
    }
  };

  const isWebField = input => WEB_FIELDS.has(input.id) || input.dataset.lrWebAutocomplete === '1';
  const openWebSearch = query => {
    const text = clean(query);
    if (!text) return;
    const url = `https://duckduckgo.com/?q=${encodeURIComponent(text)}`;
    try {
      if (typeof window.postNative === 'function' && window.webkit?.messageHandlers?.lifeRoute?.postMessage) {
        if (window.postNative({ action:'openExternalURL', url })) return;
      }
    } catch (_) {}
    const opened = window.open(url, '_blank', 'noopener,noreferrer');
    if (!opened) window.location.href = url;
  };

  const updateResourceWebSearch = input => {
    if (input?.id !== 'resourceSearch') return;
    const searchRow = input.closest('.resourceSearch');
    if (!searchRow) return;
    let bar = document.getElementById('lifeRouteResourceWebSearchBar');
    if (!bar) {
      bar = document.createElement('div');
      bar.id = 'lifeRouteResourceWebSearchBar';
      bar.className = 'lrResourceWebSearchBar';
      const button = document.createElement('button');
      button.type = 'button';
      button.className = 'secondary lrResourceWebSearchButton';
      button.innerHTML = '<span></span><span aria-hidden="true">↗</span>';
      button.addEventListener('click', () => openWebSearch(input.value));
      bar.appendChild(button);
      searchRow.insertAdjacentElement('afterend', bar);
    }
    const query = clean(input.value);
    const label = bar.querySelector('button span');
    if (label) label.textContent = query ? `Search the web for “${query}”` : 'Search the web';
    bar.classList.toggle('show', query.length >= 2);
  };

  const choose = item => {
    if (!activeInput) return;
    if (item.action === 'web-search') {
      openWebSearch(item.value || activeInput.value);
      hide();
      return;
    }
    const value = clean(item.value || item.label);
    if (!value) return;
    activeInput.value = value;
    activeInput.dispatchEvent(new Event('input', { bubbles:true }));
    activeInput.dispatchEvent(new Event('change', { bubbles:true }));
    remember(activeInput);
    hide();
  };

  const render = input => {
    if (!input || input !== activeInput) return;
    const query = clean(input.value);
    if (query.length < 1) return hide();
    const q = query.toLowerCase();
    const local = candidates(input)
      .filter(value => value.toLowerCase().includes(q) && value.toLowerCase() !== q)
      .sort((a,b) => (a.toLowerCase().startsWith(q) ? -1 : 0) - (b.toLowerCase().startsWith(q) ? -1 : 0))
      .slice(0,5)
      .map(value => ({ value, label:value, source:'LifeRoute' }));
    const remote = remoteItems
      .filter(value => clean(value).toLowerCase().includes(q) && clean(value).toLowerCase() !== q)
      .slice(0,5)
      .map(value => ({ value, label:value, source:'Web suggestion' }));
    const merged = [];
    const seen = new Set();
    [...local,...remote].forEach(item => {
      const key = item.value.toLowerCase();
      if (!seen.has(key) && merged.length < 6) { seen.add(key); merged.push(item); }
    });
    if (isWebField(input)) merged.push({ action:'web-search', value:query, label:`Search the web for “${query}”`, source:'DuckDuckGo' });
    if (!merged.length) return hide();

    const host = ensureOverlay();
    host.innerHTML = '';
    merged.forEach(item => {
      const button = document.createElement('button');
      button.type = 'button';
      button.className = `lrFormSuggestion${item.action === 'web-search' ? ' webSearch' : ''}`;
      const copy = document.createElement('span');
      copy.className = 'lrFormSuggestionText';
      const title = document.createElement('b');
      title.textContent = item.label;
      const meta = document.createElement('span');
      meta.textContent = item.source || 'Suggestion';
      copy.append(title,meta);
      const glyph = document.createElement('span');
      glyph.className = 'lrFormSuggestionGlyph';
      glyph.textContent = item.action === 'web-search' ? '↗' : '›';
      button.append(copy,glyph);
      button.addEventListener('pointerdown', event => { event.preventDefault(); choose(item); });
      host.appendChild(button);
    });
    host.hidden = false;
    position();
  };

  const browserWebSuggestions = async (query, requestID) => {
    if (browserController) browserController.abort();
    browserController = new AbortController();
    const timer = setTimeout(() => browserController?.abort(), 6500);
    try {
      const response = await fetch(`https://duckduckgo.com/ac/?q=${encodeURIComponent(query)}&type=list`, { signal:browserController.signal });
      if (!response.ok) return;
      const data = await response.json();
      if (requestID !== activeRequestID) return;
      remoteItems = (Array.isArray(data) ? data : []).map(item => clean(item?.phrase || item)).filter(Boolean).slice(0,6);
      render(activeInput);
    } catch (_) {} finally { clearTimeout(timer); }
  };

  const requestWebSuggestions = (input, query) => {
    if (!isWebField(input) || query.length < 2) return;
    const requestID = `web-${Date.now()}-${++requestSerial}`;
    activeRequestID = requestID;
    remoteItems = [];
    const hasNative = !!window.webkit?.messageHandlers?.lifeRoute?.postMessage;
    if (hasNative && typeof window.postNative === 'function' && window.postNative({ action:'webAutocomplete', query, requestID, context:fieldKey(input) })) return;
    browserWebSuggestions(query, requestID);
  };

  const search = input => {
    activeInput = input;
    remoteItems = [];
    clearTimeout(debounceTimer);
    const query = clean(input.value);
    if (!query) return hide();
    render(input);
    debounceTimer = setTimeout(() => requestWebSuggestions(input, query), 190);
  };

  const autocompleteAttribute = input => {
    const text = signal(input);
    if (isSensitive(input)) return 'off';
    if (ADDRESS.test(text)) return 'street-address';
    if (/e-?mail/i.test(text)) return 'email';
    if (/phone|mobile|telephone/i.test(text)) return 'tel';
    if (/url|web address|website/i.test(text)) return 'url';
    if (/organization|company|employer/i.test(text)) return 'organization';
    return input.type === 'search' ? 'off' : 'on';
  };

  const eligible = input => {
    if (!(input instanceof HTMLInputElement)) return false;
    const type = String(input.type || 'text').toLowerCase();
    return SAFE_TYPES.has(type) && !isSensitive(input) && !isAddress(input);
  };

  const attach = input => {
    if (!(input instanceof HTMLInputElement) || input.dataset.lrFormAutocomplete === '1') return;
    input.dataset.lrFormAutocomplete = '1';
    const attr = autocompleteAttribute(input);
    if (!isAddress(input)) input.setAttribute('autocomplete', attr);
    if (!eligible(input)) return;
    input.addEventListener('input', () => { search(input); updateResourceWebSearch(input); });
    input.addEventListener('focus', () => { activeInput = input; if (clean(input.value)) search(input); updateResourceWebSearch(input); });
    input.addEventListener('change', () => remember(input));
    input.addEventListener('blur', () => setTimeout(() => { if (document.activeElement !== input) hide(); }, 130));
    updateResourceWebSearch(input);
  };

  const scan = root => {
    if (root instanceof HTMLInputElement) attach(root);
    root?.querySelectorAll?.('input').forEach(attach);
  };

  const previousNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithWebAutocomplete(evt) {
    if (typeof previousNativeEvent === 'function') previousNativeEvent(evt);
    if (evt?.type !== 'webAutocompleteResults' || String(evt.requestID || '') !== activeRequestID) return;
    remoteItems = (Array.isArray(evt.results) ? evt.results : []).map(item => clean(item?.phrase || item?.label || item)).filter(Boolean).slice(0,6);
    render(activeInput);
  };

  document.addEventListener('keydown', event => { if (event.key === 'Escape') hide(); }, true);
  window.addEventListener('resize', position, { passive:true });
  window.addEventListener('scroll', position, { passive:true, capture:true });
  let queued = false;
  const queueScan = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => { queued = false; scan(document); });
  };
  const start = () => {
    installStyles();
    ensureOverlay();
    scan(document);
    new MutationObserver(queueScan).observe(document.body, { childList:true, subtree:true });
    window.LifeRouteFormAutocompleteV2 = { scan, hide, remember, openWebSearch };
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', start, { once:true });
  else start();
})();
