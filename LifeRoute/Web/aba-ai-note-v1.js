// LifeRoute ABA AI note assistant.
// Screenshot OCR uses Apple Vision through the native bridge; note drafting uses
// Apple Foundation Models. Narrative, screenshot text, and client context stay local.
(() => {
  if (window.__lifeRouteABAAINoteV1Loaded) return;
  window.__lifeRouteABAAINoteV1Loaded = true;

  const pendingOCR = new Map();
  let sequence = 0;
  const clean = value => String(value || "").replace(/\s+/g, " ").trim();
  const cleanGenerated = value => String(value || "")
    .replace(/\r/g, "")
    .split("\n")
    .map(line => line.replace(/[ \t]+/g, " ").trim())
    .join("\n")
    .replace(/\n{3,}/g, "\n\n")
    .trim();
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

  // Convert noisy ABA data-table OCR into compact evidence before it reaches the
  // on-device model. This keeps useful percentages/counts and removes repeated
  // provider labels, empty section headings, placeholders, and duplicate OCR rows.
  const sanitizeScreenshotEvidence = raw => {
    const lines = String(raw || "").replace(/\r/g, "\n").split(/\n+/).map(clean).filter(Boolean);
    const evidence = [];
    const seen = new Set();
    let section = "";

    const push = value => {
      const text = clean(value);
      const key = text.toLowerCase();
      if (!text || seen.has(key)) return;
      seen.add(key);
      evidence.push(text);
    };

    const metric = line => line.match(/^[\-*•]?\s*(.+?)\s*:\s*(-?\d+(?:\.\d+)?)\s*%?\s*$/i);
    const countWord = value => Math.abs(Number(value)) === 1 ? "occurrence" : "occurrences";

    for (let line of lines.slice(0, 220)) {
      if (/\[(?:insert|client|location|date)[^\]]*\]/i.test(line)) continue;
      if (/^(?:generalization|baseline)\s*:?$/i.test(line)) { section = "noise"; continue; }
      if (/^percent\s+correct\s*:?$/i.test(line)) { section = "skill"; continue; }
      if (/^decrease\s*:?$/i.test(line)) { section = "behavior"; continue; }
      if (/^intervention\s*:/i.test(line)) continue;
      if (/^(?:provider|therapist|technician|staff)\s*:/i.test(line)) continue;

      const inlineBehavior = line.match(/^decrease\s*:\s*(.+?)\s*:\s*(-?\d+(?:\.\d+)?)\s*%?\s*$/i);
      if (inlineBehavior) {
        const value = Number(inlineBehavior[2]);
        if (Number.isFinite(value)) push(`Behavior data: ${clean(inlineBehavior[1])}: ${value} ${countWord(value)}.`);
        continue;
      }

      const match = metric(line);
      if (match) {
        const label = clean(match[1]).replace(/^decrease\s*:\s*/i, "");
        const value = Number(match[2]);
        if (!Number.isFinite(value)) continue;
        if (section === "skill") push(`Skill data: ${label}: ${value}% correct.`);
        else if (section === "behavior") push(`Behavior data: ${label}: ${value} ${countWord(value)}.`);
        else if (section !== "noise") push(`${label}: ${value}${/%/.test(line) ? "%" : ""}.`);
        continue;
      }

      if (section !== "noise" && !/^(?:objective|activities|observations|feedback|interventions)\s*:?$/i.test(line)) push(line);
    }
    return evidence.join("\n").slice(0, 6500);
  };

  const normalizeGeneratedNote = (value, code) => {
    let text = cleanGenerated(value)
      .replace(/^#{1,6}\s*/gm, "")
      .replace(/\*\*/g, "")
      .replace(/^\s*(?:Date|Client|Location|Attendees)\s*:\s*\[[^\]]+\]\s*$/gim, "")
      .replace(/\n{3,}/g, "\n\n")
      .trim();
    const title = code ? `${code} Session Note` : "Session Note";
    if (!new RegExp(`^${title.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")}$`, "im").test(text)) {
      text = `${title}\n\n${text}`;
    }
    return text.slice(0, 6000).trim();
  };

  const draftNeedsRepair = value => {
    const text = String(value || "");
    const forbiddenHeading = /^(?:objective|activities|observations|interventions|feedback|percent correct|generalization|baseline)\s*:/im;
    const placeholder = /\[(?:insert|client name|client's home|location|date)[^\]]*\]/i;
    const repeatedProviderNoise = /intervention\s*:\s*[A-Z][A-Za-z]+\s+[A-Z][A-Za-z]+/i;
    const bullets = (text.match(/^\s*[-*•]\s+/gm) || []).length;
    return forbiddenHeading.test(text) || placeholder.test(text) || repeatedProviderNoise.test(text) || bullets >= 2;
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
      <div class="toolHead"><div class="toolIcon">${typeof lifeRouteIcon === "function" ? lifeRouteIcon("sparkles", 20) : "✦"}</div><div class="grow"><div class="title">AI session note assistant</div><div class="meta">Paste your session narrative and optionally attach a data screenshot. LifeRoute turns your facts into a concise narrative ABA note and weaves data into the relevant paragraphs.</div></div></div>
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
      const narrative = clean(card.querySelector("#abaAINoteNarrative")?.value || "").slice(0, 6000);
      const code = String(card.querySelector("#abaAINoteClient")?.value || "");
      const file = screenshot.files?.[0] || null;
      if (!narrative && !file) {
        if (typeof setStatus === "function") setStatus("Add a narrative or screenshot first");
        return;
      }
      generate.disabled = true;
      generate.textContent = file ? "Reading data + drafting…" : "Drafting…";
      output.hidden = false;
      output.innerHTML = '<div class="tiny">Building factual narrative locally…</div>';
      try {
        const screenshotText = file ? await recognizeScreenshot(file) : "";
        const evidence = sanitizeScreenshotEvidence(screenshotText);
        const profile = profileFor(code);
        const targets = Array.isArray(profile?.currentTargets) ? profile.currentTargets : String(profile?.currentTargets || "").split(/[;\n]+/).filter(Boolean);
        const behaviors = Array.isArray(profile?.behaviorsOfConcern) ? profile.behaviorsOfConcern : String(profile?.behaviorsOfConcern || "").split(/[;\n]+/).filter(Boolean);
        const communication = clean(profile?.communicationFCT || profile?.communicationNotes || "");
        const title = code ? `${code} Session Note` : "Session Note";

        const prompt = `You are LifeRoute's ABA session-note writer. Create a polished RBT session note in the same concise narrative style a strong human ABA documentation assistant would use. Use ONLY the supplied session facts and confirmed screenshot data.

OUTPUT FORMAT — follow exactly:
1. First line: ${title}
2. Blank line.
3. Write 2-4 cohesive professional narrative paragraphs. No other section headings.
4. NEVER output bullets, tables, SOAP fields, templates, placeholders, markdown bolding, Objective, Activities, Observations, Interventions, Feedback, Percent Correct, Generalization, or Baseline sections.
5. Do not output Date/Client/Location/Attendees fields. Mention a known location and attendees naturally in the opening paragraph instead.

HOUSE STYLE:
- Write in third person using “RBT,” “BCBA,” and “the client.” Do not use the RBT's personal name in the note unless the supplied narrative specifically requires it.
- Use objective, observable ABA language. Avoid mentalistic or diagnostic interpretations.
- Preserve useful ABA terminology such as pairing, FCT, manding, ASL, NET, choice board, prompting, reinforcement, transitions, and behaviors of concern when those facts were supplied.
- Organize chronologically: opening/pairing and skill acquisition; later activities/transitions; behaviors of concern and supervisor communication near the end.
- Make the prose natural, not repetitive. Do not restate the same activity as both an objective and an activity.

DATA INTEGRATION:
- Weave each confirmed skill-acquisition percentage into the sentence or paragraph about that target. Example form: “The client demonstrated 66.67% correct manding across opportunities.”
- Weave confirmed behavior-reduction counts into the behavior paragraph. Example form: “Two instances of mouthing objects were recorded.” For zero, use “No instances of refusal were observed.”
- Do NOT create a separate data list or data summary.
- Treat rows identified below as Skill data or Behavior data according to those labels. Do not convert behavior counts into percentages.
- Ignore OCR junk such as repeated provider names, repeated “Intervention” rows, Generalization/Baseline headings, duplicate lines, and bracketed placeholders.

FACTUAL SAFETY:
- Do not invent frequencies, percentages, prompt levels, interventions, targets, behaviors, caregiver statements, session locations, attendees, clinical interpretations, or billing facts.
- Do not state that a saved client target or behavior occurred unless the narrative or screenshot demonstrates it.
- If screenshot OCR is unclear, omit uncertain content.
- Saved profile material is terminology/context only, never proof that something happened in this session.
- If the narrative reports an observed behavior that is not currently tracked as a behavior of concern, state that distinction only if the narrative itself makes it clear.

Client code: ${code || "not specified"}
Saved targets are context only: ${targets.slice(0, 18).join("; ") || "none"}
Saved behaviors are context only: ${behaviors.slice(0, 18).join("; ") || "none"}
Saved communication/FCT context only: ${communication || "none"}

SESSION NARRATIVE:
${narrative || "none"}

CONFIRMED SCREENSHOT EVIDENCE AFTER LOCAL OCR CLEANUP:
${evidence || "none"}

Return only the finished session note.`;

        let result = await window.LifeRouteAI?.request?.("aba-session-note", prompt, { timeoutMs: 12000 });
        let draft = result?.success && result.text ? cleanGenerated(result.text) : "";

        if (draft && draftNeedsRepair(draft)) {
          const repairPrompt = `Rewrite the draft below into LifeRoute's required ABA note format without adding any facts. First line must be exactly “${title}”. Then write only 2-4 cohesive narrative paragraphs. Remove all template fields, placeholders, bullets, data blocks, Objective/Activities/Observations/Interventions/Feedback headings, Percent Correct/Generalization/Baseline sections, and repeated provider-name OCR noise. Keep valid quantitative data but weave each value naturally into the relevant paragraph. Preserve only facts already present in the draft.\n\nDRAFT TO REPAIR:\n${draft.slice(0, 6000)}\n\nReturn only the corrected note.`;
          const repaired = await window.LifeRouteAI?.request?.("aba-session-note-repair", repairPrompt, { timeoutMs: 9000 });
          if (repaired?.success && repaired.text) draft = cleanGenerated(repaired.text);
        }

        generatedText = draft ? normalizeGeneratedNote(draft, code) : "";
        if (!generatedText) {
          output.innerHTML = `<div class="tiny">On-device language AI is unavailable on this device. ${screenshotText ? "The screenshot was read locally, but a note was not generated." : "Your narrative remains local."}</div>`;
          copy.disabled = true;
        } else {
          output.innerHTML = `<div class="row"><div class="small">AI SESSION NOTE DRAFT</div><span class="badge green">On-device AI</span></div><div class="lrABAAINoteText">${safe(generatedText)}</div><div class="tiny">Review every fact before documentation or billing.</div>`;
          copy.disabled = false;
          if (typeof setStatus === "function") setStatus("Narrative ABA session note ready · review before use");
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

  window.LifeRouteABAAINote = { install, recognizeScreenshot, sanitizeScreenshotEvidence, refreshClients, version: "1.1.0" };
})();
