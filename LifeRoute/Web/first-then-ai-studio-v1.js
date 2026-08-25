// Explicit AI-generation fallback when automatic First/Then photo lookup cannot resolve.
// The system Image Playground UI is never opened without a user tap.
(() => {
  if (window.__lifeRouteFirstThenAIStudioV1Loaded) return;
  window.__lifeRouteFirstThenAIStudioV1Loaded = true;
  const STORE = "liferoute_visual_tools_v2";
  let checkTimer = 0;

  const normalize = value => window.LifeRouteVisualResolver?.normalize?.(value)
    || String(value || "").trim().toLowerCase().replace(/\s+/g, " ");

  const saveGenerated = (label, dataURL) => {
    try {
      const state = JSON.parse(localStorage.getItem(STORE) || "{}");
      state.icons = Array.isArray(state.icons) ? state.icons : [];
      const target = normalize(label);
      const existing = state.icons.find(icon => normalize(icon?.label) === target);
      if (existing) {
        existing.dataURL = dataURL;
        existing.updatedAt = new Date().toISOString();
      } else {
        state.icons.push({
          id: `visual-ai-${Date.now()}-${Math.random().toString(36).slice(2, 6)}`,
          label,
          dataURL,
          source: "apple-image-playground",
          createdAt: new Date().toISOString()
        });
      }
      if (state.icons.length > 18) state.icons = state.icons.slice(-18);
      localStorage.setItem(STORE, JSON.stringify(state));
      window.dispatchEvent(new CustomEvent("liferoute:visual-library-changed"));
      return true;
    } catch (_) {
      return false;
    }
  };

  const side = name => ({
    panel: document.querySelector(name === "first" ? "#firstThenOverlay .firstPanel" : "#firstThenOverlay .thenPanel"),
    input: document.getElementById(name === "first" ? "firstThenFirst" : "firstThenThen"),
    mode: document.getElementById(name === "first" ? "firstThenFirstMode" : "firstThenThenMode")
  });

  const ensureButton = name => {
    const config = side(name);
    if (!config.panel) return null;
    let button = config.panel.querySelector(`[data-lr-ai-firstthen="${name}"]`);
    if (!button) {
      button = document.createElement("button");
      button.type = "button";
      button.className = "lrFirstThenAIButton";
      button.dataset.lrAiFirstthen = name;
      button.textContent = "Create AI visual";
      config.panel.appendChild(button);
      button.onclick = async event => {
        event.preventDefault();
        event.stopPropagation();
        const label = String(config.input?.value || "").trim();
        if (!label || !window.LifeRouteImageStudio?.available?.()) return;
        button.disabled = true;
        button.textContent = "Opening AI studio…";
        try {
          const result = await window.LifeRouteImageStudio.open({ label });
          if (result?.success && result.dataURL && saveGenerated(label, result.dataURL)) {
            window.LifeRouteVisualResolver?.remember?.(normalize(label), {
              url: result.dataURL,
              source: "apple-image-playground",
              confidence: "high",
              canonical: window.LifeRouteVisualResolver?.canonicalFor?.(label) || normalize(label)
            });
            window.LifeRouteSmartVisuals?.refresh?.();
            if (typeof window.setStatus === "function") window.setStatus(`${label} AI visual saved locally`);
          }
        } finally {
          button.disabled = false;
          button.textContent = "Create AI visual";
          scheduleCheck(500);
        }
      };
    }
    return button;
  };

  const refresh = () => {
    const overlay = document.getElementById("firstThenOverlay");
    if (!overlay?.classList.contains("show") || !window.LifeRouteImageStudio?.available?.()) return;
    ["first", "then"].forEach(name => {
      const config = side(name);
      const button = ensureButton(name);
      if (!button || !config.panel) return;
      const mode = String(config.mode?.value || "auto");
      const hasVisual = config.panel.classList.contains("visualReady") && !!config.panel.querySelector(".firstThenVisualImage:not([hidden])");
      const loading = config.panel.classList.contains("smartVisualLoading");
      button.hidden = mode !== "auto" || hasVisual || loading;
    });
  };

  function scheduleCheck(delay = 4200) {
    clearTimeout(checkTimer);
    checkTimer = setTimeout(refresh, delay);
  }

  document.addEventListener("click", event => {
    if (event.target?.closest?.("#showFirstThen")) {
      scheduleCheck(4300);
      setTimeout(refresh, 7000);
    }
  }, true);

  ["input", "change"].forEach(type => document.addEventListener(type, event => {
    const id = event.target?.id || "";
    if (["firstThenFirst","firstThenThen","firstThenFirstMode","firstThenThenMode"].includes(id)) scheduleCheck(4600);
  }, true));

  const style = document.createElement("style");
  style.id = "lifeRouteFirstThenAIStudioStyles";
  style.textContent = `.lrFirstThenAIButton{margin-top:12px;padding:9px 12px;border-radius:999px;background:color-mix(in srgb,var(--blue) 12%,var(--panel2));border:1px solid color-mix(in srgb,var(--blue) 44%,var(--line));color:var(--text);font-size:10px;font-weight:900}.lrFirstThenAIButton[hidden]{display:none!important}`;
  document.head.appendChild(style);

  window.LifeRouteFirstThenAIStudio = { refresh, version: "1.0.0" };
})();
