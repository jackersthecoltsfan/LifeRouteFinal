// Stable runtime binding for LifeRoute Day navigation.
// Avoid inline onclick dependencies so later calendar/render wrappers cannot detach navigation.
(() => {
  if (window.__lifeRouteDayNavigationRuntimeLoaded) return;
  window.__lifeRouteDayNavigationRuntimeLoaded = true;

  const keyForDate = date => {
    const y = date.getFullYear();
    const m = String(date.getMonth() + 1).padStart(2, "0");
    const d = String(date.getDate()).padStart(2, "0");
    return `${y}-${m}-${d}`;
  };

  const dateFromKeySafe = value => {
    const match = String(value || "").match(/^(\d{4})-(\d{2})-(\d{2})$/);
    if (!match) return new Date();
    const date = new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3]), 12, 0, 0, 0);
    return Number.isNaN(date.getTime()) ? new Date() : date;
  };

  const restoreScrollPosition = (x, y) => {
    const restore = () => {
      try { window.scrollTo(x, y); } catch (_) {}
    };
    restore();
    requestAnimationFrame(() => {
      restore();
      requestAnimationFrame(restore);
    });
    setTimeout(restore, 60);
    setTimeout(restore, 180);
  };

  const refreshDay = () => {
    const scrollX = window.scrollX || window.pageXOffset || 0;
    const scrollY = window.scrollY || window.pageYOffset || 0;

    try { localStorage.setItem("liferoute_calendar_view", "today"); } catch (_) {}
    if (typeof window.renderAll === "function") window.renderAll();
    else if (typeof window.renderToday === "function") window.renderToday();
    try { window.showView?.("today"); } catch (_) {}

    const selected = dateFromKeySafe(window.selectedDate);
    const label = selected.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" });
    try { window.setStatus?.(`Day · ${label}`); } catch (_) {}

    restoreScrollPosition(scrollX, scrollY);
  };

  window.shiftSelectedDay = function shiftSelectedDayRuntime(delta) {
    const date = dateFromKeySafe(window.selectedDate);
    date.setDate(date.getDate() + Number(delta || 0));
    window.selectedDate = keyForDate(date);
    refreshDay();
  };

  window.jumpSelectedDayToToday = function jumpSelectedDayToTodayRuntime() {
    window.selectedDate = keyForDate(new Date());
    refreshDay();
  };

  const bind = () => {
    const previous = document.getElementById("dayPrevButton");
    const today = document.getElementById("dayTodayButton");
    const next = document.getElementById("dayNextButton");
    if (!previous || !today || !next) return false;

    if (previous.dataset.dayNavBound !== "1") {
      previous.dataset.dayNavBound = "1";
      previous.addEventListener("click", event => {
        event.preventDefault();
        event.stopPropagation();
        window.shiftSelectedDay(-1);
      });
    }
    if (today.dataset.dayNavBound !== "1") {
      today.dataset.dayNavBound = "1";
      today.addEventListener("click", event => {
        event.preventDefault();
        event.stopPropagation();
        window.jumpSelectedDayToToday();
      });
    }
    if (next.dataset.dayNavBound !== "1") {
      next.dataset.dayNavBound = "1";
      next.addEventListener("click", event => {
        event.preventDefault();
        event.stopPropagation();
        window.shiftSelectedDay(1);
      });
    }
    return true;
  };

  const start = () => {
    bind();
    let attempts = 0;
    const timer = setInterval(() => {
      attempts += 1;
      if (bind() || attempts > 80) clearInterval(timer);
    }, 100);
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
