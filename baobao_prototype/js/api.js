/**
 * 宝宝故事 API 客户端
 * 用于与原生API进行交互
 */
class BaoBaoAPI {
    constructor() {
        this.callbacks = {};
        this.callbackIdCounter = 0;
        
        // 初始化重试配置
        this.maxRetries = 3;
        this.retryDelay = 1000; // 毫秒
        
        // 初始化网络状态
        this.isOnline = true;
        this.offlineQueue = [];
        
        // 初始化响应处理器
        this.initResponseHandler();
        
        // 检测是否在iOS环境中
        this.isInIOS = this.checkIsInIOS();
        
        // 监听网络状态变化
        this.setupNetworkMonitoring();
        
        console.log('BaoBaoAPI 初始化完成');
    }
    
    /**
     * 检测是否在iOS环境中
     * @returns {boolean} 是否在iOS环境中
     */
    checkIsInIOS() {
        return window.webkit && 
               window.webkit.messageHandlers && 
               window.webkit.messageHandlers.api !== undefined;
    }
    
    /**
     * 设置网络监控
     */
    setupNetworkMonitoring() {
        // 监听在线状态变化
        window.addEventListener('online', () => {
            console.log('网络连接恢复');
            this.isOnline = true;
            this.processOfflineQueue();
        });
        
        window.addEventListener('offline', () => {
            console.warn('网络连接断开');
            this.isOnline = false;
        });
        
        // 初始检查网络状态
        this.isOnline = navigator.onLine;
        if (!this.isOnline) {
            console.warn('当前处于离线状态');
        }
    }
    
    /**
     * 处理离线队列
     */
    processOfflineQueue() {
        if (this.offlineQueue.length > 0) {
            console.log(`处理离线队列，共${this.offlineQueue.length}个请求`);
            
            const queue = [...this.offlineQueue];
            this.offlineQueue = [];
            
            queue.forEach(item => {
                this.sendMessage(item.action, item.params, item.callback, 0);
            });
        }
    }
    
    /**
     * 初始化响应处理器
     */
    initResponseHandler() {
        // 定义全局响应处理函数
        window.handleNativeResponse = (response) => {
            console.log('收到原生响应:', response);
            
            const { callbackID, success, data, error } = response;
            
            // 查找回调函数
            const callback = this.callbacks[callbackID];
            if (callback) {
                // 调用回调函数
                if (success) {
                    callback.resolve(data);
                } else {
                    callback.reject(new Error(error || '未知错误'));
                }
                
                // 删除回调函数
                delete this.callbacks[callbackID];
            } else {
                console.warn(`未找到回调函数: ${callbackID}`);
            }
        };
    }
    
    /**
     * 发送消息到原生API
     * @param {string} name - 消息名称
     * @param {object} params - 消息参数
     * @param {function} callback - 回调函数
     * @param {number} retryCount - 当前重试次数
     * @returns {Promise} - 返回Promise对象
     */
    sendMessage(name, params = {}, callback = null, retryCount = 0) {
        return new Promise((resolve, reject) => {
            try {
                // 生成回调ID
                const callbackID = `callback_${Date.now()}_${this.callbackIdCounter++}`;
                
                // 保存回调函数
                this.callbacks[callbackID] = { resolve, reject };
                
                // 构建消息
                const message = {
                    callbackID,
                    params
                };
                
                // 检查网络状态
                if (!this.isOnline && this.requiresNetwork(name)) {
                    console.warn(`网络离线，将请求加入队列: ${name}`);
                    this.offlineQueue.push({
                        action: name,
                        params,
                        callback: { resolve, reject }
                    });
                    
                    // 显示离线提示
                    if (typeof showToast === 'function') {
                        showToast('当前处于离线状态，请求将在网络恢复后执行');
                    }
                    
                    return;
                }
                
                // 如果在iOS环境中，发送消息到原生API
                if (this.isInIOS) {
                    console.log(`发送API请求: ${name}`);
                    window.webkit.messageHandlers.api.postMessage(message);
                } else {
                    // 否则，模拟响应（用于开发环境）
                    console.log(`模拟发送消息: ${name}`, message);
                    this.mockResponse(name, message);
                }
            } catch (e) {
                console.error(`发送消息时出错: ${e.message}`);
                
                // 如果是网络错误且未超过最大重试次数，则重试
                if (this.isNetworkError(e) && retryCount < this.maxRetries) {
                    const nextRetryDelay = this.retryDelay * Math.pow(2, retryCount);
                    
                    console.warn(`将在${nextRetryDelay}ms后重试(${retryCount + 1}/${this.maxRetries})`);
                    
                    setTimeout(() => {
                        this.sendMessage(name, params, callback, retryCount + 1)
                            .then(resolve)
                            .catch(reject);
                    }, nextRetryDelay);
                } else {
                    reject(e);
                }
            }
        });
    }
    
    /**
     * 判断是否是网络错误
     * @param {Error} error - 错误对象
     * @returns {boolean} 是否是网络错误
     */
    isNetworkError(error) {
        const message = error.message.toLowerCase();
        return message.includes('network') || 
               message.includes('connection') || 
               message.includes('offline') ||
               message.includes('timeout');
    }
    
    /**
     * 判断操作是否需要网络连接
     * @param {string} action - 操作名称
     * @returns {boolean} 是否需要网络连接
     */
    requiresNetwork(action) {
        // 这些操作需要网络连接
        const networkActions = [
            'generateStory',
            'synthesizeSpeech',
            'translateText',
            'recognizeSpeech'
        ];
        
        return networkActions.includes(action);
    }
    
    /**
     * 模拟响应（用于开发环境）
     * @param {string} name - 消息名称
     * @param {object} message - 消息对象
     */
    mockResponse(name, message) {
        const { callbackID, params } = message;
        
        // 延迟响应，模拟网络请求
        setTimeout(() => {
            let response = {
                callbackID,
                success: true,
                data: null
            };
            
            // 根据消息名称生成模拟响应
            switch (name) {
                case 'generateStory':
                    response.data = this.mockGenerateStory(params);
                    break;
                    
                case 'synthesizeSpeech':
                    response.data = { audioURL: 'mock://audio.mp3' };
                    break;
                    
                case 'playAudio':
                    response.data = { success: true };
                    break;
                    
                case 'stopAudio':
                    response.data = { success: true };
                    break;
                    
                case 'saveStory':
                    response.data = { id: `story_${Date.now()}` };
                    break;
                    
                case 'getStories':
                    response.data = { stories: this.mockGetStories(params) };
                    break;
                    
                case 'getStoryDetail':
                    response.data = { story: this.mockGetStoryDetail(params) };
                    break;
                    
                case 'deleteStory':
                    response.data = { success: true };
                    break;
                    
                case 'saveChild':
                    response.data = { id: `child_${Date.now()}` };
                    break;
                    
                case 'getChildren':
                    response.data = { children: this.mockGetChildren() };
                    break;
                    
                case 'deleteChild':
                    response.data = { success: true };
                    break;
                    
                default:
                    response.success = false;
                    response.error = `未知的消息名称: ${name}`;
            }
            
            // 调用响应处理函数
            window.handleNativeResponse(response);
        }, 1000);
    }
    
    /**
     * 模拟生成故事
     * @param {object} params - 参数
     * @returns {object} - 模拟故事数据
     */
    mockGenerateStory(params) {
        const { theme, childName, childAge } = params;
        
        // 生成随机标题
        const titles = [
            '奇妙的冒险',
            '神秘的森林',
            '魔法城堡',
            '海底探险',
            '太空之旅'
        ];
        const title = titles[Math.floor(Math.random() * titles.length)];
        
        // 生成随机内容
        const content = `从前，有一个叫${childName}的${childAge}岁小朋友，非常喜欢探险。
        
有一天，${childName}在家门口发现了一个神秘的盒子。盒子上面有着奇怪的符号，看起来非常神秘。

${childName}小心翼翼地打开盒子，突然，一道亮光闪过，${childName}被带到了一个神奇的世界。

在这个世界里，${childName}遇到了许多有趣的朋友，他们一起经历了许多冒险。

最后，${childName}学会了勇敢和友爱的重要性，带着这些宝贵的经验回到了家中。

从此以后，${childName}每天都怀着感恩的心情，珍惜身边的每一个人和每一件事。`;
        
        return {
            id: `story_${Date.now()}`,
            title,
            content,
            theme,
            childName,
            createdAt: new Date().toISOString()
        };
    }
    
    /**
     * 模拟获取故事列表
     * @param {object} params - 参数
     * @returns {array} - 模拟故事列表
     */
    mockGetStories(params) {
        const { childName } = params || {};
        
        // 生成模拟故事列表
        const stories = [];
        const themes = ['魔法世界', '动物朋友', '太空冒险', '公主王子', '海底世界', '恐龙时代'];
        
        for (let i = 0; i < 5; i++) {
            const theme = themes[Math.floor(Math.random() * themes.length)];
            const name = childName || '小明';
            
            stories.push({
                id: `story_${i}`,
                title: `${name}的${theme}冒险`,
                content: `这是一个关于${name}的${theme}冒险故事...`,
                theme,
                childName: name,
                createdAt: new Date().toISOString()
            });
        }
        
        return stories;
    }
    
    /**
     * 模拟获取宝宝列表
     * @returns {array} - 模拟宝宝列表
     */
    mockGetChildren() {
        // 生成模拟宝宝列表
        return [
            {
                id: 'child_1',
                name: '小明',
                age: 3,
                gender: '男孩',
                interests: ['恐龙', '汽车'],
                createdAt: new Date().toISOString()
            },
            {
                id: 'child_2',
                name: '小红',
                age: 4,
                gender: '女孩',
                interests: ['公主', '画画'],
                createdAt: new Date().toISOString()
            }
        ];
    }
    
    /**
     * 模拟获取故事详情
     * @param {object} params - 参数
     * @returns {object} - 模拟故事详情
     */
    mockGetStoryDetail(params) {
        const { storyId } = params;
        const themes = ['魔法世界', '动物朋友', '太空冒险', '公主王子', '海底世界', '恐龙时代'];
        const theme = themes[Math.floor(Math.random() * themes.length)];
        
        return {
            id: storyId,
            title: `小明的${theme}冒险`,
            content: `从前，有一个叫小明的小朋友，非常喜欢探险。
            
有一天，小明在家门口发现了一个神秘的盒子。盒子上面有着奇怪的符号，看起来非常神秘。

小明小心翼翼地打开盒子，突然，一道亮光闪过，小明被带到了一个神奇的世界。

在这个世界里，小明遇到了许多有趣的朋友，他们一起经历了许多冒险。

最后，小明学会了勇敢和友爱的重要性，带着这些宝贵的经验回到了家中。

从此以后，小明每天都怀着感恩的心情，珍惜身边的每一个人和每一件事。`,
            theme,
            childName: '小明',
            createdAt: new Date().toISOString(),
            audioURL: Math.random() > 0.5 ? 'mock://audio.mp3' : null
        };
    }
    
    // MARK: - API方法
    
    /**
     * 生成故事
     * @param {string} theme - 故事主题
     * @param {string} childName - 宝宝名称
     * @param {number} childAge - 宝宝年龄
     * @param {array} childInterests - 宝宝兴趣爱好
     * @param {string} length - 故事长度
     * @returns {Promise} - 返回Promise对象
     */
    generateStory(theme, childName, childAge, childInterests = [], length = '中篇') {
        return this.sendMessage('generateStory', {
            theme,
            childName,
            childAge,
            childInterests,
            length
        });
    }
    
    /**
     * 语音合成
     * @param {string} text - 文本内容
     * @param {string} voiceType - 语音类型
     * @returns {Promise} - 返回Promise对象
     */
    synthesizeSpeech(text, voiceType = '萍萍阿姨') {
        return this.sendMessage('synthesizeSpeech', {
            text,
            voiceType
        });
    }
    
    /**
     * 播放音频
     * @param {string} audioURL - 音频URL
     * @returns {Promise} - 返回Promise对象
     */
    playAudio(audioURL) {
        return this.sendMessage('playAudio', {
            audioURL
        });
    }
    
    /**
     * 停止音频播放
     * @returns {Promise} - 返回Promise对象
     */
    stopAudio() {
        return this.sendMessage('stopAudio');
    }
    
    /**
     * 保存故事
     * @param {object} story - 故事对象
     * @returns {Promise} - 返回Promise对象
     */
    saveStory(story) {
        return this.sendMessage('saveStory', {
            story
        });
    }
    
    /**
     * 获取故事列表
     * @param {string} childName - 宝宝名称（可选）
     * @returns {Promise} - 返回Promise对象
     */
    getStories(childName) {
        const params = {};
        if (childName) {
            params.childName = childName;
        }
        
        return this.sendMessage('getStories', params);
    }
    
    /**
     * 获取故事详情
     * @param {string} storyId - 故事ID
     * @returns {Promise} - 返回Promise对象
     */
    getStoryDetail(storyId) {
        return this.sendMessage('getStoryDetail', {
            storyId
        });
    }
    
    /**
     * 删除故事
     * @param {string} storyId - 故事ID
     * @returns {Promise} - 返回Promise对象
     */
    deleteStory(storyId) {
        return this.sendMessage('deleteStory', {
            storyId
        });
    }
    
    /**
     * 保存宝宝信息
     * @param {object} child - 宝宝对象
     * @returns {Promise} - 返回Promise对象
     */
    saveChild(child) {
        return this.sendMessage('saveChild', {
            child
        });
    }
    
    /**
     * 获取宝宝列表
     * @returns {Promise} - 返回Promise对象
     */
    getChildren() {
        return this.sendMessage('getChildren');
    }
    
    /**
     * 删除宝宝
     * @param {string} childId - 宝宝ID
     * @returns {Promise} - 返回Promise对象
     */
    deleteChild(childId) {
        return this.sendMessage('deleteChild', {
            childId
        });
    }
}

// 创建API实例
const api = new BaoBaoAPI();

// 导出API实例
window.api = api; 