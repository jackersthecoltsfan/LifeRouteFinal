// LifeRoute Interaction Stability v3
// User touch is the only thing allowed to move the main document viewport.
// Also pauses ambient visual motion while the user is actively touching/scrolling
// so WKWebView can prioritize input and compositing responsiveness.
(() => {
  if (window.__lifeRouteInteractionStabilityV3) return;
  window.__lifeRouteInteractionStabilityV3 = true;

  try { history.scrollRestoration = 'manual'; } catch (_) {}

  const noProgrammaticScroll = () => undefined;
  try {
    window.scroll = noProgrammaticScroll;
    window.scrollTo = noProgrammaticScroll;
    window.scrollBy = noProgrammaticScroll;
  } catch (_) {}

  try {
    if (Element.prototype.scrollIntoView) Element.prototype.scrollIntoView = noProgrammaticScroll;
    if (Element.prototype.scrollIntoViewIfNeeded) Element.prototype.scrollIntoViewIfNeeded = noProgrammaticScroll;
  } catch (_) {}

  // Script-triggered focus must not drag the document to a field. Direct user taps
  // still use WebKit's normal focus behavior.
  try {
    const nativeFocus = HTMLElement.prototype.focus;
    HTMLElement.prototype.focus = function(options) {
      const safeOptions = options && typeof options === 'object'
        ? { ...options, preventScroll: true }
        : { preventScroll: true };
      return nativeFocus.call(this, safeOptions);
    };
  } catch (_) {}

  const forceInstantScrollPolicy = () => {
    document.documentElement.style.scrollBehavior = 'auto';
    if (document.body) document.body.style.scrollBehavior = 'auto';
  };
  forceInstantScrollPolicy();
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', forceInstantScrollPolicy, { once: true });
  }

  // Prevent hash links from producing browser-managed jumps. LifeRoute navigation
  // uses buttons/views, not document anchors.
  document.addEventListener('click', event => {
    const anchor = event.target?.closest?.('a[href^="#"]');
    if (!anchor) return;
    const href = anchor.getAttribute('href') || '';
    if (href.length > 1) event.preventDefault();
  }, true);

  // Pause ambient theme motion while a finger is down. This materially reduces
  // compositing competition during scrolling without making the background feel static.
  let resumeTimer = 0;
  const pauseAmbientMotion = () => {
    clearTimeout(resumeTimer);
    document.documentElement.classList.add('lrInteractionBusy');
  };
  const resumeAmbientMotion = () => {
    clearTimeout(resumeTimer);
    resumeTimer = setTimeout(() => {
      document.documentElement.classList.remove('lrInteractionBusy');
    }, 140);
  };

  document.addEventListener('touchstart', pauseAmbientMotion, { passive: true, capture: true });
  document.addEventListener('touchend', resumeAmbientMotion, { passive: true, capture: true });
  document.addEventListener('touchcancel', resumeAmbientMotion, { passive: true, capture: true });

  document.addEventListener('visibilitychange', () => {
    if (document.hidden) document.documentElement.classList.add('lrInteractionBusy');
    else resumeAmbientMotion();
  }, { passive: true });
})();
