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

/**
 * 显示Toast通知
 * @param {string} message - 要显示的消息
 * @param {number} duration - 显示时长（毫秒）
 */
function showToast(message, duration = 2000) {
    // 获取或创建toast元素
    let toast = document.getElementById('toast');
    if (!toast) {
        toast = document.createElement('div');
        toast.id = 'toast';
        toast.className = 'toast';
        document.body.appendChild(toast);
    }
    
    // 设置消息
    toast.textContent = message;
    
    // 显示toast
    setTimeout(() => {
        toast.classList.add('show');
    }, 10);
    
    // 设置定时器，隐藏toast
    clearTimeout(toast.hideTimeout);
    toast.hideTimeout = setTimeout(() => {
        toast.classList.remove('show');
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
        
        // 为侧边栏中的宝宝管理项添加点击事件
        const babyManagementItem = document.querySelector('.sidebar-item[href="baby_management.html"]');
        if (babyManagementItem) {
            babyManagementItem.addEventListener('click', (e) => {
                e.preventDefault();
                window.location.href = 'baby_management.html';
                sidebar.classList.remove('open');
                overlay.classList.remove('open');
            });
        }
        
        // 为侧边栏中的用户资料项添加点击事件
        const profileItem = document.querySelector('.sidebar-item[href="profile.html"]');
        if (profileItem) {
            profileItem.addEventListener('click', (e) => {
                e.preventDefault();
                window.location.href = 'profile.html';
                sidebar.classList.remove('open');
                overlay.classList.remove('open');
            });
        }
        
        // 为侧边栏头部的宝宝名称添加点击事件
        const sidebarHeader = document.querySelector('.sidebar-header');
        if (sidebarHeader) {
            sidebarHeader.addEventListener('click', () => {
                window.location.href = 'baby_management.html';
                sidebar.classList.remove('open');
                overlay.classList.remove('open');
            });
        }
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

/**
 * 记录日志
 * @param {string} message - 日志消息
 * @param {string} level - 日志级别（info, warn, error, debug）
 */
function log(message, level = 'info') {
    const timestamp = new Date().toLocaleTimeString();
    const prefix = `[${timestamp}] [${level.toUpperCase()}]`;
    
    // 控制台输出
    switch (level) {
        case 'error':
            console.error(`${prefix} ${message}`);
            break;
        case 'warn':
            console.warn(`${prefix} ${message}`);
            break;
        case 'debug':
            console.debug(`${prefix} ${message}`);
            break;
        default:
            console.log(`${prefix} ${message}`);
    }
    
    // 如果在iOS环境中，发送日志到原生代码
    try {
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.log) {
            window.webkit.messageHandlers.log.postMessage({
                level: level,
                message: message
            });
        }
    } catch (e) {
        console.warn(`无法发送日志到原生代码: ${e.message}`);
    }
}

/**
 * 显示提示消息
 * @param {string} message - 提示消息内容
 * @param {number} duration - 显示时长（毫秒）
 */
function showToast(message, duration = 2000) {
    // 检查是否已存在Toast元素
    let toast = document.getElementById('commonToast');
    
    if (!toast) {
        // 创建Toast元素
        toast = document.createElement('div');
        toast.id = 'commonToast';
        toast.style.position = 'fixed';
        toast.style.bottom = '30px';
        toast.style.left = '50%';
        toast.style.transform = 'translateX(-50%)';
        toast.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
        toast.style.color = 'white';
        toast.style.padding = '12px 20px';
        toast.style.borderRadius = '20px';
        toast.style.fontSize = '14px';
        toast.style.zIndex = '10000';
        toast.style.transition = 'opacity 0.3s';
        toast.style.opacity = '0';
        
        // 添加到页面
        document.body.appendChild(toast);
    }
    
    // 设置消息文本
    toast.textContent = message;
    
    // 显示Toast
    toast.style.opacity = '1';
    
    // 设置定时器，自动隐藏Toast
    clearTimeout(toast.hideTimeout);
    toast.hideTimeout = setTimeout(() => {
        toast.style.opacity = '0';
    }, duration);
}

/**
 * 显示加载提示
 * @param {string} message - 加载提示消息
 */
function showLoading(message = '加载中...') {
    // 检查是否已存在加载提示元素
    let loadingContainer = document.getElementById('commonLoadingContainer');
    
    if (!loadingContainer) {
        // 创建加载提示元素
        loadingContainer = document.createElement('div');
        loadingContainer.id = 'commonLoadingContainer';
        loadingContainer.style.position = 'fixed';
        loadingContainer.style.top = '0';
        loadingContainer.style.left = '0';
        loadingContainer.style.width = '100%';
        loadingContainer.style.height = '100%';
        loadingContainer.style.backgroundColor = 'rgba(255, 255, 255, 0.9)';
        loadingContainer.style.display = 'flex';
        loadingContainer.style.flexDirection = 'column';
        loadingContainer.style.alignItems = 'center';
        loadingContainer.style.justifyContent = 'center';
        loadingContainer.style.zIndex = '9999';
        
        // 创建加载动画
        const loadingAnimation = document.createElement('div');
        loadingAnimation.style.width = '40px';
        loadingAnimation.style.height = '40px';
        loadingAnimation.style.border = '4px solid #f3f3f3';
        loadingAnimation.style.borderTop = '4px solid #3498db';
        loadingAnimation.style.borderRadius = '50%';
        loadingAnimation.style.animation = 'commonLoadingSpin 1s linear infinite';
        
        // 创建加载文本
        const loadingText = document.createElement('div');
        loadingText.id = 'commonLoadingText';
        loadingText.style.marginTop = '20px';
        loadingText.style.fontSize = '16px';
        loadingText.style.color = '#333';
        
        // 添加动画样式
        const style = document.createElement('style');
        style.textContent = `
            @keyframes commonLoadingSpin {
                0% { transform: rotate(0deg); }
                100% { transform: rotate(360deg); }
            }
        `;
        
        // 添加到页面
        document.head.appendChild(style);
        loadingContainer.appendChild(loadingAnimation);
        loadingContainer.appendChild(loadingText);
        document.body.appendChild(loadingContainer);
    }
    
    // 设置加载文本
    document.getElementById('commonLoadingText').textContent = message;
    
    // 显示加载提示
    loadingContainer.style.display = 'flex';
}

/**
 * 隐藏加载提示
 */
function hideLoading() {
    const loadingContainer = document.getElementById('commonLoadingContainer');
    if (loadingContainer) {
        loadingContainer.style.display = 'none';
    }
}

/**
 * 格式化日期
 * @param {Date|string} date - 日期对象或日期字符串
 * @param {string} format - 格式化模板，如 'YYYY-MM-DD HH:mm:ss'
 * @returns {string} 格式化后的日期字符串
 */
function formatDate(date, format = 'YYYY-MM-DD') {
    if (!date) return '';
    
    const d = typeof date === 'string' ? new Date(date) : date;
    
    const year = d.getFullYear();
    const month = String(d.getMonth() + 1).padStart(2, '0');
    const day = String(d.getDate()).padStart(2, '0');
    const hours = String(d.getHours()).padStart(2, '0');
    const minutes = String(d.getMinutes()).padStart(2, '0');
    const seconds = String(d.getSeconds()).padStart(2, '0');
    
    return format
        .replace('YYYY', year)
        .replace('MM', month)
        .replace('DD', day)
        .replace('HH', hours)
        .replace('mm', minutes)
        .replace('ss', seconds);
}

/**
 * 获取URL参数
 * @param {string} name - 参数名
 * @returns {string|null} 参数值，如果不存在则返回null
 */
function getUrlParam(name) {
    const urlParams = new URLSearchParams(window.location.search);
    return urlParams.get(name);
}

/**
 * 截断文本
 * @param {string} text - 原始文本
 * @param {number} maxLength - 最大长度
 * @returns {string} 截断后的文本
 */
function truncateText(text, maxLength = 100) {
    if (!text || text.length <= maxLength) return text;
    return text.substring(0, maxLength) + '...';
}

/**
 * 防抖函数
 * @param {Function} func - 要执行的函数
 * @param {number} wait - 等待时间（毫秒）
 * @returns {Function} 防抖处理后的函数
 */
function debounce(func, wait = 300) {
    let timeout;
    return function(...args) {
        clearTimeout(timeout);
        timeout = setTimeout(() => func.apply(this, args), wait);
    };
}

/**
 * 节流函数
 * @param {Function} func - 要执行的函数
 * @param {number} limit - 限制时间（毫秒）
 * @returns {Function} 节流处理后的函数
 */
function throttle(func, limit = 300) {
    let inThrottle;
    return function(...args) {
        if (!inThrottle) {
            func.apply(this, args);
            inThrottle = true;
            setTimeout(() => inThrottle = false, limit);
        }
    };
}

/**
 * 随机生成ID
 * @returns {string} 随机ID
 */
function generateId() {
    return 'id_' + Math.random().toString(36).substr(2, 9);
}

/**
 * 检查设备类型
 * @returns {Object} 设备类型信息
 */
function getDeviceInfo() {
    const ua = navigator.userAgent;
    const isIOS = /iPad|iPhone|iPod/.test(ua);
    const isAndroid = /Android/.test(ua);
    const isMobile = isIOS || isAndroid || /Mobile/.test(ua);
    const isTablet = /Tablet|iPad/.test(ua) || (isAndroid && !/Mobile/.test(ua));
    
    return {
        isIOS,
        isAndroid,
        isMobile,
        isTablet,
        isDesktop: !isMobile && !isTablet
    };
}

// 导出通用函数
window.showToast = showToast;
window.showLoading = showLoading;
window.hideLoading = hideLoading;
window.formatDate = formatDate;
window.getUrlParam = getUrlParam;
window.truncateText = truncateText;
window.debounce = debounce;
window.throttle = throttle;
window.generateId = generateId;
window.getDeviceInfo = getDeviceInfo; 