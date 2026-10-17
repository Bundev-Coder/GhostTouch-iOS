import UIKit

/// Báo cáo kiểm định dấu vết số và phân tích pháp chứng ảnh (Forensics Report)
struct MetadataItem: Identifiable {
    let id = UUID()
    let category: String // EXIF, IPTC, TIFF, XMP, C2PA
    let key: String
    let value: String
    let isSuspicious: Bool // Đánh dấu nếu là dấu vết app chỉnh sửa hoặc AI
}

struct ForensicsReport {
    var rawMetadataItems: [MetadataItem] = []
    var cleanedMetadataItems: [MetadataItem] = []
    var suspiciousCount: Int = 0
    var elaHeatmapImage: UIImage? = nil
    var hasC2PAFlag: Bool = false
    var hasPhotoshopTag: Bool = false
    var hasAIGeneratedMarker: Bool = false
    
    var isTotallyClean: Bool {
        return suspiciousCount == 0 && !hasC2PAFlag && !hasPhotoshopTag && !hasAIGeneratedMarker
    }
    
    var statusTitle: String {
        if isTotallyClean {
            return "100% Sạch Không Dấu Vết"
        } else {
            return "Phát hiện \(suspiciousCount) dấu vết chỉnh sửa & AI"
        }
    }
}
