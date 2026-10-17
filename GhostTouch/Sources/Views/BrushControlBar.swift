import SwiftUI

/// Thanh công cụ điều khiển cọ vẽ, kích thước và kích hoạt tẩy ảnh
struct BrushControlBar: View {
    @Binding var config: EraserConfig
    @Binding var isPanZoomEnabled: Bool
    var hasStrokes: Bool
    var isProcessing: Bool
    var onErase: () -> Void
    var onClearMask: () -> Void
    
    @State private var showAdvancedSettings = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Hàng 1: Nút chuyển chế độ Pan/Zoom & Thanh trượt kích thước cọ
            HStack(spacing: 16) {
                // Nút chuyển giữa Vẽ Cọ và Di chuyển/Phóng to
                Button(action: {
                    isPanZoomEnabled.toggle()
                }) {
                    Image(systemName: isPanZoomEnabled ? "hand.draw.fill" : "paintbrush.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(isPanZoomEnabled ? GhostTheme.cyan : .white)
                        .padding(10)
                        .background(isPanZoomEnabled ? GhostTheme.cyan.opacity(0.2) : GhostTheme.cardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(isPanZoomEnabled ? GhostTheme.cyan : GhostTheme.cardBorder, lineWidth: 1))
                }
                
                // Xem trước vòng tròn kích thước cọ
                Circle()
                    .fill(GhostTheme.cyan)
                    .frame(width: max(8, min(config.brushSize * 0.45, 32)), height: max(8, min(config.brushSize * 0.45, 32)))
                    .frame(width: 36, height: 36)
                
                // Slider kích thước cọ
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text("Cỡ cọ")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(Int(config.brushSize)) px")
                            .font(.caption2.bold())
                            .foregroundColor(GhostTheme.cyan)
                    }
                    Slider(value: $config.brushSize, in: 6...90, step: 1)
                        .accentColor(GhostTheme.cyan)
                }
                
                // Nút mở cấu hình nâng cao
                Button(action: { showAdvancedSettings.toggle() }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(showAdvancedSettings ? GhostTheme.mint : .white)
                        .padding(10)
                        .background(GhostTheme.cardBackground)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(showAdvancedSettings ? GhostTheme.mint : GhostTheme.cardBorder, lineWidth: 1))
                }
            }
            
            // Hàng nâng cao (Thuật toán & Hạt cảm biến)
            if showAdvancedSettings {
                VStack(spacing: 8) {
                    Picker("Thuật toán", selection: $config.inpaintingMode) {
                        ForEach(InpaintingMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        Toggle(isOn: $config.enableSensorGrainInjection) {
                            HStack(spacing: 6) {
                                Image(systemName: "camera.aperture")
                                    .foregroundColor(GhostTheme.mint)
                                Text("Bù hạt cảm biến ISO (Chống soi AI)")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: GhostTheme.mint))
                    }
                }
                .padding(10)
                .glassCard(cornerRadius: 12)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
            
            // Hàng 2: Nút Xóa Mask & Nút Kích hoạt Tẩy ảnh
            HStack(spacing: 12) {
                if hasStrokes {
                    Button(action: onClearMask) {
                        HStack(spacing: 6) {
                            Image(systemName: "trash")
                            Text("Xóa nét")
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.gray)
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(GhostTheme.cardBackground)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(GhostTheme.cardBorder, lineWidth: 1))
                    }
                }
                
                Button(action: onErase) {
                    HStack(spacing: 8) {
                        if isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                            Text("Đang phân giải...")
                                .font(.headline.bold())
                                .foregroundColor(.black)
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.headline)
                            Text("Tẩy Ngay (Ghost Erase)")
                                .font(.headline.bold())
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        hasStrokes && !isProcessing ?
                            GhostTheme.laserGradient :
                            LinearGradient(colors: [Color.gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                    )
                    .foregroundColor(hasStrokes && !isProcessing ? .black : .gray)
                    .cornerRadius(14)
                    .shadow(
                        color: hasStrokes && !isProcessing ? GhostTheme.cyan.opacity(0.4) : .clear,
                        radius: 8, x: 0, y: 4
                    )
                }
                .disabled(!hasStrokes || isProcessing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassCard(cornerRadius: 20)
    }
}
