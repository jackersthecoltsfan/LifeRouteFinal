from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
SWIFT = (ROOT / "LifeRoute" / "LifeRouteWebView.swift").read_text()
PREP = (ROOT / "scripts" / "prepare_build.sh").read_text()
MODULES = {
    name: (WEB / name).read_text()
    for name in [
        "ai-assistant-v1.js",
        "visual-resolver-ai-v2.js",
        "ai-planning-v1.js",
        "image-playground-v1.js",
        "first-then-ai-studio-v1.js",
        "aba-ai-note-v1.js",
        "visual-object-focus-v2.js",
        "visual-resolver.js",
        "visual-resolver-bridge.js",
    ]
}

checks = []
def check(name, condition):
    checks.append((name, bool(condition)))

# Privacy boundary: photos + ABA text stay on-device in the AI layers.
local_only_modules = ["ai-assistant-v1.js", "ai-planning-v1.js", "image-playground-v1.js", "first-then-ai-studio-v1.js", "aba-ai-note-v1.js", "visual-object-focus-v2.js"]
for name in local_only_modules:
    text = MODULES[name]
    check(f"{name} has no http endpoint", "http://" not in text and "https://" not in text)
    check(f"{name} has no direct network fetch", "fetch(" not in text)

check("Foundation Models imported conditionally", "#if canImport(FoundationModels)" in SWIFT and "import FoundationModels" in SWIFT)
check("Image Playground imported conditionally", "#if canImport(ImagePlayground)" in SWIFT and "import ImagePlayground" in SWIFT)
check("Foundation model unavailable path returns fallback", '"model-unavailable"' in SWIFT and '"deterministic"' in SWIFT)
check("unsupported OS Foundation model path returns fallback", '"unsupported-os"' in SWIFT)
check("Image Playground device availability checked", "ImagePlaygroundViewController.isAvailable" in SWIFT)
check("Vision segmentation availability guarded", "#available(iOS 17.0" in SWIFT and "VNGenerateForegroundInstanceMaskRequest" in SWIFT)
check("Vision OCR uses local VNRecognizeTextRequest", "VNRecognizeTextRequest" in SWIFT and 'case "recognizeVisualText":' in SWIFT)

# No API keys/cloud model hosts were introduced.
combined = "\n".join(MODULES.values()) + "\n" + SWIFT
for forbidden in ["api.openai.com", "anthropic.com", "generativelanguage.googleapis.com", "api_key", "OPENAI_API_KEY", "ANTHROPIC_API_KEY"]:
    check(f"no embedded cloud AI secret/host {forbidden}", forbidden not in combined)

# The only new public network surface is generic Wikimedia visual search with deadlines.
resolver = MODULES["visual-resolver-ai-v2.js"]
check("semantic image search uses Wikimedia only", "commons.wikimedia.org" in resolver)
check("semantic search owns AbortController", "new AbortController()" in resolver and "controller.abort()" in resolver and "signal: controller.signal" in resolver)
check("semantic search has bounded deadline", "3800" in resolver)
check("semantic search strips obvious private patterns", "genericQuerySafe" in resolver and "/[.@]/" in resolver and "\\d{3,}" in resolver)
check("semantic search caps queries", ".slice(0, 3)" in resolver)
check("visual resolver still checks public lookup safety", "safeForPublicLookup" in resolver)

# Async lifecycle / memory bounds.
assistant = MODULES["ai-assistant-v1.js"]
check("AI request map clears on timeout", "pending.delete(requestId)" in assistant and "setTimeout" in assistant)
check("AI cache has explicit item cap", "CACHE_LIMIT = 40" in assistant and "trimCache" in assistant)
check("AI prompt length bounded", ".slice(0, 12000)" in assistant)
check("AI task length bounded", ".slice(0, 60)" in assistant)
studio = MODULES["image-playground-v1.js"]
check("Image Playground request has timeout cleanup", "180000" in studio and "pending.delete(requestId)" in studio)
firstthen = MODULES["first-then-ai-studio-v1.js"]
check("First Then AI fallback uses one scheduled timer", "let checkTimer = 0" in firstthen and "clearTimeout(checkTimer)" in firstthen)
check("First Then AI does not add broad MutationObserver", "MutationObserver" not in firstthen)
aba = MODULES["aba-ai-note-v1.js"]
check("ABA OCR request has timeout cleanup", "7000" in aba and "pendingOCR.delete(requestId)" in aba)
check("ABA OCR text is bounded", ".slice(0, 12000)" in aba)
check("ABA generated note is bounded", ".slice(0, 6000)" in aba)
check("ABA tool stores no screenshot or generated note in persistent storage", "localStorage.setItem" not in aba)
check("ABA tool never auto-sends documentation", "send" not in aba.lower())

# AI cannot become authority for exact route or clinical data.
planning = MODULES["ai-planning-v1.js"]
check("planning UI disclaims route authority", "AI never changes calendar times, MapKit travel times, stop durations, or leave-time calculations" in planning)
check("session fallback remains available", "deterministic fallback used" in planning)
check("route facts come from Live Day hooks", "LifeRouteLiveDayAIHooks" in planning)
check("AI does not post route actions itself", 'action: "openRoute"' not in planning and 'action: "requestRouteTimes"' not in planning)
check("AI does not write client profiles", "liferoute_client_profiles" not in planning and "prefs.clients" not in planning)
check("ABA note prohibits billing invention", "billing facts" in aba and "Review every fact before documentation or billing" in aba)
check("ABA note marks saved profile data context only", "context only" in aba)

# Shared deterministic startup and no duplicate script injection.
for module in ["ai-assistant-v1.js", "visual-resolver-ai-v2.js", "ai-planning-v1.js", "image-playground-v1.js", "first-then-ai-studio-v1.js", "aba-ai-note-v1.js"]:
    check(f"prepare_build validates {module} in shared startup", PREP.count(module) >= 2)  # core + CORE_JS validation
check("AI native patch owned once", PREP.count("patch_ai_everywhere_v2.py") == 1)
check("ABA OCR native patch owned once", PREP.count("patch_aba_ai_note_v1.py") == 1)

# Native action responses are request-ID scoped, not global shared state.
for action in ["aiGenerateText", "segmentVisualSubject", "openImagePlayground", "recognizeVisualText"]:
    check(f"native action exists: {action}", f'case "{action}":' in SWIFT)
check("Foundation response includes requestId", '"foundationAIResponse"' in SWIFT and '"requestId": requestID' in SWIFT)
check("cutout response includes requestId", '"visualSubjectCutout"' in SWIFT and '"requestId": requestID' in SWIFT)
check("Image Playground response includes requestId", '"imagePlaygroundResult"' in SWIFT and '"requestId": requestID' in SWIFT)
check("OCR response includes requestId", '"visualTextRecognition"' in SWIFT and '"requestId": requestID' in SWIFT)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute AI runtime/release audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit(1)
