#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # 无颜色

# 默认参数
APP_NAME="BaoBao"
SAMPLE_INTERVAL=2
DURATION=300  # 默认监控5分钟
OUTPUT_DIR="$HOME/Desktop/CloudKit性能报告_$(date +%Y%m%d_%H%M%S)"
IS_SIMULATOR=false
DEVICE_ID=""
SHOW_NETWORK=true

# 解析参数
while [[ $# -gt 0 ]]; do
  case $1 in
    -a|--app)
      APP_NAME="$2"
      shift 2
      ;;
    -i|--interval)
      SAMPLE_INTERVAL="$2"
      shift 2
      ;;
    -d|--duration)
      DURATION="$2"
      shift 2
      ;;
    -o|--output)
      OUTPUT_DIR="$2"
      shift 2
      ;;
    -s|--simulator)
      IS_SIMULATOR=true
      shift
      ;;
    -id|--device-id)
      DEVICE_ID="$2"
      shift 2
      ;;
    -nn|--no-network)
      SHOW_NETWORK=false
      shift
      ;;
    -h|--help)
      echo "使用方法: $0 [选项]"
      echo "选项:"
      echo "  -a, --app APP_NAME      要监控的应用名称 (默认: BaoBao)"
      echo "  -i, --interval SECONDS  采样间隔，单位秒 (默认: 2)"
      echo "  -d, --duration SECONDS  监控持续时间，单位秒 (默认: 300)"
      echo "  -o, --output DIR        输出目录 (默认: ~/Desktop/CloudKit性能报告_日期时间)"
      echo "  -s, --simulator         监控模拟器而非真机"
      echo "  -id, --device-id ID     指定设备ID (当连接多个设备时必须)"
      echo "  -nn, --no-network       不监控网络活动"
      echo "  -h, --help              显示帮助信息"
      exit 0
      ;;
    *)
      echo -e "${RED}未知参数: $1${NC}"
      exit 1
      ;;
  esac
done

# 验证所需工具
function check_tools {
    local missing_tools=false
    
    # 检查必要工具
    if ! command -v instruments &> /dev/null; then
        echo -e "${RED}错误: 未找到 instruments 命令. 请确保已安装Xcode和命令行工具.${NC}"
        missing_tools=true
    fi
    
    if ! command -v xcrun &> /dev/null; then
        echo -e "${RED}错误: 未找到 xcrun 命令. 请确保已安装Xcode和命令行工具.${NC}"
        missing_tools=true
    fi
    
    if $IS_SIMULATOR && ! command -v simctl &> /dev/null; then
        echo -e "${RED}错误: 未找到 simctl 命令. 请确保已安装Xcode和命令行工具.${NC}"
        missing_tools=true
    fi
    
    if ! command -v awk &> /dev/null || ! command -v grep &> /dev/null; then
        echo -e "${RED}错误: 基本文本处理工具不可用.${NC}"
        missing_tools=true
    fi
    
    if $missing_tools; then
        exit 1
    fi
}

# 选择设备
function select_device {
    if $IS_SIMULATOR; then
        # 查询并选择可用的模拟器
        echo -e "${YELLOW}可用的模拟器:${NC}"
        xcrun simctl list devices available | grep -v "^--" | grep -v "^$" | grep -v "Devices"
        
        if [ -z "$DEVICE_ID" ]; then
            echo -e "${YELLOW}请输入要使用的模拟器UDID:${NC}"
            read -r DEVICE_ID
            if [ -z "$DEVICE_ID" ]; then
                echo -e "${RED}未提供设备ID，退出${NC}"
                exit 1
            fi
        fi
        
        # 启动模拟器
        echo -e "${BLUE}启动模拟器...${NC}"
        xcrun simctl boot "$DEVICE_ID" || true  # 如果已启动，忽略错误
        
        DEVICE_ARG="-w $DEVICE_ID"
    else
        # 列出已连接的设备
        echo -e "${YELLOW}已连接的设备:${NC}"
        instruments -s devices | grep -v "^Known Devices:" | grep -v Simulator
        
        if [ -z "$DEVICE_ID" ]; then
            # 如果只有一个设备，自动选择
            DEVICE_COUNT=$(instruments -s devices | grep -v "^Known Devices:" | grep -v Simulator | wc -l)
            if [ "$DEVICE_COUNT" -eq 1 ]; then
                DEVICE_ID=$(instruments -s devices | grep -v "^Known Devices:" | grep -v Simulator | awk -F'[()]' '{print $2}')
                echo -e "${GREEN}自动选择设备: $DEVICE_ID${NC}"
            else
                echo -e "${YELLOW}请输入要使用的设备ID:${NC}"
                read -r DEVICE_ID
                if [ -z "$DEVICE_ID" ]; then
                    echo -e "${RED}未提供设备ID，退出${NC}"
                    exit 1
                fi
            fi
        fi
        
        DEVICE_ARG="-w $DEVICE_ID"
    fi
}

# 创建输出目录
function create_output_directory {
    mkdir -p "$OUTPUT_DIR"
    echo -e "${GREEN}将保存报告到: $OUTPUT_DIR${NC}"
}

# 获取应用进程ID
function get_app_pid {
    if $IS_SIMULATOR; then
        # 先启动应用
        echo -e "${BLUE}启动应用 $APP_NAME 在模拟器上...${NC}"
        xcrun simctl launch "$DEVICE_ID" "com.example.$APP_NAME" || {
            echo -e "${RED}启动应用失败。请确认应用程序包ID正确，且应用已安装在模拟器上。${NC}"
            echo -e "${YELLOW}提示: 应用程序包ID可能不是 com.example.$APP_NAME，请根据实际情况修改脚本。${NC}"
            exit 1
        }
        
        # 获取PID
        APP_PID=$(xcrun simctl spawn "$DEVICE_ID" launchctl list | grep "$APP_NAME" | awk '{print $1}')
    else
        echo -e "${YELLOW}请确保 $APP_NAME 应用正在设备上运行${NC}"
        echo -e "${YELLOW}请手动在设备上启动应用，然后按回车继续...${NC}"
        read -r
        
        # 在真机上无法直接获取PID，我们将使用instruments来监控整个应用
        APP_PID=""
    fi
    
    if [ -z "$APP_PID" ] && ! $IS_SIMULATOR; then
        echo -e "${YELLOW}无法获取应用PID，将监控整个应用性能${NC}"
    else
        echo -e "${GREEN}应用 $APP_NAME 的PID: $APP_PID${NC}"
    fi
}

# 开始性能监控
function start_monitoring {
    local end_time=$(($(date +%s) + DURATION))
    local current_time=$(date +%s)
    
    # 开始时间
    START_TIME=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${BLUE}开始监控 $APP_NAME 在 $START_TIME, 将持续 $DURATION 秒${NC}"
    
    # CPU和内存日志文件
    CPU_LOG="$OUTPUT_DIR/cpu_usage.csv"
    MEMORY_LOG="$OUTPUT_DIR/memory_usage.csv"
    
    # 创建日志文件头
    echo "时间戳,CPU使用率(%)" > "$CPU_LOG"
    echo "时间戳,内存使用(MB)" > "$MEMORY_LOG"
    
    # 如果启用了网络监控
    if $SHOW_NETWORK; then
        NETWORK_LOG="$OUTPUT_DIR/network_activity.csv"
        echo "时间戳,接收(KB/s),发送(KB/s)" > "$NETWORK_LOG"
    fi
    
    # 启动时间点记录器
    EVENT_LOG="$OUTPUT_DIR/events.log"
    echo "CloudKit性能监控事件日志" > "$EVENT_LOG"
    echo "开始时间: $START_TIME" >> "$EVENT_LOG"
    echo "----------------------------------------" >> "$EVENT_LOG"
    
    echo -e "${YELLOW}监控已开始. 按 'e' 然后回车记录事件, 按 'q' 然后回车结束监控.${NC}"
    
    # 在后台启动采样
    {
        while [ $(date +%s) -lt $end_time ]; do
            TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
            
            if $IS_SIMULATOR && [ ! -z "$APP_PID" ]; then
                # 模拟器: 使用simctl获取进程信息
                CPU_USAGE=$(xcrun simctl spawn "$DEVICE_ID" ps -o %cpu -p "$APP_PID" | tail -n 1 | tr -d ' ')
                MEM_USAGE=$(xcrun simctl spawn "$DEVICE_ID" ps -o rss -p "$APP_PID" | tail -n 1 | tr -d ' ')
                MEM_USAGE_MB=$(echo "scale=2; $MEM_USAGE / 1024" | bc)
            else
                # 真机: 使用instruments进行一次性采样
                SAMPLE_OUTPUT=$(instruments -s -w "$DEVICE_ID" -l 1 -t "Activity Monitor" "$APP_NAME" 2>&1)
                CPU_USAGE=$(echo "$SAMPLE_OUTPUT" | grep "CPU:" | awk '{print $2}' | tr -d '%')
                MEM_USAGE=$(echo "$SAMPLE_OUTPUT" | grep "Memory:" | awk '{print $2}' | tr -d 'MB')
                MEM_USAGE_MB=$MEM_USAGE
            fi
            
            # 记录CPU和内存使用情况
            echo "$TIMESTAMP,$CPU_USAGE" >> "$CPU_LOG"
            echo "$TIMESTAMP,$MEM_USAGE_MB" >> "$MEMORY_LOG"
            
            # 如果启用了网络监控
            if $SHOW_NETWORK; then
                if $IS_SIMULATOR; then
                    # 模拟器网络监控 (受限功能)
                    RX_BYTES="N/A"
                    TX_BYTES="N/A"
                else
                    # 尝试获取网络使用情况 (需要权限)
                    NET_OUTPUT=$(instruments -s -w "$DEVICE_ID" -l 1 -t "Network" "$APP_NAME" 2>&1)
                    RX_BYTES=$(echo "$NET_OUTPUT" | grep "Data Received:" | awk '{print $3}' | tr -d 'KB/s')
                    TX_BYTES=$(echo "$NET_OUTPUT" | grep "Data Sent:" | awk '{print $3}' | tr -d 'KB/s')
                fi
                echo "$TIMESTAMP,$RX_BYTES,$TX_BYTES" >> "$NETWORK_LOG"
            fi
            
            sleep "$SAMPLE_INTERVAL"
        done
    } &
    SAMPLER_PID=$!
    
    # 等待用户输入
    while [ $(date +%s) -lt $end_time ]; do
        read -t 1 -n 1 KEY
        if [ "$KEY" = "q" ]; then
            break
        elif [ "$KEY" = "e" ]; then
            EVENT_TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
            echo -e "${YELLOW}请输入事件描述:${NC}"
            read EVENT_DESC
            echo "$EVENT_TIMESTAMP: $EVENT_DESC" >> "$EVENT_LOG"
            echo -e "${GREEN}事件已记录${NC}"
        fi
    done
    
    # 结束采样
    kill $SAMPLER_PID 2>/dev/null || true
    
    # 记录结束时间
    END_TIME=$(date "+%Y-%m-%d %H:%M:%S")
    echo "结束时间: $END_TIME" >> "$EVENT_LOG"
    
    echo -e "${GREEN}监控已完成!${NC}"
}

# 生成报告
function generate_report {
    echo -e "${BLUE}正在生成性能报告...${NC}"
    
    # 生成HTML报告
    REPORT_HTML="$OUTPUT_DIR/performance_report.html"
    
    # 创建基本HTML
    cat > "$REPORT_HTML" << EOF
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>CloudKit同步性能报告</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1, h2 { color: #333; }
        .summary { background-color: #f5f5f5; padding: 15px; border-radius: 5px; margin-bottom: 20px; }
        .chart { margin: 20px 0; width: 100%; height: 400px; }
        table { border-collapse: collapse; width: 100%; margin: 20px 0; }
        th, td { border: 1px solid #ddd; padding: 8px; text-align: left; }
        th { background-color: #f2f2f2; }
        .event-log { background-color: #f9f9f9; padding: 10px; border-radius: 5px; white-space: pre-wrap; }
    </style>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
</head>
<body>
    <h1>CloudKit同步性能报告</h1>
    
    <div class="summary">
        <h2>监控概要</h2>
        <p><strong>应用名称:</strong> $APP_NAME</p>
        <p><strong>监控开始时间:</strong> $START_TIME</p>
        <p><strong>监控结束时间:</strong> $END_TIME</p>
        <p><strong>采样间隔:</strong> $SAMPLE_INTERVAL 秒</p>
    </div>
    
    <div class="chart-container">
        <h2>CPU使用率</h2>
        <canvas id="cpuChart" class="chart"></canvas>
    </div>
    
    <div class="chart-container">
        <h2>内存使用情况</h2>
        <canvas id="memChart" class="chart"></canvas>
    </div>
EOF

    # 如果有网络数据，添加网络图表
    if $SHOW_NETWORK && [ -f "$NETWORK_LOG" ]; then
        cat >> "$REPORT_HTML" << EOF
    <div class="chart-container">
        <h2>网络活动</h2>
        <canvas id="netChart" class="chart"></canvas>
    </div>
EOF
    fi

    # 添加事件日志
    cat >> "$REPORT_HTML" << EOF
    <h2>事件日志</h2>
    <pre class="event-log">$(cat "$EVENT_LOG")</pre>
    
    <script>
        // 准备图表数据
        const cpuData = [];
        const memData = [];
EOF

    # 如果有网络数据，准备网络数据
    if $SHOW_NETWORK && [ -f "$NETWORK_LOG" ]; then
        cat >> "$REPORT_HTML" << EOF
        const rxData = [];
        const txData = [];
EOF
    fi

    cat >> "$REPORT_HTML" << EOF
        const timeLabels = [];
        
        // 读取CSV数据
        const cpuCsv = \`$(cat "$CPU_LOG" | tail -n +2)\`;
        const memCsv = \`$(cat "$MEMORY_LOG" | tail -n +2)\`;
EOF

    # 如果有网络数据，读取网络数据
    if $SHOW_NETWORK && [ -f "$NETWORK_LOG" ]; then
        cat >> "$REPORT_HTML" << EOF
        const netCsv = \`$(cat "$NETWORK_LOG" | tail -n +2)\`;
EOF
    fi

    cat >> "$REPORT_HTML" << EOF
        
        // 解析CPU数据
        cpuCsv.split('\\n').forEach(line => {
            if (line.trim() !== '') {
                const [timestamp, cpuValue] = line.split(',');
                timeLabels.push(timestamp);
                cpuData.push(parseFloat(cpuValue));
            }
        });
        
        // 解析内存数据
        memCsv.split('\\n').forEach(line => {
            if (line.trim() !== '') {
                const [timestamp, memValue] = line.split(',');
                memData.push(parseFloat(memValue));
            }
        });
EOF

    # 如果有网络数据，解析网络数据
    if $SHOW_NETWORK && [ -f "$NETWORK_LOG" ]; then
        cat >> "$REPORT_HTML" << EOF
        
        // 解析网络数据
        netCsv.split('\\n').forEach(line => {
            if (line.trim() !== '') {
                const [timestamp, rxValue, txValue] = line.split(',');
                rxData.push(rxValue === 'N/A' ? 0 : parseFloat(rxValue));
                txData.push(txValue === 'N/A' ? 0 : parseFloat(txValue));
            }
        });
EOF
    fi

    cat >> "$REPORT_HTML" << EOF
        
        // 创建CPU图表
        new Chart(document.getElementById('cpuChart'), {
            type: 'line',
            data: {
                labels: timeLabels,
                datasets: [{
                    label: 'CPU使用率 (%)',
                    data: cpuData,
                    borderColor: 'rgb(75, 192, 192)',
                    tension: 0.1,
                    fill: false
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true,
                        suggestedMax: 100
                    }
                }
            }
        });
        
        // 创建内存图表
        new Chart(document.getElementById('memChart'), {
            type: 'line',
            data: {
                labels: timeLabels,
                datasets: [{
                    label: '内存使用 (MB)',
                    data: memData,
                    borderColor: 'rgb(153, 102, 255)',
                    tension: 0.1,
                    fill: false
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
EOF

    # 如果有网络数据，创建网络图表
    if $SHOW_NETWORK && [ -f "$NETWORK_LOG" ]; then
        cat >> "$REPORT_HTML" << EOF
        
        // 创建网络图表
        new Chart(document.getElementById('netChart'), {
            type: 'line',
            data: {
                labels: timeLabels,
                datasets: [{
                    label: '接收 (KB/s)',
                    data: rxData,
                    borderColor: 'rgb(255, 99, 132)',
                    tension: 0.1,
                    fill: false
                }, {
                    label: '发送 (KB/s)',
                    data: txData,
                    borderColor: 'rgb(54, 162, 235)',
                    tension: 0.1,
                    fill: false
                }]
            },
            options: {
                responsive: true,
                scales: {
                    y: {
                        beginAtZero: true
                    }
                }
            }
        });
EOF
    fi

    cat >> "$REPORT_HTML" << EOF
    </script>
</body>
</html>
EOF

    echo -e "${GREEN}报告已生成: $REPORT_HTML${NC}"
    
    # 提示用户
    echo -e "${YELLOW}你可以使用浏览器打开生成的HTML报告查看详细的性能分析。${NC}"
    echo -e "${YELLOW}原始数据已保存在CSV文件中，可以用电子表格软件进一步分析。${NC}"
}

# 主函数
function main {
    echo -e "${BLUE}=====================================${NC}"
    echo -e "${BLUE}    CloudKit同步性能监控工具    ${NC}"
    echo -e "${BLUE}=====================================${NC}"
    
    # 检查工具
    check_tools
    
    # 选择设备
    select_device
    
    # 创建输出目录
    create_output_directory
    
    # 获取应用PID
    get_app_pid
    
    # 开始监控
    start_monitoring
    
    # 生成报告
    generate_report
    
    echo -e "${GREEN}CloudKit性能监控完成!${NC}"
    echo -e "${GREEN}结果保存在: $OUTPUT_DIR${NC}"
}

# 执行主函数
main 