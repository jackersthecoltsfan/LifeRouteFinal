// LifeRoute smart visual resolver.
// Resolves short, generic activity/object labels to concrete, child-recognizable photos.
// No API key is embedded. Common concepts use curated images; other safe generic terms
// are resolved through Wikimedia Commons and cached locally in the browser.
(() => {
  const CACHE_KEY = "liferoute_visual_resolver_v1";
  const CACHE_TTL_MS = 30 * 24 * 60 * 60 * 1000;
  const MAX_CACHE_ITEMS = 80;

  const CURATED = {
    table_work: {
      url: "https://images.unsplash.com/photo-1623287072561-95c7ba942539?auto=format&fit=crop&w=1200&q=88",
      query: "child doing school worksheet at table"
    },
    play: {
      url: "https://images.pexels.com/photos/8363750/pexels-photo-8363750.jpeg?auto=compress&dpr=1&w=1200",
      query: "child playing with toys"
    },
    outside: {
      url: "assets/visuals/outside.jpg?v=resolver-v1",
      query: "outdoor play area yard"
    }
  };

  const ALIASES = {
    "work": "table_work",
    "table work": "table_work",
    "desk work": "table_work",
    "school work": "table_work",
    "schoolwork": "table_work",
    "homework": "table_work",
    "worksheet": "table_work",
    "worksheets": "table_work",

    "play": "play",
    "free play": "play",
    "toy": "play",
    "toys": "play",
    "toy time": "play",

    "outside": "outside",
    "outdoors": "outside",
    "go outside": "outside",
    "play outside": "outside",
    "yard": "outside",
    "patio": "outside",
    "recess": "outside",

    "store": "store",
    "shop": "store",
    "shopping": "store",
    "grocery": "store",
    "groceries": "store",
    "grocery store": "store",
    "supermarket": "store",

    "chocolate": "chocolate",
    "chocolates": "chocolate",
    "candy": "candy",
    "treat": "candy",
    "treats": "candy",

    "eat": "eat",
    "eating": "eat",
    "food": "eat",
    "snack": "eat",
    "breakfast": "eat",
    "lunch": "eat",
    "dinner": "eat",
    "meal": "eat",

    "drink": "drink",
    "drinking": "drink",
    "water": "drink",
    "juice": "drink",

    "bathroom": "bathroom",
    "toilet": "bathroom",
    "potty": "bathroom",
    "wash hands": "wash_hands",
    "washing hands": "wash_hands",
    "hand washing": "wash_hands",
    "brush teeth": "brush_teeth",
    "brushing teeth": "brush_teeth",
    "toothbrush": "brush_teeth",

    "park": "park",
    "playground": "park",
    "swing": "swing",
    "swinging": "swing",
    "pool": "pool",
    "swim": "pool",
    "swimming": "pool",
    "water play": "water_play",
    "water table": "water_play",
    "bubbles": "bubbles",
    "blow bubbles": "bubbles",

    "ipad": "tablet",
    "tablet": "tablet",
    "screen time": "tablet",
    "phone": "phone",
    "music": "music",
    "song": "music",
    "sing": "music",
    "singing": "music",

    "break": "break",
    "rest": "break",
    "quiet time": "break",
    "calm": "break",
    "home": "home",
    "go home": "home",
    "car": "car",
    "drive": "car",
    "car ride": "car",
    "walk": "walk",
    "walking": "walk",

    "hug": "hug",
    "drawing": "drawing",
    "draw": "drawing",
    "coloring": "drawing",
    "colouring": "drawing",
    "crayons": "drawing",
    "blocks": "blocks",
    "lego": "blocks",
    "legos": "blocks",
    "magna tiles": "magna_tiles",
    "magna-tiles": "magna_tiles",
    "magnetic tiles": "magna_tiles",
    "magnet tiles": "magna_tiles",
    "puzzle": "puzzle",
    "read": "reading",
    "reading": "reading",
    "book": "reading",
    "books": "reading",
    "sleep": "sleep",
    "nap": "sleep",
    "bed": "sleep",
    "bedtime": "sleep",
    "sit": "sit",
    "sit down": "sit",
    "chair": "sit",
    "wait": "wait",
    "waiting": "wait",
    "clean up": "cleanup",
    "cleanup": "cleanup",
    "put away": "cleanup",
    "shoes": "shoes",
    "put on shoes": "shoes",
    "coat": "coat",
    "jacket": "coat",
    "put on coat": "coat",
    "tv": "tv",
    "television": "tv",
    "watch tv": "tv"
  };

  const SEARCH_QUERIES = {
    store: "grocery store supermarket aisle shopping cart photograph",
    chocolate: "chocolate bar pieces food photograph",
    candy: "colorful candy sweets food photograph",
    eat: "child eating meal at table photograph",
    drink: "child drinking water from cup photograph",
    bathroom: "bathroom toilet photograph",
    wash_hands: "child washing hands at sink photograph",
    brush_teeth: "child brushing teeth toothbrush photograph",
    park: "children playground park photograph",
    swing: "child on playground swing photograph",
    pool: "child swimming in pool photograph",
    water_play: "child water table play photograph",
    bubbles: "child blowing soap bubbles photograph",
    tablet: "child using tablet computer photograph",
    phone: "child holding smartphone photograph",
    music: "child listening to music headphones photograph",
    break: "child resting quiet area photograph",
    home: "house home exterior photograph",
    car: "family car automobile photograph",
    walk: "child walking outdoors photograph",
    hug: "child hugging caregiver photograph",
    drawing: "child drawing with crayons at table photograph",
    blocks: "child playing with toy building blocks photograph",
    magna_tiles: "magnetic building tiles toy photograph",
    puzzle: "child doing jigsaw puzzle photograph",
    reading: "child reading picture book photograph",
    sleep: "child sleeping in bed photograph",
    sit: "child sitting on chair photograph",
    wait: "child waiting seated photograph",
    cleanup: "child putting toys into storage bin photograph",
    shoes: "child putting on shoes photograph",
    coat: "child putting on jacket coat photograph",
    tv: "child watching television photograph"
  };

  const PERSON_WORDS = new Set(["mom","mother","dad","father","grandma","grandmother","grandpa","grandfather","teacher","therapist","friend"]);
  const BAD_TITLE_WORDS = [
    "logo", "icon", "symbol", "diagram", "chart", "map", "flag", "coat of arms",
    "poster", "sign", "drawing", "illustration", "clipart", "vector", "svg", "emoji",
    "screenshot", "scan", "document", "text"
  ];

  const normalize = value => String(value || "")
    .normalize("NFKD")
    .replace(/[’']/g, "")
    .replace(/[–—_]/g, " ")
    .replace(/[^a-zA-Z0-9\-\s]/g, " ")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();

  const singularish = value => {
    if (value.endsWith("ies") && value.length > 4) return value.slice(0, -3) + "y";
    if (value.endsWith("ses") && value.length > 4) return value.slice(0, -2);
    if (value.endsWith("s") && !value.endsWith("ss") && value.length > 3) return value.slice(0, -1);
    return value;
  };

  const canonicalFor = raw => {
    const normalized = normalize(raw);
    if (!normalized) return "";
    if (ALIASES[normalized]) return ALIASES[normalized];
    const singular = singularish(normalized);
    if (ALIASES[singular]) return ALIASES[singular];

    // Phrase matching is deliberately longest-first so "grocery store" wins over "store".
    const entries = Object.entries(ALIASES).sort((a, b) => b[0].length - a[0].length);
    for (const [phrase, canonical] of entries) {
      if (normalized.includes(phrase)) return canonical;
    }
    return normalized.replace(/\s+/g, "_");
  };

  const safeForPublicLookup = raw => {
    const normalized = normalize(raw);
    if (!normalized || normalized.length > 48) return false;
    if (/\d/.test(normalized)) return false;
    if (normalized.split(" ").length > 6) return false;
    if (/[.@]/.test(String(raw || ""))) return false;
    if (PERSON_WORDS.has(normalized)) return false;
    return true;
  };

  const readCache = () => {
    try {
      const parsed = JSON.parse(localStorage.getItem(CACHE_KEY) || "{}");
      return parsed && typeof parsed === "object" ? parsed : {};
    } catch (_) {
      return {};
    }
  };

  const writeCache = cache => {
    try {
      const items = Object.entries(cache)
        .sort((a, b) => Number(b[1]?.savedAt || 0) - Number(a[1]?.savedAt || 0))
        .slice(0, MAX_CACHE_ITEMS);
      localStorage.setItem(CACHE_KEY, JSON.stringify(Object.fromEntries(items)));
    } catch (_) {}
  };

  const cached = key => {
    const cache = readCache();
    const item = cache[key];
    if (!item?.url) return null;
    if (Date.now() - Number(item.savedAt || 0) > CACHE_TTL_MS) {
      delete cache[key];
      writeCache(cache);
      return null;
    }
    return item;
  };

  const remember = (key, result) => {
    if (!key || !result?.url) return result;
    const cache = readCache();
    cache[key] = { ...result, savedAt: Date.now() };
    writeCache(cache);
    return result;
  };

  const forget = raw => {
    const key = normalize(raw);
    if (!key) return;
    const cache = readCache();
    delete cache[key];
    writeCache(cache);
  };

  const termsForScore = raw => normalize(raw)
    .split(" ")
    .filter(term => term.length > 2 && !["child","photo","photograph","with","from","using","doing"].includes(term));

  const scoreCandidate = (page, rawQuery) => {
    const title = normalize(String(page?.title || "").replace(/^file:/i, ""));
    if (!title) return -100;
    if (BAD_TITLE_WORDS.some(word => title.includes(word))) return -100;
    const info = page?.imageinfo?.[0];
    const mime = String(info?.mime || "");
    if (mime && !/^image\/(jpeg|png|webp)$/i.test(mime)) return -100;

    let score = 0;
    for (const term of termsForScore(rawQuery)) {
      if (title.includes(term)) score += 4;
    }
    if (/\b(child|children|kid|boy|girl)\b/.test(title)) score += 2;
    if (/\b(photo|photograph|jpg|jpeg)\b/.test(title)) score += 1;
    score -= Number(page?.index || 0) * 0.04;
    return score;
  };

  const commonsSearch = async (query, originalText) => {
    const params = new URLSearchParams({
      action: "query",
      generator: "search",
      gsrsearch: query,
      gsrnamespace: "6",
      gsrlimit: "12",
      prop: "imageinfo",
      iiprop: "url|mime|size",
      iiurlwidth: "1200",
      format: "json",
      origin: "*"
    });

    const response = await fetch(`https://commons.wikimedia.org/w/api.php?${params.toString()}`, {
      method: "GET",
      mode: "cors",
      credentials: "omit",
      cache: "default"
    });
    if (!response.ok) throw new Error(`Commons search failed: ${response.status}`);
    const data = await response.json();
    const pages = Object.values(data?.query?.pages || {});
    const ranked = pages
      .map(page => ({ page, score: scoreCandidate(page, originalText || query) }))
      .filter(item => item.score > -50)
      .sort((a, b) => b.score - a.score);

    for (const { page, score } of ranked) {
      const info = page?.imageinfo?.[0];
      const url = info?.thumburl || info?.url;
      if (!url) continue;
      return {
        url,
        source: "wikimedia",
        confidence: score >= 4 ? "high" : score >= 1 ? "medium" : "low",
        title: String(page.title || "").replace(/^File:/i, "")
      };
    }
    return null;
  };

  const queryFor = (raw, canonical) => {
    if (SEARCH_QUERIES[canonical]) return SEARCH_QUERIES[canonical];

    const normalized = normalize(raw);
    // Lightweight category guessing improves arbitrary inputs without pretending
    // to know the meaning of a private/name-like phrase.
    if (/\b(cookie|cracker|fruit|apple|banana|orange|pizza|burger|sandwich|ice cream|cake|donut)\b/.test(normalized)) {
      return `${normalized} food photograph`;
    }
    if (/\b(ball|doll|train|truck|car|toy|game)\b/.test(normalized)) {
      return `${normalized} toy photograph`;
    }
    if (/\b(store|shop|market|restaurant|library|school|gym|playground|park)\b/.test(normalized)) {
      return `${normalized} place photograph`;
    }
    if (/\b(run|jump|dance|climb|paint|write|cook|bake|wash|brush|ride)\b/.test(normalized)) {
      return `child ${normalized} activity photograph`;
    }
    return `${normalized} object activity photograph`;
  };

  const resolve = async raw => {
    const normalized = normalize(raw);
    if (!normalized) return null;
    const canonical = canonicalFor(normalized);

    const curated = CURATED[canonical];
    if (curated?.url) {
      return {
        url: curated.url,
        source: "curated",
        confidence: "high",
        canonical
      };
    }

    const hit = cached(normalized);
    if (hit?.url) return hit;

    if (!safeForPublicLookup(raw)) return null;

    try {
      const query = queryFor(normalized, canonical);
      let result = await commonsSearch(query, normalized);
      if (!result && query !== `${normalized} photograph`) {
        result = await commonsSearch(`${normalized} photograph`, normalized);
      }
      if (!result?.url) return null;
      return remember(normalized, { ...result, canonical, query });
    } catch (_) {
      return null;
    }
  };

  window.LifeRouteVisualResolver = {
    normalize,
    canonicalFor,
    resolve,
    remember,
    forget,
    safeForPublicLookup,
    version: "1.0.0"
  };
})();
