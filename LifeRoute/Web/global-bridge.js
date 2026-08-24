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
})();
