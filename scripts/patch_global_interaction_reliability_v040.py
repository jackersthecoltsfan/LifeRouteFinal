from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
DELIGHT = WEB / "delight-ui-v1.js"
NAV_CLEANUP = WEB / "nav-cleanup.js"

# WKWebView must be allowed to complete its native touch -> click synthesis before
# decorative JavaScript mutates the touched control. CSS :active provides immediate
# tactile compression without changing the DOM or class list during pointerdown.
text = DELIGHT.read_text()
text = text.replace(
    'button:active,[role="button"]:active,.lrTouchPressed{',
    'button:active,[role="button"]:active{',
    1,
)
text = text.replace(
    '    .lrTouchPressed{transition:transform .055s cubic-bezier(.18,.92,.22,1),filter .055s ease,box-shadow .075s ease!important}\n',
    '',
    1,
)

unsafe = '''  document.addEventListener('pointerdown', () => { ensureAudio(); }, { once: true, capture: true });
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
safe = '''  // v0.4.0 interaction reliability contract: decorative work happens only after
  // WebKit has delivered a real click. Never mutate a touched button on pointerdown.
  document.addEventListener('click', event => {
    const control = event.target?.closest?.('button,[role="button"]');
    if (!control || control.matches(':disabled') || control.getAttribute('aria-disabled') === 'true') return;
    control.__lrSoundAt = performance.now();
    haptic(control);
    playSound(classifySound(control));
  }, { capture:false, passive:true });
'''
if safe not in text:
    if unsafe not in text:
        raise SystemExit("global interaction pointer handler marker missing")
    text = text.replace(unsafe, safe, 1)

# A legacy Setup subnav handler used capture + stopImmediatePropagation. It is scoped,
# but the newer Setup architecture owns its own buttons, so there is no benefit to
# suppressing sibling handlers. Let clicks continue through the normal event path.
nav = NAV_CLEANUP.read_text()
nav = nav.replace("        event.preventDefault();\n        event.stopImmediatePropagation();\n", "", 1)
NAV_CLEANUP.write_text(nav)
DELIGHT.write_text(text)

verified = DELIGHT.read_text()
for forbidden in [
    "classList.add('lrTouchPressed')",
    "classList.remove('lrTouchPressed')",
    "document.addEventListener('pointerdown', event =>",
    "document.addEventListener('pointerup', event =>",
]:
    if forbidden in verified:
        raise SystemExit(f"global interaction reliability failed: pre-click mutation remains: {forbidden}")
for required in [
    "decorative work happens only after",
    "document.addEventListener('click', event =>",
    "{ capture:false, passive:true }",
    "haptic(control);",
    "playSound(classifySound(control));",
    'button:active,[role="button"]:active{',
]:
    if required not in verified:
        raise SystemExit(f"global interaction reliability failed: missing {required}")
if "stopImmediatePropagation" in NAV_CLEANUP.read_text():
    raise SystemExit("navigation cleanup still suppresses sibling click handlers")

print("v0.4.0 functionality pass: button feedback no longer mutates controls before WebKit delivers click events.")
