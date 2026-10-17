import UIKit
import CoreGraphics
import CoreImage
import Accelerate

/// Bộ máy Inpainting Native hiệu năng cao chạy trực tiếp trên chip Apple Silicon
class InpaintingEngine {
    static let shared = InpaintingEngine()
    private let ciContext = CIContext(options: [.useSoftwareRenderer: false])
    
    /// Xóa vật thể và bù đắp nội dung dựa trên Mask vẽ tay
    func processInpaint(
        sourceImage: UIImage,
        maskImage: UIImage,
        mode: InpaintingMode,
        completion: @escaping (UIImage?) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Tối ưu kích thước xử lý để duy trì tốc độ tức thì
            let maxDim: CGFloat = 1920
            let targetSource = sourceImage.resized(maxDimension: maxDim)
            let targetMask = maskImage.resized(maxDimension: maxDim)
            
            guard var (sourcePixels, width, height) = targetSource.extractRGBAPixels(),
                  let (maskPixels, mWidth, mHeight) = targetMask.extractRGBAPixels(),
                  width == mWidth, height == mHeight else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            switch mode {
            case .fastDiffusion:
                self.fastPatchDiffusion(
                    sourcePixels: &sourcePixels,
                    maskPixels: maskPixels,
                    width: width,
                    height: height,
                    iterations: 18
                )
            case .textureTransfer:
                self.textureSynthesisInpaint(
                    sourcePixels: &sourcePixels,
                    maskPixels: maskPixels,
                    width: width,
                    height: height
                )
            case .smartHybrid:
                // Bước 1: Khuếch tán lớp nền
                self.fastPatchDiffusion(
                    sourcePixels: &sourcePixels,
                    maskPixels: maskPixels,
                    width: width,
                    height: height,
                    iterations: 12
                )
                // Bước 2: Ghép hạt vân vi mô
                self.textureSynthesisInpaint(
                    sourcePixels: &sourcePixels,
                    maskPixels: maskPixels,
                    width: width,
                    height: height
                )
            }
            
            guard let resultImage = UIImage.fromRGBAPixels(&sourcePixels, width: width, height: height) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            DispatchQueue.main.async {
                completion(resultImage)
            }
        }
    }
    
    /// Thuật toán khuếch tán vi mép (Navier-Stokes / Telea Inpainting)
    private func fastPatchDiffusion(
        sourcePixels: inout [UInt8],
        maskPixels: [UInt8],
        width: Int,
        height: Int,
        iterations: Int
    ) {
        let bpp = 4
        let bpr = width * bpp
        
        // Tạo bản đồ đánh dấu vùng cần tẩy
        var isMasked = [Bool](repeating: false, count: width * height)
        for y in 0..<height {
            let rowOffset = y * bpr
            let maskRowOffset = y * width
            for x in 0..<width {
                let maskAlpha = maskPixels[rowOffset + x * bpp + 3]
                let maskRed = maskPixels[rowOffset + x * bpp]
                // Nếu điểm ảnh được tô (Alpha > 30 hoặc Đỏ > 50)
                if maskAlpha > 30 || maskRed > 50 {
                    isMasked[maskRowOffset + x] = true
                }
            }
        }
        
        // Lan truyền màu sắc từ viền ngoài vào trong tâm qua các vòng lặp
        for _ in 0..<iterations {
            for y in 1..<(height - 1) {
                let rowOffset = y * bpr
                let maskRowOffset = y * width
                
                for x in 1..<(width - 1) {
                    let idx = maskRowOffset + x
                    guard isMasked[idx] else { continue }
                    
                    var sumR: Int = 0
                    var sumG: Int = 0
                    var sumB: Int = 0
                    var count: Int = 0
                    
                    // Lấy mẫu 8 điểm lân cận
                    let neighbors = [
                        (x - 1, y), (x + 1, y),
                        (x, y - 1), (x, y + 1),
                        (x - 1, y - 1), (x + 1, y - 1),
                        (x - 1, y + 1), (x + 1, y + 1)
                    ]
                    
                    for (nx, ny) in neighbors {
                        let nPixelOffset = ny * bpr + nx * bpp
                        let weight = 1
                        sumR += Int(sourcePixels[nPixelOffset]) * weight
                        sumG += Int(sourcePixels[nPixelOffset + 1]) * weight
                        sumB += Int(sourcePixels[nPixelOffset + 2]) * weight
                        count += weight
                    }
                    
                    if count > 0 {
                        let pixelOffset = rowOffset + x * bpp
                        sourcePixels[pixelOffset] = UInt8(sumR / count)
                        sourcePixels[pixelOffset + 1] = UInt8(sumG / count)
                        sourcePixels[pixelOffset + 2] = UInt8(sumB / count)
                    }
                }
            }
        }
    }
    
    /// Thuật toán tái tạo vân nền từ vùng lân cận (Texture Transfer)
    private func textureSynthesisInpaint(
        sourcePixels: inout [UInt8],
        maskPixels: [UInt8],
        width: Int,
        height: Int
    ) {
        let bpp = 4
        let bpr = width * bpp
        let patchRadius = 6
        
        for y in stride(from: patchRadius, to: height - patchRadius, by: 2) {
            for x in stride(from: patchRadius, to: width - patchRadius, by: 2) {
                let centerMaskIdx = y * bpr + x * bpp + 3
                guard maskPixels[centerMaskIdx] > 40 else { continue }
                
                // Tìm vùng mẫu sạch gần nhất không bị che bởi mask
                var bestSampleX = x
                var bestSampleY = y
                var found = false
                
                let searchRadii = [8, 16, 24, 32]
                for radius in searchRadii {
                    let candidates = [
                        (x - radius, y), (x + radius, y),
                        (x, y - radius), (x, y + radius),
                        (x - radius, y - radius), (x + radius, y + radius)
                    ]
                    for (cx, cy) in candidates {
                        if cx >= 0 && cx < width && cy >= 0 && cy < height {
                            let cMaskIdx = cy * bpr + cx * bpp + 3
                            if maskPixels[cMaskIdx] < 20 {
                                bestSampleX = cx
                                bestSampleY = cy
                                found = true
                                break
                            }
                        }
                    }
                    if found { break }
                }
                
                if found {
                    // Sao chép khối kết cấu với độ mờ viền tự nhiên
                    for dy in -patchRadius...patchRadius {
                        let targetY = y + dy
                        let srcY = bestSampleY + dy
                        guard targetY >= 0 && targetY < height && srcY >= 0 && srcY < height else { continue }
                        
                        for dx in -patchRadius...patchRadius {
                            let targetX = x + dx
                            let srcX = bestSampleX + dx
                            guard targetX >= 0 && targetX < width && srcX >= 0 && srcX < width else { continue }
                            
                            let targetOffset = targetY * bpr + targetX * bpp
                            let srcOffset = srcY * bpr + srcX * bpp
                            
                            // Pha trộn 40% kết cấu mới với màu nền đã làm mịn
                            let blend: Float = 0.42
                            let r = Float(sourcePixels[targetOffset]) * (1 - blend) + Float(sourcePixels[srcOffset]) * blend
                            let g = Float(sourcePixels[targetOffset + 1]) * (1 - blend) + Float(sourcePixels[srcOffset + 1]) * blend
                            let b = Float(sourcePixels[targetOffset + 2]) * (1 - blend) + Float(sourcePixels[srcOffset + 2]) * blend
                            
                            sourcePixels[targetOffset] = UInt8(min(255, max(0, r)))
                            sourcePixels[targetOffset + 1] = UInt8(min(255, max(0, g)))
                            sourcePixels[targetOffset + 2] = UInt8(min(255, max(0, b)))
                        }
                    }
                }
            }
        }
    }
}
