// LifeRoute authentication gate: phone verification + 4-digit PIN.
// Browser preview can use an explicitly labeled preview SMS code. Native builds
// never fake SMS verification; configure server-side send/verify endpoints first.
(() => {
  if (window.__lifeRouteAuthGateLoaded) return;
  window.__lifeRouteAuthGateLoaded = true;

  const STORE = "liferoute_auth_browser_v1";
  const SESSION = "liferoute_auth_session_v1";
  const PREVIEW_CODE = "246810";
  const MAX_ATTEMPTS = 5;
  const LOCK_MS = 60_000;
  let stage = "loading";
  let verifiedPhone = "";
  let smsToken = "";
  let nativeConfigured = null;
  let nativePhoneHint = "";

  const isNative = () => !!window.webkit?.messageHandlers?.lifeRoute;
  const isPreview = () => !isNative() && document.documentElement.dataset.webPreview === "true";
  const config = () => window.LifeRouteConfig?.auth || {};
  const post = payload => {
    try {
      const handler = window.webkit?.messageHandlers?.lifeRoute;
      if (!handler) return false;
      handler.postMessage(payload);
      return true;
    } catch (_) { return false; }
  };
  const normalizePhone = value => {
    const digits = String(value || "").replace(/\D/g, "");
    if (digits.length === 10) return `+1${digits}`;
    if (digits.length >= 8 && digits.length <= 15) return `+${digits}`;
    return "";
  };
  const prettyPhone = value => {
    const digits = String(value || "").replace(/\D/g, "");
    const local = digits.length === 11 && digits[0] === "1" ? digits.slice(1) : digits;
    return local.length === 10 ? `(${local.slice(0,3)}) ${local.slice(3,6)}-${local.slice(6)}` : value;
  };
  const phoneHint = value => {
    const digits = String(value || "").replace(/\D/g, "");
    return digits.length >= 4 ? `••• ••• ${digits.slice(-4)}` : "your verified phone";
  };
  const bytesToHex = bytes => Array.from(bytes).map(b => b.toString(16).padStart(2,"0")).join("");
  const hexToBytes = hex => new Uint8Array((String(hex || "").match(/.{1,2}/g) || []).map(x => parseInt(x,16)));
  const randomHex = count => {
    const bytes = new Uint8Array(count);
    crypto.getRandomValues(bytes);
    return bytesToHex(bytes);
  };
  const derivePin = async (pin, saltHex) => {
    const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(pin), "PBKDF2", false, ["deriveBits"]);
    const bits = await crypto.subtle.deriveBits({ name:"PBKDF2", salt:hexToBytes(saltHex), iterations:120000, hash:"SHA-256" }, key, 256);
    return bytesToHex(new Uint8Array(bits));
  };
  const readBrowser = () => {
    try { return JSON.parse(localStorage.getItem(STORE) || "null"); } catch (_) { return null; }
  };
  const writeBrowser = value => localStorage.setItem(STORE, JSON.stringify(value));
  const browserLockedUntil = data => Number(data?.lockedUntil || 0);
  const browserConfigured = () => !!readBrowser()?.pinHash;
  const saveSession = () => { try { sessionStorage.setItem(SESSION, "1"); } catch (_) {} };
  const hasSession = () => { try { return sessionStorage.getItem(SESSION) === "1"; } catch (_) { return false; } };
  const clearSession = () => { try { sessionStorage.removeItem(SESSION); } catch (_) {} };

  const styles = document.createElement("style");
  styles.id = "lifeRouteAuthStyles";
  styles.textContent = `
    .lrAuthGate{position:fixed;inset:0;z-index:50000;display:flex;align-items:center;justify-content:center;padding:calc(18px + env(safe-area-inset-top)) 16px calc(18px + env(safe-area-inset-bottom));background:radial-gradient(circle at 15% 5%,rgba(70,136,218,.22),transparent 30%),radial-gradient(circle at 90% 90%,rgba(242,200,109,.13),transparent 34%),linear-gradient(160deg,#040b15,#08172a 56%,#040b15);color:#f8fbff;font-family:Inter,ui-sans-serif,system-ui,-apple-system,sans-serif}.lrAuthCard{width:min(440px,100%);border-radius:28px;padding:24px 20px;background:rgba(11,25,45,.94);border:1px solid rgba(167,195,231,.18);box-shadow:0 35px 100px rgba(0,0,0,.48);backdrop-filter:blur(24px);-webkit-backdrop-filter:blur(24px)}.lrAuthBrand{display:flex;align-items:center;gap:11px;margin-bottom:21px}.lrAuthMark{width:48px;height:48px;border-radius:15px;display:grid;place-items:center;background:linear-gradient(135deg,#78b9ff,#f2c86d);color:#07111f;font-weight:1000;box-shadow:0 12px 34px rgba(0,0,0,.28)}.lrAuthBrand b{display:block;font-size:20px}.lrAuthBrand span{display:block;font-size:10px;color:#aebed2;margin-top:2px}.lrAuthTitle{font-size:27px;font-weight:950;letter-spacing:-.7px;margin:0 0 7px}.lrAuthCopy{font-size:12px;line-height:1.5;color:#aebed2;margin:0 0 17px}.lrAuthField{margin-top:10px}.lrAuthField label{display:block;font-size:10px;color:#aebed2;margin-bottom:5px}.lrAuthField input{width:100%;box-sizing:border-box;border:1px solid rgba(167,195,231,.19);background:#122a48;color:#fff;border-radius:13px;padding:13px;font:700 16px/1 system-ui,-apple-system,sans-serif;outline:none}.lrAuthField input:focus{border-color:#78b9ff}.lrAuthPin{letter-spacing:.42em;text-align:center;font-size:24px!important;padding-left:calc(13px + .42em)!important}.lrAuthActions{display:grid;gap:8px;margin-top:15px}.lrAuthPrimary,.lrAuthSecondary{border:0;border-radius:13px;padding:12px;font-weight:950;font-size:13px}.lrAuthPrimary{background:linear-gradient(135deg,#78b9ff,#d6ecff);color:#08172a}.lrAuthSecondary{background:#142a48;color:#fff;border:1px solid rgba(167,195,231,.18)}.lrAuthPrimary:disabled,.lrAuthSecondary:disabled{opacity:.48}.lrAuthStatus{min-height:18px;margin-top:10px;font-size:10px;line-height:1.45;color:#aebed2}.lrAuthStatus.error{color:#ffabab}.lrAuthStatus.good{color:#83e5aa}.lrAuthPreview{margin-top:12px;padding:10px;border-radius:13px;background:rgba(242,200,109,.08);border:1px solid rgba(242,200,109,.25);color:#d9c690;font-size:10px;line-height:1.45}.lrAuthFooter{margin-top:15px;font-size:9px;color:#7f93aa;line-height:1.45}.lrAuthHidden{display:none!important}.lrAuthPhoneHint{font-size:13px;font-weight:850;color:#f2c86d;margin-bottom:12px}.lrAuthSettingsRow{margin-top:12px;padding:12px;border-radius:15px;background:var(--panel2);border:1px solid var(--line);display:flex;align-items:center;justify-content:space-between;gap:12px}.lrAuthSettingsRow .title{font-size:12px}.lrAuthSettingsRow .meta{font-size:9px}.lrAuthSettingsRow button{white-space:nowrap}
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
  const setStatus = (text, kind="") => {
    const node = document.getElementById("lrAuthStatus");
    if (!node) return;
    node.textContent = text || "";
    node.className = `lrAuthStatus ${kind}`.trim();
  };
  const setBusy = busy => document.querySelectorAll("#lifeRouteAuthGate button").forEach(b => b.disabled = !!busy);

  const renderLoading = () => {
    ensureGate();
    document.getElementById("lrAuthContent").innerHTML = `<div class="lrAuthTitle">Securing LifeRoute…</div><p class="lrAuthCopy">Checking your login settings.</p>`;
  };
  const renderSetupPhone = () => {
    stage = "phone";
    ensureGate();
    document.getElementById("lrAuthContent").innerHTML = `<div class="lrAuthTitle">Set up your login</div><p class="lrAuthCopy">Verify your phone once, then choose a 4-digit PIN for quick protected access.</p><div class="lrAuthField"><label>Mobile number</label><input id="lrAuthPhone" type="tel" inputmode="tel" autocomplete="tel" placeholder="(215) 555-0123"></div><div class="lrAuthActions"><button class="lrAuthPrimary" id="lrAuthSend">Send verification code</button></div><div id="lrAuthStatus" class="lrAuthStatus"></div>${isPreview()?`<div class="lrAuthPreview"><b>Web preview:</b> SMS is simulated only for testing. The preview verification code is <b>${PREVIEW_CODE}</b>. Production builds never use this bypass.</div>`:""}<div class="lrAuthFooter">SMS delivery requires a server-side verification provider. LifeRoute never stores an SMS provider secret in the app.</div>`;
    document.getElementById("lrAuthSend").onclick = sendCode;
  };
  const renderVerify = phone => {
    stage = "verify";
    document.getElementById("lrAuthContent").innerHTML = `<div class="lrAuthTitle">Enter the SMS code</div><p class="lrAuthCopy">We sent a verification code to <b>${prettyPhone(phone)}</b>.</p><div class="lrAuthField"><label>6-digit code</label><input id="lrAuthCode" class="lrAuthPin" type="text" inputmode="numeric" autocomplete="one-time-code" maxlength="6" placeholder="••••••"></div><div class="lrAuthActions"><button class="lrAuthPrimary" id="lrAuthVerify">Verify phone</button><button class="lrAuthSecondary" id="lrAuthBack">Use another number</button></div><div id="lrAuthStatus" class="lrAuthStatus"></div>${isPreview()?`<div class="lrAuthPreview">Preview code: <b>${PREVIEW_CODE}</b></div>`:""}`;
    document.getElementById("lrAuthVerify").onclick = verifyCode;
    document.getElementById("lrAuthBack").onclick = renderSetupPhone;
  };
  const renderChoosePin = phone => {
    stage = "choose-pin";
    document.getElementById("lrAuthContent").innerHTML = `<div class="lrAuthTitle">Choose your PIN</div><p class="lrAuthCopy">Pick a 4-digit PIN. You’ll use your phone number and this PIN to unlock LifeRoute.</p><div class="lrAuthField"><label>4-digit PIN</label><input id="lrAuthNewPin" class="lrAuthPin" type="password" inputmode="numeric" autocomplete="new-password" maxlength="4" placeholder="••••"></div><div class="lrAuthField"><label>Confirm PIN</label><input id="lrAuthNewPin2" class="lrAuthPin" type="password" inputmode="numeric" autocomplete="new-password" maxlength="4" placeholder="••••"></div><div class="lrAuthActions"><button class="lrAuthPrimary" id="lrAuthSavePin">Protect LifeRoute</button></div><div id="lrAuthStatus" class="lrAuthStatus"></div><div class="lrAuthFooter">A 4-digit PIN is convenient but inherently limited. LifeRoute rate-limits repeated guesses, and native builds store the derived credential in iOS Keychain.</div>`;
    verifiedPhone = phone;
    document.getElementById("lrAuthSavePin").onclick = savePin;
  };
  const renderLogin = hint => {
    stage = "login";
    ensureGate();
    document.getElementById("lrAuthContent").innerHTML = `<div class="lrAuthTitle">Welcome back</div><p class="lrAuthCopy">Enter your verified phone number and 4-digit PIN.</p>${hint?`<div class="lrAuthPhoneHint">Account: ${hint}</div>`:""}<div class="lrAuthField"><label>Mobile number</label><input id="lrAuthLoginPhone" type="tel" inputmode="tel" autocomplete="tel" placeholder="Mobile number"></div><div class="lrAuthField"><label>4-digit PIN</label><input id="lrAuthLoginPin" class="lrAuthPin" type="password" inputmode="numeric" autocomplete="current-password" maxlength="4" placeholder="••••"></div><div class="lrAuthActions"><button class="lrAuthPrimary" id="lrAuthUnlock">Unlock LifeRoute</button><button class="lrAuthSecondary" id="lrAuthForgot">Forgot PIN / change phone</button></div><div id="lrAuthStatus" class="lrAuthStatus"></div>`;
    document.getElementById("lrAuthUnlock").onclick = unlock;
    document.getElementById("lrAuthForgot").onclick = () => {
      verifiedPhone = ""; smsToken = ""; renderSetupPhone();
    };
  };
  const dismiss = () => {
    saveSession();
    const gate = document.getElementById("lifeRouteAuthGate");
    if (gate) gate.remove();
    document.dispatchEvent(new CustomEvent("liferoute-auth-unlocked"));
  };

  const apiPost = async (url, payload) => {
    const response = await fetch(url, { method:"POST", headers:{"Content-Type":"application/json"}, credentials:"omit", body:JSON.stringify(payload) });
    const data = await response.json().catch(() => ({}));
    if (!response.ok) throw new Error(data.message || `Verification service error (${response.status})`);
    return data;
  };
  async function sendCode() {
    const phone = normalizePhone(document.getElementById("lrAuthPhone")?.value);
    if (!phone) return setStatus("Enter a valid mobile number.", "error");
    setBusy(true); setStatus("Sending verification code…");
    try {
      if (isPreview()) {
        smsToken = `preview-${Date.now()}`;
        verifiedPhone = phone;
        renderVerify(phone);
        return;
      }
      const url = String(config().smsSendURL || "").trim();
      if (!url) throw new Error("SMS verification is not connected yet. Add a server-side Verify endpoint before enabling account setup in the iPhone build.");
      const result = await apiPost(url, { phone });
      smsToken = String(result.token || result.requestId || "");
      verifiedPhone = phone;
      renderVerify(phone);
    } catch (error) { setStatus(error.message || "Could not send the code.", "error"); }
    finally { setBusy(false); }
  }
  async function verifyCode() {
    const code = String(document.getElementById("lrAuthCode")?.value || "").replace(/\D/g, "");
    if (code.length !== 6) return setStatus("Enter the 6-digit verification code.", "error");
    setBusy(true); setStatus("Verifying…");
    try {
      if (isPreview()) {
        if (code !== PREVIEW_CODE) throw new Error("That preview verification code is incorrect.");
        renderChoosePin(verifiedPhone); return;
      }
      const url = String(config().smsVerifyURL || "").trim();
      if (!url) throw new Error("SMS verification is not connected yet.");
      const result = await apiPost(url, { phone:verifiedPhone, code, token:smsToken });
      if (result.verified !== true && result.success !== true) throw new Error(result.message || "The verification code was not accepted.");
      renderChoosePin(verifiedPhone);
    } catch (error) { setStatus(error.message || "Could not verify the code.", "error"); }
    finally { setBusy(false); }
  }
  async function savePin() {
    const pin = String(document.getElementById("lrAuthNewPin")?.value || "");
    const pin2 = String(document.getElementById("lrAuthNewPin2")?.value || "");
    if (!/^\d{4}$/.test(pin)) return setStatus("Choose exactly 4 digits.", "error");
    if (pin !== pin2) return setStatus("Those PINs do not match.", "error");
    setBusy(true); setStatus("Securing your login…");
    try {
      if (isNative()) {
        if (!post({ action:"authSetCredentials", phone:verifiedPhone, pin })) throw new Error("Could not reach iPhone secure storage.");
        return;
      }
      const salt = randomHex(16);
      const pinHash = await derivePin(pin, salt);
      writeBrowser({ phone:verifiedPhone, salt, pinHash, failed:0, lockedUntil:0, verifiedAt:new Date().toISOString() });
      dismiss();
    } catch (error) { setStatus(error.message || "Could not save your PIN.", "error"); setBusy(false); }
  }
  async function unlock() {
    const phone = normalizePhone(document.getElementById("lrAuthLoginPhone")?.value);
    const pin = String(document.getElementById("lrAuthLoginPin")?.value || "");
    if (!phone) return setStatus("Enter your mobile number.", "error");
    if (!/^\d{4}$/.test(pin)) return setStatus("Enter your 4-digit PIN.", "error");
    setBusy(true); setStatus("Checking PIN…");
    if (isNative()) {
      post({ action:"authVerifyCredentials", phone, pin });
      return;
    }
    const data = readBrowser();
    if (!data?.pinHash) { setBusy(false); renderSetupPhone(); return; }
    const lockedUntil = browserLockedUntil(data);
    if (lockedUntil > Date.now()) {
      setBusy(false); return setStatus(`Too many attempts. Try again in ${Math.ceil((lockedUntil-Date.now())/1000)} seconds.`, "error");
    }
    const hash = await derivePin(pin, data.salt);
    const ok = data.phone === phone && hash === data.pinHash;
    if (ok) {
      data.failed = 0; data.lockedUntil = 0; writeBrowser(data); dismiss(); return;
    }
    data.failed = Number(data.failed || 0) + 1;
    if (data.failed >= MAX_ATTEMPTS) { data.failed = 0; data.lockedUntil = Date.now() + LOCK_MS; }
    writeBrowser(data); setBusy(false);
    setStatus(data.lockedUntil > Date.now() ? "Too many attempts. LifeRoute is locked for 60 seconds." : "Phone number or PIN is incorrect.", "error");
  }

  const nativeEventBeforeAuth = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithAuth(evt) {
    if (typeof nativeEventBeforeAuth === "function") nativeEventBeforeAuth(evt);
    if (!evt?.type) return;
    if (evt.type === "authStatus") {
      nativeConfigured = !!evt.configured;
      nativePhoneHint = String(evt.phoneHint || "");
      if (hasSession()) return dismiss();
      if (nativeConfigured) renderLogin(nativePhoneHint);
      else renderSetupPhone();
    }
    if (evt.type === "authCredentialSaved") {
      if (evt.success) dismiss();
      else { setBusy(false); setStatus(evt.message || "Could not save the PIN.", "error"); }
    }
    if (evt.type === "authVerifyResult") {
      if (evt.success) dismiss();
      else {
        setBusy(false);
        if (Number(evt.lockedForSeconds || 0) > 0) setStatus(`Too many attempts. Try again in ${evt.lockedForSeconds} seconds.`, "error");
        else setStatus(evt.message || "Phone number or PIN is incorrect.", "error");
      }
    }
  };

  const installSettings = () => {
    const sheet = document.querySelector("#lifeRouteSettingsOverlay .lrSettingsSheet");
    if (!sheet || document.getElementById("lifeRouteAuthSettings")) return false;
    const section = document.createElement("div");
    section.id = "lifeRouteAuthSettings";
    section.className = "lrSettingsSection";
    section.innerHTML = `<div class="lrSettingsSectionHead"><b>Login & security</b><span>phone + 4-digit PIN</span></div><div class="lrAuthSettingsRow"><div><div class="title">Lock LifeRoute</div><div class="meta">Require your phone number and PIN again.</div></div><button type="button" class="secondary" id="lrAuthLockNow">Lock now</button></div>`;
    sheet.appendChild(section);
    section.querySelector("#lrAuthLockNow").onclick = () => {
      clearSession();
      ensureGate();
      if (isNative()) { renderLoading(); post({action:"authStatus"}); }
      else renderLogin(phoneHint(readBrowser()?.phone || ""));
      document.getElementById("lifeRouteSettingsOverlay")?.classList.remove("show");
    };
    return true;
  };

  const start = () => {
    if (hasSession()) return;
    renderLoading();
    if (isNative()) {
      post({ action:"authStatus" });
    } else if (browserConfigured()) {
      renderLogin(phoneHint(readBrowser()?.phone || ""));
    } else {
      renderSetupPhone();
    }
    let tries = 0;
    const timer = setInterval(() => { tries += 1; if (installSettings() || tries > 80) clearInterval(timer); }, 120);
  };

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", start, { once:true });
  else start();
})();
