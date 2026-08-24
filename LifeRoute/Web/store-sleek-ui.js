// Compact, premium styling for store-route comparison results.
(() => {
  const apply = () => {
    if (document.getElementById("storeSleekUIStyles")) return;

    const style = document.createElement("style");
    style.id = "storeSleekUIStyles";
    style.textContent = `
      .storeChooser{margin-top:8px!important;padding-top:8px!important;border-top:0!important}
      .storeChooserHead{margin:0 2px 7px!important;gap:10px!important;align-items:center!important}
      .storeChooserHead b{font-size:12px!important;letter-spacing:-.1px!important}
      .storeChooserHead .tiny{opacity:.72}

      .storeOption{
        margin-top:8px!important;
        padding:12px!important;
        border-radius:16px!important;
        border:1px solid color-mix(in srgb,var(--line) 72%,transparent)!important;
        background:color-mix(in srgb,var(--panel) 94%,var(--panel2) 6%)!important;
        box-shadow:0 6px 18px rgba(0,0,0,.08)!important;
      }
      .storeOption.best{
        border-color:color-mix(in srgb,var(--gold) 42%,var(--line))!important;
        box-shadow:0 7px 22px color-mix(in srgb,var(--gold) 8%,transparent)!important;
      }
      .storeOption>.row{
        display:grid!important;
        grid-template-columns:minmax(0,1fr) auto!important;
        align-items:start!important;
        gap:10px!important;
      }
      .storeOption .grow{min-width:0!important}
      .storeOption .title{font-size:15px!important;line-height:1.15!important;margin-top:1px!important}
      .storeOption .meta{font-size:10.5px!important;line-height:1.35!important;margin-top:3px!important;color:var(--muted)!important}
      .storeOption .small{font-size:9px!important;line-height:1.2!important;color:var(--muted)!important;margin-bottom:2px!important}
      .storeOption .tiny{font-size:9.8px!important;line-height:1.35!important;color:var(--muted)!important}

      .storeOption .fit,.storeOption .miss,.storeOption .unknown{
        display:inline-flex!important;
        align-items:center!important;
        justify-content:center!important;
        min-height:26px!important;
        padding:5px 8px!important;
        border-radius:999px!important;
        white-space:nowrap!important;
        font-size:9.6px!important;
        line-height:1!important;
        letter-spacing:-.05px!important;
        border:1px solid transparent!important;
      }
      .storeOption .fit{background:color-mix(in srgb,var(--green) 11%,transparent)!important;border-color:color-mix(in srgb,var(--green) 32%,transparent)!important}
      .storeOption .miss{background:color-mix(in srgb,var(--red) 10%,transparent)!important;border-color:color-mix(in srgb,var(--red) 28%,transparent)!important}
      .storeOption .unknown{background:color-mix(in srgb,var(--gold) 10%,transparent)!important;border-color:color-mix(in srgb,var(--gold) 28%,transparent)!important}

      .storeOptionButtons{margin-top:8px!important;gap:5px!important}
      .storeOptionButtons button{min-height:32px!important;padding:7px 10px!important;border-radius:10px!important;font-size:10px!important;box-shadow:none!important}

      @media(max-width:520px){
        .storeOption{padding:11px!important}
        .storeOption>.row{grid-template-columns:minmax(0,1fr) auto!important;gap:8px!important}
        .storeOption .title{font-size:14px!important}
        .storeOption .fit,.storeOption .miss,.storeOption .unknown{font-size:9px!important;padding:5px 7px!important}
      }
    `;
    document.head.appendChild(style);
  };

  const removeRedundantBrandLabels = root => {
    (root || document).querySelectorAll?.(".storeOption").forEach(card => {
      const kicker = card.querySelector(".small");
      const title = card.querySelector(".title");
      if (!kicker || !title) return;
      const kickerText = kicker.textContent.trim();
      const titleText = title.textContent.trim();
      if (!kickerText.startsWith("★") && kickerText.toLowerCase() === titleText.toLowerCase()) {
        kicker.style.display = "none";
      }
    });
  };

  const start = () => {
    apply();
    removeRedundantBrandLabels(document);
    const observer = new MutationObserver(records => {
      records.forEach(record => record.addedNodes.forEach(node => {
        if (node.nodeType === 1) removeRedundantBrandLabels(node);
      }));
    });
    observer.observe(document.body, { childList: true, subtree: true });
  };

  if (document.readyState === "loading") window.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
