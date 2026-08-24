// LifeRoute visual polish + expanded themes.
window.addEventListener("DOMContentLoaded", () => {
  const themes = [
    ["royal", "Royal Blue + Gold"],
    ["midnight", "Midnight Indigo"],
    ["aurora", "Aurora"],
    ["ocean", "Deep Ocean"],
    ["forest", "Emerald Forest"],
    ["plum", "Plum Night"],
    ["ember", "Ember"],
    ["rose", "Rose Quartz"],
    ["slate", "Graphite"],
    ["mono", "Monochrome"],
    ["daylight", "Daylight"]
  ];

  const style = document.createElement("style");
  style.textContent = `
    html[data-theme="midnight"]{--bg:#050713;--bg2:#10152b;--panel:rgba(19,24,51,.88);--panel2:#1a2145;--line:rgba(157,169,255,.18);--text:#fbfbff;--muted:#aeb4d3;--blue:#9ca8ff;--gold:#e8ca7b;--green:#7ee0b4;--red:#ff929f}
    html[data-theme="aurora"]{--bg:#05131a;--bg2:#0c2631;--panel:rgba(10,38,48,.88);--panel2:#143b49;--line:rgba(116,229,217,.20);--text:#f5ffff;--muted:#a7cdd0;--blue:#71dbff;--gold:#d7ee9d;--green:#72edbd;--red:#ff99a4}
    html[data-theme="forest"]{--bg:#06130f;--bg2:#0d251c;--panel:rgba(13,40,31,.90);--panel2:#173d30;--line:rgba(141,218,178,.18);--text:#f5fff9;--muted:#a9cbbb;--blue:#8ad6c5;--gold:#e2c77b;--green:#73e2a7;--red:#ff9d9d}
    html[data-theme="plum"]{--bg:#120817;--bg2:#26102e;--panel:rgba(43,19,52,.90);--panel2:#3b1c46;--line:rgba(218,154,230,.18);--text:#fff8ff;--muted:#d0b4d4;--blue:#d79bea;--gold:#f0c77d;--green:#96e4b5;--red:#ff9aaa}
    html[data-theme="ember"]{--bg:#160a08;--bg2:#2d1510;--panel:rgba(50,24,18,.90);--panel2:#48261e;--line:rgba(238,170,125,.18);--text:#fff9f4;--muted:#d5b9a8;--blue:#f0a37e;--gold:#f2c36d;--green:#9ed9a4;--red:#ff9494}
    html[data-theme="rose"]{--bg:#160d14;--bg2:#2b1826;--panel:rgba(47,27,42,.90);--panel2:#45283d;--line:rgba(244,174,211,.18);--text:#fff8fc;--muted:#d8b8ca;--blue:#efadd2;--gold:#f0cf91;--green:#9be0ba;--red:#ff9aac}
    html[data-theme="mono"]{--bg:#08090b;--bg2:#15171b;--panel:rgba(27,29,34,.92);--panel2:#22252b;--line:rgba(255,255,255,.12);--text:#fff;--muted:#b5b8bf;--blue:#e2e6ec;--gold:#fff;--green:#c8f7d4;--red:#ffaaaa}

    html{scroll-behavior:smooth} body{background-attachment:fixed!important}
    .app{max-width:900px!important;padding-left:17px!important;padding-right:17px!important}
    header{padding:4px 2px 2px}.brand{gap:12px!important}h1{font-weight:950!important;letter-spacing:-1.25px!important}.subtitle{font-size:12.5px!important}
    .mark{width:46px!important;height:46px!important;border-radius:15px!important}.status{backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px)}
    .tabs{display:flex!important;grid-template-columns:none!important;gap:7px!important;overflow-x:auto!important;padding:3px 1px 7px!important;margin:16px 0 19px!important;scrollbar-width:none;-webkit-overflow-scrolling:touch}.tabs::-webkit-scrollbar{display:none}
    .tab{flex:0 0 auto!important;min-width:77px!important;padding:11px 13px!important;border-radius:15px!important;box-shadow:none!important;white-space:nowrap;font-size:12px!important;transition:transform .14s ease,filter .14s ease}.tab:active{transform:scale(.97)}.tab.active{box-shadow:0 8px 26px rgba(70,135,210,.18)!important}
    .hero{border-radius:26px!important;padding:19px!important;backdrop-filter:blur(22px);-webkit-backdrop-filter:blur(22px);box-shadow:0 18px 50px rgba(0,0,0,.18)!important}.hero h2{letter-spacing:-.45px}
    .card,.metric,.todoMetric,.monthMetric{backdrop-filter:blur(18px);-webkit-backdrop-filter:blur(18px);box-shadow:0 11px 32px rgba(0,0,0,.16)!important;border-color:color-mix(in srgb,var(--line) 82%,transparent)!important}.card{border-radius:20px!important}.metric,.todoMetric,.monthMetric{border-radius:18px!important}
    .title{letter-spacing:-.18px}.sectionHead h2{letter-spacing:-.25px}
    button{transition:transform .13s ease,filter .13s ease}button:active{transform:scale(.975)}
    input,select{border-radius:14px!important;background:color-mix(in srgb,var(--panel2) 88%,transparent)!important;min-height:44px}input:focus,select:focus{box-shadow:0 0 0 3px color-mix(in srgb,var(--blue) 17%,transparent)}
    .route{border:1px solid color-mix(in srgb,var(--line) 75%,transparent);border-radius:15px!important}
    .gap{border-style:solid!important;border-color:color-mix(in srgb,var(--blue) 24%,var(--line))!important;background:linear-gradient(135deg,color-mix(in srgb,var(--blue) 5%,transparent),transparent),var(--panel)!important}.gapAction{border-color:color-mix(in srgb,var(--blue) 35%,var(--line))!important}
    .weekday{padding:12px 2px!important}.bar{height:7px!important}
    .bottom{background:color-mix(in srgb,var(--bg) 78%,transparent)!important;backdrop-filter:blur(28px)!important;-webkit-backdrop-filter:blur(28px)!important}.bottomin button{min-height:48px;border-radius:16px!important}
    .themeTiles{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-top:11px}.themeTile{display:flex;align-items:center;gap:9px;text-align:left;background:var(--panel2);color:var(--text);border:1px solid var(--line);border-radius:14px;padding:10px;font-size:11px}.themeTile.active{box-shadow:inset 0 0 0 2px var(--gold)}.themeDot{width:20px;height:20px;border-radius:7px;background:linear-gradient(135deg,var(--blue),var(--gold));border:1px solid var(--line);flex:0 0 20px}
    @media(max-width:680px){.app{padding-left:13px!important;padding-right:13px!important}.tab{min-width:72px!important;padding:10px 11px!important}.status{max-width:48%;line-height:1.2}.themeTiles{grid-template-columns:1fr 1fr}.hero{padding:17px!important}}
  `;
  document.head.appendChild(style);

  const select = document.getElementById("themeSelect");
  if (select) {
    const selected = prefs.theme || "royal";
    select.innerHTML = themes.map(([value, label]) => `<option value="${value}">${label}</option>`).join("");
    select.value = themes.some(([value]) => value === selected) ? selected : "royal";
    select.onchange = () => setTheme(select.value);

    const host = select.closest(".card") || select.parentElement;
    if (host && !document.getElementById("themeTiles")) {
      const tiles = document.createElement("div");
      tiles.id = "themeTiles";
      tiles.className = "themeTiles";
      host.appendChild(tiles);
    }
  }

  const renderTiles = () => {
    const target = document.getElementById("themeTiles");
    if (!target) return;
    target.innerHTML = themes.map(([value, label]) => `<button class="themeTile ${prefs.theme === value ? "active" : ""}" onclick="setTheme('${value}');window.renderLifeRouteThemeTiles?.()"><span class="themeDot"></span><span>${label}</span></button>`).join("");
  };
  window.renderLifeRouteThemeTiles = renderTiles;

  window.setTheme = function setExpandedTheme(value) {
    prefs.theme = value;
    document.documentElement.dataset.theme = value === "royal" ? "" : value;
    if (select) select.value = value;
    persist();
    renderTiles();
  };

  const weekHint = document.querySelector("#week .section .sectionHead .hint");
  if (weekHint && weekHint.textContent.includes("route-aware")) weekHint.textContent = "route-aware";
  const gapHead = Array.from(document.querySelectorAll("#today .sectionHead")).find(el => el.textContent.includes("Gap opportunities"));
  const gapHint = gapHead?.querySelector(".hint");
  if (gapHint) gapHint.textContent = "tap a gap for ranked To-Dos";

  if (!themes.some(([value]) => value === (prefs.theme || "royal"))) prefs.theme = "royal";
  document.documentElement.dataset.theme = prefs.theme === "royal" ? "" : prefs.theme;
  if (select) select.value = prefs.theme;
  renderTiles();
});