from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"


def replace_once(path: Path, old: str, new: str, label: str) -> None:
    text = path.read_text()
    if new in text:
        return
    if old not in text:
        raise SystemExit(f"{label}: source marker missing")
    path.write_text(text.replace(old, new, 1))


# ---------- Existing on-device Apple Vision OCR bridge ----------
swift = SWIFT.read_text()

if 'case "recognizeVisualText":' not in swift:
    marker = '            default:\n'
    if marker not in swift:
        raise SystemExit("ABA OCR bridge: native switch default marker missing")
    case = '''            case "recognizeVisualText":
                let requestID = (body["requestId"] as? String) ?? UUID().uuidString
                let imageBase64 = (body["imageBase64"] as? String) ?? ""
                recognizeVisualText(requestID: requestID, imageBase64: imageBase64)
'''
    swift = swift.replace(marker, case + marker, 1)

if "private func recognizeVisualText(requestID:" not in swift:
    marker = "        private func emit(type: String, payload: [String: Any]) {"
    if marker not in swift:
        raise SystemExit("ABA OCR bridge: emit marker missing")
    method = r'''        private func recognizeVisualText(requestID: String, imageBase64: String) {
            let encoded: String
            if let comma = imageBase64.firstIndex(of: ",") {
                encoded = String(imageBase64[imageBase64.index(after: comma)...])
            } else {
                encoded = imageBase64
            }
            guard !encoded.isEmpty,
                  let data = Data(base64Encoded: encoded),
                  let image = UIImage(data: data),
                  let cgImage = image.cgImage else {
                emit(type: "visualTextRecognition", payload: [
                    "requestId": requestID,
                    "success": false
                ])
                return
            }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                request.minimumTextHeight = 0.008
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    let lines = (request.results ?? []).compactMap { observation in
                        observation.topCandidates(1).first?.string
                    }
                    let text = String(lines.joined(separator: "\n").prefix(12_000))
                    DispatchQueue.main.async {
                        self?.emit(type: "visualTextRecognition", payload: [
                            "requestId": requestID,
                            "success": !text.isEmpty,
                            "text": text,
                            "engine": "apple-vision-ocr"
                        ])
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.emit(type: "visualTextRecognition", payload: [
                            "requestId": requestID,
                            "success": false,
                            "message": error.localizedDescription
                        ])
                    }
                }
            }
        }

'''
    swift = swift.replace(marker, method + marker, 1)

SWIFT.write_text(swift)


# ---------- Day AI: structured output, never raw JSON/debug text ----------
ai = ROOT / "LifeRoute" / "Web" / "ai-assistant-v1.js"
old = '''  const dayBrief = async payload => {
    const date = clean(payload?.date || "");
    const events = Array.isArray(payload?.events) ? payload.events.slice(0, 16) : [];
    const places = Array.isArray(payload?.places) ? payload.places.slice(0, 16) : [];
    const prompt = `Give a compact LifeRoute day-planning brief in 2 to 4 sentences. Fixed appointment times and computed travel or leave times are immutable; never change or contradict them. You may identify useful open gaps, suggest one or two supplied saved places or errands that appear to fit, and call out a rushed transition. Do not invent locations or appointments. Date: ${date}. Fixed day: ${JSON.stringify(events)}. Saved optional places: ${JSON.stringify(places)}.`;
    const result = await request("day-plan", prompt, { timeoutMs: 7500 });
    return result?.success && result.text ? { text: clean(result.text).slice(0, 1000), engine: result.engine || "apple-foundation-model" } : null;
  };

  const routeBrief = async payload => {
    const route = payload && typeof payload === "object" ? payload : {};
    const prompt = `Give one concise route-planning insight using only these computed facts: ${JSON.stringify(route)}. Do not calculate or alter travel times, departure times, addresses, stop durations, or distances. Explain why the selected stop or route fits, or flag that timing is tight. If there is no useful insight, return an empty string.`;
    const result = await request("route-brief", prompt, { timeoutMs: 5500 });
    return result?.success && result.text ? { text: clean(result.text).slice(0, 420), engine: result.engine || "apple-foundation-model" } : null;
  };
'''
new = '''  const dayBrief = async payload => {
    const date = clean(payload?.date || "");
    const events = Array.isArray(payload?.events) ? payload.events.slice(0, 16) : [];
    const places = Array.isArray(payload?.places) ? payload.places.slice(0, 16) : [];
    const prompt = `Return JSON only in exactly this shape: {"dayBrief":"2-4 concise natural-language sentences","gapSuggestion":"optional one-sentence suggestion or empty string"}. Summarize the fixed LifeRoute day for a person reading a polished mobile planner. Fixed appointment times, MapKit travel times, stop durations, arrival buffers, and computed leave times are immutable facts; never change or recalculate them. Use friendly clock times when mentioning times instead of raw ISO timestamps. Do not repeat the input JSON, expose field names, use markdown/code fences, or invent locations, appointments, errands, or route facts. You may mention a useful open gap and suggest only a supplied saved place that plausibly fits. Date: ${date}. Fixed day facts: ${JSON.stringify(events)}. Saved optional places: ${JSON.stringify(places)}.`;
    const result = await request("day-plan", prompt, { timeoutMs: 7500 });
    if (!result?.success || !result.text) return null;
    const parsed = parseJSON(result.text);
    const brief = clean(parsed?.dayBrief || "");
    const gap = clean(parsed?.gapSuggestion || "");
    let text = [brief, gap].filter(Boolean).join(" ").slice(0, 1000);
    if (!text) {
      const raw = clean(result.text).replace(/```(?:json)?/gi, "").replace(/```/g, "").trim();
      text = /^[{[]/.test(raw) ? "" : raw.slice(0, 1000);
    }
    return text ? { text, engine: result.engine || "apple-foundation-model" } : null;
  };

  const routeBrief = async payload => {
    const route = payload && typeof payload === "object" ? payload : {};
    const prompt = `Return JSON only in exactly this shape: {"routeInsight":"one concise natural-language sentence or empty string"}. Use only the computed route facts supplied below. Never calculate or alter travel times, departure times, addresses, stop durations, distances, or arrival buffers. Use friendly clock times rather than raw ISO timestamps when a time must be mentioned. Do not repeat the input JSON, expose field names, or use markdown/code fences. Explain why the route fits or say timing is tight; otherwise return an empty routeInsight. Computed route facts: ${JSON.stringify(route)}.`;
    const result = await request("route-brief", prompt, { timeoutMs: 5500 });
    if (!result?.success || !result.text) return null;
    const parsed = parseJSON(result.text);
    let text = clean(parsed?.routeInsight || "").slice(0, 420);
    if (!text) {
      const raw = clean(result.text).replace(/```(?:json)?/gi, "").replace(/```/g, "").trim();
      text = /^[{[]/.test(raw) ? "" : raw.slice(0, 420);
    }
    return text ? { text, engine: result.engine || "apple-foundation-model" } : null;
  };
'''
replace_once(ai, old, new, "structured Day AI")

planning = ROOT / "LifeRoute" / "Web" / "ai-planning-v1.js"
old = '''    host.innerHTML = `
      <div class="row"><div class="small">AI DAY + ROUTE CHECK</div><span class="badge green">${safe(day?.engine ? engineLabel(day.engine) : "Smart fallback")}</span></div>
      <div class="lrAIInsightText">${safe(day?.text || fallback)}</div>
      ${route?.text ? `<div class="lrAIRouteText"><b>Route insight:</b> ${safe(route.text)}</div>` : ""}
      <div class="tiny">AI never changes calendar times, MapKit travel times, stop durations, or leave-time calculations.</div>`;

    const stored = readAIStore();
    stored[date] = { text: day?.text || fallback, route: route?.text || "", savedAt: Date.now() };
'''
new = '''    const scrubDisplayText = value => String(value || "")
      .replace(/```(?:json)?/gi, "")
      .replace(/```/g, "")
      .replace(/\\u0060/g, "")
      .trim();
    const dayText = scrubDisplayText(day?.text || fallback);
    const routeText = scrubDisplayText(route?.text || "");
    host.innerHTML = `
      <div class="row"><div class="small">AI DAY + ROUTE CHECK</div><span class="badge green">${safe(day?.engine ? engineLabel(day.engine) : "Smart fallback")}</span></div>
      <div class="lrAIInsightText">${safe(dayText || fallback)}</div>
      ${routeText ? `<div class="lrAIRouteText"><b>Route insight:</b> ${safe(routeText)}</div>` : ""}
      <div class="tiny">AI never changes calendar times, MapKit travel times, stop durations, or leave-time calculations.</div>`;

    const stored = readAIStore();
    stored[date] = { text: dayText || fallback, route: routeText, savedAt: Date.now() };
'''
replace_once(planning, old, new, "Day AI display cleanup")


# ---------- ABA/privacy warnings ----------
aba = ROOT / "LifeRoute" / "Web" / "aba-ai-note-v1.js"
old = '''      <div class="notice toolClinicalNote">AI drafts from supplied facts only. Review for accuracy before using. It does not verify billing, infer undocumented behavior, or replace supervisor requirements.</div>'''
new = '''      <div class="notice lrPHIWarning"><b>Privacy / HIPAA:</b> Do not enter PHI or direct identifiers. Use only your organization-approved de-identified client code (for example, first 2 + last 2 initials). Avoid full names, DOBs, MRNs, phone/email, client photos, or other identifying details. Review your employer's HIPAA/privacy requirements before use.</div>
      <div class="notice toolClinicalNote">AI drafts from supplied facts only. Review for accuracy before using. It does not verify billing, infer undocumented behavior, or replace supervisor requirements.</div>'''
replace_once(aba, old, new, "ABA note privacy warning")

clients = ROOT / "LifeRoute" / "Web" / "client-profiles-v1.js"
replace_once(clients, '''          <div class="full"><label>Client address / service location <span class="tiny">optional</span></label><input id="clientAddress" placeholder="Street address or searchable place"></div>''', '''          <div class="full"><label>Service location <span class="tiny">optional · may be PHI</span></label><input id="clientAddress" placeholder="Only if your organization authorizes storing this location"></div>''', "client address PHI label")
replace_once(clients, '''        <div class="lrClientProfileGrid">''', '''        <div class="notice lrPHIWarning"><b>Privacy / HIPAA:</b> Do not enter PHI or direct identifiers. Use only your organization-approved de-identified client code (for example, first 2 + last 2 initials). Do not enter full names, DOBs, MRNs, phone/email, client photos, or other identifying details. A home/service address can itself be PHI; only save one if your organization specifically authorizes that use.</div>
        <div class="lrClientProfileGrid">''', "client profile privacy warning")
replace_once(clients, '''        <div class="lrClientPrivacy">Client profile data stays in LifeRoute’s local device storage. LifeRoute only uses the four-letter code and service location for calendar/route matching; profile details are used locally by session tools and are not sent to calendar or routing providers.</div>''', '''        <div class="lrClientPrivacy">LifeRoute stores these profile fields locally on this device. Local storage does not by itself guarantee HIPAA compliance. Follow your organization's privacy policy and avoid PHI unless that specific use is authorized.</div>''', "client profile compliance wording")

rbt = ROOT / "LifeRoute" / "Web" / "rbt-tools.js"
replace_once(rbt, '''      <div class="toolGrid">''', '''      <div class="notice lrPHIWarning"><b>Privacy / HIPAA:</b> Keep session-tool entries de-identified. Do not enter PHI or direct identifiers; use only your organization-approved client code and avoid full names, DOBs, MRNs, phone/email, client photos, or other identifying details.</div>
      <div class="toolGrid">''', "Tools privacy warning")


# ---------- Visual timer: ~5x louder + native playback audio session ----------
timer = ROOT / "LifeRoute" / "Web" / "visual-timer-v2.js"
replace_once(timer, '''  const POLL_MS = 70;\n''', '''  const POLL_MS = 70;\n  const nativeHandler = () => window.webkit?.messageHandlers?.lifeRoute;\n  const configureNativePlayback = active => {\n    try { nativeHandler()?.postMessage?.({ action: "configureTimerAudio", active: !!active }); } catch (_) {}\n  };\n''', "timer native audio helper")
replace_once(timer, '''    if (!enabled) lastChimeAt = 0;''', '''    if (!enabled) {\n      lastChimeAt = 0;\n      configureNativePlayback(false);\n    }''', "timer audio deactivation")
replace_once(timer, '''    if (!soundEnabled()) return null;\n    const AudioContextClass = contextClass();''', '''    if (!soundEnabled()) return null;\n    configureNativePlayback(true);\n    const AudioContextClass = contextClass();''', "timer audio activation")
replace_once(timer, "0.052 * gainScale", "0.25 * gainScale", "timer louder gain")

swift = SWIFT.read_text()
if "import AVFoundation" not in swift:
    if "import UIKit\n" not in swift:
        raise SystemExit("timer native audio: UIKit import missing")
    swift = swift.replace("import UIKit\n", "import UIKit\nimport AVFoundation\n", 1)
if 'case "configureTimerAudio":' not in swift:
    marker = '            default:\n'
    if marker not in swift:
        raise SystemExit("timer native audio: switch default missing")
    case = '''            case "configureTimerAudio":
                let active = (body["active"] as? Bool) ?? true
                configureTimerAudio(active: active)
'''
    swift = swift.replace(marker, case + marker, 1)
if "private func configureTimerAudio(active:" not in swift:
    marker = "        private func emit(type: String, payload: [String: Any]) {"
    if marker not in swift:
        raise SystemExit("timer native audio: emit marker missing")
    method = '''        private func configureTimerAudio(active: Bool) {
            let session = AVAudioSession.sharedInstance()
            do {
                if active {
                    try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
                    try session.setActive(true)
                } else {
                    try session.setActive(false, options: [.notifyOthersOnDeactivation])
                }
                emit(type: "timerAudioSession", payload: ["success": true, "active": active])
            } catch {
                emit(type: "timerAudioSession", payload: ["success": false, "active": active, "message": error.localizedDescription])
            }
        }

'''
    swift = swift.replace(marker, method + marker, 1)
SWIFT.write_text(swift)

timer_audit = ROOT / "scripts" / "audit_visual_timer.py"
replace_once(timer_audit, 'check("0.052 * gainScale" in timer, "chime gain is deliberately gentle")', 'check("0.25 * gainScale" in timer, "chime gain is boosted for session use")', "timer audit gain")
text = timer_audit.read_text()
marker = 'check("playCompletion" in timer, "timer has a distinct completion chime")\n'
addition = 'check("configureTimerAudio" in timer, "timer requests native playback audio session")\ncheck("AVAudioSession" in (ROOT / "LifeRoute" / "LifeRouteWebView.swift").read_text(encoding="utf-8") and "setCategory(.playback" in (ROOT / "LifeRoute" / "LifeRouteWebView.swift").read_text(encoding="utf-8"), "native playback category bypasses silent switch")\n'
if addition not in text:
    if marker not in text:
        raise SystemExit("timer audit silent-mode marker missing")
    timer_audit.write_text(text.replace(marker, marker + addition, 1))


# ---------- Image Playground: explicit subject title ----------
playground = ROOT / "LifeRoute" / "Web" / "image-playground-v1.js"
replace_once(playground, "const open = async ({ label, file } = {}) => {", "const open = async ({ label, subjectTitle, file } = {}) => {", "Image Playground open signature")
replace_once(playground, '''          label: String(label || "Visual support").trim().slice(0, 80),\n          imageBase64''', '''          label: String(label || "Visual support").trim().slice(0, 80),\n          subjectTitle: String(subjectTitle || label || "Visual support").trim().slice(0, 80),\n          imageBase64''', "Image Playground subject payload")
old = '''    actions.insertAdjacentElement("afterend", button);

    const note = document.createElement("div");
    note.className = "tiny lrAIStudioNote";
    note.textContent = "AI image studio uses Apple’s system Image Playground. You review the generated image before it returns to LifeRoute.";
    button.insertAdjacentElement("afterend", note);

    button.onclick = async () => {
      const label = String(document.getElementById("visualIconLabel")?.value || "Visual support").trim() || "Visual support";
      const input = document.getElementById("visualCameraInput");
      const file = input?.files?.[0] || null;
'''
new = '''    const subjectRow = document.createElement("div");
    subjectRow.className = "toolInline lrAIStudioSubjectRow";
    subjectRow.innerHTML = '<input id="visualAISubjectTitle" maxlength="80" placeholder="AI subject title (e.g., playground swing)">';
    actions.insertAdjacentElement("afterend", subjectRow);
    subjectRow.insertAdjacentElement("afterend", button);

    const note = document.createElement("div");
    note.className = "tiny lrAIStudioNote";
    note.textContent = "Subject title is sent into Apple Image Playground as the generation concept. You review the generated image before it returns to LifeRoute.";
    button.insertAdjacentElement("afterend", note);

    button.onclick = async () => {
      const label = String(document.getElementById("visualIconLabel")?.value || "Visual support").trim() || "Visual support";
      const subjectTitle = String(document.getElementById("visualAISubjectTitle")?.value || label).trim() || label;
      const input = document.getElementById("visualCameraInput");
      const file = input?.files?.[0] || null;
'''
replace_once(playground, old, new, "Image Playground subject field")
replace_once(playground, "const result = await open({ label, file });", "const result = await open({ label, subjectTitle, file });", "Image Playground subject call")
replace_once(playground, '''  style.textContent = `#visualAIStudioButton{margin-top:8px;width:100%;border-color:color-mix(in srgb,var(--blue) 45%,var(--line));background:linear-gradient(135deg,color-mix(in srgb,var(--blue) 10%,var(--panel2)),color-mix(in srgb,var(--gold) 7%,var(--panel2)))}.lrAIStudioNote{margin-top:5px}`;''', '''  style.textContent = `#visualAIStudioButton{margin-top:8px;width:100%;border-color:color-mix(in srgb,var(--blue) 45%,var(--line));background:linear-gradient(135deg,color-mix(in srgb,var(--blue) 10%,var(--panel2)),color-mix(in srgb,var(--gold) 7%,var(--panel2)))}.lrAIStudioSubjectRow{margin-top:8px}.lrAIStudioSubjectRow input{width:100%}.lrAIStudioNote{margin-top:5px}`;''', "Image Playground subject styles")

first_then_ai = ROOT / "LifeRoute" / "Web" / "first-then-ai-studio-v1.js"
replace_once(first_then_ai, "window.LifeRouteImageStudio.open({ label })", "window.LifeRouteImageStudio.open({ label, subjectTitle: label })", "First Then Image Playground subject")

replace_once(SWIFT, '''                let label = (body["label"] as? String) ?? "Visual support"\n                let source = body["imageBase64"] as? String\n                openImagePlayground(requestID: requestID, label: label, imageBase64: source)''', '''                let label = (body["label"] as? String) ?? "Visual support"\n                let subjectTitle = (body["subjectTitle"] as? String) ?? label\n                let source = body["imageBase64"] as? String\n                openImagePlayground(requestID: requestID, label: label, subjectTitle: subjectTitle, imageBase64: source)''', "Image Playground native subject case")
replace_once(SWIFT, '''        private func openImagePlayground(requestID: String, label: String, imageBase64: String?) {''', '''        private func openImagePlayground(requestID: String, label: String, subjectTitle: String, imageBase64: String?) {''', "Image Playground native signature")
replace_once(SWIFT, '''                        .text("A clean visual-support image of \\(String(label.prefix(80))). One obvious centered subject, simple uncluttered background, bright natural colors, easy for a child to recognize, no written words in the image.")''', '''                        .text("Subject: \\(String(subjectTitle.prefix(80))). Create a clean visual-support image for the label \\(String(label.prefix(80))). Make the named subject unmistakable and centered, with a simple uncluttered background, bright natural colors, child-recognizable composition, and no written words in the image.")''', "Image Playground native concept")


# ---------- Theme simplification: Metallic Wave cards + Dynamic + Fluid only ----------
theme = ROOT / "LifeRoute" / "Web" / "theme-catalog-v3.js"
text = theme.read_text()
if "lifeRouteSimplifiedThemeCatalogV4" not in text:
    marker = "  document.head.appendChild(style);\n"
    if marker not in text:
        raise SystemExit("theme simplification: style marker missing")
    block = r'''  const METALLIC_ITEMS = [
    ["solar-flare","Solar Flare"],["electric-storm","Electric Storm"],["ultraviolet","Ultraviolet"],["molten-gold","Molten Gold"],["arctic-pulse","Arctic Pulse"],["emerald-tempest","Emerald Tempest"],["rose-nebula","Rose Nebula"],["royal-cosmos","Royal Cosmos"],["sapphire-tide","Sapphire Tide"],["phantom-silver","Phantom Silver"]
  ];
  const simplifyThemeCatalog = sheet => {
    window.lifeRouteSimplifiedThemeCatalogV4 = true;
    document.getElementById("lifeRouteCoreThemeSection")?.remove();
    document.getElementById("lifeRouteDynamicAnimalSection")?.remove();
    [...sheet.querySelectorAll(":scope > .lrSettingsSection")].forEach(section => {
      const title = section.querySelector(".lrSettingsSectionHead b")?.textContent?.trim() || "";
      if (/nature|scenery|living creatures|creatures/i.test(title)) section.remove();
    });
    const section = document.getElementById("lifeRouteMetallicWaveThemeSection");
    const select = document.getElementById("lifeRouteMetallicWaveThemeSelect");
    if (section && select) {
      select.hidden = true;
      let grid = section.querySelector(".lrMetallicThemeGrid");
      if (!grid) {
        grid = document.createElement("div");
        grid.className = "lrMetallicThemeGrid";
        grid.innerHTML = METALLIC_ITEMS.map(([key,name]) => `<button type="button" class="lrThemeCard lrMetallicThemeCard" data-metallic-key="${key}"><b>${name}</b><span>Metallic Wave</span></button>`).join("");
        select.insertAdjacentElement("afterend", grid);
        grid.querySelectorAll("[data-metallic-key]").forEach(button => {
          button.addEventListener("click", () => {
            select.value = button.dataset.metallicKey || "";
            select.dispatchEvent(new Event("change", { bubbles: true }));
            queueMicrotask(syncMarks);
          });
        });
      }
    }
  };
  const simplifiedStyle = document.createElement("style");
  simplifiedStyle.id = "lifeRouteSimplifiedThemeCatalogV4Styles";
  simplifiedStyle.textContent = `.lrMetallicThemeGrid{display:grid;grid-template-columns:repeat(2,minmax(0,1fr));gap:8px;margin-top:8px}.lrMetallicThemeCard{min-height:58px;text-align:left;padding:10px 11px;border-radius:13px}.lrMetallicThemeCard b{display:block;font-size:11px}.lrMetallicThemeCard span{display:block;margin-top:3px;font-size:8px;color:var(--muted)}.lrMetallicThemeCard.active{border-color:var(--gold);box-shadow:inset 0 0 0 1px var(--gold),0 8px 24px rgba(0,0,0,.12)}@media(max-width:560px){.lrMetallicThemeGrid{grid-template-columns:1fr}}`;
  document.head.appendChild(simplifiedStyle);
'''
    text = text.replace(marker, marker + block, 1)
    old_cards = '''  const syncCards = () => {
    const nature = currentNature();
    const dynamic = currentDynamic();
    const fluid = currentFluid();
    const animal = currentAnimal();
    document.querySelectorAll(".lrThemeCard").forEach(card => {
      let active = false;
      if (card.dataset.animalKey) active = card.dataset.animalKey === animal;
      else if (card.dataset.fluidKey) active = card.dataset.fluidKey === fluid;
      else if (card.dataset.dynamicKey) active = card.dataset.dynamicKey === dynamic;
      else if (card.dataset.themeKey) active = card.dataset.themeKey === nature;
'''
    new_cards = '''  const syncCards = () => {
    const classic = currentClassic();
    const nature = currentNature();
    const dynamic = currentDynamic();
    const fluid = currentFluid();
    const animal = currentAnimal();
    document.querySelectorAll(".lrThemeCard").forEach(card => {
      let active = false;
      if (card.dataset.metallicKey) active = card.dataset.metallicKey === classic;
      else if (card.dataset.animalKey) active = card.dataset.animalKey === animal;
      else if (card.dataset.fluidKey) active = card.dataset.fluidKey === fluid;
      else if (card.dataset.dynamicKey) active = card.dataset.dynamicKey === dynamic;
      else if (card.dataset.themeKey) active = card.dataset.themeKey === nature;
'''
    if old_cards not in text:
        raise SystemExit("theme simplification: syncCards marker missing")
    text = text.replace(old_cards, new_cards, 1)
    old_normalize = '''    removePlaceholder(sheet);
    orderSections(sheet);
    syncMarks();'''
    new_normalize = '''    removePlaceholder(sheet);
    simplifyThemeCatalog(sheet);
    orderSections(sheet);
    syncMarks();'''
    if old_normalize not in text:
        raise SystemExit("theme simplification: normalize marker missing")
    text = text.replace(old_normalize, new_normalize, 1)
    count_marker = '''    const natureCount = sheet.querySelectorAll(".lrThemeCard[data-theme-key]").length;'''
    count_new = '''    if (window.lifeRouteSimplifiedThemeCatalogV4) {
      const metallicCount = sheet.querySelectorAll(".lrThemeCard[data-metallic-key]").length;
      const dynamicCount = sheet.querySelectorAll(".lrThemeCard[data-dynamic-key]").length;
      const fluidCount = sheet.querySelectorAll(".lrThemeCard[data-fluid-key]").length;
      const total = metallicCount + dynamicCount + fluidCount;
      count.textContent = total ? `${total} themes` : "Themes";
      return;
    }
    const natureCount = sheet.querySelectorAll(".lrThemeCard[data-theme-key]").length;'''
    if count_marker not in text:
        raise SystemExit("theme simplification: count marker missing")
    text = text.replace(count_marker, count_new, 1)
    theme.write_text(text)


# ---------- Landscape support for app + First/Then + choice boards ----------
plist = ROOT / "LifeRoute" / "Info.plist"
plist_text = plist.read_text()
if "UIInterfaceOrientationLandscapeLeft" not in plist_text:
    old = '''    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
    </array>'''
    new = '''    <key>UISupportedInterfaceOrientations</key>
    <array>
        <string>UIInterfaceOrientationPortrait</string>
        <string>UIInterfaceOrientationLandscapeLeft</string>
        <string>UIInterfaceOrientationLandscapeRight</string>
    </array>'''
    if old not in plist_text:
        raise SystemExit("landscape orientations: plist marker missing")
    plist.write_text(plist_text.replace(old, new, 1))

first_then = ROOT / "LifeRoute" / "Web" / "first-then-back.js"
text = first_then.read_text()
if "lrLandscapeBoardsV1" not in text:
    marker = '''      @media(max-width:680px){#lifeRouteFirstThenEscape{min-width:88px;min-height:44px;padding:9px 13px;font-size:12px}}\n'''
    addition = '''      @media(max-width:680px){#lifeRouteFirstThenEscape{min-width:88px;min-height:44px;padding:9px 13px;font-size:12px}}\n      /* lrLandscapeBoardsV1 */\n      @media(orientation:landscape) and (max-height:700px){\n        #firstThenOverlay{overflow:auto!important}\n        #firstThenOverlay .firstThenTop{position:sticky;top:0;z-index:5;padding-top:max(8px,env(safe-area-inset-top));background:color-mix(in srgb,var(--bg) 92%,transparent);backdrop-filter:blur(12px);-webkit-backdrop-filter:blur(12px)}\n        #firstThenOverlay .firstThenBoard{display:grid!important;grid-template-columns:minmax(0,1fr) auto minmax(0,1fr)!important;align-items:center!important;gap:14px!important;min-height:calc(100dvh - 74px)!important;padding:8px max(18px,env(safe-area-inset-right)) 16px max(18px,env(safe-area-inset-left))!important}\n        #firstThenOverlay .firstThenPanel{min-width:0!important}\n        #firstThenOverlay .firstThenVisualImage{width:min(38vw,420px)!important;max-height:46vh!important}\n        #firstThenOverlay .firstThenPanel.visualReady .firstThenValue{width:min(38vw,420px)!important;font-size:clamp(18px,3vw,32px)!important;padding:7px 10px 9px!important}\n        .choiceBoardOverlay{padding:max(7px,env(safe-area-inset-top)) max(12px,env(safe-area-inset-right)) max(8px,env(safe-area-inset-bottom)) max(12px,env(safe-area-inset-left))!important;overflow:auto!important}\n        .choiceBoardTop{margin-bottom:4px!important}.choiceBoardTitle{font-size:clamp(20px,5vh,32px)!important;margin:2px 0 7px!important}\n        .choiceBoardGrid{max-width:1180px!important;grid-template-columns:repeat(4,minmax(0,1fr))!important;gap:8px!important}\n        .choiceBoardCell{min-height:0!important;height:calc((100dvh - 118px)/2)!important;max-height:42vh!important;padding:5px!important;border-radius:14px!important}\n        .choiceBoardCell img{width:auto!important;max-width:100%!important;max-height:28vh!important;aspect-ratio:1!important}.choiceBoardCell b{font-size:clamp(14px,3.4vh,24px)!important;margin-top:3px!important}\n      }\n'''
    if marker not in text:
        raise SystemExit("landscape boards: First Then CSS marker missing")
    first_then.write_text(text.replace(marker, addition, 1))

print("LifeRoute requested polish applied: structured Apple AI output, ABA narrative/privacy safeguards, simplified themes, louder silent-mode timer, explicit Image Playground subjects, and landscape boards.")
