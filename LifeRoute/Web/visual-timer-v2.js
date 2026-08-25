// LifeRoute Visual Timer v2: gentle rising chime + bold futuristic presentation.
// Audio is synthesized locally with Web Audio. No audio files, network calls, or cloud services.
(() => {
  if (window.__lifeRouteVisualTimerV2Loaded) return;
  window.__lifeRouteVisualTimerV2Loaded = true;

  const SOUND_KEY = "liferoute_visual_timer_sound_v2";
  const CHIME_PERIOD_MS = 500;
  const START_HZ = 220;
  const END_HZ = 1320;
  const POLL_MS = 70;

  let audioContext = null;
  let audioUnlocked = false;
  let scheduler = 0;
  let lastChimeAt = 0;
  let completionPlayed = false;
  let overlayObserver = null;

  const soundEnabled = () => {
    try { return localStorage.getItem(SOUND_KEY) !== "0"; } catch (_) { return true; }
  };
  const setSoundEnabled = enabled => {
    try { localStorage.setItem(SOUND_KEY, enabled ? "1" : "0"); } catch (_) {}
    syncSoundButton();
    if (!enabled) lastChimeAt = 0;
  };

  const contextClass = () => window.AudioContext || window.webkitAudioContext;
  const ensureAudio = async () => {
    if (!soundEnabled()) return null;
    const AudioContextClass = contextClass();
    if (!AudioContextClass) return null;
    try {
      if (!audioContext) audioContext = new AudioContextClass({ latencyHint: "interactive" });
      if (audioContext.state === "suspended") await audioContext.resume();
      audioUnlocked = audioContext.state === "running";
      return audioUnlocked ? audioContext : null;
    } catch (_) {
      audioUnlocked = false;
      return null;
    }
  };

  const overlay = () => document.getElementById("visualTimerOverlay");
  const running = () => {
    const host = overlay();
    if (!host?.classList.contains("show") || document.visibilityState === "hidden") return false;
    const pause = host.querySelector("#timerPauseResume");
    const ring = host.querySelector("#visualTimerRing");
    return pause?.textContent?.trim() === "Pause" && !ring?.classList.contains("complete");
  };

  const progressElapsed = () => {
    const ring = document.getElementById("visualTimerRing");
    if (!ring) return 0;
    const raw = ring.style.getPropertyValue("--timer-progress").trim();
    const remainingDegrees = Number.parseFloat(raw);
    if (!Number.isFinite(remainingDegrees)) return 0;
    return Math.max(0, Math.min(1, 1 - remainingDegrees / 360));
  };

  // Exponential pitch growth keeps the opening calm while making the final stretch
  // unmistakably higher without ever becoming a harsh alarm.
  const pitchForProgress = progress => {
    const eased = Math.pow(Math.max(0, Math.min(1, progress)), 1.18);
    return START_HZ * Math.pow(END_HZ / START_HZ, eased);
  };

  const playBell = async (frequency, gainScale = 1) => {
    if (!soundEnabled()) return;
    const ctx = await ensureAudio();
    if (!ctx) return;

    const now = ctx.currentTime;
    const master = ctx.createGain();
    master.gain.setValueAtTime(0.0001, now);
    master.gain.exponentialRampToValueAtTime(0.052 * gainScale, now + 0.009);
    master.gain.exponentialRampToValueAtTime(0.0001, now + 0.115);
    master.connect(ctx.destination);

    const fundamental = ctx.createOscillator();
    fundamental.type = "sine";
    fundamental.frequency.setValueAtTime(frequency, now);
    fundamental.frequency.exponentialRampToValueAtTime(frequency * 1.012, now + 0.085);
    fundamental.connect(master);

    const shimmerGain = ctx.createGain();
    shimmerGain.gain.setValueAtTime(0.22, now);
    shimmerGain.gain.exponentialRampToValueAtTime(0.0001, now + 0.075);
    shimmerGain.connect(master);
    const shimmer = ctx.createOscillator();
    shimmer.type = "sine";
    shimmer.frequency.setValueAtTime(frequency * 2.01, now);
    shimmer.connect(shimmerGain);

    fundamental.start(now);
    shimmer.start(now);
    fundamental.stop(now + 0.12);
    shimmer.stop(now + 0.08);
  };

  const playCompletion = async () => {
    if (completionPlayed || !soundEnabled()) return;
    completionPlayed = true;
    const ctx = await ensureAudio();
    if (!ctx) return;
    const base = END_HZ * 0.72;
    [0, 110, 230].forEach((delay, index) => {
      window.setTimeout(() => playBell(base * [1, 1.22, 1.5][index], 0.82), delay);
    });
  };

  const updatePitchReadout = () => {
    const host = overlay();
    const readout = host?.querySelector("#lrTimerPitchReadout");
    if (!readout) return;
    const progress = progressElapsed();
    const hz = Math.round(pitchForProgress(progress));
    readout.textContent = soundEnabled() ? `CHIME ${hz} HZ · RISING` : "CHIME MUTED";
  };

  const schedulerTick = () => {
    const host = overlay();
    if (!host?.classList.contains("show")) {
      stopScheduler();
      return;
    }

    const ring = host.querySelector("#visualTimerRing");
    if (ring?.classList.contains("complete")) {
      playCompletion();
      updatePitchReadout();
      return;
    }

    completionPlayed = false;
    if (!running() || !soundEnabled()) {
      lastChimeAt = 0;
      updatePitchReadout();
      return;
    }

    const now = performance.now();
    if (!lastChimeAt || now - lastChimeAt >= CHIME_PERIOD_MS - 18) {
      lastChimeAt = now;
      playBell(pitchForProgress(progressElapsed()));
    }
    updatePitchReadout();
  };

  const startScheduler = () => {
    if (scheduler || !overlay()?.classList.contains("show")) return;
    completionPlayed = false;
    lastChimeAt = 0;
    scheduler = window.setInterval(schedulerTick, POLL_MS);
    schedulerTick();
  };
  function stopScheduler() {
    if (scheduler) window.clearInterval(scheduler);
    scheduler = 0;
    lastChimeAt = 0;
  }

  const syncSoundButton = () => {
    const button = document.getElementById("lrTimerSoundToggle");
    if (!button) return;
    const enabled = soundEnabled();
    button.setAttribute("aria-pressed", enabled ? "true" : "false");
    button.classList.toggle("muted", !enabled);
    button.innerHTML = `<span class="lrTimerSoundGlyph" aria-hidden="true">${enabled ? "◖))" : "◖×"}</span><span>${enabled ? "Sound on" : "Sound off"}</span>`;
  };

  const decorate = () => {
    const host = overlay();
    if (!host) return false;
    host.classList.add("lrVisualTimerV2");

    const chrome = host.querySelector(".visualTimerChrome");
    if (chrome && !document.getElementById("lrTimerSoundToggle")) {
      const sound = document.createElement("button");
      sound.id = "lrTimerSoundToggle";
      sound.type = "button";
      sound.className = "lrTimerSoundToggle";
      sound.addEventListener("click", async event => {
        event.preventDefault();
        const next = !soundEnabled();
        setSoundEnabled(next);
        if (next) {
          await ensureAudio();
          playBell(pitchForProgress(progressElapsed()), 0.72);
        }
      });
      const reset = chrome.querySelector("#timerReset");
      chrome.insertBefore(sound, reset || null);
    }

    const center = host.querySelector(".visualTimerCenter");
    if (center && !document.getElementById("lrTimerPitchReadout")) {
      const telemetry = document.createElement("div");
      telemetry.className = "lrTimerTelemetry";
      telemetry.innerHTML = '<span class="lrTimerTelemetryDot"></span><span id="lrTimerPitchReadout">CHIME 220 HZ · RISING</span><span class="lrTimerTelemetrySep">•</span><span>0.5 SEC PULSE</span>';
      const message = center.querySelector("#visualTimerMessage");
      if (message) message.insertAdjacentElement("afterend", telemetry);
      else center.appendChild(telemetry);
    }

    const ring = host.querySelector("#visualTimerRing");
    if (ring && !ring.querySelector(".lrTimerInnerGrid")) {
      const grid = document.createElement("div");
      grid.className = "lrTimerInnerGrid";
      grid.setAttribute("aria-hidden", "true");
      ring.prepend(grid);
    }

    syncSoundButton();
    updatePitchReadout();

    if (!overlayObserver) {
      overlayObserver = new MutationObserver(() => {
        if (host.classList.contains("show")) startScheduler();
        else stopScheduler();
      });
      overlayObserver.observe(host, { attributes: true, attributeFilter: ["class"] });
    }
    if (host.classList.contains("show")) startScheduler();
    return true;
  };

  const installStyles = () => {
    if (document.getElementById("lifeRouteVisualTimerV2Styles")) return;
    const style = document.createElement("style");
    style.id = "lifeRouteVisualTimerV2Styles";
    style.textContent = `
      .visualTimerOverlay.lrVisualTimerV2{
        --lr-timer-cyan:#5ce8ff;--lr-timer-violet:#8e78ff;--lr-timer-gold:#f4c75a;
        overflow:hidden;background:
          radial-gradient(circle at 50% 42%,color-mix(in srgb,var(--lr-timer-cyan) 12%,transparent),transparent 28%),
          radial-gradient(circle at 16% 14%,color-mix(in srgb,var(--lr-timer-violet) 10%,transparent),transparent 32%),
          linear-gradient(155deg,#030913 0%,#071322 48%,#02060d 100%)!important;
        isolation:isolate;
      }
      .visualTimerOverlay.lrVisualTimerV2:before{content:"";position:absolute;inset:0;z-index:-2;pointer-events:none;opacity:.24;background-image:linear-gradient(rgba(116,225,255,.06) 1px,transparent 1px),linear-gradient(90deg,rgba(116,225,255,.045) 1px,transparent 1px);background-size:42px 42px;mask-image:radial-gradient(circle at center,#000,transparent 78%);-webkit-mask-image:radial-gradient(circle at center,#000,transparent 78%)}
      .visualTimerOverlay.lrVisualTimerV2:after{content:"";position:absolute;left:50%;top:47%;z-index:-1;width:min(94vw,620px);aspect-ratio:1;border-radius:50%;border:1px solid rgba(93,231,255,.08);box-shadow:0 0 0 34px rgba(93,231,255,.018),0 0 0 74px rgba(142,120,255,.014);transform:translate(-50%,-50%);pointer-events:none;animation:lrTimerHalo 8s ease-in-out infinite alternate}
      .lrVisualTimerV2 .visualTimerChrome{position:relative;z-index:4;grid-template-columns:auto 1fr auto auto!important;gap:8px;max-width:760px;margin:0 auto;padding:7px;border:1px solid rgba(126,222,255,.13);border-radius:18px;background:rgba(5,16,29,.56);box-shadow:0 14px 46px rgba(0,0,0,.2);backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px)}
      .lrVisualTimerV2 .visualTimerChrome>.small{font-size:9px!important;letter-spacing:.2em!important;font-weight:950!important;color:rgba(218,244,255,.75)!important;text-align:left;padding-left:6px}
      .lrVisualTimerV2 .timerChromeButton,.lrTimerSoundToggle{min-height:38px;border:1px solid rgba(123,222,255,.12)!important;border-radius:12px!important;background:rgba(8,25,42,.72)!important;color:#dff7ff!important;padding:8px 10px!important;font-size:9px!important;font-weight:850!important;box-shadow:inset 0 1px rgba(255,255,255,.035)}
      .lrTimerSoundToggle{display:inline-flex;align-items:center;gap:6px;white-space:nowrap}.lrTimerSoundToggle[aria-pressed="true"]{border-color:rgba(92,232,255,.32)!important;box-shadow:0 0 22px rgba(92,232,255,.08),inset 0 1px rgba(255,255,255,.05)}.lrTimerSoundToggle.muted{opacity:.58}.lrTimerSoundGlyph{font-size:11px;color:var(--lr-timer-cyan);letter-spacing:-2px}
      .lrVisualTimerV2 .visualTimerCenter{position:relative;gap:14px!important;height:calc(100% - 64px)!important}
      .lrVisualTimerV2 .visualTimerRing{width:min(76vw,390px)!important;background:conic-gradient(from -90deg,var(--lr-timer-cyan) 0 var(--timer-progress),rgba(28,48,68,.48) var(--timer-progress) 360deg)!important;border:1px solid rgba(114,228,255,.2);box-shadow:0 0 0 8px rgba(92,232,255,.018),0 0 48px rgba(40,194,255,.16),0 34px 90px rgba(0,0,0,.42)!important;transition:box-shadow .25s ease}
      .lrVisualTimerV2 .visualTimerRing:before{content:"";position:absolute;inset:7px;border-radius:50%;border:1px dashed rgba(132,229,255,.15);box-shadow:inset 0 0 34px rgba(68,213,255,.05);animation:lrTimerOrbit 18s linear infinite}
      .lrVisualTimerV2 .visualTimerRing:after{inset:18px!important;background:radial-gradient(circle at 50% 42%,rgba(84,221,255,.10),transparent 34%),radial-gradient(circle at 50% 76%,rgba(142,120,255,.08),transparent 42%),linear-gradient(155deg,#071421,#030912)!important;border:1px solid rgba(126,225,255,.11);box-shadow:inset 0 0 52px rgba(0,0,0,.55)}
      .lrTimerInnerGrid{position:absolute;z-index:1;inset:34px;border-radius:50%;opacity:.18;background:linear-gradient(transparent 49.4%,rgba(108,227,255,.22) 50%,transparent 50.6%),linear-gradient(90deg,transparent 49.4%,rgba(108,227,255,.22) 50%,transparent 50.6%);pointer-events:none}
      .lrVisualTimerV2 .visualTimerValue{z-index:3!important;color:#f3fbff;text-shadow:0 0 18px rgba(94,226,255,.18),0 4px 22px rgba(0,0,0,.5);font-size:clamp(58px,18vw,100px)!important;font-weight:950!important;font-variant-numeric:tabular-nums;letter-spacing:-5px!important}
      .lrVisualTimerV2 .visualTimerMessage{text-transform:uppercase;letter-spacing:.18em;font-size:9px!important;color:rgba(210,239,250,.64)!important}
      .lrTimerTelemetry{display:flex;align-items:center;justify-content:center;gap:7px;min-height:25px;padding:5px 10px;border-radius:999px;border:1px solid rgba(114,224,255,.12);background:rgba(7,19,33,.52);color:rgba(208,239,250,.62);font-size:7px;font-weight:900;letter-spacing:.08em;white-space:nowrap}.lrTimerTelemetryDot{width:5px;height:5px;border-radius:50%;background:var(--lr-timer-cyan);box-shadow:0 0 10px var(--lr-timer-cyan);animation:lrTimerPulse .5s ease-in-out infinite alternate}.lrTimerTelemetrySep{opacity:.35}
      .lrVisualTimerV2 .visualTimerActions{padding:7px;border:1px solid rgba(111,220,255,.1);border-radius:17px;background:rgba(5,16,28,.5);backdrop-filter:blur(12px);-webkit-backdrop-filter:blur(12px)}
      .lrVisualTimerV2 .visualTimerActions button{min-height:43px;border-radius:12px!important;font-weight:900!important}
      .lrVisualTimerV2 .visualTimerRing.complete{background:conic-gradient(from -90deg,#6cf2be 0 360deg)!important;box-shadow:0 0 0 8px rgba(108,242,190,.025),0 0 65px rgba(108,242,190,.22),0 34px 90px rgba(0,0,0,.42)!important}
      @keyframes lrTimerHalo{from{opacity:.56;transform:translate(-50%,-50%) scale(.98)}to{opacity:1;transform:translate(-50%,-50%) scale(1.025)}}
      @keyframes lrTimerOrbit{to{transform:rotate(360deg)}}
      @keyframes lrTimerPulse{from{opacity:.42;transform:scale(.72)}to{opacity:1;transform:scale(1.08)}}
      @media(max-width:680px){.lrVisualTimerV2 .visualTimerChrome{grid-template-columns:auto 1fr auto!important}.lrVisualTimerV2 .visualTimerChrome>.small{display:none}.lrTimerSoundToggle span:last-child{display:none}.lrVisualTimerV2 .visualTimerRing{width:min(82vw,360px)!important}.lrTimerTelemetry{font-size:6.5px;gap:5px}.lrVisualTimerV2 .visualTimerValue{letter-spacing:-4px!important}}
      @media(prefers-reduced-motion:reduce){.visualTimerOverlay.lrVisualTimerV2:after,.lrVisualTimerV2 .visualTimerRing:before,.lrTimerTelemetryDot{animation:none!important}}
    `;
    document.head.appendChild(style);
  };

  const primeAudioFromGesture = event => {
    if (!event.target.closest?.("#timerStartButton,.timerPreset,#timerPauseResume,#lrTimerSoundToggle")) return;
    ensureAudio();
  };

  const start = () => {
    installStyles();
    document.addEventListener("pointerdown", primeAudioFromGesture, true);
    document.addEventListener("touchstart", primeAudioFromGesture, { capture: true, passive: true });
    document.addEventListener("click", event => {
      if (event.target.closest?.("#timerClose")) stopScheduler();
      if (event.target.closest?.("#timerReset")) completionPlayed = false;
      window.setTimeout(decorate, 0);
    }, true);

    // The overlay is created lazily by rbt-tools.js, so observe only added nodes until
    // it appears. Once found, the dedicated overlay observer handles its visibility.
    if (!decorate()) {
      const bodyObserver = new MutationObserver(() => {
        if (!decorate()) return;
        bodyObserver.disconnect();
      });
      bodyObserver.observe(document.body, { childList: true, subtree: true });
    }

    document.addEventListener("visibilitychange", () => {
      if (document.visibilityState === "hidden") stopScheduler();
      else if (overlay()?.classList.contains("show")) startScheduler();
    });
    window.addEventListener("pagehide", stopScheduler);
    window.addEventListener("pageshow", () => {
      if (overlay()?.classList.contains("show")) startScheduler();
    });

    window.LifeRouteVisualTimerV2 = {
      soundEnabled,
      setSoundEnabled,
      pitchForProgress,
      startHz: START_HZ,
      endHz: END_HZ,
      chimePeriodMs: CHIME_PERIOD_MS
    };
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
