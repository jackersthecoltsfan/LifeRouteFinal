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

old_startup = '''    // Ask for When-In-Use location once the native interface has settled. iOS itself
    // controls the permission prompt and will not repeatedly re-prompt after a choice.
    setTimeout(() => {
      if (!nativeState.currentLocation && nativeState.locationStatus !== "denied") {
        window.requestLifeRouteLocation();
      }
    }, 850);
'''
new_startup = '''    // Location permission is user-initiated from the Home & location control.
    // Keep the freshness condition structurally available for the later safety-hardening pass,
    // but never trigger a permission prompt automatically at startup.
    setTimeout(() => {
      if (!nativeState.currentLocation && nativeState.locationStatus !== "denied") {
        // Intentionally idle until the user taps Use live location.
      }
    }, 850);
'''
if new_startup not in text:
    if old_startup not in text:
        raise SystemExit("Could not neutralize automatic startup location prompt")
    text = text.replace(old_startup, new_startup, 1)

path.write_text(text)
print("Home save and live-location UI now route through one canonical state/lifecycle facade.")
