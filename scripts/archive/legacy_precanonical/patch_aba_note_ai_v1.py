from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SWIFT = ROOT / "LifeRoute" / "LifeRouteWebView.swift"

swift = SWIFT.read_text()

if 'case "ocrImageText":' not in swift:
    marker = '            default:\n'
    if marker not in swift:
        raise SystemExit("ABA Note OCR: native switch default marker not found")
    case = '''            case "ocrImageText":
                let requestID = (body["requestId"] as? String) ?? UUID().uuidString
                let imageBase64 = (body["imageBase64"] as? String) ?? ""
                recognizeImageText(requestID: requestID, imageBase64: imageBase64)
'''
    swift = swift.replace(marker, case + marker, 1)

if "private func recognizeImageText(requestID:" not in swift:
    marker = '        private func emit(type: String, payload: [String: Any]) {'
    if marker not in swift:
        raise SystemExit("ABA Note OCR: emit marker not found")
    method = r'''        private func recognizeImageText(requestID: String, imageBase64: String) {
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
                emit(type: "ocrImageTextResult", payload: ["requestId": requestID, "success": false])
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
                    let observations = request.results ?? []
                    let ordered = observations.sorted { left, right in
                        let dy = abs(left.boundingBox.midY - right.boundingBox.midY)
                        if dy > 0.025 { return left.boundingBox.midY > right.boundingBox.midY }
                        return left.boundingBox.minX < right.boundingBox.minX
                    }
                    let lines = ordered.compactMap { $0.topCandidates(1).first?.string }
                    let text = String(lines.joined(separator: "\n").prefix(12_000))
                    DispatchQueue.main.async {
                        self?.emit(type: "ocrImageTextResult", payload: [
                            "requestId": requestID,
                            "success": !text.isEmpty,
                            "text": text,
                            "engine": "apple-vision-ocr"
                        ])
                    }
                } catch {
                    DispatchQueue.main.async {
                        self?.emit(type: "ocrImageTextResult", payload: [
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
print("On-device Apple Vision OCR enabled for ABA Note AI screenshots.")
