import UIKit
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

/// Bộ khử dấu vết số & Ngụy trang siêu dữ liệu (Zero-Trace Metadata Sanitizer & Camouflage)
class ZeroTraceSanitizer {
    static let shared = ZeroTraceSanitizer()
    
    /// Xuất ảnh sạch hoàn toàn hoặc ngụy trang sang thông số máy ảnh gốc Apple
    func sanitizeAndExport(
        image: UIImage,
        mode: AntiForensicMode,
        originalData: Data? = nil,
        format: ExportFormat = .jpeg(quality: 0.98)
    ) -> Data? {
        guard let cgImage = image.cgImage else { return nil }
        let mutableData = NSMutableData()
        
        let typeIdentifier: CFString
        switch format {
        case .png:
            typeIdentifier = UTType.png.identifier as CFString
        case .jpeg:
            typeIdentifier = UTType.jpeg.identifier as CFString
        }
        
        guard let destination = CGImageDestinationCreateWithData(
            mutableData as CFMutableData,
            typeIdentifier,
            1,
            nil
        ) else { return nil }
        
        var destinationProperties: [CFString: Any] = [:]
        
        switch mode {
        case .cleanSlate:
            // Chế độ Xóa Trắng: Không nhúng bất kỳ metadata nào
            if case .jpeg(let quality) = format {
                destinationProperties[kCGImageDestinationLossyCompressionQuality] = quality
            }
            // Không truyền bất kỳ từ điển EXIF, TIFF, IPTC, XMP nào
            CGImageDestinationAddImage(destination, cgImage, destinationProperties as CFDictionary)
            
        case .appleCamouflage:
            // Chế độ Ngụy Trang: Giả lập chính xác 100% ảnh chụp gốc từ Apple Camera
            var tiffDict: [CFString: Any] = [
                kCGImagePropertyTIFFMake: "Apple",
                kCGImagePropertyTIFFModel: "iPhone 15 Pro",
                kCGImagePropertyTIFFSoftware: "17.6.1",
                kCGImagePropertyTIFFResolutionUnit: 2,
                kCGImagePropertyTIFFXResolution: 72,
                kCGImagePropertyTIFFYResolution: 72
            ]
            
            let nowFormatter = DateFormatter()
            nowFormatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
            let dateString = nowFormatter.string(from: Date())
            tiffDict[kCGImagePropertyTIFFDateTime] = dateString
            
            let exifDict: [CFString: Any] = [
                kCGImagePropertyExifDateTimeOriginal: dateString,
                kCGImagePropertyExifDateTimeDigitized: dateString,
                kCGImagePropertyExifColorSpace: 1, // sRGB
                kCGImagePropertyExifFocalLength: 6.76,
                kCGImagePropertyExifFNumber: 1.78,
                kCGImagePropertyExifExposureTime: 0.01, // 1/100s
                kCGImagePropertyExifISOSpeedRatings: [50],
                kCGImagePropertyExifLensMake: "Apple",
                kCGImagePropertyExifLensModel: "iPhone 15 Pro back triple camera 6.76mm f/1.78",
                kCGImagePropertyExifFlash: 16 // Flash did not fire
            ]
            
            destinationProperties[kCGImagePropertyTIFFDictionary] = tiffDict
            destinationProperties[kCGImagePropertyExifDictionary] = exifDict
            if case .jpeg(let quality) = format {
                destinationProperties[kCGImageDestinationLossyCompressionQuality] = quality
            }
            
            CGImageDestinationAddImage(destination, cgImage, destinationProperties as CFDictionary)
            
        case .preserveExif:
            // Giữ lại EXIF cũ nhưng lọc sạch các trường chỉnh sửa/AI
            var cleanProps = extractCleanedProperties(from: originalData)
            if case .jpeg(let quality) = format {
                cleanProps[kCGImageDestinationLossyCompressionQuality as String] = quality
            }
            CGImageDestinationAddImage(destination, cgImage, cleanProps as CFDictionary)
        }
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        return mutableData as Data
    }
    
    /// Lọc bỏ các trường nhạy cảm tố cáo phần mềm chỉnh sửa hoặc AI
    private func extractCleanedProperties(from data: Data?) -> [String: Any] {
        guard let data = data,
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let originalProps = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any] else {
            return [:]
        }
        
        var sanitized = originalProps
        
        // Danh sách các khóa nguy cơ cao cần tước bỏ
        let blacklist = [
            "Software", "CreatorTool", "History", "Derivation",
            "ImageUniqueID", "DocumentID", "OriginalDocumentID",
            "InstanceID", "XMP", "Photoshop", "c2pa", "synthid", "firefly"
        ]
        
        for (key, value) in sanitized {
            for bad in blacklist {
                if key.lowercased().contains(bad.lowercased()) {
                    sanitized.removeValue(forKey: key)
                }
            }
            
            if var subDict = value as? [String: Any] {
                for (subKey, _) in subDict {
                    for bad in blacklist {
                        if subKey.lowercased().contains(bad.lowercased()) {
                            subDict.removeValue(forKey: subKey)
                        }
                    }
                }
                sanitized[key] = subDict
            }
        }
        
        return sanitized
    }
}

enum ExportFormat {
    case jpeg(quality: CGFloat)
    case png
}
