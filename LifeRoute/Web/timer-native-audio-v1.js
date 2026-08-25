// LifeRoute native Visual Timer audio companion.
// In the iPhone app, timer tones are bridged to AVAudioSession.playback so they remain audible
// with the silent switch enabled. Browser preview keeps using visual-timer-v2.js Web Audio.
(() => {
  if (window.__lifeRouteTimerNativeAudioV1Loaded) return;
  window.__lifeRouteTimerNativeAudioV1Loaded = true;

  const SOUND_KEY = 'liferoute_visual_timer_sound_v2';
  const PERIOD_MS = 500;
  const START_HZ = 220;
  const END_HZ = 1320;
  let timer = 0;
  let completed = false;

  const soundEnabled = () => {
    try { return localStorage.getItem(SOUND_KEY) !== '0'; } catch (_) { return true; }
  };
  const post = payload => {
    try {
      const handler = window.webkit?.messageHandlers?.lifeRoute;
      if (!handler?.postMessage) return false;
      handler.postMessage(payload);
      return true;
    } catch (_) { return false; }
  };
  const overlay = () => document.getElementById('visualTimerOverlay');
  const progressElapsed = () => {
    const ring = document.getElementById('visualTimerRing');
    if (!ring) return 0;
    const raw = ring.style.getPropertyValue('--timer-progress').trim();
    const remainingDegrees = Number.parseFloat(raw);
    if (!Number.isFinite(remainingDegrees)) return 0;
    return Math.max(0, Math.min(1, 1 - remainingDegrees / 360));
  };
  const pitch = progress => {
    const eased = Math.pow(Math.max(0, Math.min(1, progress)), 1.18);
    return START_HZ * Math.pow(END_HZ / START_HZ, eased);
  };
  const running = host => {
    if (!host?.classList.contains('show') || document.visibilityState === 'hidden') return false;
    const pause = host.querySelector('#timerPauseResume');
    const ring = host.querySelector('#visualTimerRing');
    return pause?.textContent?.trim() === 'Pause' && !ring?.classList.contains('complete');
  };
  const playTone = (frequency, intensity = .96) => post({ action:'playTimerTone', frequency, intensity });
  const successHaptic = () => post({ action:'haptic', style:'success' });

  const playCompletion = () => {
    if (completed || !soundEnabled()) return;
    completed = true;
    successHaptic();
    const base = END_HZ * .72;
    [0,115,245,390].forEach((delay, index) => {
      const ratios = [1,1.22,1.5,1.82];
      setTimeout(() => playTone(base * ratios[index], 1.0), delay);
    });
  };

  const tick = () => {
    const host = overlay();
    if (!host?.classList.contains('show')) return stop();
    const ring = host.querySelector('#visualTimerRing');
    if (ring?.classList.contains('complete')) {
      playCompletion();
      return;
    }
    completed = false;
    if (!soundEnabled() || !running(host)) return;
    playTone(pitch(progressElapsed()), .96);
  };
  const start = () => {
    if (timer || !overlay()?.classList.contains('show')) return;
    completed = false;
    tick();
    timer = setInterval(tick, PERIOD_MS);
  };
  function stop() {
    if (timer) clearInterval(timer);
    timer = 0;
  }

  const attach = () => {
    const host = overlay();
    if (!host) return false;
    if (host.dataset.lrNativeTimerAudio !== '1') {
      host.dataset.lrNativeTimerAudio = '1';
      const observer = new MutationObserver(() => host.classList.contains('show') ? start() : stop());
      observer.observe(host, { attributes:true, attributeFilter:['class'] });
    }
    if (host.classList.contains('show')) start();
    return true;
  };

  const begin = () => {
    if (!attach()) {
      const observer = new MutationObserver(() => {
        if (!attach()) return;
        observer.disconnect();
      });
      observer.observe(document.body, { childList:true, subtree:true });
    }
    document.addEventListener('visibilitychange', () => {
      if (document.visibilityState === 'hidden') stop();
      else if (overlay()?.classList.contains('show')) start();
    });
    window.addEventListener('pagehide', stop);
  };
  if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', begin, { once:true });
  else begin();
})();
