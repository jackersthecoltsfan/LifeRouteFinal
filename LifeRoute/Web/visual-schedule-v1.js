// LifeRoute Visual Schedule v1.
// A local-first sequence builder that reuses the visual-support library, supports
// touch-friendly reordering/completion, and can expand into a session display.
(() => {
  if (window.__lifeRouteVisualScheduleV1Loaded) return;
  window.__lifeRouteVisualScheduleV1Loaded = true;

  const STORE = 'liferoute_visual_schedule_v1';
  const VISUAL_STORE = 'liferoute_visual_tools_v2';
  let state = { title:'Visual Schedule', steps:[] };
  try {
    const saved = JSON.parse(localStorage.getItem(STORE) || '{}');
    if (saved && typeof saved === 'object') {
      state.title = String(saved.title || 'Visual Schedule');
      state.steps = Array.isArray(saved.steps) ? saved.steps : [];
    }
  } catch (_) {}

  const safe = value => String(value || '').replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[c]));
  const save = () => { try { localStorage.setItem(STORE,JSON.stringify(state)); } catch (_) {} };
  const visuals = () => {
    try {
      const data = JSON.parse(localStorage.getItem(VISUAL_STORE) || '{}');
      return Array.isArray(data?.icons) ? data.icons.filter(item=>item?.id && item?.dataURL) : [];
    } catch (_) { return []; }
  };
  const iconById = id => visuals().find(item=>String(item.id)===String(id)) || null;
  const haptic = style => window.LifeRouteLiquidInteractionV4?.haptic?.(style || 'selection');

  const style = document.createElement('style');
  style.id = 'lifeRouteVisualScheduleStyles';
  style.textContent = `
    #visualScheduleTool .lrScheduleBuilder{display:grid;gap:9px}.lrScheduleAdd{display:grid;grid-template-columns:1.2fr 1fr auto;gap:7px;align-items:end}.lrScheduleSteps{display:grid;gap:7px;margin-top:8px}.lrScheduleStep{display:grid;grid-template-columns:48px 1fr auto;gap:9px;align-items:center;padding:8px;border:1px solid var(--line);border-radius:14px;background:color-mix(in srgb,var(--panel2) 65%,transparent);transition:transform .16s cubic-bezier(.18,.89,.26,1.22),opacity .18s ease,background .18s ease}.lrScheduleStep.done{opacity:.56;background:color-mix(in srgb,var(--green) 6%,var(--panel2))}.lrScheduleVisual{width:48px;height:48px;border-radius:11px;display:grid;place-items:center;overflow:hidden;background:color-mix(in srgb,var(--blue) 7%,var(--panel));border:1px solid var(--line);font-size:20px}.lrScheduleVisual img{width:100%;height:100%;object-fit:cover}.lrScheduleStep b{display:block;font-size:11px}.lrScheduleStep .tiny{margin-top:2px}.lrScheduleStepActions{display:grid;grid-template-columns:repeat(2,34px);gap:4px}.lrScheduleStepActions button{width:34px!important;height:34px!important;min-height:34px!important;padding:0!important}.lrScheduleComplete{grid-column:1/-1!important;width:72px!important}.lrScheduleEmpty{padding:18px 10px;text-align:center;color:var(--muted);font-size:9px;border:1px dashed var(--line);border-radius:13px}.lrScheduleProgress{height:7px;border-radius:999px;background:color-mix(in srgb,var(--panel2) 72%,transparent);overflow:hidden;margin:9px 0 3px}.lrScheduleProgress>span{display:block;height:100%;width:0;border-radius:inherit;background:linear-gradient(90deg,var(--blue),var(--gold));transition:width .3s cubic-bezier(.2,.82,.2,1)}
    .lrScheduleOverlay{position:fixed;inset:0;z-index:13000;display:none;background:linear-gradient(160deg,var(--bg),var(--bg2));color:var(--text);padding:calc(14px + env(safe-area-inset-top)) 14px calc(14px + env(safe-area-inset-bottom));overflow:auto}.lrScheduleOverlay.show{display:block}.lrScheduleOverlayTop{max-width:860px;margin:0 auto 12px;display:flex;align-items:center;justify-content:space-between;gap:10px}.lrScheduleOverlayTitle{font-size:clamp(24px,6vw,42px);font-weight:950;letter-spacing:-1px}.lrScheduleOverlayGrid{max-width:860px;margin:auto;display:grid;gap:10px}.lrScheduleDisplayStep{display:grid;grid-template-columns:minmax(92px,24%) 1fr auto;align-items:center;gap:14px;padding:12px;border-radius:22px;background:color-mix(in srgb,var(--panel) 90%,transparent);border:2px solid color-mix(in srgb,var(--line) 84%,transparent);box-shadow:0 10px 30px rgba(0,0,0,.10);transition:opacity .18s ease,transform .18s ease,border-color .18s ease}.lrScheduleDisplayStep.done{opacity:.42;transform:scale(.985)}.lrScheduleDisplayStep.current{border-color:color-mix(in srgb,var(--gold) 68%,var(--line));box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 24%,transparent),0 14px 34px rgba(0,0,0,.13)}.lrScheduleDisplayVisual{width:100%;aspect-ratio:1;border-radius:18px;background:white;display:grid;place-items:center;overflow:hidden;color:#10213a;font-size:34px}.lrScheduleDisplayVisual img{width:100%;height:100%;object-fit:contain}.lrScheduleDisplayText{font-size:clamp(20px,5vw,34px);font-weight:950;line-height:1.04}.lrScheduleDisplayCheck{width:50px!important;height:50px!important;min-height:50px!important;padding:0!important;border-radius:999px!important;font-size:21px!important}.lrScheduleDisplayStep.done .lrScheduleDisplayCheck{background:var(--green)!important;color:#07111f!important}
    @media(max-width:620px){.lrScheduleAdd{grid-template-columns:1fr}.lrScheduleAdd button{width:100%}.lrScheduleDisplayStep{grid-template-columns:86px 1fr auto;gap:10px;padding:9px;border-radius:18px}.lrScheduleDisplayVisual{border-radius:14px}.lrScheduleDisplayCheck{width:44px!important;height:44px!important;min-height:44px!important}.lrScheduleStep{grid-template-columns:44px 1fr}.lrScheduleVisual{width:44px;height:44px}.lrScheduleStepActions{grid-column:1/-1;display:flex;justify-content:flex-end}.lrScheduleComplete{width:auto!important}}
  `;
  document.head.appendChild(style);

  const ensureOverlay = () => {
    let overlay = document.getElementById('lifeRouteVisualScheduleOverlay');
    if (overlay) return overlay;
    overlay = document.createElement('div');
    overlay.id = 'lifeRouteVisualScheduleOverlay';
    overlay.className = 'lrScheduleOverlay';
    overlay.innerHTML = `<div class="lrScheduleOverlayTop"><div><div class="tiny">VISUAL SCHEDULE</div><div class="lrScheduleOverlayTitle" id="lrScheduleDisplayTitle"></div></div><button class="secondary" type="button" id="lrScheduleClose">Done</button></div><div class="lrScheduleOverlayGrid" id="lrScheduleDisplayGrid"></div>`;
    document.body.appendChild(overlay);
    overlay.querySelector('#lrScheduleClose')?.addEventListener('click',()=>overlay.classList.remove('show'));
    return overlay;
  };

  const ensureTool = () => {
    const grid = document.querySelector('#tools .toolGrid');
    if (!grid) return false;
    if (document.getElementById('visualScheduleTool')) return true;
    const card = document.createElement('div');
    card.className = 'card toolCard';
    card.id = 'visualScheduleTool';
    card.innerHTML = `
      <div class="toolHead"><div class="toolIcon">☷</div><div class="grow"><div class="title">Visual Schedule</div><div class="meta">Build a sequence of activities, reuse saved visuals, reorder steps, and check them off during a session.</div></div></div>
      <div class="lrScheduleBuilder">
        <div><label>Schedule title</label><input id="lrScheduleTitle" maxlength="42" value="${safe(state.title)}" placeholder="Visual Schedule"></div>
        <div class="lrScheduleAdd">
          <div><label>Step</label><input id="lrScheduleStepLabel" maxlength="42" placeholder="What happens next?"></div>
          <div><label>Visual</label><select id="lrScheduleStepVisual"><option value="">Text only</option></select></div>
          <button class="goldButton" type="button" id="lrScheduleAddStep">Add step</button>
        </div>
        <div class="lrScheduleProgress"><span id="lrScheduleProgressBar"></span></div>
        <div class="tiny" id="lrScheduleProgressText">0 of 0 complete</div>
        <div class="lrScheduleSteps" id="lrScheduleSteps"></div>
        <div class="toolActions"><button class="goldButton" type="button" id="lrSchedulePresent">Present schedule</button><button class="secondary" type="button" id="lrScheduleReset">Reset checks</button><button class="secondary" type="button" id="lrScheduleClear">Clear schedule</button></div>
      </div>`;
    const choice = document.getElementById('choiceBoardTool');
    if (choice?.nextSibling) grid.insertBefore(card,choice.nextSibling); else grid.appendChild(card);
    wire();
    return true;
  };

  const syncVisualOptions = () => {
    const select = document.getElementById('lrScheduleStepVisual');
    if (!select) return;
    const current = select.value;
    select.innerHTML = '<option value="">Text only</option>' + visuals().map(item=>`<option value="${safe(item.id)}">${safe(item.label)}</option>`).join('');
    if ([...select.options].some(option=>option.value===current)) select.value = current;
  };

  const render = () => {
    syncVisualOptions();
    const list = document.getElementById('lrScheduleSteps');
    const progress = document.getElementById('lrScheduleProgressBar');
    const progressText = document.getElementById('lrScheduleProgressText');
    if (!list) return;
    const done = state.steps.filter(step=>step.done).length;
    const total = state.steps.length;
    if (progress) progress.style.width = `${total ? done/total*100 : 0}%`;
    if (progressText) progressText.textContent = `${done} of ${total} complete`;
    list.innerHTML = total ? state.steps.map((step,index)=>{
      const icon = iconById(step.iconId);
      return `<div class="lrScheduleStep ${step.done?'done':''}" data-lr-schedule-step="${safe(step.id)}"><div class="lrScheduleVisual">${icon?`<img src="${icon.dataURL}" alt="">`:'☷'}</div><div><b>${safe(step.label)}</b><div class="tiny">Step ${index+1}${icon?` · ${safe(icon.label)}`:''}</div></div><div class="lrScheduleStepActions"><button class="secondary" type="button" data-lr-step-up="${safe(step.id)}" aria-label="Move up">↑</button><button class="secondary" type="button" data-lr-step-down="${safe(step.id)}" aria-label="Move down">↓</button><button class="${step.done?'secondary':'goldButton'} lrScheduleComplete" type="button" data-lr-step-done="${safe(step.id)}">${step.done?'Undo':'Complete'}</button><button class="danger" type="button" data-lr-step-remove="${safe(step.id)}" aria-label="Remove step">×</button></div></div>`;
    }).join('') : '<div class="lrScheduleEmpty">Add the first step above. Saved visual-support icons will appear in the Visual menu automatically.</div>';

    list.querySelectorAll('[data-lr-step-up]').forEach(button=>button.onclick=()=>move(button.dataset.lrStepUp,-1));
    list.querySelectorAll('[data-lr-step-down]').forEach(button=>button.onclick=()=>move(button.dataset.lrStepDown,1));
    list.querySelectorAll('[data-lr-step-done]').forEach(button=>button.onclick=()=>toggleDone(button.dataset.lrStepDone));
    list.querySelectorAll('[data-lr-step-remove]').forEach(button=>button.onclick=()=>remove(button.dataset.lrStepRemove));
    renderDisplay();
  };

  const move = (id,delta) => {
    const index = state.steps.findIndex(step=>step.id===id);
    const next = index + delta;
    if (index < 0 || next < 0 || next >= state.steps.length) return;
    [state.steps[index],state.steps[next]]=[state.steps[next],state.steps[index]];
    save();haptic('rigid');render();
  };
  const toggleDone = id => {
    const step = state.steps.find(item=>item.id===id);
    if (!step) return;
    step.done = !step.done;
    save();haptic(step.done?'success':'selection');render();
  };
  const remove = id => { state.steps = state.steps.filter(step=>step.id!==id);save();haptic('medium');render(); };

  const renderDisplay = () => {
    const overlay = ensureOverlay();
    const title = overlay.querySelector('#lrScheduleDisplayTitle');
    const grid = overlay.querySelector('#lrScheduleDisplayGrid');
    if (title) title.textContent = state.title || 'Visual Schedule';
    if (!grid) return;
    const currentIndex = state.steps.findIndex(step=>!step.done);
    grid.innerHTML = state.steps.length ? state.steps.map((step,index)=>{
      const icon = iconById(step.iconId);
      return `<div class="lrScheduleDisplayStep ${step.done?'done':''} ${!step.done&&index===currentIndex?'current':''}"><div class="lrScheduleDisplayVisual">${icon?`<img src="${icon.dataURL}" alt="">`:'☷'}</div><div class="lrScheduleDisplayText">${safe(step.label)}</div><button class="lrScheduleDisplayCheck ${step.done?'secondary':'goldButton'}" type="button" data-lr-display-done="${safe(step.id)}" aria-label="${step.done?'Mark incomplete':'Mark complete'}">${step.done?'✓':'○'}</button></div>`;
    }).join('') : '<div class="lrScheduleEmpty">No schedule steps yet.</div>';
    grid.querySelectorAll('[data-lr-display-done]').forEach(button=>button.onclick=()=>toggleDone(button.dataset.lrDisplayDone));
  };

  const wire = () => {
    document.getElementById('lrScheduleTitle')?.addEventListener('change',event=>{state.title=String(event.target.value||'Visual Schedule').trim()||'Visual Schedule';save();renderDisplay();});
    document.getElementById('lrScheduleAddStep')?.addEventListener('click',()=>{
      const label = String(document.getElementById('lrScheduleStepLabel')?.value || '').trim();
      const iconId = String(document.getElementById('lrScheduleStepVisual')?.value || '');
      const icon = iconById(iconId);
      const resolved = label || icon?.label || '';
      if (!resolved) return;
      state.steps.push({id:`step-${Date.now()}-${Math.random().toString(36).slice(2,7)}`,label:resolved,iconId,done:false});
      document.getElementById('lrScheduleStepLabel').value='';
      document.getElementById('lrScheduleStepVisual').value='';
      save();haptic('success');render();
    });
    document.getElementById('lrSchedulePresent')?.addEventListener('click',()=>{renderDisplay();ensureOverlay().classList.add('show');haptic('rigid');});
    document.getElementById('lrScheduleReset')?.addEventListener('click',()=>{state.steps.forEach(step=>step.done=false);save();haptic('selection');render();});
    document.getElementById('lrScheduleClear')?.addEventListener('click',()=>{state.steps=[];save();haptic('heavy');render();});
    render();
  };

  const wrapToolGroup = () => {
    const api = window.LifeRouteToolbarCleanupV1;
    if (!api?.openToolGroup || api.__visualScheduleWrapped) return false;
    api.__visualScheduleWrapped = true;
    const original = api.openToolGroup;
    api.openToolGroup = function lifeRouteToolGroupWithVisualSchedule(key,...args) {
      const result = original.call(this,key,...args);
      const schedule = document.getElementById('visualScheduleTool');
      if (schedule) schedule.style.display = key === 'visuals' ? '' : 'none';
      return result;
    };
    return true;
  };

  let queued = false;
  const reconcile = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(()=>{
      queued=false;
      ensureTool();
      wrapToolGroup();
      syncVisualOptions();
    });
  };

  const start = () => {
    reconcile();
    new MutationObserver(reconcile).observe(document.body,{childList:true,subtree:true});
    [240,700,1500].forEach(delay=>setTimeout(reconcile,delay));
  };

  window.LifeRouteVisualScheduleV1 = { render, show:()=>{renderDisplay();ensureOverlay().classList.add('show');} };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded',start,{once:true});
  else start();
})();
