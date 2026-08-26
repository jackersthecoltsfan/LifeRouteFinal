// LifeRoute Home + live-location reliability layer.
// Keeps a dedicated persisted home anchor in sync with the shared preferences and Saved Places models.
(() => {
  if (window.__lifeRouteHomeLocationV3Loaded) return;
  window.__lifeRouteHomeLocationV3Loaded = true;

  const HOME_KEY = "liferoute_home_address_v3";
  const clean = value => String(value || "").trim();

  const readDedicatedHome = () => {
    try { return clean(localStorage.getItem(HOME_KEY)); } catch (_) { return ""; }
  };

  const writeDedicatedHome = address => {
    try {
      if (address) localStorage.setItem(HOME_KEY, address);
      else localStorage.removeItem(HOME_KEY);
    } catch (_) {}
  };

  const homePlace = () => (Array.isArray(window.places) ? window.places : []).find(place => String(place?.type || "").toLowerCase() === "home");

  const upsertHomePlace = address => {
    if (!Array.isArray(window.places)) return;
    const existing = homePlace();
    if (!address) {
      if (existing && existing.__lifeRouteHomeAnchor) {
        const index = window.places.indexOf(existing);
        if (index >= 0) window.places.splice(index, 1);
      }
      return;
    }
    if (existing) {
      existing.name = clean(existing.name) || "Home";
      existing.type = "Home";
      existing.address = address;
      existing.member = existing.member || "yes";
      existing.__lifeRouteHomeAnchor = true;
      return;
    }
    window.places.unshift({
      name: "Home",
      type: "Home",
      address,
      min: 30,
      member: "yes",
      __lifeRouteHomeAnchor: true
    });
  };

  const persistHome = raw => {
    const address = clean(raw);
    if (window.prefs && typeof window.prefs === "object") window.prefs.homeAddress = address;
    writeDedicatedHome(address);
    upsertHomePlace(address);
    try { window.persist?.(); } catch (_) {}
    try { window.renderPlaces?.(); } catch (_) {}
    window.dispatchEvent(new CustomEvent("liferoute-home-address-changed", { detail: { address } }));
    return address;
  };

  const canonicalHome = () => {
    const dedicated = readDedicatedHome();
    if (dedicated) return dedicated;
    const preference = clean(window.prefs?.homeAddress);
    if (preference) return preference;
    return clean(homePlace()?.address);
  };

  const reconcileHome = () => {
    const address = canonicalHome();
    if (address) {
      if (window.prefs && clean(window.prefs.homeAddress) !== address) window.prefs.homeAddress = address;
      writeDedicatedHome(address);
      upsertHomePlace(address);
    }
    const field = document.getElementById("homeAddressField");
    if (field && document.activeElement !== field && field.value !== address) field.value = address;
    return address;
  };

  const removeSmartArtifacts = () => {
    document.querySelectorAll("button,.badge,.chip,.contextPill,.hint").forEach(node => {
      if (clean(node.textContent).toLowerCase() === "smart") node.remove();
    });
    document.getElementById("smartContextStrip")?.remove();
    document.querySelectorAll("#locationContextStatus .contextPill").forEach(node => {
      if (/mapkit route intelligence/i.test(clean(node.textContent))) node.remove();
    });
  };

  const simplifyHomeUI = () => {
    reconcileHome();
    removeSmartArtifacts();

    const field = document.getElementById("homeAddressField");
    if (!field) return;
    field.setAttribute("autocomplete", "street-address");
    field.setAttribute("enterkeyhint", "done");

    const section = field.closest(".section");
    const heading = section?.querySelector(".sectionHead h2, h2");
    if (heading) heading.textContent = "Home & location";
    section?.querySelector(".sectionHead .hint")?.remove();

    const card = field.closest(".card");
    card?.classList.remove("commuteCard");
    card?.querySelectorAll(":scope > .tiny").forEach(node => node.remove());

    const save = document.getElementById("saveHomeButton");
    if (save) save.textContent = "Save home";
    const location = document.getElementById("locationButton");
    if (location && !/location access off/i.test(location.textContent || "")) location.textContent = "Use live location";
  };

  const startLiveLocation = () => {
    try { window.LifeRouteLiveLocation?.start?.(); } catch (_) {}
    // One-shot request is kept as a fast first fix while the foreground stream starts.
    try {
      if (typeof window.postNative === "function") window.postNative({ action: "requestCurrentLocation" });
    } catch (_) {}
  };

  document.addEventListener("click", event => {
    const save = event.target.closest?.("#saveHomeButton");
    if (save) {
      const address = persistHome(document.getElementById("homeAddressField")?.value);
      simplifyHomeUI();
      try { window.setStatus?.(address ? "Home address saved" : "Home address cleared"); } catch (_) {}
      setTimeout(() => { try { window.refreshRouteTimes?.(); } catch (_) {} }, 80);
      return;
    }
    if (event.target.closest?.("#locationButton")) startLiveLocation();
  }, true);

  document.addEventListener("change", event => {
    if (event.target?.id === "homeAddressField" && event.target.dataset.lrAutocompleteSelected === "1") {
      persistHome(event.target.value);
      simplifyHomeUI();
    }
  }, true);

  const previousNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithReliableHome(evt) {
    if (typeof previousNativeEvent === "function") previousNativeEvent(evt);
    if (evt?.type === "currentLocation" || evt?.type === "currentLocationStatus") requestAnimationFrame(simplifyHomeUI);
  };

  let queued = false;
  const queue = () => {
    if (queued) return;
    queued = true;
    requestAnimationFrame(() => {
      queued = false;
      simplifyHomeUI();
    });
  };

  const start = () => {
    reconcileHome();
    simplifyHomeUI();
    const root = document.getElementById("setup") || document.body;
    new MutationObserver(queue).observe(root, { childList: true, subtree: true });
  };

  window.LifeRouteHomeLocationV3 = { persistHome, canonicalHome, reconcileHome, startLiveLocation };
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();