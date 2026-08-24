// Subtle animated marble background for every LifeRoute theme.
// The motion is intentionally slow and low-contrast so the UI feels alive
// without becoming distracting or looking like a game/visualizer.
(() => {
  const style = document.createElement("style");
  style.id = "lifeRouteLiveThemeStyles";
  style.textContent = `
    :root{
      --marble-a:#0b2948;--marble-b:#173e66;--marble-c:#8f6e2e;--marble-d:#07111f;
      --marble-light:rgba(140,194,255,.10);--marble-vein:rgba(242,200,109,.055)
    }
    html[data-theme="obsidian"]{--marble-a:#060709;--marble-b:#17191d;--marble-c:#493d24;--marble-d:#020203;--marble-light:rgba(232,197,116,.065);--marble-vein:rgba(232,197,116,.055)}
    html[data-theme="carbon"]{--marble-a:#080b10;--marble-b:#1b222b;--marble-c:#37424f;--marble-d:#050609;--marble-light:rgba(169,199,234,.07);--marble-vein:rgba(215,224,235,.045)}
    html[data-theme="midnight"]{--marble-a:#080b20;--marble-b:#18214a;--marble-c:#463f77;--marble-d:#03040c;--marble-light:rgba(149,167,255,.085);--marble-vein:rgba(230,199,122,.045)}
    html[data-theme="navy-noir"]{--marble-a:#03101c;--marble-b:#0d2b49;--marble-c:#29405f;--marble-d:#02060b;--marble-light:rgba(114,183,255,.08);--marble-vein:rgba(216,185,108,.04)}
    html[data-theme="titanium"]{--marble-a:#0d0f12;--marble-b:#262b31;--marble-c:#41464d;--marble-d:#070809;--marble-light:rgba(196,209,223,.065);--marble-vein:rgba(217,193,138,.04)}
    html[data-theme="ocean"]{--marble-a:#041924;--marble-b:#0a3a4e;--marble-c:#14586b;--marble-d:#020e15;--marble-light:rgba(121,220,255,.08);--marble-vein:rgba(223,200,129,.035)}
    html[data-theme="aurora"]{--marble-a:#061c20;--marble-b:#0b3b40;--marble-c:#285d55;--marble-d:#031011;--marble-light:rgba(120,225,232,.08);--marble-vein:rgba(217,229,143,.04)}
    html[data-theme="forest"]{--marble-a:#061911;--marble-b:#123628;--marble-c:#355742;--marble-d:#020c08;--marble-light:rgba(135,209,190,.075);--marble-vein:rgba(220,196,125,.035)}
    html[data-theme="plum"]{--marble-a:#160b1c;--marble-b:#3a1e46;--marble-c:#62406d;--marble-d:#09040c;--marble-light:rgba(199,156,221,.08);--marble-vein:rgba(229,195,122,.04)}
    html[data-theme="ember"]{--marble-a:#1a0a06;--marble-b:#4a2115;--marble-c:#6d3a27;--marble-d:#0c0403;--marble-light:rgba(226,155,119,.08);--marble-vein:rgba(232,191,105,.045)}
    html[data-theme="slate"]{--marble-a:#15191f;--marble-b:#2c343d;--marble-c:#424b55;--marble-d:#0b0d10;--marble-light:rgba(143,197,255,.065);--marble-vein:rgba(228,193,122,.035)}
    html[data-theme="mono"]{--marble-a:#070809;--marble-b:#1b1d21;--marble-c:#34363b;--marble-d:#020303;--marble-light:rgba(255,255,255,.055);--marble-vein:rgba(255,255,255,.035)}
    html[data-theme="daylight"]{--marble-a:#e6eef8;--marble-b:#f7f4e9;--marble-c:#ccdbea;--marble-d:#f6f9fd;--marble-light:rgba(255,255,255,.48);--marble-vein:rgba(70,105,145,.045)}

    html{background:var(--bg)!important}
    body{position:relative;isolation:isolate;background:transparent!important;min-height:100vh}
    #lifeRouteMarbleBackdrop{position:fixed;inset:-12vh -12vw;z-index:-2;pointer-events:none;overflow:hidden;background:linear-gradient(145deg,var(--marble-d),var(--marble-a) 42%,var(--marble-b) 72%,var(--marble-d));transform:translateZ(0)}
    #lifeRouteMarbleBackdrop .marbleField{position:absolute;inset:-14%;will-change:transform;transform:translateZ(0);filter:blur(20px) saturate(108%)}
    #lifeRouteMarbleBackdrop .marbleFieldA{opacity:.82;background:
      radial-gradient(ellipse at 17% 24%,color-mix(in srgb,var(--marble-b) 88%,transparent) 0 16%,transparent 43%),
      radial-gradient(ellipse at 78% 18%,color-mix(in srgb,var(--marble-c) 44%,transparent) 0 12%,transparent 38%),
      radial-gradient(ellipse at 64% 77%,color-mix(in srgb,var(--marble-b) 76%,transparent) 0 18%,transparent 45%),
      radial-gradient(ellipse at 21% 82%,color-mix(in srgb,var(--marble-a) 85%,transparent) 0 16%,transparent 42%),
      linear-gradient(125deg,transparent 12%,var(--marble-light) 34%,transparent 53%)}
    #lifeRouteMarbleBackdrop .marbleFieldB{opacity:.56;background:
      conic-gradient(from 118deg at 48% 52%,transparent 0 12%,color-mix(in srgb,var(--marble-c) 25%,transparent) 18%,transparent 30% 55%,color-mix(in srgb,var(--marble-b) 42%,transparent) 67%,transparent 82%),
      radial-gradient(ellipse at 84% 68%,color-mix(in srgb,var(--marble-a) 80%,transparent) 0 16%,transparent 45%),
      radial-gradient(ellipse at 35% 45%,var(--marble-light) 0 9%,transparent 36%)}
    #lifeRouteMarbleBackdrop .marbleVeins{position:absolute;inset:-20%;opacity:.72;will-change:transform;mix-blend-mode:soft-light;background:
      repeating-linear-gradient(116deg,transparent 0 74px,var(--marble-vein) 75px 76px,transparent 77px 154px),
      repeating-radial-gradient(ellipse at 40% 45%,transparent 0 92px,var(--marble-vein) 93px 95px,transparent 96px 182px);filter:blur(.4px)}

    @keyframes lrMarbleDriftA{
      0%{transform:translate3d(-2.5%,-1.5%,0) scale(1.05) rotate(-1.2deg)}
      35%{transform:translate3d(2.5%,1%,0) scale(1.10) rotate(.8deg)}
      70%{transform:translate3d(-.5%,3%,0) scale(1.07) rotate(-.3deg)}
      100%{transform:translate3d(-2.5%,-1.5%,0) scale(1.05) rotate(-1.2deg)}
    }
    @keyframes lrMarbleDriftB{
      0%{transform:translate3d(3%,-2%,0) scale(1.10) rotate(.8deg)}
      45%{transform:translate3d(-2%,2.5%,0) scale(1.05) rotate(-1deg)}
      100%{transform:translate3d(3%,-2%,0) scale(1.10) rotate(.8deg)}
    }
    @keyframes lrMarbleVeins{
      0%{transform:translate3d(-1%,0,0) rotate(.15deg)}
      50%{transform:translate3d(1.5%,-1%,0) rotate(-.2deg)}
      100%{transform:translate3d(-1%,0,0) rotate(.15deg)}
    }
    #lifeRouteMarbleBackdrop .marbleFieldA{animation:lrMarbleDriftA 38s ease-in-out infinite}
    #lifeRouteMarbleBackdrop .marbleFieldB{animation:lrMarbleDriftB 52s ease-in-out infinite}
    #lifeRouteMarbleBackdrop .marbleVeins{animation:lrMarbleVeins 68s ease-in-out infinite}

    /* Preserve the restrained glass look over the moving background. */
    .card,.metric,.hero,.todoMetric,.monthMetric,.provider,.notice{background-color:color-mix(in srgb,var(--panel) 88%,transparent)!important}
    .bottom{background:color-mix(in srgb,var(--bg) 69%,transparent)!important}

    @media(prefers-reduced-motion:reduce){
      #lifeRouteMarbleBackdrop .marbleFieldA,#lifeRouteMarbleBackdrop .marbleFieldB,#lifeRouteMarbleBackdrop .marbleVeins{animation:none!important}
    }
  `;
  document.head.appendChild(style);

  const mount = () => {
    if (document.getElementById("lifeRouteMarbleBackdrop")) return;
    const backdrop = document.createElement("div");
    backdrop.id = "lifeRouteMarbleBackdrop";
    backdrop.setAttribute("aria-hidden", "true");
    backdrop.innerHTML = '<div class="marbleField marbleFieldA"></div><div class="marbleField marbleFieldB"></div><div class="marbleVeins"></div>';
    document.body.prepend(backdrop);
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", mount, { once: true });
  else mount();
})();
