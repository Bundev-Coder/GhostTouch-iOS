import UIKit

/// Báo cáo kiểm định dấu vết số và phân tích pháp chứng ảnh (Forensics & AI Detection Report)
struct MetadataItem: Identifiable {
    let id = UUID()
    let category: String // EXIF, IPTC, TIFF, XMP, C2PA
    let key: String
    let value: String
    let isSuspicious: Bool // Đánh dấu nếu là dấu vết app chỉnh sửa hoặc AI
}

struct ForensicsReport {
    // 1. Phân tích nội dung ảnh (Vision Content Recognition)
    var detectedContentTags: [String] = []       // Các đối tượng nhận diện trong ảnh (chân dung, xe cộ, phong cảnh...)
    var faceCount: Int = 0                       // Số lượng khuôn mặt phát hiện
    var containsText: Bool = false               // Có chữ/văn bản trong ảnh không
    
    // 2. Giám định AI (AI Detection & Artifacts)
    var aiProbability: Int = 0                   // Điểm xác suất AI: 0% - 100%
    var aiVerdict: String = "Đang phân tích..."  // Đánh giá: "Khả năng cao do AI tạo", "Nghi vấn chỉnh sửa", "Ảnh chụp tự nhiên"
    var detectedAIEngines: [String] = []         // Tên công cụ AI phát hiện (Midjourney, Stable Diffusion, DALL-E, FaceSwap...)
    var aiArtifactDetails: [String] = []         // Các chi tiết bất thường (Thiếu hạt CMOS, phổ nén lệch, C2PA manifest...)
    
    // 3. Giám định phần mềm chỉnh sửa (Editing Software Detection)
    var detectedSoftwares: [String] = []         // Tên phần mềm (Photoshop, Canva, Snapseed, PicsArt, Lightroom...)
    var editHistorySummary: [String] = []        // Lịch sử sửa (ngày giờ sửa, số lần re-save...)
    
    // 4. Siêu dữ liệu & Dấu vết số
    var rawMetadataItems: [MetadataItem] = []
    var suspiciousCount: Int = 0
    var elaHeatmapImage: UIImage? = nil
    var hasC2PAFlag: Bool = false
    var hasPhotoshopTag: Bool = false
    var hasAIGeneratedMarker: Bool = false
    
    // 5. Trạng thái sau khi Clean
    var isCleaned: Bool = false
    
    var isTotallyClean: Bool {
        return isCleaned || (suspiciousCount == 0 && aiProbability <= 5 && detectedSoftwares.isEmpty && !hasC2PAFlag)
    }
    
    var statusTitle: String {
        if isCleaned {
            return "100% Đã Làm Sạch Vô Vết"
        } else if aiProbability >= 70 {
            return "Cảnh Báo: \(aiProbability)% Dấu Vết AI"
        } else if !detectedSoftwares.isEmpty || suspiciousCount > 0 {
            return "Phát Hiện \(detectedSoftwares.count) App Chỉnh Sửa & \(suspiciousCount) Dấu Vết"
        } else {
            return "Ảnh Chụp Gốc Tự Nhiên"
        }
    }
}
