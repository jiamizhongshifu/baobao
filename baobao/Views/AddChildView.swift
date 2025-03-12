import SwiftUI

struct AddChildView: View {
    @EnvironmentObject private var childViewModel: ChildViewModel
    @Binding var isPresented: Bool
    
    @State private var name = ""
    @State private var age = 5
    @State private var gender = "male"
    @State private var selectedInterests: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAlert = false
    
    // 年龄范围
    private let ageRange = 3...8
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景颜色
                Color.backgroundColor
                    .edgesIgnoringSafeArea(.all)
                
                // 主内容
                ScrollView {
                    VStack(spacing: 24) {
                        // 已有宝宝列表
                        if !childViewModel.children.isEmpty {
                            existingChildrenSection
                        }
                        
                        // 添加新宝宝表单
                        addChildFormSection
                    }
                    .padding()
                }
                
                // 加载指示器
                if isLoading {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: Color.white))
                        .padding()
                        .background(Color.primaryBackground.opacity(0.8))
                        .cornerRadius(10)
                }
            }
            .navigationTitle("宝宝管理")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    isPresented = false
                }
                .foregroundColor(Color.accentColor),
                trailing: Button("保存") {
                    saveChild()
                }
                .disabled(name.isEmpty || isLoading)
                .foregroundColor(name.isEmpty ? Color.gray : Color.accentColor)
            )
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("提示"),
                    message: Text(errorMessage ?? "未知错误"),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
    
    // 已有宝宝列表部分
    private var existingChildrenSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("已有宝宝")
                .font(.headline)
                .foregroundColor(Color.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(childViewModel.children, id: \.id) { child in
                        ExistingChildCard(
                            child: child,
                            isSelected: childViewModel.selectedChild?.id == child.id,
                            onSelect: {
                                childViewModel.selectChild(child)
                            }
                        )
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 添加新宝宝表单部分
    private var addChildFormSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("添加新宝宝")
                .font(.headline)
                .foregroundColor(Color.primaryText)
            
            // 宝宝名字
            VStack(alignment: .leading, spacing: 8) {
                Text("宝宝名字")
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryText)
                
                TextField("请输入宝宝的名字", text: $name)
                    .padding()
                    .background(Color.searchBarBackground)
                    .cornerRadius(8)
                    .foregroundColor(Color.primaryText)
            }
            
            // 宝宝年龄
            VStack(alignment: .leading, spacing: 8) {
                Text("宝宝年龄")
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryText)
                
                HStack {
                    Text("\(age)岁")
                        .font(.headline)
                        .foregroundColor(Color.primaryText)
                        .frame(width: 60, alignment: .leading)
                    
                    Slider(value: Binding(
                        get: { Double(age) },
                        set: { age = Int($0) }
                    ), in: Double(ageRange.lowerBound)...Double(ageRange.upperBound), step: 1)
                    .accentColor(Color.accentColor)
                }
                
                // 年龄标签
                HStack {
                    ForEach(ageRange, id: \.self) { value in
                        Text("\(value)")
                            .font(.caption)
                            .foregroundColor(Color.secondaryText)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            
            // 宝宝性别
            VStack(alignment: .leading, spacing: 8) {
                Text("宝宝性别")
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryText)
                
                HStack(spacing: 16) {
                    GenderButton(
                        title: "男孩",
                        iconName: "person.fill",
                        isSelected: gender == "male",
                        color: .blue
                    ) {
                        gender = "male"
                    }
                    
                    GenderButton(
                        title: "女孩",
                        iconName: "person.fill",
                        isSelected: gender == "female",
                        color: .pink
                    ) {
                        gender = "female"
                    }
                }
            }
            
            // 宝宝兴趣爱好
            VStack(alignment: .leading, spacing: 8) {
                Text("宝宝兴趣爱好（可选）")
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryText)
                
                InterestTagsView(
                    selectedInterests: $selectedInterests,
                    availableInterests: childViewModel.interestOptions.map { $0.key }
                )
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 保存宝宝信息
    private func saveChild() {
        guard !name.isEmpty else {
            errorMessage = "请输入宝宝的名字"
            showAlert = true
            return
        }
        
        isLoading = true
        
        // 创建宝宝对象
        let child = Child(
            id: UUID().uuidString,
            name: name,
            age: age,
            gender: gender == "male" ? .male : .female,
            interests: Array(selectedInterests)
        )
        
        // 添加宝宝
        childViewModel.saveChild(child) { success in
            isLoading = false
            
            if success {
                // 选择新添加的宝宝
                childViewModel.selectChild(child)
                // 关闭表单
                isPresented = false
            } else {
                // 显示错误
                errorMessage = "添加宝宝失败，请重试"
                showAlert = true
            }
        }
    }
}

// MARK: - 辅助视图

// 已有宝宝卡片
struct ExistingChildCard: View {
    let child: Child
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                // 宝宝头像
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.gray)
                        .frame(width: 60, height: 60)
                    
                    Text(child.name.prefix(1))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                // 宝宝名字
                Text(child.name)
                    .font(.subheadline)
                    .foregroundColor(isSelected ? Color.accentColor : Color.primaryText)
                
                // 宝宝年龄和性别
                Text("\(child.age)岁 · \(child.gender == .male ? "男孩" : "女孩")")
                    .font(.caption)
                    .foregroundColor(Color.secondaryText)
            }
            .frame(width: 100)
            .padding(.vertical, 12)
            .padding(.horizontal, 8)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color.searchBarBackground)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
    }
}

// 性别选择按钮
struct GenderButton: View {
    let title: String
    let iconName: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: iconName)
                    .font(.headline)
                
                Text(title)
                    .font(.headline)
            }
            .foregroundColor(isSelected ? .white : color)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isSelected ? color : Color.searchBarBackground)
            .cornerRadius(8)
        }
    }
}

// 兴趣标签视图
struct InterestTagsView: View {
    @Binding var selectedInterests: Set<String>
    let availableInterests: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 已选兴趣
            if !selectedInterests.isEmpty {
                Text("已选兴趣")
                    .font(.caption)
                    .foregroundColor(Color.secondaryText)
                
                FlowLayout(
                    mode: .scrollable,
                    items: Array(selectedInterests),
                    itemSpacing: 8
                ) { interest in
                    InterestTag(
                        title: interest,
                        isSelected: true,
                        action: {
                            selectedInterests.remove(interest)
                        }
                    )
                }
            }
            
            // 可选兴趣
            Text("可选兴趣")
                .font(.caption)
                .foregroundColor(Color.secondaryText)
            
            FlowLayout(
                mode: .scrollable,
                items: availableInterests.filter { !selectedInterests.contains($0) },
                itemSpacing: 8
            ) { interest in
                InterestTag(
                    title: interest,
                    isSelected: false,
                    action: {
                        selectedInterests.insert(interest)
                    }
                )
            }
        }
    }
}

// 兴趣标签
struct InterestTag: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.subheadline)
                
                Image(systemName: isSelected ? "xmark.circle.fill" : "plus.circle.fill")
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.searchBarBackground)
            .foregroundColor(isSelected ? .white : Color.primaryText)
            .cornerRadius(16)
        }
    }
}

// 流式布局
struct FlowLayout<T: Hashable, V: View>: View {
    enum Mode {
        case scrollable
        case vstack
    }
    
    let mode: Mode
    let items: [T]
    let itemSpacing: CGFloat
    let itemBuilder: (T) -> V
    
    init(mode: Mode = .scrollable, items: [T], itemSpacing: CGFloat = 8, @ViewBuilder itemBuilder: @escaping (T) -> V) {
        self.mode = mode
        self.items = items
        self.itemSpacing = itemSpacing
        self.itemBuilder = itemBuilder
    }
    
    var body: some View {
        GeometryReader { geometry in
            generateContent(in: geometry)
        }
    }
    
    @ViewBuilder
    private func generateContent(in geometry: GeometryProxy) -> some View {
        switch mode {
        case .scrollable:
            ScrollView {
                createFlowItems(in: geometry.size.width)
            }
        case .vstack:
            createFlowItems(in: geometry.size.width)
        }
    }
    
    private func createFlowItems(in containerWidth: CGFloat) -> some View {
        var width: CGFloat = 0
        var height: CGFloat = 0
        var lastHeight: CGFloat = 0
        var rowItems: [[T]] = [[]]
        
        // 计算每个项目的位置
        for item in items {
            let itemView = itemBuilder(item)
            let itemSize = getItemSize(itemView)
            
            if width + itemSize.width + itemSpacing > containerWidth {
                // 换行
                width = itemSize.width
                height += lastHeight + itemSpacing
                lastHeight = itemSize.height
                rowItems.append([item])
            } else {
                // 同一行
                width += itemSize.width + itemSpacing
                lastHeight = max(lastHeight, itemSize.height)
                rowItems[rowItems.count - 1].append(item)
            }
        }
        
        return VStack(alignment: .leading, spacing: itemSpacing) {
            ForEach(0..<rowItems.count, id: \.self) { rowIndex in
                HStack(spacing: itemSpacing) {
                    ForEach(rowItems[rowIndex], id: \.self) { item in
                        itemBuilder(item)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
    
    private func getItemSize(_ itemView: V) -> CGSize {
        // 使用一个默认大小，或者根据内容计算大小
        return CGSize(width: 100, height: 30)
    }
} 