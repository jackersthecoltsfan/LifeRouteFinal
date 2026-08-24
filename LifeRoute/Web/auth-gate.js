// LifeRoute local authentication gate: username + 4-digit PIN.
// This is a device-local app lock, not a cloud identity account. Native builds
// keep the derived credential in iOS Keychain; browser preview uses Web Crypto.
(() => {
  if (window.__lifeRouteAuthGateLoaded) return;
  window.__lifeRouteAuthGateLoaded = true;

  const STORE = "liferoute_auth_browser_v2";
  const SESSION = "liferoute_auth_session_v2";
  const MAX_ATTEMPTS = 5;
  const LOCK_MS = 60_000;
  let nativeConfigured = null;
  let nativeUsernameHint = "";

  const isNative = () => !!window.webkit?.messageHandlers?.lifeRoute;
  const post = payload => {
    try {
      const handler = window.webkit?.messageHandlers?.lifeRoute;
      if (!handler) return false;
      handler.postMessage(payload);
      return true;
    } catch (_) { return false; }
  };

  const normalizeUsername = value => String(value || "").trim().toLowerCase();
  const validUsername = value => /^[a-z0-9][a-z0-9._-]{2,23}$/.test(normalizeUsername(value));
  const validPin = value => /^\d{4}$/.test(String(value || ""));
  const usernameHint = value => String(value || "").trim() || "your username";
  const bytesToHex = bytes => Array.from(bytes).map(b => b.toString(16).padStart(2, "0")).join("");
  const hexToBytes = hex => new Uint8Array((String(hex || "").match(/.{1,2}/g) || []).map(x => parseInt(x, 16)));
  const randomHex = count => {
    const bytes = new Uint8Array(count);
    crypto.getRandomValues(bytes);
    return bytesToHex(bytes);
  };
  const derivePin = async (pin, saltHex) => {
    const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(pin), "PBKDF2", false, ["deriveBits"]);
    const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", salt: hexToBytes(saltHex), iterations: 120000, hash: "SHA-256" }, key, 256);
    return bytesToHex(new Uint8Array(bits));
  };

  const readBrowser = () => {
    try { return JSON.parse(localStorage.getItem(STORE) || "null"); } catch (_) { return null; }
  };
  const writeBrowser = value => localStorage.setItem(STORE, JSON.stringify(value));
  const browserConfigured = () => !!readBrowser()?.pinHash;
  const saveSession = () => { try { sessionStorage.setItem(SESSION, "1"); } catch (_) {} };
  const hasSession = () => { try { return sessionStorage.getItem(SESSION) === "1"; } catch (_) { return false; } };
  const clearSession = () => { try { sessionStorage.removeItem(SESSION); } catch (_) {} };

  const styles = document.createElement("style");
  styles.id = "lifeRouteAuthStyles";
  styles.textContent = `
    .lrAuthGate{position:fixed;inset:0;z-index:50000;display:flex;align-items:center;justify-content:center;padding:calc(18px + env(safe-area-inset-top)) 16px calc(18px + env(safe-area-inset-bottom));background:radial-gradient(circle at 15% 5%,rgba(70,136,218,.22),transparent 30%),radial-gradient(circle at 90% 90%,rgba(242,200,109,.13),transparent 34%),linear-gradient(160deg,#040b15,#08172a 56%,#040b15);color:#f8fbff;font-family:Inter,ui-sans-serif,system-ui,-apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}.lrAuthCard{width:min(440px,100%);border-radius:28px;padding:24px 20px;background:rgba(11,25,45,.94);border:1px solid rgba(167,195,231,.18);box-shadow:0 35px 100px rgba(0,0,0,.48);backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px)}.lrAuthBrand{display:flex;align-items:center;gap:11px;margin-bottom:21px}.lrAuthMark{width:48px;height:48px;border-radius:15px;display:grid;place-items:center;background:linear-gradient(135deg,#78b9ff,#f2c86d);color:#07111f;font-weight:1000;box-shadow:0 12px 34px rgba(0,0,0,.28)}.lrAuthBrand b{display:block;font-size:20px}.lrAuthBrand span{display:block;font-size:10px;color:#aebed2;margin-top:2px}.lrAuthTitle{font-size:27px;font-weight:950;letter-spacing:-.7px;margin:0 0 7px}.lrAuthCopy{font-size:12px;line-height:1.5;color:#aebed2;margin:0 0 17px}.lrAuthField{margin-top:10px}.lrAuthField label{display:block;font-size:10px;color:#aebed2;margin-bottom:5px}.lrAuthField input{width:100%;box-sizing:border-box;border:1px solid rgba(167,195,231,.19);background:#122a48;color:#fff;border-radius:13px;padding:13px;font:700 16px/1 system-ui,-apple-system,sans-serif;outline:none}.lrAuthField input:focus{border-color:#78b9ff}.lrAuthPin{letter-spacing:.42em;text-align:center;font-size:24px!important;padding-left:calc(13px + .42em)!important}.lrAuthActions{display:grid;gap:8px;margin-top:15px}.lrAuthPrimary,.lrAuthSecondary{border:0;border-radius:13px;padding:12px;font-weight:950;font-size:13px}.lrAuthPrimary{background:linear-gradient(135deg,#78b9ff,#d6ecff);color:#08172a}.lrAuthSecondary{background:#142a48;color:#fff;border:1px solid rgba(167,195,231,.18)}.lrAuthPrimary:disabled,.lrAuthSecondary:disabled{opacity:.48}.lrAuthStatus{min-height:18px;margin-top:10px;font-size:10px;line-height:1.45;color:#aebed2}.lrAuthStatus.error{color:#ffabab}.lrAuthStatus.good{color:#83e5aa}.lrAuthFooter{margin-top:15px;font-size:9px;color:#7f93aa;line-height:1.45}.lrAuthUserHint{font-size:13px;font-weight:850;color:#f2c86d;margin-bottom:12px}.lrAuthSettingsRow{margin-top:12px;padding:12px;border-radius:15px;background:var(--panel2);border:1px solid var(--line);display:flex;align-items:center;justify-content:space-between;gap:12px}.lrAuthSettingsRow .title{font-size:12px}.lrAuthSettingsRow .meta{font-size:9px}.lrAuthSettingsRow button{white-space:nowrap}
  `;
  document.head.appendChild(styles);

  const ensureGate = () => {
    let gate = document.getElementById("lifeRouteAuthGate");
    if (gate) return gate;
    gate = document.createElement("div");
    gate.id = "lifeRouteAuthGate";
    gate.className = "lrAuthGate";
    gate.innerHTML = `<div class="lrAuthCard"><div class="lrAuthBrand"><div class="lrAuthMark">LR</div><div><b>LifeRoute</b><span>Protected access</span></div></div><div id="lrAuthContent"></div></div>`;
    document.body.appendChild(gate);
    return gate;
  };
  const setStatus = (text, kind = "") => {
    const node = document.getElementById("lrAuthStatus");
    if (!node) return;
    node.textContent = text || "";
    node.className = `lrAuthStatus ${kind}`.trim();
  };
  const setBusy = busy => document.querySelectorAll("#lifeRouteAuthGate button").forEach(button => button.disabled = !!busy);

  const renderLoading = () => {
    ensureGate();
    document.getElementById("lrAuthContent").innerHTML = `<div class="lrAuthTitle">Securing LifeRoute…</div><p class="lrAuthCopy">Checking your login settings.</p>`;
  };

  const renderSetup = () => {
    ensureGate();
    document.getElementById("lrAuthContent").innerHTML = `
      <div class="lrAuthTitle">Create your login</div>
      <p class="lrAuthCopy">Choose a username and a 4-digit PIN. No phone number, SMS, or online account is required.</p>
      <div class="lrAuthField"><label>Username</label><input id="lrAuthNewUsername" type="text" autocomplete="username" autocapitalize="none" spellcheck="false" maxlength="24" placeholder="Choose a username"></div>
      <div class="lrAuthField"><label>4-digit PIN</label><input id="lrAuthNewPin" class="lrAuthPin" type="password" inputmode="numeric" autocomplete="new-password" maxlength="4" placeholder="••••"></div>
      <div class="lrAuthField"><label>Confirm PIN</label><input id="lrAuthNewPin2" class="lrAuthPin" type="password" inputmode="numeric" autocomplete="new-password" maxlength="4" placeholder="••••"></div>
      <div class="lrAuthActions"><button class="lrAuthPrimary" id="lrAuthCreate">Protect LifeRoute</button></div>
      <div id="lrAuthStatus" class="lrAuthStatus"></div>
      <div class="lrAuthFooter">Username: 3–24 characters using letters, numbers, periods, underscores, or hyphens. Your PIN is stored only as a salted derived credential. On iPhone that credential lives in Keychain.</div>`;
    document.getElementById("lrAuthCreate").onclick = createLogin;
  };

  const renderLogin = hint => {
    ensureGate();
    document.getElementById("lrAuthContent").innerHTML = `
      <div class="lrAuthTitle">Welcome back</div>
      <p class="lrAuthCopy">Enter your username and 4-digit PIN to unlock LifeRoute.</p>
      ${hint ? `<div class="lrAuthUserHint">Username: ${escapeHTML(hint)}</div>` : ""}
      <div class="lrAuthField"><label>Username</label><input id="lrAuthLoginUsername" type="text" autocomplete="username" autocapitalize="none" spellcheck="false" maxlength="24" placeholder="Username" value="${escapeAttr(hint || "")}"></div>
      <div class="lrAuthField"><label>4-digit PIN</label><input id="lrAuthLoginPin" class="lrAuthPin" type="password" inputmode="numeric" autocomplete="current-password" maxlength="4" placeholder="••••"></div>
      <div class="lrAuthActions"><button class="lrAuthPrimary" id="lrAuthUnlock">Unlock LifeRoute</button></div>
      <div id="lrAuthStatus" class="lrAuthStatus"></div>
      <div class="lrAuthFooter">This login protects access on this device. It is not a cloud account and does not sync credentials between devices.</div>`;
    document.getElementById("lrAuthUnlock").onclick = unlock;
    document.getElementById("lrAuthLoginPin")?.addEventListener("keydown", event => { if (event.key === "Enter") unlock(); });
  };

  function escapeHTML(value) {
    return String(value || "").replace(/[&<>"']/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#039;" })[c]);
  }
  function escapeAttr(value) { return escapeHTML(value); }

  const dismiss = () => {
    saveSession();
    document.getElementById("lifeRouteAuthGate")?.remove();
    document.dispatchEvent(new CustomEvent("liferoute-auth-unlocked"));
  };

  async function createLogin() {
    const username = normalizeUsername(document.getElementById("lrAuthNewUsername")?.value);
    const pin = String(document.getElementById("lrAuthNewPin")?.value || "");
    const confirm = String(document.getElementById("lrAuthNewPin2")?.value || "");
    if (!validUsername(username)) return setStatus("Choose a valid username with 3–24 characters.", "error");
    if (!validPin(pin)) return setStatus("Choose a 4-digit numeric PIN.", "error");
    if (pin !== confirm) return setStatus("The two PIN entries do not match.", "error");
    setBusy(true); setStatus("Securing your login…");
    try {
      if (isNative()) {
        post({ action: "authSetCredentials", username, pin });
        return;
      }
      const salt = randomHex(16);
      const pinHash = await derivePin(pin, salt);
      writeBrowser({ username, salt, pinHash, failedAttempts: 0, lockedUntil: 0, createdAt: Date.now() });
      dismiss();
    } catch (_) {
      setBusy(false); setStatus("Could not save your login.", "error");
    }
  }

  async function unlock() {
    const username = normalizeUsername(document.getElementById("lrAuthLoginUsername")?.value);
    const pin = String(document.getElementById("lrAuthLoginPin")?.value || "");
    if (!validUsername(username) || !validPin(pin)) return setStatus("Enter your username and 4-digit PIN.", "error");
    setBusy(true); setStatus("Checking…");
    if (isNative()) {
      post({ action: "authVerifyCredentials", username, pin });
      return;
    }
    try {
      const data = readBrowser();
      if (!data) { setBusy(false); return renderSetup(); }
      const now = Date.now();
      if (Number(data.lockedUntil || 0) > now) {
        const seconds = Math.max(1, Math.ceil((Number(data.lockedUntil) - now) / 1000));
        setBusy(false); return setStatus(`Too many attempts. Try again in ${seconds} seconds.`, "error");
      }
      const pinHash = await derivePin(pin, data.salt);
      const success = username === normalizeUsername(data.username) && pinHash === data.pinHash;
      if (success) {
        writeBrowser({ ...data, failedAttempts: 0, lockedUntil: 0 });
        dismiss();
        return;
      }
      let attempts = Number(data.failedAttempts || 0) + 1;
      let lockedUntil = 0;
      if (attempts >= MAX_ATTEMPTS) { attempts = 0; lockedUntil = now + LOCK_MS; }
      writeBrowser({ ...data, failedAttempts: attempts, lockedUntil });
      setBusy(false);
      setStatus(lockedUntil ? "Too many incorrect attempts. Locked for 60 seconds." : "Username or PIN is incorrect.", "error");
    } catch (_) {
      setBusy(false); setStatus("Could not verify your login.", "error");
    }
  }

  const nativeEventBeforeAuth = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithAuth(evt) {
    if (typeof nativeEventBeforeAuth === "function") nativeEventBeforeAuth(evt);
    if (!evt?.type) return;
    if (evt.type === "authStatus") {
      nativeConfigured = !!evt.configured;
      nativeUsernameHint = String(evt.usernameHint || evt.phoneHint || "");
      if (hasSession()) return dismiss();
      if (nativeConfigured) renderLogin(nativeUsernameHint);
      else renderSetup();
    }
    if (evt.type === "authCredentialSaved") {
      if (evt.success) dismiss();
      else { setBusy(false); setStatus(evt.message || "Could not save the login.", "error"); }
    }
    if (evt.type === "authVerifyResult") {
      if (evt.success) dismiss();
      else {
        setBusy(false);
        const lock = Number(evt.lockedForSeconds || 0);
        setStatus(lock > 0 ? `Too many attempts. Try again in ${lock} seconds.` : (evt.message || "Username or PIN is incorrect."), "error");
      }
    }
  };

  const installSettings = () => {
    const sheet = document.querySelector("#lifeRouteSettingsOverlay .lrSettingsSheet");
    if (!sheet || document.getElementById("lifeRouteAuthSettingsSection")) return false;
    const section = document.createElement("div");
    section.id = "lifeRouteAuthSettingsSection";
    section.className = "lrSettingsSection";
    section.innerHTML = `<div class="lrSettingsSectionHead"><b>Login & security</b><span>username + 4-digit PIN</span></div><div class="lrAuthSettingsRow"><div><div class="title">Lock LifeRoute</div><div class="meta">Require your username and PIN again.</div></div><button type="button" class="secondary" id="lrAuthLockNow">Lock now</button></div>`;
    sheet.appendChild(section);
    section.querySelector("#lrAuthLockNow").onclick = () => {
      clearSession();
      ensureGate();
      if (isNative()) { renderLoading(); post({ action: "authStatus" }); }
      else renderLogin(usernameHint(readBrowser()?.username));
      document.getElementById("lifeRouteSettingsOverlay")?.classList.remove("show");
    };
    return true;
  };

  const start = () => {
    let attempts = 0;
    const settingsTimer = setInterval(() => {
      attempts += 1;
      if (installSettings() || attempts > 100) clearInterval(settingsTimer);
    }, 100);

    if (hasSession()) return;
    renderLoading();
    if (isNative()) post({ action: "authStatus" });
    else if (browserConfigured()) renderLogin(usernameHint(readBrowser()?.username));
    else renderSetup();
  };

  window.LifeRouteAuth = {
    lock() {
      clearSession();
      ensureGate();
      if (isNative()) { renderLoading(); post({ action: "authStatus" }); }
      else if (browserConfigured()) renderLogin(usernameHint(readBrowser()?.username));
      else renderSetup();
    }
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once: true });
  else start();
})();
