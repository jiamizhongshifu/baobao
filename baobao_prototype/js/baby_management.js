/**
 * 宝宝管理页面脚本
 * 包含宝宝信息的添加、编辑、删除和展示功能
 */

// 全局变量
let babies = [];
let selectedGender = '';
let interests = [];
let editingBabyId = null;
let deletingBabyId = null;
let currentAvatar = null; // 存储当前选择的头像

// DOM元素引用
let babyCards;
let emptyState;
let babyModal;
let confirmDialog;

// 初始化页面
document.addEventListener('DOMContentLoaded', function() {
    // 初始化DOM引用
    initDomReferences();
    
    // 加载宝宝数据
    loadBabies();
    
    // 渲染宝宝卡片
    renderBabies();
    
    // 检查是否首次使用
    checkFirstTimeUser();
});

// 初始化DOM元素引用
function initDomReferences() {
    babyCards = document.getElementById('babyCards');
    emptyState = document.getElementById('emptyState');
    babyModal = document.getElementById('babyModal');
    confirmDialog = document.getElementById('confirmDialog');
}

// 检查是否是首次使用
function checkFirstTimeUser() {
    const isFirstTimeUser = !localStorage.getItem('hasAddedBaby');
    
    if (isFirstTimeUser) {
        // 隐藏返回按钮
        const backButton = document.querySelector('.back-button');
        if (backButton) {
            backButton.style.display = 'none';
        }
        
        // 添加欢迎横幅
        addWelcomeBanner();
        
        // 自动打开添加宝宝表单
        setTimeout(() => {
            openModal(false);
        }, 500);
    }
}

// 添加欢迎横幅
function addWelcomeBanner() {
    const welcomeBanner = document.createElement('div');
    welcomeBanner.className = 'welcome-banner';
    welcomeBanner.innerHTML = `
        <div class="welcome-title">欢迎来到宝宝故事！</div>
        <div class="welcome-text">请先告诉我们一些关于您宝宝的信息，这样我们能为Ta创建更加个性化的故事体验。</div>
        <div class="progress-indicator">
            <div class="progress-step active">填写宝宝资料</div>
            <div class="progress-line"></div>
            <div class="progress-step">选择故事主题</div>
            <div class="progress-line"></div>
            <div class="progress-step">开始故事之旅</div>
        </div>
    `;
    
    const header = document.querySelector('.header');
    if (header && header.parentNode) {
        header.parentNode.insertBefore(welcomeBanner, header);
    }
}

// 从localStorage加载宝宝数据
function loadBabies() {
    const savedBabies = localStorage.getItem('babies');
    if (savedBabies) {
        babies = JSON.parse(savedBabies);
    }
}

// 保存宝宝数据到localStorage
function saveBabies() {
    localStorage.setItem('babies', JSON.stringify(babies));
    
    // 设置当前宝宝（如果有的话）
    if (babies.length > 0) {
        localStorage.setItem('currentBabyId', babies[0].id);
    }
}

// 渲染宝宝卡片
function renderBabies() {
    // 清空现有卡片
    babyCards.innerHTML = '';
    
    // 检查是否有宝宝数据
    if (babies.length === 0) {
        babyCards.style.display = 'none';
        emptyState.style.display = 'flex';
        return;
    }
    
    // 显示宝宝卡片
    babyCards.style.display = 'flex';
    emptyState.style.display = 'none';
    
    // 创建文档片段，减少DOM操作
    const fragment = document.createDocumentFragment();
    
    // 为每个宝宝创建卡片
    babies.forEach(baby => {
        const card = createBabyCard(baby);
        fragment.appendChild(card);
    });
    
    // 一次性更新DOM
    babyCards.appendChild(fragment);
}

// 创建单个宝宝卡片
function createBabyCard(baby) {
    const card = document.createElement('div');
    card.className = 'baby-card';
    card.dataset.id = baby.id;
    
    const avatarHtml = baby.avatar 
        ? `<img src="${baby.avatar}" alt="${baby.name}" class="baby-avatar">` 
        : `<i class="fas fa-baby default-avatar"></i>`;
    
    card.innerHTML = `
        <div class="baby-actions">
            <button class="action-button edit-button" onclick="editBaby('${baby.id}')">
                <i class="fas fa-edit"></i>
            </button>
            <button class="action-button delete-button" onclick="deleteBaby('${baby.id}')">
                <i class="fas fa-trash"></i>
            </button>
        </div>
        <div class="baby-info">
            <div class="baby-avatar-container">
                ${avatarHtml}
            </div>
            <div class="baby-header">
                <div class="baby-name">${baby.name}</div>
                <div class="baby-age">${baby.age}</div>
            </div>
            <div class="baby-gender ${baby.gender}">${baby.gender === 'boy' ? '男宝宝' : '女宝宝'}</div>
            <div class="interests-container">
                <div class="interests-title">兴趣标签</div>
                <div class="interests-tags">
                    ${baby.interests.map(interest => `
                        <span class="interest-tag">${interest}</span>
                    `).join('')}
                </div>
            </div>
        </div>
    `;
    
    return card;
}

// 打开添加/编辑宝宝弹窗
function openModal(isEdit = false) {
    document.getElementById('modalTitle').textContent = isEdit ? '编辑宝宝' : '添加宝宝';
    babyModal.classList.add('open');
}

// 关闭弹窗
function closeModal() {
    babyModal.classList.remove('open');
    resetForm();
}

// 选择性别
function selectGender(gender) {
    selectedGender = gender;
    document.getElementById('boyOption').classList.remove('selected');
    document.getElementById('girlOption').classList.remove('selected');
    document.getElementById(`${gender}Option`).classList.add('selected');
}

// 添加快速兴趣标签
function addQuickInterest(interest) {
    if (!interests.includes(interest)) {
        interests.push(interest);
        updateInterestsList();
        
        // 突出显示选中的快速标签
        const quickTags = document.querySelectorAll('.quick-interest-tag');
        quickTags.forEach(tag => {
            if (tag.textContent === interest) {
                tag.classList.add('selected');
            }
        });
    }
}

// 按回车添加兴趣标签
function addInterestOnEnter(event) {
    if (event.key === 'Enter') {
        event.preventDefault();
        const input = document.getElementById('interestInput');
        const interest = input.value.trim();
        
        if (interest && !interests.includes(interest)) {
            interests.push(interest);
            updateInterestsList();
        }
        
        input.value = '';
    }
}

// 移除兴趣标签
function removeInterest(index) {
    // 获取要移除的兴趣标签
    const removedInterest = interests[index];
    
    // 从数组中移除
    interests.splice(index, 1);
    
    // 更新兴趣列表显示
    updateInterestsList();
    
    // 取消快速标签中的选中效果
    const quickTags = document.querySelectorAll('.quick-interest-tag');
    quickTags.forEach(tag => {
        if (tag.textContent === removedInterest) {
            tag.classList.remove('selected');
        }
    });
}

// 更新兴趣标签列表
function updateInterestsList() {
    const list = document.getElementById('interestsList');
    list.innerHTML = interests.map((interest, index) => `
        <div class="interest-item">
            ${interest}
            <button class="remove-interest" onclick="removeInterest(${index})">
                <i class="fas fa-times"></i>
            </button>
        </div>
    `).join('');
}

// 显示头像预览
function previewAvatar(input) {
    if (input.files && input.files[0]) {
        const reader = new FileReader();
        
        reader.onload = function(e) {
            const defaultAvatar = document.getElementById('defaultAvatar');
            const avatarImage = document.getElementById('avatarImage');
            
            avatarImage.src = e.target.result;
            avatarImage.style.display = 'block';
            defaultAvatar.style.display = 'none';
            
            currentAvatar = e.target.result;
        }
        
        reader.readAsDataURL(input.files[0]);
    }
}

// 重置头像预览
function resetAvatarPreview() {
    const defaultAvatar = document.getElementById('defaultAvatar');
    const avatarImage = document.getElementById('avatarImage');
    
    avatarImage.src = '';
    avatarImage.style.display = 'none';
    defaultAvatar.style.display = 'block';
    
    currentAvatar = null;
}

// 编辑宝宝信息
function editBaby(id) {
    // 找到要编辑的宝宝
    const baby = babies.find(b => b.id === id);
    if (!baby) return;
    
    // 设置编辑状态
    editingBabyId = id;
    
    // 填充表单
    document.getElementById('babyId').value = baby.id;
    document.getElementById('babyName').value = baby.name;
    document.getElementById('babyAge').value = baby.age;
    
    // 设置头像
    if (baby.avatar) {
        const defaultAvatar = document.getElementById('defaultAvatar');
        const avatarImage = document.getElementById('avatarImage');
        
        avatarImage.src = baby.avatar;
        avatarImage.style.display = 'block';
        defaultAvatar.style.display = 'none';
        
        currentAvatar = baby.avatar;
    } else {
        resetAvatarPreview();
    }
    
    // 设置性别
    selectedGender = baby.gender;
    document.getElementById('boyOption').classList.remove('selected');
    document.getElementById('girlOption').classList.remove('selected');
    document.getElementById(`${baby.gender}Option`).classList.add('selected');
    
    // 设置兴趣标签
    interests = [...baby.interests];
    updateInterestsList();
    
    // 选中对应的快速兴趣标签
    const quickTags = document.querySelectorAll('.quick-interest-tag');
    quickTags.forEach(tag => {
        if (interests.includes(tag.textContent)) {
            tag.classList.add('selected');
        } else {
            tag.classList.remove('selected');
        }
    });
    
    // 打开弹窗
    openModal(true);
}

// 删除宝宝信息
function deleteBaby(id) {
    deletingBabyId = id;
    confirmDialog.classList.add('open');
}

// 取消删除
function cancelDelete() {
    deletingBabyId = null;
    confirmDialog.classList.remove('open');
}

// 确认删除
function confirmDelete() {
    if (deletingBabyId) {
        // 从数组中删除
        babies = babies.filter(baby => baby.id !== deletingBabyId);
        
        // 保存更新后的数据
        saveBabies();
        
        // 重新渲染页面
        renderBabies();
        
        // 显示提示
        showToast('宝宝信息已删除');
        
        // 关闭确认对话框
        confirmDialog.classList.remove('open');
        deletingBabyId = null;
    }
}

// 提交表单
function submitForm() {
    const name = document.getElementById('babyName').value;
    const age = document.getElementById('babyAge').value;
    
    if (!name || !age || !selectedGender) {
        showToast('请填写完整信息');
        return;
    }
    
    // 准备宝宝数据
    const babyData = {
        id: editingBabyId || generateId(),
        name,
        age,
        gender: selectedGender,
        interests: [...interests],
        avatar: currentAvatar
    };
    
    // 检查是否是首次使用
    const isFirstTimeUser = !localStorage.getItem('hasAddedBaby');
    
    // 处理编辑或添加
    if (editingBabyId) {
        // 更新现有宝宝数据
        const index = babies.findIndex(baby => baby.id === editingBabyId);
        if (index !== -1) {
            babies[index] = babyData;
        }
        showToast('宝宝信息已更新');
        
        // 关闭弹窗和重置状态
        closeModal();
    } else {
        // 添加新宝宝
        babies.push(babyData);
        
        if (isFirstTimeUser) {
            // 标记已添加宝宝
            localStorage.setItem('hasAddedBaby', 'true');
            
            // 关闭弹窗
            babyModal.classList.remove('open');
            
            // 显示成功界面
            showSuccessScreen(babyData.name);
        } else {
            showToast('宝宝添加成功');
            closeModal();
        }
    }
    
    // 保存数据
    saveBabies();
    
    // 重新渲染页面
    renderBabies();
    
    // 重置编辑状态
    editingBabyId = null;
}

// 显示成功界面
function showSuccessScreen(babyName) {
    // 创建成功界面
    const successScreen = document.createElement('div');
    successScreen.className = 'success-screen';
    successScreen.innerHTML = `
        <div class="success-icon">
            <i class="fas fa-check-circle"></i>
        </div>
        <div class="success-title">太棒了！</div>
        <div class="success-message">${babyName}的资料已设置完成，我们可以开始创建专属于Ta的故事了！</div>
        <button class="start-story-button" onclick="goToStoryThemes()">
            开始创建故事
            <i class="fas fa-arrow-right"></i>
        </button>
    `;
    
    document.body.appendChild(successScreen);
}

// 跳转到故事主题页面
function goToStoryThemes() {
    window.location.href = 'story_themes.html';
}

// 重置表单
function resetForm() {
    document.getElementById('babyId').value = '';
    document.getElementById('babyName').value = '';
    
    // 如果使用select元素作为年龄选择器
    const ageSelect = document.getElementById('babyAge');
    if (ageSelect.tagName === 'SELECT') {
        ageSelect.selectedIndex = 0;
    } else {
        ageSelect.value = '';
    }
    
    selectedGender = '';
    document.getElementById('boyOption').classList.remove('selected');
    document.getElementById('girlOption').classList.remove('selected');
    
    interests = [];
    updateInterestsList();
    
    // 清除快速兴趣标签选择
    const quickTags = document.querySelectorAll('.quick-interest-tag');
    quickTags.forEach(tag => tag.classList.remove('selected'));
    
    resetAvatarPreview();
    document.getElementById('avatarUpload').value = '';
    editingBabyId = null;
}

// 生成唯一ID
function generateId() {
    return 'baby_' + Date.now() + '_' + Math.floor(Math.random() * 1000);
}

// 显示提示信息
function showToast(message) {
    // 如果页面中已有common.js包含showToast函数，则直接使用
    if (typeof window.showToast === 'function') {
        window.showToast(message);
        return;
    }
    
    // 否则创建一个简单的toast
    const toast = document.createElement('div');
    toast.className = 'toast';
    toast.textContent = message;
    
    document.body.appendChild(toast);
    
    // 添加样式
    toast.style.position = 'fixed';
    toast.style.bottom = '20px';
    toast.style.left = '50%';
    toast.style.transform = 'translateX(-50%)';
    toast.style.backgroundColor = 'rgba(0, 0, 0, 0.7)';
    toast.style.color = '#FFF';
    toast.style.padding = '12px 20px';
    toast.style.borderRadius = '20px';
    toast.style.fontSize = '16px';
    toast.style.zIndex = '9999';
    
    // 显示动画
    toast.style.opacity = '0';
    toast.style.transition = 'opacity 0.3s';
    
    setTimeout(() => {
        toast.style.opacity = '1';
    }, 10);
    
    // 自动隐藏
    setTimeout(() => {
        toast.style.opacity = '0';
        setTimeout(() => {
            document.body.removeChild(toast);
        }, 300);
    }, 2000);
} 