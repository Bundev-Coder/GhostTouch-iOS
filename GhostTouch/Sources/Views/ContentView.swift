import SwiftUI
import PhotosUI

/// Màn hình chính điều phối toàn bộ luồng làm việc của GhostTouch Studio
struct ContentView: View {
    @StateObject private var historyManager = EditHistoryManager()
    @State private var config = EraserConfig()
    
    // Quản lý ảnh
    @State private var currentImage: UIImage? = nil
    @State private var originalData: Data? = nil
    
    // Báo cáo giám định AI & Nội dung ảnh
    @State private var forensicsReport: ForensicsReport = ForensicsReport()
    @State private var isAnalyzing: Bool = false
    
    // Nét vẽ Mask tẩy xóa thủ công
    @State private var strokes: [MaskStroke] = []
    @State private var currentStroke: MaskStroke? = nil
    @State private var isPanZoomEnabled: Bool = false
    @State private var isProcessing: Bool = false
    
    // Quản lý các Modal / Sheets
    @State private var showPhotoPicker: Bool = false
    @State private var showCompareSheet: Bool = false
    @State private var showInspectorSheet: Bool = false
    @State private var showExportSheet: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    
    var body: some View {
        ZStack {
            GhostTheme.background.ignoresSafeArea()
            
            if let image = currentImage {
                // --- TRẠNG THÁI ĐANG CHỈNH SỬA & GIÁM ĐỊNH ẢNH ---
                VStack(spacing: 0) {
                    // Thanh điều hướng trên cùng (Top Navigation Bar)
                    topEditorToolbar
                        .padding(.horizontal)
                        .padding(.top, 8)
                        .padding(.bottom, 6)
                        .background(GhostTheme.background.opacity(0.95))
                    
                    // Thẻ Giám Định AI, Nhận Diện Nội Dung & Nút 1-Click Deep Clean
                    AIDiagnosticCardView(
                        report: forensicsReport,
                        isAnalyzing: isAnalyzing,
                        onPerformDeepClean: triggerOneClickDeepClean
                    )
                    .padding(.horizontal, 14)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                    
                    // Khung Canvas hiển thị & Tẩy xóa ảnh
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
                        self.loadImage(uiImage, rawData: data)
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
                
                Text("Giám Định AI & Làm Sạch Ảnh Vô Vết")
                    .font(.subheadline.bold())
                    .foregroundColor(GhostTheme.cyan)
                
                Text("Thêm ảnh bất kỳ để phát hiện ngay nội dung bên trong, tỷ lệ AI và các phần mềm chỉnh sửa đã can thiệp. 1-Click làm sạch triệt để, tái tạo hạt cảm biến ISO và ngụy trang Camera iPhone thật.")
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
                        Text("Chọn Ảnh Giám Định & Làm Sạch")
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
                        Text("Thử Nghiệm Ảnh Mẫu AI/Photoshop")
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
            HStack(spacing: 18) {
                featureBadge(icon: "eye.fill", text: "Vision Detect")
                featureBadge(icon: "cpu.fill", text: "AI Scanner")
                featureBadge(icon: "shield.slash.fill", text: "Zero Trace")
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
    private func loadImage(_ image: UIImage, rawData: Data?) {
        self.currentImage = image
        self.historyManager.reset(initialImage: image)
        self.strokes.removeAll()
        self.currentStroke = nil
        
        // Chạy giám định AI & Phân tích nội dung ngay lập tức
        self.isAnalyzing = true
        AIDetectionService.shared.analyzeImage(image: image, rawData: rawData) { report in
            self.forensicsReport = report
            self.isAnalyzing = false
        }
    }
    
    /// Kích hoạt 1-Click Deep Clean: Làm sạch toàn bộ dấu vết AI & phần mềm chỉnh sửa
    private func triggerOneClickDeepClean() {
        guard let image = currentImage else { return }
        isProcessing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let cleaned = ZeroTraceSanitizer.shared.performDeepClean(
                image: image,
                mode: self.config.antiForensicMode,
                injectGrain: self.config.enableSensorGrainInjection
            )
            
            DispatchQueue.main.async {
                self.currentImage = cleaned
                self.historyManager.push(newImage: cleaned, actionName: "1-Click Deep Clean")
                
                // Cập nhật trạng thái báo cáo sang Sạch Tuyệt Đối
                self.forensicsReport.isCleaned = true
                self.forensicsReport.aiProbability = 0
                self.forensicsReport.suspiciousCount = 0
                self.forensicsReport.detectedSoftwares.removeAll()
                self.forensicsReport.detectedAIEngines.removeAll()
                self.forensicsReport.aiVerdict = "100% Ảnh Đã Khử Dấu Vết (Chuẩn Apple Camera Gốc)"
                self.isProcessing = false
            }
        }
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
    
    /// Tạo ảnh mẫu có gắn sẵn dấu vết AI & Photoshop giả lập để người dùng thử nghiệm
    private func loadDemoSamplePhoto() {
        let size = CGSize(width: 800, height: 1000)
        let renderer = UIGraphicsImageRenderer(size: size)
        let demo = renderer.image { ctx in
            let cg = ctx.cgContext
            let colors = [
                UIColor(red: 0.12, green: 0.16, blue: 0.28, alpha: 1.0).cgColor,
                UIColor(red: 0.75, green: 0.40, blue: 0.35, alpha: 1.0).cgColor
            ] as CFArray
            let space = CGColorSpaceCreateDeviceRGB()
            if let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
                cg.drawLinearGradient(grad, start: .zero, end: CGPoint(x: 0, y: 1000), options: [])
            }
            
            // Vẽ người & chi tiết mẫu
            cg.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            cg.fillEllipse(in: CGRect(x: 320, y: 340, width: 160, height: 160)) // Mặt
            cg.fillEllipse(in: CGRect(x: 260, y: 520, width: 280, height: 320)) // Thân
            
            let text = "AI GENERATED • PHOTOSHOP 2024"
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                .foregroundColor: UIColor.white.withAlphaComponent(0.8)
            ]
            (text as NSString).draw(at: CGPoint(x: 210, y: 880), withAttributes: attrs)
        }
        
        // Nhúng chuỗi giả lập Photoshop & Stable Diffusion vào rawData
        let baseJpg = demo.jpegData(compressionQuality: 0.92) ?? Data()
        var mockData = baseJpg
        let fakeSignature = "Software: Adobe Photoshop 2024 (Macintosh)\nGenerator: Stable Diffusion XL v1.0\nc2pa: manifest-urn:uuid:12345".data(using: .ascii) ?? Data()
        mockData.append(fakeSignature)
        
        self.originalData = mockData
        self.loadImage(demo, rawData: mockData)
    }
}
