from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"
VISUAL = ROOT / "LifeRoute" / "Web" / "visual-object-focus-v2.js"
TOOLS = ROOT / "LifeRoute" / "Web" / "visual-tools.js"
RBT = ROOT / "LifeRoute" / "Web" / "rbt-tools.js"
LIVE = ROOT / "LifeRoute" / "Web" / "live-day.js"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if old in text:
        return text.replace(old, new, 1)
    if new in text:
        return text
    raise SystemExit(f"{label}: expected source pattern not found")


# ---------- Native intelligence bridge ----------
swift = SWIFT.read_text()
if "#if canImport(FoundationModels)" not in swift:
    swift = swift.replace("import UIKit\n", "import UIKit\n#if canImport(FoundationModels)\nimport FoundationModels\n#endif\n#if canImport(ImagePlayground)\nimport ImagePlayground\n#endif\nimport CoreImage\n", 1)

if "final class LifeRouteImagePlaygroundDelegate" not in swift:
    marker = "struct LifeRouteWebView: UIViewRepresentable {"
    helper = '''#if canImport(ImagePlayground)
@available(iOS 18.2, *)
@MainActor
final class LifeRouteImagePlaygroundDelegate: NSObject, ImagePlaygroundViewController.Delegate {
    var completion: ((URL?) -> Void)?

    func imagePlaygroundViewController(
        _ imagePlaygroundViewController: ImagePlaygroundViewController,
        didCreateImageAt imageURL: URL
    ) {
        completion?(imageURL)
    }

    func imagePlaygroundViewControllerDidCancel(_ imagePlaygroundViewController: ImagePlaygroundViewController) {
        completion?(nil)
    }
}
#endif

'''
    if marker not in swift:
        raise SystemExit("Image Playground helper: LifeRouteWebView marker missing")
    swift = swift.replace(marker, helper + marker, 1)

if "private var imagePlaygroundDelegate" not in swift:
    marker = "        private let isoFormatter = ISO8601DateFormatter()\n"
    if marker not in swift:
        raise SystemExit("AI native state: iso formatter marker missing")
    swift = swift.replace(marker, marker + "        private var imagePlaygroundDelegate: AnyObject?\n", 1)

if 'case "aiGenerateText":' not in swift:
    marker = "            default:\n"
    if marker not in swift:
        raise SystemExit("AI native switch: default marker missing")
    cases = '''            case "aiGenerateText":
                let requestID = (body["requestId"] as? String) ?? UUID().uuidString
                let task = (body["task"] as? String) ?? "general"
                let prompt = (body["prompt"] as? String) ?? ""
                generateFoundationAI(requestID: requestID, task: task, prompt: prompt)
            case "segmentVisualSubject":
                let requestID = (body["requestId"] as? String) ?? UUID().uuidString
                let imageBase64 = (body["imageBase64"] as? String) ?? ""
                segmentVisualSubject(requestID: requestID, imageBase64: imageBase64)
            case "openImagePlayground":
                let requestID = (body["requestId"] as? String) ?? UUID().uuidString
                let label = (body["label"] as? String) ?? "Visual support"
                let source = body["imageBase64"] as? String
                openImagePlayground(requestID: requestID, label: label, imageBase64: source)
'''
    swift = swift.replace(marker, cases + marker, 1)

if "private func generateFoundationAI(requestID:" not in swift:
    marker = "        private func emit(type: String, payload: [String: Any]) {"
    if marker not in swift:
        raise SystemExit("AI native methods: emit marker missing")
    methods = r'''        private func base64ImageData(_ rawValue: String) -> Data? {
            let encoded: String
            if let comma = rawValue.firstIndex(of: ",") {
                encoded = String(rawValue[rawValue.index(after: comma)...])
            } else {
                encoded = rawValue
            }
            guard !encoded.isEmpty else { return nil }
            return Data(base64Encoded: encoded)
        }

        private func generateFoundationAI(requestID: String, task: String, prompt: String) {
            let boundedPrompt = String(prompt.prefix(12_000))
#if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                Task { [weak self] in
                    let model = SystemLanguageModel.default
                    guard case .available = model.availability else {
                        await MainActor.run {
                            self?.emit(type: "foundationAIResponse", payload: [
                                "requestId": requestID,
                                "success": false,
                                "engine": "deterministic",
                                "reason": "model-unavailable"
                            ])
                        }
                        return
                    }
                    do {
                        let session = LanguageModelSession(instructions: """
                            You are LifeRoute's concise planning intelligence. Follow the user's supplied constraints exactly. Never invent appointments, addresses, route times, stop durations, ABA treatment targets, prompting procedures, diagnoses, behavior protocols, or clinical claims. When JSON is requested, return JSON only.
                            """)
                        let response = try await session.respond(to: boundedPrompt)
                        await MainActor.run {
                            self?.emit(type: "foundationAIResponse", payload: [
                                "requestId": requestID,
                                "success": true,
                                "task": task,
                                "text": response.content,
                                "engine": "apple-foundation-model"
                            ])
                        }
                    } catch {
                        await MainActor.run {
                            self?.emit(type: "foundationAIResponse", payload: [
                                "requestId": requestID,
                                "success": false,
                                "engine": "deterministic",
                                "reason": "generation-failed",
                                "message": error.localizedDescription
                            ])
                        }
                    }
                }
                return
            }
#endif
            emit(type: "foundationAIResponse", payload: [
                "requestId": requestID,
                "success": false,
                "engine": "deterministic",
                "reason": "unsupported-os"
            ])
        }

        private func segmentVisualSubject(requestID: String, imageBase64: String) {
            guard let data = base64ImageData(imageBase64),
                  let image = UIImage(data: data),
                  let cgImage = image.cgImage else {
                emit(type: "visualSubjectCutout", payload: ["requestId": requestID, "success": false])
                return
            }

            if #available(iOS 17.0, *) {
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    let request = VNGenerateForegroundInstanceMaskRequest()
                    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                    do {
                        try handler.perform([request])
                        guard let observation = request.results?.first,
                              !observation.allInstances.isEmpty else {
                            DispatchQueue.main.async {
                                self?.emit(type: "visualSubjectCutout", payload: ["requestId": requestID, "success": false])
                            }
                            return
                        }
                        let pixelBuffer = try observation.generateMaskedImage(
                            ofInstances: observation.allInstances,
                            from: handler,
                            croppedToInstancesExtent: true
                        )
                        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
                        let context = CIContext(options: [.cacheIntermediates: false])
                        guard let maskedCG = context.createCGImage(ciImage, from: ciImage.extent),
                              let png = UIImage(cgImage: maskedCG).pngData() else {
                            DispatchQueue.main.async {
                                self?.emit(type: "visualSubjectCutout", payload: ["requestId": requestID, "success": false])
                            }
                            return
                        }
                        let dataURL = "data:image/png;base64," + png.base64EncodedString()
                        DispatchQueue.main.async {
                            self?.emit(type: "visualSubjectCutout", payload: [
                                "requestId": requestID,
                                "success": true,
                                "dataURL": dataURL,
                                "engine": "apple-vision-foreground-mask"
                            ])
                        }
                    } catch {
                        DispatchQueue.main.async {
                            self?.emit(type: "visualSubjectCutout", payload: [
                                "requestId": requestID,
                                "success": false,
                                "message": error.localizedDescription
                            ])
                        }
                    }
                }
            } else {
                emit(type: "visualSubjectCutout", payload: ["requestId": requestID, "success": false])
            }
        }

        private func openImagePlayground(requestID: String, label: String, imageBase64: String?) {
#if canImport(ImagePlayground)
            if #available(iOS 18.2, *) {
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    guard ImagePlaygroundViewController.isAvailable else {
                        self.emit(type: "imagePlaygroundResult", payload: [
                            "requestId": requestID,
                            "success": false,
                            "reason": "unavailable"
                        ])
                        return
                    }
                    let controller = ImagePlaygroundViewController()
                    controller.concepts = [
                        .text("A clean visual-support image of \(String(label.prefix(80))). One obvious centered subject, simple uncluttered background, bright natural colors, easy for a child to recognize, no written words in the image.")
                    ]
                    if let imageBase64,
                       let data = self.base64ImageData(imageBase64),
                       let sourceImage = UIImage(data: data) {
                        controller.sourceImage = sourceImage
                    }
                    let proxy = LifeRouteImagePlaygroundDelegate()
                    proxy.completion = { [weak self, weak controller] url in
                        guard let self else { return }
                        defer {
                            controller?.dismiss(animated: true)
                            self.imagePlaygroundDelegate = nil
                        }
                        guard let url,
                              let data = try? Data(contentsOf: url) else {
                            self.emit(type: "imagePlaygroundResult", payload: [
                                "requestId": requestID,
                                "success": false,
                                "reason": "cancelled"
                            ])
                            return
                        }
                        let mime = url.pathExtension.lowercased() == "png" ? "image/png" : "image/jpeg"
                        self.emit(type: "imagePlaygroundResult", payload: [
                            "requestId": requestID,
                            "success": true,
                            "dataURL": "data:\(mime);base64," + data.base64EncodedString(),
                            "engine": "apple-image-playground"
                        ])
                    }
                    self.imagePlaygroundDelegate = proxy
                    controller.delegate = proxy
                    var presenter = self.webView?.window?.rootViewController
                    while let presented = presenter?.presentedViewController { presenter = presented }
                    guard let presenter else {
                        self.imagePlaygroundDelegate = nil
                        self.emit(type: "imagePlaygroundResult", payload: [
                            "requestId": requestID,
                            "success": false,
                            "reason": "no-presenter"
                        ])
                        return
                    }
                    presenter.present(controller, animated: true)
                }
                return
            }
#endif
            emit(type: "imagePlaygroundResult", payload: [
                "requestId": requestID,
                "success": false,
                "reason": "unsupported"
            ])
        }

'''
    swift = swift.replace(marker, methods + marker, 1)
SWIFT.write_text(swift)


# ---------- Better photo preprocessing: foreground segmentation + softer style ----------
visual = VISUAL.read_text()
if "const cutoutPending = new Map();" not in visual:
    marker = "  const requestVisionCrop = async image => {"
    if marker not in visual:
        raise SystemExit("AI cutout: requestVisionCrop marker missing; patch_visual_ai_v1 must run first")
    visual = visual.replace(marker, "  const cutoutPending = new Map();\n\n" + marker, 1)

if "const requestVisionCutout = async image =>" not in visual:
    marker = "  const priorNativeEvent = window.lifeRouteNativeEvent;"
    if marker not in visual:
        raise SystemExit("AI cutout: native event marker missing")
    cutout = '''  const requestVisionCutout = async image => {
    const handler = window.webkit?.messageHandlers?.lifeRoute;
    if (!handler || typeof handler.postMessage !== "function") return null;
    const requestId = `cutout-${Date.now()}-${++visionSequence}`;
    return new Promise(resolve => {
      const timeout = setTimeout(() => {
        cutoutPending.delete(requestId);
        resolve(null);
      }, 2600);
      cutoutPending.set(requestId, payload => {
        clearTimeout(timeout);
        cutoutPending.delete(requestId);
        if (!payload?.success || !payload.dataURL) return resolve(null);
        const cutout = new Image();
        cutout.onload = () => resolve(cutout);
        cutout.onerror = () => resolve(null);
        cutout.src = payload.dataURL;
      });
      try {
        handler.postMessage({
          action: "segmentVisualSubject",
          requestId,
          imageBase64: analysisDataURL(image)
        });
      } catch (_) {
        clearTimeout(timeout);
        cutoutPending.delete(requestId);
        resolve(null);
      }
    });
  };

'''
    visual = visual.replace(marker, cutout + marker, 1)

old_event = '''  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithVisualAI(evt) {
    if (typeof priorNativeEvent === "function") priorNativeEvent(evt);
    if (evt?.type !== "visualSubjectAnalysis") return;
    visionPending.get(String(evt.requestId || ""))?.(evt);
  };'''
new_event = '''  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithVisualAI(evt) {
    if (typeof priorNativeEvent === "function") priorNativeEvent(evt);
    if (evt?.type === "visualSubjectAnalysis") {
      visionPending.get(String(evt.requestId || ""))?.(evt);
      return;
    }
    if (evt?.type === "visualSubjectCutout") {
      cutoutPending.get(String(evt.requestId || ""))?.(evt);
    }
  };'''
visual = replace_once(visual, old_event, new_event, "AI cutout native event routing")
visual = replace_once(
    visual,
    "    const crop = await resolveSubjectCrop(image);\n    const canvas = document.createElement(\"canvas\");",
    "    const crop = await resolveSubjectCrop(image);\n    const cutout = await requestVisionCutout(image);\n    const canvas = document.createElement(\"canvas\");",
    "AI cutout preprocessing request",
)

old_subject = '''    // Sharp subject-forward crop with a soft white frame; visual-tools applies the final bold style afterward.
    const inset = 58;
    ctx.save();
    roundRect(ctx, inset, inset, 1024 - inset * 2, 1024 - inset * 2, 54);
    ctx.clip();
    ctx.filter = "saturate(1.13) contrast(1.08) brightness(1.02)";
    ctx.drawImage(image, crop.left, crop.top, crop.side, crop.side, inset, inset, 1024 - inset * 2, 1024 - inset * 2);
    ctx.restore();'''
new_subject = '''    // Prefer Apple's foreground-instance mask: actual subject isolation instead of a crop.
    const inset = 58;
    ctx.save();
    roundRect(ctx, inset, inset, 1024 - inset * 2, 1024 - inset * 2, 54);
    ctx.clip();
    if (cutout) {
      const maxW = 1024 - inset * 2 - 54;
      const maxH = 1024 - inset * 2 - 54;
      const ratio = Math.min(maxW / cutout.naturalWidth, maxH / cutout.naturalHeight);
      const drawW = Math.max(1, cutout.naturalWidth * ratio);
      const drawH = Math.max(1, cutout.naturalHeight * ratio);
      const drawX = 512 - drawW / 2;
      const drawY = 512 - drawH / 2 - Math.min(24, drawH * .035);
      ctx.shadowColor = "rgba(16,24,32,.17)";
      ctx.shadowBlur = 24;
      ctx.shadowOffsetY = 12;
      ctx.filter = "saturate(1.09) contrast(1.05) brightness(1.025)";
      ctx.drawImage(cutout, drawX, drawY, drawW, drawH);
      lastFocusEngine = "apple-vision-foreground-mask";
    } else {
      ctx.filter = "saturate(1.10) contrast(1.055) brightness(1.02)";
      ctx.drawImage(image, crop.left, crop.top, crop.side, crop.side, inset, inset, 1024 - inset * 2, 1024 - inset * 2);
    }
    ctx.restore();'''
visual = replace_once(visual, old_subject, new_subject, "AI isolated subject render")
visual = replace_once(
    visual,
    '    return new File([blob], `${base}-subject.jpg`, { type: "image/jpeg", lastModified: Date.now() });',
    '    return new File([blob], `${base}-${cutout ? "ai-subject" : "subject"}.jpg`, { type: "image/jpeg", lastModified: Date.now() });',
    "AI subject filename",
)
visual = replace_once(
    visual,
    '      if (typeof setStatus === "function") setStatus(lastFocusEngine === "apple-vision-saliency" ? "Main subject focused with on-device AI · ready to label" : "Main subject focused locally · ready to label");',
    '      if (typeof setStatus === "function") setStatus(lastFocusEngine === "apple-vision-foreground-mask" ? "Subject isolated with on-device Vision AI · ready to label" : lastFocusEngine === "apple-vision-saliency" ? "Main subject focused with on-device AI · ready to label" : "Main subject focused locally · ready to label");',
    "AI cutout status copy",
)
visual = replace_once(
    visual,
    "  window.LifeRouteVisualObjectFocus = { preprocess, requestVisionCrop, heuristicSubjectCrop };",
    "  window.LifeRouteVisualObjectFocus = { preprocess, requestVisionCrop, requestVisionCutout, heuristicSubjectCrop };",
    "AI cutout exports",
)
VISUAL.write_text(visual)


# Gentler final styling for isolated subjects; old photos retain posterized fallback.
tools = TOOLS.read_text()
if "const polishIsolatedSubject =" not in tools:
    marker = "  const makeVisualIcon = async (file, label) => {"
    if marker not in tools:
        raise SystemExit("Visual styling: makeVisualIcon marker missing")
    helper = '''  const polishIsolatedSubject = imageData => {
    const data = imageData.data;
    for (let i = 0; i < data.length; i += 4) {
      let r = data[i], g = data[i + 1], b = data[i + 2];
      const avg = (r + g + b) / 3;
      r = avg + (r - avg) * 1.08;
      g = avg + (g - avg) * 1.08;
      b = avg + (b - avg) * 1.08;
      data[i] = Math.max(0, Math.min(255, (r - 128) * 1.045 + 130));
      data[i + 1] = Math.max(0, Math.min(255, (g - 128) * 1.045 + 130));
      data[i + 2] = Math.max(0, Math.min(255, (b - 128) * 1.045 + 130));
    }
    return imageData;
  };

'''
    tools = tools.replace(marker, helper + marker, 1)

old_pixels = '''    try {
      const pixels = ctx.getImageData(x, y, w, h);
      ctx.putImageData(posterize(pixels, w, h), x, y);
    } catch (_) {}'''
new_pixels = '''    try {
      const pixels = ctx.getImageData(x, y, w, h);
      const isolated = /(?:ai-)?subject/i.test(String(file?.name || ""));
      ctx.putImageData(isolated ? polishIsolatedSubject(pixels) : posterize(pixels, w, h), x, y);
    } catch (_) {}'''
tools = replace_once(tools, old_pixels, new_pixels, "gentler isolated subject styling")
TOOLS.write_text(tools)


# Expose existing deterministic planners so AI can augment rather than duplicate them.
rbt = RBT.read_text()
if "window.LifeRouteFieldToolsAIHooks" not in rbt:
    marker = "  const bind = () => {"
    hooks = '''  window.LifeRouteFieldToolsAIHooks = {
    splitList,
    buildFallbackPlan: buildPlan,
    renderPlan,
    savePlan(planState) {
      state.lastPlan = planState;
      save();
      renderPlan(planState);
    },
    notes() { return state.notes.slice(); }
  };

'''
    if marker not in rbt:
        raise SystemExit("RBT AI hooks: bind marker missing")
    rbt = rbt.replace(marker, hooks + marker, 1)
RBT.write_text(rbt)

live = LIVE.read_text()
if "window.LifeRouteLiveDayAIHooks" not in live:
    marker = "  window.generateLifeRouteDay = () => {"
    hooks = '''  window.LifeRouteLiveDayAIHooks = {
    buildDay,
    notificationItems,
    renderPlan,
    isGenerated(dateKey) { return !!activeDays[dateKey]; }
  };

'''
    if marker not in live:
        raise SystemExit("Live Day AI hooks: generate marker missing")
    live = live.replace(marker, hooks + marker, 1)
LIVE.write_text(live)

print("LifeRoute AI v2: Foundation Models, foreground segmentation, Image Playground bridge, and planning hooks enabled.")
