// 页面加载完成后执行
document.addEventListener('DOMContentLoaded', function() {
    // 移除底部导航栏相关代码
    
    // 移除设置当前活动标签
    // setActiveTab();
    
    initSidebar();
    initPlayerControls();
    replaceCatIcons();
    
    // 添加toast样式
    const style = document.createElement('style');
    style.textContent = `
        .toast-message {
            position: fixed;
            bottom: 50px;
            left: 50%;
            transform: translateX(-50%);
            background-color: rgba(0, 0, 0, 0.7);
            color: white;
            padding: 12px 20px;
            border-radius: 20px;
            font-size: 16px;
            z-index: 1000;
            opacity: 0;
            transition: opacity 0.3s;
            pointer-events: none;
            max-width: 80%;
            text-align: center;
        }
        
        .toast-message.show {
            opacity: 1;
        }
    `;
    document.head.appendChild(style);
});

// 移除添加底部导航栏函数
// function addTabBar() { ... }

// 移除设置当前活动标签函数
// function setActiveTab() { ... }

// 显示加载动画
function showLoading() {
    const loading = document.createElement('div');
    loading.className = 'loading';
    loading.id = 'loading';
    
    const spinner = document.createElement('div');
    spinner.className = 'loading-spinner';
    
    loading.appendChild(spinner);
    document.body.appendChild(loading);
}

// 隐藏加载动画
function hideLoading() {
    const loading = document.getElementById('loading');
    if (loading) {
        loading.remove();
    }
}

// 显示Toast消息
function showToast(message, duration = 2000) {
    Logger.debug(`显示Toast消息: "${message}"`);
    
    let toast = document.getElementById('toast');
    
    if (!toast) {
        toast = document.createElement('div');
        toast.id = 'toast';
        toast.style.cssText = 'position: fixed; bottom: 80px; left: 50%; transform: translateX(-50%); background-color: rgba(0,0,0,0.7); color: white; padding: 10px 20px; border-radius: 20px; z-index: 9999; font-size: 16px; transition: opacity 0.3s; opacity: 0;';
        document.body.appendChild(toast);
    }
    
    // 清除之前的定时器
    if (toast.timeoutId) {
        clearTimeout(toast.timeoutId);
    }
    
    // 设置消息内容
    toast.textContent = message;
    
    // 显示Toast
    setTimeout(() => {
        toast.style.opacity = '1';
    }, 10);
    
    // 设置定时器隐藏Toast
    toast.timeoutId = setTimeout(() => {
        toast.style.opacity = '0';
    }, duration);
}

// 播放简单的动画效果
function playAnimation(element, animationClass, duration = 1000) {
    element.classList.add(animationClass);
    
    setTimeout(() => {
        element.classList.remove(animationClass);
    }, duration);
}

// 创建可爱的动物图标
function createAnimalIcon(animalType, color = '#FF9A9E') {
    let svgContent = '';
    
    switch(animalType) {
        case 'cat':
            svgContent = `
                <circle cx="50" cy="50" r="40" fill="${color}" />
                <circle cx="35" cy="40" r="5" fill="#333" />
                <circle cx="65" cy="40" r="5" fill="#333" />
                <path d="M40,60 Q50,70 60,60" stroke="#333" stroke-width="3" fill="none" />
                <path d="M30,30 L40,20 M70,30 L60,20" stroke="#333" stroke-width="3" fill="none" />
            `;
            break;
        case 'dog':
            svgContent = `
                <circle cx="50" cy="50" r="40" fill="${color}" />
                <circle cx="35" cy="40" r="5" fill="#333" />
                <circle cx="65" cy="40" r="5" fill="#333" />
                <path d="M40,60 Q50,70 60,60" stroke="#333" stroke-width="3" fill="none" />
                <ellipse cx="50" cy="75" rx="15" ry="10" fill="#333" opacity="0.2" />
            `;
            break;
        case 'rabbit':
            svgContent = `
                <circle cx="50" cy="50" r="40" fill="${color}" />
                <circle cx="35" cy="40" r="5" fill="#333" />
                <circle cx="65" cy="40" r="5" fill="#333" />
                <path d="M45,60 Q50,65 55,60" stroke="#333" stroke-width="3" fill="none" />
                <path d="M30,10 Q40,30 30,40 M70,10 Q60,30 70,40" stroke="#333" stroke-width="3" fill="none" />
            `;
            break;
        case 'bear':
            svgContent = `
                <circle cx="50" cy="50" r="40" fill="${color}" />
                <circle cx="35" cy="40" r="6" fill="#333" />
                <circle cx="65" cy="40" r="6" fill="#333" />
                <circle cx="30" cy="25" r="10" fill="${color}" stroke="#333" stroke-width="2" />
                <circle cx="70" cy="25" r="10" fill="${color}" stroke="#333" stroke-width="2" />
                <path d="M40,60 Q50,65 60,60" stroke="#333" stroke-width="3" fill="none" />
            `;
            break;
        default:
            svgContent = `
                <circle cx="50" cy="50" r="40" fill="${color}" />
                <circle cx="35" cy="40" r="5" fill="#333" />
                <circle cx="65" cy="40" r="5" fill="#333" />
                <path d="M40,60 Q50,70 60,60" stroke="#333" stroke-width="3" fill="none" />
            `;
    }
    
    return `<svg viewBox="0 0 100 100" xmlns="http://www.w3.org/2000/svg">${svgContent}</svg>`;
}

// 创建猫咪图标
function createCatIcon() {
    const svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.setAttribute("viewBox", "0 0 100 100");
    svg.setAttribute("width", "100%");
    svg.setAttribute("height", "100%");
    
    // 猫咪头部
    const head = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    head.setAttribute("cx", "50");
    head.setAttribute("cy", "50");
    head.setAttribute("r", "40");
    head.setAttribute("fill", "black");
    
    // 猫咪耳朵
    const leftEar = document.createElementNS("http://www.w3.org/2000/svg", "path");
    leftEar.setAttribute("d", "M30,30 L15,10 L35,15 Z");
    leftEar.setAttribute("fill", "black");
    
    const rightEar = document.createElementNS("http://www.w3.org/2000/svg", "path");
    rightEar.setAttribute("d", "M70,30 L85,10 L65,15 Z");
    rightEar.setAttribute("fill", "black");
    
    // 猫咪眼睛
    const leftEye = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    leftEye.setAttribute("cx", "35");
    leftEye.setAttribute("cy", "40");
    leftEye.setAttribute("r", "10");
    leftEye.setAttribute("fill", "white");
    
    const rightEye = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    rightEye.setAttribute("cx", "65");
    rightEye.setAttribute("cy", "40");
    rightEye.setAttribute("r", "10");
    rightEye.setAttribute("fill", "white");
    
    // 猫咪瞳孔
    const leftPupil = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    leftPupil.setAttribute("cx", "35");
    leftPupil.setAttribute("cy", "40");
    leftPupil.setAttribute("r", "5");
    leftPupil.setAttribute("fill", "black");
    
    const rightPupil = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    rightPupil.setAttribute("cx", "65");
    rightPupil.setAttribute("cy", "40");
    rightPupil.setAttribute("r", "5");
    rightPupil.setAttribute("fill", "black");
    
    // 猫咪鼻子
    const nose = document.createElementNS("http://www.w3.org/2000/svg", "circle");
    nose.setAttribute("cx", "50");
    nose.setAttribute("cy", "55");
    nose.setAttribute("r", "5");
    nose.setAttribute("fill", "#FFD700");
    
    // 猫咪嘴巴
    const mouth = document.createElementNS("http://www.w3.org/2000/svg", "path");
    mouth.setAttribute("d", "M40,65 Q50,75 60,65");
    mouth.setAttribute("stroke", "white");
    mouth.setAttribute("stroke-width", "2");
    mouth.setAttribute("fill", "none");
    
    // 添加所有元素到SVG
    svg.appendChild(head);
    svg.appendChild(leftEar);
    svg.appendChild(rightEar);
    svg.appendChild(leftEye);
    svg.appendChild(rightEye);
    svg.appendChild(leftPupil);
    svg.appendChild(rightPupil);
    svg.appendChild(nose);
    svg.appendChild(mouth);
    
    return svg;
}

// 初始化侧边栏
function initSidebar() {
    const toggleSidebar = document.getElementById('toggleSidebar');
    const sidebar = document.getElementById('sidebar');
    const overlay = document.getElementById('overlay');
    
    if (toggleSidebar && sidebar && overlay) {
        toggleSidebar.addEventListener('click', () => {
            sidebar.classList.toggle('open');
            overlay.classList.toggle('open');
        });
        
        overlay.addEventListener('click', () => {
            sidebar.classList.remove('open');
            overlay.classList.remove('open');
        });
    }
}

// 初始化播放控制
function initPlayerControls() {
    const playBtn = document.querySelector('.play-btn');
    if (playBtn) {
        playBtn.addEventListener('click', () => {
            const icon = playBtn.querySelector('i');
            if (icon.classList.contains('fa-play')) {
                icon.classList.remove('fa-play');
                icon.classList.add('fa-pause');
            } else {
                icon.classList.remove('fa-pause');
                icon.classList.add('fa-play');
            }
        });
    }
    
    const musicToggle = document.getElementById('musicToggle');
    if (musicToggle) {
        musicToggle.addEventListener('click', () => {
            musicToggle.classList.toggle('off');
        });
    }
}

// 替换猫咪图标占位符
function replaceCatIcons() {
    document.querySelectorAll('.membership-icon').forEach(img => {
        if (img.src.includes('placeholder')) {
            const container = img.parentElement;
            img.style.display = 'none';
            const catIcon = createCatIcon();
            container.insertBefore(catIcon, img);
        }
    });
}

// 宝宝故事APP通用JavaScript函数库

// 全局日志系统
const Logger = {
    // 日志级别
    LEVELS: {
        DEBUG: 0,
        INFO: 1,
        WARN: 2,
        ERROR: 3
    },
    
    // 当前日志级别
    currentLevel: 0, // 默认为DEBUG级别
    
    // 是否在控制台显示日志
    consoleOutput: true,
    
    // 是否在页面上显示日志
    pageOutput: false,
    
    // 日志容器元素ID
    containerId: 'globalLogContainer',
    
    // 初始化日志系统
    init: function(options = {}) {
        console.log('[Logger] 初始化日志系统');
        
        // 设置日志级别
        if (options.level !== undefined) {
            this.currentLevel = options.level;
        } else {
            // 根据URL参数设置日志级别
            const urlParams = new URLSearchParams(window.location.search);
            if (urlParams.has('logLevel')) {
                const levelName = urlParams.get('logLevel').toUpperCase();
                if (this.LEVELS[levelName] !== undefined) {
                    this.currentLevel = this.LEVELS[levelName];
                }
            }
        }
        
        // 设置是否在页面上显示日志
        if (options.pageOutput !== undefined) {
            this.pageOutput = options.pageOutput;
        } else {
            // 根据URL参数设置是否在页面上显示日志
            const urlParams = new URLSearchParams(window.location.search);
            this.pageOutput = urlParams.has('debug') && urlParams.get('debug') !== 'false';
        }
        
        // 如果需要在页面上显示日志，创建日志容器
        if (this.pageOutput) {
            this.createLogContainer();
        }
        
        // 设置全局错误处理
        this.setupErrorHandling();
        
        console.log(`[Logger] 日志系统初始化完成，级别: ${Object.keys(this.LEVELS)[this.currentLevel]}, 页面输出: ${this.pageOutput}`);
    },
    
    // 创建日志容器
    createLogContainer: function() {
        // 检查是否已存在日志容器
        if (document.getElementById(this.containerId)) {
            return;
        }
        
        // 创建日志容器
        const container = document.createElement('div');
        container.id = this.containerId;
        container.style.cssText = 'position: fixed; bottom: 0; left: 0; right: 0; height: 200px; background: rgba(0,0,0,0.8); color: white; overflow-y: auto; z-index: 9999; font-family: monospace; font-size: 12px; padding: 10px; display: none;';
        
        // 创建日志控制栏
        const controlBar = document.createElement('div');
        controlBar.style.cssText = 'position: absolute; top: 0; left: 0; right: 0; height: 30px; background: #333; display: flex; justify-content: space-between; align-items: center; padding: 0 10px;';
        
        // 创建标题
        const title = document.createElement('div');
        title.textContent = '日志控制台';
        title.style.cssText = 'font-weight: bold;';
        
        // 创建按钮组
        const buttonGroup = document.createElement('div');
        
        // 创建清除按钮
        const clearButton = document.createElement('button');
        clearButton.textContent = '清除';
        clearButton.style.cssText = 'background: #555; color: white; border: none; padding: 3px 8px; margin-right: 5px; cursor: pointer; border-radius: 3px;';
        clearButton.onclick = () => this.clearLogs();
        
        // 创建关闭按钮
        const closeButton = document.createElement('button');
        closeButton.textContent = '关闭';
        closeButton.style.cssText = 'background: #555; color: white; border: none; padding: 3px 8px; cursor: pointer; border-radius: 3px;';
        closeButton.onclick = () => this.toggleLogDisplay();
        
        // 添加按钮到按钮组
        buttonGroup.appendChild(clearButton);
        buttonGroup.appendChild(closeButton);
        
        // 添加标题和按钮组到控制栏
        controlBar.appendChild(title);
        controlBar.appendChild(buttonGroup);
        
        // 创建日志内容区域
        const logContent = document.createElement('div');
        logContent.id = `${this.containerId}-content`;
        logContent.style.cssText = 'margin-top: 30px; padding: 5px;';
        
        // 添加控制栏和内容区域到容器
        container.appendChild(controlBar);
        container.appendChild(logContent);
        
        // 添加容器到页面
        document.body.appendChild(container);
        
        // 添加样式
        const style = document.createElement('style');
        style.textContent = `
            .log-entry { margin-bottom: 5px; border-bottom: 1px solid #333; padding-bottom: 5px; }
            .log-debug { color: #8bc34a; }
            .log-info { color: #03a9f4; }
            .log-warn { color: #ffbc00; }
            .log-error { color: #ff5252; }
            
            .log-toggle-button {
                position: fixed;
                bottom: 10px;
                right: 10px;
                width: 40px;
                height: 40px;
                background: rgba(0,0,0,0.7);
                color: white;
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                cursor: pointer;
                z-index: 9998;
                font-size: 20px;
                border: none;
            }
        `;
        document.head.appendChild(style);
        
        // 创建日志切换按钮
        const toggleButton = document.createElement('button');
        toggleButton.className = 'log-toggle-button';
        toggleButton.innerHTML = '📋';
        toggleButton.title = '显示/隐藏日志';
        toggleButton.onclick = () => this.toggleLogDisplay();
        document.body.appendChild(toggleButton);
    },
    
    // 切换日志显示状态
    toggleLogDisplay: function() {
        const container = document.getElementById(this.containerId);
        if (container) {
            if (container.style.display === 'none') {
                container.style.display = 'block';
            } else {
                container.style.display = 'none';
            }
        }
    },
    
    // 清除日志
    clearLogs: function() {
        const logContent = document.getElementById(`${this.containerId}-content`);
        if (logContent) {
            logContent.innerHTML = '';
        }
    },
    
    // 设置全局错误处理
    setupErrorHandling: function() {
        // 捕获全局错误
        window.onerror = (message, source, lineno, colno, error) => {
            this.error(`全局错误: ${message} (${source}:${lineno}:${colno})`);
            if (error && error.stack) {
                this.error(`错误堆栈: ${error.stack}`);
            }
            return false;
        };
        
        // 捕获未处理的Promise错误
        window.addEventListener('unhandledrejection', (event) => {
            this.error(`未处理的Promise错误: ${event.reason}`);
        });
    },
    
    // 记录日志
    log: function(message, level = 'info', module = 'APP') {
        // 检查日志级别
        const levelValue = this.LEVELS[level.toUpperCase()] || this.LEVELS.INFO;
        if (levelValue < this.currentLevel) {
            return;
        }
        
        // 格式化日志消息
        const timestamp = new Date().toISOString();
        const prefix = `[${timestamp}][${module}][${level.toUpperCase()}]`;
        const formattedMessage = `${prefix} ${message}`;
        
        // 输出到控制台
        if (this.consoleOutput) {
            switch (level.toLowerCase()) {
                case 'debug':
                    console.debug(formattedMessage);
                    break;
                case 'warn':
                    console.warn(formattedMessage);
                    break;
                case 'error':
                    console.error(formattedMessage);
                    break;
                default:
                    console.log(formattedMessage);
            }
        }
        
        // 输出到页面
        if (this.pageOutput) {
            const logContent = document.getElementById(`${this.containerId}-content`);
            if (logContent) {
                const logEntry = document.createElement('div');
                logEntry.className = `log-entry log-${level.toLowerCase()}`;
                logEntry.textContent = formattedMessage;
                logContent.appendChild(logEntry);
                
                // 保持滚动到最新日志
                logContent.scrollTop = logContent.scrollHeight;
            }
        }
    },
    
    // 便捷日志方法
    debug: function(message, module = 'APP') {
        this.log(message, 'debug', module);
    },
    
    info: function(message, module = 'APP') {
        this.log(message, 'info', module);
    },
    
    warn: function(message, module = 'APP') {
        this.log(message, 'warn', module);
    },
    
    error: function(message, module = 'APP') {
        this.log(message, 'error', module);
    }
};

// 页面加载性能监控
const PerformanceMonitor = {
    metrics: {},
    
    init: function() {
        Logger.debug('初始化性能监控', 'PERF');
        
        // 记录页面加载时间
        window.addEventListener('load', () => {
            this.recordPageLoadMetrics();
        });
    },
    
    recordPageLoadMetrics: function() {
        if (!window.performance) {
            Logger.warn('浏览器不支持Performance API', 'PERF');
            return;
        }
        
        // 获取性能指标
        const perfData = window.performance.timing;
        const pageLoadTime = perfData.loadEventEnd - perfData.navigationStart;
        const domReadyTime = perfData.domComplete - perfData.domLoading;
        const networkLatency = perfData.responseEnd - perfData.requestStart;
        
        // 记录指标
        this.metrics = {
            pageLoadTime,
            domReadyTime,
            networkLatency
        };
        
        Logger.info(`页面加载完成，总耗时: ${pageLoadTime}ms`, 'PERF');
        Logger.debug(`DOM处理时间: ${domReadyTime}ms, 网络延迟: ${networkLatency}ms`, 'PERF');
        
        // 如果加载时间过长，记录警告
        if (pageLoadTime > 3000) {
            Logger.warn(`页面加载时间过长: ${pageLoadTime}ms`, 'PERF');
        }
    },
    
    getMetrics: function() {
        return this.metrics;
    }
};

// 设备信息检测
const DeviceDetector = {
    info: {},
    
    init: function() {
        Logger.debug('初始化设备检测', 'DEVICE');
        
        this.detectDevice();
    },
    
    detectDevice: function() {
        const ua = navigator.userAgent;
        const platform = navigator.platform;
        
        // 检测设备类型
        const isMobile = /Android|webOS|iPhone|iPad|iPod|BlackBerry|IEMobile|Opera Mini/i.test(ua);
        const isIOS = /iPad|iPhone|iPod/.test(ua) && !window.MSStream;
        const isAndroid = /Android/i.test(ua);
        
        // 检测浏览器
        const isChrome = /Chrome/i.test(ua) && !/Edge/i.test(ua);
        const isSafari = /Safari/i.test(ua) && !/Chrome/i.test(ua);
        const isFirefox = /Firefox/i.test(ua);
        const isEdge = /Edge/i.test(ua);
        
        // 检测屏幕信息
        const screenWidth = window.screen.width;
        const screenHeight = window.screen.height;
        const pixelRatio = window.devicePixelRatio || 1;
        
        // 存储设备信息
        this.info = {
            userAgent: ua,
            platform,
            isMobile,
            isIOS,
            isAndroid,
            browser: {
                isChrome,
                isSafari,
                isFirefox,
                isEdge
            },
            screen: {
                width: screenWidth,
                height: screenHeight,
                pixelRatio
            }
        };
        
        Logger.info(`设备检测完成: ${isMobile ? '移动设备' : '桌面设备'}, ${isIOS ? 'iOS' : isAndroid ? 'Android' : '其他系统'}`, 'DEVICE');
        Logger.debug(`屏幕: ${screenWidth}x${screenHeight}, 像素比: ${pixelRatio}`, 'DEVICE');
    },
    
    getInfo: function() {
        return this.info;
    }
};

// 页面初始化
document.addEventListener('DOMContentLoaded', function() {
    // 初始化日志系统
    Logger.init();
    
    // 初始化性能监控
    PerformanceMonitor.init();
    
    // 初始化设备检测
    DeviceDetector.init();
    
    Logger.info('页面初始化完成');
});

// 导出全局对象
window.Logger = Logger;
window.showToast = showToast;
window.PerformanceMonitor = PerformanceMonitor;
window.DeviceDetector = DeviceDetector; 