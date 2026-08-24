// Photorealistic override for LifeRoute nature themes.
// Uses real Unsplash photography with restrained cinematic motion instead of CSS concept-art terrain.
(() => {
  if (window.__lifeRoutePhotorealNatureLoaded) return;
  window.__lifeRoutePhotorealNatureLoaded = true;

  const photo = id => `https://unsplash.com/photos/${id}/download?force=true&w=2400`;
  const PHOTOS = {
    "alpine-sunrise": photo("mhVlYssLoWE"),
    "blue-ridge-mist": photo("U5Rdrv5ZOt8"),
    "golden-rockies": photo("vaPoJZB9Mzg"),
    "moonlit-peaks": photo("sJNzuARVW0s"),
    "ocean-cliffs": photo("G-X7xk52Olg"),
    "tropical-tide": photo("sG2cgXJHg3M"),
    "storm-coast": photo("0dhj8gxONos"),
    "desert-sunset": photo("PDcABuRlJ2Y"),
    "sahara-night": photo("59n5rzOFNec"),
    "red-canyon": photo("Q8Vu-TPzu1c"),
    "snowbound-pines": photo("GtlEnUy0m9A"),
    "arctic-twilight": photo("opcZWej_4Js"),
    "glacier-blue": photo("oxGAYd7wVrA"),
    "emerald-forest": photo("kfVwI-kShCw"),
    "redwood-fog": photo("leeHbTl9qqI"),
    "autumn-valley": photo("--orwXoJ0A4"),
    "waterfall-gorge": photo("5M9S53JUXB8"),
    "northern-lights": photo("gD7KrKqYZFk"),
    "volcanic-dawn": photo("D3K9FAHa82w"),
    "wildflower-highlands": photo("pVfZmrNK5Mg")
  };

  const SCENE_BY_THEME = {
    "alpine-sunrise":"mountain","blue-ridge-mist":"mist","golden-rockies":"mountain","moonlit-peaks":"night",
    "ocean-cliffs":"ocean","tropical-tide":"ocean","storm-coast":"storm","desert-sunset":"desert","sahara-night":"night",
    "red-canyon":"desert","snowbound-pines":"snow","arctic-twilight":"snow","glacier-blue":"ice","emerald-forest":"forest",
    "redwood-fog":"mist","autumn-valley":"mist","waterfall-gorge":"water","northern-lights":"night","volcanic-dawn":"volcano",
    "wildflower-highlands":"meadow"
  };

  const style = document.createElement("style");
  style.id = "lifeRoutePhotorealNatureStyles";
  style.textContent = `
    html[data-nature-theme="true"] #lifeRouteNatureBackdrop{
      background:#07111b!important;isolation:isolate;
    }
    html[data-nature-theme="true"] #lifeRouteNatureBackdrop > *{display:none!important}
    html[data-nature-theme="true"] #lifeRouteNatureBackdrop::before{
      content:"";position:absolute;inset:-5%;z-index:0;
      background-image:var(--lr-nature-photo);background-size:cover;background-position:50% 50%;background-repeat:no-repeat;
      filter:saturate(1.08) contrast(1.06) brightness(.78);
      transform:scale(1.04);will-change:transform,background-position,filter;
      animation:lrNaturePhotoMove 28s ease-in-out infinite alternate;
    }
    html[data-nature-theme="true"] #lifeRouteNatureBackdrop::after{
      content:"";position:absolute;inset:0;z-index:1;pointer-events:none;
      background:linear-gradient(180deg,rgba(2,7,14,.28) 0%,rgba(2,7,14,.05) 31%,rgba(2,7,14,.18) 63%,rgba(2,7,14,.55) 100%),
                 radial-gradient(circle at 50% 16%,transparent 0 30%,rgba(1,5,10,.20) 84%);
    }
    #lrNatureAtmosphere{display:none;position:absolute!important;inset:-12%!important;z-index:2!important;pointer-events:none!important;overflow:hidden!important}
    html[data-nature-theme="true"] #lrNatureAtmosphere{display:block!important}
    #lrNatureAtmosphere::before,#lrNatureAtmosphere::after{content:"";position:absolute;pointer-events:none}

    html[data-photo-scene="mist"] #lrNatureAtmosphere::before,
    html[data-photo-scene="forest"] #lrNatureAtmosphere::before,
    html[data-photo-scene="water"] #lrNatureAtmosphere::before{
      left:-25%;right:-25%;height:34%;bottom:17%;
      background:linear-gradient(90deg,transparent,rgba(224,239,242,.04),rgba(240,247,248,.18),rgba(224,239,242,.05),transparent);
      filter:blur(30px);animation:lrPhotoMist 18s ease-in-out infinite alternate;
    }
    html[data-photo-scene="snow"] #lrNatureAtmosphere::before{
      inset:-12%;background-image:radial-gradient(circle,rgba(255,255,255,.85) 0 1.1px,transparent 1.8px);
      background-size:43px 43px;opacity:.45;animation:lrPhotoSnow 16s linear infinite;
    }
    html[data-photo-scene="storm"] #lrNatureAtmosphere::after{
      inset:0;background:radial-gradient(ellipse at 70% 5%,rgba(214,232,244,.18),transparent 34%);
      opacity:.15;animation:lrStormLight 9s ease-in-out infinite;
    }
    html[data-photo-scene="ocean"] #lrNatureAtmosphere::after,
    html[data-photo-scene="ice"] #lrNatureAtmosphere::after{
      left:-20%;right:-20%;bottom:-8%;height:42%;background:linear-gradient(110deg,transparent 20%,rgba(150,230,245,.08) 46%,rgba(255,255,255,.13) 50%,transparent 72%);
      filter:blur(20px);animation:lrOceanLight 11s ease-in-out infinite alternate;
    }
    html[data-photo-scene="night"] #lifeRouteNatureBackdrop::before{filter:saturate(1.13) contrast(1.08) brightness(.70)}
    html[data-photo-scene="desert"] #lifeRouteNatureBackdrop::before,
    html[data-photo-scene="volcano"] #lifeRouteNatureBackdrop::before{filter:saturate(1.12) contrast(1.08) brightness(.76)}
    html[data-photo-scene="meadow"] #lifeRouteNatureBackdrop::before{filter:saturate(1.13) contrast(1.04) brightness(.78)}

    html[data-nature-theme="true"] .card,html[data-nature-theme="true"] .metric,html[data-nature-theme="true"] .hero,
    html[data-nature-theme="true"] .todoMetric,html[data-nature-theme="true"] .monthMetric,html[data-nature-theme="true"] .provider,
    html[data-nature-theme="true"] .notice{background-color:color-mix(in srgb,var(--panel) 84%,transparent)!important;backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px)}

    .lrThemeCard[data-theme-key] .lrThemePreview{background-size:cover!important;background-position:center!important;filter:saturate(1.05) contrast(1.05) brightness(.78)}
    .lrThemeCard[data-theme-key] .lrThemePreview::before{display:none!important}
    .lrThemeCard[data-theme-key]::after{content:"";position:absolute;inset:0;background:linear-gradient(180deg,transparent 32%,rgba(0,0,0,.62));pointer-events:none}
    .lrThemeCard .lrThemeName{z-index:4!important}

    @keyframes lrNaturePhotoMove{
      0%{transform:translate3d(-1.2%,-.8%,0) scale(1.055);background-position:48% 49%}
      50%{transform:translate3d(.9%,.4%,0) scale(1.085);background-position:52% 51%}
      100%{transform:translate3d(-.3%,1%,0) scale(1.065);background-position:50% 53%}
    }
    @keyframes lrPhotoMist{from{transform:translate3d(-9%,1%,0) scaleX(.94);opacity:.36}to{transform:translate3d(10%,-3%,0) scaleX(1.08);opacity:.7}}
    @keyframes lrPhotoSnow{from{transform:translate3d(-1%,-8%,0)}to{transform:translate3d(5%,11%,0)}}
    @keyframes lrOceanLight{from{transform:translate3d(-8%,0,0) skewX(-8deg);opacity:.25}to{transform:translate3d(9%,-2%,0) skewX(5deg);opacity:.55}}
    @keyframes lrStormLight{0%,84%,100%{opacity:.08}87%{opacity:.34}90%{opacity:.12}93%{opacity:.24}}
    @media(prefers-reduced-motion:reduce){html[data-nature-theme="true"] #lifeRouteNatureBackdrop::before,#lrNatureAtmosphere::before,#lrNatureAtmosphere::after{animation:none!important}}
  `;
  document.head.appendChild(style);

  const currentTheme = () => String(document.documentElement.dataset.theme || window.prefs?.theme || "");
  const applyPhoto = () => {
    const key = currentTheme();
    const url = PHOTOS[key];
    const backdrop = document.getElementById("lifeRouteNatureBackdrop");
    if (!url || !backdrop || document.documentElement.dataset.natureTheme !== "true") return;
    backdrop.style.setProperty("--lr-nature-photo", `url("${url}")`);
    document.documentElement.dataset.photoScene = SCENE_BY_THEME[key] || "nature";
    let atmosphere = document.getElementById("lrNatureAtmosphere");
    if (!atmosphere) {
      atmosphere = document.createElement("div");
      atmosphere.id = "lrNatureAtmosphere";
      backdrop.appendChild(atmosphere);
    }
  };

  const decoratePreviews = () => {
    Object.entries(PHOTOS).forEach(([key,url]) => {
      const preview = document.querySelector(`.lrThemeCard[data-theme-key="${CSS.escape(key)}"] .lrThemePreview`);
      if (preview) preview.style.backgroundImage = `url("${url}")`;
    });
  };

  const observeTheme = () => {
    new MutationObserver(() => {
      applyPhoto();
      decoratePreviews();
    }).observe(document.documentElement,{attributes:true,attributeFilter:["data-theme","data-nature-theme","data-scene"]});
  };

  const start = () => {
    applyPhoto();decoratePreviews();observeTheme();
    [250,700,1400,2600].forEach(delay => setTimeout(() => { applyPhoto();decoratePreviews(); },delay));
  };
  if(document.readyState === "loading") document.addEventListener("DOMContentLoaded",start,{once:true}); else start();
})();
