import Vision

/// On-device OCR for the nutrition / ingredients panel, used when a barcode
/// lookup finds nothing or the user wants to check the physical label.
/// Vision runs on-device; the image never leaves the phone.
struct OCRService {
    /// Recognise text in an image. Accurate level, language correction on.
    static func recogniseText(in image: CGImage) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let text = (request.results as? [VNRecognizedTextObservation])?
                    .compactMap { $0.topCandidates(1).first?.string }
                    .joined(separator: "\n") ?? ""
                continuation.resume(returning: text)
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Allergens found in OCR text, via the on-device matcher.
    /// The caller shows the matches and asks the user to confirm them:
    /// OCR can misread, so extracted allergens are never presented as fact.
    static func allergensInText(_ text: String) -> [String] {
        AllergenMatcher.extractAllergens(from: text)
    }
}
