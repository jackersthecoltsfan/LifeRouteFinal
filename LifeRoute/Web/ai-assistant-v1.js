// LifeRoute AI assistant runtime.
// Uses Apple Foundation Models through the native bridge when available.
// Browser/unsupported-device fallbacks remain deterministic and local.
(() => {
  if (window.__lifeRouteAIAssistantV1Loaded) return;
  window.__lifeRouteAIAssistantV1Loaded = true;

  const pending = new Map();
  const cache = new Map();
  let sequence = 0;
  const CACHE_LIMIT = 40;

  const clean = value => String(value || "").replace(/\s+/g, " ").trim();
  const handler = () => window.webkit?.messageHandlers?.lifeRoute;
  const nativeAvailable = () => typeof handler()?.postMessage === "function";

  const trimCache = () => {
    while (cache.size > CACHE_LIMIT) cache.delete(cache.keys().next().value);
  };

  const request = (task, prompt, options = {}) => {
    if (!nativeAvailable()) return Promise.resolve({ success: false, engine: "deterministic", reason: "browser" });
    const requestId = `ai-${Date.now()}-${++sequence}`;
    const timeoutMs = Math.max(1500, Math.min(12000, Number(options.timeoutMs || 7000)));
    return new Promise(resolve => {
      const timeout = setTimeout(() => {
        pending.delete(requestId);
        resolve({ success: false, engine: "deterministic", reason: "timeout" });
      }, timeoutMs);
      pending.set(requestId, payload => {
        clearTimeout(timeout);
        pending.delete(requestId);
        resolve(payload || { success: false, engine: "deterministic", reason: "empty" });
      });
      try {
        handler().postMessage({
          action: "aiGenerateText",
          requestId,
          task: clean(task).slice(0, 60),
          prompt: clean(prompt).slice(0, 12000)
        });
      } catch (_) {
        clearTimeout(timeout);
        pending.delete(requestId);
        resolve({ success: false, engine: "deterministic", reason: "bridge" });
      }
    });
  };

  const priorNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithAI(evt) {
    if (typeof priorNativeEvent === "function") priorNativeEvent(evt);
    if (evt?.type !== "foundationAIResponse") return;
    pending.get(String(evt.requestId || ""))?.(evt);
  };

  const parseJSON = text => {
    const raw = clean(text).replace(/^```(?:json)?/i, "").replace(/```$/i, "").trim();
    try { return JSON.parse(raw); } catch (_) {}
    const start = raw.indexOf("{");
    const end = raw.lastIndexOf("}");
    if (start >= 0 && end > start) {
      try { return JSON.parse(raw.slice(start, end + 1)); } catch (_) {}
    }
    return null;
  };

  const SYNONYMS = {
    "table work": ["child doing worksheet at table", "school worksheet desk"],
    work: ["child doing worksheet at table", "school work desk"],
    break: ["child quiet break", "child resting calm area"],
    outside: ["child outdoor play yard", "children outside playground"],
    swing: ["child playground swing", "playground swing child"],
    pool: ["child swimming pool", "swimming pool child"],
    bubbles: ["child blowing soap bubbles", "soap bubbles play"],
    snack: ["child eating snack", "snack food child"],
    eat: ["child eating meal", "child food table"],
    drink: ["child drinking water cup", "water cup child"],
    bathroom: ["bathroom toilet", "toilet bathroom"],
    "wash hands": ["child washing hands sink", "hand washing sink child"],
    "brush teeth": ["child brushing teeth toothbrush", "toothbrush child"],
    music: ["child listening to music", "music headphones child"],
    drawing: ["child drawing crayons", "crayons drawing child"],
    blocks: ["child toy building blocks", "building blocks toy"],
    puzzle: ["child jigsaw puzzle", "jigsaw puzzle child"],
    reading: ["child reading picture book", "picture book child"],
    book: ["child reading picture book", "picture book child"],
    car: ["car automobile", "family car"],
    home: ["house home exterior", "home house"],
    store: ["grocery store shopping cart", "supermarket aisle shopping"],
    park: ["children playground park", "playground park child"]
  };

  const deterministicVisualTerms = label => {
    const normalized = clean(label).toLowerCase();
    if (SYNONYMS[normalized]) return SYNONYMS[normalized];
    const words = normalized.replace(/[^a-z0-9\s-]/g, " ").replace(/\s+/g, " ").trim();
    if (!words) return [];
    return [`${words} photograph`, `${words} object activity photograph`];
  };

  const visualSearchTerms = async label => {
    const normalized = clean(label).toLowerCase();
    const key = `visual:${normalized}`;
    if (cache.has(key)) return cache.get(key);
    const fallback = deterministicVisualTerms(label);
    const prompt = `Return JSON only: {"queries":["...","...","..."]}. Convert this short visual-support label into up to 3 concrete, generic, child-recognizable photograph search phrases. Do not include names, private details, brands unless essential, therapy terminology, or explanations. Prefer a visible object, action, or place. Label: ${clean(label)}`;
    const result = await request("visual-search", prompt, { timeoutMs: 4500 });
    let queries = fallback;
    if (result?.success && result.text) {
      const parsed = parseJSON(result.text);
      const generated = Array.isArray(parsed?.queries) ? parsed.queries.map(clean).filter(Boolean).slice(0, 3) : [];
      if (generated.length) queries = [...new Set([...generated, ...fallback])].slice(0, 4);
    }
    cache.set(key, queries);
    trimCache();
    return queries;
  };

  const sessionPlan = async payload => {
    const minutes = Math.max(30, Number(payload?.minutes || 60));
    const targets = Array.isArray(payload?.targets) ? payload.targets.map(clean).filter(Boolean).slice(0, 18) : [];
    const reinforcers = Array.isArray(payload?.reinforcers) ? payload.reinforcers.map(clean).filter(Boolean).slice(0, 18) : [];
    const client = clean(payload?.client || "general session");
    const prompt = `Return JSON only in this shape: {"blocks":[{"minutes":15,"title":"...","detail":"..."}]}. Build a practical ${minutes}-minute ABA session flow for ${client}. ONLY organize the supervisor-approved targets and reinforcers supplied below. Do not invent treatment goals, prompting procedures, behavior protocols, diagnoses, clinical claims, or new interventions. Include pairing/regulation at the beginning, reasonable alternation of teaching or NET and reinforcement or movement, generalization, and wrap-up. The block minutes must total exactly ${minutes}. Keep titles short and details concise. Approved targets: ${targets.join("; ") || "none supplied"}. Approved reinforcers and activities: ${reinforcers.join("; ") || "none supplied"}.`;
    const result = await request("session-plan", prompt, { timeoutMs: 8500 });
    if (!result?.success || !result.text) return null;
    const parsed = parseJSON(result.text);
    const blocks = (Array.isArray(parsed?.blocks) ? parsed.blocks : []).map(block => ({
      minutes: Math.max(1, Math.round(Number(block?.minutes || 0))),
      title: clean(block?.title).slice(0, 80),
      detail: clean(block?.detail).slice(0, 280)
    })).filter(block => block.minutes > 0 && block.title);
    const total = blocks.reduce((sum, block) => sum + block.minutes, 0);
    if (!blocks.length || total !== minutes) return null;
    return { blocks, engine: result.engine || "apple-foundation-model" };
  };

  const dayBrief = async payload => {
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

  const summarizeNotes = async payload => {
    const notes = Array.isArray(payload?.notes) ? payload.notes.map(clean).filter(Boolean).slice(-18) : [];
    if (!notes.length) return null;
    const prompt = `Summarize these scratch session notes into a concise factual recap. Do not diagnose, infer intent, invent data, or turn it into a billable clinical note. Preserve uncertainty and only state what is present. Notes: ${JSON.stringify(notes)}`;
    const result = await request("note-summary", prompt, { timeoutMs: 6500 });
    return result?.success && result.text ? { text: clean(result.text).slice(0, 1400), engine: result.engine || "apple-foundation-model" } : null;
  };

  window.LifeRouteAI = {
    request,
    visualSearchTerms,
    deterministicVisualTerms,
    sessionPlan,
    dayBrief,
    routeBrief,
    summarizeNotes,
    parseJSON,
    nativeAvailable,
    version: "1.0.0"
  };
})();
