// LifeRoute final top-navigation enforcer.
// The top bar must contain exactly four equal destinations with no hidden/legacy track.
(() => {
  if (window.__lifeRouteTopNavFourV1Loaded) return;
  window.__lifeRouteTopNavFourV1Loaded = true;

  const ORDER = ['today', 'tools', 'resources', 'setup'];

  const enforce = () => {
    const tabs = document.querySelector('.tabs');
    if (!tabs) return false;

    const byView = new Map();
    tabs.querySelectorAll(':scope > .tab').forEach(button => {
      const view = String(button.dataset.view || '');
      if (!ORDER.includes(view) || byView.has(view)) {
        button.remove();
        return;
      }
      byView.set(view, button);
    });

    // If the canonical navigation owner has not finished yet, let it create the
    // missing buttons and come back on the next frame/mutation.
    if (ORDER.some(view => !byView.has(view))) return false;

    ORDER.forEach(view => tabs.appendChild(byView.get(view)));

    tabs.style.setProperty('display', 'grid', 'important');
    tabs.style.setProperty('grid-template-columns', 'repeat(4, minmax(0, 1fr))', 'important');
    tabs.style.setProperty('grid-auto-columns', '0', 'important');
    tabs.style.setProperty('grid-auto-flow', 'row', 'important');
    tabs.style.setProperty('width', '100%', 'important');

    tabs.querySelectorAll(':scope > .tab').forEach(button => {
      button.style.setProperty('width', '100%', 'important');
      button.style.setProperty('min-width', '0', 'important');
      button.style.setProperty('max-width', 'none', 'important');
      button.style.setProperty('margin', '0', 'important');
    });

    tabs.dataset.lrFourTabLayout = '1';
    return true;
  };

  let queued = false;
  const queue = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      enforce();
    });
  };

  const start = () => {
    enforce();
    const tabs = document.querySelector('.tabs');
    if (tabs) {
      new MutationObserver(queue).observe(tabs, {
        childList: true,
        attributes: true,
        attributeFilter: ['class', 'style']
      });
    }
    requestAnimationFrame(enforce);
    setTimeout(enforce, 120);
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start, { once: true });
  } else {
    start();
  }

  window.LifeRouteTopNavFourV1 = { enforce };
})();
