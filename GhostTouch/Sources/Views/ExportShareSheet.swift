import SwiftUI
import Photos

/// Màn hình tùy chọn xuất ảnh không dấu vết và chia sẻ (Export & Share Sheet)
struct ExportShareSheet: View {
    let image: UIImage
    let originalData: Data?
    @Binding var config: EraserConfig
    @Environment(\.dismiss) private var dismiss
    
    @State private var exportFormat: ExportFormatChoice = .jpegHigh
    @State private var isSaving: Bool = false
    @State private var showSuccessMessage: Bool = false
    @State private var shareItem: ShareFileItem? = nil
    
    enum ExportFormatChoice: String, CaseIterable, Identifiable {
        case jpegHigh = "JPEG Siêu Nét (100% Quality)"
        case pngLossless = "PNG Nguyên Bản (Lossless)"
        
        var id: String { self.rawValue }
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                GhostTheme.background.ignoresSafeArea()
                
                VStack(spacing: 20) {
                    // Xem trước ảnh xuất
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 240)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GhostTheme.cyan.opacity(0.5), lineWidth: 1))
                        .shadow(color: GhostTheme.cyan.opacity(0.2), radius: 10)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 14) {
                        Text("Định Dạng Tệp")
                            .font(.subheadline.bold())
                            .foregroundColor(.white)
                        
                        Picker("Định dạng", selection: $exportFormat) {
                            ForEach(ExportFormatChoice.allCases) { choice in
                                Text(choice.rawValue).tag(choice)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        // Thông báo chế độ bảo mật đang bật
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(GhostTheme.mint)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Chế độ bảo mật:")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                                Text(config.antiForensicMode.rawValue)
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .glassCard(borderColor: GhostTheme.mint.opacity(0.4))
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    // Nút Hành Động: Lưu vào Thư Viện hoặc Chia Sẻ
                    VStack(spacing: 12) {
                        Button(action: saveToPhotoLibrary) {
                            HStack(spacing: 8) {
                                if isSaving {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                } else {
                                    Image(systemName: "arrow.down.to.line.circle.fill")
                                        .font(.title3)
                                }
                                Text(isSaving ? "Đang xử lý & lưu..." : "Lưu Vào Album Ảnh (Zero-Trace)")
                                    .font(.headline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 15)
                            .background(GhostTheme.laserGradient)
                            .foregroundColor(.black)
                            .cornerRadius(16)
                            .shadow(color: GhostTheme.cyan.opacity(0.4), radius: 8, y: 4)
                        }
                        .disabled(isSaving)
                        
                        Button(action: prepareShareItem) {
                            HStack(spacing: 8) {
                                Image(systemName: "square.and.arrow.up")
                                    .font(.subheadline.bold())
                                Text("Chia Sẻ Qua AirDrop / Tệp / Tin Nhắn")
                                    .font(.subheadline.bold())
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(GhostTheme.cardBackground)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(GhostTheme.cardBorder, lineWidth: 1))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Xuất Ảnh Vô Vết")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") { dismiss() }
                        .foregroundColor(GhostTheme.cyan)
                }
            }
            .alert("Đã Lưu Thành Công!", isPresented: $showSuccessMessage) {
                Button("OK") { dismiss() }
            } message: {
                Text("Ảnh đã được xử lý và lưu an toàn vào Album của bạn. Toàn bộ dấu vết chỉnh sửa và AI đã được triệt tiêu hoàn toàn!")
            }
            .sheet(item: $shareItem) { item in
                ActivityViewController(activityItems: [item.fileURL])
            }
        }
    }
    
    private func saveToPhotoLibrary() {
        isSaving = true
        DispatchQueue.global(qos: .userInitiated).async {
            let format: ExportFormat = (exportFormat == .pngLossless) ? .png : .jpeg(quality: 1.0)
            guard let data = ZeroTraceSanitizer.shared.sanitizeAndExport(
                image: image,
                mode: config.antiForensicMode,
                originalData: originalData,
                format: format
            ) else {
                DispatchQueue.main.async { isSaving = false }
                return
            }
            
            // Lưu trực tiếp file data sạch vào Photo Library để giữ trọn vẹn EXIF đã ngụy trang
            PHPhotoLibrary.requestAuthorization { status in
                if status == .authorized || status == .limited {
                    PHPhotoLibrary.shared().performChanges({
                        let creationRequest = PHAssetCreationRequest.forAsset()
                        creationRequest.addResource(with: .photo, data: data, options: nil)
                    }) { success, error in
                        DispatchQueue.main.async {
                            self.isSaving = false
                            if success {
                                self.showSuccessMessage = true
                            }
                        }
                    }
                } else {
                    DispatchQueue.main.async { self.isSaving = false }
                }
            }
        }
    }
    
    private func prepareShareItem() {
        let format: ExportFormat = (exportFormat == .pngLossless) ? .png : .jpeg(quality: 1.0)
        guard let data = ZeroTraceSanitizer.shared.sanitizeAndExport(
            image: image,
            mode: config.antiForensicMode,
            originalData: originalData,
            format: format
        ) else { return }
        
        let filename = (exportFormat == .pngLossless) ? "IMG_GhostTouch.png" : "IMG_GhostTouch.jpg"
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: tempURL)
        
        self.shareItem = ShareFileItem(fileURL: tempURL)
    }
}

struct ShareFileItem: Identifiable {
    let id = UUID()
    let fileURL: URL
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
