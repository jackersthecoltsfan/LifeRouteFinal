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


# Turn Saved Places categories into a real third-level tab row and remove the
# redundant Saved Places hero. Tabs filter the list and switch the relevant editor
# without moving the viewport.
toolbar = WEB / "toolbar-cleanup-v1.js"
toolbar_text = toolbar.read_text()
old_category_css = '''      .lrPlaceCategories{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin:0 0 13px}.lrPlaceCategory{min-height:78px;text-align:left!important;background:color-mix(in srgb,var(--panel) 90%,transparent)!important;color:var(--text)!important;border:1px solid var(--line)!important;border-radius:17px!important;padding:12px!important}.lrPlaceCategory b{display:block;font-size:13px}.lrPlaceCategory span{display:block;font-size:9px;color:var(--muted);line-height:1.35;margin-top:3px}.lrPlaceCategory .lrPlaceGlyph{font-size:20px;margin-bottom:6px;color:var(--gold)}
'''
new_category_css = '''      .lrPlaceCategories{display:flex;gap:4px;width:100%;padding:4px;margin:0 0 13px;border-radius:16px;background:color-mix(in srgb,var(--panel) 58%,transparent);border:1px solid color-mix(in srgb,var(--line) 75%,white 6%);box-shadow:inset 0 1px rgba(255,255,255,.06),0 10px 28px rgba(0,0,0,.08);backdrop-filter:blur(12px);-webkit-backdrop-filter:blur(12px)}.lrPlaceCategory{flex:1 1 0;min-width:0;min-height:42px!important;text-align:center!important;background:transparent!important;color:var(--muted)!important;border:0!important;border-radius:12px!important;padding:8px 6px!important;box-shadow:none!important}.lrPlaceCategory b{display:block;font-size:9.5px;font-weight:900;white-space:nowrap}.lrPlaceCategory span,.lrPlaceCategory .lrPlaceGlyph{display:none!important}.lrPlaceCategory.active{color:var(--text)!important;background:color-mix(in srgb,var(--panel2) 82%,transparent)!important;box-shadow:inset 0 0 0 1px color-mix(in srgb,var(--gold) 30%,var(--line)),0 5px 14px rgba(0,0,0,.10)!important}
'''
if old_category_css in toolbar_text:
    toolbar_text = toolbar_text.replace(old_category_css, new_category_css, 1)
elif new_category_css not in toolbar_text:
    raise SystemExit("place category tab CSS marker missing")

old_focus = '''  const focusPlaceCategory = name => {
    setPlaceCategoryOptions();
    if (name === 'Home') {
      const home = document.getElementById('homeAddressField');
      home?.scrollIntoView({ behavior: 'smooth', block: 'center' });
      setTimeout(() => home?.focus({ preventScroll: true }), 250);
      return;
    }
    const select = document.getElementById('placeType');
    if (select) select.value = name;
    const add = document.getElementById('placeName')?.closest('.section');
    add?.scrollIntoView({ behavior: 'smooth', block: 'start' });
    setTimeout(() => document.getElementById('placeName')?.focus({ preventScroll: true }), 250);
  };
'''
new_focus = '''  let activePlaceCategory = 'Home';
  const normalizedPlaceCategory = value => {
    const type = String(value || '').trim().toLowerCase();
    if (type === 'home') return 'Home';
    if (/gym|coffee|cafe|café|park|library|relax/.test(type)) return 'Relaxation';
    if (/grocery|errand|store|pharmacy|pickup/.test(type)) return 'Errand';
    return 'Other';
  };
  const placeTypeFromCard = card => String(card?.querySelector?.('.small')?.textContent || '').split('·')[0].trim();
  const applyPlaceCategory = () => {
    const pane = document.getElementById('places');
    if (!pane) return;
    const categories = document.getElementById('lifeRoutePlaceCategoriesV2');
    categories?.querySelectorAll?.('[data-lr-place-category]').forEach(button => {
      const active = button.dataset.lrPlaceCategory === activePlaceCategory;
      button.classList.toggle('active', active);
      button.setAttribute('aria-selected', active ? 'true' : 'false');
    });

    const homeSection = document.getElementById('homeAddressField')?.closest('.section');
    const addSection = document.getElementById('placeName')?.closest('.section');
    if (homeSection) homeSection.style.display = activePlaceCategory === 'Home' ? '' : 'none';
    if (addSection) addSection.style.display = activePlaceCategory === 'Home' ? 'none' : '';

    const select = document.getElementById('placeType');
    if (select && activePlaceCategory !== 'Home') select.value = activePlaceCategory;

    const list = document.getElementById('placesList');
    let visible = 0;
    list?.querySelectorAll?.(':scope > .card:not(.empty)').forEach(card => {
      const show = normalizedPlaceCategory(placeTypeFromCard(card)) === activePlaceCategory;
      card.style.display = show ? '' : 'none';
      if (show) visible += 1;
    });
    list?.querySelectorAll?.(':scope > .card.empty').forEach(card => { card.style.display = 'none'; });

    let empty = document.getElementById('lifeRoutePlaceCategoryEmptyV3');
    if (!empty && list) {
      empty = document.createElement('div');
      empty.id = 'lifeRoutePlaceCategoryEmptyV3';
      empty.className = 'card empty';
      list.insertAdjacentElement('afterend', empty);
    }
    if (empty) {
      empty.textContent = activePlaceCategory === 'Home'
        ? 'No saved Home locations yet.'
        : `No ${activePlaceCategory.toLowerCase()} places saved yet.`;
      empty.style.display = visible ? 'none' : '';
    }

    const count = document.getElementById('placeCount');
    if (count) count.textContent = `${visible} ${activePlaceCategory.toLowerCase()} place${visible === 1 ? '' : 's'}`;
  };
  const focusPlaceCategory = name => {
    setPlaceCategoryOptions();
    activePlaceCategory = categoryInfo[name] ? name : 'Other';
    applyPlaceCategory();
  };
'''
if old_focus in toolbar_text:
    toolbar_text = toolbar_text.replace(old_focus, new_focus, 1)
elif new_focus not in toolbar_text:
    raise SystemExit("place category behavior marker missing")

old_install = '''  function installSavedPlaceCategories() {
    const pane = document.getElementById('places');
    if (!pane) return;
    setPlaceCategoryOptions();
    let categories = document.getElementById('lifeRoutePlaceCategoriesV2');
    if (!categories) {
      categories = document.createElement('div');
      categories.id = 'lifeRoutePlaceCategoriesV2';
      categories.className = 'lrPlaceCategories';
      categories.innerHTML = Object.entries(categoryInfo).map(([name, [glyph, description]]) => `<button class="lrPlaceCategory" type="button" data-lr-place-category="${name}"><div class="lrPlaceGlyph">${glyph}</div><b>${name}</b><span>${description}</span></button>`).join('');
      const hero = pane.querySelector('.hero');
      if (hero) hero.insertAdjacentElement('afterend', categories);
      else pane.insertBefore(categories, pane.children[1] || null);
      categories.querySelectorAll('[data-lr-place-category]').forEach(button => button.addEventListener('click', () => focusPlaceCategory(button.dataset.lrPlaceCategory)));
    }
    const heroTitle = pane.querySelector('.hero h2');
    const heroText = pane.querySelector('.hero p');
    if (heroTitle) heroTitle.textContent = 'Saved Places';
    if (heroText) heroText.textContent = 'Organize the places LifeRoute can use for routing and gap suggestions.';
  }
'''
new_install = '''  function installSavedPlaceCategories() {
    const pane = document.getElementById('places');
    if (!pane) return;
    setPlaceCategoryOptions();
    pane.querySelector(':scope > .hero')?.remove();
    let categories = document.getElementById('lifeRoutePlaceCategoriesV2');
    if (!categories) {
      categories = document.createElement('div');
      categories.id = 'lifeRoutePlaceCategoriesV2';
      categories.className = 'lrPlaceCategories';
      categories.setAttribute('role', 'tablist');
      categories.setAttribute('aria-label', 'Saved place category');
      categories.innerHTML = Object.keys(categoryInfo).map(name => `<button class="lrPlaceCategory" type="button" role="tab" data-lr-place-category="${name}"><b>${name}</b></button>`).join('');
      pane.prepend(categories);
      categories.querySelectorAll('[data-lr-place-category]').forEach(button => button.addEventListener('click', () => focusPlaceCategory(button.dataset.lrPlaceCategory)));
    }
    if (!window.__lifeRoutePlaceRenderWrappedV3 && typeof window.renderPlaces === 'function') {
      window.__lifeRoutePlaceRenderWrappedV3 = true;
      const originalRenderPlaces = window.renderPlaces;
      window.renderPlaces = function lifeRouteCategorizedRenderPlaces(...args) {
        const result = originalRenderPlaces.apply(this, args);
        requestAnimationFrame(applyPlaceCategory);
        return result;
      };
    }
    applyPlaceCategory();
  }
'''
if old_install in toolbar_text:
    toolbar_text = toolbar_text.replace(old_install, new_install, 1)
elif new_install not in toolbar_text:
    raise SystemExit("place category installer marker missing")

toolbar.write_text(toolbar_text)
for marker in [
    "activePlaceCategory = 'Home'",
    "role=\"tab\"",
    "pane.querySelector(':scope > .hero')?.remove()",
    "lifeRouteCategorizedRenderPlaces",
    "No saved Home locations yet.",
]:
    if marker not in toolbar.read_text():
        raise SystemExit(f"place category tabs verification failed: missing {marker}")


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

print("Removed redundant Session Tools hero, converted Saved Places categories to tabs, and deepened LifeRoute tactile/fluid feedback.")
