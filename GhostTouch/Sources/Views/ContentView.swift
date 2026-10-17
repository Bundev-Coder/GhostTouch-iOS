import SwiftUI
import PhotosUI

/// Màn hình chính điều phối toàn bộ luồng làm việc của GhostTouch Studio
struct ContentView: View {
    @StateObject private var historyManager = EditHistoryManager()
    @State private var config = EraserConfig()
    
    // Quản lý ảnh
    @State private var currentImage: UIImage? = nil
    @State private var originalData: Data? = nil
    
    // Nét vẽ Mask tẩy xóa
    @State private var strokes: [MaskStroke] = []
    @State private var currentStroke: MaskStroke? = nil
    @State private var isPanZoomEnabled: Bool = false
    @State private var isProcessing: Bool = false
    
    // Quản lý các Modal / Sheets
    @State private var showPhotoPicker: Bool = false
    @State private var showCameraPicker: Bool = false
    @State private var showCompareSheet: Bool = false
    @State private var showInspectorSheet: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    var body: some View {
        ZStack {
            GhostTheme.background.ignoresSafeArea()
            
            if let image = currentImage {
                // --- TRẠNG THÁI ĐANG CHỈNH SỬA ẢNH ---
                VStack(spacing: 0) {
                    // Thanh điều hướng trên cùng (Top Navigation Bar)
                    topEditorToolbar
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .background(GhostTheme.background.opacity(0.95))
                    
                    // Khung Canvas chỉnh sửa chính
                    ZStack {
                        CanvasEditorView(
                            sourceImage: image,
                            strokes: $strokes,
                            currentStroke: $currentStroke,
                            brushSize: config.brushSize,
                            isPanZoomEnabled: isPanZoomEnabled
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    // Thanh công cụ cọ vẽ & Tẩy xóa dưới cùng
                    BrushControlBar(
                        config: $config,
                        isPanZoomEnabled: $isPanZoomEnabled,
                        hasStrokes: !strokes.isEmpty || currentStroke != nil,
                        isProcessing: isProcessing,
                        onErase: performInpaint,
                        onClearMask: {
                            strokes.removeAll()
                            currentStroke = nil
                        }
                    )
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
                }
            } else {
                // --- TRẠNG THÁI CHƯA CHỌN ẢNH (WELCOME HERO) ---
                welcomeHeroView
            }
        }
        .sheet(isPresented: $showCompareSheet) {
            if let initial = historyManager.initialImage, let current = currentImage {
                CompareView(originalImage: initial, editedImage: current)
            }
        }
        .sheet(isPresented: $showInspectorSheet) {
            if let current = currentImage {
                ForensicInspectorView(currentImage: current, originalData: originalData, config: $config)
            }
        }
        .sheet(isPresented: $showExportSheet) {
            if let current = currentImage {
                ExportShareSheet(image: current, originalData: originalData, config: $config)
            }
        }
        .photosPicker(isPresented: $showPhotoPicker, selection: $selectedPhotoItem, matching: .images)
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        self.originalData = data
                        self.loadImage(uiImage)
                    }
                }
            }
        }
    }
    
    // --- TOP TOOLBAR ---
    private var topEditorToolbar: some View {
        HStack(spacing: 12) {
            // Nút Đổi ảnh
            Button(action: { showPhotoPicker = true }) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(GhostTheme.cardBackground)
                    .clipShape(Circle())
            }
            
            // Undo & Redo
            HStack(spacing: 8) {
                Button(action: performUndo) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(historyManager.canUndo ? GhostTheme.cyan : .gray.opacity(0.4))
                }
                .disabled(!historyManager.canUndo)
                
                Button(action: performRedo) {
                    Image(systemName: "arrow.uturn.forward")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(historyManager.canRedo ? GhostTheme.cyan : .gray.opacity(0.4))
                }
                .disabled(!historyManager.canRedo)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .glassCard(cornerRadius: 20)
            
            Spacer()
            
            // Nút So Sánh Trước / Sau
            if historyManager.canUndo {
                Button(action: { showCompareSheet = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "rectangle.split.2x1")
                        Text("So sánh")
                            .font(.caption.bold())
                    }
                    .foregroundColor(GhostTheme.mint)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .glassCard(cornerRadius: 14, borderColor: GhostTheme.mint.opacity(0.4))
                }
            }
            
            // Nút Soi Dấu Vết (Forensic Inspector)
            Button(action: { showInspectorSheet = true }) {
                Image(systemName: "shield.checkerboard")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(GhostTheme.cyan)
                    .padding(8)
                    .background(GhostTheme.cardBackground)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(GhostTheme.cyan.opacity(0.5), lineWidth: 1))
            }
            
            // Nút Xuất Ảnh (Export)
            Button(action: { showExportSheet = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                    Text("Xuất")
                        .font(.caption.bold())
                }
                .foregroundColor(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(GhostTheme.laserGradient)
                .cornerRadius(14)
                .shadow(color: GhostTheme.cyan.opacity(0.4), radius: 6)
            }
        }
    }
    
    // --- MÀN HÌNH CHÀO MỪNG / HERO VIEW ---
    private var welcomeHeroView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Logo Hologram phát sáng
            ZStack {
                Circle()
                    .fill(GhostTheme.laserGradient.opacity(0.2))
                    .frame(width: 140, height: 140)
                    .blur(radius: 20)
                
                Image(systemName: "wand.and.rays.inverse")
                    .font(.system(size: 60, weight: .light))
                    .foregroundStyle(GhostTheme.laserGradient)
            }
            
            VStack(spacing: 8) {
                Text("GhostTouch")
                    .font(.system(size: 34, weight: .heavy))
                    .foregroundColor(.white)
                
                Text("Tẩy Ảnh Không Dấu Vết & Khử Dấu Ấn AI")
                    .font(.subheadline)
                    .foregroundColor(GhostTheme.cyan)
                
                Text("Xóa sạch vật thể, người thừa, logo và văn bản trực tiếp trên iPhone. Tự động tái tạo hạt cảm biến ISO máy ảnh, triệt tiêu 100% metadata & chữ ký phần mềm chỉnh sửa.")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .lineSpacing(3)
            }
            
            VStack(spacing: 12) {
                Button(action: { showPhotoPicker = true }) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.fill.on.rectangle.fill")
                            .font(.headline)
                        Text("Chọn Ảnh Từ Album")
                            .font(.headline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(GhostTheme.laserGradient)
                    .foregroundColor(.black)
                    .cornerRadius(16)
                    .shadow(color: GhostTheme.cyan.opacity(0.4), radius: 8, y: 4)
                }
                
                Button(action: loadDemoSamplePhoto) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundColor(GhostTheme.mint)
                        Text("Thử Nghiệm Ảnh Mẫu (1-Click)")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(GhostTheme.cardBackground)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(GhostTheme.cardBorder, lineWidth: 1))
                }
            }
            .padding(.horizontal, 28)
            
            // Tính năng nổi bật
            HStack(spacing: 20) {
                featureBadge(icon: "shield.slash.fill", text: "Zero Trace")
                featureBadge(icon: "camera.aperture", text: "ISO Grain")
                featureBadge(icon: "lock.shield.fill", text: "100% On-Device")
            }
            .padding(.top, 8)
            
            Spacer()
        }
    }
    
    private func featureBadge(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(GhostTheme.cyan)
            Text(text)
                .font(.caption2.bold())
                .foregroundColor(.gray)
        }
    }
    
    // --- CÁC HÀM XỬ LÝ LOGIC ---
    private func loadImage(_ image: UIImage) {
        self.currentImage = image
        self.historyManager.reset(initialImage: image)
        self.strokes.removeAll()
        self.currentStroke = nil
    }
    
    private func performInpaint() {
        guard let image = currentImage, !strokes.isEmpty else { return }
        isProcessing = true
        
        let targetSize = CGSize(width: image.size.width, height: image.size.height)
        let canvasSize = UIScreen.main.bounds.size
        let maskImage = CanvasEditorView.renderMaskImage(
            strokes: strokes,
            targetSize: targetSize,
            canvasSize: canvasSize
        )
        
        InpaintingEngine.shared.processInpaint(
            sourceImage: image,
            maskImage: maskImage,
            mode: config.inpaintingMode
        ) { result in
            guard var finalResult = result else {
                self.isProcessing = false
                return
            }
            
            // Tái tạo hạt cảm biến ISO nếu bật
            if self.config.enableSensorGrainInjection {
                finalResult = SensorNoiseInjector.shared.injectSensorNoise(
                    to: finalResult,
                    mask: maskImage,
                    intensity: self.config.grainIntensity
                )
            }
            
            self.currentImage = finalResult
            self.historyManager.push(newImage: finalResult, actionName: "Tẩy xóa vật thể")
            self.strokes.removeAll()
            self.currentStroke = nil
            self.isProcessing = false
        }
    }
    
    private func performUndo() {
        if let previous = historyManager.undo() {
            self.currentImage = previous
            self.strokes.removeAll()
            self.currentStroke = nil
        }
    }
    
    private func performRedo() {
        if let next = historyManager.redo() {
            self.currentImage = next
            self.strokes.removeAll()
            self.currentStroke = nil
        }
    }
    
    /// Tạo ảnh mẫu để người dùng thử nghiệm ngay lập tức không cần chọn ảnh
    private func loadDemoSamplePhoto() {
        let size = CGSize(width: 800, height: 1000)
        let renderer = UIGraphicsImageRenderer(size: size)
        let demo = renderer.image { ctx in
            let cg = ctx.cgContext
            // Nền gradient hoàng hôn
            let colors = [
                UIColor(red: 0.15, green: 0.20, blue: 0.35, alpha: 1.0).cgColor,
                UIColor(red: 0.85, green: 0.45, blue: 0.35, alpha: 1.0).cgColor
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
                cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: 1000), options: [])
            }
            
            // Vẽ vật thể mẫu (ví dụ logo / văn bản / watermark cần tẩy)
            let text = "SAMPLE WATERMARK © 2026"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.85)
            ]
            (text as NSString).draw(at: CGPoint(x: 160, y: 460), withAttributes: attrs)
        }
        
        self.originalData = demo.jpegData(compressionQuality: 0.95)
        self.loadImage(demo)
    }
}
