#!/bin/bash

# 简单的xcpretty替代脚本
# 用法: ./xcpretty.sh < xcodebuild_output 或 xcodebuild | ./xcpretty.sh

# 设置颜色
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 读取标准输入并处理
while IFS= read -r line; do
  # 过滤和美化输出
  if [[ $line == *"Test Case"*"passed"* ]]; then
    echo -e "${GREEN}✓${NC} ${line#*Test Case \'}"
  elif [[ $line == *"Test Case"*"failed"* ]]; then
    echo -e "${RED}✗${NC} ${line#*Test Case \'}"
  elif [[ $line == *"error:"* ]]; then
    echo -e "${RED}错误:${NC} $line"
  elif [[ $line == *"warning:"* ]]; then
    echo -e "${YELLOW}警告:${NC} $line"
  elif [[ $line == *"Compile"* ]]; then
    echo -e "${BLUE}编译:${NC} $line"
  elif [[ $line == *"Build succeeded"* ]]; then
    echo -e "${GREEN}构建成功${NC}"
  elif [[ $line == *"Build failed"* ]]; then
    echo -e "${RED}构建失败${NC}"
  elif [[ $line == *"** TEST SUCCEEDED **"* ]]; then
    echo -e "${GREEN}✅ 测试全部通过!${NC}"
  elif [[ $line == *"** TEST FAILED **"* ]]; then
    echo -e "${RED}❌ 测试失败!${NC}"
  else
    # 只输出重要信息，忽略大部分冗长输出
    if [[ $line == *"Testing"* || $line == *"Executed"* || $line == *"Linking"* ]]; then
      echo "$line"
    fi
  fi
done

exit 0 