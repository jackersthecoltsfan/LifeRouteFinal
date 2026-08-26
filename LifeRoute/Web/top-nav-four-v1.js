// LifeRoute final top-navigation enforcer.
// Keeps exactly four equal destinations without creating a mutation/reflow loop.
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

    if (ORDER.some(view => !byView.has(view))) return false;

    const current = Array.from(tabs.querySelectorAll(':scope > .tab'));
    const alreadyOrdered = current.length === ORDER.length && ORDER.every((view, index) => current[index] === byView.get(view));
    if (!alreadyOrdered) ORDER.forEach(view => tabs.appendChild(byView.get(view)));

    const setImportant = (element, property, value) => {
      if (element.style.getPropertyValue(property) === value && element.style.getPropertyPriority(property) === 'important') return;
      element.style.setProperty(property, value, 'important');
    };

    setImportant(tabs, 'display', 'grid');
    setImportant(tabs, 'grid-template-columns', 'repeat(4, minmax(0, 1fr))');
    setImportant(tabs, 'grid-auto-columns', '0');
    setImportant(tabs, 'grid-auto-flow', 'row');
    setImportant(tabs, 'width', '100%');

    tabs.querySelectorAll(':scope > .tab').forEach(button => {
      setImportant(button, 'width', '100%');
      setImportant(button, 'min-width', '0');
      setImportant(button, 'max-width', 'none');
      setImportant(button, 'margin', '0');
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
    if (tabs) new MutationObserver(queue).observe(tabs, { childList: true });
    requestAnimationFrame(enforce);
    setTimeout(enforce, 180);
  };

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', start, { once: true });
  } else {
    start();
  }

  window.LifeRouteTopNavFourV1 = { enforce };
})();
