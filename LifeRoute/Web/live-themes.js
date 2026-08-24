// LifeRoute live metallic wave background.
// Broad reflective ribbons bend and drift like slow cloth/silk waves, but use
// polished metallic light/shadow instead of a literal fabric texture.
(() => {
  const style = document.createElement("style");
  style.id = "lifeRouteLiveThemeStyles";
  style.textContent = `
    :root{
      --metal-base:#06101d;--metal-deep:#0a1d33;
      --metal-a:#387cc5;--metal-b:#d2ad58;--metal-c:#173f6d;
      --metal-hi:rgba(226,242,255,.72);--metal-mid:rgba(123,187,255,.34);--metal-shadow:rgba(0,7,18,.72)
    }
    html[data-theme="obsidian"]{--metal-base:#030405;--metal-deep:#0d1014;--metal-a:#555d68;--metal-b:#c9a957;--metal-c:#252a30;--metal-hi:rgba(248,239,210,.62);--metal-mid:rgba(205,215,226,.22);--metal-shadow:rgba(0,0,0,.80)}
    html[data-theme="carbon"]{--metal-base:#06080b;--metal-deep:#121820;--metal-a:#677b91;--metal-b:#aeb7c2;--metal-c:#2d3947;--metal-hi:rgba(236,245,255,.58);--metal-mid:rgba(170,203,239,.24);--metal-shadow:rgba(0,2,7,.77)}
    html[data-theme="midnight"]{--metal-base:#030510;--metal-deep:#101832;--metal-a:#596bc6;--metal-b:#c6a95e;--metal-c:#30286f;--metal-hi:rgba(220,225,255,.64);--metal-mid:rgba(132,147,255,.30);--metal-shadow:rgba(0,1,15,.76)}
    html[data-theme="navy-noir"]{--metal-base:#010711;--metal-deep:#071a2d;--metal-a:#327fc4;--metal-b:#b99b54;--metal-c:#143c66;--metal-hi:rgba(211,236,255,.65);--metal-mid:rgba(95,176,255,.28);--metal-shadow:rgba(0,4,12,.78)}
    html[data-theme="titanium"]{--metal-base:#08090b;--metal-deep:#181c21;--metal-a:#737d88;--metal-b:#b9aa83;--metal-c:#343a41;--metal-hi:rgba(250,252,255,.60);--metal-mid:rgba(201,215,229,.23);--metal-shadow:rgba(2,3,4,.75)}
    html[data-theme="ocean"]{--metal-base:#010f18;--metal-deep:#06283a;--metal-a:#2c96bd;--metal-b:#c1ab6b;--metal-c:#12576e;--metal-hi:rgba(205,247,255,.65);--metal-mid:rgba(93,214,250,.29);--metal-shadow:rgba(0,8,13,.76)}
    html[data-theme="aurora"]{--metal-base:#021012;--metal-deep:#0a292d;--metal-a:#309b9e;--metal-b:#a8b86a;--metal-c:#235f56;--metal-hi:rgba(214,255,247,.61);--metal-mid:rgba(95,216,209,.28);--metal-shadow:rgba(0,9,9,.74)}
    html[data-theme="forest"]{--metal-base:#020d08;--metal-deep:#0a2419;--metal-a:#3f8268;--metal-b:#b8a460;--metal-c:#24513d;--metal-hi:rgba(220,250,232,.58);--metal-mid:rgba(113,202,164,.25);--metal-shadow:rgba(0,8,5,.76)}
    html[data-theme="plum"]{--metal-base:#09040d;--metal-deep:#25102d;--metal-a:#87569d;--metal-b:#c2a45d;--metal-c:#523061;--metal-hi:rgba(247,222,255,.62);--metal-mid:rgba(194,133,219,.28);--metal-shadow:rgba(7,1,10,.76)}
    html[data-theme="ember"]{--metal-base:#0e0402;--metal-deep:#2b110a;--metal-a:#a44d31;--metal-b:#c49d4f;--metal-c:#6a2c1e;--metal-hi:rgba(255,228,207,.61);--metal-mid:rgba(229,128,86,.26);--metal-shadow:rgba(10,2,0,.77)}
    html[data-theme="slate"]{--metal-base:#0d1116;--metal-deep:#222a33;--metal-a:#58728f;--metal-b:#aa9660;--metal-c:#354353;--metal-hi:rgba(230,241,252,.58);--metal-mid:rgba(132,174,218,.24);--metal-shadow:rgba(3,6,10,.72)}
    html[data-theme="mono"]{--metal-base:#040506;--metal-deep:#141619;--metal-a:#6e7278;--metal-b:#9b9b9b;--metal-c:#292c31;--metal-hi:rgba(255,255,255,.56);--metal-mid:rgba(210,210,210,.19);--metal-shadow:rgba(0,0,0,.78)}
    html[data-theme="daylight"]{--metal-base:#e9f0f7;--metal-deep:#f6f1e4;--metal-a:#769cbc;--metal-b:#c0a25a;--metal-c:#b8cad9;--metal-hi:rgba(255,255,255,.92);--metal-mid:rgba(102,148,190,.19);--metal-shadow:rgba(72,91,108,.16)}

    html{background:var(--metal-base)!important}
    body{position:relative;isolation:isolate;background:transparent!important;min-height:100vh}
    #lifeRouteMetalBackdrop{position:fixed;inset:0;z-index:0;pointer-events:none;overflow:hidden;background:linear-gradient(155deg,var(--metal-base),var(--metal-deep) 48%,var(--metal-base));transform:translateZ(0)}
    .app{position:relative;z-index:2}
    .bottom{z-index:8!important}

    #lifeRouteMetalBackdrop .metalWave{position:absolute;left:-28%;width:156%;height:42%;border-radius:44% 56% 48% 52% / 58% 44% 56% 42%;will-change:transform;transform-origin:50% 50%;filter:blur(1px) saturate(112%);backface-visibility:hidden}
    #lifeRouteMetalBackdrop .metalWave::before{content:"";position:absolute;inset:0;border-radius:inherit;background:
      linear-gradient(98deg,
        transparent 3%,
        var(--metal-shadow) 14%,
        color-mix(in srgb,var(--metal-c) 86%,transparent) 25%,
        var(--metal-mid) 37%,
        var(--metal-hi) 46%,
        color-mix(in srgb,var(--metal-a) 80%,transparent) 55%,
        var(--metal-shadow) 67%,
        color-mix(in srgb,var(--metal-b) 68%,transparent) 80%,
        transparent 96%);
      box-shadow:inset 0 24px 70px rgba(255,255,255,.035),inset 0 -32px 80px rgba(0,0,0,.22)}
    #lifeRouteMetalBackdrop .metalWave::after{content:"";position:absolute;inset:7% -2%;border-radius:inherit;background:linear-gradient(102deg,transparent 11%,rgba(255,255,255,.025) 26%,var(--metal-hi) 45%,rgba(255,255,255,.025) 57%,transparent 84%);opacity:.38;filter:blur(13px);mix-blend-mode:screen}

    #lifeRouteMetalBackdrop .waveOne{top:-8%;opacity:.78}
    #lifeRouteMetalBackdrop .waveTwo{top:26%;height:47%;opacity:.58;filter:blur(3px) saturate(108%)}
    #lifeRouteMetalBackdrop .waveThree{top:62%;height:39%;opacity:.47;filter:blur(5px) saturate(105%)}
    #lifeRouteMetalBackdrop .specular{position:absolute;inset:-18%;will-change:transform;background:
      radial-gradient(ellipse at 24% 22%,var(--metal-hi),transparent 19%),
      radial-gradient(ellipse at 76% 68%,color-mix(in srgb,var(--metal-b) 42%,transparent),transparent 25%),
      linear-gradient(112deg,transparent 30%,rgba(255,255,255,.055) 48%,transparent 63%);
      opacity:.28;filter:blur(28px);mix-blend-mode:screen}

    .card,.metric,.hero,.todoMetric,.monthMetric,.provider,.notice{background-color:color-mix(in srgb,var(--panel) 84%,transparent)!important}
    .bottom{background:color-mix(in srgb,var(--bg) 65%,transparent)!important}
  `;
  document.head.appendChild(style);

  let raf = 0;
  let startedAt = 0;
  const animate = timestamp => {
    if (!startedAt) startedAt = timestamp;
    const t = (timestamp - startedAt) / 1000;
    const one = document.querySelector("#lifeRouteMetalBackdrop .waveOne");
    const two = document.querySelector("#lifeRouteMetalBackdrop .waveTwo");
    const three = document.querySelector("#lifeRouteMetalBackdrop .waveThree");
    const shine = document.querySelector("#lifeRouteMetalBackdrop .specular");

    if (one) one.style.transform = `translate3d(${Math.sin(t*.17)*7}%,${Math.cos(t*.12)*4}%,0) rotate(${(-8 + Math.sin(t*.11)*5).toFixed(2)}deg) scaleX(${(1.07 + Math.sin(t*.09)*.07).toFixed(3)}) scaleY(${(1 + Math.cos(t*.13)*.05).toFixed(3)})`;
    if (two) two.style.transform = `translate3d(${Math.cos(t*.13)*8}%,${Math.sin(t*.15)*5}%,0) rotate(${(6 + Math.cos(t*.10)*6).toFixed(2)}deg) scaleX(${(1.10 + Math.cos(t*.08)*.08).toFixed(3)}) scaleY(${(1 + Math.sin(t*.12)*.06).toFixed(3)})`;
    if (three) three.style.transform = `translate3d(${Math.sin(t*.11+1.8)*7}%,${Math.cos(t*.14+1.2)*4}%,0) rotate(${(-4 + Math.sin(t*.09+1)*5).toFixed(2)}deg) scaleX(${(1.08 + Math.sin(t*.075)*.09).toFixed(3)}) scaleY(${(1 + Math.cos(t*.11)*.05).toFixed(3)})`;
    if (shine) shine.style.transform = `translate3d(${Math.sin(t*.07)*5}%,${Math.cos(t*.06)*4}%,0) rotate(${(Math.sin(t*.05)*3).toFixed(2)}deg) scale(${(1.03 + Math.sin(t*.08)*.04).toFixed(3)})`;

    raf = requestAnimationFrame(animate);
  };

  const mount = () => {
    document.getElementById("lifeRouteMarbleBackdrop")?.remove();
    document.getElementById("lifeRouteLightBackdrop")?.remove();
    let backdrop = document.getElementById("lifeRouteMetalBackdrop");
    if (!backdrop) {
      backdrop = document.createElement("div");
      backdrop.id = "lifeRouteMetalBackdrop";
      backdrop.setAttribute("aria-hidden", "true");
      backdrop.innerHTML = '<div class="metalWave waveOne"></div><div class="metalWave waveTwo"></div><div class="metalWave waveThree"></div><div class="specular"></div>';
      document.body.prepend(backdrop);
    }
    if (raf) cancelAnimationFrame(raf);
    startedAt = 0;
    raf = requestAnimationFrame(animate);
  };

  document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
      if (raf) cancelAnimationFrame(raf);
      raf = 0;
    } else if (!raf) {
      startedAt = 0;
      raf = requestAnimationFrame(animate);
    }
  });

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", mount, { once:true });
  else mount();
})();
