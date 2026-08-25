// AI-assisted visual resolver layered over visual-resolver.js.
// Apple Foundation Models expands short labels locally; only generic search phrases
// are sent to Wikimedia Commons. Every network request has a hard deadline.
(() => {
  if (window.__lifeRouteVisualResolverAIV2Loaded) return;
  window.__lifeRouteVisualResolverAIV2Loaded = true;

  const resolver = window.LifeRouteVisualResolver;
  if (!resolver?.resolve) return;
  const originalResolve = resolver.resolve.bind(resolver);
  const originalNormalize = resolver.normalize.bind(resolver);
  const STOP_WORDS = new Set(["child","children","photo","photograph","object","activity","with","from","using","doing","the","and","for"]);
  const BAD = ["logo","icon","symbol","diagram","chart","map","flag","coat of arms","poster","sign","drawing","illustration","clipart","vector","svg","emoji","screenshot","scan","document","text","seal","emblem","statue","sculpture","taxidermy"];
  const SAFE_FALLBACK = /\b(eat|drink|snack|food|bathroom|toilet|wash|brush|teeth|park|playground|swing|pool|swim|bubbles|tablet|phone|music|break|home|house|car|walk|hug|draw|drawing|blocks|lego|tiles|puzzle|read|book|sleep|bed|sit|chair|wait|clean|shoes|coat|tv|store|shop|grocery|candy|chocolate|toy|ball|game|outside|work)\b/i;

  const words = value => originalNormalize(value).split(" ").filter(word => word.length > 2 && !STOP_WORDS.has(word));
  const genericQuerySafe = query => {
    const normalized = originalNormalize(query);
    if (!normalized || normalized.length > 110 || normalized.split(" ").length > 14) return false;
    if (/[.@]/.test(query) || /\d{3,}/.test(query)) return false;
    return !BAD.some(term => normalized.includes(term));
  };

  const score = (page, queryTerms, index) => {
    const info = page?.imageinfo?.[0];
    const title = originalNormalize(String(page?.title || "").replace(/^file:/i, ""));
    const mime = String(info?.mime || "");
    if (!title || !info || (mime && !/^image\/(jpeg|png|webp)$/i.test(mime))) return -999;
    if (BAD.some(term => title.includes(term))) return -999;
    let total = 0;
    queryTerms.forEach(term => { if (title.includes(term)) total += 4; });
    if (/\b(child|children|kid|boy|girl|person|people)\b/.test(title)) total += 1.2;
    if (/\b(photo|photograph|jpg|jpeg)\b/.test(title)) total += 1.2;
    const width = Number(info?.width || 0), height = Number(info?.height || 0);
    if (width >= 500 && height >= 500) total += 1;
    if (width >= 900 && height >= 700) total += .5;
    const ratio = width && height ? Math.max(width / height, height / width) : 1;
    if (ratio > 3.2) total -= 1.5;
    total -= index * .035;
    return total;
  };

  const commons = async (query, originalLabel) => {
    if (!genericQuerySafe(query)) return [];
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 3800);
    try {
      const params = new URLSearchParams({
        action: "query",
        generator: "search",
        gsrsearch: query,
        gsrnamespace: "6",
        gsrlimit: "20",
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
        cache: "default",
        signal: controller.signal
      });
      if (!response.ok) return [];
      const data = await response.json();
      const terms = [...new Set([...words(query), ...words(originalLabel)])];
      return Object.values(data?.query?.pages || {}).map((page, index) => ({
        page,
        query,
        score: score(page, terms, index)
      })).filter(item => item.score > -100);
    } catch (_) {
      return [];
    } finally {
      clearTimeout(timeout);
    }
  };

  const aiResolve = async raw => {
    const normalized = originalNormalize(raw);
    if (!normalized) return null;

    // Preserve curated/exact/high-confidence resolver hits immediately.
    const primary = await originalResolve(raw);
    if (primary?.url && (primary.source === "curated" || primary.confidence === "high")) return primary;

    let queries = [];
    try {
      queries = await window.LifeRouteAI?.visualSearchTerms?.(raw) || [];
    } catch (_) {}

    // Browser fallback only exposes clearly generic activity/object words.
    if (!queries.length && resolver.safeForPublicLookup?.(raw) && SAFE_FALLBACK.test(raw)) {
      queries = window.LifeRouteAI?.deterministicVisualTerms?.(raw) || [`${normalized} photograph`];
    }
    queries = [...new Set(queries.map(String).map(value => value.trim()).filter(genericQuerySafe))].slice(0, 3);
    if (!queries.length) return primary?.url ? primary : null;

    const batches = [];
    for (const query of queries) {
      const found = await commons(query, normalized);
      batches.push(...found);
      if (found.some(item => item.score >= 8)) break;
    }
    batches.sort((a, b) => b.score - a.score);
    const best = batches[0];
    const info = best?.page?.imageinfo?.[0];
    const url = info?.thumburl || info?.url;
    if (!url) return primary?.url ? primary : null;

    const result = {
      url,
      source: "wikimedia-ai-semantic",
      confidence: best.score >= 8 ? "high" : best.score >= 4 ? "medium" : "low",
      canonical: resolver.canonicalFor?.(raw) || normalized.replace(/\s+/g, "_"),
      title: String(best.page?.title || "").replace(/^File:/i, ""),
      query: best.query,
      semanticScore: Math.round(best.score * 10) / 10
    };
    resolver.remember?.(normalized, result);
    return result;
  };

  resolver.resolve = aiResolve;
  resolver.aiResolve = aiResolve;
  resolver.version = "2.0.0-ai";
})();
