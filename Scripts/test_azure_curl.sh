#!/bin/bash

# API密钥和区域
AZURE_KEY="a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6"
AZURE_REGION="eastasia"

# 测试文本
TEXT="这是一个测试，用于验证Azure语音服务API是否正常工作。"

# 构建SSML
SSML="<speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xml:lang='zh-CN'><voice name='zh-CN-XiaoxiaoNeural'><prosody rate='0.9' pitch='0'>$TEXT</prosody></voice></speak>"

# 输出文件
OUTPUT_FILE="$HOME/Documents/test_azure_speech.mp3"

# 打印请求信息
echo "🔍 请求URL: https://$AZURE_REGION.tts.speech.microsoft.com/cognitiveservices/v1"
echo "🔍 请求头:"
echo "   Content-Type: application/ssml+xml"
echo "   Ocp-Apim-Subscription-Key: $AZURE_KEY"
echo "   X-Microsoft-OutputFormat: audio-16khz-128kbitrate-mono-mp3"
echo "🔍 请求体: $SSML"

# 发送请求
echo "📤 发送Azure语音合成请求..."
curl -v -X POST \
  "https://$AZURE_REGION.tts.speech.microsoft.com/cognitiveservices/v1" \
  -H "Content-Type: application/ssml+xml" \
  -H "Ocp-Apim-Subscription-Key: $AZURE_KEY" \
  -H "X-Microsoft-OutputFormat: audio-16khz-128kbitrate-mono-mp3" \
  -d "$SSML" \
  -o "$OUTPUT_FILE" 2>&1

# 检查结果
if [ $? -eq 0 ]; then
  FILE_SIZE=$(stat -f%z "$OUTPUT_FILE")
  if [ $FILE_SIZE -gt 1000 ]; then
    echo "✅ 语音合成成功!"
    echo "📊 音频文件大小: $FILE_SIZE 字节"
    echo "💾 音频文件已保存至: $OUTPUT_FILE"
  else
    echo "❌ 音频文件大小异常: $FILE_SIZE 字节"
    cat "$OUTPUT_FILE"
  fi
else
  echo "❌ 请求失败"
fi 