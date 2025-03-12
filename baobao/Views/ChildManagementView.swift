import SwiftUI

struct ChildManagementView: View {
    @EnvironmentObject private var childViewModel: ChildViewModel
    @State private var showingAddChildSheet = false
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showAlert = false
    
    var body: some View {
        ZStack {
            // 背景颜色
            Color.backgroundColor
                .edgesIgnoringSafeArea(.all)
            
            // 主内容
            ScrollView {
                VStack(spacing: 24) {
                    // 头部说明
                    headerSection
                    
                    // 宝宝列表
                    childrenListSection
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
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddChildSheet = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddChildSheet) {
            AddChildView(isPresented: $showingAddChildSheet)
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("提示"),
                message: Text(errorMessage ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
        .onAppear {
            // 加载宝宝数据
            childViewModel.loadChildren()
        }
    }
    
    // 头部说明部分
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("管理宝宝信息")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.primaryText)
            
            Text("在这里管理宝宝的基本信息，选择当前使用的宝宝，或添加新的宝宝。")
                .font(.subheadline)
                .foregroundColor(Color.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 宝宝列表部分
    private var childrenListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("宝宝列表")
                    .font(.headline)
                    .foregroundColor(Color.primaryText)
                
                Spacer()
                
                Button(action: {
                    showingAddChildSheet = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("添加宝宝")
                    }
                    .font(.subheadline)
                    .foregroundColor(Color.accentColor)
                }
            }
            
            if childViewModel.children.isEmpty {
                // 没有宝宝时显示提示
                emptyChildrenView
            } else {
                // 显示宝宝列表
                childrenListView
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 空宝宝列表视图
    private var emptyChildrenView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(Color.secondaryText)
            
            Text("还没有添加宝宝")
                .font(.headline)
                .foregroundColor(Color.primaryText)
            
            Text("点击「添加宝宝」按钮来创建你的第一个宝宝档案")
                .font(.subheadline)
                .foregroundColor(Color.secondaryText)
                .multilineTextAlignment(.center)
            
            Button(action: {
                showingAddChildSheet = true
            }) {
                Text("添加宝宝")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.accentColor)
                    .cornerRadius(8)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
    
    // 宝宝列表视图
    private var childrenListView: some View {
        VStack(spacing: 16) {
            ForEach(childViewModel.children, id: \.id) { child in
                ChildRow(
                    child: child,
                    isSelected: childViewModel.selectedChild?.id == child.id,
                    onSelect: {
                        childViewModel.selectChild(child)
                    },
                    onEdit: {
                        // 编辑宝宝信息
                    },
                    onDelete: {
                        deleteChild(id: child.id)
                    }
                )
            }
        }
    }
    
    // 删除宝宝
    private func deleteChild(id: String) {
        isLoading = true
        
        childViewModel.deleteChild(id: id) { success in
            isLoading = false
            
            if !success {
                errorMessage = "删除宝宝失败"
                showAlert = true
            }
        }
    }
}

// MARK: - 辅助视图

// 宝宝行视图
struct ChildRow: View {
    let child: Child
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 宝宝信息行
            HStack(spacing: 16) {
                // 宝宝头像
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accentColor : Color.gray)
                        .frame(width: 50, height: 50)
                    
                    Text(child.name.prefix(1))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                }
                
                // 宝宝信息
                VStack(alignment: .leading, spacing: 4) {
                    Text(child.name)
                        .font(.headline)
                        .foregroundColor(Color.primaryText)
                    
                    HStack(spacing: 8) {
                        Text("\(child.age)岁")
                            .font(.subheadline)
                            .foregroundColor(Color.secondaryText)
                        
                        Text("•")
                            .foregroundColor(Color.secondaryText)
                        
                        Text(child.gender == .male ? "男孩" : "女孩")
                            .font(.subheadline)
                            .foregroundColor(Color.secondaryText)
                    }
                    
                    if !child.interests.isEmpty {
                        Text("兴趣: \(child.interests.joined(separator: "、"))")
                            .font(.caption)
                            .foregroundColor(Color.secondaryText)
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // 选择状态
                if isSelected {
                    Text("当前选中")
                        .font(.caption)
                        .foregroundColor(Color.accentColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.accentColor.opacity(0.1))
                        .cornerRadius(4)
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.05) : Color.clear)
            
            // 操作按钮行
            HStack {
                // 选择按钮
                Button(action: onSelect) {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark")
                        Text("选择")
                    }
                    .font(.subheadline)
                    .foregroundColor(isSelected ? Color.gray : Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .disabled(isSelected)
                
                Spacer()
                
                // 编辑按钮
                Button(action: onEdit) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil")
                        Text("编辑")
                    }
                    .font(.subheadline)
                    .foregroundColor(Color.blue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                
                // 删除按钮
                Button(action: {
                    showDeleteConfirmation = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                        Text("删除")
                    }
                    .font(.subheadline)
                    .foregroundColor(Color.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                }
                .alert(isPresented: $showDeleteConfirmation) {
                    Alert(
                        title: Text("确认删除"),
                        message: Text("确定要删除「\(child.name)」吗？此操作不可恢复。"),
                        primaryButton: .destructive(Text("删除")) {
                            onDelete()
                        },
                        secondaryButton: .cancel(Text("取消"))
                    )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.searchBarBackground)
        }
        .background(Color.cardBackground)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
} 