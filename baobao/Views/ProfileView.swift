import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var childViewModel: ChildViewModel
    @State private var isOfflineMode = false
    @State private var showClearDataConfirmation = false
    @State private var showingAddChildSheet = false
    
    var body: some View {
        ZStack {
            // 背景颜色
            Color.backgroundColor
                .edgesIgnoringSafeArea(.all)
            
            // 主内容
            ScrollView {
                VStack(spacing: 24) {
                    // 用户信息
                    userInfoSection
                    
                    // 宝宝信息
                    childInfoSection
                    
                    // 应用设置
                    settingsSection
                    
                    // 关于应用
                    aboutSection
                }
                .padding()
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showingAddChildSheet) {
            AddChildView(isPresented: $showingAddChildSheet)
        }
        .alert(isPresented: $showClearDataConfirmation) {
            Alert(
                title: Text("确认清除数据"),
                message: Text("确定要清除所有数据吗？此操作不可恢复。"),
                primaryButton: .destructive(Text("清除")) {
                    clearAllData()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    // 用户信息部分
    private var userInfoSection: some View {
        VStack(spacing: 20) {
            // 用户头像
            Image(systemName: "person.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(Color.accentColor)
            
            // 用户名
            Text("亲爱的家长")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color.primaryText)
            
            // 用户标签
            Text("宝宝故事创作者")
                .font(.subheadline)
                .foregroundColor(Color.secondaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(16)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 宝宝信息部分
    private var childInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 标题
            HStack {
                Text("宝宝信息")
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
                VStack(spacing: 12) {
                    Text("还没有添加宝宝")
                        .font(.subheadline)
                        .foregroundColor(Color.secondaryText)
                    
                    Button(action: {
                        showingAddChildSheet = true
                    }) {
                        Text("添加宝宝")
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.accentColor)
                            .cornerRadius(8)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.searchBarBackground)
                .cornerRadius(8)
            } else {
                // 显示宝宝列表
                ForEach(childViewModel.children, id: \.id) { child in
                    HStack(spacing: 16) {
                        // 宝宝头像
                        ZStack {
                            Circle()
                                .fill(childViewModel.selectedChild?.id == child.id ? Color.accentColor : Color.gray)
                                .frame(width: 40, height: 40)
                            
                            Text(child.name.prefix(1))
                                .font(.headline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                        }
                        
                        // 宝宝信息
                        VStack(alignment: .leading, spacing: 4) {
                            Text(child.name)
                                .font(.headline)
                                .foregroundColor(Color.primaryText)
                            
                            Text("\(child.age)岁 · \(child.gender == .male ? "男孩" : "女孩")")
                                .font(.subheadline)
                                .foregroundColor(Color.secondaryText)
                        }
                        
                        Spacer()
                        
                        // 当前选中标签
                        if childViewModel.selectedChild?.id == child.id {
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
                    .background(childViewModel.selectedChild?.id == child.id ? Color.accentColor.opacity(0.05) : Color.searchBarBackground)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 应用设置部分
    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("应用设置")
                .font(.headline)
                .foregroundColor(Color.primaryText)
            
            // 离线模式
            Toggle(isOn: $isOfflineMode) {
                HStack(spacing: 16) {
                    Image(systemName: "wifi.slash")
                        .font(.headline)
                        .foregroundColor(Color.primaryText)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("离线模式")
                            .font(.subheadline)
                            .foregroundColor(Color.primaryText)
                        
                        Text("在没有网络的情况下使用已下载的故事")
                            .font(.caption)
                            .foregroundColor(Color.secondaryText)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: Color.accentColor))
            .padding()
            .background(Color.searchBarBackground)
            .cornerRadius(8)
            
            // 清除数据
            Button(action: {
                showClearDataConfirmation = true
            }) {
                HStack(spacing: 16) {
                    Image(systemName: "trash")
                        .font(.headline)
                        .foregroundColor(Color.red)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("清除所有数据")
                            .font(.subheadline)
                            .foregroundColor(Color.red)
                        
                        Text("删除所有故事和宝宝信息")
                            .font(.caption)
                            .foregroundColor(Color.secondaryText)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(Color.secondaryText)
                }
                .padding()
                .background(Color.searchBarBackground)
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 关于应用部分
    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("关于应用")
                .font(.headline)
                .foregroundColor(Color.primaryText)
            
            // 应用信息
            VStack(spacing: 16) {
                // 应用图标
                Image(systemName: "book.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color.accentColor)
                
                // 应用名称和版本
                VStack(spacing: 4) {
                    Text("宝宝故事")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Color.primaryText)
                    
                    Text("版本 1.0.0")
                        .font(.subheadline)
                        .foregroundColor(Color.secondaryText)
                }
                
                // 应用描述
                Text("为您的宝宝创造个性化的故事体验，激发想象力和创造力。")
                    .font(.body)
                    .foregroundColor(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                // 版权信息
                Text("© 2023 宝宝故事团队. 保留所有权利。")
                    .font(.caption)
                    .foregroundColor(Color.secondaryText)
            }
            .frame(maxWidth: .infinity)
            .padding()
            
            // 链接列表
            VStack(spacing: 0) {
                // 隐私政策
                LinkRow(title: "隐私政策", iconName: "lock.shield")
                
                Divider()
                    .padding(.leading, 40)
                
                // 用户协议
                LinkRow(title: "用户协议", iconName: "doc.text")
                
                Divider()
                    .padding(.leading, 40)
                
                // 联系我们
                LinkRow(title: "联系我们", iconName: "envelope")
                
                Divider()
                    .padding(.leading, 40)
                
                // 评分
                LinkRow(title: "给我们评分", iconName: "star")
            }
            .background(Color.searchBarBackground)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 清除所有数据
    private func clearAllData() {
        // 清除宝宝数据
        childViewModel.clearAllChildren()
        
        // 清除故事数据
        // storyViewModel.clearAllStories()
        
        // 清除缓存
        // cacheManager.clearAllCaches()
    }
}

// MARK: - 辅助视图

// 链接行
struct LinkRow: View {
    let title: String
    let iconName: String
    
    var body: some View {
        Button(action: {
            // 处理点击事件
        }) {
            HStack(spacing: 16) {
                Image(systemName: iconName)
                    .font(.headline)
                    .foregroundColor(Color.accentColor)
                
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(Color.primaryText)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.secondaryText)
            }
            .padding()
        }
    }
} 