// Theme-aware moving light waves for LifeRoute.
// Slow, restrained bands of light drift behind the glass UI so every theme
// feels alive and premium without becoming distracting.
(() => {
  const style = document.createElement("style");
  style.id = "lifeRouteLiveThemeStyles";
  style.textContent = `
    :root{
      --wave-base:#07111f;--wave-deep:#0a2038;--wave-a:rgba(93,166,255,.22);--wave-b:rgba(242,200,109,.15);--wave-c:rgba(78,126,196,.15);--wave-glow:rgba(193,225,255,.12)
    }
    html[data-theme="obsidian"]{--wave-base:#040506;--wave-deep:#0b0d10;--wave-a:rgba(205,213,225,.10);--wave-b:rgba(232,197,116,.18);--wave-c:rgba(103,112,124,.10);--wave-glow:rgba(255,238,191,.08)}
    html[data-theme="carbon"]{--wave-base:#07090c;--wave-deep:#11161d;--wave-a:rgba(169,199,234,.14);--wave-b:rgba(210,220,232,.10);--wave-c:rgba(94,113,136,.12);--wave-glow:rgba(220,234,250,.08)}
    html[data-theme="midnight"]{--wave-base:#040611;--wave-deep:#101735;--wave-a:rgba(117,139,255,.22);--wave-b:rgba(230,199,122,.11);--wave-c:rgba(95,76,176,.16);--wave-glow:rgba(183,194,255,.10)}
    html[data-theme="navy-noir"]{--wave-base:#020812;--wave-deep:#071a2d;--wave-a:rgba(75,155,241,.20);--wave-b:rgba(216,185,108,.10);--wave-c:rgba(35,86,141,.17);--wave-glow:rgba(135,197,255,.10)}
    html[data-theme="titanium"]{--wave-base:#090a0c;--wave-deep:#181c21;--wave-a:rgba(196,209,223,.13);--wave-b:rgba(217,193,138,.09);--wave-c:rgba(107,117,128,.12);--wave-glow:rgba(240,244,248,.07)}
    html[data-theme="ocean"]{--wave-base:#02101a;--wave-deep:#062a3b;--wave-a:rgba(69,194,236,.21);--wave-b:rgba(223,200,129,.09);--wave-c:rgba(27,123,157,.17);--wave-glow:rgba(151,232,255,.10)}
    html[data-theme="aurora"]{--wave-base:#031113;--wave-deep:#0a2e32;--wave-a:rgba(74,210,216,.20);--wave-b:rgba(192,225,132,.11);--wave-c:rgba(69,147,132,.15);--wave-glow:rgba(171,255,240,.09)}
    html[data-theme="forest"]{--wave-base:#030e09;--wave-deep:#0b271b;--wave-a:rgba(91,190,151,.18);--wave-b:rgba(220,196,125,.09);--wave-c:rgba(47,111,79,.15);--wave-glow:rgba(180,238,210,.08)}
    html[data-theme="plum"]{--wave-base:#0b050f;--wave-deep:#25102d;--wave-a:rgba(181,121,207,.19);--wave-b:rgba(229,195,122,.10);--wave-c:rgba(109,63,132,.16);--wave-glow:rgba(235,190,255,.09)}
    html[data-theme="ember"]{--wave-base:#100503;--wave-deep:#30130c;--wave-a:rgba(218,119,79,.18);--wave-b:rgba(232,191,105,.14);--wave-c:rgba(133,55,34,.15);--wave-glow:rgba(255,194,150,.08)}
    html[data-theme="slate"]{--wave-base:#10141a;--wave-deep:#232b34;--wave-a:rgba(113,164,218,.14);--wave-b:rgba(228,193,122,.08);--wave-c:rgba(93,106,122,.14);--wave-glow:rgba(206,226,248,.08)}
    html[data-theme="mono"]{--wave-base:#050607;--wave-deep:#15171a;--wave-a:rgba(255,255,255,.10);--wave-b:rgba(255,255,255,.055);--wave-c:rgba(150,150,150,.09);--wave-glow:rgba(255,255,255,.07)}
    html[data-theme="daylight"]{--wave-base:#edf4fb;--wave-deep:#f9f6ec;--wave-a:rgba(74,138,203,.15);--wave-b:rgba(199,160,76,.11);--wave-c:rgba(151,182,211,.14);--wave-glow:rgba(255,255,255,.52)}

    html{background:var(--wave-base)!important}
    body{position:relative;isolation:isolate;background:transparent!important;min-height:100vh}
    #lifeRouteLightBackdrop{position:fixed;inset:-16vh -14vw;z-index:-3;pointer-events:none;overflow:hidden;background:linear-gradient(160deg,var(--wave-base),var(--wave-deep) 52%,var(--wave-base));transform:translateZ(0)}
    #lifeRouteLightBackdrop .lightWave{position:absolute;left:-18%;width:136%;height:46%;border-radius:50%;filter:blur(42px);opacity:.72;will-change:transform;transform:translate3d(0,0,0) rotate(-7deg)}
    #lifeRouteLightBackdrop .waveA{top:4%;background:linear-gradient(100deg,transparent 5%,var(--wave-a) 34%,var(--wave-glow) 50%,var(--wave-a) 66%,transparent 95%);animation:lrWaveA 24s ease-in-out infinite}
    #lifeRouteLightBackdrop .waveB{top:37%;height:38%;background:linear-gradient(95deg,transparent 7%,var(--wave-c) 30%,var(--wave-b) 50%,var(--wave-c) 70%,transparent 93%);opacity:.54;animation:lrWaveB 31s ease-in-out infinite}
    #lifeRouteLightBackdrop .waveC{top:68%;height:34%;background:linear-gradient(102deg,transparent 4%,var(--wave-b) 28%,var(--wave-glow) 48%,var(--wave-a) 72%,transparent 96%);opacity:.38;animation:lrWaveC 39s ease-in-out infinite}
    #lifeRouteLightBackdrop .waveSheen{position:absolute;inset:-10%;background:radial-gradient(ellipse at 30% 18%,var(--wave-glow),transparent 34%),radial-gradient(ellipse at 77% 64%,color-mix(in srgb,var(--wave-a) 60%,transparent),transparent 38%);filter:blur(34px);opacity:.46;animation:lrWaveSheen 46s ease-in-out infinite;will-change:transform}

    @keyframes lrWaveA{
      0%{transform:translate3d(-7%,-4%,0) rotate(-8deg) scaleX(1.03)}
      50%{transform:translate3d(8%,8%,0) rotate(-3deg) scaleX(1.12)}
      100%{transform:translate3d(-7%,-4%,0) rotate(-8deg) scaleX(1.03)}
    }
    @keyframes lrWaveB{
      0%{transform:translate3d(8%,2%,0) rotate(7deg) scaleX(1.08)}
      50%{transform:translate3d(-7%,-7%,0) rotate(2deg) scaleX(1.16)}
      100%{transform:translate3d(8%,2%,0) rotate(7deg) scaleX(1.08)}
    }
    @keyframes lrWaveC{
      0%{transform:translate3d(-4%,6%,0) rotate(-5deg) scaleX(1.1)}
      50%{transform:translate3d(7%,-5%,0) rotate(1deg) scaleX(1.18)}
      100%{transform:translate3d(-4%,6%,0) rotate(-5deg) scaleX(1.1)}
    }
    @keyframes lrWaveSheen{
      0%{transform:translate3d(-3%,-2%,0) scale(1.02)}
      50%{transform:translate3d(4%,3%,0) scale(1.08)}
      100%{transform:translate3d(-3%,-2%,0) scale(1.02)}
    }

    .card,.metric,.hero,.todoMetric,.monthMetric,.provider,.notice{background-color:color-mix(in srgb,var(--panel) 87%,transparent)!important}
    .bottom{background:color-mix(in srgb,var(--bg) 67%,transparent)!important}

    @media(prefers-reduced-motion:reduce){
      #lifeRouteLightBackdrop .lightWave,#lifeRouteLightBackdrop .waveSheen{animation:none!important}
    }
  `;
  document.head.appendChild(style);

  const mount = () => {
    document.getElementById("lifeRouteMarbleBackdrop")?.remove();
    if (document.getElementById("lifeRouteLightBackdrop")) return;
    const backdrop = document.createElement("div");
    backdrop.id = "lifeRouteLightBackdrop";
    backdrop.setAttribute("aria-hidden", "true");
    backdrop.innerHTML = '<div class="lightWave waveA"></div><div class="lightWave waveB"></div><div class="lightWave waveC"></div><div class="waveSheen"></div>';
    document.body.prepend(backdrop);
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", mount, { once: true });
  else mount();
})();
