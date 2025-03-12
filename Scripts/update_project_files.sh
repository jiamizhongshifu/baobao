#!/bin/bash

# 项目根目录
PROJECT_ROOT="/Users/zhongqingbiao/Documents/baobao"
BAOBAO_DIR="$PROJECT_ROOT/baobao"
SCRIPT_DIR="$PROJECT_ROOT/Scripts"

# 颜色设置
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
NC="\033[0m" # No Color

echo -e "${BLUE}开始更新项目文件引用...${NC}"

# 检查Xcode项目文件
PROJECT_FILE="$PROJECT_ROOT/baobao.xcodeproj/project.pbxproj"
if [ ! -f "$PROJECT_FILE" ]; then
    echo -e "${RED}错误: 找不到Xcode项目文件!${NC}"
    exit 1
fi

echo -e "${GREEN}找到Xcode项目文件:${NC} $PROJECT_FILE"

# 检查并确保所有必要的目录都存在
mkdir -p "$BAOBAO_DIR/Models"
mkdir -p "$BAOBAO_DIR/Services/API"
mkdir -p "$BAOBAO_DIR/Services/Story"
mkdir -p "$BAOBAO_DIR/Services/Speech"

echo -e "${GREEN}验证所有必要的文件存在...${NC}"

# 检查关键文件是否存在
required_files=(
    "$BAOBAO_DIR/Models/Story.swift"
    "$BAOBAO_DIR/Services/API/APIController.swift"
    "$BAOBAO_DIR/Services/API/DataService.swift"
    "$BAOBAO_DIR/Services/Story/StoryService.swift"
    "$BAOBAO_DIR/Services/Speech/SpeechService.swift"
    "$BAOBAO_DIR/Project.swift"
)

for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}错误: 找不到文件:${NC} $file"
        exit 1
    fi
done

echo -e "${GREEN}所有必要的文件都存在.${NC}"

# 确保main.swift引用了所有服务
echo -e "${YELLOW}更新main.swift引用...${NC}"

cat <<EOF > "$BAOBAO_DIR/main.swift"
import Foundation
import UIKit

// 这个文件是应用程序的入口点
// 使用UIApplicationMain函数启动应用程序
UIApplicationMain(
    CommandLine.argc,
    CommandLine.unsafeArgv,
    nil,
    NSStringFromClass(AppDelegate.self)
)

// 确保所有服务都被初始化
func initializeServices() {
    // 初始化数据服务
    let _ = DataService.shared
    
    // 初始化故事服务
    let _ = StoryService.shared
    
    // 初始化语音服务
    let _ = SpeechService.shared
    
    // 初始化API控制器
    let _ = APIController.shared
    
    print("所有服务已初始化完成")
}

// 应用启动时初始化服务
@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // 初始化所有服务
        initializeServices()
        
        return true
    }
}
EOF

echo -e "${GREEN}main.swift 已更新${NC}"

echo -e "${YELLOW}尝试手动添加文件到Xcode项目...${NC}"
echo -e "${YELLOW}注意: 这是一个简单的脚本，可能需要使用Xcode手动添加引用.${NC}"

echo -e "${GREEN}完成!${NC}"
echo -e "${BLUE}建议:${NC}"
echo -e "1. 打开Xcode项目"
echo -e "2. 右键项目导航器中的baobao目录"
echo -e "3. 选择 '添加文件到 \"baobao\"...'"
echo -e "4. 选择项目目录中的所有源文件"
echo -e "5. 确保勾选 '按照目标关联添加到需要的Target'，点击添加"
echo -e "\n${GREEN}脚本执行完毕.${NC}" 