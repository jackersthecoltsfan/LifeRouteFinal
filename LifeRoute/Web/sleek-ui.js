// LifeRoute premium visual system + compact theme selector.
window.addEventListener("DOMContentLoaded", () => {
  const themes = [
    ["royal", "Royal Navy + Gold"],
    ["obsidian", "Obsidian Gold"],
    ["carbon", "Carbon"],
    ["midnight", "Midnight Indigo"],
    ["navy-noir", "Navy Noir"],
    ["titanium", "Titanium Night"],
    ["ocean", "Deep Ocean"],
    ["aurora", "Aurora Night"],
    ["forest", "Emerald Night"],
    ["plum", "Plum Night"],
    ["ember", "Ember Night"],
    ["slate", "Graphite"],
    ["mono", "Monochrome"],
    ["daylight", "Daylight"]
  ];

  const style = document.createElement("style");
  style.textContent = `
    html[data-theme="obsidian"]{--bg:#050607;--bg2:#0b0d10;--panel:rgba(16,18,22,.92);--panel2:#171a1f;--line:rgba(228,196,120,.14);--text:#f8f8f6;--muted:#a7a8aa;--blue:#aeb8c7;--gold:#e8c574;--green:#7fddb0;--red:#ff9d9d;--shadow:0 18px 50px rgba(0,0,0,.34)}
    html[data-theme="carbon"]{--bg:#07090c;--bg2:#10141a;--panel:rgba(19,23,29,.93);--panel2:#1a2028;--line:rgba(185,199,219,.13);--text:#f7f9fb;--muted:#9da8b5;--blue:#a9c7ea;--gold:#c9d1dc;--green:#82d8aa;--red:#ff999f}
    html[data-theme="midnight"]{--bg:#050713;--bg2:#0d1228;--panel:rgba(16,21,45,.91);--panel2:#171e3d;--line:rgba(143,160,255,.16);--text:#fbfbff;--muted:#a8afd0;--blue:#95a7ff;--gold:#e6c77a;--green:#7ee0b4;--red:#ff929f}
    html[data-theme="navy-noir"]{--bg:#030911;--bg2:#071524;--panel:rgba(8,24,42,.93);--panel2:#0e2036;--line:rgba(108,165,222,.15);--text:#f8fbff;--muted:#97abc1;--blue:#72b7ff;--gold:#d8b96c;--green:#7dd9ae;--red:#ff959e}
    html[data-theme="titanium"]{--bg:#0a0b0d;--bg2:#15181c;--panel:rgba(26,29,34,.92);--panel2:#20252b;--line:rgba(218,225,233,.13);--text:#f4f6f8;--muted:#a8afb7;--blue:#c4d1df;--gold:#d9c18a;--green:#8ed3ad;--red:#f79b9b}
    html[data-theme="ocean"]{--bg:#03131d;--bg2:#062735;--panel:rgba(7,34,47,.92);--panel2:#0d3444;--line:rgba(122,207,231,.16);--text:#f3fcff;--muted:#a0c8d4;--blue:#79dcff;--gold:#dfc881;--green:#77dfb8;--red:#ff9aa2}
    html[data-theme="aurora"]{--bg:#041316;--bg2:#09272e;--panel:rgba(8,36,42,.91);--panel2:#103840;--line:rgba(105,222,211,.17);--text:#f5ffff;--muted:#a4ccca;--blue:#78e1e8;--gold:#d9e58f;--green:#78e1b7;--red:#ff9aa4}
    html[data-theme="forest"]{--bg:#04110d;--bg2:#0a2118;--panel:rgba(11,34,26,.92);--panel2:#123429;--line:rgba(134,211,173,.15);--text:#f5fff9;--muted:#a3c4b5;--blue:#87d1be;--gold:#dcc47d;--green:#75dda6;--red:#ff9d9d}
    html[data-theme="plum"]{--bg:#0e0612;--bg2:#211029;--panel:rgba(37,18,45,.92);--panel2:#32183d;--line:rgba(205,145,218,.15);--text:#fff8ff;--muted:#c8afcc;--blue:#c79cdd;--gold:#e5c37a;--green:#91dbae;--red:#ff99aa}
    html[data-theme="ember"]{--bg:#120705;--bg2:#29110c;--panel:rgba(43,20,14,.92);--panel2:#3b2119;--line:rgba(228,157,111,.15);--text:#fff9f4;--muted:#cfb4a4;--blue:#e29b77;--gold:#e8bf69;--green:#98d4a0;--red:#ff9494}
    html[data-theme="mono"]{--bg:#050607;--bg2:#111316;--panel:rgba(21,23,27,.93);--panel2:#1c1f24;--line:rgba(255,255,255,.11);--text:#fff;--muted:#adb0b6;--blue:#e2e6ec;--gold:#fff;--green:#c8f7d4;--red:#ffaaaa}

    html{scroll-behavior:smooth;background:var(--bg)}
    body{background-attachment:fixed!important;background-image:radial-gradient(circle at 85% -5%,color-mix(in srgb,var(--blue) 12%,transparent),transparent 30%),radial-gradient(circle at -10% 15%,color-mix(in srgb,var(--gold) 7%,transparent),transparent 26%),linear-gradient(180deg,var(--bg),var(--bg2) 58%,var(--bg))!important}
    .app{max-width:880px!important;padding-left:16px!important;padding-right:16px!important;padding-bottom:108px!important}
    header{padding:5px 2px 3px;align-items:center!important}.brand{gap:11px!important}h1{font-size:28px!important;font-weight:850!important;letter-spacing:-1.15px!important}.subtitle{font-size:11.5px!important;letter-spacing:.02em}.mark{width:43px!important;height:43px!important;border-radius:13px!important;font-weight:900!important;box-shadow:0 10px 30px color-mix(in srgb,var(--blue) 10%,transparent)!important}.status{font-size:10px!important;padding:7px 9px!important;backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);box-shadow:none!important}
    .tabs{display:flex!important;grid-template-columns:none!important;gap:6px!important;overflow-x:auto!important;padding:3px 1px 5px!important;margin:14px 0 17px!important;scrollbar-width:none;-webkit-overflow-scrolling:touch}.tabs::-webkit-scrollbar{display:none}.tab{flex:0 0 auto!important;min-width:70px!important;padding:9px 12px!important;border-radius:12px!important;box-shadow:none!important;white-space:nowrap;font-size:11.5px!important;font-weight:760!important;transition:transform .13s ease,background .18s ease,color .18s ease}.tab:active{transform:scale(.975)}.tab.active{background:linear-gradient(135deg,color-mix(in srgb,var(--blue) 92%,white 8%),color-mix(in srgb,var(--blue) 72%,var(--gold) 28%))!important;color:#07121f!important;box-shadow:0 8px 24px color-mix(in srgb,var(--blue) 12%,transparent)!important}
    .hero{border-radius:21px!important;padding:17px!important;background:linear-gradient(145deg,color-mix(in srgb,var(--blue) 9%,transparent),color-mix(in srgb,var(--gold) 4%,transparent)),var(--panel)!important;backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px);box-shadow:0 18px 42px rgba(0,0,0,.14)!important}.hero h2{font-size:20px!important;letter-spacing:-.5px!important;font-weight:820!important}.hero p{font-size:12px!important}
    .metrics{gap:7px!important}.metric,.card,.todoMetric,.monthMetric{backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);box-shadow:0 9px 26px rgba(0,0,0,.12)!important;border-color:color-mix(in srgb,var(--line) 82%,transparent)!important}.card{border-radius:17px!important;padding:13px!important;margin-bottom:8px!important}.metric,.todoMetric,.monthMetric{border-radius:15px!important;padding:12px!important}.metric b{font-size:18px!important}.metric span{font-size:9px!important;letter-spacing:.025em}.section{margin-top:16px!important}.sectionHead{margin-bottom:8px!important}.sectionHead h2,.section h2{font-size:15px!important;letter-spacing:-.2px!important;font-weight:790!important}.hint{font-size:9.5px!important}.title{font-weight:800!important;letter-spacing:-.2px!important}.meta,.small{font-size:11.5px!important}.tiny{font-size:9.8px!important}
    .route{border:1px solid color-mix(in srgb,var(--line) 70%,transparent);border-radius:13px!important;padding:9px 10px!important;background:color-mix(in srgb,var(--panel2) 78%,transparent)!important}.gap{border-style:solid!important;border-color:color-mix(in srgb,var(--blue) 20%,var(--line))!important;background:linear-gradient(135deg,color-mix(in srgb,var(--blue) 4%,transparent),transparent),var(--panel)!important}.gapAction{border-color:color-mix(in srgb,var(--blue) 27%,var(--line))!important}
    button{border-radius:11px!important;font-weight:780!important;transition:transform .12s ease,filter .12s ease,opacity .12s ease}button:active{transform:scale(.98)}.primary,.goldButton{box-shadow:none!important}.goldButton{background:linear-gradient(135deg,color-mix(in srgb,var(--gold) 94%,white 6%),color-mix(in srgb,var(--gold) 76%,white 24%))!important}
    input,select{border-radius:11px!important;background:color-mix(in srgb,var(--panel2) 86%,transparent)!important;min-height:42px!important;padding:10px 11px!important;border-color:color-mix(in srgb,var(--line) 86%,transparent)!important}input:focus,select:focus{box-shadow:0 0 0 3px color-mix(in srgb,var(--blue) 13%,transparent)!important}
    .provider{padding:11px!important}.provider .icon{font-size:18px!important;margin-bottom:5px!important}.integrationIcon{border-radius:11px!important}.chip,.badge{padding:5px 7px!important;font-size:9.5px!important}.weekday{padding:10px 0!important}.bar{height:6px!important}.notice{border-radius:12px!important;font-size:10.5px!important}
    .bottom{background:color-mix(in srgb,var(--bg) 76%,transparent)!important;backdrop-filter:blur(30px)!important;-webkit-backdrop-filter:blur(30px)!important;padding-top:7px!important;border-top-color:color-mix(in srgb,var(--line) 75%,transparent)!important}.bottomin{gap:7px!important}.bottomin button{min-height:45px!important;border-radius:13px!important;font-size:12px!important}
    .themeTiles,#themeTiles{display:none!important}
    @media(max-width:680px){.app{padding-left:12px!important;padding-right:12px!important}.tab{min-width:66px!important;padding:9px 10px!important}.status{max-width:46%;line-height:1.15}.hero{padding:15px!important}.card{padding:12px!important}.providerGrid{gap:7px!important}}
  `;
  document.head.appendChild(style);

  const select = document.getElementById("themeSelect");
  if (select) {
    const selected = prefs.theme || "royal";
    select.innerHTML = themes.map(([value, label]) => `<option value="${value}">${label}</option>`).join("");
    select.value = themes.some(([value]) => value === selected) ? selected : "royal";
    select.onchange = () => setTheme(select.value);
  }

  window.setTheme = function setPremiumTheme(value) {
    const selected = themes.some(([theme]) => theme === value) ? value : "royal";
    prefs.theme = selected;
    document.documentElement.dataset.theme = selected === "royal" ? "" : selected;
    if (select) select.value = selected;
    persist();
  };

  const legacyTiles = document.getElementById("themeTiles");
  legacyTiles?.remove();
  document.querySelectorAll(".themeTiles").forEach(node => node.remove());

  const gapHead = Array.from(document.querySelectorAll("#today .sectionHead")).find(el => el.textContent.includes("Gap opportunities"));
  const gapHint = gapHead?.querySelector(".hint");
  if (gapHint) gapHint.textContent = "ranked by route + priority";

  if (!themes.some(([value]) => value === (prefs.theme || "royal"))) prefs.theme = "royal";
  document.documentElement.dataset.theme = prefs.theme === "royal" ? "" : prefs.theme;
  if (select) select.value = prefs.theme;
});
