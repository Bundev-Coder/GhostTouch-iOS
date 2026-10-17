import SwiftUI

/// Hệ thống màu sắc và giao diện chuẩn Dark Glassmorphism cho GhostTouch iOS
enum GhostTheme {
    // Nền tối obsidian cao cấp
    static let background = Color(red: 0.04, green: 0.05, blue: 0.08)
    static let cardBackground = Color(red: 0.08, green: 0.10, blue: 0.15)
    static let cardBorder = Color(red: 0.16, green: 0.20, blue: 0.29)
    static let glassOverlay = Color.white.opacity(0.06)
    
    // Màu nhấn Holographic / Neon Cyber
    static let cyan = Color(red: 0.00, green: 0.95, blue: 1.00)
    static let violet = Color(red: 0.61, green: 0.32, blue: 0.88)
    static let mint = Color(red: 0.02, green: 1.00, blue: 0.63)
    static let warning = Color(red: 1.00, green: 0.76, blue: 0.03)
    static let danger = Color(red: 1.00, green: 0.27, blue: 0.38)
    
    // Gradient ánh sáng
    static let laserGradient = LinearGradient(
        colors: [cyan, violet],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let stealthGradient = LinearGradient(
        colors: [Color(red: 0.12, green: 0.16, blue: 0.24), Color(red: 0.06, green: 0.08, blue: 0.12)],
        startPoint: .top,
        endPoint: .bottom
    )
}

struct GlassCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 16
    var borderColor: Color = GhostTheme.cardBorder
    
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(GhostTheme.cardBackground.opacity(0.85))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(borderColor, lineWidth: 1)
                    )
            )
    }
}

extension View {
    func glassCard(cornerRadius: CGFloat = 16, borderColor: Color = GhostTheme.cardBorder) -> some View {
        self.modifier(GlassCardModifier(cornerRadius: cornerRadius, borderColor: borderColor))
    }
}
