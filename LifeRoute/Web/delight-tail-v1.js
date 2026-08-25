// Moves the Delight UI stylesheet to the end of the cascade after LifeRoute's legacy
// presentation layers finish loading, then performs one final structural sync.
(() => {
  const finalize = () => {
    const style = document.getElementById('lifeRouteDelightUIV1Styles');
    if (style && style.parentElement) style.parentElement.appendChild(style);
    try { window.LifeRouteDelightUIV1?.syncContext?.(); } catch (_) {}
  };
  [120,320,800,1600,2800].forEach(delay => setTimeout(finalize, delay));
})();
