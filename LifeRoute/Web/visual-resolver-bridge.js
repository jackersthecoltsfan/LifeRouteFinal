// Bridges LifeRoute's First / Then board to the asynchronous smart photo resolver.
// Loaded after visual-tools.js so it can replace the old generic SVG fallback without
// changing saved/manual visual behavior.
(() => {
  const STORE = "liferoute_visual_tools_v2";
  let renderToken = 0;
  let scheduled = 0;
  let observer = null;
  const lastAssignedSrc = new WeakMap();

  const normalize = value => window.LifeRouteVisualResolver?.normalize
    ? window.LifeRouteVisualResolver.normalize(value)
    : String(value || "").trim().toLowerCase().replace(/\s+/g, " ");

  const getSavedVisualForText = text => {
    try {
      const saved = JSON.parse(localStorage.getItem(STORE) || "{}");
      const icons = Array.isArray(saved.icons) ? saved.icons : [];
      const target = normalize(text);
      if (!target) return null;
      const exact = icons.find(icon => normalize(icon?.label) === target && icon?.dataURL);
      return exact?.dataURL || null;
    } catch (_) {
      return null;
    }
  };

  const ensureImage = (panel, value) => {
    let img = panel?.querySelector(".firstThenVisualImage");
    if (!img && panel && value) {
      img = document.createElement("img");
      img.className = "firstThenVisualImage";
      img.alt = "";
      img.hidden = true;
      panel.insertBefore(img, value);
    }
    return img;
  };

  const setTextOnly = (panel, img, label) => {
    if (!panel || !img) return;
    img.onerror = null;
    img.hidden = true;
    lastAssignedSrc.set(img, "");
    img.removeAttribute("src");
    img.removeAttribute("data-smart-visual");
    panel.classList.remove("visualReady", "smartVisualLoading");
    panel.setAttribute("aria-label", label || "");
  };

  const setPhoto = (panel, img, label, url, source) => {
    if (!panel || !img || !url) return;
    img.onerror = () => {
      window.LifeRouteVisualResolver?.forget?.(label);
      setTextOnly(panel, img, label);
    };
    img.onload = () => panel.classList.remove("smartVisualLoading");
    img.dataset.smartVisual = source || "resolved";
    img.alt = label;
    lastAssignedSrc.set(img, url);
    img.src = url;
    img.hidden = false;
    panel.classList.add("visualReady");
    panel.classList.remove("smartVisualLoading");
    panel.setAttribute("aria-label", label);
  };

  const sideConfig = side => ({
    input: document.getElementById(side === "first" ? "firstThenFirst" : "firstThenThen"),
    mode: document.getElementById(side === "first" ? "firstThenFirstMode" : "firstThenThenMode"),
    panelSelector: side === "first" ? ".firstPanel" : ".thenPanel",
    valueId: side === "first" ? "firstThenFirstValue" : "firstThenThenValue"
  });

  const resolveSide = async (overlay, side, token) => {
    const config = sideConfig(side);
    const panel = overlay.querySelector(config.panelSelector);
    const value = overlay.querySelector(`#${config.valueId}`);
    const img = ensureImage(panel, value);
    const label = String(config.input?.value || value?.textContent || "").trim();
    const mode = String(config.mode?.value || "auto");

    if (!panel || !value || !img || !label) return;
    value.textContent = label;

    // Respect explicit user choices. Saved mode remains owned by visual-tools.js.
    if (mode === "text") {
      setTextOnly(panel, img, label);
      return;
    }
    if (mode === "saved") {
      panel.classList.remove("smartVisualLoading");
      return;
    }

    // Never show the old generic assembled drawing while a real image is resolving.
    setTextOnly(panel, img, label);
    panel.classList.add("smartVisualLoading");

    // A manually photographed visual with the exact same label always wins.
    const savedURL = getSavedVisualForText(label);
    if (savedURL) {
      if (token !== renderToken) return;
      setPhoto(panel, img, label, savedURL, "saved-exact");
      return;
    }

    const resolver = window.LifeRouteVisualResolver;
    if (!resolver?.resolve) {
      panel.classList.remove("smartVisualLoading");
      return;
    }

    const result = await resolver.resolve(label);
    if (token !== renderToken) return;

    // Low-confidence public search results are intentionally rejected. A clean word
    // card is more useful than showing a child the wrong object/activity.
    if (!result?.url || result.confidence === "low") {
      setTextOnly(panel, img, label);
      return;
    }

    setPhoto(panel, img, label, result.url, result.source);
  };

  const render = async () => {
    const overlay = document.getElementById("firstThenOverlay");
    if (!overlay?.classList.contains("show")) return;
    const token = ++renderToken;
    await Promise.all([
      resolveSide(overlay, "first", token),
      resolveSide(overlay, "then", token)
    ]);
  };

  const scheduleRender = (delay = 40) => {
    clearTimeout(scheduled);
    scheduled = setTimeout(render, delay);
  };

  const wire = () => {
    const overlay = document.getElementById("firstThenOverlay");
    if (overlay && !observer) {
      observer = new MutationObserver(mutations => {
        const relevant = mutations.some(mutation => {
          if (mutation.type === "attributes" && mutation.attributeName === "class" && mutation.target === overlay) return true;
          if (mutation.type === "attributes" && mutation.attributeName === "src") {
            const img = mutation.target;
            if (!(img instanceof HTMLImageElement) || !img.classList.contains("firstThenVisualImage")) return false;
            const current = img.getAttribute("src") || "";
            const ours = lastAssignedSrc.get(img) || "";
            // If legacy visual-tools writes a different image after us, immediately
            // resolve again so the old generic drawing never wins the race.
            return current !== ours;
          }
          return false;
        });
        if (relevant) scheduleRender(25);
      });
      observer.observe(overlay, { attributes: true, subtree: true, attributeFilter: ["class", "src"] });
    }

    ["firstThenFirst", "firstThenThen", "firstThenFirstMode", "firstThenThenMode"].forEach(id => {
      const field = document.getElementById(id);
      if (field && !field.dataset.smartVisualWired) {
        field.dataset.smartVisualWired = "1";
        field.addEventListener(id.includes("Mode") ? "change" : "input", () => scheduleRender(180));
      }
    });
  };

  const styles = document.createElement("style");
  styles.id = "smartVisualResolverStyles";
  styles.textContent = `
    .firstThenPanel.smartVisualLoading .firstThenValue{display:block!important;width:auto!important;border:0!important;background:transparent!important;color:var(--text)!important;padding:0!important;border-radius:0!important;box-shadow:none!important}
    .firstThenPanel.smartVisualLoading .firstThenValue:after{content:"Finding visual…";display:block;margin-top:10px;font-size:10px;letter-spacing:.08em;text-transform:uppercase;color:var(--muted);font-weight:850}
    .firstThenPanel:not(.visualReady) .firstThenVisualImage{display:none!important}
  `;
  document.head.appendChild(styles);

  document.addEventListener("click", event => {
    if (event.target?.closest?.("#showFirstThen")) {
      setTimeout(() => {
        wire();
        scheduleRender(20);
      }, 20);
    }
  }, true);

  document.addEventListener("DOMContentLoaded", () => {
    wire();
    const bodyObserver = new MutationObserver(() => wire());
    bodyObserver.observe(document.body, { childList: true, subtree: true });
  }, { once: true });

  window.LifeRouteSmartVisuals = {
    refresh: () => scheduleRender(0),
    version: "1.0.1"
  };
})();
