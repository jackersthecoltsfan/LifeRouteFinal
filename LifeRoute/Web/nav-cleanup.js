// LifeRoute web navigation cleanup: keep Month inside Calendar and Saved Places inside Setup.
(() => {
  const activateSetupPane = paneName => {
    const setup = document.getElementById("setup");
    const nav = document.getElementById("setupSubnav");
    if (!setup || !nav) return;

    nav.querySelectorAll("[data-setup-pane]").forEach(button => {
      button.classList.toggle("active", button.dataset.setupPane === paneName);
    });

    const panes = {
      general: document.getElementById("setupGeneral"),
      clients: document.getElementById("setupClients"),
      places: document.getElementById("places")
    };

    Object.entries(panes).forEach(([name, pane]) => {
      if (!pane) return;
      pane.classList.toggle("active", name === paneName);
    });
  };

  const cleanTopTabs = () => {
    const tabs = document.querySelector(".tabs");
    if (!tabs) return;

    // Day / Week / Month already live inside the Calendar hub. Places now lives
    // inside Setup. Remove any late-added duplicate top-level buttons.
    tabs.querySelectorAll('.tab[data-view="month"], .tab[data-view="places"]').forEach(button => button.remove());
  };

  const movePlacesIntoSetup = () => {
    const setup = document.getElementById("setup");
    const nav = document.getElementById("setupSubnav");
    const places = document.getElementById("places");
    if (!setup || !nav || !places) return false;

    places.classList.remove("view", "active");
    places.classList.add("setupPane");
    if (places.parentElement !== setup) setup.appendChild(places);

    let button = nav.querySelector('[data-setup-pane="places"]');
    if (!button) {
      button = document.createElement("button");
      button.type = "button";
      button.dataset.setupPane = "places";
      button.textContent = "Places";
      nav.appendChild(button);
    }

    // Own setup-subnav switching so the new Places pane behaves exactly like
    // General and Clients even though those two were created by another module.
    if (nav.dataset.lifeRoutePlacesNav !== "1") {
      nav.dataset.lifeRoutePlacesNav = "1";
      nav.addEventListener("click", event => {
        const target = event.target.closest("[data-setup-pane]");
        if (!target || !nav.contains(target)) return;
        event.preventDefault();
        event.stopImmediatePropagation();
        activateSetupPane(target.dataset.setupPane || "general");
      }, true);
    }

    return true;
  };

  const installShowViewRedirect = () => {
    if (window.__lifeRoutePlacesRedirectInstalled || typeof window.showView !== "function") return;
    window.__lifeRoutePlacesRedirectInstalled = true;
    const previous = window.showView;
    window.showView = function lifeRouteViewWithPlacesInSetup(id) {
      if (id === "places") {
        const result = previous.call(this, "setup");
        requestAnimationFrame(() => activateSetupPane("places"));
        return result;
      }
      return previous.apply(this, arguments);
    };
  };

  const reconcile = () => {
    cleanTopTabs();
    if (movePlacesIntoSetup()) installShowViewRedirect();
  };

  const start = () => {
    reconcile();
    // Other feature modules create tabs during DOMContentLoaded. Reconcile a
    // few more times so late-created Month/Places buttons cannot reappear.
    [0, 80, 250, 700].forEach(delay => setTimeout(reconcile, delay));

    const tabs = document.querySelector(".tabs");
    if (tabs && !window.__lifeRouteNavCleanupObserver) {
      const observer = new MutationObserver(reconcile);
      observer.observe(tabs, { childList: true });
      window.__lifeRouteNavCleanupObserver = observer;
    }
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
