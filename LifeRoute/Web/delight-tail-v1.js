// Moves the Delight UI stylesheet to the end of the cascade after LifeRoute's legacy
// presentation layers finish loading, performs one final structural sync, and locks in
// one distinct vector icon per top-level destination.
(() => {
  const NAV = {
    today: ['calendar','Schedule'],
    tools: ['briefcase','Session Tools'],
    resources: ['package','Resources'],
    setup: ['settings','Setup']
  };
  const correctIcons = () => {
    if (typeof window.lifeRouteIcon !== 'function') return;
    document.querySelectorAll('.tabs .tab').forEach(button => {
      const item = NAV[button.dataset.view];
      if (!item) return;
      button.dataset.lrDelightIcon = '1';
      button.innerHTML = `${window.lifeRouteIcon(item[0],18)}<span>${item[1]}</span>`;
    });
  };
  const finalize = () => {
    const style = document.getElementById('lifeRouteDelightUIV1Styles');
    if (style && style.parentElement) style.parentElement.appendChild(style);
    try { window.LifeRouteDelightUIV1?.syncContext?.(); } catch (_) {}
    correctIcons();
  };
  [120,320,800,1600,2800].forEach(delay => setTimeout(finalize, delay));
})();
