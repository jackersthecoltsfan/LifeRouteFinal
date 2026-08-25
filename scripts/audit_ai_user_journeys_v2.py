from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
WEB = ROOT / "LifeRoute" / "Web"
SWIFT = (ROOT / "LifeRoute" / "LifeRouteWebView.swift").read_text()
PREP = (ROOT / "scripts" / "prepare_build.sh").read_text()
FILES = {
    "assistant": (WEB / "ai-assistant-v1.js").read_text(),
    "resolver": (WEB / "visual-resolver-ai-v2.js").read_text(),
    "planning": (WEB / "ai-planning-v1.js").read_text(),
    "studio": (WEB / "image-playground-v1.js").read_text(),
    "firstthen": (WEB / "first-then-ai-studio-v1.js").read_text(),
    "focus": (WEB / "visual-object-focus-v2.js").read_text(),
    "tools": (WEB / "visual-tools.js").read_text(),
    "rbt": (WEB / "rbt-tools.js").read_text(),
    "live": (WEB / "live-day.js").read_text(),
}

checks = []
def check(name, condition):
    checks.append((name, bool(condition)))

# Photo -> visual journey.
check("foreground instance segmentation native action", 'case "segmentVisualSubject":' in SWIFT)
check("Vision foreground request exists", "VNGenerateForegroundInstanceMaskRequest" in SWIFT)
check("masked image uses all foreground instances", "observation.allInstances" in SWIFT and "generateMaskedImage" in SWIFT)
check("foreground cutout returns local data URL", '"visualSubjectCutout"' in SWIFT and '"data:image/png;base64,"' in SWIFT)
check("web photo pipeline requests native cutout", "requestVisionCutout" in FILES["focus"] and 'action: "segmentVisualSubject"' in FILES["focus"])
check("photo pipeline retains Vision saliency fallback", "requestVisionCrop" in FILES["focus"] and "heuristicSubjectCrop" in FILES["focus"])
check("isolated subject gets gentler styling", "polishIsolatedSubject" in FILES["tools"] and "posterize" in FILES["tools"])
check("AI photo status names foreground engine", "apple-vision-foreground-mask" in FILES["focus"])

# Optional high quality image generation.
check("Image Playground native action", 'case "openImagePlayground":' in SWIFT)
check("Image Playground availability is gated", "ImagePlaygroundViewController.isAvailable" in SWIFT)
check("Image Playground accepts source photo", "controller.sourceImage = sourceImage" in SWIFT)
check("Image Playground is explicit user action", 'button.textContent = "AI image studio"' in FILES["studio"] and "button.onclick" in FILES["studio"])
check("Image Playground not automatically launched by photo selection", 'openImagePlayground' not in FILES["focus"])
check("First Then AI generation requires tap", 'button.textContent = "Create AI visual"' in FILES["firstthen"] and "button.onclick" in FILES["firstthen"])
check("generated First Then image saved locally", "localStorage.setItem(STORE" in FILES["firstthen"] and "apple-image-playground" in FILES["firstthen"])

# First / Then automatic visual search journey.
check("AI semantic resolver wraps standard resolver", "originalResolve" in FILES["resolver"] and "resolver.resolve = aiResolve" in FILES["resolver"])
check("AI expands short labels into visual queries", "visualSearchTerms" in FILES["assistant"] and 'task: "visual-search"' not in FILES["assistant"])
check("semantic resolver searches multiple phrases", "queries" in FILES["resolver"] and ".slice(0, 3)" in FILES["resolver"])
check("semantic resolver quality scores results", "semanticScore" in FILES["resolver"] and "score(page" in FILES["resolver"])
check("semantic resolver preserves curated high confidence results", 'primary.source === "curated"' in FILES["resolver"])
check("smart visual bridge still loads", "visual-resolver-bridge.js" in PREP)
check("First Then remains text safe when unresolved", "setTextOnly" in (WEB / "visual-resolver-bridge.js").read_text())

# Session planner journey.
check("Foundation Models native text action", 'case "aiGenerateText":' in SWIFT and "LanguageModelSession" in SWIFT)
check("Foundation Models availability checked", "SystemLanguageModel.default" in SWIFT and ".availability" in SWIFT)
check("session planner AI only organizes approved content", "ONLY organize the supervisor-approved targets" in FILES["assistant"])
check("session planner prohibits invented ABA treatment", "Do not invent treatment goals" in FILES["assistant"])
check("session plan enforces exact total minutes", "total !== minutes" in FILES["assistant"])
check("session planner exposes deterministic fallback", "buildFallbackPlan" in FILES["rbt"] and "sessionBypass" in FILES["planning"])
check("session AI saves through existing planner state", "hooks.savePlan(planState)" in FILES["planning"])

# Day / route planning journey.
check("Live Day exposes exact computed plan to AI", "LifeRouteLiveDayAIHooks" in FILES["live"] and "buildDay" in FILES["live"])
check("AI day brief treats appointment and route facts as immutable", "immutable" in FILES["assistant"] and "never change or contradict" in FILES["assistant"])
check("AI route brief prohibited from recalculating travel", "Do not calculate or alter travel times" in FILES["assistant"])
check("Generate Day triggers AI brief after deterministic build", "generateLifeRouteDayWithAI" in FILES["planning"] and "setTimeout(refreshDayAI" in FILES["planning"])
check("day UI states route math remains authoritative", "Fixed route math remains authoritative" in FILES["planning"])

# Notes intelligence journey.
check("AI scratch note recap exists", 'button.textContent = "AI recap"' in FILES["planning"])
check("notes summary forbids diagnosis and inference", "Do not diagnose, infer intent" in FILES["assistant"])
check("notes recap explicitly not billable documentation", "not a billable clinical note" in FILES["planning"])

# Graceful fallback / shared build.
check("AI assistant has deterministic unsupported-device fallback", 'engine: "deterministic"' in FILES["assistant"])
check("browser does not require native Foundation Models", "nativeAvailable" in FILES["assistant"])
for module in ["ai-assistant-v1.js", "visual-resolver-ai-v2.js", "ai-planning-v1.js", "image-playground-v1.js", "first-then-ai-studio-v1.js"]:
    check(f"shared build includes {module}", module in PREP)

failed = [name for name, ok in checks if not ok]
for name, ok in checks:
    print(f"{'PASS' if ok else 'FAIL'}: {name}")
print(f"LifeRoute AI user-journey audit: {len(checks)-len(failed)} passed, {len(failed)} failed")
if failed:
    raise SystemExit(1)
