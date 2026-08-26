// LifeRoute Theme Accordion v1
// Turns the settings theme catalog into compact Apple-like categorized accordions.
(() => {
  if (window.__lifeRouteThemeAccordionV1Loaded) return;
  window.__lifeRouteThemeAccordionV1Loaded = true;

  const style = document.createElement('style');
  style.id = 'lifeRouteThemeAccordionV1Styles';
  style.textContent = `
    #lifeRouteSettingsOverlay .lrSettingsSheet{padding-bottom:28px!important}
    #lifeRouteSettingsOverlay .lrSettingsSection.lrThemeAccordion{padding:0!important;overflow:hidden;border-radius:18px!important;background:linear-gradient(155deg,color-mix(in srgb,var(--panel) 72%,transparent),color-mix(in srgb,var(--panel2) 52%,transparent))!important;border:1px solid color-mix(in srgb,var(--line) 72%,white 8%)!important;box-shadow:inset 0 1px rgba(255,255,255,.07),0 12px 30px rgba(0,0,0,.09)!important;backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px)}
    #lifeRouteSettingsOverlay .lrThemeAccordionHead{width:100%;min-height:58px;padding:13px 15px;border:0;background:transparent;color:var(--text);display:flex;align-items:center;justify-content:space-between;gap:12px;text-align:left;box-shadow:none!important}
    #lifeRouteSettingsOverlay .lrThemeAccordionTitle{display:flex;flex-direction:column;gap:3px;min-width:0}
    #lifeRouteSettingsOverlay .lrThemeAccordionTitle strong{font-size:13px;letter-spacing:.01em}
    #lifeRouteSettingsOverlay .lrThemeAccordionTitle span{font-size:9px;color:var(--muted);font-weight:750}
    #lifeRouteSettingsOverlay .lrThemeAccordionChevron{width:27px;height:27px;border-radius:999px;display:grid;place-items:center;background:color-mix(in srgb,var(--panel2) 78%,transparent);border:1px solid color-mix(in srgb,var(--line) 72%,white 8%);transition:transform .28s cubic-bezier(.2,.82,.2,1),background .2s ease;flex:0 0 auto}
    #lifeRouteSettingsOverlay .lrThemeAccordionChevron::before{content:'⌄';font-size:15px;line-height:1;transform:translateY(-1px)}
    #lifeRouteSettingsOverlay .lrThemeAccordion.isOpen .lrThemeAccordionChevron{transform:rotate(180deg);background:color-mix(in srgb,var(--gold) 16%,var(--panel2))}
    #lifeRouteSettingsOverlay .lrThemeAccordionBody{display:grid;grid-template-rows:0fr;transition:grid-template-rows .3s cubic-bezier(.16,1,.3,1),opacity .22s ease;opacity:.35}
    #lifeRouteSettingsOverlay .lrThemeAccordion.isOpen .lrThemeAccordionBody{grid-template-rows:1fr;opacity:1}
    #lifeRouteSettingsOverlay .lrThemeAccordionBodyInner{overflow:hidden;padding:0 13px}
    #lifeRouteSettingsOverlay .lrThemeAccordion.isOpen .lrThemeAccordionBodyInner{padding-bottom:14px}
    #lifeRouteSettingsOverlay .lrThemeAccordion .lrSettingsSectionHead{display:none!important}
    #lifeRouteSettingsOverlay .lrThemeAccordion select{width:100%;min-height:48px;border-radius:14px!important;background:color-mix(in srgb,var(--panel2) 76%,transparent)!important;border:1px solid color-mix(in srgb,var(--line) 76%,white 7%)!important;padding:0 13px!important;font-weight:800}
    #lifeRouteSettingsOverlay .lrThemeAccordion .lrThemeGrid,#lifeRouteSettingsOverlay .lrThemeAccordion .themeGrid{grid-template-columns:repeat(2,minmax(0,1fr))!important;gap:9px!important}
    #lifeRouteSettingsOverlay .lrThemeAccordion .lrThemeCard{min-height:86px!important;border-radius:15px!important;padding:10px!important;transition:transform .16s cubic-bezier(.2,.8,.2,1),border-color .18s ease,box-shadow .18s ease!important}
    #lifeRouteSettingsOverlay .lrThemeAccordion .lrThemeCard:active{transform:scale(.975)}
    #lifeRouteSettingsOverlay .lrThemeAccordion .lrThemeCard.active{border-color:color-mix(in srgb,var(--gold) 62%,var(--line))!important;box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 18%,transparent),0 8px 22px color-mix(in srgb,var(--gold) 10%,transparent)!important}
    #lifeRouteSettingsOverlay .lrThemeAccordionSummary{display:inline-flex;align-items:center;gap:5px;color:var(--gold)!important}
    @media(max-width:520px){#lifeRouteSettingsOverlay .lrThemeAccordion .lrThemeGrid,#lifeRouteSettingsOverlay .lrThemeAccordion .themeGrid{grid-template-columns:1fr 1fr!important}#lifeRouteSettingsOverlay .lrThemeAccordionHead{min-height:56px;padding:12px 13px}}
    @media(prefers-reduced-motion:reduce){#lifeRouteSettingsOverlay .lrThemeAccordionBody,#lifeRouteSettingsOverlay .lrThemeAccordionChevron{transition:none!important}}
  `;
  document.head.appendChild(style);

  const names = new Map([
    ['lifeRouteCoreThemeSection',['Classic','Clean signature themes']],
    ['lifeRouteMetallicWaveThemeSection',['Metallic','Polished dark & luminous finishes']],
    ['lifeRouteDynamicThemeSection',['Dynamic','Animated atmospheric themes']],
    ['lifeRouteFluidSceneSection',['Fluid','Flowing ambient scenes']],
    ['lifeRouteDynamicAnimalSection',['Living','Animated creature themes']]
  ]);

  const sectionLabel = section => {
    const id = section.id || '';
    if (names.has(id)) return names.get(id);
    const raw = section.querySelector('.lrSettingsSectionHead b')?.textContent?.replace('✓','').trim() || 'Scenery';
    if (/nature|scenery/i.test(raw)) return ['Scenery','Nature-inspired visual environments'];
    return [raw,'Theme collection'];
  };

  const isActiveSection = section => !!section.querySelector('.lrThemeSelectedMark,.lrThemeCard.active,select option:checked:not([value=""])');

  const install = section => {
    if (!(section instanceof HTMLElement) || section.dataset.lrThemeAccordion === '1') return;
    const hasThemeContent = section.id?.includes('ThemeSection') || section.querySelector('.lrThemeCard') || /nature scenery|scenery/i.test(section.querySelector('.lrSettingsSectionHead b')?.textContent || '');
    if (!hasThemeContent) return;
    section.dataset.lrThemeAccordion='1'; section.classList.add('lrThemeAccordion');
    const [title,subtitle]=sectionLabel(section);
    const head=document.createElement('button'); head.type='button'; head.className='lrThemeAccordionHead'; head.setAttribute('aria-expanded','false');
    head.innerHTML=`<span class="lrThemeAccordionTitle"><strong>${title}</strong><span>${subtitle}</span></span><span class="lrThemeAccordionChevron" aria-hidden="true"></span>`;
    const body=document.createElement('div'); body.className='lrThemeAccordionBody';
    const inner=document.createElement('div'); inner.className='lrThemeAccordionBodyInner';
    [...section.childNodes].forEach(node=>inner.appendChild(node)); body.appendChild(inner); section.append(head,body);
    const open = isActiveSection(section); section.classList.toggle('isOpen',open); head.setAttribute('aria-expanded',open?'true':'false');
    head.addEventListener('click',()=>{const next=!section.classList.contains('isOpen');section.classList.toggle('isOpen',next);head.setAttribute('aria-expanded',next?'true':'false');try{window.LifeRouteInteractionPolish?.haptic?.('selection');}catch(_){}});
  };

  const sync = () => {
    const sheet=document.querySelector('#lifeRouteSettingsOverlay .lrSettingsSheet'); if(!sheet)return;
    sheet.querySelectorAll(':scope > .lrSettingsSection').forEach(install);
    sheet.querySelectorAll('.lrThemeAccordion').forEach(section=>{if(isActiveSection(section)){section.classList.add('isOpen');section.querySelector('.lrThemeAccordionHead')?.setAttribute('aria-expanded','true');}});
  };
  const observer=new MutationObserver(()=>requestAnimationFrame(sync));
  const start=()=>{sync();observer.observe(document.body,{subtree:true,childList:true,attributes:true,attributeFilter:['class','aria-pressed']});[150,500,1100].forEach(ms=>setTimeout(sync,ms));};
  if(document.readyState==='loading')document.addEventListener('DOMContentLoaded',start,{once:true});else start();
  window.LifeRouteThemeAccordionV1={sync};
})();
