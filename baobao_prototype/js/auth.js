// auth.js - 宝宝故事应用认证服务

/**
 * 认证服务 - 处理用户登录、注册和CloudKit同步
 * 提供与iOS原生应用集成的认证功能
 */
const auth = {
    // 当前用户信息
    currentUser: null,
    
    // 认证状态
    authState: {
        isInitialized: false,
        isAuthenticating: false,
        lastError: null,
        cloudKitStatus: 'unknown' // unknown, available, unavailable, syncing
    },
    
    // 初始化认证服务
    init: function() {
        Logger.info('初始化认证服务', 'AUTH');
        
        // 检查是否在iOS环境中
        this.isInIOS = this.checkIsInIOS();
        Logger.debug(`运行环境: ${this.isInIOS ? 'iOS应用内' : 'Web浏览器'}`, 'AUTH');
        
        // 检查本地存储中是否有用户信息
        const savedUser = localStorage.getItem('baobao_user');
        if (savedUser) {
            try {
                this.currentUser = JSON.parse(savedUser);
                Logger.info(`已从本地存储恢复用户登录状态: ${this.currentUser.name}`, 'AUTH');
                
                // 初始化CloudKit同步
                this.initCloudKitSync();
                
                // 触发登录事件
                this.triggerLoginEvent();
                
                this.authState.isInitialized = true;
                return true;
            } catch (error) {
                Logger.error(`解析保存的用户信息失败: ${error.message}`, 'AUTH');
                localStorage.removeItem('baobao_user');
            }
        }
        
        this.authState.isInitialized = true;
        return false;
    },
    
    /**
     * 检查是否在iOS环境中
     * @returns {boolean} 是否在iOS环境中
     */
    checkIsInIOS: function() {
        return window.webkit && 
               window.webkit.messageHandlers && 
               window.webkit.messageHandlers.auth !== undefined;
    },
    
    /**
     * 触发登录事件
     */
    triggerLoginEvent: function() {
        // 触发登录事件
        const event = new CustomEvent('userLogin', { detail: this.currentUser });
        document.dispatchEvent(event);
        
        // 如果在iOS环境中，通知原生应用
        if (this.isInIOS) {
            try {
                window.webkit.messageHandlers.auth.postMessage({
                    action: 'userLoggedIn',
                    user: this.currentUser
                });
                Logger.debug('已通知iOS原生应用用户登录状态', 'AUTH');
            } catch (error) {
                Logger.error(`通知iOS原生应用失败: ${error.message}`, 'AUTH');
            }
        }
        
        // 根据用户是否首次登录决定跳转到哪个页面
        this.handleLoginSuccess();
    },
    
    /**
     * 处理登录成功后的导航
     */
    handleLoginSuccess: function() {
        // 如果当前在登录页面
        if (window.location.pathname.includes('login.html')) {
            // 检查是否首次登录（没有添加过宝宝）
            const isFirstLogin = !localStorage.getItem('hasAddedBaby');
            
            if (isFirstLogin) {
                // 首次登录，导航到宝宝管理页面
                Logger.info('首次登录，跳转到宝宝管理页面', 'AUTH');
                window.location.href = 'baby_management.html';
            } else {
                // 非首次登录，导航到主页
                Logger.info('非首次登录，跳转到主页', 'AUTH');
                window.location.href = 'home.html';
            }
        }
    },
    
    // 使用Apple ID登录
    loginWithApple: async function() {
        try {
            if (this.authState.isAuthenticating) {
                Logger.warn('已有登录过程正在进行中', 'AUTH');
                return false;
            }
            
            this.authState.isAuthenticating = true;
            this.authState.lastError = null;
            
            // 显示加载提示
            showLoading('正在使用Apple账号登录...');
            
            let user;
            
            // 如果在iOS环境中，调用原生Apple登录
            if (this.isInIOS) {
                Logger.debug('调用iOS原生Apple登录', 'AUTH');
                
                user = await new Promise((resolve, reject) => {
                    // 设置回调函数
                    window.handleAppleSignInResult = function(result) {
                        if (result.success) {
                            resolve(result.user);
                        } else {
                            reject(new Error(result.error || '登录失败'));
                        }
                    };
                    
                    // 调用原生登录方法
                    window.webkit.messageHandlers.auth.postMessage({
                        action: 'loginWithApple'
                    });
                });
                
                Logger.info('iOS原生Apple登录成功', 'AUTH');
            } else {
                // 在Web环境中模拟Apple登录
                Logger.debug('模拟Apple登录流程', 'AUTH');
                
                // 模拟API调用延迟
                await new Promise(resolve => setTimeout(resolve, 1500));
                
                // 模拟成功登录
                user = {
                    id: 'apple_' + Date.now(),
                    name: '苹果用户',
                    email: 'apple_user@example.com',
                    loginType: 'apple',
                    avatar: null,
                    createdAt: new Date().toISOString()
                };
                
                Logger.info('模拟Apple登录成功', 'AUTH');
            }
            
            // 保存用户信息
            this.setCurrentUser(user);
            
            // 初始化CloudKit同步
            this.initCloudKitSync();
            
            hideLoading();
            showToast('Apple账号登录成功');
            
            this.authState.isAuthenticating = false;
            return true;
        } catch (error) {
            hideLoading();
            showToast('Apple账号登录失败: ' + error.message);
            Logger.error(`Apple登录失败: ${error.message}`, 'AUTH');
            
            this.authState.isAuthenticating = false;
            this.authState.lastError = error.message;
            return false;
        }
    },
    
    // 使用微信登录
    loginWithWeChat: async function() {
        try {
            if (this.authState.isAuthenticating) {
                Logger.warn('已有登录过程正在进行中', 'AUTH');
                return false;
            }
            
            this.authState.isAuthenticating = true;
            this.authState.lastError = null;
            
            // 显示加载提示
            showLoading('正在使用微信账号登录...');
            
            let user;
            
            // 如果在iOS环境中，调用原生微信登录
            if (this.isInIOS) {
                Logger.debug('调用iOS原生微信登录', 'AUTH');
                
                user = await new Promise((resolve, reject) => {
                    // 设置回调函数
                    window.handleWeChatSignInResult = function(result) {
                        if (result.success) {
                            resolve(result.user);
                        } else {
                            reject(new Error(result.error || '登录失败'));
                        }
                    };
                    
                    // 调用原生登录方法
                    window.webkit.messageHandlers.auth.postMessage({
                        action: 'loginWithWeChat'
                    });
                });
                
                Logger.info('iOS原生微信登录成功', 'AUTH');
            } else {
                // 在Web环境中模拟微信登录
                Logger.debug('模拟微信登录流程', 'AUTH');
                
                // 模拟API调用延迟
                await new Promise(resolve => setTimeout(resolve, 1500));
                
                // 模拟成功登录
                user = {
                    id: 'wechat_' + Date.now(),
                    name: '微信用户',
                    openid: 'wx_' + Math.random().toString(36).substr(2, 9),
                    loginType: 'wechat',
                    avatar: null,
                    createdAt: new Date().toISOString()
                };
                
                Logger.info('模拟微信登录成功', 'AUTH');
            }
            
            // 保存用户信息
            this.setCurrentUser(user);
            
            // 初始化CloudKit同步
            this.initCloudKitSync();
            
            hideLoading();
            showToast('微信账号登录成功');
            
            this.authState.isAuthenticating = false;
            return true;
        } catch (error) {
            hideLoading();
            showToast('微信账号登录失败: ' + error.message);
            Logger.error(`微信登录失败: ${error.message}`, 'AUTH');
            
            this.authState.isAuthenticating = false;
            this.authState.lastError = error.message;
            return false;
        }
    },
    
    // 游客登录
    loginAsGuest: async function() {
        try {
            if (this.authState.isAuthenticating) {
                Logger.warn('已有登录过程正在进行中', 'AUTH');
                return false;
            }
            
            this.authState.isAuthenticating = true;
            this.authState.lastError = null;
            
            // 显示加载提示
            showLoading('正在以游客身份登录...');
            
            // 模拟API调用延迟
            await new Promise(resolve => setTimeout(resolve, 800));
            
            // 创建游客用户
            const guestId = 'guest_' + Date.now();
            const user = {
                id: guestId,
                name: '游客用户',
                loginType: 'guest',
                avatar: null,
                createdAt: new Date().toISOString()
            };
            
            // 保存用户信息
            this.setCurrentUser(user);
            
            // 游客模式下不启用CloudKit同步
            Logger.info('游客登录成功，不启用CloudKit同步', 'AUTH');
            
            hideLoading();
            showToast('游客登录成功');
            
            this.authState.isAuthenticating = false;
            return true;
        } catch (error) {
            hideLoading();
            showToast('游客登录失败: ' + error.message);
            Logger.error(`游客登录失败: ${error.message}`, 'AUTH');
            
            this.authState.isAuthenticating = false;
            this.authState.lastError = error.message;
            return false;
        }
    },
    
    // 退出登录
    logout: async function() {
        try {
            Logger.info('用户退出登录', 'AUTH');
            
            // 如果在iOS环境中，通知原生应用
            if (this.isInIOS) {
                try {
                    await new Promise((resolve, reject) => {
                        // 设置回调函数
                        window.handleLogoutResult = function(result) {
                            if (result.success) {
                                resolve();
                            } else {
                                reject(new Error(result.error || '退出登录失败'));
                            }
                        };
                        
                        // 调用原生退出登录方法
                        window.webkit.messageHandlers.auth.postMessage({
                            action: 'logout'
                        });
                    });
                    
                    Logger.debug('已通知iOS原生应用用户退出登录', 'AUTH');
                } catch (error) {
                    Logger.error(`通知iOS原生应用退出登录失败: ${error.message}`, 'AUTH');
                }
            }
            
            // 清除用户信息
            this.currentUser = null;
            localStorage.removeItem('baobao_user');
            
            // 禁用CloudKit同步
            this.disableCloudKitSync();
            
            // 触发退出登录事件
            const event = new CustomEvent('userLogout');
            document.dispatchEvent(event);
            
            showToast('已退出登录');
            
            // 跳转到欢迎页面
            window.location.href = 'welcome.html';
            
            return true;
        } catch (error) {
            Logger.error(`退出登录失败: ${error.message}`, 'AUTH');
            showToast('退出登录失败: ' + error.message);
            return false;
        }
    },
    
    // 设置当前用户
    setCurrentUser: function(user) {
        this.currentUser = user;
        
        // 保存到本地存储
        localStorage.setItem('baobao_user', JSON.stringify(user));
        
        // 触发登录事件
        this.triggerLoginEvent();
        
        Logger.info(`用户信息已保存: ${user.name} (${user.loginType})`, 'AUTH');
    },
    
    // 获取当前用户
    getCurrentUser: function() {
        return this.currentUser;
    },
    
    // 检查是否已登录
    isLoggedIn: function() {
        return this.currentUser !== null;
    },
    
    // 检查是否是游客登录
    isGuestUser: function() {
        return this.currentUser && this.currentUser.loginType === 'guest';
    },
    
    // 更新用户信息
    updateUserInfo: async function(userInfo) {
        try {
            if (!this.isLoggedIn()) {
                throw new Error('用户未登录');
            }
            
            Logger.debug(`更新用户信息: ${JSON.stringify(userInfo)}`, 'AUTH');
            
            // 合并用户信息
            const updatedUser = {
                ...this.currentUser,
                ...userInfo,
                updatedAt: new Date().toISOString()
            };
            
            // 如果在iOS环境中，通知原生应用
            if (this.isInIOS) {
                try {
                    await new Promise((resolve, reject) => {
                        // 设置回调函数
                        window.handleUpdateUserResult = function(result) {
                            if (result.success) {
                                resolve();
                            } else {
                                reject(new Error(result.error || '更新用户信息失败'));
                            }
                        };
                        
                        // 调用原生更新用户信息方法
                        window.webkit.messageHandlers.auth.postMessage({
                            action: 'updateUserInfo',
                            userInfo: updatedUser
                        });
                    });
                    
                    Logger.debug('已通知iOS原生应用更新用户信息', 'AUTH');
                } catch (error) {
                    Logger.error(`通知iOS原生应用更新用户信息失败: ${error.message}`, 'AUTH');
                    throw error;
                }
            }
            
            // 保存更新后的用户信息
            this.setCurrentUser(updatedUser);
            
            showToast('用户信息已更新');
            return true;
        } catch (error) {
            Logger.error(`更新用户信息失败: ${error.message}`, 'AUTH');
            showToast('更新用户信息失败: ' + error.message);
            return false;
        }
    },
    
    // 将游客账号升级为正式账号
    upgradeGuestAccount: async function(loginType) {
        try {
            if (!this.isLoggedIn()) {
                throw new Error('用户未登录');
            }
            
            if (!this.isGuestUser()) {
                throw new Error('当前不是游客账号');
            }
            
            Logger.info(`尝试将游客账号升级为${loginType}账号`, 'AUTH');
            
            // 根据登录类型调用相应的登录方法
            let success = false;
            if (loginType === 'apple') {
                success = await this.loginWithApple();
            } else if (loginType === 'wechat') {
                success = await this.loginWithWeChat();
            } else {
                throw new Error('不支持的登录类型');
            }
            
            if (success) {
                Logger.info('游客账号升级成功', 'AUTH');
                showToast('账号升级成功');
                return true;
            } else {
                throw new Error('账号升级失败');
            }
        } catch (error) {
            Logger.error(`游客账号升级失败: ${error.message}`, 'AUTH');
            showToast('账号升级失败: ' + error.message);
            return false;
        }
    },
    
    // 初始化CloudKit同步
    initCloudKitSync: async function() {
        // 如果是游客用户，不启用CloudKit同步
        if (this.isGuestUser()) {
            Logger.info('游客模式，不启用CloudKit同步', 'AUTH');
            this.authState.cloudKitStatus = 'unavailable';
            return;
        }
        
        Logger.info('正在初始化CloudKit同步...', 'AUTH');
        this.authState.cloudKitStatus = 'syncing';
        
        try {
            // 如果在iOS环境中，调用原生CloudKit同步
            if (this.isInIOS) {
                await new Promise((resolve, reject) => {
                    // 设置回调函数
                    window.handleCloudKitSyncResult = function(result) {
                        if (result.success) {
                            resolve();
                        } else {
                            reject(new Error(result.error || 'CloudKit同步失败'));
                        }
                    };
                    
                    // 调用原生CloudKit同步方法
                    window.webkit.messageHandlers.auth.postMessage({
                        action: 'initCloudKitSync'
                    });
                });
                
                Logger.info('iOS原生CloudKit同步初始化成功', 'AUTH');
                this.authState.cloudKitStatus = 'available';
            } else {
                // 在Web环境中模拟CloudKit同步
                Logger.debug('模拟CloudKit同步初始化', 'AUTH');
                
                // 模拟API调用延迟
                await new Promise(resolve => setTimeout(resolve, 1000));
                
                Logger.info('模拟CloudKit同步初始化成功', 'AUTH');
                this.authState.cloudKitStatus = 'available';
            }
            
            // 触发CloudKit同步事件
            const event = new CustomEvent('cloudKitSyncReady');
            document.dispatchEvent(event);
            
            return true;
        } catch (error) {
            Logger.error(`CloudKit同步初始化失败: ${error.message}`, 'AUTH');
            this.authState.cloudKitStatus = 'unavailable';
            
            // 触发CloudKit同步失败事件
            const event = new CustomEvent('cloudKitSyncFailed', { detail: { error: error.message } });
            document.dispatchEvent(event);
            
            return false;
        }
    },
    
    // 禁用CloudKit同步
    disableCloudKitSync: async function() {
        Logger.info('禁用CloudKit同步', 'AUTH');
        
        try {
            // 如果在iOS环境中，调用原生禁用CloudKit同步
            if (this.isInIOS) {
                await new Promise((resolve, reject) => {
                    // 设置回调函数
                    window.handleDisableCloudKitResult = function(result) {
                        if (result.success) {
                            resolve();
                        } else {
                            reject(new Error(result.error || '禁用CloudKit同步失败'));
                        }
                    };
                    
                    // 调用原生禁用CloudKit同步方法
                    window.webkit.messageHandlers.auth.postMessage({
                        action: 'disableCloudKitSync'
                    });
                });
                
                Logger.info('iOS原生CloudKit同步已禁用', 'AUTH');
            } else {
                // 在Web环境中模拟禁用CloudKit同步
                Logger.debug('模拟禁用CloudKit同步', 'AUTH');
                
                // 模拟API调用延迟
                await new Promise(resolve => setTimeout(resolve, 500));
                
                Logger.info('模拟CloudKit同步已禁用', 'AUTH');
            }
            
            this.authState.cloudKitStatus = 'unavailable';
            
            // 触发CloudKit同步禁用事件
            const event = new CustomEvent('cloudKitSyncDisabled');
            document.dispatchEvent(event);
            
            return true;
        } catch (error) {
            Logger.error(`禁用CloudKit同步失败: ${error.message}`, 'AUTH');
            return false;
        }
    },
    
    // 获取CloudKit同步状态
    getCloudKitStatus: function() {
        return this.authState.cloudKitStatus;
    },
    
    // 手动触发CloudKit同步
    triggerCloudKitSync: async function() {
        try {
            if (this.isGuestUser()) {
                throw new Error('游客模式不支持CloudKit同步');
            }
            
            if (this.authState.cloudKitStatus !== 'available') {
                throw new Error('CloudKit同步不可用');
            }
            
            Logger.info('手动触发CloudKit同步', 'AUTH');
            this.authState.cloudKitStatus = 'syncing';
            
            // 如果在iOS环境中，调用原生触发CloudKit同步
            if (this.isInIOS) {
                await new Promise((resolve, reject) => {
                    // 设置回调函数
                    window.handleTriggerSyncResult = function(result) {
                        if (result.success) {
                            resolve();
                        } else {
                            reject(new Error(result.error || 'CloudKit同步失败'));
                        }
                    };
                    
                    // 调用原生触发CloudKit同步方法
                    window.webkit.messageHandlers.auth.postMessage({
                        action: 'triggerCloudKitSync'
                    });
                });
                
                Logger.info('iOS原生CloudKit同步成功', 'AUTH');
            } else {
                // 在Web环境中模拟CloudKit同步
                Logger.debug('模拟CloudKit同步', 'AUTH');
                
                // 模拟API调用延迟
                await new Promise(resolve => setTimeout(resolve, 1500));
                
                Logger.info('模拟CloudKit同步成功', 'AUTH');
            }
            
            this.authState.cloudKitStatus = 'available';
            
            // 触发CloudKit同步完成事件
            const event = new CustomEvent('cloudKitSyncCompleted');
            document.dispatchEvent(event);
            
            showToast('数据同步完成');
            return true;
        } catch (error) {
            Logger.error(`CloudKit同步失败: ${error.message}`, 'AUTH');
            this.authState.cloudKitStatus = 'available';
            
            // 触发CloudKit同步失败事件
            const event = new CustomEvent('cloudKitSyncFailed', { detail: { error: error.message } });
            document.dispatchEvent(event);
            
            showToast('数据同步失败: ' + error.message);
            return false;
        }
    },
    
    // 获取认证状态
    getAuthState: function() {
        return this.authState;
    }
};

// 页面加载时初始化认证服务
document.addEventListener('DOMContentLoaded', function() {
    auth.init();
});

// 添加全局加载提示函数
function showLoading(message) {
    // 检查是否已存在加载提示元素
    let loadingContainer = document.getElementById('authLoadingContainer');
    
    if (!loadingContainer) {
        // 创建加载提示元素
        loadingContainer = document.createElement('div');
        loadingContainer.id = 'authLoadingContainer';
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
        loadingAnimation.style.animation = 'authLoadingSpin 1s linear infinite';
        
        // 创建加载文本
        const loadingText = document.createElement('div');
        loadingText.id = 'authLoadingText';
        loadingText.style.marginTop = '20px';
        loadingText.style.fontSize = '16px';
        loadingText.style.color = '#333';
        
        // 添加动画样式
        const style = document.createElement('style');
        style.textContent = `
            @keyframes authLoadingSpin {
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
    document.getElementById('authLoadingText').textContent = message || '加载中...';
    
    // 显示加载提示
    loadingContainer.style.display = 'flex';
}

// 隐藏加载提示
function hideLoading() {
    const loadingContainer = document.getElementById('authLoadingContainer');
    if (loadingContainer) {
        loadingContainer.style.display = 'none';
    }
}

// 显示提示消息
function showToast(message, duration = 2000) {
    // 检查是否已存在Toast元素
    let toast = document.getElementById('authToast');
    
    if (!toast) {
        // 创建Toast元素
        toast = document.createElement('div');
        toast.id = 'authToast';
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

// 导出认证服务
window.auth = auth; 