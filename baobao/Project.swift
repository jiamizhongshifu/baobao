import Foundation

// 此文件用于帮助组织项目结构
// 并确保所有模块都被正确识别和导入

/*
 项目结构:
 
 Models/
   - Story.swift (故事模型和相关枚举)
 
 Services/
   - API/
     - APIController.swift (WebView API控制器)
     - DataService.swift (数据持久化服务)
   - Story/
     - StoryService.swift (故事生成服务)
   - Speech/
     - SpeechService.swift (语音合成和播放服务)
 
 */

// 这个空协议用于标记模块，确保编译器能找到所有相关文件
protocol BaoBaoModule {}

// 实现标记协议的空类，确保编译器查找相关文件
class StoryModels: BaoBaoModule {}
class APIServices: BaoBaoModule {}
class StoryServices: BaoBaoModule {}
class SpeechServices: BaoBaoModule {} 