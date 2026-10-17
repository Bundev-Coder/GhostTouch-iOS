import UIKit
import ImageIO

/// Bộ phân tích pháp chứng ảnh & Soi lỗi mức nén (Error Level Analysis - ELA)
class ForensicAnalyzer {
    static let shared = ForensicAnalyzer()
    
    /// Tạo ảnh nhiệt ELA (Error Level Analysis) để kiểm tra tính đồng nhất của hạt nén
    func generateELAImage(from image: UIImage, scale: CGFloat = 20.0) -> UIImage? {
        // Nén ảnh lại ở mức 95%
        guard let jpegData = image.jpegData(compressionQuality: 0.95),
              let compressedImage = UIImage(data: jpegData),
              let (origPixels, width, height) = image.extractRGBAPixels(),
              let (compPixels, cWidth, cHeight) = compressedImage.extractRGBAPixels(),
              width == cWidth, height == cHeight else {
            return nil
        }
        
        var diffPixels = [UInt8](repeating: 0, count: width * height * 4)
        let bpp = 4
        
        for i in stride(from: 0, to: origPixels.count, by: bpp) {
            let diffR = abs(Int(origPixels[i]) - Int(compPixels[i]))
            let diffG = abs(Int(origPixels[i + 1]) - Int(compPixels[i + 1]))
            let diffB = abs(Int(origPixels[i + 2]) - Int(compPixels[i + 2]))
            
            // Khuếch đại sai số để mắt người nhìn rõ cấu trúc nén
            let outR = min(255, Int(CGFloat(diffR) * scale))
            let outG = min(255, Int(CGFloat(diffG) * scale))
            let outB = min(255, Int(CGFloat(diffB) * scale))
            
            diffPixels[i] = UInt8(outR)
            diffPixels[i + 1] = UInt8(outG)
            diffPixels[i + 2] = UInt8(outB)
            diffPixels[i + 3] = 255 // Alpha đầy đủ
        }
        
        return UIImage.fromRGBAPixels(&diffPixels, width: width, height: height)
    }
    
    /// Quét siêu dữ liệu để tìm các dấu vết phần mềm và AI
    func scanMetadata(data: Data?) -> ForensicsReport {
        var report = ForensicsReport()
        guard let data = data,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return report
        }
        
        let suspiciousKeywords = [
            "adobe", "photoshop", "lightroom", "snapseed", "picsart",
            "meitu", "c2pa", "dall-e", "midjourney", "stable diffusion",
            "generator", "synthid", "firefly", "canvas", "inpaint"
        ]
        
        for (category, value) in properties {
            if let subDict = value as? [String: Any] {
                for (key, val) in subDict {
                    let valStr = "\(val)"
                    let isSuspicious = suspiciousKeywords.contains { keyword in
                        key.lowercased().contains(keyword) || valStr.lowercased().contains(keyword)
                    }
                    
                    if isSuspicious {
                        report.suspiciousCount += 1
                        if key.lowercased().contains("c2pa") { report.hasC2PAFlag = true }
                        if key.lowercased().contains("photoshop") { report.hasPhotoshopTag = true }
                        if valStr.lowercased().contains("ai") || valStr.lowercased().contains("diffusion") {
                            report.hasAIGeneratedMarker = true
                        }
                    }
                    
                    report.rawMetadataItems.append(
                        MetadataItem(category: category, key: key, value: valStr, isSuspicious: isSuspicious)
                    )
                }
            } else {
                let valStr = "\(value)"
                let isSuspicious = suspiciousKeywords.contains { keyword in
                    category.lowercased().contains(keyword) || valStr.lowercased().contains(keyword)
                }
                if isSuspicious { report.suspiciousCount += 1 }
                
                report.rawMetadataItems.append(
                    MetadataItem(category: "General", key: category, value: valStr, isSuspicious: isSuspicious)
                )
            }
        }
        
        return report
    }
}
