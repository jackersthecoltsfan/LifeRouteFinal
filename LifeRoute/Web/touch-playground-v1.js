// LifeRoute Touch Playground v1
// Extra tactile delight without layout-driven animation or persistent heavy work.
(() => {
  if (window.__lifeRouteTouchPlaygroundV1) return;
  window.__lifeRouteTouchPlaygroundV1 = true;

  const root = document.documentElement;
  let scrollIdleTimer = 0;

  const style = document.createElement('style');
  style.id = 'lifeRouteTouchPlaygroundV1Styles';
  style.textContent = `
    button,[role="button"],.tab,.lrContextTab,.lrPlaceCategory{
      -webkit-tap-highlight-color:transparent;
      transform-origin:center;
    }

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

    .lrTouchReleaseGlow{
      animation:lrTouchReleaseGlow .24s cubic-bezier(.16,.84,.24,1) both!important;
    }
    @keyframes lrTouchReleaseGlow{
      0%{filter:brightness(1.10) saturate(1.08)}
      45%{filter:brightness(1.16) saturate(1.13)}
      100%{filter:none}
    }

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

    html.lrUserScrolling #lifeRouteDelightBackdrop>span,
    html.lrDocumentHidden #lifeRouteDelightBackdrop>span{
      animation-play-state:paused!important;
    }

    @media(prefers-reduced-motion:reduce){
      .lrTouchBloom,.lrTouchReleaseGlow,
      .tabs .tab.active::after,.lrContextTab.active::after,.lrPlaceCategory.active::after,
      .goldButton.lrTouchReleaseGlow::before,.primary.lrTouchReleaseGlow::before,#findGapsButton.lrTouchReleaseGlow::before{
        animation:none!important;
      }
      .lrTouchBloom{display:none!important}
    }
  `;
  document.head.appendChild(style);

  const interactive = target => target?.closest?.('button,[role="button"],.tab,.lrContextTab,.lrPlaceCategory');
  const enabled = control => !!control && !control.matches(':disabled') && control.getAttribute('aria-disabled') !== 'true';

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
    // A frame boundary makes repeated fast taps restart cleanly without forced layout.
    requestAnimationFrame(() => {
      control.classList.add('lrTouchReleaseGlow');
      setTimeout(() => control.classList.remove('lrTouchReleaseGlow'), 420);
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
