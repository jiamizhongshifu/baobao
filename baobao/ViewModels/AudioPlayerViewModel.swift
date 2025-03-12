import Foundation
import AVFoundation
import Combine

class AudioPlayerViewModel: NSObject, ObservableObject, AVAudioPlayerDelegate {
    // 发布属性，当值变化时会通知观察者
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var progress: Double = 0
    @Published var errorMessage: String?
    
    // 语音角色选项
    let voiceOptions = [
        "xiaoMing": "小明哥哥",
        "xiaoHong": "小红姐姐",
        "pingPing": "萍萍阿姨",
        "laoWang": "老王爷爷",
        "robot": "机器人"
    ]
    
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?
    private let speechService = SpeechService.shared
    private var cancellables = Set<AnyCancellable>()
    
    // 播放音频
    func playAudio(url: URL) {
        do {
            // 停止当前播放
            stopAudio()
            
            // 创建新的音频播放器
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.prepareToPlay()
            
            // 设置音频信息
            duration = audioPlayer?.duration ?? 0
            
            // 开始播放
            audioPlayer?.play()
            isPlaying = true
            
            // 启动定时器更新进度
            startProgressTimer()
        } catch {
            errorMessage = "播放音频失败: \(error.localizedDescription)"
        }
    }
    
    // 播放故事音频
    func playStoryAudio(story: Story) {
        guard let audioURLString = story.audioURL, let audioURL = URL(string: audioURLString) else {
            errorMessage = "音频URL无效"
            return
        }
        
        playAudio(url: audioURL)
    }
    
    // 合成并播放文本
    func synthesizeAndPlay(text: String, voiceType: String, completion: @escaping (Bool) -> Void) {
        // 将字符串转换为 VoiceType 枚举
        let voiceTypeEnum: VoiceType
        switch voiceType {
        case "男声":
            voiceTypeEnum = .male
        case "女声":
            voiceTypeEnum = .female
        case "童声":
            voiceTypeEnum = .child
        case "机器人":
            voiceTypeEnum = .robot
        default:
            voiceTypeEnum = .female // 默认使用女声
        }
        
        speechService.synthesizeSpeech(text: text, voiceType: voiceTypeEnum) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let audioURL):
                    self?.playAudio(url: audioURL)
                    completion(true)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }
    
    // 暂停播放
    func pauseAudio() {
        audioPlayer?.pause()
        isPlaying = false
        timer?.invalidate()
    }
    
    // 恢复播放
    func resumeAudio() {
        audioPlayer?.play()
        isPlaying = true
        startProgressTimer()
    }
    
    // 停止播放
    func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        currentTime = 0
        progress = 0
        timer?.invalidate()
    }
    
    // 跳转到指定位置
    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
        progress = Double(currentTime / duration)
    }
    
    // 启动进度更新定时器
    private func startProgressTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
            self.progress = Double(self.currentTime / self.duration)
        }
    }
    
    // MARK: - AVAudioPlayerDelegate
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { [weak self] in
            self?.isPlaying = false
            self?.timer?.invalidate()
            self?.currentTime = self?.duration ?? 0
            self?.progress = 1.0
        }
    }
    
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        if let error = error {
            errorMessage = "音频解码错误: \(error.localizedDescription)"
        }
    }
    
    // 格式化时间
    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
} 