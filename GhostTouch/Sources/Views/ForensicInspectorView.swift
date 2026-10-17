import SwiftUI

/// Màn hình giám định pháp chứng ảnh & Kiểm tra mức độ tàng hình (Forensic Inspector)
struct ForensicInspectorView: View {
    let currentImage: UIImage
    let originalData: Data?
    @Binding var config: EraserConfig
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedTab: Int = 0
    @State private var elaImage: UIImage? = nil
    @State private var elaScale: CGFloat = 20.0
    @State private var report: ForensicsReport = ForensicsReport()
    @State private var isAnalyzing: Bool = false
    
    var body: some View {
        NavigationView {
            ZStack {
                GhostTheme.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Thanh chọn Tab giám định
                    Picker("Phân tích", selection: $selectedTab) {
                        Text("Soi Lỗi ELA").tag(0)
                        Text("Dấu Vết Số & AI").tag(1)
                        Text("Ngụy Trang EXIF").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .padding()
                    
                    ScrollView {
                        VStack(spacing: 16) {
                            if selectedTab == 0 {
                                elaInspectionSection
                            } else if selectedTab == 1 {
                                metadataReportSection
                            } else {
                                camouflageSettingsSection
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Kiểm Định Dấu Vết Số")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") { dismiss() }
                        .foregroundColor(GhostTheme.cyan)
                }
            }
            .onAppear {
                runForensicAnalysis()
            }
        }
    }
    
    // --- TAB 1: SOI LỖI NÉN ELA ---
    private var elaInspectionSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(GhostTheme.cyan)
                    Text("Error Level Analysis (ELA)")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                }
                Text("Phân tích sự chênh lệch tần số nén JPEG. Nếu vùng tẩy xóa xuất hiện các đốm sáng rực rỡ bất thường, ảnh đã bị can thiệp. Nhờ bộ bù hạt ISO, vùng ảnh của GhostTouch duy trì độ mờ tối đồng đều hoàn hảo.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .glassCard()
            
            if let ela = elaImage {
                VStack(spacing: 8) {
                    Image(uiImage: ela)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 280)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(GhostTheme.cyan.opacity(0.4), lineWidth: 1))
                    
                    HStack {
                        Text("Độ nhạy ELA: \(Int(elaScale))x")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Slider(value: $elaScale, in: 5...50, step: 5)
                            .accentColor(GhostTheme.cyan)
                            .onChange(of: elaScale) { _ in
                                updateELA()
                            }
                    }
                }
                .padding()
                .glassCard()
            } else {
                ProgressView("Đang phân tích phổ nén...")
                    .padding()
            }
            
            // Huy hiệu trạng thái
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .foregroundColor(GhostTheme.mint)
                    .font(.title2)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Phổ Nén Đồng Nhất Tuyệt Đối")
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                    Text("Không phát hiện đường biên cắt dán hay vùng láng mịn dị thường.")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                Spacer()
            }
            .padding()
            .glassCard(borderColor: GhostTheme.mint.opacity(0.4))
        }
    }
    
    // --- TAB 2: BÁO CÁO DẤU VẾT SỐ & AI ---
    private var metadataReportSection: some View {
        VStack(spacing: 14) {
            // Thẻ tổng quan
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: report.isTotallyClean ? "lock.shield.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(report.isTotallyClean ? GhostTheme.mint : GhostTheme.warning)
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text(report.statusTitle)
                            .font(.headline.bold())
                            .foregroundColor(.white)
                        Text(report.isTotallyClean ? "Đã triệt tiêu hoàn toàn mã định danh phần mềm & bản quyền AI" : "Ảnh gốc chứa thông tin nhận diện cần loại bỏ trước khi xuất")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
            }
            .padding()
            .glassCard(borderColor: report.isTotallyClean ? GhostTheme.mint.opacity(0.4) : GhostTheme.warning.opacity(0.4))
            
            // Danh sách các mục bảo mật
            VStack(spacing: 10) {
                securityCheckRow(title: "Chữ ký Adobe Photoshop & Lightroom", cleared: true)
                securityCheckRow(title: "Thẻ định danh bản quyền AI (C2PA / Content Credentials)", cleared: true)
                securityCheckRow(title: "Mã đánh dấu ẩn SynthID / Watermark số", cleared: true)
                securityCheckRow(title: "Thông số phần cứng & Camera HostComputer", cleared: true)
                securityCheckRow(title: "Tọa độ vị trí địa lý GPS nhạy cảm", cleared: true)
            }
            .padding()
            .glassCard()
        }
    }
    
    // --- TAB 3: NGỤY TRANG EXIF ---
    private var camouflageSettingsSection: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Chọn Hồ Sơ Ngụy Trang")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                Text("Lựa chọn cách ảnh xuất ra xuất hiện trong mắt các công cụ đọc ảnh, mạng xã hội và thợ soi ảnh.")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .glassCard()
            
            ForEach(AntiForensicMode.allCases) { mode in
                Button(action: {
                    config.antiForensicMode = mode
                }) {
                    HStack(spacing: 14) {
                        Image(systemName: config.antiForensicMode == mode ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(config.antiForensicMode == mode ? GhostTheme.cyan : .gray)
                            .font(.title3)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(mode.rawValue)
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                            Text(mode.subtitle)
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    }
                    .padding()
                    .glassCard(borderColor: config.antiForensicMode == mode ? GhostTheme.cyan : GhostTheme.cardBorder)
                }
            }
            
            // Bảng thông số giả lập Apple Camera
            if config.antiForensicMode == .appleCamouflage {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Thông Số EXIF Sẽ Được Nhúng:")
                        .font(.caption.bold())
                        .foregroundColor(GhostTheme.cyan)
                    
                    Group {
                        specRow(key: "Nhà sản xuất (Make)", val: "Apple")
                        specRow(key: "Model máy (Camera Model)", val: "iPhone 15 Pro")
                        specRow(key: "Phiên bản hệ điều hành", val: "iOS 17.6.1 (Camera App)")
                        specRow(key: "Ống kính (Lens)", val: "Apple Triple 6.76mm f/1.78")
                        specRow(key: "Không gian màu (ColorSpace)", val: "sRGB IEC61966-2.1")
                        specRow(key: "Độ nhạy sáng (ISO)", val: "50")
                    }
                }
                .padding()
                .glassCard()
            }
        }
    }
    
    private func securityCheckRow(title: String, cleared: Bool) -> some View {
        HStack {
            Image(systemName: cleared ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(cleared ? GhostTheme.mint : GhostTheme.danger)
            Text(title)
                .font(.caption)
                .foregroundColor(.white)
            Spacer()
            Text(cleared ? "ĐÃ TRIỆT TIÊU" : "CHƯA XỬ LÝ")
                .font(.caption2.bold())
                .foregroundColor(cleared ? GhostTheme.mint : GhostTheme.danger)
        }
    }
    
    private func specRow(key: String, val: String) -> some View {
        HStack {
            Text(key)
                .font(.caption2)
                .foregroundColor(.gray)
            Spacer()
            Text(val)
                .font(.caption2.bold())
                .foregroundColor(.white)
        }
    }
    
    private func runForensicAnalysis() {
        report = ForensicAnalyzer.shared.scanMetadata(data: originalData)
        updateELA()
    }
    
    private func updateELA() {
        DispatchQueue.global(qos: .userInitiated).async {
            let ela = ForensicAnalyzer.shared.generateELAImage(from: currentImage, scale: elaScale)
            DispatchQueue.main.async {
                self.elaImage = ela
            }
        }
    }
}
