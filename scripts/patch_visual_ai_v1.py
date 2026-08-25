from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"
VISUAL = ROOT / "LifeRoute" / "Web" / "visual-object-focus-v2.js"


def replace_once(text: str, old: str, new: str, label: str) -> str:
    if new in text:
        return text
    if old not in text:
        raise SystemExit(f"{label}: expected source pattern not found")
    return text.replace(old, new, 1)

# Native Apple Vision bridge. This is completely on-device: no cloud endpoint,
# API key, subscription, or per-image fee.
swift = SWIFT.read_text()
if "import Vision" not in swift:
    swift = swift.replace("import UIKit\n", "import UIKit\nimport Vision\n", 1)

if 'case "analyzeVisualSubject":' not in swift:
    marker = '            default:\n                emit(type: "bridgeError", payload: ["message": "Unknown native action: \\(action)"])'
    if marker not in swift:
        raise SystemExit("Vision bridge: native switch default marker not found")
    cases = '''            case "analyzeVisualSubject":
                let requestID = (body["requestId"] as? String) ?? UUID().uuidString
                let imageBase64 = (body["imageBase64"] as? String) ?? ""
                analyzeVisualSubject(requestID: requestID, imageBase64: imageBase64)
            case "openExternalURL":
                let rawURL = (body["url"] as? String) ?? ""
                openExternalURL(rawURL)
'''
    swift = swift.replace("            default:\n", cases + "            default:\n", 1)

if "private func analyzeVisualSubject(requestID:" not in swift:
    marker = "        private func emit(type: String, payload: [String: Any]) {"
    if marker not in swift:
        raise SystemExit("Vision bridge: emit marker not found")
    methods = '''        private func openExternalURL(_ rawValue: String) {
            let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed),
                  let scheme = url.scheme?.lowercased(),
                  scheme == "https" || scheme == "http" else { return }
            UIApplication.shared.open(url)
        }

        private func analyzeVisualSubject(requestID: String, imageBase64: String) {
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
                emit(type: "visualSubjectAnalysis", payload: ["requestId": requestID, "success": false])
                return
            }

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                let request = VNGenerateObjectnessBasedSaliencyImageRequest()
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                do {
                    try handler.perform([request])
                    guard let observation = request.results?.first,
                          let objects = observation.salientObjects,
                          let best = objects.max(by: {
                            ($0.boundingBox.width * $0.boundingBox.height) < ($1.boundingBox.width * $1.boundingBox.height)
                          }) else {
                        DispatchQueue.main.async {
                            self?.emit(type: "visualSubjectAnalysis", payload: ["requestId": requestID, "success": false])
                        }
                        return
                    }
                    let box = best.boundingBox
                    let topY = max(0, min(1, 1 - box.origin.y - box.height))
                    DispatchQueue.main.async {
                        self?.emit(type: "visualSubjectAnalysis", payload: [
                            "requestId": requestID,
                            "success": true,
                            "x": max(0, min(1, box.origin.x)),
                            "y": topY,
                            "width": max(0, min(1, box.width)),
                            "height": max(0, min(1, box.height)),
                            "engine": "apple-vision-saliency"
                        ])
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.emit(type: "visualSubjectAnalysis", payload: [
                            "requestId": requestID,
                            "success": false,
                            "message": error.localizedDescription
                        ])
                    }
                }
            }
        }

'''
    swift = swift.replace(marker, methods + marker, 1)
SWIFT.write_text(swift)

# Web-side bridge uses the Vision rectangle when native, and falls back to the
# existing local saliency heuristic in Safari/web preview.
visual = VISUAL.read_text()
visual = replace_once(visual, "  const subjectCrop = image => {", "  const heuristicSubjectCrop = image => {", "rename heuristic crop")

if "const requestVisionCrop = async image =>" not in visual:
    marker = "  const roundRect = (ctx, x, y, width, height, radius) => {"
    if marker not in visual:
        raise SystemExit("Visual AI: roundRect marker not found")
    ai_code = '''  let visionSequence = 0;
  const visionPending = new Map();
  let lastFocusEngine = "local-saliency";

  const analysisDataURL = image => {
    const maxSide = 720;
    const scale = Math.min(1, maxSide / Math.max(image.naturalWidth, image.naturalHeight));
    const canvas = document.createElement("canvas");
    canvas.width = Math.max(32, Math.round(image.naturalWidth * scale));
    canvas.height = Math.max(32, Math.round(image.naturalHeight * scale));
    const ctx = canvas.getContext("2d");
    ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL("image/jpeg", .74);
  };

  const cropFromVisionBox = (image, box) => {
    const x = clamp(Number(box?.x || 0), 0, 1);
    const y = clamp(Number(box?.y || 0), 0, 1);
    const width = clamp(Number(box?.width || 0), 0, 1);
    const height = clamp(Number(box?.height || 0), 0, 1);
    if (width < .03 || height < .03) return null;
    const centerX = (x + width / 2) * image.naturalWidth;
    const centerY = (y + height / 2) * image.naturalHeight;
    const subjectSide = Math.max(width * image.naturalWidth, height * image.naturalHeight);
    const minSide = Math.min(image.naturalWidth, image.naturalHeight);
    const side = clamp(subjectSide * 1.42, minSide * .46, minSide * .96);
    return {
      left: clamp(centerX - side / 2, 0, Math.max(0, image.naturalWidth - side)),
      top: clamp(centerY - side / 2, 0, Math.max(0, image.naturalHeight - side)),
      side,
      focusX: centerX,
      focusY: centerY
    };
  };

  const requestVisionCrop = async image => {
    const handler = window.webkit?.messageHandlers?.lifeRoute;
    if (!handler || typeof handler.postMessage !== "function") return null;
    const requestId = `vision-${Date.now()}-${++visionSequence}`;
    return new Promise(resolve => {
      const timeout = setTimeout(() => {
        visionPending.delete(requestId);
        resolve(null);
      }, 1500);
      visionPending.set(requestId, payload => {
        clearTimeout(timeout);
        visionPending.delete(requestId);
        if (!payload?.success) return resolve(null);
        resolve(cropFromVisionBox(image, payload));
      });
      try {
        handler.postMessage({
          action: "analyzeVisualSubject",
          requestId,
          imageBase64: analysisDataURL(image)
        });
      } catch (_) {
        clearTimeout(timeout);
        visionPending.delete(requestId);
        resolve(null);
      }
    });
  };

  const priorNativeEvent = window.lifeRouteNativeEvent;
  window.lifeRouteNativeEvent = function lifeRouteNativeEventWithVisualAI(evt) {
    if (typeof priorNativeEvent === "function") priorNativeEvent(evt);
    if (evt?.type !== "visualSubjectAnalysis") return;
    visionPending.get(String(evt.requestId || ""))?.(evt);
  };

  const resolveSubjectCrop = async image => {
    const vision = await requestVisionCrop(image);
    if (vision) {
      lastFocusEngine = "apple-vision-saliency";
      return vision;
    }
    lastFocusEngine = "local-saliency";
    return heuristicSubjectCrop(image);
  };

'''
    visual = visual.replace(marker, ai_code + marker, 1)

visual = replace_once(
    visual,
    "    const crop = subjectCrop(image);",
    "    const crop = await resolveSubjectCrop(image);",
    "use AI-assisted subject crop",
)
visual = replace_once(
    visual,
    '      if (typeof setStatus === "function") setStatus("Main subject focused · ready to label");',
    '      if (typeof setStatus === "function") setStatus(lastFocusEngine === "apple-vision-saliency" ? "Main subject focused with on-device AI · ready to label" : "Main subject focused locally · ready to label");',
    "AI status copy",
)
visual = replace_once(
    visual,
    "  window.LifeRouteVisualObjectFocus = { preprocess };",
    "  window.LifeRouteVisualObjectFocus = { preprocess, requestVisionCrop, heuristicSubjectCrop };",
    "visual AI exports",
)
VISUAL.write_text(visual)

print("On-device Apple Vision subject AI enabled with local heuristic fallback; external links use native iOS handoff.")
