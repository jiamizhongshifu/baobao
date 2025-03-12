import Foundation

/// 语音角色类型
enum VoiceType: String, Codable, CaseIterable {
    case xiaoMing = "小明哥哥"
    case xiaoHong = "小红姐姐"
    case pingPing = "萍萍阿姨"
    case laoWang = "老王爷爷"
    case robot = "机器人"
    
    /// 获取Azure语音服务对应的声音名称
    var azureVoiceName: String {
        switch self {
        case .xiaoMing:
            return "zh-CN-YunxiNeural"      // 年轻男声
        case .xiaoHong:
            return "zh-CN-XiaoxiaoNeural"   // 年轻女声
        case .pingPing:
            return "zh-CN-XiaohanNeural"    // 成熟女声
        case .laoWang:
            return "zh-CN-YunjianNeural"    // 成熟男声
        case .robot:
            return "zh-CN-YunyangNeural"    // 机器人风格声音
        }
    }
    
    /// 获取本地TTS备选声音
    var localVoiceName: String {
        switch self {
        case .xiaoMing:
            return "Tingting"  // 或其他适合的本地声音
        case .xiaoHong:
            return "Sinji"     // 或其他适合的本地声音
        case .pingPing:
            return "Meijia"    // 或其他适合的本地声音
        case .laoWang:
            return "Dahai"     // 或其他适合的本地声音
        case .robot:
            return "Sin-ji"    // 或其他适合的本地声音
        }
    }
    
    /// 获取语音图标名称
    var icon: String {
        switch self {
        case .xiaoMing:
            return "person.fill"
        case .xiaoHong:
            return "person.fill"
        case .pingPing:
            return "person.fill"
        case .laoWang:
            return "person.fill"
        case .robot:
            return "robot"
        }
    }
} 