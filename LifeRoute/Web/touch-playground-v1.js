// LifeRoute Touch Playground v1
// High-reward tactile polish without layout-driven animation or persistent heavy work.
(() => {
  if (window.__lifeRouteTouchPlaygroundV1) return;
  window.__lifeRouteTouchPlaygroundV1 = true;

  const root = document.documentElement;
  let scrollIdleTimer = 0;
  let rewardTimer = 0;

  const style = document.createElement('style');
  style.id = 'lifeRouteTouchPlaygroundV1Styles';
  style.textContent = `
    button,[role="button"],.tab,.lrContextTab,.lrPlaceCategory{
      -webkit-tap-highlight-color:transparent;
      transform-origin:center;
    }

    /* Touch bloom: one short-lived DOM node, then immediately removed. */
    .lrPlaygroundArmed{
      position:relative!important;
      isolation:isolate;
      overflow:hidden!important;
    }
    .lrTouchBloom{
      position:absolute;
      left:var(--lr-touch-x,50%);
      top:var(--lr-touch-y,50%);
      width:28px;
      height:28px;
      margin:-14px 0 0 -14px;
      border-radius:999px;
      pointer-events:none;
      z-index:0;
      opacity:.34;
      background:radial-gradient(circle,rgba(255,255,255,.88) 0 14%,color-mix(in srgb,var(--gold) 54%,transparent) 28%,transparent 68%);
      mix-blend-mode:screen;
      transform:translate3d(0,0,0) scale(.35);
      animation:lrTouchBloomOut .34s cubic-bezier(.15,.72,.22,1) forwards;
      will-change:transform,opacity;
    }
    .lrPlaygroundArmed>*:not(.lrTouchBloom){position:relative;z-index:1}
    @keyframes lrTouchBloomOut{
      0%{opacity:.42;transform:translate3d(0,0,0) scale(.35)}
      58%{opacity:.22;transform:translate3d(0,0,0) scale(3.8)}
      100%{opacity:0;transform:translate3d(0,0,0) scale(5.4)}
    }

    /* A fast luminous release makes controls feel spring-loaded. */
    .lrTouchReleaseGlow{
      animation:lrTouchReleaseGlow .24s cubic-bezier(.16,.84,.24,1) both!important;
    }
    @keyframes lrTouchReleaseGlow{
      0%{filter:brightness(1.10) saturate(1.08)}
      45%{filter:brightness(1.16) saturate(1.13)}
      100%{filter:none}
    }

    /* Selected destinations feel alive rather than merely highlighted. */
    .tabs .tab.active,.lrContextTab.active,.lrPlaceCategory.active{
      position:relative;
      overflow:hidden;
    }
    .tabs .tab.active::after,.lrContextTab.active::after,.lrPlaceCategory.active::after{
      content:"";
      position:absolute;
      pointer-events:none;
      inset:auto 20% 2px 20%;
      height:1px;
      border-radius:99px;
      opacity:.72;
      background:linear-gradient(90deg,transparent,color-mix(in srgb,var(--gold) 72%,white 18%),transparent);
      box-shadow:0 0 10px color-mix(in srgb,var(--gold) 44%,transparent);
      animation:lrActiveTabBreathe 2.8s ease-in-out infinite alternate;
    }
    @keyframes lrActiveTabBreathe{
      from{opacity:.38;transform:scaleX(.78)}
      to{opacity:.86;transform:scaleX(1.08)}
    }

    /* Primary actions get a single glint only after deliberate interaction. */
    .goldButton,.primary,#findGapsButton{
      position:relative;
      overflow:hidden;
    }
    .goldButton::before,.primary::before,#findGapsButton::before{
      content:"";
      position:absolute;
      pointer-events:none;
      inset:-45% auto -45% -38%;
      width:28%;
      opacity:0;
      transform:skewX(-18deg) translate3d(-180%,0,0);
      background:linear-gradient(90deg,transparent,rgba(255,255,255,.32),transparent);
    }
    .goldButton.lrTouchReleaseGlow::before,.primary.lrTouchReleaseGlow::before,#findGapsButton.lrTouchReleaseGlow::before{
      opacity:.9;
      animation:lrPrimaryGlint .38s cubic-bezier(.16,.82,.24,1) both;
    }
    @keyframes lrPrimaryGlint{
      from{transform:skewX(-18deg) translate3d(-180%,0,0)}
      to{transform:skewX(-18deg) translate3d(620%,0,0)}
    }

    /* Reward halo: a single reusable layer for high-value actions. */
    #lifeRouteRewardHalo{
      position:fixed;
      z-index:2147482000;
      pointer-events:none;
      left:50%;
      top:52%;
      width:min(78vw,620px);
      aspect-ratio:1;
      border-radius:999px;
      opacity:0;
      transform:translate3d(-50%,-50%,0) scale(.34);
      background:radial-gradient(circle,color-mix(in srgb,var(--gold) 22%,transparent) 0 12%,color-mix(in srgb,var(--blue) 14%,transparent) 31%,transparent 67%);
      will-change:transform,opacity;
    }
    #lifeRouteRewardHalo.lrRewardPulse{
      animation:lrRewardPulse .52s cubic-bezier(.12,.72,.22,1) both;
    }
    @keyframes lrRewardPulse{
      0%{opacity:0;transform:translate3d(-50%,-50%,0) scale(.34)}
      26%{opacity:.54;transform:translate3d(-50%,-50%,0) scale(.60)}
      100%{opacity:0;transform:translate3d(-50%,-50%,0) scale(1.08)}
    }

    /* Views arrive with a quick glass sweep; no geometry tracking required. */
    .view.active>.hero,.view.active>.section:first-child,.lrSetupPane.active>.hero{
      position:relative;
      overflow:hidden;
    }
    .view.active>.hero::after,.view.active>.section:first-child::after,.lrSetupPane.active>.hero::after{
      content:"";
      position:absolute;
      pointer-events:none;
      inset:-30% auto -30% -22%;
      width:20%;
      opacity:0;
      transform:skewX(-14deg) translate3d(-220%,0,0);
      background:linear-gradient(90deg,transparent,rgba(255,255,255,.18),transparent);
      animation:lrScreenArrivalSweep .58s cubic-bezier(.16,.82,.22,1) .04s both;
    }
    @keyframes lrScreenArrivalSweep{
      0%{opacity:0;transform:skewX(-14deg) translate3d(-220%,0,0)}
      24%{opacity:.62}
      100%{opacity:0;transform:skewX(-14deg) translate3d(780%,0,0)}
    }

    /* Forms should feel responsive before submit, not dead until a button tap. */
    input,select,textarea{
      transition:border-color .16s ease,box-shadow .16s ease,background-color .16s ease,transform .16s ease;
    }
    input:focus,select:focus,textarea:focus{
      border-color:color-mix(in srgb,var(--blue) 66%,var(--gold) 18%)!important;
      box-shadow:0 0 0 3px color-mix(in srgb,var(--blue) 15%,transparent),0 10px 28px rgba(0,0,0,.10);
      transform:translate3d(0,-1px,0);
    }
    button:focus-visible,[role="button"]:focus-visible,input:focus-visible,select:focus-visible,textarea:focus-visible{
      outline:2px solid color-mix(in srgb,var(--gold) 72%,white 14%)!important;
      outline-offset:3px;
    }

    /* A tiny living signature around the LR mark, opacity/transform only. */
    .mark{position:relative;isolation:isolate}
    .mark::after{
      content:"";
      position:absolute;
      pointer-events:none;
      inset:-5px;
      z-index:-1;
      border-radius:inherit;
      border:1px solid color-mix(in srgb,var(--gold) 35%,transparent);
      opacity:.16;
      transform:scale(.96);
      animation:lrBrandBreath 4.8s ease-in-out infinite alternate;
    }
    @keyframes lrBrandBreath{
      from{opacity:.12;transform:scale(.95)}
      to{opacity:.48;transform:scale(1.08)}
    }

    /* Fine-pointer depth only: zero touch churn on iPhone. */
    @media(hover:hover) and (pointer:fine){
      .card,.metric,.hero,.route{
        transition:transform .18s cubic-bezier(.16,.82,.24,1),border-color .18s ease,box-shadow .18s ease;
      }
      .card:hover,.metric:hover,.route:hover{
        transform:translate3d(0,-2px,0);
        border-color:color-mix(in srgb,var(--blue) 25%,var(--line));
      }
      .hero:hover{transform:translate3d(0,-1px,0)}
      button:not(:disabled):hover,[role="button"]:hover{
        filter:brightness(1.055) saturate(1.035);
      }
    }

    /* Expensive ambient work stops exactly when it matters most. */
    html.lrUserScrolling #lifeRouteDelightBackdrop>span,
    html.lrDocumentHidden #lifeRouteDelightBackdrop>span,
    html.lrUserScrolling .mark::after,
    html.lrDocumentHidden .mark::after,
    html.lrUserScrolling .tabs .tab.active::after,
    html.lrDocumentHidden .tabs .tab.active::after,
    html.lrUserScrolling .lrContextTab.active::after,
    html.lrDocumentHidden .lrContextTab.active::after{
      animation-play-state:paused!important;
    }

    @media(prefers-reduced-motion:reduce){
      .lrTouchBloom,.lrTouchReleaseGlow,#lifeRouteRewardHalo.lrRewardPulse,
      .tabs .tab.active::after,.lrContextTab.active::after,.lrPlaceCategory.active::after,
      .goldButton.lrTouchReleaseGlow::before,.primary.lrTouchReleaseGlow::before,#findGapsButton.lrTouchReleaseGlow::before,
      .view.active>.hero::after,.view.active>.section:first-child::after,.lrSetupPane.active>.hero::after,
      .mark::after{
        animation:none!important;
      }
      .lrTouchBloom{display:none!important}
      input:focus,select:focus,textarea:focus{transform:none!important}
    }
  `;
  document.head.appendChild(style);

  const rewardHalo = document.createElement('div');
  rewardHalo.id = 'lifeRouteRewardHalo';
  rewardHalo.setAttribute('aria-hidden','true');
  document.body.appendChild(rewardHalo);

  const interactive = target => target?.closest?.('button,[role="button"],.tab,.lrContextTab,.lrPlaceCategory');
  const enabled = control => !!control && !control.matches(':disabled') && control.getAttribute('aria-disabled') !== 'true';
  const isPrimaryReward = control => !!control?.matches?.('.goldButton,.primary,#findGapsButton,[data-lr-reward="primary"]');

  const clearBloom = control => {
    control?.querySelectorAll?.(':scope > .lrTouchBloom').forEach(node => node.remove());
  };

  const addBloom = (control, event) => {
    if (!enabled(control)) return;
    clearBloom(control);
    const rect = control.getBoundingClientRect();
    const x = Number.isFinite(event.clientX) ? event.clientX - rect.left : rect.width / 2;
    const y = Number.isFinite(event.clientY) ? event.clientY - rect.top : rect.height / 2;
    control.style.setProperty('--lr-touch-x', `${Math.max(0,Math.min(rect.width,x))}px`);
    control.style.setProperty('--lr-touch-y', `${Math.max(0,Math.min(rect.height,y))}px`);
    control.classList.add('lrPlaygroundArmed');
    const bloom = document.createElement('span');
    bloom.className = 'lrTouchBloom';
    bloom.setAttribute('aria-hidden','true');
    control.appendChild(bloom);
    bloom.addEventListener('animationend', () => bloom.remove(), { once:true });
    setTimeout(() => bloom.remove(), 450);
  };

  const releaseGlow = control => {
    if (!enabled(control)) return;
    control.classList.remove('lrTouchReleaseGlow');
    // A single frame boundary reliably restarts repeated fast taps without layout reads.
    requestAnimationFrame(() => {
      control.classList.add('lrTouchReleaseGlow');
      setTimeout(() => control.classList.remove('lrTouchReleaseGlow'), 420);
    });
  };

  const pulseReward = () => {
    clearTimeout(rewardTimer);
    rewardHalo.classList.remove('lrRewardPulse');
    requestAnimationFrame(() => {
      rewardHalo.classList.add('lrRewardPulse');
      rewardTimer = window.setTimeout(() => rewardHalo.classList.remove('lrRewardPulse'), 620);
    });
  };

  document.addEventListener('pointerdown', event => {
    const control = interactive(event.target);
    if (!enabled(control)) return;
    addBloom(control, event);
  }, { capture:true, passive:true });

  document.addEventListener('pointerup', event => {
    const control = interactive(event.target);
    if (!enabled(control)) return;
    releaseGlow(control);
    if (isPrimaryReward(control)) pulseReward();
  }, { capture:true, passive:true });

  document.addEventListener('pointercancel', event => {
    const control = interactive(event.target);
    control?.classList.remove('lrTouchReleaseGlow');
    clearBloom(control);
  }, { capture:true, passive:true });

  window.addEventListener('scroll', () => {
    root.classList.add('lrUserScrolling');
    clearTimeout(scrollIdleTimer);
    scrollIdleTimer = window.setTimeout(() => root.classList.remove('lrUserScrolling'), 140);
  }, { passive:true });

  const syncVisibility = () => root.classList.toggle('lrDocumentHidden', document.hidden);
  document.addEventListener('visibilitychange', syncVisibility, { passive:true });
  syncVisibility();
})();
