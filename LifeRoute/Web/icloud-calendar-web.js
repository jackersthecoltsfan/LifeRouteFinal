// LifeRoute web-only iCloud Calendar setup helper.
// Adds a guided Apple/iCloud read-only calendar flow on top of the generic
// Calendar Links feature. Calendar subscription URLs remain in browser storage.
(() => {
  if (window.__lifeRouteICloudCalendarWebLoaded) return;
  window.__lifeRouteICloudCalendarWebLoaded = true;

  const APPLE_HELP = `
    <b>Apple / iCloud Calendar — iPhone setup</b><br><br>
    1. Open the <b>Calendar</b> app on your iPhone.<br>
    2. Tap <b>Calendars</b> at the bottom.<br>
    3. Tap the <b>ⓘ</b> button next to the <b>iCloud</b> calendar you want LifeRoute to read.<br>
    4. Turn on <b>Public Calendar</b>.<br>
    5. Tap <b>Share Link</b>, then copy the calendar URL.<br>
    6. Return to LifeRoute, paste the link below, and tap <b>Add calendar link</b>.<br><br>
    Repeat these steps for each iCloud calendar you want included in LifeRoute.<br><br>
    <b>Read-only:</b> LifeRoute cannot edit the iCloud calendar through this link. When the published calendar updates, Refresh Calendars can pull the newest copy.<br><br>
    <b>Privacy:</b> Apple’s Public Calendar setting means anyone who obtains that URL can view that calendar. Treat the URL like a password. LifeRoute stores it in this browser and does not intentionally send it through a third-party calendar proxy.
  `;

  const installStyles = () => {
    if (document.getElementById("icloudCalendarWebStyles")) return;
    const style = document.createElement("style");
    style.id = "icloudCalendarWebStyles";
    style.textContent = `
      .icloudCalendarGuide{margin:0 0 12px;padding:14px;border-radius:16px;border:1px solid color-mix(in srgb,var(--blue) 32%,var(--line));background:linear-gradient(145deg,color-mix(in srgb,var(--blue) 10%,var(--panel2)),color-mix(in srgb,var(--gold) 5%,var(--panel2)))}
      .icloudCalendarGuideHead{display:flex;gap:11px;align-items:flex-start}.icloudCalendarAppleMark{width:42px;height:42px;flex:0 0 42px;display:grid;place-items:center;border-radius:13px;background:rgba(255,255,255,.10);border:1px solid var(--line);font-size:24px}.icloudCalendarGuide .title{font-size:15px}.icloudCalendarGuide .meta{margin-top:3px}.icloudCalendarSteps{display:grid;gap:7px;margin-top:12px}.icloudCalendarStep{display:grid;grid-template-columns:24px 1fr;gap:8px;align-items:start;color:var(--muted);font-size:10.5px;line-height:1.45}.icloudCalendarStep b{color:var(--text)}.icloudCalendarStepNum{width:24px;height:24px;border-radius:999px;display:grid;place-items:center;background:var(--panel);border:1px solid var(--line);color:var(--gold);font-weight:950}.icloudCalendarGuideActions{display:flex;gap:8px;flex-wrap:wrap;margin-top:12px}.icloudCalendarPrivacy{margin-top:10px;font-size:9.5px;line-height:1.45;color:var(--muted)}.icloudCalendarPrivacy b{color:var(--gold)}
      .icloudCalendarCompatibility{margin-top:8px;padding:9px 10px;border-radius:12px;background:rgba(120,185,255,.06);border:1px solid rgba(120,185,255,.16);font-size:9.5px;line-height:1.45;color:var(--muted)}
    `;
    document.head.appendChild(style);
  };

  const setAppleHelp = () => {
    const help = document.getElementById("calendarLinkHelp");
    if (help) help.innerHTML = APPLE_HELP;
  };

  const chooseICloud = () => {
    const platform = document.getElementById("calendarLinkPlatform");
    if (!platform) return;
    platform.value = "icloud";
    platform.dispatchEvent(new Event("change", { bubbles: true }));
    setAppleHelp();
    const label = document.getElementById("calendarLinkLabel");
    if (label && !label.value.trim()) label.placeholder = "iCloud calendar";
    document.getElementById("calendarLinkURL")?.focus({ preventScroll: true });
    document.getElementById("readOnlyCalendarLinks")?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  const mount = () => {
    const section = document.getElementById("readOnlyCalendarLinks");
    const platform = document.getElementById("calendarLinkPlatform");
    const card = section?.querySelector(".calendarLinkCard");
    if (!section || !platform || !card) return false;
    if (document.getElementById("icloudCalendarGuide")) return true;

    if (!platform.querySelector('option[value="icloud"]')) {
      const option = document.createElement("option");
      option.value = "icloud";
      option.textContent = "Apple / iCloud Calendar";
      platform.insertBefore(option, platform.firstElementChild);
    }

    const guide = document.createElement("div");
    guide.className = "icloudCalendarGuide";
    guide.id = "icloudCalendarGuide";
    guide.innerHTML = `
      <div class="icloudCalendarGuideHead">
        <div class="icloudCalendarAppleMark" aria-hidden="true"></div>
        <div class="grow">
          <div class="title">Sync an iCloud calendar to the web version</div>
          <div class="meta">Use Apple’s read-only Public Calendar link so LifeRoute can load events without direct iPhone Calendar permission.</div>
        </div>
      </div>
      <div class="icloudCalendarSteps">
        <div class="icloudCalendarStep"><span class="icloudCalendarStepNum">1</span><span>On iPhone, open <b>Calendar → Calendars</b>.</span></div>
        <div class="icloudCalendarStep"><span class="icloudCalendarStepNum">2</span><span>Tap <b>ⓘ</b> beside the iCloud calendar you want.</span></div>
        <div class="icloudCalendarStep"><span class="icloudCalendarStepNum">3</span><span>Turn on <b>Public Calendar</b>, then tap <b>Share Link</b>.</span></div>
        <div class="icloudCalendarStep"><span class="icloudCalendarStepNum">4</span><span>Copy the <b>webcal://</b> or <b>https://</b> link and paste it into LifeRoute below.</span></div>
      </div>
      <div class="icloudCalendarGuideActions">
        <button type="button" class="goldButton" id="useICloudCalendarLink">Add iCloud calendar</button>
      </div>
      <div class="icloudCalendarPrivacy"><b>Important:</b> anyone with the Public Calendar URL can view that calendar. Keep the URL private and disable Public Calendar in Apple Calendar whenever you want to revoke the link.</div>
      <div class="icloudCalendarCompatibility">The browser will try to read the calendar directly from its subscription URL. Some calendar hosts block browser cross-site requests. If LifeRoute reports that a feed is blocked, the URL is still valid; the limitation is the host’s browser-access policy rather than your calendar data.</div>
    `;

    const form = card.querySelector(".formgrid");
    card.insertBefore(guide, form || card.firstChild);
    document.getElementById("useICloudCalendarLink")?.addEventListener("click", chooseICloud);

    platform.addEventListener("change", () => {
      if (platform.value === "icloud") setTimeout(setAppleHelp, 0);
    });

    // The original calendar-link handler already accepts webcal:// and https://
    // URLs. Add a friendlier iCloud-specific label and status when selected.
    document.getElementById("addCalendarLink")?.addEventListener("click", () => {
      if (platform.value !== "icloud") return;
      const url = String(document.getElementById("calendarLinkURL")?.value || "").trim();
      if (!url) return;
      const status = document.getElementById("calendarFeedStatus");
      if (status) status.textContent = "iCloud calendar saved · checking the read-only feed…";
    }, true);

    return true;
  };

  installStyles();

  let attempts = 0;
  const timer = setInterval(() => {
    attempts += 1;
    if (mount() || attempts > 80) clearInterval(timer);
  }, 125);

  window.addEventListener("DOMContentLoaded", () => {
    mount();
  });
})();
