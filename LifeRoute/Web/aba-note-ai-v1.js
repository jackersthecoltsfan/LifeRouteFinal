// LifeRoute ABA Note AI: narrative + screenshot OCR + saved client profile -> draft note.
// OCR and language generation are on-device on supported iPhones. No network calls.
(() => {
  if (window.__lifeRouteABANoteAIV1Loaded) return;
  window.__lifeRouteABANoteAIV1Loaded = true;

  const ocrPending = new Map();
  let sequence = 0;
  let selectedScreenshot = null;
  let ocrText = "";

  const clean = value => String(value || "").replace(/\s+/g, " ").trim();
  const safe = value => typeof window.esc === "function" ? window.esc(String(value || "")) : String(value || "").replace(/[&<>"']/g, char => ({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#039;"}[char]));
  const nativeHandler = () => window.webkit?.messageHandlers?.lifeRoute;

  const fileToAnalysisDataURL = file => new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(url);
      const maxSide = 1800;
      const scale = Math.min(1, maxSide / Math.max(image.naturalWidth, image.naturalHeight));
      const canvas = document.createElement("canvas");
      canvas.width = Math.max(40, Math.round(image.naturalWidth * scale));
      canvas.height = Math.max(40, Math.round(image.naturalHeight * scale));
      const ctx = canvas.getContext("2d");
      ctx.fillStyle = "#fff";
      ctx.fillRect(0, 0, canvas.width, canvas.height);
      ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
      resolve(canvas.toDataURL("image/jpeg", .84));
    };
    image.onerror = error => { URL.revokeObjectURL(url); reject(error); };
    image.src = url;
  });

  const recognizeScreenshot = async file => {
    const handler = nativeHandler();
    if (!file || typeof handler?.postMessage !== "function") return "";
    const requestId = `ocr-${Date.now()}-${++sequence}`;
    const imageBase64 = await fileToAnalysisDataURL(file);
    return new Promise(resolve => {
      const timeout = setTimeout(() => {
        ocrPending.delete(requestId);
        resolve("");
      }, 6500);
      ocrPending.set(requestId, payload => {
        clearTimeout(timeout);
        ocrPending.delete(requestId);
        resolve(payload?.success ? String(payload.text || "") : "");
      });
      try {
        handler.postMessage({ action: "ocrImageText", requestId, imageBase64 });
      } catch (_) {
        clearTimeout(timeout);
        ocrPending.delete(requestId);
        resolve("");
      }
    });
  };

  const priorNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithABANoteAI(evt) {
    if (typeof priorNativeEvent === "function") priorNativeEvent(evt);
    if (evt?.type !== "ocrImageTextResult") return;
    ocrPending.get(String(evt.requestId || ""))?.(evt);
  };

  const clientProfile = code => {
    try {
      const prefsValue = window.prefs || {};
      const clients = Array.isArray(prefsValue.clients) ? prefsValue.clients : [];
      const formatPair = value => {
        const letters = String(value || "").replace(/[^a-z]/gi, "").slice(0, 2);
        return letters ? letters.charAt(0).toUpperCase() + letters.slice(1).toLowerCase() : "";
      };
      const clientCode = client => `${formatPair(client?.first2)}${formatPair(client?.last2)}`;
      const client = clients.find(item => clientCode(item) === code);
      if (!client) return null;
      return {
        code,
        preferredActivities: clean(client.preferredActivities || client.reinforcers || ""),
        currentTargets: clean(client.currentTargets || client.targets || ""),
        behaviorsOfConcern: clean(client.behaviorsOfConcern || ""),
        communicationFCT: clean(client.communicationFCT || client.communicationNotes || ""),
        promptingReinforcement: clean(client.promptingReinforcement || ""),
        caregiverSetting: clean(client.caregiverSetting || "")
      };
    } catch (_) {
      return null;
    }
  };

  const notePrompt = ({ narrative, screenshotText, profile, client }) => `Write a concise professional ABA session-note draft from ONLY the information supplied below. Use objective observable language. Refer to the person as "the client" unless the client code is needed in a heading. Integrate quantitative/data-like information from the screenshot text naturally throughout the note when it is clearly interpretable. Do not invent frequencies, percentages, behaviors, prompting levels, interventions, caregiver statements, targets, diagnoses, or outcomes. Do not claim a behavior occurred merely because it appears in the saved profile; the profile is context only. Do not turn preferences or historical targets into events unless the narrative says they were addressed. Preserve uncertainty if screenshot OCR is unclear. Prefer "behaviors of concern" over stigmatizing language. Note that the AI output is a draft requiring RBT review before documentation. Do not add billing language.\n\nClient: ${clean(client) || "General"}\nSaved client context: ${JSON.stringify(profile || {})}\nNarrative from RBT: ${clean(narrative)}\nOCR text extracted locally from session-data screenshot: ${clean(screenshotText) || "No screenshot text supplied"}`;

  const ensureUI = () => {
    const tools = document.getElementById("tools");
    const grid = tools?.querySelector(".toolGrid");
    if (!grid || document.getElementById("abaNoteAITool")) return;
    const card = document.createElement("div");
    card.id = "abaNoteAITool";
    card.className = "card toolCard";
    card.innerHTML = `
      <div class="toolHead"><div class="toolIcon">✦</div><div class="grow"><div class="title">ABA Note AI</div><div class="meta">Narrative + optional data screenshot → an objective session-note draft using on-device AI.</div></div></div>
      <div class="grid2">
        <div><label>Client</label><select id="abaNoteAIClient"></select></div>
        <div><label>Data screenshot</label><button type="button" class="secondary" id="abaNoteAIScreenshotButton">Choose screenshot</button></div>
      </div>
      <input id="abaNoteAIScreenshotInput" type="file" accept="image/*" hidden>
      <div class="tiny" id="abaNoteAIScreenshotStatus">Screenshot optional · Vision OCR stays on this iPhone.</div>
      <label style="margin-top:9px">Session narrative</label>
      <textarea id="abaNoteAINarrative" class="toolTextarea" rows="7" placeholder="Paste or dictate what happened during the session…"></textarea>
      <div class="toolActions"><button class="goldButton" id="abaNoteAIGenerate" type="button">✦ Draft session note</button><button class="secondary" id="abaNoteAIClear" type="button">Clear</button></div>
      <div id="abaNoteAIOutput" class="lrABANoteAIOutput" hidden></div>
      <div class="notice toolClinicalNote">AI organizes the facts you provide. Review the draft against your actual session data and agency/BCBA documentation requirements before using it.</div>`;
    grid.appendChild(card);
    refreshClients();
    bindUI();
  };

  const refreshClients = () => {
    const select = document.getElementById("abaNoteAIClient");
    if (!select) return;
    const source = document.getElementById("quickNoteClient") || document.getElementById("sessionPlanClient");
    if (source?.options?.length) {
      const current = select.value;
      select.innerHTML = Array.from(source.options).map(option => `<option value="${safe(option.value)}">${safe(option.textContent)}</option>`).join("");
      if (Array.from(select.options).some(option => option.value === current)) select.value = current;
      return;
    }
    select.innerHTML = '<option value="">General / no client</option>';
  };

  const renderOutput = (text, engine) => {
    const host = document.getElementById("abaNoteAIOutput");
    if (!host) return;
    host.hidden = false;
    host.innerHTML = `<div class="row"><div class="small">AI SESSION-NOTE DRAFT</div><span class="badge green">${/foundation/i.test(String(engine || "")) ? "On-device Apple AI" : "Draft"}</span></div><textarea id="abaNoteAIResult" class="toolTextarea" rows="12">${safe(text)}</textarea><div class="toolActions"><button type="button" class="secondary" id="abaNoteAICopy">Copy note</button></div><div class="tiny">Draft only · verify every factual/data statement before documentation.</div>`;
    document.getElementById("abaNoteAICopy")?.addEventListener("click", async () => {
      const value = document.getElementById("abaNoteAIResult")?.value || "";
      try {
        await navigator.clipboard.writeText(value);
        if (typeof window.setStatus === "function") window.setStatus("Session-note draft copied");
      } catch (_) {}
    });
  };

  const bindUI = () => {
    const screenshotButton = document.getElementById("abaNoteAIScreenshotButton");
    const input = document.getElementById("abaNoteAIScreenshotInput");
    screenshotButton.onclick = () => input.click();
    input.onchange = async () => {
      selectedScreenshot = input.files?.[0] || null;
      ocrText = "";
      const status = document.getElementById("abaNoteAIScreenshotStatus");
      if (!selectedScreenshot) {
        if (status) status.textContent = "Screenshot optional · Vision OCR stays on this iPhone.";
        return;
      }
      if (status) status.textContent = "Reading screenshot locally with Vision OCR…";
      ocrText = await recognizeScreenshot(selectedScreenshot);
      if (status) status.textContent = ocrText ? `Screenshot read locally · ${ocrText.length} characters extracted` : "Screenshot selected · no readable text found";
    };

    document.getElementById("abaNoteAIClear").onclick = () => {
      document.getElementById("abaNoteAINarrative").value = "";
      input.value = "";
      selectedScreenshot = null;
      ocrText = "";
      const output = document.getElementById("abaNoteAIOutput");
      if (output) { output.hidden = true; output.innerHTML = ""; }
      const status = document.getElementById("abaNoteAIScreenshotStatus");
      if (status) status.textContent = "Screenshot optional · Vision OCR stays on this iPhone.";
    };

    document.getElementById("abaNoteAIGenerate").onclick = async () => {
      const narrative = String(document.getElementById("abaNoteAINarrative")?.value || "").trim();
      if (!narrative) {
        if (typeof window.setStatus === "function") window.setStatus("Add the session narrative first");
        return;
      }
      const button = document.getElementById("abaNoteAIGenerate");
      const client = String(document.getElementById("abaNoteAIClient")?.value || "");
      const profile = clientProfile(client);
      button.disabled = true;
      button.textContent = "AI drafting…";
      try {
        if (selectedScreenshot && !ocrText) ocrText = await recognizeScreenshot(selectedScreenshot);
        const result = await window.LifeRouteAI?.request?.("aba-session-note", notePrompt({ narrative, screenshotText: ocrText, profile, client }), { timeoutMs: 10000 });
        if (result?.success && result.text) {
          renderOutput(result.text, result.engine);
          if (typeof window.setStatus === "function") window.setStatus("ABA session-note draft ready · review facts before use");
        } else {
          renderOutput(`Narrative: ${narrative}${ocrText ? `\n\nExtracted screenshot data: ${ocrText}` : ""}`, "deterministic");
          if (typeof window.setStatus === "function") window.setStatus("On-device language AI unavailable · source facts preserved for manual drafting");
        }
      } finally {
        button.disabled = false;
        button.textContent = "✦ Draft session note";
      }
    };
  };

  const style = document.createElement("style");
  style.id = "lifeRouteABANoteAIStyles";
  style.textContent = `.lrABANoteAIOutput{margin-top:10px;padding:11px;border-radius:14px;border:1px solid color-mix(in srgb,var(--blue) 30%,var(--line));background:color-mix(in srgb,var(--blue) 5%,var(--panel2))}.lrABANoteAIOutput textarea{margin-top:7px;min-height:220px}`;
  document.head.appendChild(style);

  const install = () => ensureUI();
  if (document.readyState === "loading") document.addEventListener("DOMContentLoaded", install, { once: true });
  else install();
  window.addEventListener("liferoute:clients-changed", () => { ensureUI(); refreshClients(); });

  window.LifeRouteABANoteAI = { recognizeScreenshot, refreshClients, version: "1.0.0" };
})();
