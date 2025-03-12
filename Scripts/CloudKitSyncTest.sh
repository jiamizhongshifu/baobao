#!/bin/bash

# 宝宝故事应用CloudKit同步测试脚本
# 用法: ./CloudKitSyncTest.sh [选项]
# 选项:
#   -d, --diagnostic    仅运行诊断测试
#   -c, --cleanup       清理测试数据
#   -f, --full          执行全量同步
#   -h, --help          显示此帮助信息

# 设置颜色
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 显示帮助信息
function show_help {
    echo -e "${BLUE}宝宝故事应用CloudKit同步测试脚本${NC}"
    echo "用法: ./CloudKitSyncTest.sh [选项]"
    echo "选项:"
    echo "  -d, --diagnostic    仅运行诊断测试"
    echo "  -c, --cleanup       清理测试数据"
    echo "  -f, --full          执行全量同步"
    echo "  -h, --help          显示此帮助信息"
}

# 应用路径
APP_PATH="/Applications/BaoBao.app"
BUNDLE_ID="com.example.baobao"

# 检查是否安装了必要工具
function check_tools {
    echo -e "${YELLOW}检查必要工具...${NC}"
    
    # 检查xcrun
    if ! command -v xcrun &> /dev/null; then
        echo -e "${RED}错误: 未找到xcrun，请确保已安装Xcode命令行工具${NC}"
        exit 1
    fi
    
    # 检查simctl
    if ! xcrun simctl help &> /dev/null; then
        echo -e "${RED}错误: simctl不可用，请确保已安装Xcode${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}所有工具检查通过✓${NC}"
}

# 诊断测试
function run_diagnostic {
    echo -e "${YELLOW}运行CloudKit诊断...${NC}"
    
    # 启动应用
    echo "启动应用..."
    xcrun simctl launch booted $BUNDLE_ID
    
    # 等待应用启动
    sleep 2
    
    echo "请在应用中手动打开CloudKit诊断工具并运行诊断"
    echo "诊断完成后，请在此处按任意键继续..."
    read -n 1
    
    # 终止应用
    xcrun simctl terminate booted $BUNDLE_ID
    
    echo -e "${GREEN}诊断测试完成✓${NC}"
}

# 清理测试数据
function cleanup_data {
    echo -e "${YELLOW}清理CloudKit测试数据...${NC}"
    
    # 启动应用
    echo "启动应用..."
    xcrun simctl launch booted $BUNDLE_ID
    
    # 等待应用启动
    sleep 2
    
    echo "请在应用中手动打开CloudKit诊断工具并清理数据"
    echo "清理完成后，请在此处按任意键继续..."
    read -n 1
    
    # 终止应用
    xcrun simctl terminate booted $BUNDLE_ID
    
    echo -e "${GREEN}数据清理完成✓${NC}"
}

# 执行全量同步
function perform_full_sync {
    echo -e "${YELLOW}执行全量同步...${NC}"
    
    # 启动应用
    echo "启动应用..."
    xcrun simctl launch booted $BUNDLE_ID
    
    # 等待应用启动
    sleep 2
    
    echo "请在应用中手动打开设置页面并刷新CloudKit状态"
    echo "然后等待同步完成"
    echo "同步完成后，请在此处按任意键继续..."
    read -n 1
    
    # 终止应用
    xcrun simctl terminate booted $BUNDLE_ID
    
    echo -e "${GREEN}全量同步完成✓${NC}"
}

# 多设备同步测试
function multi_device_test {
    echo -e "${YELLOW}多设备同步测试${NC}"
    echo "此测试需要两台或更多运行宝宝故事应用的设备。"
    echo -e "${BLUE}测试步骤：${NC}"
    echo "1. 确保所有设备都使用相同的iCloud账户"
    echo "2. 在所有设备上启用CloudKit同步"
    echo "3. 在设备A上创建一个新故事"
    echo "4. 检查设备B上是否能看到新故事"
    echo "5. 在设备B上修改故事"
    echo "6. 检查设备A上的故事是否已更新"
    echo "7. 在设备A上删除故事"
    echo "8. 检查设备B上的故事是否已删除"
    
    echo -e "${YELLOW}请现在开始测试，完成后按任意键继续...${NC}"
    read -n 1
    
    echo -e "${BLUE}请输入测试结果 (成功/失败)：${NC}"
    read result
    
    if [[ "$result" == "成功" ]]; then
        echo -e "${GREEN}多设备同步测试成功✓${NC}"
    else
        echo -e "${RED}多设备同步测试失败✗${NC}"
        echo "请运行诊断工具查找问题。"
    fi
}

# 执行基本测试流程
function run_basic_tests {
    echo -e "${YELLOW}执行基本CloudKit同步测试...${NC}"
    
    # 启动应用
    echo "启动应用..."
    xcrun simctl launch booted $BUNDLE_ID
    
    # 等待应用启动
    sleep 2
    
    echo -e "${BLUE}测试步骤：${NC}"
    echo "1. 创建一个新故事，主题为'测试故事'"
    echo "2. 创建一个新宝宝资料，名字为'测试宝宝'"
    echo "3. 等待数据同步到CloudKit (约10秒)"
    echo "4. 清除应用数据 (设置中的'重置应用')"
    echo "5. 重启应用，检查数据是否从CloudKit恢复"
    
    echo -e "${YELLOW}请现在开始测试，完成后按任意键继续...${NC}"
    read -n 1
    
    # 终止应用
    xcrun simctl terminate booted $BUNDLE_ID
    
    echo -e "${BLUE}请输入测试结果 (成功/失败)：${NC}"
    read result
    
    if [[ "$result" == "成功" ]]; then
        echo -e "${GREEN}基本CloudKit同步测试成功✓${NC}"
    else
        echo -e "${RED}基本CloudKit同步测试失败✗${NC}"
        echo "请运行诊断工具查找问题。"
    fi
}

# 主函数
function main {
    check_tools
    
    # 解析命令行参数
    if [[ $# -eq 0 ]]; then
        # 无参数，执行所有测试
        run_diagnostic
        run_basic_tests
        multi_device_test
    else
        while [[ $# -gt 0 ]]; do
            case $1 in
                -d|--diagnostic)
                    run_diagnostic
                    shift
                    ;;
                -c|--cleanup)
                    cleanup_data
                    shift
                    ;;
                -f|--full)
                    perform_full_sync
                    shift
                    ;;
                -h|--help)
                    show_help
                    exit 0
                    ;;
                *)
                    echo -e "${RED}未知选项: $1${NC}"
                    show_help
                    exit 1
                    ;;
            esac
        done
    fi
    
    echo -e "${GREEN}CloudKit同步测试完成!${NC}"
}

# 运行主函数
main "$@" 