import UIKit
import CoreGraphics
import CoreImage
import Accelerate

extension UIImage {
    /// Chuyển đổi UIImage sang kích thước tối ưu nếu ảnh quá lớn để đảm bảo tốc độ inpainting 60fps
    func resized(maxDimension: CGFloat) -> UIImage {
        let size = self.size
        let maxSide = max(size.width, size.height)
        guard maxSide > maxDimension else { return self }
        
        let ratio = maxDimension / maxSide
        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    
    /// Chuyển đổi sang ảnh thang độ xám (Grayscale mask)
    func toGrayscale() -> UIImage? {
        guard let ciImage = CIImage(image: self) else { return nil }
        let filter = CIFilter(name: "CIColorControls")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(0.0, forKey: kCIInputSaturationKey)
        
        guard let outputCI = filter?.outputImage else { return nil }
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(outputCI, from: outputCI.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
    
    /// Lấy mảng byte dữ liệu pixel RGBA
    func extractRGBAPixels() -> (pixels: [UInt8], width: Int, height: Int)? {
        guard let cgImage = self.cgImage else { return nil }
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let totalBytes = bytesPerRow * height
        
        var rawData = [UInt8](repeating: 0, count: totalBytes)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (rawData, width, height)
    }
    
    /// Tạo UIImage từ mảng byte dữ liệu pixel RGBA
    static func fromRGBAPixels(_ pixels: inout [UInt8], width: Int, height: Int) -> UIImage? {
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        guard let cgImage = context.makeImage() else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
