// Expose LifeRoute's top-level lexical state through safe live window accessors for late feature modules.
(() => {
  const expose = (name, getter, setter) => {
    try {
      const current = Object.getOwnPropertyDescriptor(window, name);
      if (current && current.configurable === false) return;
      Object.defineProperty(window, name, {
        configurable: true,
        enumerable: false,
        get: getter,
        set: setter
      });
    } catch (_) {}
  };

  expose("prefs", () => prefs, value => { prefs = value; });
  expose("events", () => events, value => { events = value; });
  expose("places", () => places, value => { places = value; });
  expose("nativeState", () => nativeState, value => { nativeState = value; });
  expose("selectedDate", () => selectedDate, value => { selectedDate = value; });

  window.addEventListener("DOMContentLoaded", () => {
    const calendarHeading = Array.from(document.querySelectorAll("#setup .sectionHead h2"))
      .find(node => /calendar inputs/i.test(node.textContent || ""));
    const hint = calendarHeading?.parentElement?.querySelector(".hint");
    if (hint) hint.textContent = "combine your read-only sources";

    const readiness = Array.from(document.querySelectorAll("#setup .notice"))
      .find(node => /integration readiness/i.test(node.closest(".section")?.textContent || ""));
    if (readiness) {
      readiness.innerHTML = '<b>Ready now:</b> Apple Calendar permission/read, read-only iCal / ICS calendar subscriptions, Apple Maps and Google Maps handoff, saved places, route-aware gap suggestions, themes, and local schedule planning.<br><br><b>Optional connection:</b> Google Calendar can also be connected with read-only OAuth when configured.';
    }
  }, { once: true });
})();
