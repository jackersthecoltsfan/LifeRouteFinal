// LifeRoute ABA AI note assistant.
// Screenshot OCR uses Apple Vision through the native bridge; note drafting uses
// Apple Foundation Models. Narrative, screenshot text, and client context stay local.
(() => {
  if (window.__lifeRouteABAAINoteV1Loaded) return;
  window.__lifeRouteABAAINoteV1Loaded = true;

  const pendingOCR = new Map();
  let sequence = 0;
  const clean = value => String(value || "").replace(/\s+/g, " ").trim();
  const safe = value => typeof esc === "function" ? esc(String(value || "")) : String(value || "").replace(/[&<>"']/g, char => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[char]));
  const nativeHandler = () => window.webkit?.messageHandlers?.lifeRoute;

  const fmtPair = value => {
    const letters = String(value || "").replace(/[^a-z]/gi, "").slice(0, 2);
    return letters ? letters.charAt(0).toUpperCase() + letters.slice(1).toLowerCase() : "";
  };
  const codeFor = client => `${fmtPair(client?.first2)}${fmtPair(client?.last2)}`;
  const clients = () => Array.isArray(window.prefs?.clients) ? window.prefs.clients : [];

  const profileFor = code => clients().find(client => codeFor(client) === code) || null;
  const clientOptions = () => ['<option value="">General / no client</option>']
    .concat(clients().map(client => codeFor(client)).filter(code => code.length === 4).map(code => `<option value="${safe(code)}">${safe(code)}</option>`))
    .join("");

  const fileToDataURL = file => new Promise(resolve => {
    if (!file) return resolve("");
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result || ""));
    reader.onerror = () => resolve("");
    reader.readAsDataURL(file);
  });

  const recognizeScreenshot = async file => {
    if (!file || typeof nativeHandler()?.postMessage !== "function") return "";
    const imageBase64 = await fileToDataURL(file);
    if (!imageBase64) return "";
    const requestId = `ocr-${Date.now()}-${++sequence}`;
    return new Promise(resolve => {
      const timeout = setTimeout(() => {
        pendingOCR.delete(requestId);
        resolve("");
      }, 7000);
      pendingOCR.set(requestId, payload => {
        clearTimeout(timeout);
        pendingOCR.delete(requestId);
        resolve(payload?.success ? String(payload.text || "").slice(0, 12000) : "");
      });
      try {
        nativeHandler().postMessage({ action: "recognizeVisualText", requestId, imageBase64 });
      } catch (_) {
        clearTimeout(timeout);
        pendingOCR.delete(requestId);
        resolve("");
      }
    });
  };

  const priorNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithABAOCR(evt) {
    if (typeof priorNativeEvent === "function") priorNativeEvent(evt);
    if (evt?.type !== "visualTextRecognition") return;
    pendingOCR.get(String(evt.requestId || ""))?.(evt);
  };

  const install = () => {
    const tools = document.getElementById("tools");
    const grid = tools?.querySelector(".toolGrid");
    if (!grid || document.getElementById("abaAINoteTool")) return;

    const card = document.createElement("div");
    card.className = "card toolCard";
    card.id = "abaAINoteTool";
    card.innerHTML = `
      <div class="toolHead"><div class="toolIcon">${typeof lifeRouteIcon === "function" ? lifeRouteIcon("sparkles", 20) : "✦"}</div><div class="grow"><div class="title">AI session note assistant</div><div class="meta">Paste your session narrative and optionally attach a data screenshot. LifeRoute drafts an objective note from only what you provide.</div></div></div>
      <div class="grid2">
        <div><label>Client</label><select id="abaAINoteClient">${clientOptions()}</select></div>
        <div><label>Data screenshot</label><button type="button" class="secondary" id="abaAINoteScreenshotButton">Choose screenshot</button><input id="abaAINoteScreenshot" type="file" accept="image/*" hidden></div>
      </div>
      <label style="margin-top:9px">Narrative / session facts</label>
      <textarea id="abaAINoteNarrative" class="toolTextarea" rows="6" placeholder="Paste what happened during the session…"></textarea>
      <div id="abaAINoteScreenshotStatus" class="tiny">No screenshot selected.</div>
      <div class="toolActions"><button class="goldButton" id="abaAINoteGenerate" type="button">Draft note with AI</button><button class="secondary" id="abaAINoteCopy" type="button" disabled>Copy note</button><button class="secondary" id="abaAINoteClear" type="button">Clear</button></div>
      <div class="notice toolClinicalNote">AI drafts from supplied facts only. Review for accuracy before using. It does not verify billing, infer undocumented behavior, or replace supervisor requirements.</div>
      <div id="abaAINoteOutput" class="lrABAAINoteOutput" hidden></div>`;
    grid.appendChild(card);

    const screenshot = card.querySelector("#abaAINoteScreenshot");
    const screenshotButton = card.querySelector("#abaAINoteScreenshotButton");
    const screenshotStatus = card.querySelector("#abaAINoteScreenshotStatus");
    const generate = card.querySelector("#abaAINoteGenerate");
    const output = card.querySelector("#abaAINoteOutput");
    const copy = card.querySelector("#abaAINoteCopy");
    let generatedText = "";

    screenshotButton.onclick = () => screenshot.click();
    screenshot.onchange = () => {
      const file = screenshot.files?.[0];
      screenshotStatus.textContent = file ? `Screenshot ready · ${file.name || "image"}` : "No screenshot selected.";
    };

    generate.onclick = async () => {
      const narrative = clean(card.querySelector("#abaAINoteNarrative")?.value || "");
      const code = String(card.querySelector("#abaAINoteClient")?.value || "");
      const file = screenshot.files?.[0] || null;
      if (!narrative && !file) {
        if (typeof setStatus === "function") setStatus("Add a narrative or screenshot first");
        return;
      }
      generate.disabled = true;
      generate.textContent = file ? "Reading data + drafting…" : "Drafting…";
      output.hidden = false;
      output.innerHTML = '<div class="tiny">Building factual draft locally…</div>';
      try {
        const screenshotText = file ? await recognizeScreenshot(file) : "";
        const profile = profileFor(code);
        const targets = Array.isArray(profile?.currentTargets) ? profile.currentTargets : String(profile?.currentTargets || "").split(/[;\n]+/).filter(Boolean);
        const behaviors = Array.isArray(profile?.behaviorsOfConcern) ? profile.behaviorsOfConcern : String(profile?.behaviorsOfConcern || "").split(/[;\n]+/).filter(Boolean);
        const communication = clean(profile?.communicationFCT || profile?.communicationNotes || "");
        const prompt = `Draft one concise professional ABA session note from ONLY the facts supplied below. Use objective observable language and weave quantitative data into the relevant narrative when it is clearly present. Do not invent frequencies, percentages, prompt levels, interventions, targets, behaviors, caregiver statements, session locations, attendees, clinical interpretations, or billing facts. Do not state that a saved client target or behavior occurred unless the narrative or screenshot demonstrates it. If screenshot OCR is unclear, omit uncertain content. Avoid mentalistic language. Keep the result as cohesive paragraphs, not SOAP unless the source explicitly asks for SOAP. Client code: ${code || "not specified"}. Saved targets are context only: ${targets.slice(0, 18).join("; ") || "none"}. Saved behaviors are context only: ${behaviors.slice(0, 18).join("; ") || "none"}. Saved communication/FCT context only: ${communication || "none"}. Narrative: ${narrative || "none"}. Screenshot OCR/data: ${clean(screenshotText) || "none"}. Return only the note text.`;
        const result = await window.LifeRouteAI?.request?.("aba-session-note", prompt, { timeoutMs: 10000 });
        generatedText = result?.success && result.text ? clean(result.text).slice(0, 6000) : "";
        if (!generatedText) {
          output.innerHTML = `<div class="tiny">On-device language AI is unavailable on this device. ${screenshotText ? "The screenshot was read locally, but a note was not generated." : "Your narrative remains local."}</div>`;
          copy.disabled = true;
        } else {
          output.innerHTML = `<div class="row"><div class="small">AI SESSION NOTE DRAFT</div><span class="badge green">On-device AI</span></div><div class="lrABAAINoteText">${safe(generatedText)}</div><div class="tiny">Review every fact before documentation or billing.</div>`;
          copy.disabled = false;
          if (typeof setStatus === "function") setStatus("AI session note draft ready · review before use");
        }
      } finally {
        generate.disabled = false;
        generate.textContent = "Draft note with AI";
      }
    };

    copy.onclick = async () => {
      if (!generatedText) return;
      try {
        await navigator.clipboard.writeText(generatedText);
        if (typeof setStatus === "function") setStatus("Session note copied");
      } catch (_) {}
    };

    card.querySelector("#abaAINoteClear").onclick = () => {
      card.querySelector("#abaAINoteNarrative").value = "";
      screenshot.value = "";
      screenshotStatus.textContent = "No screenshot selected.";
      generatedText = "";
      output.hidden = true;
      output.innerHTML = "";
      copy.disabled = true;
    };
  };

  const refreshClients = () => {
    const select = document.getElementById("abaAINoteClient");
    if (!select) return;
    const current = select.value;
    select.innerHTML = clientOptions();
    if (Array.from(select.options).some(option => option.value === current)) select.value = current;
  };

  const style = document.createElement("style");
  style.id = "lifeRouteABAAINoteStyles";
  style.textContent = `.lrABAAINoteOutput{margin-top:10px;padding:12px;border-radius:14px;border:1px solid color-mix(in srgb,var(--gold) 30%,var(--line));background:color-mix(in srgb,var(--panel2) 78%,transparent);font-size:12px;line-height:1.55}.lrABAAINoteText{white-space:pre-wrap;margin:8px 0}`;
  document.head.appendChild(style);

  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", install, { once: true });
  else install();
  window.addEventListener("liferoute:clients-changed", () => { install(); refreshClients(); });

  window.LifeRouteABAAINote = { install, recognizeScreenshot, refreshClients, version: "1.0.0" };
})();
