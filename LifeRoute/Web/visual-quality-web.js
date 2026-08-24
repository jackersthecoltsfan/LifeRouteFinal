// Web-preview visual quality guard for First / Then smart photos.
// Tightens ambiguous concepts so an unrelated literal keyword match never wins.
(() => {
  if (window.__lifeRouteVisualQualityWebLoaded) return;
  window.__lifeRouteVisualQualityWebLoaded = true;

  const normalize = value => String(value || "")
    .normalize("NFKD")
    .replace(/[’']/g, "")
    .replace(/[^a-zA-Z0-9\s-]/g, " ")
    .toLowerCase()
    .replace(/\s+/g, " ")
    .trim();

  const PROFILES = {
    cleanup: {
      query: "child cleaning up toys putting toys away toy bin playroom photograph",
      human: ["child", "children", "kid", "kids", "boy", "girl", "toddler"],
      context: ["toy", "toys", "cleanup", "clean up", "tidy", "tidying", "putting away", "playroom", "storage bin", "toy bin"],
      reject: ["street", "road", "pavement", "sidewalk", "pressure washer", "power wash", "industrial", "construction", "janitor", "municipal", "parking", "exterior cleaning", "graffiti"],
      minScore: 10
    },
    shower: {
      query: "modern home bathroom shower interior showerhead bathtub glass shower photograph",
      context: ["shower", "showerhead", "shower head", "bathroom", "bath", "bathtub", "bath tub"],
      interior: ["bathroom", "interior", "shower", "showerhead", "bathtub", "bath tub", "tile", "glass"],
      reject: ["shower block", "shower building", "public shower", "campground", "camp site", "exterior", "outside", "sports facility", "locker room building", "shower station", "beach shower"],
      minScore: 7
    }
  };

  const profileFor = raw => {
    const text = normalize(raw);
    if (/^(clean up|cleanup|put away|tidy up|tidy)$/.test(text) || /\b(clean up|cleanup|put toys away|tidy up)\b/.test(text)) return ["cleanup", PROFILES.cleanup];
    if (/\b(shower|take a shower|bathroom shower)\b/.test(text)) return ["shower", PROFILES.shower];
    return null;
  };

  const titleFor = page => normalize(String(page?.title || "").replace(/^file:/i, ""));
  const containsAny = (text, terms) => terms.some(term => text.includes(term));

  const scorePage = (page, key, profile) => {
    const info = page?.imageinfo?.[0];
    const title = titleFor(page);
    const mime = String(info?.mime || "");
    if (!title || (mime && !/^image\/(jpeg|png|webp)$/i.test(mime))) return -1000;
    if (profile.reject.some(term => title.includes(term))) return -1000;

    let score = 0;
    if (key === "cleanup") {
      const human = containsAny(title, profile.human);
      const context = containsAny(title, profile.context);
      // Require BOTH a child and a cleanup/toy context. This intentionally
      // rejects generic cleaners, streets, pressure washing, and adult chores.
      if (!human || !context) return -1000;
      score += 7;
      profile.human.forEach(term => { if (title.includes(term)) score += 2; });
      profile.context.forEach(term => { if (title.includes(term)) score += 3; });
    } else if (key === "shower") {
      const context = containsAny(title, profile.context);
      const interior = containsAny(title, profile.interior);
      if (!context || !interior) return -1000;
      score += 6;
      profile.context.forEach(term => { if (title.includes(term)) score += 2; });
      if (/\b(home|house|residential|bathroom|interior)\b/.test(title)) score += 3;
      if (/\b(glass|tile|tiled|bathtub|showerhead)\b/.test(title)) score += 2;
    }
    if (/\b(photo|photograph|jpg|jpeg)\b/.test(title)) score += 1;
    score -= Number(page?.index || 0) * 0.04;
    return score;
  };

  const strictCommonsSearch = async (key, profile) => {
    const params = new URLSearchParams({
      action: "query",
      generator: "search",
      gsrsearch: profile.query,
      gsrnamespace: "6",
      gsrlimit: "30",
      prop: "imageinfo",
      iiprop: "url|mime|size",
      iiurlwidth: "1200",
      format: "json",
      origin: "*"
    });

    try {
      const response = await fetch(`https://commons.wikimedia.org/w/api.php?${params}`, {
        method: "GET",
        mode: "cors",
        credentials: "omit",
        cache: "default"
      });
      if (!response.ok) return null;
      const data = await response.json();
      const ranked = Object.values(data?.query?.pages || {})
        .map(page => ({ page, score: scorePage(page, key, profile) }))
        .filter(item => item.score >= profile.minScore)
        .sort((a, b) => b.score - a.score);

      const best = ranked[0]?.page;
      const info = best?.imageinfo?.[0];
      const url = info?.thumburl || info?.url;
      if (!url) return null;
      return {
        url,
        source: "wikimedia-strict",
        confidence: "high",
        canonical: key,
        title: String(best.title || "").replace(/^File:/i, ""),
        query: profile.query
      };
    } catch (_) {
      return null;
    }
  };

  const install = () => {
    const resolver = window.LifeRouteVisualResolver;
    if (!resolver?.resolve || resolver.__lifeRouteStrictWrapped) return false;

    const originalResolve = resolver.resolve.bind(resolver);
    ["clean up", "cleanup", "put away", "shower", "take a shower"].forEach(value => {
      try { resolver.forget?.(value); } catch (_) {}
    });

    resolver.resolve = async raw => {
      const special = profileFor(raw);
      if (!special) return originalResolve(raw);
      const [key, profile] = special;
      const result = await strictCommonsSearch(key, profile);
      // Do not fall back to the loose resolver for these concepts. A clean
      // text-only card is preferable to a semantically wrong photo.
      if (!result?.url) return null;
      try { resolver.remember?.(normalize(raw), result); } catch (_) {}
      return result;
    };
    resolver.__lifeRouteStrictWrapped = true;
    resolver.version = "1.2.0-web-strict";
    return true;
  };

  let attempts = 0;
  const timer = setInterval(() => {
    attempts += 1;
    if (install() || attempts > 100) clearInterval(timer);
  }, 80);
  install();
})();