from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"Experience release patch failed: {label} marker not found")
    path.write_text(text.replace(old, new, 1))


# -----------------------------------------------------------------------------
# Liquid navigation compatibility.
# Legacy builds used forced-restart directional classes. The optimized runtime
# intentionally removes that path and scopes indicator work to actual nav hosts.
# If the optimized contract is present, do not reintroduce forced layout work.
# -----------------------------------------------------------------------------
liquid = WEB / "interaction-liquid-v4.js"
liquid_text = liquid.read_text()
optimized_liquid = (
    "no whole-document mutation scans or forced layout animation restarts" in liquid_text
    and "scanKnownHosts" in liquid_text
    and "observer.observe(document.body" not in liquid_text
    and "void pane.offsetWidth" not in liquid_text
)

if not optimized_liquid:
    old = """    requestAnimationFrame(()=>{const pane=document.querySelector('.view.active,.lrSetupPane.active');if(!pane||reduceMotion())return;pane.classList.remove('lrSlideFromRight','lrSlideFromLeft');void pane.offsetWidth;pane.classList.add(direction>=0?'lrSlideFromRight':'lrSlideFromLeft');setTimeout(()=>pane.classList.remove('lrSlideFromRight','lrSlideFromLeft'),340);});
  };
"""
    new = """    const transitionTarget = (() => {
      if (host.matches('.tabs')) return document.querySelector('.view.active');
      if (host.matches('.lrPlaceCategories')) return document.querySelector('#places #placesList') || document.querySelector('#places');
      if (host.matches('.setupSubnav')) return document.querySelector('.lrSetupPane.active,.setupPane.active') || document.querySelector('#setup');
      if (host.matches('.lrThemeCategoryTabs')) return document.querySelector('#lifeRouteSettingsOverlay .lrSettingsSection:not(.lrThemeSectionHidden)') || document.querySelector('#lifeRouteSettingsOverlay .lrSettingsSheet');
      if (host.matches('.lrContextTabs')) {
        if (host.closest('#tools')) return document.querySelector('#tools .toolGrid') || document.querySelector('#tools');
        if (host.closest('#resources')) return document.querySelector('#resources #resourceGroups') || document.querySelector('#resources');
        if (host.closest('#setup')) return document.querySelector('.lrSetupPane.active,.setupPane.active') || document.querySelector('#setup');
      }
      return document.querySelector('.lrSetupPane.active,.setupPane.active,.view.active');
    })();
    requestAnimationFrame(()=>{const pane=transitionTarget;if(!pane||reduceMotion())return;pane.classList.remove('lrSlideFromRight','lrSlideFromLeft');void pane.offsetWidth;pane.classList.add(direction>=0?'lrSlideFromRight':'lrSlideFromLeft');setTimeout(()=>pane.classList.remove('lrSlideFromRight','lrSlideFromLeft'),340);});
  };
"""
    replace_once(liquid, old, new, "submenu directional transition targeting")

    replace_once(
        liquid,
        ".view.active.lrSlideFromRight,.lrSetupPane.active.lrSlideFromRight{animation:lrSlideFromRight .28s cubic-bezier(.2,.82,.2,1) both!important}.view.active.lrSlideFromLeft,.lrSetupPane.active.lrSlideFromLeft{animation:lrSlideFromLeft .28s cubic-bezier(.2,.82,.2,1) both!important}",
        ".lrSlideFromRight{animation:lrSlideFromRight .28s cubic-bezier(.2,.82,.2,1) both!important}.lrSlideFromLeft{animation:lrSlideFromLeft .28s cubic-bezier(.2,.82,.2,1) both!important}",
        "submenu slide class coverage",
    )
    replace_once(
        liquid,
        ".view.active.lrSlideFromRight,.view.active.lrSlideFromLeft,.lrSetupPane.active.lrSlideFromRight,.lrSetupPane.active.lrSlideFromLeft{animation:none!important}",
        ".lrSlideFromRight,.lrSlideFromLeft{animation:none!important}",
        "reduced-motion slide class coverage",
    )

# -----------------------------------------------------------------------------
# Universal autocomplete: keep the broad form coverage the user requested while
# refusing to persist clinical/session free text, client-identifying fields, or
# other sensitive documentation into suggestion history.
# -----------------------------------------------------------------------------
auto = WEB / "universal-autocomplete-v2.js"
replace_once(
    auto,
    "return /\\b(pin|password|passcode|secret|token|api[ -]?key|credential|oauth|auth code)\\b/i.test(signal);",
    "return /\\b(pin|password|passcode|secret|token|api[ -]?key|credential|oauth|auth code|session note|clinical note|clinical|behavior|behaviour|documentation|client first|client last|first2|last2)\\b/i.test(signal);",
    "sensitive autocomplete exclusions",
)

replace_once(
    auto,
    "const value = clean(input.value);\n    if (!value || value.length > 140) return;",
    "const value = clean(input.value);\n    if (!value || value.length > 140 || (input instanceof HTMLTextAreaElement && value.length > 80)) return;",
    "textarea history pressure limit",
)

# -----------------------------------------------------------------------------
# Visual Schedule: retain a small, touch-friendly local state budget.
# -----------------------------------------------------------------------------
schedule = WEB / "visual-schedule-v1.js"
if schedule.exists():
    text = schedule.read_text()
    if "const MAX_STEPS = 12;" not in text:
        text = text.replace(
            "const VISUAL_STORE = 'liferoute_visual_tools_v2';\n  let state = { title:'Visual Schedule', steps:[] };",
            "const VISUAL_STORE = 'liferoute_visual_tools_v2';\n  const MAX_STEPS = 12;\n  let state = { title:'Visual Schedule', steps:[] };",
            1,
        )
        text = text.replace(
            "const resolved = label || icon?.label || '';\n      if (!resolved) return;\n      state.steps.push(",
            "const resolved = label || icon?.label || '';\n      if (!resolved) return;\n      if (state.steps.length >= MAX_STEPS) { if (typeof setStatus === 'function') setStatus(`Visual schedules support up to ${MAX_STEPS} steps`); return; }\n      state.steps.push(",
            1,
        )
        schedule.write_text(text)

liquid_source = liquid.read_text()
if optimized_liquid:
    liquid_markers = ["scanKnownHosts", "installHost(host)", "observer.observe(document.body"]
    if liquid_markers[0] not in liquid_source or liquid_markers[1] not in liquid_source or liquid_markers[2] in liquid_source:
        raise SystemExit("Experience release verification failed: optimized Liquid Glass performance contract missing")
else:
    for marker in ["const transitionTarget = (() =>", "host.matches('.lrThemeCategoryTabs')", ".lrSlideFromRight{animation:"]:
        if marker not in liquid_source:
            raise SystemExit(f"Experience release verification failed: interaction-liquid-v4.js missing {marker}")

for path, markers in {
    auto: ["session note|clinical note", "input instanceof HTMLTextAreaElement && value.length > 80"],
    schedule: ["const MAX_STEPS = 12;", "Visual schedules support up to ${MAX_STEPS} steps"],
}.items():
    source = path.read_text()
    for marker in markers:
        if marker not in source:
            raise SystemExit(f"Experience release verification failed: {path.name} missing {marker}")

print("Unified experience hardened: optimized/scoped navigation accepted, privacy-safe autocomplete history, and bounded Visual Schedule state.")
