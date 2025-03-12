import SwiftUI

struct StoryDetailView: View {
    let story: Story
    
    @EnvironmentObject private var audioPlayerViewModel: AudioPlayerViewModel
    @State private var selectedVoiceType = "xiaoMing"
    @State private var isSynthesizing = false
    @State private var errorMessage: String?
    @State private var showAlert = false
    @State private var showVoiceSelection = false
    @State private var showShareSheet = false
    
    var body: some View {
        ZStack {
            // 背景颜色
            Color.primaryBackground
                .edgesIgnoringSafeArea(.all)
            
            // 主内容
            ScrollView {
                VStack(spacing: 24) {
                    // 故事标题
                    storyTitleSection
                    
                    // 故事内容
                    storyContentSection
                    
                    // 音频播放器
                    audioPlayerSection
                }
                .padding()
            }
            
            // 加载指示器
            if isSynthesizing {
                synthesizingOverlay
            }
        }
        .navigationTitle("故事详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showShareSheet = true
                }) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("提示"),
                message: Text(errorMessage ?? "未知错误"),
                dismissButton: .default(Text("确定"))
            )
        }
        .sheet(isPresented: $showVoiceSelection) {
            VoiceSelectionView(
                selectedVoice: $selectedVoiceType,
                onConfirm: {
                    synthesizeSpeech()
                    showVoiceSelection = false
                },
                onCancel: {
                    showVoiceSelection = false
                }
            )
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(items: [story.title, story.content])
        }
        .onAppear {
            // 如果故事已有音频，直接加载
            if let audioURL = story.audioURL, let url = URL(string: audioURL) {
                audioPlayerViewModel.playAudio(url: url)
            }
        }
        .onDisappear {
            // 离开页面时停止播放
            audioPlayerViewModel.stopAudio()
        }
    }
    
    // 故事标题部分
    private var storyTitleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(story.title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.primaryText)
            
            HStack {
                Label(story.childName, systemImage: "person")
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryText)
                
                Spacer()
                
                Label(formatDate(story.createdAt), systemImage: "calendar")
                    .font(.subheadline)
                    .foregroundColor(Color.secondaryText)
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 故事内容部分
    private var storyContentSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("故事内容")
                .font(.headline)
                .foregroundColor(Color.primaryText)
            
            Text(story.content)
                .font(.body)
                .foregroundColor(Color.primaryText)
                .lineSpacing(6)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 音频播放器部分
    private var audioPlayerSection: some View {
        VStack(spacing: 16) {
            // 标题
            HStack {
                Text("语音朗读")
                    .font(.headline)
                    .foregroundColor(Color.primaryText)
                
                Spacer()
                
                // 语音选择按钮
                Button(action: {
                    showVoiceSelection = true
                }) {
                    Label("更换语音", systemImage: "person.wave.2")
                        .font(.subheadline)
                        .foregroundColor(Color.accentColor)
                }
            }
            
            // 播放器控件
            if story.audioURL != nil || audioPlayerViewModel.isPlaying {
                // 播放进度条
                VStack(spacing: 8) {
                    Slider(
                        value: Binding(
                            get: { audioPlayerViewModel.progress },
                            set: { audioPlayerViewModel.seek(to: $0 * audioPlayerViewModel.duration) }
                        ),
                        in: 0...1,
                        step: 0.01
                    )
                    .accentColor(Color.accentColor)
                    
                    // 时间显示
                    HStack {
                        Text(audioPlayerViewModel.formatTime(audioPlayerViewModel.currentTime))
                            .font(.caption)
                            .foregroundColor(Color.secondaryText)
                        
                        Spacer()
                        
                        Text(audioPlayerViewModel.formatTime(audioPlayerViewModel.duration))
                            .font(.caption)
                            .foregroundColor(Color.secondaryText)
                    }
                }
                
                // 播放控制按钮
                HStack(spacing: 40) {
                    Spacer()
                    
                    // 后退10秒
                    Button(action: {
                        let newTime = max(0, audioPlayerViewModel.currentTime - 10)
                        audioPlayerViewModel.seek(to: newTime)
                    }) {
                        Image(systemName: "gobackward.10")
                            .font(.title2)
                            .foregroundColor(Color.primaryText)
                    }
                    
                    // 播放/暂停
                    Button(action: {
                        if audioPlayerViewModel.isPlaying {
                            audioPlayerViewModel.pauseAudio()
                        } else {
                            if audioPlayerViewModel.currentTime > 0 {
                                audioPlayerViewModel.resumeAudio()
                            } else if let audioURL = story.audioURL, let url = URL(string: audioURL) {
                                audioPlayerViewModel.playAudio(url: url)
                            } else {
                                synthesizeSpeech()
                            }
                        }
                    }) {
                        Image(systemName: audioPlayerViewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(Color.accentColor)
                    }
                    
                    // 前进10秒
                    Button(action: {
                        let newTime = min(audioPlayerViewModel.duration, audioPlayerViewModel.currentTime + 10)
                        audioPlayerViewModel.seek(to: newTime)
                    }) {
                        Image(systemName: "goforward.10")
                            .font(.title2)
                            .foregroundColor(Color.primaryText)
                    }
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            } else {
                // 合成语音按钮
                Button(action: {
                    synthesizeSpeech()
                }) {
                    HStack {
                        Image(systemName: "waveform")
                        Text("合成语音")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color.cardBackground)
        .cornerRadius(12)
    }
    
    // 合成中覆盖层
    private var synthesizingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .edgesIgnoringSafeArea(.all)
            
            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                
                Text("正在合成语音...")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("这可能需要一点时间，请耐心等待")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(30)
            .background(Color.primaryBackground.opacity(0.8))
            .cornerRadius(16)
        }
    }
    
    // 合成语音
    private func synthesizeSpeech() {
        isSynthesizing = true
        
        audioPlayerViewModel.synthesizeAndPlay(
            text: story.content,
            voiceType: selectedVoiceType
        ) { success in
            isSynthesizing = false
            
            if !success {
                errorMessage = audioPlayerViewModel.errorMessage ?? "语音合成失败"
                showAlert = true
            }
        }
    }
    
    // 格式化日期
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

// 语音选择视图
struct VoiceSelectionView: View {
    @EnvironmentObject private var audioPlayerViewModel: AudioPlayerViewModel
    @Binding var selectedVoice: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(Array(audioPlayerViewModel.voiceOptions), id: \.key) { key, value in
                    Button(action: {
                        selectedVoice = key
                    }) {
                        HStack {
                            Text(value)
                                .foregroundColor(Color.primaryText)
                            
                            Spacer()
                            
                            if selectedVoice == key {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Color.accentColor)
                            }
                        }
                    }
                }
            }
            .navigationTitle("选择语音")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消", action: onCancel)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("确定", action: onConfirm)
                }
            }
        }
    }
}

// 分享表单
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
} 