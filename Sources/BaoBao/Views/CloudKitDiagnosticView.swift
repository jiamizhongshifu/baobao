import SwiftUI
import UniformTypeIdentifiers

/// CloudKit诊断视图
struct CloudKitDiagnosticView: View {
    @State private var isRunningDiagnostics = false
    @State private var diagnosticReport: String = ""
    @State private var showShareSheet = false
    @State private var reportURL: URL? = nil
    @State private var isClearing = false
    @State private var showConfirmClear = false
    
    var body: some View {
        VStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("CloudKit诊断工具")
                        .font(.title)
                        .fontWeight(.bold)
                        .padding(.bottom, 8)
                    
                    Text("此工具用于诊断CloudKit同步功能的问题，并提供解决方案。")
                        .foregroundColor(.secondary)
                    
                    if diagnosticReport.isEmpty {
                        if isRunningDiagnostics {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(1.5)
                                
                                Text("正在运行诊断...")
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        } else {
                            VStack {
                                Spacer()
                                Image(systemName: "icloud.and.arrow.up.fill")
                                    .font(.system(size: 60))
                                    .foregroundColor(.blue.opacity(0.8))
                                    .padding(.bottom, 12)
                                
                                Text("点击下方按钮开始诊断")
                                    .foregroundColor(.secondary)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, minHeight: 200)
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                    } else {
                        Text("诊断结果")
                            .font(.headline)
                        
                        Text(diagnosticReport)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                .padding()
            }
            
            Divider()
            
            VStack(spacing: 16) {
                if !diagnosticReport.isEmpty {
                    Button(action: {
                        reportURL = CloudKitDiagnosticTool.shared.saveDiagnosticReport(diagnosticReport)
                        if reportURL != nil {
                            showShareSheet = true
                        }
                    }) {
                        HStack {
                            Image(systemName: "square.and.arrow.up")
                            Text("分享诊断报告")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        showConfirmClear = true
                    }) {
                        HStack {
                            Image(systemName: "trash")
                            Text("清理CloudKit数据")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .alert(isPresented: $showConfirmClear) {
                        Alert(
                            title: Text("确认清理"),
                            message: Text("这将删除所有CloudKit数据，并重新创建同步所需的容器结构。是否继续？"),
                            primaryButton: .destructive(Text("清理")) {
                                clearCloudKitData()
                            },
                            secondaryButton: .cancel()
                        )
                    }
                }
                
                Button(action: {
                    runDiagnostics()
                }) {
                    if isRunningDiagnostics {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                        Text("正在诊断...")
                    } else {
                        Image(systemName: "stethoscope")
                        Text(diagnosticReport.isEmpty ? "开始诊断" : "重新诊断")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunningDiagnostics || isClearing)
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("CloudKit诊断")
        .sheet(isPresented: $showShareSheet) {
            if let url = reportURL {
                ShareSheet(items: [url])
            }
        }
    }
    
    /// 运行诊断
    private func runDiagnostics() {
        isRunningDiagnostics = true
        diagnosticReport = ""
        
        CloudKitDiagnosticTool.shared.runDiagnostics { report in
            diagnosticReport = report
            isRunningDiagnostics = false
        }
    }
    
    /// 清理CloudKit数据
    private func clearCloudKitData() {
        isClearing = true
        
        CloudKitDiagnosticTool.shared.clearCloudKitData { result in
            isClearing = false
            
            switch result {
            case .success:
                diagnosticReport += "\n== 清理操作 ==\n"
                diagnosticReport += "CloudKit数据已成功清理\n"
                diagnosticReport += "请重启应用以重新初始化CloudKit同步\n\n"
            case .failure(let error):
                diagnosticReport += "\n== 清理操作 ==\n"
                diagnosticReport += "清理CloudKit数据失败: \(error.localizedDescription)\n\n"
            }
        }
    }
}

/// 分享页面
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct CloudKitDiagnosticView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            CloudKitDiagnosticView()
        }
    }
} 