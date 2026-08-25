from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RBT = ROOT / "LifeRoute/Web/rbt-tools.js"
VISUAL = ROOT / "LifeRoute/Web/visual-tools.js"

rbt = RBT.read_text()
visual = VISUAL.read_text()

old_close = '    overlay.querySelector("#timerClose").onclick = () => overlay.classList.remove("show");'
new_close = '''    overlay.querySelector("#timerClose").onclick = () => {
      if (timer.running) pauseTimer();
      else if (timer.interval) {
        clearInterval(timer.interval);
        timer.interval = 0;
      }
      overlay.classList.remove("show");
    };'''
if old_close in rbt:
    rbt = rbt.replace(old_close, new_close, 1)
elif new_close not in rbt:
    raise SystemExit("Could not harden visual timer close lifecycle")

old_pause = '''  function pauseTimer() {
    timer.remainingMs = remainingMs();
    timer.running = false;
    scheduleTimerAlert();
    tickTimer();
  }'''
new_pause = '''  function pauseTimer() {
    timer.remainingMs = remainingMs();
    timer.running = false;
    if (timer.interval) clearInterval(timer.interval);
    timer.interval = 0;
    scheduleTimerAlert();
    tickTimer();
  }'''
if old_pause in rbt:
    rbt = rbt.replace(old_pause, new_pause, 1)
elif new_pause not in rbt:
    raise SystemExit("Could not harden visual timer pause lifecycle")

old_apply = '''  const applyFirstThenVisuals = () => {
    const overlay = document.getElementById("firstThenOverlay");
    if (!overlay) return;'''
new_apply = '''  const applyFirstThenVisuals = () => {
    const overlay = document.getElementById("firstThenOverlay");
    if (!overlay?.classList.contains("show")) return;'''
if old_apply in visual:
    visual = visual.replace(old_apply, new_apply, 1)
elif new_apply not in visual:
    raise SystemExit("Could not gate hidden First/Then visual regeneration")

RBT.write_text(rbt)
VISUAL.write_text(visual)
print("Tools stability hardened: timer intervals tear down on pause/close and hidden First/Then visuals do no work.")
