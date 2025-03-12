#!/bin/bash

# 宝宝故事App测试运行脚本

# 定义颜色
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

echo -e "\n${YELLOW}开始运行宝宝故事App测试...${NC}\n"

# 切换到项目根目录
cd "$(dirname "$0")/.." || exit

# 确定使用的设备
DEVICE="iPhone 16"
OS_VERSION="18.3.1"
DESTINATION="platform=iOS Simulator,name=${DEVICE},OS=${OS_VERSION}"

# 运行单元测试
echo -e "${YELLOW}运行单元测试...${NC}"
xcodebuild test -scheme "baobao" -destination "${DESTINATION}" -resultBundlePath TestResults.xcresult

# 获取测试结果
TEST_RESULT=$?

# 检查测试结果
if [ $TEST_RESULT -eq 0 ]; then
  echo -e "\n${GREEN}✅ 所有测试通过!${NC}\n"
else
  echo -e "\n${RED}❌ 测试失败!${NC}\n"
fi

# 根据需要可以添加更多测试步骤，比如UI测试等
# xcodebuild test -scheme "baobaoUITests" -destination "${DESTINATION}"

exit $TEST_RESULT 