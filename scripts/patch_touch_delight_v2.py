from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{label}: source marker missing")
    path.write_text(text.replace(old, new, 1))


# Remove the redundant Session Tools marketing/info hero so functional controls
# begin immediately under the contextual tabs.
rbt = WEB / "rbt-tools.js"
rbt_text = rbt.read_text()
hero = '''      <div class="hero fieldToolsHero">
        <div class="small fieldToolsKicker">DIRECT SESSION TOOLKIT</div>
        <h2>Fast tools for the session itself.</h2>
        <p>Everything here runs locally in LifeRoute: a visual timer, quick scratch notes, First/Then support, and a simple session-plan organizer.</p>
        <div class="sourceLine"><span class="chip on">${icon("briefcase", 13)} Field tools</span><span class="chip">${icon("home", 13)} Local-first</span></div>
      </div>

'''
if hero in rbt_text:
    rbt.write_text(rbt_text.replace(hero, "", 1))
if "DIRECT SESSION TOOLKIT" in rbt.read_text():
    raise SystemExit("redundant Session Tools hero still present")


# Add a tactile layer to all buttons and flowing entry motion to screens/tabs.
delight = WEB / "delight-ui-v1.js"
css_marker = '''    .card,.hero,.metric,.lrContextTabs,.tabs{backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px)}
    .card,.hero,.metric{box-shadow:inset 0 1px rgba(255,255,255,.045),0 10px 30px rgba(0,0,0,.08)!important}
'''
css_replacement = '''    .card,.hero,.metric,.lrContextTabs,.tabs{backdrop-filter:blur(16px);-webkit-backdrop-filter:blur(16px)}
    .card,.hero,.metric{box-shadow:inset 0 1px rgba(255,255,255,.045),0 10px 30px rgba(0,0,0,.08)!important}

    button,[role="button"]{transform-origin:center;will-change:transform;transition:transform .125s cubic-bezier(.2,.92,.24,1.18),filter .125s ease,box-shadow .16s ease,background .16s ease!important;-webkit-tap-highlight-color:transparent}
    button:active,[role="button"]:active,.lrTouchPressed{transform:translate3d(0,2px,0) scale(.945)!important;filter:brightness(1.10) saturate(1.08)!important;box-shadow:inset 0 2px 8px rgba(0,0,0,.20),inset 0 0 0 1px rgba(255,255,255,.10),0 3px 10px rgba(0,0,0,.10)!important}
    .goldButton:active,.primary:active,.lrContextTab.active:active,.tabs .tab.active:active{transform:translate3d(0,2px,0) scale(.94)!important;filter:brightness(1.12) saturate(1.12)!important}
    .view.active{animation:lrViewFlowIn .20s cubic-bezier(.16,.84,.24,1) both}
    .lrContextTabs{animation:lrContextFlowIn .18s cubic-bezier(.16,.84,.24,1) both}
    @keyframes lrViewFlowIn{from{opacity:.25;transform:translate3d(8px,4px,0) scale(.994)}to{opacity:1;transform:none}}
    @keyframes lrContextFlowIn{from{opacity:.35;transform:translate3d(0,3px,0) scale(.992)}to{opacity:1;transform:none}}
'''
replace_once(delight, css_marker, css_replacement, "deep tactile button and screen motion CSS")

# Add native haptics to every meaningful touch. Stronger actions get stronger feedback.
haptic_marker = '''  const classifySound = control => {
    if (control.matches('.goldButton,.primary,[data-lr-setup-pane],[data-lr-tool-group]')) return 'primary';
    if (control.matches('.tab,.lrContextTab,.lrSettingsButton,.lrQuickAddButton')) return 'nav';
    return 'soft';
  };

'''
haptic_replacement = '''  const classifySound = control => {
    if (control.matches('.goldButton,.primary,[data-lr-setup-pane],[data-lr-tool-group]')) return 'primary';
    if (control.matches('.tab,.lrContextTab,.lrSettingsButton,.lrQuickAddButton')) return 'nav';
    return 'soft';
  };

  const hapticStyle = control => {
    if (control.matches('.danger,[data-destructive="true"]')) return 'heavy';
    if (control.matches('.goldButton,.primary,[data-lr-setup-pane],[data-lr-tool-group]')) return 'rigid';
    if (control.matches('.tab,.lrContextTab,.lrSettingsButton,.lrQuickAddButton')) return 'medium';
    return 'medium';
  };
  const haptic = control => {
    try {
      window.webkit?.messageHandlers?.lifeRoute?.postMessage?.({ action:'haptic', style:hapticStyle(control) });
    } catch (_) {}
  };

'''
replace_once(delight, haptic_marker, haptic_replacement, "global touch haptic classification")

pointer_marker = '''  document.addEventListener('pointerdown', () => { ensureAudio(); }, { once: true, capture: true });
  document.addEventListener('pointerup', event => {
    const control = event.target?.closest?.('button,[role="button"]');
    if (!control || control.matches(':disabled') || control.getAttribute('aria-disabled') === 'true') return;
    control.__lrSoundAt = performance.now();
    playSound(classifySound(control));
  }, true);
'''
pointer_replacement = '''  document.addEventListener('pointerdown', () => { ensureAudio(); }, { once: true, capture: true });
  document.addEventListener('pointerdown', event => {
    const control = event.target?.closest?.('button,[role="button"]');
    if (!control || control.matches(':disabled') || control.getAttribute('aria-disabled') === 'true') return;
    control.classList.add('lrTouchPressed');
    haptic(control);
  }, true);
  const releaseTouch = event => event.target?.closest?.('button,[role="button"]')?.classList.remove('lrTouchPressed');
  document.addEventListener('pointercancel', releaseTouch, true);
  document.addEventListener('pointerleave', releaseTouch, true);
  document.addEventListener('pointerup', event => {
    const control = event.target?.closest?.('button,[role="button"]');
    if (!control || control.matches(':disabled') || control.getAttribute('aria-disabled') === 'true') return;
    control.classList.remove('lrTouchPressed');
    control.__lrSoundAt = performance.now();
    playSound(classifySound(control));
  }, true);
'''
replace_once(delight, pointer_marker, pointer_replacement, "touch down haptic and spring release")

# Don't let the manual appointment page itself animate-scroll the document.
replace_once(
    delight,
    "window.scrollTo({ top: 0, behavior: 'smooth' });\n    setTimeout(() => document.getElementById('fDate')?.focus?.({ preventScroll: true }), 240);",
    "window.scrollTo({ top: 0, behavior: 'auto' });\n    setTimeout(() => document.getElementById('fDate')?.focus?.({ preventScroll: true }), 180);",
    "manual appointment scroll stabilization",
)

# Resource filters should not self-scroll either.
text = delight.read_text()
text = text.replace("    if (currentResource === 'custom' && !visible) customCard?.scrollIntoView?.({ block:'nearest' });\n", "")
delight.write_text(text)

verified = delight.read_text()
for marker in [
    "scale(.945)",
    "action:'haptic'",
    "lrViewFlowIn",
    "lrTouchPressed",
]:
    if marker not in verified:
        raise SystemExit(f"touch delight verification failed: missing {marker}")

print("Removed redundant Session Tools hero and deepened LifeRoute tactile/fluid feedback.")
