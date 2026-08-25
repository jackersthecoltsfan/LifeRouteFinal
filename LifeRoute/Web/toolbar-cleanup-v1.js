// LifeRoute shared top-toolbar cleanup.
// Keep Calendar's internal Day / Week / Month controls, but never expose a
// duplicate Month button in the application's main navigation toolbar.
(() => {
  const reconcile = () => {
    const tabs = document.querySelector('.tabs');
    if (!tabs) return false;

    Array.from(tabs.children).forEach(child => {
      if (child?.classList?.contains('tab') && child.dataset?.view === 'month') {
        child.remove();
      }
    });

    const count = Math.max(1, Array.from(tabs.children).filter(child => child.classList?.contains('tab')).length);
    tabs.style.setProperty('grid-template-columns', `repeat(${count}, minmax(0, 1fr))`, 'important');
    tabs.dataset.lifeRouteToolbarClean = '1';
    return true;
  };

  const start = () => {
    reconcile();
    [0, 80, 250, 700].forEach(delay => setTimeout(reconcile, delay));

    const tabs = document.querySelector('.tabs');
    if (tabs && !window.__lifeRouteToolbarCleanupObserver) {
      const observer = new MutationObserver(() => reconcile());
      observer.observe(tabs, { childList: true });
      window.__lifeRouteToolbarCleanupObserver = observer;
    }
  };

  window.LifeRouteToolbarCleanupV1 = { reconcile };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start, { once: true });
  } else {
    start();
  }
})();
