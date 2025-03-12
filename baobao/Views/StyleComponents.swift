import SwiftUI

// MARK: - 按钮样式

/// 主要按钮样式
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                LinearGradient.primaryGradient
                    .opacity(configuration.isPressed ? 0.8 : 1)
            )
            .cornerRadius(10)
            .shadow(color: Color.darkBlue.opacity(0.3), radius: 5, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// 次要按钮样式
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(Color.darkBlue)
            .padding(.vertical, 12)
            .padding(.horizontal, 20)
            .background(
                Color.lightBlue
                    .opacity(configuration.isPressed ? 0.7 : 1)
            )
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.darkBlue.opacity(0.3), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

/// 圆形图标按钮样式
struct CircleIconButtonStyle: ButtonStyle {
    var color: Color = .accentColor
    var size: CGFloat = 50
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.4))
            .foregroundColor(.white)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(
                        LinearGradient.primaryGradient
                            .opacity(configuration.isPressed ? 0.8 : 1)
                    )
            )
            .shadow(color: color.opacity(0.3), radius: 5, x: 0, y: 3)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - 卡片样式

/// 基础卡片样式
struct CardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(24)
            .shadow(color: Color.customBlack.opacity(0.05), radius: 8, x: 0, y: 4)
    }
}

/// 故事卡片样式
struct StoryCardModifier: ViewModifier {
    var isSelected: Bool = false
    
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.cardBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.customBlack.opacity(isSelected ? 0.1 : 0.05), radius: isSelected ? 10 : 5, x: 0, y: isSelected ? 5 : 2)
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - 输入框样式

/// 文本输入框样式
struct TextFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding()
            .background(Color.searchBarBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.mediumGray, lineWidth: 1)
            )
    }
}

/// 搜索框样式
struct SearchBarModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(Color.searchBarBackground)
            .cornerRadius(10)
    }
}

// MARK: - 扩展

extension View {
    /// 应用基础卡片样式
    func cardStyle() -> some View {
        self.modifier(CardModifier())
    }
    
    /// 应用故事卡片样式
    func storyCardStyle(isSelected: Bool = false) -> some View {
        self.modifier(StoryCardModifier(isSelected: isSelected))
    }
    
    /// 应用文本输入框样式
    func textFieldStyle() -> some View {
        self.modifier(TextFieldModifier())
    }
    
    /// 应用搜索框样式
    func searchBarStyle() -> some View {
        self.modifier(SearchBarModifier())
    }
} 