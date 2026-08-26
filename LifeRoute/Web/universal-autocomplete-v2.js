// LifeRoute universal form autocomplete v2.
// Adds local/recent suggestions to appropriate free-text fields and live web
// suggestions to search-oriented fields. Sensitive credentials and PINs are excluded.
(() => {
  if (window.__lifeRouteUniversalAutocompleteV2Loaded) return;
  window.__lifeRouteUniversalAutocompleteV2Loaded = true;

  const STORE = 'liferoute_form_autocomplete_v2';
  const MAX_PER_FIELD = 8;
  let history = {};
  let activeInput = null;
  let overlay = null;
  let webTimer = 0;
  let webController = null;
  let webSequence = 0;

  try {
    const parsed = JSON.parse(localStorage.getItem(STORE) || '{}');
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) history = parsed;
  } catch (_) {}

  const clean = value => String(value || '').trim();
  const sensitive = input => {
    if (!(input instanceof HTMLInputElement) && !(input instanceof HTMLTextAreaElement)) return true;
    if (input.closest?.('#lifeRouteAuthGate')) return true;
    const type = String(input.type || 'text').toLowerCase();
    if (['password','hidden','file','checkbox','radio','range','color','date','datetime-local','time','month','week','number'].includes(type)) return true;
    const signal = [input.id,input.name,input.autocomplete,input.placeholder,input.getAttribute('aria-label')].filter(Boolean).join(' ');
    return /\b(pin|password|passcode|secret|token|api[ -]?key|credential|oauth|auth code)\b/i.test(signal);
  };
  const addressOwned = input => input.dataset.lrAddressAutocomplete === '1' || /street-address/i.test(input.autocomplete || '');
  const eligible = input => !sensitive(input) && !addressOwned(input) && !input.readOnly && !input.disabled;
  const signature = input => clean(input.id || input.name || input.placeholder || input.getAttribute('aria-label') || input.type || 'field').toLowerCase().replace(/[^a-z0-9]+/g,'-').slice(0,64) || 'field';
  const isSearchField = input => {
    const signal = [input.id,input.name,input.placeholder,input.getAttribute('aria-label'),input.type].filter(Boolean).join(' ');
    return input.type === 'search' || /\b(search|find|lookup|resource|portal|website|query)\b/i.test(signal);
  };

  const persistHistory = () => {
    try { localStorage.setItem(STORE,JSON.stringify(history)); } catch (_) {}
  };
  const remember = input => {
    if (!eligible(input)) return;
    const value = clean(input.value);
    if (!value || value.length > 140) return;
    const key = signature(input);
    const next = [value,...(Array.isArray(history[key]) ? history[key] : []).filter(item => item.toLowerCase() !== value.toLowerCase())].slice(0,MAX_PER_FIELD);
    history[key] = next;
    persistHistory();
  };

  const installStyles = () => {
    if (document.getElementById('lifeRouteUniversalAutocompleteStyles')) return;
    const style = document.createElement('style');
    style.id = 'lifeRouteUniversalAutocompleteStyles';
    style.textContent = `
      .lrUniversalAutocomplete{position:fixed;z-index:46000;max-height:min(330px,44vh);overflow:auto;padding:6px;border-radius:16px;background:linear-gradient(155deg,color-mix(in srgb,var(--panel) 94%,#07111f 6%),color-mix(in srgb,var(--panel2) 90%,transparent));border:1px solid color-mix(in srgb,var(--blue) 24%,var(--line));box-shadow:inset 0 1px rgba(255,255,255,.08),0 24px 64px rgba(0,0,0,.36);backdrop-filter:blur(18px) saturate(128%);-webkit-backdrop-filter:blur(18px) saturate(128%)}
      .lrUniversalAutocomplete[hidden]{display:none!important}.lrAutoSection{padding:5px 8px 4px;font-size:8px;font-weight:950;letter-spacing:.1em;text-transform:uppercase;color:var(--muted)}.lrAutoSuggestion{width:100%;min-height:43px!important;display:grid!important;grid-template-columns:22px 1fr auto;align-items:center;gap:8px;text-align:left!important;border:0!important;border-radius:11px!important;padding:8px 9px!important;background:transparent!important;color:var(--text)!important;box-shadow:none!important}.lrAutoSuggestion:active{background:color-mix(in srgb,var(--blue) 9%,var(--panel2))!important}.lrAutoGlyph{width:22px;height:22px;border-radius:8px;display:grid;place-items:center;background:color-mix(in srgb,var(--blue) 8%,var(--panel2));color:var(--gold);font-size:10px;font-weight:950}.lrAutoSuggestion b{font-size:10px;line-height:1.25;white-space:normal}.lrAutoSource{font-size:8px;color:var(--muted);white-space:nowrap}.lrAutoWebAction{color:var(--gold)!important;border-top:1px solid color-mix(in srgb,var(--line) 72%,transparent)!important;margin-top:4px;border-radius:0 0 10px 10px!important}.lrAutoEmpty{padding:10px;font-size:9px;color:var(--muted)}
    `;
    document.head.appendChild(style);
  };

  const ensureOverlay = () => {
    if (overlay) return overlay;
    overlay = document.createElement('div');
    overlay.id = 'lifeRouteUniversalAutocomplete';
    overlay.className = 'lrUniversalAutocomplete';
    overlay.hidden = true;
    document.body.appendChild(overlay);
    return overlay;
  };

  const hide = () => {
    if (overlay) overlay.hidden = true;
    clearTimeout(webTimer);
    if (webController) { try { webController.abort(); } catch (_) {} webController = null; }
  };

  const position = () => {
    if (!activeInput || !overlay || overlay.hidden) return;
    const rect = activeInput.getBoundingClientRect();
    const pad = 8;
    const width = Math.max(220,Math.min(Math.max(rect.width,260),window.innerWidth-pad*2));
    overlay.style.width = `${width}px`;
    overlay.style.left = `${Math.max(pad,Math.min(rect.left,window.innerWidth-width-pad))}px`;
    const below = rect.bottom + 6;
    const after = window.innerHeight - below - pad;
    const before = rect.top - pad;
    if (after < 150 && before > after) {
      overlay.style.top = 'auto';
      overlay.style.bottom = `${Math.max(pad,window.innerHeight-rect.top+6)}px`;
    } else {
      overlay.style.bottom = 'auto';
      overlay.style.top = `${below}px`;
    }
  };

  const setValue = (input,value) => {
    if (!input) return;
    input.value = value;
    input.dispatchEvent(new Event('input',{bubbles:true}));
    input.dispatchEvent(new Event('change',{bubbles:true}));
    remember(input);
    window.LifeRouteLiquidInteractionV4?.haptic?.('selection');
    hide();
  };

  const openWebSearch = query => {
    const q = clean(query);
    if (!q) return;
    window.LifeRouteLiquidInteractionV4?.haptic?.('medium');
    const url = `https://www.google.com/search?q=${encodeURIComponent(q)}`;
    try {
      if (typeof window.postNative === 'function' && window.postNative({action:'openExternalURL',url})) { hide(); return; }
    } catch (_) {}
    try { window.open(url,'_blank','noopener,noreferrer'); } catch (_) { window.location.href = url; }
    hide();
  };

  const builtinSuggestions = input => {
    if (input.id === 'resourceSearch') {
      return [...document.querySelectorAll('.resourceCard .title')].map(node => clean(node.textContent)).filter(Boolean);
    }
    if (/visual|label/i.test(`${input.id} ${input.placeholder}`)) return ['Break','Help','More','Eat','Drink','Bathroom','Outside','All done'];
    if (/task|todo|errand/i.test(`${input.id} ${input.placeholder}`)) return ['Groceries','Pharmacy','Gym','Coffee','Walk','Pickup'];
    return [];
  };

  const dedupe = values => {
    const seen = new Set();
    return values.filter(value => {
      const text = clean(value);
      const key = text.toLowerCase();
      if (!text || seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  };

  const render = (input,web = []) => {
    if (activeInput !== input || !eligible(input)) return hide();
    const host = ensureOverlay();
    const query = clean(input.value).toLowerCase();
    const local = dedupe([...(history[signature(input)] || []),...builtinSuggestions(input)])
      .filter(value => !query || value.toLowerCase().includes(query))
      .slice(0,6);
    const webItems = dedupe(web).filter(value => !local.some(item => item.toLowerCase() === value.toLowerCase())).slice(0,5);
    if (!local.length && !webItems.length && !isSearchField(input)) return hide();

    const chunks = [];
    if (local.length) {
      chunks.push('<div class="lrAutoSection">Suggestions</div>');
      local.forEach(value => chunks.push(`<button type="button" class="lrAutoSuggestion" data-lr-auto-value="${encodeURIComponent(value)}"><span class="lrAutoGlyph">↺</span><b></b><span class="lrAutoSource">Recent</span></button>`));
    }
    if (webItems.length) {
      chunks.push('<div class="lrAutoSection">From the web</div>');
      webItems.forEach(value => chunks.push(`<button type="button" class="lrAutoSuggestion" data-lr-auto-value="${encodeURIComponent(value)}"><span class="lrAutoGlyph">⌕</span><b></b><span class="lrAutoSource">Web</span></button>`));
    }
    if (isSearchField(input) && clean(input.value).length >= 2) {
      chunks.push(`<button type="button" class="lrAutoSuggestion lrAutoWebAction" data-lr-web-search="${encodeURIComponent(clean(input.value))}"><span class="lrAutoGlyph">↗</span><b>Search the web for “${clean(input.value).replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[c]))}”</b><span class="lrAutoSource">Web</span></button>`);
    }
    host.innerHTML = chunks.join('') || '<div class="lrAutoEmpty">Keep typing for suggestions.</div>';
    host.querySelectorAll('[data-lr-auto-value]').forEach(button => {
      const value = decodeURIComponent(button.dataset.lrAutoValue || '');
      const label = button.querySelector('b');
      if (label) label.textContent = value;
      button.addEventListener('pointerdown',event=>{event.preventDefault();setValue(input,value);});
    });
    host.querySelector('[data-lr-web-search]')?.addEventListener('pointerdown',event=>{
      event.preventDefault();
      openWebSearch(decodeURIComponent(event.currentTarget.dataset.lrWebSearch || ''));
    });
    host.hidden = false;
    position();
  };

  const fetchWebSuggestions = async (input,query,sequence) => {
    if (webController) { try { webController.abort(); } catch (_) {} }
    webController = new AbortController();
    const timeout = setTimeout(()=>webController?.abort(),5000);
    try {
      let values = [];
      try {
        const response = await fetch(`https://duckduckgo.com/ac/?q=${encodeURIComponent(query)}&type=list`,{signal:webController.signal,headers:{'Accept':'application/json'}});
        if (response.ok) {
          const data = await response.json();
          if (Array.isArray(data)) values = data.map(item=>clean(item?.phrase || item)).filter(Boolean);
        }
      } catch (_) {}
      if (!values.length) {
        const response = await fetch(`https://en.wikipedia.org/w/api.php?action=opensearch&search=${encodeURIComponent(query)}&limit=6&namespace=0&format=json&origin=*`,{signal:webController.signal});
        if (response.ok) {
          const data = await response.json();
          values = Array.isArray(data?.[1]) ? data[1].map(clean).filter(Boolean) : [];
        }
      }
      if (sequence === webSequence && activeInput === input) render(input,values);
    } catch (_) {
      if (sequence === webSequence && activeInput === input) render(input,[]);
    } finally { clearTimeout(timeout); }
  };

  const update = input => {
    if (!eligible(input)) return;
    activeInput = input;
    const query = clean(input.value);
    render(input,[]);
    clearTimeout(webTimer);
    if (!isSearchField(input) || query.length < 2) return;
    const sequence = ++webSequence;
    webTimer = setTimeout(()=>fetchWebSuggestions(input,query,sequence),220);
  };

  const attach = input => {
    if (!eligible(input) || input.dataset.lrUniversalAutocomplete === '1') return;
    input.dataset.lrUniversalAutocomplete = '1';
    if (!input.getAttribute('autocomplete')) input.setAttribute('autocomplete','on');
    input.addEventListener('focus',()=>update(input));
    input.addEventListener('input',()=>update(input));
    input.addEventListener('change',()=>remember(input));
    input.addEventListener('blur',()=>setTimeout(()=>{if (document.activeElement !== input) hide();},140));
  };

  const scan = root => {
    if (root instanceof HTMLInputElement || root instanceof HTMLTextAreaElement) attach(root);
    root?.querySelectorAll?.('input,textarea').forEach(attach);
  };

  document.addEventListener('keydown',event=>{if(event.key==='Escape')hide();},true);
  window.addEventListener('resize',position,{passive:true});
  window.addEventListener('scroll',position,{passive:true,capture:true});

  let queued = false;
  const queueScan = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(()=>{queued=false;scan(document);});
  };

  const start = () => {
    installStyles();
    ensureOverlay();
    scan(document);
    new MutationObserver(queueScan).observe(document.body,{childList:true,subtree:true});
  };

  window.LifeRouteUniversalAutocompleteV2 = { scan:queueScan, hide, remember:()=>activeInput&&remember(activeInput) };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded',start,{once:true});
  else start();
})();
