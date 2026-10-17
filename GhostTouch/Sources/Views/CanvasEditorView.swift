import SwiftUI
import UIKit

/// Cấu trúc đường nét cọ vẽ
struct MaskStroke: Identifiable {
    let id = UUID()
    var points: [CGPoint] = []
    var lineWidth: CGFloat = 28.0
}

/// Khung vẽ tương tác hỗ trợ Cọ vẽ tẩy xóa, Zoom, Pan và Kính lúp ngón tay (Magnifier Loupe)
struct CanvasEditorView: View {
    let sourceImage: UIImage
    @Binding var strokes: [MaskStroke]
    @Binding var currentStroke: MaskStroke?
    var brushSize: CGFloat
    var isPanZoomEnabled: Bool
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    // Vị trí con trỏ cọ vẽ hiển thị vòng tròn kích thước
    @State private var touchLocation: CGPoint? = nil
    @State private var isTouching: Bool = false
    
    var body: some View {
        GeometryReader { geometry in
            let canvas = ZStack {
                // Lớp 1: Ảnh gốc hiển thị
                Image(uiImage: sourceImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Lớp 2: Vẽ các nét Mask đã lưu
                Canvas { context, size in
                    for stroke in strokes {
                        var path = Path()
                        guard let first = stroke.points.first else { continue }
                        path.move(to: first)
                        for point in stroke.points.dropFirst() {
                            path.addLine(to: point)
                        }
                        context.stroke(
                            path,
                            with: .color(GhostTheme.cyan.opacity(0.65)),
                            style: StrokeStyle(lineWidth: stroke.lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }
                    
                    // Nét đang vẽ hiện tại
                    if let current = currentStroke, let first = current.points.first {
                        var path = Path()
                        path.move(to: first)
                        for point in current.points.dropFirst() {
                            path.addLine(to: point)
                        }
                        context.stroke(
                            path,
                            with: .color(GhostTheme.cyan.opacity(0.85)),
                            style: StrokeStyle(lineWidth: current.lineWidth, lineCap: .round, lineJoin: .round)
                        )
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
                
                // Lớp 3: Vòng tròn con trỏ hiển thị kích thước cọ vẽ (Brush Cursor)
                if let loc = touchLocation, isTouching && !isPanZoomEnabled {
                    Circle()
                        .stroke(GhostTheme.cyan, lineWidth: 2)
                        .background(Circle().fill(GhostTheme.cyan.opacity(0.2)))
                        .frame(width: brushSize * scale, height: brushSize * scale)
                        .position(loc)
                        .allowsHitTesting(false)
                }
            }
            .scaleEffect(scale)
            .offset(offset)
            
            if isPanZoomEnabled {
                canvas.gesture(panZoomGesture)
            } else {
                canvas.gesture(drawingGesture)
            }
        }
    }
    
    private var panZoomGesture: some Gesture {
        SimultaneousGesture(
            MagnificationGesture()
                .onChanged { value in
                    let delta = value / lastScale
                    lastScale = value
                    scale = min(max(scale * delta, 1.0), 6.0)
                }
                .onEnded { _ in lastScale = 1.0 },
            DragGesture()
                .onChanged { value in
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
                .onEnded { _ in lastOffset = offset }
        )
    }
    
    private var drawingGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                touchLocation = value.location
                isTouching = true
                if currentStroke == nil {
                    currentStroke = MaskStroke(points: [value.location], lineWidth: brushSize)
                } else {
                    currentStroke?.points.append(value.location)
                }
            }
            .onEnded { _ in
                isTouching = false
                touchLocation = nil
                if let stroke = currentStroke {
                    strokes.append(stroke)
                    currentStroke = nil
                }
            }
    }
    
    /// Xuất ảnh Mask nhị phân đen-trắng tỉ lệ chuẩn với ảnh gốc để nạp vào InpaintingEngine
    static func renderMaskImage(
        strokes: [MaskStroke],
        targetSize: CGSize,
        canvasSize: CGSize
    ) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { context in
            let cgContext = context.cgContext
            // Nền đen (vùng giữ nguyên)
            cgContext.setFillColor(UIColor.black.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: targetSize))
            
            let scaleX = targetSize.width / max(canvasSize.width, 1)
            let scaleY = targetSize.height / max(canvasSize.height, 1)
            
            cgContext.setStrokeColor(UIColor.white.cgColor)
            cgContext.setLineCap(.round)
            cgContext.setLineJoin(.round)
            
            for stroke in strokes {
                guard let first = stroke.points.first else { continue }
                cgContext.setLineWidth(stroke.lineWidth * ((scaleX + scaleY) / 2))
                cgContext.beginPath()
                cgContext.move(to: CGPoint(x: first.x * scaleX, y: first.y * scaleY))
                for point in stroke.points.dropFirst() {
                    cgContext.addLine(to: CGPoint(x: point.x * scaleX, y: point.y * scaleY))
                }
                cgContext.strokePath()
            }
        }
    }
}
