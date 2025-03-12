import SwiftUI

// MARK: - 颜色扩展
extension Color {
    // 主要颜色
    static let babyBlue = Color(hex: "A1C4FD")
    static let darkBlue = Color(hex: "667EEA")
    static let lightBlue = Color(hex: "E0EAFC")
    
    // 中性颜色
    static let customWhite = Color.white
    static let lightGray = Color(hex: "F2F2F7")
    static let mediumGray = Color(hex: "E5E5EA")
    static let darkGray = Color(hex: "8E8E93")
    static let customBlack = Color(hex: "333333")
    
    // 语义颜色
    static let successColor = Color(hex: "4CD964")
    static let warningColor = Color(hex: "FFCC00")
    static let errorColor = Color(hex: "FF3B30")
    static let infoColor = Color(hex: "5AC8FA")
    
    // 背景颜色
    static let backgroundColor = Color(hex: "F9F9F9")
    static let cardBackground = Color.white
    
    // 应用特定颜色
    static let primaryText = Color(hex: "333333")
    static let secondaryText = Color(hex: "8E8E93")
    static let accentColor = Color(hex: "667EEA")
    static let primaryBackground = Color(hex: "F9F9F9")
    static let searchBarBackground = Color(hex: "F2F2F7")
}

// MARK: - 渐变扩展
extension LinearGradient {
    static let primaryGradient = LinearGradient(
        gradient: Gradient(colors: [Color.babyBlue, Color.darkBlue]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

// MARK: - 辅助方法
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 