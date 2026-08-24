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

  const SEARCH_HINTS = {
    store: "grocery supermarket store aisle shopping cart",
    chocolate: "chocolate bar cocoa candy food",
    candy: "candy sweets food",
    eat: "child eating meal table food",
    drink: "child drinking cup water",
    bathroom: "bathroom toilet",
    wash_hands: "child washing hands sink",
    brush_teeth: "child brushing teeth toothbrush",
    park: "children playground park",
    swing: "child playground swing",
    pool: "child swimming pool",
    water_play: "child water table play",
    bubbles: "child blowing bubbles",
    tablet: "child tablet computer",
    phone: "smartphone phone",
    music: "child music headphones",
    break: "child resting quiet area",
    home: "house home exterior",
    car: "car automobile",
    walk: "child walking outdoors",
    hug: "child hugging caregiver",
    drawing: "child drawing crayons table",
    blocks: "child toy building blocks",
    magna_tiles: "magnetic building tiles toy",
    puzzle: "child jigsaw puzzle",
    reading: "child reading picture book",
    sleep: "child sleeping bed",
    sit: "child sitting chair",
    wait: "child waiting seated",
    cleanup: "child putting toys storage bin",
    shoes: "child putting on shoes",
    coat: "child putting on jacket coat",
    tv: "child watching television"
  };

  const BAD_PUBLIC_TITLES = [
    "logo", "icon", "symbol", "diagram", "chart", "map", "flag", "coat of arms",
    "poster", "sign", "drawing", "illustration", "clipart", "vector", "svg", "emoji",
    "screenshot", "scan", "document", "text", "seal", "emblem"
  ];

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

  const usefulTerms = text => normalize(text)
    .split(" ")
    .filter(term => term.length > 2 && !["child","photo","photograph","object","activity","with","from","using","doing"].includes(term));

  const publicPhotoFallback = async label => {
    const resolver = window.LifeRouteVisualResolver;
    if (!resolver?.safeForPublicLookup?.(label)) return null;

    const canonical = resolver.canonicalFor?.(label) || normalize(label).replace(/\s+/g, "_");
    const hint = SEARCH_HINTS[canonical] || `${normalize(label)} object activity`;
    const query = `${hint} photograph`;
    const params = new URLSearchParams({
      action: "query",
      generator: "search",
      gsrsearch: query,
      gsrnamespace: "6",
      gsrlimit: "16",
      prop: "imageinfo",
      iiprop: "url|mime|size",
      iiurlwidth: "1200",
      format: "json",
      origin: "*"
    });

    try {
      const response = await fetch(`https://commons.wikimedia.org/w/api.php?${params.toString()}`, {
        method: "GET",
        mode: "cors",
        credentials: "omit",
        cache: "default"
      });
      if (!response.ok) return null;
      const data = await response.json();
      const pages = Object.values(data?.query?.pages || {});
      const terms = [...new Set([...usefulTerms(label), ...usefulTerms(hint)])];

      const ranked = pages.map(page => {
        const info = page?.imageinfo?.[0];
        const title = normalize(String(page?.title || "").replace(/^file:/i, ""));
        const mime = String(info?.mime || "");
        if (!title || (mime && !/^image\/(jpeg|png|webp)$/i.test(mime))) return { page, score: -100 };
        if (BAD_PUBLIC_TITLES.some(word => title.includes(word))) return { page, score: -100 };
        let score = 0;
        terms.forEach(term => { if (title.includes(term)) score += 3; });
        if (/\b(child|children|kid|boy|girl)\b/.test(title)) score += 2;
        if (/\b(photo|photograph|jpg|jpeg)\b/.test(title)) score += 1;
        score -= Number(page?.index || 0) * 0.03;
        return { page, score };
      }).filter(item => item.score > -50).sort((a, b) => b.score - a.score);

      const best = ranked[0]?.page;
      const info = best?.imageinfo?.[0];
      const url = info?.thumburl || info?.url;
      if (!url) return null;

      const result = {
        url,
        source: "wikimedia-fallback",
        confidence: "medium",
        canonical,
        title: String(best.title || "").replace(/^File:/i, ""),
        query
      };
      resolver.remember?.(normalize(label), result);
      return result;
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

    let result = await resolver.resolve(label);
    if (token !== renderToken) return;

    // If the primary resolver cannot confidently identify a photo, run a broader
    // category-aware Commons lookup. This is what lets terms like Store, Chocolate,
    // foods, toys, places and new activity words resolve without hardcoded SVG art.
    if (!result?.url || result.confidence === "low") {
      result = await publicPhotoFallback(label);
      if (token !== renderToken) return;
    }

    // Wrong is worse than blank. If two search passes still fail, preserve the
    // activity word as a clean text-only First / Then card.
    if (!result?.url) {
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
    version: "1.1.0"
  };
})();
