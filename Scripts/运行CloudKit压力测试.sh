#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 项目目录
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
echo -e "${BLUE}项目目录: ${PROJECT_DIR}${NC}"

# 运行类型
RUN_TYPE="all"
TEST_NAME=""

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    -t|--test)
      RUN_TYPE="single"
      TEST_NAME="$2"
      shift 2
      ;;
    -s|--small)
      RUN_TYPE="small"
      shift
      ;;
    -l|--large)
      RUN_TYPE="large"
      shift
      ;;
    -c|--concurrent)
      RUN_TYPE="concurrent"
      shift
      ;;
    -m|--mixed)
      RUN_TYPE="mixed"
      shift
      ;;
    -h|--help)
      echo "使用方法: $0 [选项]"
      echo "选项:"
      echo "  -t, --test TEST_NAME    运行指定的单一测试"
      echo "  -s, --small             仅运行小数据批量同步测试"
      echo "  -l, --large             仅运行大数据同步测试"
      echo "  -c, --concurrent        仅运行并发操作测试"
      echo "  -m, --mixed             仅运行混合工作负载测试"
      echo "  -h, --help              显示帮助信息"
      exit 0
      ;;
    *)
      echo -e "${RED}未知参数: $1${NC}"
      exit 1
      ;;
  esac
done

# 验证当前用户登录到iCloud
function check_icloud_login {
    echo -e "${YELLOW}正在检查iCloud登录状态...${NC}"
    # 实际上无法直接检查iCloud登录状态，但我们可以提醒用户
    echo -e "${YELLOW}请确保你的开发设备已经登录到iCloud，并且已在系统偏好设置启用iCloud Drive${NC}"
    read -p "是否已确认iCloud登录状态？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}请先登录iCloud后再进行测试${NC}"
        exit 1
    fi
}

# 检查CloudKit开发环境
function check_cloudkit_env {
    echo -e "${YELLOW}正在检查CloudKit开发环境...${NC}"
    
    # 检查是否安装了Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}错误: 未找到Xcode。请确保已安装Xcode并设置命令行工具。${NC}"
        exit 1
    fi
    
    # 显示Xcode版本
    XCODE_VERSION=$(xcodebuild -version | head -n 1)
    echo -e "${GREEN}✓ $XCODE_VERSION${NC}"
    
    # 提醒用户确认项目配置
    echo -e "${YELLOW}请确保你的项目已正确配置CloudKit容器和权限:${NC}"
    echo "  - 在Xcode中选择项目目标"
    echo "  - 检查 'Signing & Capabilities' 选项卡"
    echo "  - 确认iCloud服务已启用并勾选CloudKit"
    echo "  - 确认已配置正确的CloudKit容器标识符"
    
    read -p "是否已确认CloudKit配置无误？(y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}请先完成CloudKit配置后再进行测试${NC}"
        exit 1
    fi
}

# 清理测试数据
function cleanup_test_data {
    echo -e "${YELLOW}是否需要清理之前的测试数据？这将删除所有以'压力测试'开头的故事和宝宝信息。${NC}"
    read -p "清理测试数据？(y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}启动测试App以清理测试数据...${NC}"
        echo "这个功能需要应用程序内置清理功能支持"
        echo "请在App启动后执行以下操作:"
        echo "1. 进入App设置页面"
        echo "2. 找到'开发者选项'或'测试工具'"
        echo "3. 点击'清理测试数据'按钮"
        echo -e "${YELLOW}完成后请按任意键继续...${NC}"
        read -n 1 -s
    fi
}

# 使用xcodebuild运行指定测试
function run_test {
    TEST_CLASS="CloudKitStressTest"
    TEST_METHOD="$1"
    
    if [ -z "$TEST_METHOD" ]; then
        TEST_SPECIFIER="$TEST_CLASS"
    else
        TEST_SPECIFIER="$TEST_CLASS/$TEST_METHOD"
    fi
    
    echo -e "${BLUE}运行测试: $TEST_SPECIFIER${NC}"
    
    # 构建命令
    # 注意：这里假设使用标准的Xcode项目结构，可能需要根据实际项目调整
    TEST_CMD="xcodebuild test -project $PROJECT_DIR/BaoBao.xcodeproj -scheme BaoBao -destination 'platform=iOS Simulator,name=iPhone 14' -testPlan CloudKitTests -only-testing:BaoBao/$TEST_SPECIFIER"
    
    echo -e "${YELLOW}执行命令: $TEST_CMD${NC}"
    
    # 执行测试命令
    eval $TEST_CMD
    
    # 检查执行结果
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}测试 $TEST_SPECIFIER 完成${NC}"
    else
        echo -e "${RED}测试 $TEST_SPECIFIER 失败${NC}"
    fi
    
    echo "-------------------------------------"
}

# 主函数
function main {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}    宝宝故事 CloudKit 压力测试工具    ${NC}"
    echo -e "${BLUE}=====================================${NC}"
    
    # 检查环境
    check_icloud_login
    check_cloudkit_env
    
    # 清理数据
    cleanup_test_data
    
    # 根据运行类型执行测试
    case $RUN_TYPE in
        "single")
            if [ -z "$TEST_NAME" ]; then
                echo -e "${RED}错误: 未指定测试名称${NC}"
                exit 1
            fi
            run_test "$TEST_NAME"
            ;;
        "small")
            run_test "testBulkSmallDataSync"
            ;;
        "large")
            run_test "testLargeDataSync"
            ;;
        "concurrent")
            run_test "testConcurrentOperations"
            ;;
        "mixed")
            run_test "testMixedWorkload"
            ;;
        "all")
            echo -e "${BLUE}运行所有CloudKit压力测试...${NC}"
            run_test "testBulkSmallDataSync"
            run_test "testLargeDataSync"
            run_test "testConcurrentOperations"
            run_test "testMixedWorkload"
            ;;
    esac
    
    echo -e "${GREEN}CloudKit压力测试完成!${NC}"
    echo "如需查看详细测试报告，请检查Xcode测试结果或控制台输出"
}

# 执行主函数
main 