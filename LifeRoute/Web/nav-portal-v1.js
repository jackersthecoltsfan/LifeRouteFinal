// LifeRoute Navigation Portal v1
// One reusable compositor-only pulse makes screen changes feel spatial without tracking the pointer.
(() => {
  if (window.__lifeRouteNavPortalV1) return;
  window.__lifeRouteNavPortalV1 = true;

  const style = document.createElement('style');
  style.id = 'lifeRouteNavPortalV1Styles';
  style.textContent = `
    #lifeRouteNavPortal{
      position:fixed;
      z-index:2147481900;
      pointer-events:none;
      width:88px;
      height:88px;
      margin:-44px 0 0 -44px;
      left:var(--lr-portal-x,50%);
      top:var(--lr-portal-y,50%);
      border-radius:999px;
      opacity:0;
      transform:translate3d(0,0,0) scale(.18);
      background:
        radial-gradient(circle,
          rgba(255,255,255,.78) 0 4%,
          color-mix(in srgb,var(--gold) 42%,transparent) 9%,
          color-mix(in srgb,var(--blue) 22%,transparent) 27%,
          transparent 66%);
      box-shadow:
        inset 0 0 0 1px color-mix(in srgb,var(--gold) 24%,transparent),
        0 0 34px color-mix(in srgb,var(--blue) 16%,transparent);
      will-change:transform,opacity;
    }
    #lifeRouteNavPortal.lrPortalOpen{
      animation:lrPortalOpen .46s cubic-bezier(.10,.72,.18,1) both;
    }
    @keyframes lrPortalOpen{
      0%{opacity:0;transform:translate3d(0,0,0) scale(.18)}
      18%{opacity:.64;transform:translate3d(0,0,0) scale(.55)}
      58%{opacity:.28;transform:translate3d(0,0,0) scale(4.2)}
      100%{opacity:0;transform:translate3d(0,0,0) scale(8.6)}
    }
    @media(prefers-reduced-motion:reduce){
      #lifeRouteNavPortal.lrPortalOpen{animation:none!important;opacity:0!important}
    }
  `;
  document.head.appendChild(style);

  const portal = document.createElement('div');
  portal.id = 'lifeRouteNavPortal';
  portal.setAttribute('aria-hidden','true');
  document.body.appendChild(portal);

  let portalTimer = 0;
  const selector = '.tabs .tab,.lrContextTab,.lrPlaceCategory,.lrDayPager button,#lifeRouteQuickAddAppointment,#lifeRouteSettingsButton';

  const enabled = control => !!control && !control.matches(':disabled') && control.getAttribute('aria-disabled') !== 'true';

  const openPortal = (control, event) => {
    if (!enabled(control)) return;
    const rect = control.getBoundingClientRect();
    const x = Number.isFinite(event.clientX) && event.clientX > 0 ? event.clientX : rect.left + rect.width / 2;
    const y = Number.isFinite(event.clientY) && event.clientY > 0 ? event.clientY : rect.top + rect.height / 2;
    portal.style.setProperty('--lr-portal-x', `${Math.max(0, Math.min(window.innerWidth, x))}px`);
    portal.style.setProperty('--lr-portal-y', `${Math.max(0, Math.min(window.innerHeight, y))}px`);
    clearTimeout(portalTimer);
    portal.classList.remove('lrPortalOpen');
    requestAnimationFrame(() => {
      portal.classList.add('lrPortalOpen');
      portalTimer = window.setTimeout(() => portal.classList.remove('lrPortalOpen'), 540);
    });
  };

  document.addEventListener('pointerup', event => {
    const control = event.target?.closest?.(selector);
    if (control) openPortal(control, event);
  }, { capture:true, passive:true });

  document.addEventListener('pointercancel', () => {
    clearTimeout(portalTimer);
    portal.classList.remove('lrPortalOpen');
  }, { capture:true, passive:true });

  document.addEventListener('visibilitychange', () => {
    if (!document.hidden) return;
    clearTimeout(portalTimer);
    portal.classList.remove('lrPortalOpen');
  }, { passive:true });
})();
