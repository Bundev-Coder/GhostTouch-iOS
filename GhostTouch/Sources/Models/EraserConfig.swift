import SwiftUI

/// Chế độ thuật toán tẩy bù đắp ảnh (Inpainting)
enum InpaintingMode: String, CaseIterable, Identifiable {
    case fastDiffusion = "Khuếch Tán Vi Mép (Fast Patch)"
    case textureTransfer = "Tái Sinh Vân Nền (Texture Synthesis)"
    case smartHybrid = "Đa Tầng Kết Hợp (Smart Hybrid)"
    
    var id: String { self.rawValue }
    
    var description: String {
        switch self {
        case .fastDiffusion:
            return "Tốc độ tức thì (<0.1s), tối ưu cho xóa nốt ruồi, mụn, chữ ký, văn bản, vết xước nhỏ."
        case .textureTransfer:
            return "Tái tạo kết cấu hạt và hoa văn xung quanh, thích hợp cho xóa người, cột điện, vật thể lớn."
        case .smartHybrid:
            return "Tự động phân tích biên và độ tương phản để chọn vùng ghép mẫu mịn nhất."
        }
    }
}

/// Chế độ xóa dấu vết phần mềm và ngụy trang chống soi (Anti-Forensic Camouflage)
enum AntiForensicMode: String, CaseIterable, Identifiable {
    case cleanSlate = "Xóa Trắng Tuyệt Đối (Clean Slate)"
    case appleCamouflage = "Ngụy Trang Camera Apple Gốc (iPhone 15 Pro)"
    case preserveExif = "Giữ Lại Ngày Giờ Gốc (Sanitized Safe)"
    
    var id: String { self.rawValue }
    
    var subtitle: String {
        switch self {
        case .cleanSlate:
            return "Triệt tiêu 100% EXIF, IPTC, XMP, C2PA, Adobe Photoshop tags. 0 byte dữ liệu theo dõi."
        case .appleCamouflage:
            return "Tạo bộ EXIF chuẩn như chụp thẳng từ Camera Apple iPhone, che giấu hoàn toàn app thứ 3."
        case .preserveExif:
            return "Giữ nguyên ngày giờ chụp và thông số máy ảnh nhưng xóa sạch dấu vết AI và phần mềm chỉnh sửa."
        }
    }
}

/// Cấu hình cọ vẽ và bộ lọc tẩy dấu vết
struct EraserConfig {
    var brushSize: CGFloat = 28.0
    var brushFeather: CGFloat = 6.0
    var inpaintingMode: InpaintingMode = .smartHybrid
    var antiForensicMode: AntiForensicMode = .appleCamouflage
    
    // Tự động phun bù hạt cảm biến ISO để khử hiện tượng láng mịn nhân tạo
    var enableSensorGrainInjection: Bool = true
    var grainIntensity: Float = 0.55 // 0.0 - 1.0
    
    // Tước bỏ thẻ định danh bản quyền AI (C2PA, SynthID, Content Credentials)
    var stripC2PACredentials: Bool = true
    var stripPhotoshopHistory: Bool = true
    var highResolutionExport: Bool = true
}
