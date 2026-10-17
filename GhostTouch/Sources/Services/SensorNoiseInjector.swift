import UIKit
import CoreGraphics
import Accelerate

/// Bộ tái tạo hạt cảm biến ISO máy ảnh (Camera Sensor Noise Synthesizer)
/// Triệt tiêu hiện tượng "vùng tẩy bị láng mịn bất thường", chống lại các thuật toán soi ảnh AI & ELA
class SensorNoiseInjector {
    static let shared = SensorNoiseInjector()
    
    /// Bơm vi hạt cảm biến tự nhiên vào vùng ảnh bị tẩy xóa
    func injectSensorNoise(
        to image: UIImage,
        mask: UIImage,
        intensity: Float = 0.55
    ) -> UIImage {
        guard var (pixels, width, height) = image.extractRGBAPixels(),
              let (maskPixels, mWidth, mHeight) = mask.extractRGBAPixels(),
              width == mWidth, height == mHeight else {
            return image
        }
        
        let bpp = 4
        let bpr = width * bpp
        
        // Đo đạc độ lệch chuẩn hạt nhiễu (Sensor Noise Standard Deviation) của vùng gốc
        var sampleDiffs: [Float] = []
        let step = 8
        for y in stride(from: step, to: height - step, by: step) {
            for x in stride(from: step, to: width - step, by: step) {
                let maskAlpha = maskPixels[y * bpr + x * bpp + 3]
                // Chỉ lấy mẫu ở vùng ảnh thật không bị mask
                if maskAlpha < 10 {
                    let center = Float(pixels[y * bpr + x * bpp])
                    let neighbor = Float(pixels[y * bpr + (x + 1) * bpp])
                    sampleDiffs.append(abs(center - neighbor))
                    if sampleDiffs.count > 400 { break }
                }
            }
            if sampleDiffs.count > 400 { break }
        }
        
        // Tính biên độ hạt trung bình
        let averageNoiseScale: Float
        if !sampleDiffs.isEmpty {
            let avg = sampleDiffs.reduce(0, +) / Float(sampleDiffs.count)
            averageNoiseScale = max(1.5, min(avg, 8.0)) * intensity
        } else {
            averageNoiseScale = 3.2 * intensity
        }
        
        // Phủ hạt nhiễu vi mô đồng cấu trúc lên chính xác vùng đã tẩy xóa
        var seed: UInt32 = 123456789
        func fastRandom() -> Float {
            seed = (1103515245 &* seed &+ 12345) & 0x7fffffff
            let normalized = Float(seed) / Float(0x7fffffff)
            return (normalized - 0.5) * 2.0 // Giá trị từ -1.0 đến +1.0
        }
        
        for y in 0..<height {
            let rowOffset = y * bpr
            for x in 0..<width {
                let maskAlpha = maskPixels[rowOffset + x * bpp + 3]
                guard maskAlpha > 15 else { continue }
                
                let alphaFactor = Float(maskAlpha) / 255.0
                let noise = fastRandom() * averageNoiseScale * alphaFactor
                
                let pixelOffset = rowOffset + x * bpp
                let r = Float(pixels[pixelOffset]) + noise
                let g = Float(pixels[pixelOffset + 1]) + noise
                let b = Float(pixels[pixelOffset + 2]) + noise
                
                pixels[pixelOffset] = UInt8(min(255, max(0, r)))
                pixels[pixelOffset + 1] = UInt8(min(255, max(0, g)))
                pixels[pixelOffset + 2] = UInt8(min(255, max(0, b)))
            }
        }
        
        return UIImage.fromRGBAPixels(&pixels, width: width, height: height) ?? image
    }
}
