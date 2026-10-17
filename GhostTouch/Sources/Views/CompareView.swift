import SwiftUI

/// Màn hình tương tác so sánh ảnh Trước và Sau (Interactive Before/After Slider)
struct CompareView: View {
    let originalImage: UIImage
    let editedImage: UIImage
    
    @State private var splitRatio: CGFloat = 0.5
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                GhostTheme.background.ignoresSafeArea()
                
                GeometryReader { geometry in
                    let width = geometry.size.width
                    let height = geometry.size.height
                    
                    ZStack {
                        // Ảnh Sau khi chỉnh sửa (Lớp nền đầy đủ)
                        Image(uiImage: editedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: width, height: height)
                        
                        // Ảnh Trước (Bị cắt theo vị trí thanh trượt)
                        Image(uiImage: originalImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: width, height: height)
                            .mask(
                                HStack {
                                    Rectangle()
                                        .frame(width: width * splitRatio)
                                    Spacer(minLength: 0)
                                }
                            )
                        
                        // Thanh trượt phân cách thẳng đứng
                        Rectangle()
                            .fill(GhostTheme.cyan)
                            .frame(width: 2)
                            .shadow(color: GhostTheme.cyan, radius: 4)
                            .position(x: width * splitRatio, y: height / 2)
                        
                        // Tay nắm kéo trượt ở giữa
                        Circle()
                            .fill(GhostTheme.cardBackground)
                            .frame(width: 38, height: 38)
                            .overlay(
                                Image(systemName: "chevron.left.chevron.right")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(GhostTheme.cyan)
                            )
                            .overlay(Circle().stroke(GhostTheme.cyan, lineWidth: 2))
                            .shadow(color: .black.opacity(0.5), radius: 6)
                            .position(x: width * splitRatio, y: height / 2)
                            .gesture(
                                DragGesture()
                                    .onChanged { value in
                                        let newRatio = value.location.x / width
                                        splitRatio = min(max(newRatio, 0.05), 0.95)
                                    }
                            )
                        
                        // Nhãn chỉ dẫn Trước / Sau
                        VStack {
                            HStack {
                                Text("GỐC")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.6))
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                                    .padding(.leading, 16)
                                Spacer()
                                Text("ĐÃ TẨY")
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(GhostTheme.cyan.opacity(0.8))
                                    .foregroundColor(.black)
                                    .cornerRadius(6)
                                    .padding(.trailing, 16)
                            }
                            .padding(.top, 16)
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("So Sánh Trước & Sau")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        dismiss()
                    }
                    .foregroundColor(GhostTheme.cyan)
                }
            }
        }
    }
}
