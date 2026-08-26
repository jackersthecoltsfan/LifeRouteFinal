from pathlib import Path

path = Path("LifeRoute/Web/smart-context.js")
text = path.read_text()

old_save = '''    document.getElementById("saveHomeButton")?.addEventListener("click", () => {
      prefs.homeAddress = String(document.getElementById("homeAddressField")?.value || "").trim();
      persist();
      renderLocationStatus();
      setStatus(prefs.homeAddress ? "Home commute fallback saved" : "Home fallback cleared");
      setTimeout(() => window.refreshRouteTimes?.(), 120);
    });
'''
new_save = '''    document.getElementById("saveHomeButton")?.addEventListener("click", () => {
      const rawAddress = String(document.getElementById("homeAddressField")?.value || "").trim();
      const savedAddress = window.LifeRouteHomeLocationV3?.persistHome
        ? window.LifeRouteHomeLocationV3.persistHome(rawAddress)
        : rawAddress;
      if (!window.LifeRouteHomeLocationV3?.persistHome) {
        prefs.homeAddress = savedAddress;
        persist();
      }
      renderLocationStatus();
      setStatus(savedAddress ? "Home address saved" : "Home address cleared");
      setTimeout(() => window.refreshRouteTimes?.(), 120);
    });
'''
if new_save not in text:
    if old_save not in text:
        raise SystemExit("Could not consolidate Save Home handler")
    text = text.replace(old_save, new_save, 1)

old_location = '''    window.requestLifeRouteLocation = () => {
      nativeState.locationStatus = "requesting";
      renderLocationStatus();
      if (!postNative({ action: "requestCurrentLocation" })) {
        nativeState.locationStatus = "unavailable";
        renderLocationStatus();
        setStatus("Current location requires the iPhone app build");
      }
    };
'''
new_location = '''    window.requestLifeRouteLocation = () => {
      nativeState.locationStatus = "requesting";
      renderLocationStatus();
      if (window.LifeRouteHomeLocationV3?.startLiveLocation?.()) return;
      if (!postNative({ action: "startLiveLocation" })) {
        nativeState.locationStatus = "unavailable";
        renderLocationStatus();
        setStatus("Live location is unavailable on this device");
      }
    };
'''
if new_location not in text:
    if old_location not in text:
        raise SystemExit("Could not consolidate live-location button handler")
    text = text.replace(old_location, new_location, 1)

startup_prompts = [
'''    // Ask for When-In-Use location once the native interface has settled. iOS itself
    // controls the permission prompt and will not repeatedly re-prompt after a choice.
    setTimeout(() => {
      if (!nativeState.currentLocation && nativeState.locationStatus !== "denied") {
        window.requestLifeRouteLocation();
      }
    }, 850);
''',
'''    // Ask for When-In-Use location once the native interface has settled. iOS itself
    // controls the permission prompt and will not repeatedly re-prompt after a choice.
    setTimeout(() => {
      if (!freshLiveLocation() && nativeState.locationStatus !== "denied") {
        window.requestLifeRouteLocation();
      }
    }, 850);
'''
]
replacement = '''    // Location permission is user-initiated from the Home & location control.
    // Previously enabled live location resumes through live-location-v2.js while visible.
'''
if replacement not in text:
    for startup_prompt in startup_prompts:
        if startup_prompt in text:
            text = text.replace(startup_prompt, replacement, 1)
            break
    else:
        raise SystemExit("Could not remove automatic startup location prompt")

path.write_text(text)
print("Home save and live-location UI now route through one canonical state/lifecycle facade.")
