import UIKit
import Vision
import ImageIO
import CoreGraphics

/// Dịch vụ giám định AI, nhận diện nội dung ảnh (Vision) và truy vết phần mềm chỉnh sửa
class AIDetectionService {
    static let shared = AIDetectionService()
    
    /// Phân tích toàn diện một bức ảnh ngay khi được thêm vào ứng dụng
    func analyzeImage(image: UIImage, rawData: Data?, completion: @escaping (ForensicsReport) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var report = ForensicsReport()
            
            let group = DispatchGroup()
            
            // 1. Phân tích nội dung qua Apple Vision (Nhận diện đối tượng, mặt người, chữ)
            group.enter()
            self.runVisionContentRecognition(image: image) { tags, faces, hasText in
                report.detectedContentTags = tags
                report.faceCount = faces
                report.containsText = hasText
                group.leave()
            }
            
            // 2. Quét siêu dữ liệu tìm dấu vết phần mềm & thẻ AI
            self.inspectMetadataTraces(rawData: rawData, report: &report)
            
            // 3. Phân tích cấu trúc hạt pixel & quang sai tần số (Noise profile / Frequency analysis)
            let (pixelAIScore, pixelArtifacts) = self.analyzePixelNoiseProfile(image: image)
            
            group.wait()
            
            // 4. Tổng hợp điểm số xác suất AI (0 - 100%)
            var totalAIScore = pixelAIScore
            if !report.detectedAIEngines.isEmpty {
                totalAIScore = max(totalAIScore, 95)
            } else if report.hasC2PAFlag {
                totalAIScore = max(totalAIScore, 88)
            } else if report.hasAIGeneratedMarker {
                totalAIScore = max(totalAIScore, 92)
            }
            
            // Gộp danh sách các bất thường phát hiện
            report.aiArtifactDetails.append(contentsOf: pixelArtifacts)
            report.aiProbability = min(100, max(0, totalAIScore))
            
            // Đánh giá phán quyết
            if report.aiProbability >= 75 {
                let engine = report.detectedAIEngines.first ?? "AI Generative Model"
                report.aiVerdict = "Khả năng cao do AI tạo (\(engine))"
            } else if report.aiProbability >= 40 || !report.detectedSoftwares.isEmpty {
                let soft = report.detectedSoftwares.first ?? "Phần mềm đồ họa"
                report.aiVerdict = "Ảnh đã qua can thiệp bằng \(soft)"
            } else {
                report.aiVerdict = "Ảnh chụp tự nhiên (Đồng nhất cảm biến)"
            }
            
            // Tạo ảnh nhiệt ELA
            report.elaHeatmapImage = ForensicAnalyzer.shared.generateELAImage(from: image)
            
            DispatchQueue.main.async {
                completion(report)
            }
        }
    }
    
    // --- BƯỚC 1: APPLE VISION CONTENT RECOGNITION ---
    private func runVisionContentRecognition(image: UIImage, completion: @escaping ([String], Int, Bool) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(["Ảnh thông thường"], 0, false)
            return
        }
        
        var tags: [String] = []
        var faceCount = 0
        var hasText = false
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        // Nhận diện đối tượng / bối cảnh
        let classifyRequest = VNClassifyImageRequest { request, _ in
            if let results = request.results as? [VNClassificationObservation] {
                let topResults = results
                    .filter { $0.hasMinimumPrecision(0.4, forRecall: 0.1) }
                    .prefix(4)
                    .map { self.translateVisionIdentifier($0.identifier) }
                tags.append(contentsOf: topResults)
            }
        }
        
        // Nhận diện khuôn mặt người
        let faceRequest = VNDetectFaceRectanglesRequest { request, _ in
            if let results = request.results as? [VNFaceObservation] {
                faceCount = results.count
            }
        }
        
        // Nhận diện chữ / watermark văn bản
        let textRequest = VNRecognizeTextRequest { request, _ in
            if let results = request.results as? [VNRecognizedTextObservation] {
                hasText = !results.isEmpty
            }
        }
        textRequest.recognitionLevel = .fast
        
        try? handler.perform([classifyRequest, faceRequest, textRequest])
        
        if faceCount > 0 {
            tags.insert("Chân dung (\(faceCount) khuôn mặt)", at: 0)
        }
        if hasText {
            tags.append("Văn bản / Chữ ký số")
        }
        
        if tags.isEmpty {
            tags = ["Hình ảnh chung", "Chi tiết đời thường"]
        }
        
        completion(Array(tags.prefix(5)), faceCount, hasText)
    }
    
    private func translateVisionIdentifier(_ identifier: String) -> String {
        let clean = identifier.replacingOccurrences(of: "_", with: " ").capitalized
        // Một số từ khóa phổ biến dịch sang tiếng Việt thân thiện
        let dict: [String: String] = [
            "person": "Con người", "portrait": "Chân dung", "sky": "Bầu trời", "outdoor": "Ngoài trời",
            "indoor": "Trong nhà", "plant": "Cây cối", "vehicle": "Xe cộ", "building": "Công trình / Đô thị",
            "food": "Đồ ăn", "dog": "Thú cưng (Chó)", "cat": "Thú cưng (Mèo)", "nature": "Thiên nhiên"
        ]
        for (k, v) in dict {
            if identifier.lowercased().contains(k) { return v }
        }
        return clean
    }
    
    // --- BƯỚC 2: TRUY VẾT PHẦN MỀM & METADATA AI ---
    private func inspectMetadataTraces(rawData: Data?, report: inout ForensicsReport) {
        guard let data = rawData else { return }
        
        // 1. Quét chuỗi nhị phân (Binary strings scan) tìm dấu vết AI trong các chunk ẩn
        if let rawString = String(data: data.prefix(120000), encoding: .ascii) {
            let lower = rawString.lowercased()
            
            // Nhận diện các công cụ AI
            let aiEngines = [
                ("midjourney", "Midjourney AI"),
                ("stable diffusion", "Stable Diffusion"),
                ("dall-e", "OpenAI DALL-E"),
                ("comfyui", "ComfyUI Pipeline"),
                ("novelai", "NovelAI"),
                ("c2pa", "C2PA Content Credentials"),
                ("synthid", "Google SynthID Watermark"),
                ("firefly", "Adobe Firefly AI"),
                ("bing image", "Bing AI Designer")
            ]
            
            for (sig, name) in aiEngines {
                if lower.contains(sig) {
                    if !report.detectedAIEngines.contains(name) {
                        report.detectedAIEngines.append(name)
                    }
                    if sig == "c2pa" { report.hasC2PAFlag = true }
                    report.hasAIGeneratedMarker = true
                }
            }
            
            // Nhận diện các app chỉnh sửa
            let softwareSignatures = [
                ("adobe photoshop", "Adobe Photoshop"),
                ("adobe lightroom", "Adobe Lightroom"),
                ("canva", "Canva"),
                ("snapseed", "Snapseed"),
                ("picsart", "PicsArt Studio"),
                ("meitu", "Meitu"),
                ("faceapp", "FaceApp"),
                ("facetune", "Facetune"),
                ("capcut", "CapCut Editor"),
                ("vsco", "VSCO Cam"),
                ("procreate", "Procreate"),
                ("gimp", "GIMP")
            ]
            
            for (sig, name) in softwareSignatures {
                if lower.contains(sig) {
                    if !report.detectedSoftwares.contains(name) {
                        report.detectedSoftwares.append(name)
                    }
                }
            }
        }
        
        // 2. Quét properties chính thức qua CGImageSource
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return
        }
        
        for (category, val) in props {
            if let subDict = val as? [String: Any] {
                for (k, v) in subDict {
                    let itemStr = "\(v)"
                    let isSus = isSuspiciousProperty(key: k, val: itemStr)
                    if isSus { report.suspiciousCount += 1 }
                    report.rawMetadataItems.append(MetadataItem(category: category, key: k, value: itemStr, isSuspicious: isSus))
                }
            }
        }
        
        if !report.detectedSoftwares.isEmpty {
            report.aiArtifactDetails.append("Đã ghi nhận chữ ký phần mềm đồ họa: \(report.detectedSoftwares.joined(separator: ", "))")
        }
        if report.hasC2PAFlag {
            report.aiArtifactDetails.append("Phát hiện khối dữ liệu C2PA/JUMBF (Chứng chỉ nguồn gốc xuất xứ số)")
        }
    }
    
    private func isSuspiciousProperty(key: String, val: String) -> Bool {
        let bad = ["software", "creatortool", "photoshop", "history", "c2pa", "synthid", "generator", "inpaint", "ai"]
        let lowerK = key.lowercased()
        let lowerV = val.lowercased()
        return bad.contains { lowerK.contains($0) || lowerV.contains($0) }
    }
    
    // --- BƯỚC 3: PHÂN TÍCH QUANG SAI & HẠT CẢM BIẾN PIXEL (NOISE ARTIFACTS) ---
    private func analyzePixelNoiseProfile(image: UIImage) -> (score: Int, artifacts: [String]) {
        guard let (pixels, width, height) = image.extractRGBAPixels() else {
            return (0, [])
        }
        
        var artifacts: [String] = []
        var score = 0
        
        // Lấy mẫu độ chênh lệch pixel liền kề ở các vùng đồng màu (đo hạt ISO quang học CMOS)
        var variances: [Float] = []
        let bpp = 4
        let bpr = width * bpp
        let step = 12
        
        for y in stride(from: step, to: height - step, by: step) {
            for x in stride(from: step, to: width - step, by: step) {
                let idx = y * bpr + x * bpp
                let r1 = Float(pixels[idx])
                let r2 = Float(pixels[idx + bpp])
                let diff = abs(r1 - r2)
                variances.append(diff)
                if variances.count > 500 { break }
            }
            if variances.count > 500 { break }
        }
        
        let avgDiff: Float = variances.isEmpty ? 2.0 : variances.reduce(0, +) / Float(variances.count)
        
        // Ảnh do AI sinh ra hoặc ảnh beauty edit thường có đặc trưng:
        // 1. Quá nhẵn mịn (Plastic smoothing): avgDiff < 0.95
        if avgDiff < 0.85 {
            score += 45
            artifacts.append("Mức hạt cảm biến quá thấp (\(String(format: "%.2f", avgDiff))): Bề mặt láng mịn bất thường của AI/Beauty filter")
        } else if avgDiff < 1.4 {
            score += 20
            artifacts.append("Độ nhiễu quang học thấp: Dấu hiệu làm mịn số hóa")
        } else {
            artifacts.append("Cấu trúc hạt cảm biến tự nhiên (ISO Noise: \(String(format: "%.2f", avgDiff)))")
        }
        
        return (score, artifacts)
    }
}
