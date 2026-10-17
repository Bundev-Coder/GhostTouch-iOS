import SwiftUI

/// Thẻ báo cáo giám định AI, nhận diện nội dung ảnh và nút kích hoạt Làm Sạch Vô Vết (1-Click Deep Clean)
struct AIDiagnosticCardView: View {
    let report: ForensicsReport
    var isAnalyzing: Bool
    var onPerformDeepClean: () -> Void
    
    @State private var isExpanded: Bool = false
    
    var body: some View {
        VStack(spacing: 12) {
            // Hàng tóm tắt đầu thẻ
            HStack(spacing: 12) {
                // Vòng tròn điểm số AI / Trạng thái
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.1), lineWidth: 4)
                        .frame(width: 46, height: 46)
                    
                    if isAnalyzing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: GhostTheme.cyan))
                    } else {
                        Circle()
                            .trim(from: 0, to: CGFloat(report.aiProbability) / 100.0)
                            .stroke(
                                report.isTotallyClean ? GhostTheme.mint :
                                    (report.aiProbability >= 70 ? GhostTheme.danger : GhostTheme.warning),
                                style: StrokeStyle(lineWidth: 4, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 46, height: 46)
                        
                        Text(report.isTotallyClean ? "0%" : "\(report.aiProbability)%")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(
                                report.isTotallyClean ? GhostTheme.mint :
                                    (report.aiProbability >= 70 ? GhostTheme.danger : GhostTheme.warning)
                            )
                    }
                }
                
                // Nội dung tóm tắt
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(report.statusTitle)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        
                        if report.isCleaned {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(GhostTheme.mint)
                                .font(.caption)
                        }
                    }
                    
                    Text(report.aiVerdict)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Nút mở rộng xem chi tiết
                Button(action: { withAnimation(.spring()) { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                        .foregroundColor(GhostTheme.cyan)
                        .font(.title3)
                }
            }
            
            // Nội dung mở rộng chi tiết giám định
            if isExpanded {
                VStack(spacing: 10) {
                    Divider().background(GhostTheme.cardBorder)
                    
                    // 1. Nhận diện nội dung bức ảnh (Apple Vision)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundColor(GhostTheme.cyan)
                                .font(.caption)
                            Text("Nội dung bức ảnh (Vision AI):")
                                .font(.caption2.bold())
                                .foregroundColor(.gray)
                        }
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(report.detectedContentTags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(GhostTheme.cyan.opacity(0.15))
                                        .foregroundColor(GhostTheme.cyan)
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(GhostTheme.cyan.opacity(0.3), lineWidth: 1))
                                }
                            }
                        }
                    }
                    
                    // 2. Các phần mềm & Công cụ AI phát hiện
                    if !report.detectedSoftwares.isEmpty || !report.detectedAIEngines.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Image(systemName: "cpu.fill")
                                    .foregroundColor(GhostTheme.danger)
                                    .font(.caption)
                                Text("Phát hiện công cụ can thiệp:")
                                    .font(.caption2.bold())
                                    .foregroundColor(.gray)
                            }
                            
                            HStack(spacing: 6) {
                                ForEach(report.detectedSoftwares + report.detectedAIEngines, id: \.self) { tool in
                                    Text(tool)
                                        .font(.caption2.bold())
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(GhostTheme.danger.opacity(0.2))
                                        .foregroundColor(GhostTheme.danger)
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                    
                    // 3. Chi tiết bất thường quang học
                    if !report.aiArtifactDetails.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(report.aiArtifactDetails.prefix(3), id: \.self) { detail in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.circle")
                                        .font(.caption2)
                                        .foregroundColor(GhostTheme.warning)
                                        .padding(.top, 2)
                                    Text(detail)
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
            
            // Nút Thần Thánh: "⚡ LÀM SẠCH VÔ VẾT (1-CLICK DEEP CLEAN)"
            if !report.isCleaned {
                Button(action: onPerformDeepClean) {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .font(.headline)
                        Text("LÀM SẠCH VÔ VẾT (1-Click Deep Clean)")
                            .font(.subheadline.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(GhostTheme.laserGradient)
                    .foregroundColor(.black)
                    .cornerRadius(12)
                    .shadow(color: GhostTheme.cyan.opacity(0.4), radius: 6, y: 2)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                        .foregroundColor(GhostTheme.mint)
                    Text("Ảnh đã được khử 100% dấu vết AI & Ngụy trang Apple Camera")
                        .font(.caption2.bold())
                        .foregroundColor(GhostTheme.mint)
                }
                .padding(.vertical, 6)
            }
        }
        .padding(14)
        .glassCard(borderColor: report.isTotallyClean ? GhostTheme.mint.opacity(0.4) : GhostTheme.cardBorder)
    }
}
