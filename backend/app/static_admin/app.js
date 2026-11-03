/**
/**
 * IELTS Vision - Web Admin Portal Client Logic
 * Hoạt động mượt mà trực tiếp trên mọi trình duyệt (Chrome, Edge, Safari, Firefox).
 */

const API_BASE = `${window.location.origin}/api/v1`;

// App State
const state = {
  token: localStorage.getItem('ielts_admin_token') || '',
  user: JSON.parse(localStorage.getItem('ielts_admin_user') || 'null'),
  currentTab: 'tab-kpis',
  selectedSkill: 'reading',
  selectedStageFilter: 'all',
  skillSearchTerm: '',
  lessons: [],
  skillPage: 1,
  skillPageSize: 6,
  mappings: [],
  vocabPage: 1,
  vocabPageSize: 15,
  users: [],
  userPage: 1,
  userPageSize: 10,
  selectedImportFile: null,
  activeQuestions: [], // Dùng trong modal soạn câu hỏi trắc nghiệm
  writingChartMode: 'none', // 'image' | 'data' | 'none'
  vocabConfig: null, // Cấu hình động học từ vựng & AI Qwen
  savedVocabConfig: null, // Snapshot cấu hình đã lưu trong CSDL
  availableModels: [], // Danh sách models cài trên Ollama
  isBackendOnline: false,
  isOllamaOnline: false,
  // Quản lý Lịch sử chấm AI Qwen
  aiLogs: [],
  aiLogPage: 1,
  aiLogPageSize: 20,
  aiLogTotal: 0,
  aiLogTotalPages: 1,
  aiLogSelectedFeature: 'all',
  aiLogSelectedStatus: 'all',
  aiLogSelectedCache: 'all',
  aiLogSearchTerm: '',
  selectedLogIds: new Set(),
  currentViewingLogId: null,
};

// ─────────────────────────────────────────────────────────────
// AUTHENTICATION & INITIALIZATION
// ─────────────────────────────────────────────────────────────

document.addEventListener('DOMContentLoaded', () => {
  initEventListeners();
  checkAuth();
});

function checkAuth() {
  const loginModal = document.getElementById('login-modal');
  if (state.token && state.user && state.user.role === 'admin') {
    loginModal.style.display = 'none';
    updateUserProfileUI();
    loadAllData();
  } else {
    loginModal.style.display = 'flex';
  }
}

function updateUserProfileUI() {
  if (state.user) {
    document.getElementById('current-user-name').textContent = state.user.username;
    document.getElementById('current-user-avatar').textContent = state.user.username.substring(0, 2).toUpperCase();
  }
}

function authHeaders() {
  return {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${state.token}`,
  };
}

async function apiRequest(endpoint, options = {}) {
  const url = `${API_BASE}${endpoint}`;
  const headers = options.isFormData
    ? { 'Authorization': `Bearer ${state.token}` }
    : { ...authHeaders(), ...(options.headers || {}) };

  const config = {
    method: options.method || 'GET',
    headers: headers,
    body: options.body,
  };

  try {
    const res = await fetch(url, config);
    if (res.status === 401 || res.status === 403) {
      showToast('Phiên làm việc hết hạn hoặc không có quyền Admin!', 'error');
      logout();
      throw new Error('Unauthorized');
    }
    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.detail || data.message || 'Lỗi xử lý yêu cầu API');
    }
    return data;
  } catch (err) {
    console.error('API Error:', err);
    throw err;
  }
}

function logout() {
  localStorage.removeItem('ielts_admin_token');
  localStorage.removeItem('ielts_admin_user');
  state.token = '';
  state.user = null;
  document.getElementById('login-modal').style.display = 'flex';
}

// ─────────────────────────────────────────────────────────────
// EVENT LISTENERS
// ─────────────────────────────────────────────────────────────

function initEventListeners() {
  // Login Form
  document.getElementById('login-form').addEventListener('submit', handleLogin);
  document.getElementById('btn-logout').addEventListener('click', logout);
  document.getElementById('btn-refresh-data').addEventListener('click', () => {
    loadAllData();
    showToast('Đã làm mới dữ liệu hệ thống!', 'success');
  });

  // Sidebar Tab Navigation
  document.querySelectorAll('.sidebar-nav .nav-item').forEach(btn => {
    btn.addEventListener('click', () => {
      const tabId = btn.getAttribute('data-tab');
      switchTab(tabId);
    });
  });

  // Tab Skills: Skill Pills
  document.querySelectorAll('.skill-pill').forEach(pill => {
    pill.addEventListener('click', () => {
      document.querySelectorAll('.skill-pill').forEach(p => p.classList.remove('active'));
      pill.classList.add('active');
      state.selectedSkill = pill.getAttribute('data-skill');
      state.selectedStageFilter = 'all';
      state.skillPage = 1;
      updateStagePillsUI();
      loadSkillLessons();
    });
  });

  // Tab Skills: Stage Filter Pills
  document.querySelectorAll('.stage-pill').forEach(pill => {
    pill.addEventListener('click', () => {
      document.querySelectorAll('.stage-pill').forEach(p => p.classList.remove('active'));
      pill.classList.add('active');
      state.selectedStageFilter = pill.getAttribute('data-stage');
      state.skillPage = 1;
      renderSkillLessons();
    });
  });

  // Tab Skills: Search Box
  document.getElementById('skill-search-input').addEventListener('input', (e) => {
    state.skillSearchTerm = e.target.value.trim().toLowerCase();
    state.skillPage = 1;
    renderSkillLessons();
  });

  // Tab Skills: Create Lesson & Import & Download Template
  document.getElementById('btn-open-create-lesson').addEventListener('click', () => openLessonModal());
  document.getElementById('btn-open-import-modal').addEventListener('click', openImportModal);
  document.getElementById('btn-download-template').addEventListener('click', handleDownloadTemplate);

  // Lesson Form Dynamic Inputs
  document.getElementById('lesson-skill-type').addEventListener('change', (e) => {
    renderDynamicLessonForm(e.target.value);
  });
  document.getElementById('lesson-form').addEventListener('submit', handleSaveLesson);

  // Import File Drag & Drop
  initDropZone();

  // Tab Vocab Search & Filter
  document.getElementById('vocab-search-input').addEventListener('input', () => {
    state.vocabPage = 1;
    renderVocabTable();
  });
  document.getElementById('vocab-band-filter').addEventListener('change', () => {
    state.vocabPage = 1;
    renderVocabTable();
  });
  document.getElementById('btn-reset-mappings').addEventListener('click', handleResetMappings);

  // Tab Users: Create User
  document.getElementById('btn-open-create-user').addEventListener('click', () => {
    document.getElementById('user-modal').classList.add('active');
  });
  document.getElementById('user-form').addEventListener('submit', handleCreateUser);

  // Modal Close buttons
  document.querySelectorAll('.modal-close').forEach(btn => {
    btn.addEventListener('click', () => {
      document.querySelectorAll('.modal-overlay').forEach(m => m.classList.remove('active'));
    });
  });

  // Tab Vocab & AI Config Event Listeners
  initVocabConfigEventListeners();

  // Tab AI Grading History Event Listeners
  initAiGradingEventListeners();
}

function switchTab(tabId) {
  state.currentTab = tabId;
  document.querySelectorAll('.sidebar-nav .nav-item').forEach(b => {
    b.classList.toggle('active', b.getAttribute('data-tab') === tabId);
  });
  document.querySelectorAll('.tab-pane').forEach(pane => {
    pane.classList.toggle('active', pane.id === tabId);
  });

  // Update Page Title
  const titles = {
    'tab-kpis': 'Tổng quan KPIs Hệ thống',
    'tab-skills': 'Quản Lý Kỹ Năng',
    'tab-vocab': 'Kho Từ Vựng',
    'tab-vocab-config': 'Cấu hình AI & Học Tập',
    'tab-ai-grading': 'Lịch Sử Chấm Điểm',
    'tab-users': 'Quản lý Người Dùng & Phân Quyền (RBAC)',
  };
  document.getElementById('page-title').textContent = titles[tabId] || 'Quản trị viên';

  if (tabId === 'tab-vocab-config') {
    loadVocabAiConfig();
  } else if (tabId === 'tab-ai-grading') {
    loadAiGradingData();
  }
}

function updateStagePillsUI() {
  document.querySelectorAll('.stage-pill').forEach(pill => {
    pill.classList.toggle('active', pill.getAttribute('data-stage') === state.selectedStageFilter);
  });
}

// ─────────────────────────────────────────────────────────────
// AUTH: LOGIN
// ─────────────────────────────────────────────────────────────

async function handleLogin(e) {
  e.preventDefault();
  const username = document.getElementById('login-username').value.trim();
  const password = document.getElementById('login-password').value.trim();
  const errBox = document.getElementById('login-error');
  errBox.style.display = 'none';

  try {
    const res = await fetch(`${API_BASE}/auth/admin/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });

    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.detail || 'Tài khoản hoặc mật khẩu Quản trị viên không đúng!');
    }

    if (data.user && data.user.role !== 'admin') {
      throw new Error('Tài khoản này là Học viên (Learner), không có quyền truy cập trang Quản trị!');
    }

    state.token = data.access_token;
    state.user = data.user;
    localStorage.setItem('ielts_admin_token', data.access_token);
    localStorage.setItem('ielts_admin_user', JSON.stringify(data.user));

    document.getElementById('login-modal').style.display = 'none';
    updateUserProfileUI();
    showToast(`Chào mừng Admin "${data.user.username}" quay trở lại!`, 'success');
    loadAllData();
  } catch (err) {
    errBox.textContent = err.message;
    errBox.style.display = 'block';
  }
}

// ─────────────────────────────────────────────────────────────
// DATA LOADING
// ─────────────────────────────────────────────────────────────

async function loadAllData() {
  await Promise.all([
    loadKPIS(),
    loadSkillLessons(),
    loadVocabMappings(),
    loadUsers(),
    loadVocabAiConfig(),
    loadAiGradingData(),
  ]);
}

async function loadKPIS() {
  try {
    const data = await apiRequest('/admin/kpis');
    document.getElementById('kpi-mappings').textContent = data.total_mappings || 80;
    document.getElementById('kpi-learners').textContent = data.total_learners || 0;
    document.getElementById('kpi-users').textContent = data.total_users || 0;
    document.getElementById('kpi-notebook').textContent = data.total_notebook_items || 0;

    const dbStatusBadge = document.getElementById('status-db');
    if (dbStatusBadge) {
      dbStatusBadge.className = 'status-badge success';
      dbStatusBadge.innerHTML = '<i class="fa-solid fa-check"></i> Đã kết nối';
    }

    // Render Band Bars
    const dist = data.band_distribution || {};
    const total = Object.values(dist).reduce((a, b) => a + b, 0) || 1;
    const container = document.getElementById('band-distribution-container');
    container.innerHTML = '';

    ['Band 7.0', 'Band 7.5', 'Band 8.0', 'Band 8.5'].forEach(band => {
      const count = dist[band] || 0;
      const pct = Math.round((count / total) * 100);
      container.innerHTML += `
        <div class="band-bar-item">
          <div class="band-bar-header">
            <span><strong>${band}</strong> (Học thuật)</span>
            <span>${count} từ (${pct}%)</span>
          </div>
          <div class="band-progress-bg">
            <div class="band-progress-fill" style="width: ${pct}%"></div>
          </div>
        </div>
      `;
    });
  } catch (e) {
    console.error('Lỗi tải KPIs:', e);
    const dbStatusBadge = document.getElementById('status-db');
    if (dbStatusBadge) {
      dbStatusBadge.className = 'status-badge warning';
      dbStatusBadge.innerHTML = '<i class="fa-solid fa-triangle-exclamation"></i> Kiểm tra kết nối';
    }
  }
}

// ─────────────────────────────────────────────────────────────
// PHÂN TRANG (PAGINATION HELPER REUSABLE)
// ─────────────────────────────────────────────────────────────

function getPaginationRange(currentPage, totalPages) {
  if (totalPages <= 5) {
    return Array.from({ length: totalPages }, (_, i) => i + 1);
  }
  const delta = 1;
  const left = Math.max(2, currentPage - delta);
  const right = Math.min(totalPages - 1, currentPage + delta);
  const items = [1];
  if (left > 2) {
    items.push('...');
  }
  for (let i = left; i <= right; i++) {
    items.push(i);
  }
  if (right < totalPages - 1) {
    items.push('...');
  }
  items.push(totalPages);
  return items;
}

function renderPaginationBar({
  barId,
  infoId,
  actionsId,
  currentPage,
  pageSize,
  totalItems,
  pageSizeOptions = [10, 20, 50],
  onPageChange,
  onPageSizeChange,
}) {
  const bar = document.getElementById(barId);
  const info = document.getElementById(infoId);
  const actions = document.getElementById(actionsId);
  if (!bar || !info || !actions) return;

  if (totalItems === 0) {
    bar.style.display = 'none';
    return;
  }
  bar.style.display = 'flex';

  const totalPages = Math.ceil(totalItems / pageSize) || 1;
  const safePage = Math.min(Math.max(1, currentPage), totalPages);

  const start = (safePage - 1) * pageSize + 1;
  const end = Math.min(safePage * pageSize, totalItems);

  info.innerHTML = `Hiển thị <strong>${start} - ${end}</strong> trong <strong>${totalItems.toLocaleString()}</strong> bản ghi (Trang <strong>${safePage}/${totalPages}</strong>)`;

  const sizeSelectHtml = `
    <div class="pagination-size-wrap">
      <span>Dòng/trang:</span>
      <select class="pagination-size-select" id="${barId}-size-select">
        ${pageSizeOptions.map(opt => `<option value="${opt}" ${opt === pageSize ? 'selected' : ''}>${opt}</option>`).join('')}
      </select>
    </div>
  `;

  const prevDisabled = safePage <= 1 ? 'disabled' : '';
  const nextDisabled = safePage >= totalPages ? 'disabled' : '';

  const range = getPaginationRange(safePage, totalPages);
  const pageBtnsHtml = range.map(p => {
    if (p === '...') {
      return `<span style="padding: 0 4px; color: var(--muted); font-size: 13px;">...</span>`;
    }
    const isActive = p === safePage ? 'active' : '';
    return `<button class="pagination-page-btn ${isActive}" data-page="${p}">${p}</button>`;
  }).join('');

  actions.innerHTML = `
    ${sizeSelectHtml}
    <div class="pagination-btn-group">
      <button class="pagination-page-btn" id="${barId}-btn-prev" ${prevDisabled} title="Trang trước">
        <i class="fa-solid fa-chevron-left"></i>
      </button>
      ${pageBtnsHtml}
      <button class="pagination-page-btn" id="${barId}-btn-next" ${nextDisabled} title="Trang sau">
        <i class="fa-solid fa-chevron-right"></i>
      </button>
    </div>
  `;

  const sizeSelect = document.getElementById(`${barId}-size-select`);
  if (sizeSelect && onPageSizeChange) {
    sizeSelect.addEventListener('change', (e) => {
      onPageSizeChange(parseInt(e.target.value, 10));
    });
  }

  const prevBtn = document.getElementById(`${barId}-btn-prev`);
  if (prevBtn && !prevDisabled && onPageChange) {
    prevBtn.addEventListener('click', () => onPageChange(safePage - 1));
  }

  const nextBtn = document.getElementById(`${barId}-btn-next`);
  if (nextBtn && !nextDisabled && onPageChange) {
    nextBtn.addEventListener('click', () => onPageChange(safePage + 1));
  }

  actions.querySelectorAll('.pagination-page-btn[data-page]').forEach(btn => {
    btn.addEventListener('click', () => {
      const p = parseInt(btn.getAttribute('data-page'), 10);
      if (p !== safePage && onPageChange) {
        onPageChange(p);
      }
    });
  });
}

// ─────────────────────────────────────────────────────────────
// TAB SKILLS & 5 STAGES
// ─────────────────────────────────────────────────────────────

async function loadSkillLessons() {
  try {
    const lessons = await apiRequest(`/admin/skills/lessons?skill_type=${state.selectedSkill}`);
    state.lessons = Array.isArray(lessons) ? lessons : [];
    renderSkillLessons();
  } catch (e) {
    console.error('Lỗi tải đề thi:', e);
  }
}

function renderSkillLessons() {
  const container = document.getElementById('skills-lessons-list');
  let filtered = state.lessons.slice();

  // Filter theo Stage
  if (state.selectedStageFilter !== 'all') {
    const stg = parseInt(state.selectedStageFilter);
    filtered = filtered.filter(l => (l.stage_number || 1) === stg);
  }

  // Filter theo Search
  if (state.skillSearchTerm) {
    filtered = filtered.filter(l =>
      (l.title || '').toLowerCase().includes(state.skillSearchTerm) ||
      (l.category_or_topic || '').toLowerCase().includes(state.skillSearchTerm)
    );
  }

  const totalItems = filtered.length;
  const pBar = document.getElementById('skills-pagination');

  if (totalItems === 0) {
    container.innerHTML = `
      <div style="text-align: center; padding: 48px 20px; background: white; border-radius: 16px; border: 1px solid var(--border);">
        <i class="fa-solid fa-folder-open" style="font-size: 42px; color: #94a3b8; margin-bottom: 12px;"></i>
        <h4 style="font-weight: 800; font-size: 16px;">Chưa có đề thi nào cho bộ lọc này</h4>
        <p style="color: var(--muted); font-size: 13px; margin-top: 4px;">
          Bấm "<strong>Thêm Đề Thi / Ải Mới</strong>" hoặc "<strong>Import File Đề Thi</strong>" để nạp nội dung.
        </p>
      </div>
    `;
    if (pBar) pBar.style.display = 'none';
    return;
  }

  const totalPages = Math.ceil(totalItems / state.skillPageSize) || 1;
  if (state.skillPage > totalPages) {
    state.skillPage = totalPages;
  }
  if (state.skillPage < 1) {
    state.skillPage = 1;
  }

  const startIdx = (state.skillPage - 1) * state.skillPageSize;
  const pageItems = filtered.slice(startIdx, startIdx + state.skillPageSize);

  container.innerHTML = pageItems.map(l => {
    const stageNum = l.stage_number || 1;
    const targetBand = l.target_band || l.band_score_target || '7.0';
    const passCond = l.pass_condition || {};
    let passText = '';

    if (state.selectedSkill === 'reading' || state.selectedSkill === 'listening') {
      const minC = passCond.min_correct || l.pass_score_required || 2;
      passText = `Đúng tối thiểu: <strong>${minC} câu</strong> để mở khóa ải kế tiếp`;
    } else if (state.selectedSkill === 'writing') {
      const minW = passCond.min_words || 150;
      const minB = passCond.min_band || 6.0;
      passText = `Tối thiểu: <strong>${minW} từ</strong> (Band điểm chấm >= <strong>${minB}</strong>)`;
    } else {
      const minB = passCond.min_band || 6.0;
      passText = `Band điểm Speaking trung bình >= <strong>${minB}</strong> để qua ải`;
    }

    const content = l.content_json || {};
    let detailSummary = '';
    if (state.selectedSkill === 'reading' || state.selectedSkill === 'listening') {
      const qList = content.questions || [];
      detailSummary = `Gồm <strong>${qList.length} câu trắc nghiệm</strong>`;
    } else if (state.selectedSkill === 'writing') {
      const chartType = content.chart_data?.type;
      const chartLabel = chartType ? (chartType === 'image' ? '📸 Ảnh Supabase' : `📊 Biểu đồ ${chartType}`) : '';
      detailSummary = `Dạng: <strong>${content.taskType || 'Task 2'}</strong> ${chartLabel ? '• ' + chartLabel : ''} • Có văn mẫu Band 8.0+`;
    } else {
      detailSummary = `Part 1 Q&A + Part 2 Cue Card`;
    }

    return `
      <div class="lesson-card">
        <div class="lesson-card-top">
          <div class="lesson-badges">
            <span class="badge-stage"><i class="fa-solid fa-flag"></i> ẢI ${stageNum}</span>
            <span class="badge-band"><i class="fa-solid fa-star"></i> Target Band ${targetBand}</span>
          </div>
          <div class="lesson-actions">
            <button class="btn-icon edit" onclick="openLessonModal('${l.id}')" title="Chỉnh sửa đề thi">
              <i class="fa-solid fa-pen-to-square"></i>
            </button>
            <button class="btn-icon delete" onclick="handleDeleteLesson('${l.id}')" title="Xóa đề thi">
              <i class="fa-solid fa-trash-can"></i>
            </button>
          </div>
        </div>
        <div class="lesson-title-area">
          <h4>${escapeHtml(l.title || 'Chưa đặt tiêu đề')}</h4>
          <span class="lesson-meta">${l.difficulty_label || `Ải ${stageNum}`} • Chủ đề: <strong>${escapeHtml(l.category_or_topic || 'General')}</strong></span>
        </div>
        <div class="lesson-pass-chip">
          <div class="pass-condition-text">
            <i class="fa-solid fa-circle-check"></i> ${passText}
          </div>
          <div class="pass-summary-text">${detailSummary}</div>
        </div>
      </div>
    `;
  }).join('');

  renderPaginationBar({
    barId: 'skills-pagination',
    infoId: 'skills-pagination-info',
    actionsId: 'skills-pagination-actions',
    currentPage: state.skillPage,
    pageSize: state.skillPageSize,
    totalItems: totalItems,
    pageSizeOptions: [6, 12, 24],
    onPageChange: (newPage) => {
      state.skillPage = newPage;
      renderSkillLessons();
      container.scrollIntoView({ behavior: 'smooth', block: 'start' });
    },
    onPageSizeChange: (newSize) => {
      state.skillPageSize = newSize;
      state.skillPage = 1;
      renderSkillLessons();
    }
  });
}

// ─────────────────────────────────────────────────────────────
// LESSON MODAL: CRUD FORM & DYNAMIC FIELDS
// ─────────────────────────────────────────────────────────────

function openLessonModal(lessonId = null) {
  const modal = document.getElementById('lesson-modal');
  const titleElem = document.getElementById('lesson-modal-title');
  const form = document.getElementById('lesson-form');

  if (lessonId) {
    const lesson = state.lessons.find(l => String(l.id) === String(lessonId));
    if (!lesson) {
      console.warn('Không tìm thấy bài học với ID:', lessonId);
      return;
    }
    titleElem.innerHTML = `<i class="fa-solid fa-file-pen"></i> Chỉnh sửa Đề thi & Ải (#${lesson.id})`;
    document.getElementById('lesson-edit-id').value = lesson.id;
    document.getElementById('lesson-skill-type').value = lesson.skill_type || state.selectedSkill;
    document.getElementById('lesson-skill-type').disabled = true; // Không đổi skill khi sửa
    document.getElementById('lesson-stage-number').value = lesson.stage_number || 1;
    document.getElementById('lesson-target-band').value = lesson.target_band || lesson.band_score_target || 7.0;
    document.getElementById('lesson-title').value = lesson.title || '';
    document.getElementById('lesson-topic').value = lesson.category_or_topic || 'General';

    renderDynamicLessonForm(lesson.skill_type || state.selectedSkill, lesson);
  } else {
    titleElem.innerHTML = `<i class="fa-solid fa-file-circle-plus"></i> Thêm mới Đề thi & Cấu hình Ải`;
    document.getElementById('lesson-edit-id').value = '';
    document.getElementById('lesson-skill-type').value = state.selectedSkill;
    document.getElementById('lesson-skill-type').disabled = false;
    document.getElementById('lesson-stage-number').value = 1;
    document.getElementById('lesson-target-band').value = 7.0;
    document.getElementById('lesson-title').value = '';
    document.getElementById('lesson-topic').value = 'General';

    renderDynamicLessonForm(state.selectedSkill, null);
  }

  modal.classList.add('active');
}

function renderDynamicLessonForm(skill, initialLesson = null) {
  const passContainer = document.getElementById('pass-condition-fields');
  const contentContainer = document.getElementById('skill-content-fields');
  const content = initialLesson?.content_json || {};
  const passCond = initialLesson?.pass_condition || {};

  // 1. Render Pass Condition
  if (skill === 'reading' || skill === 'listening') {
    const minC = passCond.min_correct || initialLesson?.pass_score_required || 2;
    passContainer.innerHTML = `
      <div class="form-group flex-1">
        <label><i class="fa-solid fa-circle-check" style="color: var(--success);"></i> Số câu trắc nghiệm đúng tối thiểu để qua ải</label>
        <input type="number" id="pass-min-correct" value="${minC}" min="1" required />
      </div>
    `;
  } else if (skill === 'writing') {
    const minW = passCond.min_words || 150;
    const minB = passCond.min_band || 6.0;
    passContainer.innerHTML = `
      <div class="form-group flex-1">
        <label>Số từ tối thiểu (min_words)</label>
        <input type="number" id="pass-min-words" value="${minW}" required />
      </div>
      <div class="form-group flex-1">
        <label>Band điểm viết tối thiểu</label>
        <input type="number" step="0.5" id="pass-min-band" value="${minB}" required />
      </div>
    `;
  } else {
    const minB = passCond.min_band || 6.0;
    passContainer.innerHTML = `
      <div class="form-group flex-1">
        <label>Band điểm nói (Speaking) tối thiểu để qua ải</label>
        <input type="number" step="0.5" id="pass-min-band" value="${minB}" required />
      </div>
    `;
  }

  // 2. Render Skill Content
  if (skill === 'reading') {
    const paras = content.paragraphs || {};
    state.activeQuestions = content.questions || [
      { id: 1, questionText: 'What is the primary topic of this passage?', options: ['Renewable energy', 'Fossil fuels', 'Nuclear power', 'Hydro power'], correctAnswer: 'Renewable energy', explanation: '' }
    ];

    contentContainer.innerHTML = `
      <div class="form-group">
        <label>Đoạn văn A (Học thuật)</label>
        <textarea id="reading-para-a" rows="4" placeholder="Nhập nội dung đoạn văn A..." required>${paras.A || ''}</textarea>
      </div>
      <div class="form-group">
        <label>Đoạn văn B (Tùy chọn)</label>
        <textarea id="reading-para-b" rows="3" placeholder="Nhập nội dung đoạn văn B nếu có...">${paras.B || ''}</textarea>
      </div>
      <div id="questions-editor-wrapper"></div>
    `;
    renderQuestionsEditorUI();
  } else if (skill === 'listening') {
    state.activeQuestions = content.questions || [
      { id: 1, questionText: 'Where does the conversation take place?', options: ['At the library', 'At the airport', 'At the hotel', 'In a restaurant'], correctAnswer: 'At the library', explanation: '' }
    ];

    contentContainer.innerHTML = `
      <div class="form-group">
        <label>Kịch bản bài nghe (Audio Script)</label>
        <textarea id="listening-script" rows="5" placeholder="Nhập nội dung hội thoại hoặc kịch bản nghe..." required>${content.audioScript || ''}</textarea>
      </div>
      <div id="questions-editor-wrapper"></div>
    `;
    renderQuestionsEditorUI();
  } else if (skill === 'writing') {
    const chartData = content.chart_data || null;
    let initialMode = 'none';
    if (content.taskType === 'Task 1') {
      if (chartData && chartData.type === 'image') initialMode = 'image';
      else if (chartData && (chartData.type === 'bar' || chartData.type === 'line')) initialMode = 'data';
      else initialMode = 'data';
    }
    state.writingChartMode = initialMode;

    contentContainer.innerHTML = `
      <div class="form-group">
        <label>Dạng bài Writing</label>
        <select id="writing-task-type" class="form-select" onchange="toggleWritingTaskType(this.value)">
          <option value="Task 1" ${content.taskType === 'Task 1' ? 'selected' : ''}>Writing Task 1 (Mô tả biểu đồ / bản đồ / quy trình)</option>
          <option value="Task 2" ${content.taskType === 'Task 2' || !content.taskType ? 'selected' : ''}>Writing Task 2 (Bài luận Essay 250 từ)</option>
        </select>
      </div>

      <!-- KHU VỰC CẤU HÌNH BIỂU ĐỒ TASK 1 -->
      <div id="writing-task1-chart-section" class="chart-config-container" style="display: ${content.taskType === 'Task 1' ? 'block' : 'none'};">
        <div style="display: flex; justify-content: space-between; align-items: center; margin-bottom: 10px;">
          <label style="font-weight: 800; color: var(--navy); font-size: 13.5px;">
            <i class="fa-solid fa-chart-column"></i> Cấu hình Biểu đồ Task 1
          </label>
          <span style="font-size: 11px; color: var(--muted);"><i class="fa-solid fa-cloud"></i> Lưu trực tiếp vào Supabase Storage</span>
        </div>

        <!-- Chế độ biểu đồ (Pills) -->
        <div class="chart-mode-pills">
          <button type="button" class="chart-mode-pill ${initialMode === 'image' ? 'active' : ''}" data-mode="image" onclick="switchChartMode('image')">
            <i class="fa-solid fa-cloud-arrow-up"></i> 1. Tải ảnh đề thi (Supabase Storage)
          </button>
          <button type="button" class="chart-mode-pill ${initialMode === 'data' ? 'active' : ''}" data-mode="data" onclick="switchChartMode('data')">
            <i class="fa-solid fa-chart-line"></i> 2. Biểu đồ Số liệu Động (Bar / Line)
          </button>
          <button type="button" class="chart-mode-pill ${initialMode === 'none' ? 'active' : ''}" data-mode="none" onclick="switchChartMode('none')">
            <i class="fa-solid fa-ban"></i> 3. Không dùng biểu đồ
          </button>
        </div>

        <!-- PANEL 1: UPLOAD ẢNH SUPABASE STORAGE -->
        <div id="chart-panel-image" style="display: ${initialMode === 'image' ? 'block' : 'none'};">
          <input type="file" id="chart-file-input" accept=".png,.jpg,.jpeg,.webp" style="display: none;" onchange="handleChartFileSelect(event)" />
          <div class="chart-upload-zone" onclick="document.getElementById('chart-file-input').click()">
            <i class="fa-solid fa-cloud-arrow-up" style="font-size: 28px; color: var(--primary); margin-bottom: 8px;"></i>
            <div style="font-weight: 700; font-size: 13.5px; color: var(--navy);">Bấm để Chọn ảnh hoặc Kéo thả ảnh vào đây</div>
            <div style="font-size: 11.5px; color: var(--muted); margin-top: 4px;">Hỗ trợ: .png, .jpg, .webp (Dung lượng &le; 5MB)</div>
          </div>
          <div id="chart-upload-status" style="margin-top: 8px; font-size: 12px; font-weight: 600;"></div>

          <div id="chart-preview-container" class="chart-preview-box" style="display: ${chartData?.image_url ? 'flex' : 'none'};">
            <img id="chart-image-preview" src="${chartData?.image_url || ''}" class="chart-preview-img" alt="Chart Preview" />
            <div style="flex: 1;">
              <div style="font-weight: 700; font-size: 12.5px; color: var(--navy); margin-bottom: 4px;">Ảnh biểu đồ hiện tại</div>
              <input type="text" id="writing-chart-image-url" value="${chartData?.image_url || ''}" placeholder="URL ảnh biểu đồ trên Supabase Storage..." style="font-size: 12px; padding: 6px 10px;" />
              <div style="margin-top: 6px;">
                <span id="chart-source-badge" class="badge badge-success" style="font-size: 10.5px;">Cloud: Supabase Storage</span>
              </div>
            </div>
            <button type="button" class="btn-icon delete" onclick="removeChartImage()" title="Xóa ảnh này">
              <i class="fa-solid fa-trash"></i>
            </button>
          </div>
        </div>

        <!-- PANEL 2: SỐ LIỆU ĐỘNG (BAR / LINE) -->
        <div id="chart-panel-data" style="display: ${initialMode === 'data' ? 'block' : 'none'};">
          <div class="form-row">
            <div class="form-group flex-1">
              <label>Loại Biểu Đồ</label>
              <select id="chart-data-type" class="form-select">
                <option value="bar" ${chartData?.type === 'bar' ? 'selected' : ''}>Biểu đồ Cột (Bar Chart)</option>
                <option value="line" ${chartData?.type === 'line' ? 'selected' : ''}>Biểu đồ Đường (Line Graph)</option>
              </select>
            </div>
            <div class="form-group flex-1">
              <label>Đơn vị Trục tung Y</label>
              <input type="text" id="chart-data-unit" value="${chartData?.unit || '%'}" placeholder="VD: %, TWh, Triệu..." />
            </div>
          </div>
          <div class="form-group">
            <label>Tiêu đề Biểu Đồ</label>
            <input type="text" id="chart-data-title" value="${chartData?.title || ''}" placeholder="VD: Internet Access in Households (2015 - 2025)" />
          </div>
          <div class="form-group">
            <label>Mốc Trục Hoành X (Cách nhau bằng dấu phẩy)</label>
            <input type="text" id="chart-data-categories" value="${(chartData?.categories || ['2015', '2018', '2020', '2025']).join(', ')}" placeholder="VD: 2015, 2018, 2020, 2025" />
            <small style="color: var(--muted); font-size: 11px;">Mỗi chuỗi số liệu bên dưới bắt buộc phải có số lượng giá trị bằng đúng số mốc này.</small>
          </div>

          <div style="display: flex; justify-content: space-between; align-items: center; margin: 12px 0 8px 0;">
            <label style="font-weight: 700; font-size: 12.5px; color: var(--slate);"><i class="fa-solid fa-layer-group"></i> Các Chuỗi Số Liệu (Series)</label>
            <button type="button" class="btn btn-secondary btn-sm" onclick="addChartSeriesRow()">
              <i class="fa-solid fa-plus"></i> Thêm Chuỗi
            </button>
          </div>
          <div id="chart-series-list-container">
            <!-- Dynamic Series Items -->
          </div>
        </div>

        <!-- PANEL 3: KHÔNG DÙNG BIỂU ĐỒ -->
        <div id="chart-panel-none" style="display: ${initialMode === 'none' ? 'block' : 'none'}; padding: 10px; color: var(--muted); font-size: 12.5px;">
          <i class="fa-solid fa-info-circle"></i> Đề bài này sẽ không hiển thị biểu đồ.
        </div>
      </div>

      <div class="form-group" style="margin-top: 14px;">
        <label>Đề bài (Writing Prompt)</label>
        <textarea id="writing-prompt" rows="3" placeholder="Nhập đề bài Writing..." required>${content.prompt || ''}</textarea>
      </div>
      <div class="form-group">
        <label>Dàn ý gợi ý (Key Outline - mỗi dòng một ý)</label>
        <textarea id="writing-outline" rows="3" placeholder="Mở bài: Paraphrase...&#10;Body 1: Luận điểm 1...&#10;Body 2: Luận điểm 2...">${(content.keyOutline || []).join('\n')}</textarea>
      </div>
      <div class="form-group">
        <label>Bài văn mẫu Band 8.0+</label>
        <textarea id="writing-sample" rows="4" placeholder="Nhập bài luận mẫu chất lượng cao...">${content.sampleEssay || ''}</textarea>
      </div>
      <div class="form-group">
        <label>Từ vựng học thuật gợi ý (cách nhau dấu phẩy)</label>
        <input type="text" id="writing-vocab" value="${(content.academicVocabulary || []).join(', ')}" placeholder="VD: sustainable, mitigate, pivotal..." />
      </div>
    `;

    // Khởi tạo các hàng series
    const seriesContainer = document.getElementById('chart-series-list-container');
    if (seriesContainer) {
      seriesContainer.innerHTML = '';
      if (chartData && Array.isArray(chartData.series) && chartData.series.length > 0) {
        chartData.series.forEach(s => addChartSeriesRow(s.name, s.color, (s.values || []).join(', ')));
      } else {
        addChartSeriesRow('Đô thị (Urban)', '#1E3A8A', '65, 75, 82, 92');
        addChartSeriesRow('Nông thôn (Rural)', '#D97706', '30, 42, 55, 78');
      }
    }
  } else if (skill === 'speaking') {
    const p1 = (content.part1Questions && content.part1Questions[0]) || {};
    contentContainer.innerHTML = `
      <div class="form-group">
        <label>Câu hỏi Speaking Part 1</label>
        <input type="text" id="speaking-p1-q" value="${p1.question || ''}" placeholder="VD: Do you prefer working individually or in a team?" required />
      </div>
      <div class="form-group">
        <label>Câu trả lời mẫu Part 1</label>
        <textarea id="speaking-p1-a" rows="2" placeholder="Câu trả lời mẫu tự nhiên và lưu loát...">${p1.sampleAnswer || ''}</textarea>
      </div>
      <div class="form-group">
        <label>Đề bài Part 2 (Cue Card Prompt)</label>
        <textarea id="speaking-p2-prompt" rows="3" placeholder="Describe an important technological invention..." required>${content.part2CueCardPrompt || ''}</textarea>
      </div>
      <div class="form-group">
        <label>Bài nói mẫu Part 2 (Band 8.0+)</label>
        <textarea id="speaking-p2-sample" rows="4" placeholder="Bài nói mẫu chi tiết 2 phút...">${content.part2SampleAnswer || ''}</textarea>
      </div>
      <div class="form-group">
        <label>Collocations & Idioms gợi ý (cách nhau dấu phẩy)</label>
        <input type="text" id="speaking-collocations" value="${(content.part2Collocations || []).join(', ')}" placeholder="VD: cutting-edge, revolutionize, a double-edged sword..." />
      </div>
    `;
  }
}

function renderQuestionsEditorUI() {
  const wrapper = document.getElementById('questions-editor-wrapper');
  if (!wrapper) return;

  wrapper.innerHTML = `
    <div style="display: flex; justify-content: space-between; align-items: center; margin: 16px 0 10px 0;">
      <h5 style="font-weight: 800; font-size: 13.5px;"><i class="fa-solid fa-list-ol"></i> Danh Sách Câu Hỏi Trắc Nghiệm (${state.activeQuestions.length} câu)</h5>
      <button type="button" class="btn btn-secondary btn-sm" onclick="addQuestionItem()">
        <i class="fa-solid fa-plus"></i> Thêm Câu Hỏi
      </button>
    </div>
    <div id="questions-list-container">
      ${state.activeQuestions.map((q, idx) => `
        <div class="question-item-card" data-idx="${idx}">
          <div class="question-item-header">
            <strong>Câu ${idx + 1}</strong>
            ${state.activeQuestions.length > 1 ? `
              <button type="button" class="btn-icon delete" onclick="removeQuestionItem(${idx})" title="Xóa câu này">
                <i class="fa-solid fa-trash"></i>
              </button>
            ` : ''}
          </div>
          <div class="form-group">
            <input type="text" class="q-text" value="${escapeHtml(q.questionText || '')}" placeholder="Nội dung câu hỏi..." required />
          </div>
          <div class="form-row">
            <div class="form-group flex-1">
              <input type="text" class="q-optA" value="${escapeHtml(q.options?.[0] || '')}" placeholder="Đáp án A" required />
            </div>
            <div class="form-group flex-1">
              <input type="text" class="q-optB" value="${escapeHtml(q.options?.[1] || '')}" placeholder="Đáp án B" required />
            </div>
          </div>
          <div class="form-row">
            <div class="form-group flex-1">
              <input type="text" class="q-optC" value="${escapeHtml(q.options?.[2] || '')}" placeholder="Đáp án C" required />
            </div>
            <div class="form-group flex-1">
              <input type="text" class="q-optD" value="${escapeHtml(q.options?.[3] || '')}" placeholder="Đáp án D" required />
            </div>
          </div>
          <div class="form-group">
            <label style="color: var(--success);"><i class="fa-solid fa-check"></i> Đáp án đúng (khớp đúng 1 trong 4 lựa chọn trên)</label>
            <input type="text" class="q-correct" value="${escapeHtml(q.correctAnswer || '')}" placeholder="VD: Đáp án A" required />
          </div>
        </div>
      `).join('')}
    </div>
  `;
}

function addQuestionItem() {
  saveCurrentQuestionsState();
  state.activeQuestions.push({
    id: state.activeQuestions.length + 1,
    questionText: `Câu hỏi số ${state.activeQuestions.length + 1}?`,
    options: ['Lựa chọn A', 'Lựa chọn B', 'Lựa chọn C', 'Lựa chọn D'],
    correctAnswer: 'Lựa chọn A',
    explanation: '',
  });
  renderQuestionsEditorUI();
}

function removeQuestionItem(idx) {
  saveCurrentQuestionsState();
  if (state.activeQuestions.length > 1) {
    state.activeQuestions.splice(idx, 1);
    renderQuestionsEditorUI();
  }
}

function saveCurrentQuestionsState() {
  const cards = document.querySelectorAll('.question-item-card');
  state.activeQuestions = Array.from(cards).map((card, idx) => {
    return {
      id: idx + 1,
      questionText: card.querySelector('.q-text')?.value.trim() || '',
      options: [
        card.querySelector('.q-optA')?.value.trim() || '',
        card.querySelector('.q-optB')?.value.trim() || '',
        card.querySelector('.q-optC')?.value.trim() || '',
        card.querySelector('.q-optD')?.value.trim() || '',
      ],
      correctAnswer: card.querySelector('.q-correct')?.value.trim() || '',
      explanation: '',
    };
  });
}

// ─────────────────────────────────────────────────────────────
// CHART CONFIGURATION HELPER FUNCTIONS (TASK 1)
// ─────────────────────────────────────────────────────────────

window.toggleWritingTaskType = function (taskType) {
  const chartSection = document.getElementById('writing-task1-chart-section');
  if (!chartSection) return;
  if (taskType === 'Task 1') {
    chartSection.style.display = 'block';
    if (!state.writingChartMode || state.writingChartMode === 'none') {
      switchChartMode('data');
    }
  } else {
    chartSection.style.display = 'none';
  }
};

window.switchChartMode = function (mode) {
  state.writingChartMode = mode;
  document.querySelectorAll('.chart-mode-pill').forEach(btn => {
    btn.classList.toggle('active', btn.getAttribute('data-mode') === mode);
  });
  const pImage = document.getElementById('chart-panel-image');
  const pData = document.getElementById('chart-panel-data');
  const pNone = document.getElementById('chart-panel-none');
  if (pImage) pImage.style.display = mode === 'image' ? 'block' : 'none';
  if (pData) pData.style.display = mode === 'data' ? 'block' : 'none';
  if (pNone) pNone.style.display = mode === 'none' ? 'block' : 'none';
};

window.handleChartFileSelect = function (e) {
  const file = e.target.files && e.target.files[0];
  if (file) uploadChartImage(file);
};

window.uploadChartImage = async function (file) {
  if (file.size > 5 * 1024 * 1024) {
    showToast('File ảnh quá lớn! Dung lượng tối đa là 5MB.', 'error');
    return;
  }
  const ext = file.name.split('.').pop().toLowerCase();
  if (!['png', 'jpg', 'jpeg', 'webp'].includes(ext)) {
    showToast('Chỉ chấp nhận file ảnh .png, .jpg, .jpeg, .webp!', 'error');
    return;
  }

  const formData = new FormData();
  formData.append('file', file);

  const statusEl = document.getElementById('chart-upload-status');
  if (statusEl) {
    statusEl.innerHTML = `<span style="color:var(--primary)"><i class="fa-solid fa-spinner fa-spin"></i> Đang tải lên Supabase Storage...</span>`;
  }

  try {
    const res = await fetch(`${API_BASE}/admin/skills/upload-chart`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${state.token}`,
      },
      body: formData,
    });

    if (!res.ok) {
      const err = await res.json().catch(() => ({}));
      throw new Error(err.detail || 'Upload thất bại');
    }

    const data = await res.json();
    const urlInput = document.getElementById('writing-chart-image-url');
    if (urlInput) urlInput.value = data.url;

    const previewContainer = document.getElementById('chart-preview-container');
    const previewImg = document.getElementById('chart-image-preview');
    const sourceBadge = document.getElementById('chart-source-badge');

    if (previewImg && previewContainer) {
      previewImg.src = data.url;
      previewContainer.style.display = 'flex';
      if (sourceBadge) {
        sourceBadge.textContent = data.source === 'supabase' ? 'Cloud: Supabase Storage' : 'Local Fallback';
        sourceBadge.className = data.source === 'supabase' ? 'badge badge-success' : 'badge badge-warning';
      }
    }

    if (statusEl) {
      statusEl.innerHTML = `<span style="color:var(--success)"><i class="fa-solid fa-circle-check"></i> Đã tải ảnh lên thành công!</span>`;
    }
    showToast('Đã upload ảnh biểu đồ lên Supabase Storage thành công!', 'success');
  } catch (err) {
    if (statusEl) {
      statusEl.innerHTML = `<span style="color:var(--danger)"><i class="fa-solid fa-triangle-exclamation"></i> Lỗi: ${err.message}</span>`;
    }
    showToast(`Lỗi upload ảnh: ${err.message}`, 'error');
  }
};

window.removeChartImage = function () {
  const urlInput = document.getElementById('writing-chart-image-url');
  if (urlInput) urlInput.value = '';
  const previewContainer = document.getElementById('chart-preview-container');
  if (previewContainer) previewContainer.style.display = 'none';
  const statusEl = document.getElementById('chart-upload-status');
  if (statusEl) statusEl.innerHTML = '';
};

window.addChartSeriesRow = function (name = 'Nhóm mới', color = '#1E3A8A', values = '') {
  const container = document.getElementById('chart-series-list-container');
  if (!container) return;
  const row = document.createElement('div');
  row.className = 'chart-series-row';
  row.innerHTML = `
    <div style="flex: 1.2;">
      <input type="text" class="series-name" value="${escapeHtml(name)}" placeholder="Tên nhóm (VD: Đô thị)" required />
    </div>
    <div style="width: 50px;">
      <input type="color" class="series-color" value="${color}" title="Chọn màu" style="height: 38px; padding: 2px; cursor: pointer;" />
    </div>
    <div style="flex: 2;">
      <input type="text" class="series-values" value="${escapeHtml(values)}" placeholder="Số liệu (VD: 65, 75, 82, 92)" required />
    </div>
    <button type="button" class="btn-icon delete" onclick="removeChartSeriesRow(this)" title="Xóa chuỗi này">
      <i class="fa-solid fa-trash"></i>
    </button>
  `;
  container.appendChild(row);
};

window.removeChartSeriesRow = function (btn) {
  const row = btn.closest('.chart-series-row');
  const container = document.getElementById('chart-series-list-container');
  if (row && container && container.querySelectorAll('.chart-series-row').length > 1) {
    row.remove();
  } else {
    showToast('Phải giữ lại ít nhất 1 chuỗi số liệu!', 'warning');
  }
};

async function handleSaveLesson(e) {
  e.preventDefault();
  const btn = document.getElementById('btn-save-lesson');
  const editId = document.getElementById('lesson-edit-id').value;
  const skill = document.getElementById('lesson-skill-type').value;
  const stageNumber = parseInt(document.getElementById('lesson-stage-number').value);
  const targetBand = parseFloat(document.getElementById('lesson-target-band').value);
  const title = document.getElementById('lesson-title').value.trim();
  const topic = document.getElementById('lesson-topic').value.trim();

  // Đóng gói pass_condition
  const passCondition = {};
  let passScoreRequired = null;
  if (skill === 'reading' || skill === 'listening') {
    passScoreRequired = parseInt(document.getElementById('pass-min-correct').value) || 2;
    passCondition.min_correct = passScoreRequired;
  } else if (skill === 'writing') {
    passCondition.min_words = parseInt(document.getElementById('pass-min-words').value) || 150;
    passCondition.min_band = parseFloat(document.getElementById('pass-min-band').value) || 6.0;
  } else {
    passCondition.min_band = parseFloat(document.getElementById('pass-min-band').value) || 6.0;
  }

  // Đóng gói content_json
  const contentJson = {};
  if (skill === 'reading') {
    saveCurrentQuestionsState();
    contentJson.paragraphs = {
      A: document.getElementById('reading-para-a').value.trim(),
    };
    const paraB = document.getElementById('reading-para-b').value.trim();
    if (paraB) contentJson.paragraphs.B = paraB;
    contentJson.questions = state.activeQuestions;
  } else if (skill === 'listening') {
    saveCurrentQuestionsState();
    contentJson.audioScript = document.getElementById('listening-script').value.trim();
    contentJson.questions = state.activeQuestions;
  } else if (skill === 'writing') {
    contentJson.taskType = document.getElementById('writing-task-type').value;
    contentJson.prompt = document.getElementById('writing-prompt').value.trim();
    contentJson.keyOutline = document.getElementById('writing-outline').value.split('\n').map(s => s.trim()).filter(Boolean);
    contentJson.sampleEssay = document.getElementById('writing-sample').value.trim();
    contentJson.academicVocabulary = document.getElementById('writing-vocab').value.split(',').map(s => s.trim()).filter(Boolean);

    // Cấu hình Biểu đồ Task 1 & Validate mảng số liệu
    if (contentJson.taskType === 'Task 1') {
      const mode = state.writingChartMode || 'none';
      if (mode === 'image') {
        const imgUrl = (document.getElementById('writing-chart-image-url')?.value || '').trim();
        if (!imgUrl) {
          showToast('Vui lòng chọn hoặc upload file ảnh biểu đồ cho Task 1!', 'error');
          btn.disabled = false;
          btn.innerHTML = `<i class="fa-solid fa-floppy-disk"></i> Lưu Đề Thi & Ải`;
          return;
        }
        contentJson.chart_data = {
          type: 'image',
          image_url: imgUrl,
        };
      } else if (mode === 'data') {
        const chartType = document.getElementById('chart-data-type')?.value || 'bar';
        const chartTitle = (document.getElementById('chart-data-title')?.value || '').trim();
        const yUnit = (document.getElementById('chart-data-unit')?.value || '').trim() || '%';
        const categoriesRaw = (document.getElementById('chart-data-categories')?.value || '')
          .split(',')
          .map(s => s.trim())
          .filter(Boolean);

        if (categoriesRaw.length === 0) {
          showToast('Vui lòng nhập ít nhất 1 mốc danh mục/năm cho trục hoành X!', 'error');
          btn.disabled = false;
          btn.innerHTML = `<i class="fa-solid fa-floppy-disk"></i> Lưu Đề Thi & Ải`;
          return;
        }

        const seriesElements = document.querySelectorAll('.chart-series-row');
        const series = [];
        for (const row of seriesElements) {
          const name = row.querySelector('.series-name')?.value.trim() || 'Nhóm';
          const color = row.querySelector('.series-color')?.value || '#1E3A8A';
          const rawVals = (row.querySelector('.series-values')?.value || '')
            .split(',')
            .map(v => parseFloat(v.trim()))
            .filter(n => !isNaN(n));

          // Validate nghiêm ngặt: values.length == categories.length
          if (rawVals.length !== categoriesRaw.length) {
            showToast(`Lỗi số liệu: Chuỗi "${name}" có ${rawVals.length} số, không khớp với ${categoriesRaw.length} mốc danh mục (${categoriesRaw.join(', ')})!`, 'error');
            btn.disabled = false;
            btn.innerHTML = `<i class="fa-solid fa-floppy-disk"></i> Lưu Đề Thi & Ải`;
            return;
          }

          series.push({
            name: name,
            color: color,
            values: rawVals,
          });
        }

        if (series.length === 0) {
          showToast('Vui lòng tạo ít nhất 1 chuỗi số liệu cho biểu đồ!', 'error');
          btn.disabled = false;
          btn.innerHTML = `<i class="fa-solid fa-floppy-disk"></i> Lưu Đề Thi & Ải`;
          return;
        }

        contentJson.chart_data = {
          type: chartType,
          title: chartTitle,
          unit: yUnit,
          categories: categoriesRaw,
          series: series,
        };
      } else {
        contentJson.chart_data = null;
      }
    } else {
      contentJson.chart_data = null;
    }
  } else if (skill === 'speaking') {
    contentJson.part1Questions = [{
      question: document.getElementById('speaking-p1-q').value.trim(),
      sampleAnswer: document.getElementById('speaking-p1-a').value.trim(),
    }];
    contentJson.part2CueCardPrompt = document.getElementById('speaking-p2-prompt').value.trim();
    contentJson.part2SampleAnswer = document.getElementById('speaking-p2-sample').value.trim();
    contentJson.part2Collocations = document.getElementById('speaking-collocations').value.split(',').map(s => s.trim()).filter(Boolean);
  }

  const payload = {
    skill_type: skill,
    stage_number: stageNumber,
    title: title,
    category_or_topic: topic,
    difficulty_label: `Ải ${stageNumber}: Cấp độ ${stageNumber}`,
    target_band: targetBand,
    band_score_target: targetBand.toString(),
    pass_condition: passCondition,
    pass_score_required: passScoreRequired,
    content_json: contentJson,
  };

  if (btn) {
    btn.disabled = true;
    btn.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> Đang lưu...`;
  }

  try {
    if (editId) {
      await apiRequest(`/admin/skills/lessons/${editId}`, {
        method: 'PUT',
        body: JSON.stringify(payload),
      });
      showToast(`Đã cập nhật ải "${stageNumber} - ${title}" thành công!`, 'success');
    } else {
      await apiRequest('/admin/skills/lessons', {
        method: 'POST',
        body: JSON.stringify(payload),
      });
      showToast(`Đã tạo mới ải "${stageNumber} - ${title}" thành công!`, 'success');
    }

    document.getElementById('lesson-modal').classList.remove('active');
    loadSkillLessons();
  } catch (err) {
    showToast(`Lỗi: ${err.message}`, 'error');
  } finally {
    btn.disabled = false;
    btn.innerHTML = `<i class="fa-solid fa-floppy-disk"></i> Lưu Đề Thi & Ải`;
  }
}

async function handleDeleteLesson(lessonId, lessonTitle = '') {
  const lesson = state.lessons.find(l => String(l.id) === String(lessonId));
  const title = lessonTitle || (lesson ? lesson.title : '') || lessonId;
  if (!confirm(`Bạn có chắc muốn xóa đề thi "${title}" không? Hành động này không thể hoàn tác.`)) {
    return;
  }

  try {
    await apiRequest(`/admin/skills/lessons/${lessonId}`, { method: 'DELETE' });
    showToast(`Đã xóa đề thi thành công!`, 'success');
    loadSkillLessons();
  } catch (err) {
    showToast(`Lỗi xóa đề thi: ${err.message}`, 'error');
  }
}

// ─────────────────────────────────────────────────────────────
// IMPORT FILE & DOWNLOAD TEMPLATE
// ─────────────────────────────────────────────────────────────

function openImportModal() {
  document.getElementById('import-skill-type').value = state.selectedSkill;
  state.selectedImportFile = null;
  document.getElementById('file-upload-input').value = '';
  document.getElementById('file-selected-info').style.display = 'none';
  document.getElementById('import-preview-box').style.display = 'none';
  document.getElementById('btn-submit-import').disabled = true;
  document.getElementById('import-modal').classList.add('active');
}

function initDropZone() {
  const dropZone = document.getElementById('file-drop-zone');
  const fileInput = document.getElementById('file-upload-input');

  dropZone.addEventListener('click', () => fileInput.click());

  dropZone.addEventListener('dragover', (e) => {
    e.preventDefault();
    dropZone.classList.add('dragover');
  });

  dropZone.addEventListener('dragleave', () => dropZone.classList.remove('dragover'));

  dropZone.addEventListener('drop', (e) => {
    e.preventDefault();
    dropZone.classList.remove('dragover');
    if (e.dataTransfer.files.length > 0) {
      handleFileSelected(e.dataTransfer.files[0]);
    }
  });

  fileInput.addEventListener('change', (e) => {
    if (e.target.files.length > 0) {
      handleFileSelected(e.target.files[0]);
    }
  });

  document.getElementById('btn-submit-import').addEventListener('click', handleSubmitImport);
}

function handleFileSelected(file) {
  state.selectedImportFile = file;
  const info = document.getElementById('file-selected-info');
  info.textContent = `Đã chọn: ${file.name} (${(file.size / 1024).toFixed(1)} KB)`;
  info.style.display = 'block';
  document.getElementById('btn-submit-import').disabled = false;

  // Nếu là file JSON, hiển thị preview cấu trúc
  if (file.name.toLowerCase().endsWith('.json')) {
    const reader = new FileReader();
    reader.onload = (e) => {
      try {
        const parsed = JSON.parse(e.target.result);
        const formatted = JSON.stringify(parsed, null, 2);
        document.getElementById('import-preview-content').textContent = formatted.length > 1000
          ? formatted.substring(0, 1000) + '\n... (và các phần còn lại)'
          : formatted;
        document.getElementById('import-preview-box').style.display = 'block';
      } catch (err) {
        document.getElementById('import-preview-content').textContent = '⚠️ File JSON có lỗi định dạng cú pháp!';
        document.getElementById('import-preview-box').style.display = 'block';
      }
    };
    reader.readAsText(file);
  } else {
    document.getElementById('import-preview-box').style.display = 'none';
  }
}

async function handleSubmitImport() {
  if (!state.selectedImportFile) return;

  const skill = document.getElementById('import-skill-type').value;
  const btn = document.getElementById('btn-submit-import');
  btn.disabled = true;
  btn.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> Đang nạp dữ liệu...`;

  const formData = new FormData();
  formData.append('file', state.selectedImportFile);

  try {
    const res = await fetch(`${API_BASE}/admin/skills/import?skill_type=${skill}`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${state.token}`,
      },
      body: formData,
    });

    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.detail || 'Lỗi khi nạp file đề thi');
    }

    document.getElementById('import-modal').classList.remove('active');
    showToast(`✅ ${data.message || 'Nạp đề thi thành công!'}`, 'success');
    loadSkillLessons();
  } catch (err) {
    showToast(`Lỗi: ${err.message}`, 'error');
  } finally {
    btn.disabled = false;
    btn.innerHTML = `<i class="fa-solid fa-upload"></i> Bắt đầu nạp dữ liệu`;
  }
}

async function handleDownloadTemplate() {
  try {
    const template = await apiRequest(`/admin/skills/template?skill_type=${state.selectedSkill}`);
    const jsonStr = JSON.stringify(template, null, 2);
    const blob = new Blob([jsonStr], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = `ielts_${state.selectedSkill}_template.json`;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    showToast(`Đã tải xuống file mẫu ${state.selectedSkill.toUpperCase()} JSON!`, 'success');
  } catch (err) {
    showToast(`Lỗi tải file mẫu: ${err.message}`, 'error');
  }
}

// ─────────────────────────────────────────────────────────────
// TAB VOCABULARY MAPPINGS (82 LABELS)
// ─────────────────────────────────────────────────────────────

async function loadVocabMappings() {
  try {
    const data = await apiRequest('/vocabulary/mappings');
    state.mappings = Array.isArray(data) ? data : [];
    renderVocabTable();
  } catch (e) {
    console.error('Lỗi tải từ vựng:', e);
  }
}

function renderVocabTable() {
  const tbody = document.getElementById('vocab-table-body');
  const searchTerm = (document.getElementById('vocab-search-input').value || '').trim().toLowerCase();
  const bandFilter = document.getElementById('vocab-band-filter').value;

  let filtered = state.mappings.slice();

  if (bandFilter !== 'all') {
    filtered = filtered.filter(m => (m.band_score || '').includes(bandFilter.replace('Band ', '')));
  }

  if (searchTerm) {
    filtered = filtered.filter(m =>
      (m.label || '').toLowerCase().includes(searchTerm) ||
      (m.academic_word || '').toLowerCase().includes(searchTerm) ||
      (m.vietnamese_meaning || '').toLowerCase().includes(searchTerm)
    );
  }

  const totalItems = filtered.length;
  const pBar = document.getElementById('vocab-pagination');

  if (totalItems === 0) {
    tbody.innerHTML = `<tr><td colspan="7" class="text-center py-4" style="color: var(--muted);">Không tìm thấy từ vựng phù hợp</td></tr>`;
    if (pBar) pBar.style.display = 'none';
    return;
  }

  const totalPages = Math.ceil(totalItems / state.vocabPageSize) || 1;
  if (state.vocabPage > totalPages) {
    state.vocabPage = totalPages;
  }
  if (state.vocabPage < 1) {
    state.vocabPage = 1;
  }

  const startIdx = (state.vocabPage - 1) * state.vocabPageSize;
  const pageItems = filtered.slice(startIdx, startIdx + state.vocabPageSize);

  tbody.innerHTML = pageItems.map(m => `
    <tr>
      <td>#${m.id}</td>
      <td><strong><code>${escapeHtml(m.label || '')}</code></strong></td>
      <td style="color: var(--primary); font-weight: 700;">${escapeHtml(m.academic_word || '')}</td>
      <td style="font-family: monospace; color: var(--muted);">${escapeHtml(m.ipa || '')}</td>
      <td><span class="badge-band-score">Band ${m.band_score || '7.0'}</span></td>
      <td>
        <strong>${escapeHtml(m.vietnamese_meaning || '')}</strong>
        ${m.ielts_context ? `<br><small style="color: var(--muted);">${escapeHtml(m.ielts_context)}</small>` : ''}
      </td>
      <td class="text-center">
        <button class="btn-tts" onclick="speakWord('${escapeHtml(m.academic_word || m.label || '')}')" title="Nghe phát âm chuẩn AI">
          <i class="fa-solid fa-volume-high"></i>
        </button>
      </td>
    </tr>
  `).join('');

  renderPaginationBar({
    barId: 'vocab-pagination',
    infoId: 'vocab-pagination-info',
    actionsId: 'vocab-pagination-actions',
    currentPage: state.vocabPage,
    pageSize: state.vocabPageSize,
    totalItems: totalItems,
    pageSizeOptions: [15, 30, 50, 100],
    onPageChange: (newPage) => {
      state.vocabPage = newPage;
      renderVocabTable();
    },
    onPageSizeChange: (newSize) => {
      state.vocabPageSize = newSize;
      state.vocabPage = 1;
      renderVocabTable();
    }
  });
}

function speakWord(word) {
  if (!('speechSynthesis' in window)) {
    showToast('Trình duyệt của bạn không hỗ trợ Web Speech API', 'error');
    return;
  }
  window.speechSynthesis.cancel();
  const utter = new SpeechSynthesisUtterance(word);
  utter.lang = 'en-US';
  utter.rate = 0.9;
  window.speechSynthesis.speak(utter);
}

async function handleResetMappings() {
  if (!confirm('Bạn có chắc chắn muốn khôi phục lại toàn bộ 82 nhãn từ vựng AI gốc theo chuẩn Band 7.0 - 8.5 không?')) {
    return;
  }
  try {
    await apiRequest('/vocabulary/mappings/reset', { method: 'POST' });
    showToast('Đã khôi phục 82 nhãn từ vựng gốc thành công!', 'success');
    loadVocabMappings();
    loadKPIS();
  } catch (err) {
    showToast(`Lỗi khôi phục: ${err.message}`, 'error');
  }
}

// ─────────────────────────────────────────────────────────────
// TAB USERS MANAGEMENT
// ─────────────────────────────────────────────────────────────

async function loadUsers() {
  try {
    const data = await apiRequest('/users/');
    state.users = Array.isArray(data) ? data : [];
    renderUsersTable();
  } catch (e) {
    console.error('Lỗi tải người dùng:', e);
  }
}

function renderUsersTable() {
  const tbody = document.getElementById('users-table-body');
  const totalItems = state.users.length;
  const pBar = document.getElementById('users-pagination');

  if (totalItems === 0) {
    tbody.innerHTML = `<tr><td colspan="6" class="text-center py-4" style="color: var(--muted);">Chưa có tài khoản nào trong hệ thống</td></tr>`;
    if (pBar) pBar.style.display = 'none';
    return;
  }

  const totalPages = Math.ceil(totalItems / state.userPageSize) || 1;
  if (state.userPage > totalPages) {
    state.userPage = totalPages;
  }
  if (state.userPage < 1) {
    state.userPage = 1;
  }

  const startIdx = (state.userPage - 1) * state.userPageSize;
  const pageItems = state.users.slice(startIdx, startIdx + state.userPageSize);

  tbody.innerHTML = pageItems.map(u => {
    const isCurrent = state.user && state.user.id === u.id;
    const isAdmin = u.role === 'admin';
    const dateStr = u.created_at ? u.created_at.substring(0, 10) : 'N/A';
    const emailStr = u.email ? escapeHtml(u.email) : '<span style="color: var(--muted); font-style: italic;">Chưa thiết lập</span>';
    const otpBadge = u.is_email_verified
      ? '<span style="display: inline-block; margin-left: 6px; font-size: 10px; background: rgba(16, 185, 129, 0.15); color: #10B981; padding: 2px 6px; border-radius: 4px; font-weight: 600;"><i class="fa-solid fa-circle-check"></i> Đã xác thực</span>'
      : (u.email ? '<span style="display: inline-block; margin-left: 6px; font-size: 10px; background: rgba(245, 158, 11, 0.15); color: #F59E0B; padding: 2px 6px; border-radius: 4px; font-weight: 600;"><i class="fa-solid fa-clock"></i> Chưa xác thực</span>' : '');

    return `
      <tr>
        <td>#${u.id}</td>
        <td>
          <strong>${escapeHtml(u.username)}</strong>
          ${isCurrent ? `<span style="margin-left: 6px; font-size: 10px; background: var(--primary-light); color: var(--primary); padding: 2px 6px; border-radius: 4px; font-weight: 700;">HIỆN TẠI</span>` : ''}
        </td>
        <td>
          <div>${emailStr} ${otpBadge}</div>
        </td>
        <td>
          <span class="badge-role ${isAdmin ? 'admin' : 'learner'}">
            ${isAdmin ? '<i class="fa-solid fa-shield"></i> ADMIN' : '<i class="fa-solid fa-graduation-cap"></i> LEARNER'}
          </span>
        </td>
        <td>${dateStr}</td>
        <td class="text-center">
          ${!isCurrent ? `
            <button class="btn-icon delete" onclick="handleDeleteUser(${u.id}, '${escapeHtml(u.username)}')" title="Xóa tài khoản">
              <i class="fa-solid fa-trash-can"></i>
            </button>
          ` : `<span style="font-size: 12px; color: var(--muted);">-</span>`}
        </td>
      </tr>
    `;
  }).join('');

  renderPaginationBar({
    barId: 'users-pagination',
    infoId: 'users-pagination-info',
    actionsId: 'users-pagination-actions',
    currentPage: state.userPage,
    pageSize: state.userPageSize,
    totalItems: totalItems,
    pageSizeOptions: [10, 20, 50],
    onPageChange: (newPage) => {
      state.userPage = newPage;
      renderUsersTable();
    },
    onPageSizeChange: (newSize) => {
      state.userPageSize = newSize;
      state.userPage = 1;
      renderUsersTable();
    }
  });
}

async function handleCreateUser(e) {
  e.preventDefault();
  const username = document.getElementById('new-user-username').value.trim();
  const password = document.getElementById('new-user-password').value.trim();
  const role = document.getElementById('new-user-role').value;

  try {
    await apiRequest('/users/', {
      method: 'POST',
      body: JSON.stringify({ username, password, role }),
    });
    showToast(`Đã tạo tài khoản "${username}" thành công!`, 'success');
    document.getElementById('user-modal').classList.remove('active');
    document.getElementById('user-form').reset();
    loadUsers();
    loadKPIS();
  } catch (err) {
    showToast(`Lỗi tạo tài khoản: ${err.message}`, 'error');
  }
}

async function handleDeleteUser(userId, username) {
  if (!confirm(`Bạn có chắc muốn xóa tài khoản "${username}" không?`)) return;

  try {
    await apiRequest(`/users/${userId}`, { method: 'DELETE' });
    showToast(`Đã xóa tài khoản "${username}" thành công!`, 'success');
    loadUsers();
    loadKPIS();
  } catch (err) {
    showToast(`Lỗi xóa tài khoản: ${err.message}`, 'error');
  }
}

// ─────────────────────────────────────────────────────────────
// TOAST NOTIFICATION UTILITY
// ─────────────────────────────────────────────────────────────

function showToast(message, type = 'info') {
  const container = document.getElementById('toast-container');
  const toast = document.createElement('div');
  toast.className = `toast ${type}`;
  toast.innerHTML = `
    <i class="fa-solid ${type === 'success' ? 'fa-circle-check' : 'fa-circle-exclamation'}"></i>
    <span>${message}</span>
  `;
  container.appendChild(toast);

  setTimeout(() => {
    toast.style.opacity = '0';
    toast.style.transform = 'translateY(10px)';
    setTimeout(() => toast.remove(), 300);
  }, 3500);
}

function escapeHtml(text) {
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;',
  };
  return (text || '').replace(/[&<>"']/g, m => map[m]);
}

// ─────────────────────────────────────────────────────────────
// PHÂN HỆ QUẢN TRỊ CẤU HÌNH AI & HỌC TỪ VỰNG (TAB 5)
// ─────────────────────────────────────────────────────────────

function initVocabConfigEventListeners() {
  // Save Config buttons (top and bottom)
  const btnSaveTop = document.getElementById('btn-save-vocab-config-top');
  const btnSaveBottom = document.getElementById('btn-save-vocab-config-bottom');
  if (btnSaveTop) btnSaveTop.addEventListener('click', saveVocabAiConfig);
  if (btnSaveBottom) btnSaveBottom.addEventListener('click', saveVocabAiConfig);

  // Reset Buttons (top and bottom)
  const btnResetTop = document.getElementById('btn-reset-vocab-config-top');
  const btnResetBottom = document.getElementById('btn-reset-vocab-config');
  if (btnResetTop) btnResetTop.addEventListener('click', resetVocabAiConfig);
  if (btnResetBottom) btnResetBottom.addEventListener('click', resetVocabAiConfig);

  // Refresh Models Button
  const btnRefreshModels = document.getElementById('btn-refresh-models');
  if (btnRefreshModels) {
    btnRefreshModels.addEventListener('click', () => fetchOllamaTags(true));
  }

  // Test Model Benchmark Button
  const btnTestModel = document.getElementById('btn-test-model');
  if (btnTestModel) btnTestModel.addEventListener('click', testOllamaModel);

  // Copy JSON Result Button
  const btnCopyJson = document.getElementById('btn-copy-test-json');
  if (btnCopyJson) {
    btnCopyJson.addEventListener('click', () => {
      const jsonEl = document.getElementById('test-result-json');
      if (jsonEl && jsonEl.textContent) {
        navigator.clipboard.writeText(jsonEl.textContent).then(() => {
          showToast('Đã sao chép phản hồi JSON vào Clipboard!', 'success');
        }).catch(() => {
          showToast('Không thể sao chép văn bản!', 'error');
        });
      }
    });
  }

  // Model Select Change
  const modelSelect = document.getElementById('config-model-select');
  if (modelSelect) {
    modelSelect.addEventListener('change', () => {
      validateModelSelection();
      checkFormDirty();
    });
  }

  // Live Sliders Event Listeners
  const tempSlider = document.getElementById('config-temperature');
  if (tempSlider) {
    tempSlider.addEventListener('input', (e) => {
      const val = (parseInt(e.target.value) / 10).toFixed(1);
      document.getElementById('val-temperature').textContent = val;
      updatePresetChipsUI('config-temperature', e.target.value);
      checkFormDirty();
    });
  }

  const quizQSlider = document.getElementById('config-quiz-questions');
  if (quizQSlider) {
    quizQSlider.addEventListener('input', (e) => {
      document.getElementById('val-quiz-questions').textContent = `${e.target.value} câu`;
      updatePresetChipsUI('config-quiz-questions', e.target.value);
      updateQuizRulePreview();
      checkFormDirty();
    });
  }

  const passSlider = document.getElementById('config-pass-percentage');
  if (passSlider) {
    passSlider.addEventListener('input', (e) => {
      const val = parseInt(e.target.value);
      document.getElementById('val-pass-percentage').textContent = `${val}%`;
      updatePresetChipsUI('config-pass-percentage', e.target.value);
      updateQuizRulePreview();

      // Tự động nâng star1 nếu star1 trước đó đang bằng hoặc nhỏ hơn passRate
      const star1Input = document.getElementById('config-star1');
      if (star1Input && parseInt(star1Input.value || 0) < val) {
        star1Input.value = val;
      }
      validateStarThresholds();
      checkFormDirty();
    });
  }

  const genCountSlider = document.getElementById('config-default-gen-count');
  if (genCountSlider) {
    genCountSlider.addEventListener('input', (e) => {
      document.getElementById('val-default-gen-count').textContent = `${e.target.value} từ`;
      updatePresetChipsUI('config-default-gen-count', e.target.value);
      checkFormDirty();
    });
  }

  // Star Inputs Listeners
  ['config-star1', 'config-star2', 'config-star3'].forEach(id => {
    const el = document.getElementById(id);
    if (el) {
      el.addEventListener('input', () => {
        validateStarThresholds();
        checkFormDirty();
      });
    }
  });

  // Auto-cache Toggle Listener
  const autoCache = document.getElementById('config-auto-cache');
  if (autoCache) {
    autoCache.addEventListener('change', () => {
      checkFormDirty();
    });
  }

  // Preset Chips Click Listeners
  document.querySelectorAll('.preset-chip').forEach(chip => {
    chip.addEventListener('click', () => {
      const sliderId = chip.getAttribute('data-slider');
      const val = chip.getAttribute('data-val');
      const slider = document.getElementById(sliderId);
      if (slider) {
        slider.value = val;
        slider.dispatchEvent(new Event('input', { bubbles: true }));
      }
    });
  });

  // Khởi động kiểm tra hệ thống định kỳ (mỗi 25s)
  checkSystemStatus();
  setInterval(checkSystemStatus, 25000);
}

function updateRangeFill(slider) {
  if (!slider) return;
  const min = parseFloat(slider.min || 0);
  const max = parseFloat(slider.max || 100);
  const pct = max > min ? ((parseFloat(slider.value) - min) / (max - min)) * 100 : 0;
  slider.style.setProperty('--fill', `${pct}%`);
}

// Tô màu phần track đã chọn của mọi thanh trượt
document.addEventListener('input', (e) => {
  if (e.target && e.target.classList && e.target.classList.contains('custom-styled-range')) {
    updateRangeFill(e.target);
  }
});
document.addEventListener('DOMContentLoaded', () => {
  document.querySelectorAll('.custom-styled-range').forEach(updateRangeFill);
});

function updatePresetChipsUI(sliderId, activeVal) {
  updateRangeFill(document.getElementById(sliderId));
  document.querySelectorAll(`.preset-chip[data-slider="${sliderId}"]`).forEach(chip => {
    const chipVal = chip.getAttribute('data-val');
    chip.classList.toggle('active', chipVal == activeVal);
  });
}

function updateQuizRulePreview() {
  const questions = parseInt(document.getElementById('config-quiz-questions')?.value || 5);
  const passRate = parseInt(document.getElementById('config-pass-percentage')?.value || 60);
  const minRequired = Math.max(1, Math.ceil(questions * (passRate / 100)));

  const preview = document.getElementById('quiz-rule-preview');
  if (preview) {
    preview.innerHTML = `Học viên cần đạt tối thiểu <strong>${minRequired} / ${questions} câu</strong> (${passRate}%) để vượt qua bài kiểm tra và mở khóa Cấp độ tiếp theo.`;
  }
}

/**
 * Kiểm tra trạng thái Backend (:8000) và Ollama (:11434)
 */
async function checkSystemStatus() {
  // 1. Kiểm tra Backend :8000 qua /api/health
  const backendChip = document.getElementById('topbar-backend-status');
  const fastapiBadge = document.getElementById('status-fastapi');
  try {
    const res = await fetch(`${window.location.origin}/api/health`, { method: 'GET', cache: 'no-cache' });
    if (res.ok) {
      state.isBackendOnline = true;
      if (backendChip) {
        backendChip.className = 'status-chip online';
        backendChip.innerHTML = '<span class="status-dot-pulse green"></span><span class="chip-text">Backend Online (:8000)</span>';
      }
      if (fastapiBadge) {
        fastapiBadge.className = 'status-badge success';
        fastapiBadge.innerHTML = '<i class="fa-solid fa-check"></i> Hoạt động';
      }
    } else {
      throw new Error(`HTTP ${res.status}`);
    }
  } catch (err) {
    // Fallback thử /health
    try {
      const res2 = await fetch(`${window.location.origin}/health`, { method: 'GET', cache: 'no-cache' });
      if (res2.ok) {
        state.isBackendOnline = true;
        if (backendChip) {
          backendChip.className = 'status-chip online';
          backendChip.innerHTML = '<span class="status-dot-pulse green"></span><span class="chip-text">Backend Online (:8000)</span>';
        }
        if (fastapiBadge) {
          fastapiBadge.className = 'status-badge success';
          fastapiBadge.innerHTML = '<i class="fa-solid fa-check"></i> Hoạt động';
        }
      } else {
        throw new Error();
      }
    } catch {
      state.isBackendOnline = false;
      if (backendChip) {
        backendChip.className = 'status-chip offline';
        backendChip.innerHTML = '<span class="status-dot-pulse red"></span><span class="chip-text">Backend Offline</span>';
      }
      if (fastapiBadge) {
        fastapiBadge.className = 'status-badge danger';
        fastapiBadge.innerHTML = '<i class="fa-solid fa-xmark"></i> Gián đoạn';
      }
    }
  }

  // 2. Kiểm tra Ollama :11434 qua /api/tags
  await fetchOllamaTags(false);
}

/**
 * Gọi GET /api/tags để cập nhật danh sách model Ollama
 */
async function fetchOllamaTags(showToastOnManual = false) {
  const ollamaChip = document.getElementById('topbar-ollama-status');
  const statusBadge = document.getElementById('ollama-status-badge');
  const statusText = document.getElementById('ollama-status-text');
  const modelSelect = document.getElementById('config-model-select');
  const modelHint = document.getElementById('config-model-hint');
  const modelCountTag = document.getElementById('model-count-tag');
  const refreshBtn = document.getElementById('btn-refresh-models');

  if (refreshBtn && showToastOnManual) {
    refreshBtn.classList.add('fa-spin');
  }

  let models = [];
  let isOnline = false;

  // Thử 1: Gọi proxy backend /api/tags
  try {
    const res = await fetch(`${window.location.origin}/api/tags`, { method: 'GET', cache: 'no-cache' });
    if (res.ok) {
      const data = await res.json();
      if (data && data.models) {
        models = data.models.map(m => (typeof m === 'string' ? m : (m.name || m.model || ''))).filter(Boolean);
        isOnline = true;
      }
    }
  } catch (e) {
    console.debug('Không thể kết nối /api/tags:', e);
  }

  // Thử 2: Nếu chưa được, gọi /api/v1/admin/tags
  if (!isOnline && state.token) {
    try {
      const data = await apiRequest('/admin/tags');
      if (data && data.models) {
        models = data.models.map(m => (typeof m === 'string' ? m : (m.name || m.model || ''))).filter(Boolean);
        isOnline = Boolean(data.is_online);
      }
    } catch (e) {
      console.debug('Không thể kết nối /admin/tags:', e);
    }
  }

  // Thử 3: Thử trực tiếp localhost:11434 nếu đang chạy client local
  if (!isOnline) {
    try {
      const res = await fetch('http://localhost:11434/api/tags', { method: 'GET', cache: 'no-cache' });
      if (res.ok) {
        const data = await res.json();
        if (data && data.models) {
          models = data.models.map(m => m.name || m.model).filter(Boolean);
          isOnline = true;
        }
      }
    } catch (e) {
      console.debug('Direct localhost:11434 tags unreachable:', e);
    }
  }

  state.isOllamaOnline = isOnline;
  state.availableModels = models;

  // Cập nhật UI Topbar Ollama status
  if (ollamaChip) {
    if (isOnline) {
      ollamaChip.className = 'status-chip online';
      ollamaChip.innerHTML = `<span class="status-dot-pulse green"></span><span class="chip-text">Ollama Online (${models.length} models)</span>`;
    } else {
      ollamaChip.className = 'status-chip offline';
      ollamaChip.innerHTML = '<span class="status-dot-pulse red"></span><span class="chip-text">Ollama Offline (:11434)</span>';
    }
  }

  // Cập nhật Card 1 Status Badge
  if (statusBadge && statusText) {
    if (isOnline) {
      statusBadge.className = 'status-indicator-badge online';
      statusText.textContent = `Trực tuyến (${models.length} models)`;
      if (modelHint) {
        modelHint.innerHTML = `<span class="text-success"><i class="fa-solid fa-check"></i> Đã kết nối Ollama local (:11434). Tìm thấy ${models.length} mô hình.</span>`;
      }
    } else {
      statusBadge.className = 'status-indicator-badge offline';
      statusText.textContent = 'Ngoại tuyến (11434)';
      if (modelHint) {
        modelHint.innerHTML = `<span class="text-danger"><i class="fa-solid fa-triangle-exclamation"></i> Không thể kết nối Ollama tại port 11434. Vui lòng bật Ollama Desktop.</span>`;
      }
    }
  }

  // Cập nhật Card Trạng thái Kiến Trúc Ollama ở trang KPIs
  const ollamaCardBadge = document.getElementById('status-ollama-card');
  const ollamaCardDesc = document.getElementById('status-ollama-desc');
  if (ollamaCardBadge) {
    if (isOnline) {
      ollamaCardBadge.className = 'status-badge success';
      ollamaCardBadge.innerHTML = `<i class="fa-solid fa-check"></i> Sẵn sàng (${models.length} models)`;
    } else {
      ollamaCardBadge.className = 'status-badge danger';
      ollamaCardBadge.innerHTML = '<i class="fa-solid fa-xmark"></i> Ngoại tuyến';
    }
  }
  if (ollamaCardDesc) {
    if (isOnline) {
      const activeModel = models.length > 0 ? ` [${models.slice(0, 3).join(', ')}]` : '';
      ollamaCardDesc.textContent = `Qwen 2.5 7B chấm điểm Writing 4 tiêu chí, giải thích Reading / Listening${activeModel}`;
    } else {
      ollamaCardDesc.textContent = 'Chưa bật Ollama local (:11434) hoặc không tìm thấy model Qwen';
    }
  }

  if (modelCountTag) {
    modelCountTag.textContent = `${models.length} models`;
  }

  // Cập nhật dropdown model nếu có danh sách
  if (modelSelect && models.length > 0) {
    const currentVal = modelSelect.value || (state.vocabConfig?.active_model) || 'qwen2.5:7b';
    modelSelect.innerHTML = '';
    models.forEach(m => {
      const opt = document.createElement('option');
      opt.value = m;
      opt.textContent = m;
      if (m === currentVal) opt.selected = true;
      modelSelect.appendChild(opt);
    });

    // Nếu model hiện tại không nằm trong danh sách models của Ollama, giữ lại nhưng đánh dấu
    if (!models.includes(currentVal)) {
      const opt = document.createElement('option');
      opt.value = currentVal;
      opt.textContent = `${currentVal} (Không có trên Ollama)`;
      opt.selected = true;
      modelSelect.insertBefore(opt, modelSelect.firstChild);
    }
  }

  // Validate model đã chọn
  validateModelSelection();

  if (refreshBtn) {
    refreshBtn.classList.remove('fa-spin');
  }

  if (showToastOnManual) {
    if (isOnline) {
      showToast(`Đã quét Ollama thành công: tìm thấy ${models.length} mô hình!`, 'success');
    } else {
      showToast('Không thể kết nối tới Ollama (:11434). Kiểm tra lại tiến trình Ollama!', 'error');
    }
  }
}

/**
 * Validate model đã lưu/chọn với danh sách trên Ollama
 */
function validateModelSelection() {
  const modelSelect = document.getElementById('config-model-select');
  const alertBox = document.getElementById('model-warning-alert');
  const alertText = document.getElementById('model-warning-text');
  const btnSaveTop = document.getElementById('btn-save-vocab-config-top');
  const btnSaveBottom = document.getElementById('btn-save-vocab-config-bottom');

  if (!modelSelect) return true;
  const currentModel = modelSelect.value;

  if (state.availableModels.length > 0 && !state.availableModels.includes(currentModel)) {
    if (alertBox) {
      alertBox.style.display = 'flex';
      if (alertText) {
        alertText.textContent = `Mô hình "${currentModel}" trong cấu hình không tìm thấy trên Ollama. Vui lòng chọn mô hình đã cài đặt bên dưới trước khi lưu.`;
      }
    }
    if (btnSaveTop) btnSaveTop.disabled = true;
    if (btnSaveBottom) btnSaveBottom.disabled = true;
    return false;
  } else {
    if (alertBox) alertBox.style.display = 'none';
    // Chỉ kích hoạt lại nút lưu nếu star thresholds cũng hợp lệ
    const starsValid = validateStarThresholds(false);
    if (starsValid) {
      if (btnSaveTop) btnSaveTop.disabled = false;
      if (btnSaveBottom) btnSaveBottom.disabled = false;
    }
    return true;
  }
}

/**
 * Validate mốc xếp hạng Sao (0 <= star1 <= star2 <= star3 <= 100, star1 >= pass_percentage)
 */
function validateStarThresholds(updateButtons = true) {
  const star1Input = document.getElementById('config-star1');
  const star2Input = document.getElementById('config-star2');
  const star3Input = document.getElementById('config-star3');
  const passInput = document.getElementById('config-pass-percentage');
  const alertBox = document.getElementById('star-validation-alert');
  const alertMsg = document.getElementById('star-validation-msg');
  const btnSaveTop = document.getElementById('btn-save-vocab-config-top');
  const btnSaveBottom = document.getElementById('btn-save-vocab-config-bottom');

  if (!star1Input || !star2Input || !star3Input) return true;

  const star1 = parseInt(star1Input.value || 0);
  const star2 = parseInt(star2Input.value || 0);
  const star3 = parseInt(star3Input.value || 0);
  const passRate = parseInt(passInput?.value || 60);

  const card1 = document.getElementById('card-star1');
  const card2 = document.getElementById('card-star2');
  const card3 = document.getElementById('card-star3');

  let isValid = true;
  let reason = '';

  if (star1 < 0 || star1 > 100 || star2 < 0 || star2 > 100 || star3 < 0 || star3 > 100) {
    isValid = false;
    reason = 'Mốc sao phải là số nguyên trong khoảng 0% đến 100%!';
  } else if (star1 < passRate) {
    isValid = false;
    reason = `Mốc 1 ⭐ (${star1}%) phải lớn hơn hoặc bằng Tỷ lệ vượt ải (${passRate}%)!`;
  } else if (star1 > star2 || star2 > star3) {
    isValid = false;
    reason = `Thứ tự mốc sao không hợp lệ: Yêu cầu 0 ≤ 1 ⭐ (${star1}%) ≤ 2 ⭐ (${star2}%) ≤ 3 ⭐ (${star3}%) ≤ 100%!`;
  }

  if (card1) card1.classList.toggle('input-error', !isValid && (star1 < passRate || star1 > star2));
  if (card2) card2.classList.toggle('input-error', !isValid && (star2 < star1 || star2 > star3));
  if (card3) card3.classList.toggle('input-error', !isValid && star3 < star2);

  if (!isValid) {
    if (alertBox) {
      alertBox.style.display = 'flex';
      if (alertMsg) alertMsg.textContent = reason;
    }
    if (updateButtons) {
      if (btnSaveTop) btnSaveTop.disabled = true;
      if (btnSaveBottom) btnSaveBottom.disabled = true;
    }
  } else {
    if (alertBox) alertBox.style.display = 'none';
    if (updateButtons) {
      // Chỉ kích hoạt lại nút lưu nếu model cũng hợp lệ
      const modelValid = validateModelSelection();
      if (modelValid) {
        if (btnSaveTop) btnSaveTop.disabled = false;
        if (btnSaveBottom) btnSaveBottom.disabled = false;
      }
    }
  }

  return isValid;
}

/**
 * Kiểm tra xem form hiện tại có khác với cấu hình đã lưu trong CSDL hay không
 */
function checkFormDirty() {
  if (!state.savedVocabConfig) return;

  const saved = state.savedVocabConfig;
  const currentModel = document.getElementById('config-model-select')?.value || '';
  const currentTemp = parseFloat(document.getElementById('config-temperature')?.value || 3) / 10.0;
  const currentQuizQ = parseInt(document.getElementById('config-quiz-questions')?.value || 5);
  const currentPass = parseInt(document.getElementById('config-pass-percentage')?.value || 60);
  const currentGen = parseInt(document.getElementById('config-default-gen-count')?.value || 5);
  const currentAutoCache = Boolean(document.getElementById('config-auto-cache')?.checked);
  const currentStar1 = parseInt(document.getElementById('config-star1')?.value || 60);
  const currentStar2 = parseInt(document.getElementById('config-star2')?.value || 80);
  const currentStar3 = parseInt(document.getElementById('config-star3')?.value || 100);

  const savedTemp = saved.temperature !== undefined ? saved.temperature : 0.3;
  const savedStars = saved.star_thresholds || { star1: 60, star2: 80, star3: 100 };

  const isDirty = (
    currentModel !== saved.active_model ||
    Math.abs(currentTemp - savedTemp) > 0.01 ||
    currentQuizQ !== saved.quiz_question_count ||
    currentPass !== saved.pass_percentage ||
    currentGen !== saved.default_gen_count ||
    currentAutoCache !== Boolean(saved.auto_cache_enabled) ||
    currentStar1 !== savedStars.star1 ||
    currentStar2 !== savedStars.star2 ||
    currentStar3 !== savedStars.star3
  );

  updateUnsavedState(isDirty);
}

function updateUnsavedState(isDirty) {
  const topbarBadge = document.getElementById('topbar-unsaved-indicator');
  const headerBadge = document.getElementById('header-unsaved-badge');
  const footerBadge = document.getElementById('footer-unsaved-badge');

  const displayVal = isDirty ? 'inline-flex' : 'none';
  if (topbarBadge) topbarBadge.style.display = displayVal;
  if (headerBadge) headerBadge.style.display = displayVal;
  if (footerBadge) footerBadge.style.display = displayVal;
}

/**
 * Tải cấu hình AI & Học tập từ Backend
 */
async function loadVocabAiConfig(showNotification = false) {
  try {
    let data;
    try {
      data = await apiRequest('/admin/ai-config');
    } catch {
      data = await apiRequest('/admin/vocab-config');
    }

    state.vocabConfig = data;
    state.savedVocabConfig = JSON.parse(JSON.stringify(data));

    renderVocabAiConfig(data);
    updateUnsavedState(false);

    if (showNotification) {
      showToast('Đã làm mới thông tin Model và Cấu hình từ CSDL!', 'success');
    }
  } catch (err) {
    console.error('Lỗi tải cấu hình học từ vựng:', err);
    if (showNotification) {
      showToast(`Không thể tải cấu hình AI: ${err.message}`, 'error');
    }
  }
}

/**
 * Đổ dữ liệu cấu hình vào form
 */
function renderVocabAiConfig(cfg) {
  if (!cfg) return;

  // 1. Ollama Status & Models
  const modelSelect = document.getElementById('config-model-select');
  if (cfg.available_models && cfg.available_models.length > 0) {
    state.availableModels = cfg.available_models;
    modelSelect.innerHTML = '';
    cfg.available_models.forEach(m => {
      const opt = document.createElement('option');
      opt.value = m;
      opt.textContent = m;
      if (m === cfg.active_model) opt.selected = true;
      modelSelect.appendChild(opt);
    });

    if (!cfg.available_models.includes(cfg.active_model)) {
      const opt = document.createElement('option');
      opt.value = cfg.active_model;
      opt.textContent = `${cfg.active_model} (Không có trên Ollama)`;
      opt.selected = true;
      modelSelect.insertBefore(opt, modelSelect.firstChild);
    }
  } else if (modelSelect) {
    modelSelect.value = cfg.active_model;
  }

  // 2. Temperature
  const tempSlider = document.getElementById('config-temperature');
  const tempVal = document.getElementById('val-temperature');
  const tempFloat = cfg.temperature !== undefined ? cfg.temperature : 0.3;
  if (tempSlider) {
    tempSlider.value = Math.round(tempFloat * 10);
    updatePresetChipsUI('config-temperature', tempSlider.value);
  }
  if (tempVal) tempVal.textContent = tempFloat.toFixed(1);

  // 3. Quiz Settings
  const quizQSlider = document.getElementById('config-quiz-questions');
  const quizQVal = document.getElementById('val-quiz-questions');
  if (quizQSlider) {
    quizQSlider.value = cfg.quiz_question_count || 5;
    updatePresetChipsUI('config-quiz-questions', quizQSlider.value);
  }
  if (quizQVal) quizQVal.textContent = `${quizQSlider.value} câu`;

  const passSlider = document.getElementById('config-pass-percentage');
  const passVal = document.getElementById('val-pass-percentage');
  if (passSlider) {
    passSlider.value = cfg.pass_percentage || 60;
    updatePresetChipsUI('config-pass-percentage', passSlider.value);
  }
  if (passVal) passVal.textContent = `${passSlider.value}%`;

  updateQuizRulePreview();

  // 4. Star Thresholds
  const stars = cfg.star_thresholds || { star1: 60, star2: 80, star3: 100 };
  const star1 = document.getElementById('config-star1');
  const star2 = document.getElementById('config-star2');
  const star3 = document.getElementById('config-star3');
  if (star1) star1.value = stars.star1 !== undefined ? stars.star1 : 60;
  if (star2) star2.value = stars.star2 !== undefined ? stars.star2 : 80;
  if (star3) star3.value = stars.star3 !== undefined ? stars.star3 : 100;

  // 5. Vocab Generation Settings
  const genSlider = document.getElementById('config-default-gen-count');
  const genVal = document.getElementById('val-default-gen-count');
  if (genSlider) {
    genSlider.value = cfg.default_gen_count || 5;
    updatePresetChipsUI('config-default-gen-count', genSlider.value);
  }
  if (genVal) genVal.textContent = `${genSlider.value} từ`;

  const autoCache = document.getElementById('config-auto-cache');
  if (autoCache) autoCache.checked = Boolean(cfg.auto_cache_enabled);

  // 6. Updated Timestamp
  updateTimestampUI(cfg.updated_at);

  // Validate ban đầu
  validateModelSelection();
  validateStarThresholds();
}

function updateTimestampUI(timestamp) {
  const lastUpdated = document.getElementById('config-last-updated');
  const topbarLastSync = document.getElementById('topbar-last-sync-text');

  if (timestamp) {
    const dt = new Date(timestamp);
    const timeFormatted = dt.toLocaleString('vi-VN');
    if (lastUpdated) lastUpdated.textContent = timeFormatted;
    if (topbarLastSync) topbarLastSync.textContent = `Cập nhật: ${timeFormatted}`;
  } else {
    if (lastUpdated) lastUpdated.textContent = 'Chưa có dữ liệu';
    if (topbarLastSync) topbarLastSync.textContent = 'Cập nhật: --';
  }
}

/**
 * Lưu cấu hình hệ thống xuống backend qua PUT /api/admin/ai-config
 */
async function saveVocabAiConfig() {
  if (!validateModelSelection()) {
    showToast('Vui lòng chọn một mô hình hợp lệ đã cài trên Ollama trước khi lưu!', 'error');
    return;
  }

  if (!validateStarThresholds()) {
    showToast('Vui lòng kiểm tra lại mốc xếp hạng Sao cho đúng quy tắc trước khi lưu!', 'error');
    return;
  }

  const model = document.getElementById('config-model-select').value;
  const temp = parseFloat(document.getElementById('config-temperature').value) / 10.0;
  const quizQuestions = parseInt(document.getElementById('config-quiz-questions').value);
  const passRate = parseInt(document.getElementById('config-pass-percentage').value);
  const genCount = parseInt(document.getElementById('config-default-gen-count').value);
  const autoCache = document.getElementById('config-auto-cache').checked;
  const star1 = parseInt(document.getElementById('config-star1').value);
  const star2 = parseInt(document.getElementById('config-star2').value);
  const star3 = parseInt(document.getElementById('config-star3').value);

  const payload = {
    active_model: model,
    temperature: temp,
    quiz_question_count: quizQuestions,
    pass_percentage: passRate,
    default_gen_count: genCount,
    auto_cache_enabled: autoCache,
    star_thresholds: {
      star1: star1,
      star2: star2,
      star3: star3,
    },
  };

  const btnSaveTop = document.getElementById('btn-save-vocab-config-top');
  const btnSaveBottom = document.getElementById('btn-save-vocab-config-bottom');
  const origHtmlTop = btnSaveTop ? btnSaveTop.innerHTML : '';
  const origHtmlBottom = btnSaveBottom ? btnSaveBottom.innerHTML : '';

  if (btnSaveTop) {
    btnSaveTop.disabled = true;
    btnSaveTop.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Đang lưu...';
  }
  if (btnSaveBottom) {
    btnSaveBottom.disabled = true;
    btnSaveBottom.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Đang lưu...';
  }

  try {
    let updated;
    try {
      updated = await apiRequest('/admin/ai-config', {
        method: 'PUT',
        body: JSON.stringify(payload),
      });
    } catch {
      updated = await apiRequest('/admin/vocab-config', {
        method: 'PUT',
        body: JSON.stringify(payload),
      });
    }

    state.vocabConfig = updated;
    state.savedVocabConfig = JSON.parse(JSON.stringify(updated));

    renderVocabAiConfig(updated);
    updateUnsavedState(false);

    showToast('Đã lưu cấu hình AI & Học tập thành công! Toàn bộ thay đổi được đồng bộ tức thì tới Mobile App.', 'success');
  } catch (err) {
    // Nếu lưu lỗi, giữ nguyên dữ liệu trên form và hiển thị lỗi
    showToast(`Lỗi khi lưu cấu hình: ${err.message}`, 'error');
  } finally {
    if (btnSaveTop) {
      btnSaveTop.disabled = false;
      btnSaveTop.innerHTML = origHtmlTop;
    }
    if (btnSaveBottom) {
      btnSaveBottom.disabled = false;
      btnSaveBottom.innerHTML = origHtmlBottom;
    }
  }
}

/**
 * Khôi phục mặc định (Client-side only)
 */
function resetVocabAiConfig() {
  if (!confirm('Khôi phục toàn bộ các giá trị trên form về mặc định ban đầu? (Dữ liệu chưa ghi vào CSDL cho tới khi bạn bấm "Lưu Cấu Hình Hệ Thống")')) {
    return;
  }

  // 1. Model: qwen2.5:7b (hoặc model đầu tiên có trên Ollama)
  const modelSelect = document.getElementById('config-model-select');
  if (modelSelect) {
    if (state.availableModels.includes('qwen2.5:7b')) {
      modelSelect.value = 'qwen2.5:7b';
    } else if (state.availableModels.length > 0) {
      modelSelect.value = state.availableModels[0];
    } else {
      modelSelect.value = 'qwen2.5:7b';
    }
  }

  // 2. Temperature: 0.3
  const tempSlider = document.getElementById('config-temperature');
  if (tempSlider) {
    tempSlider.value = 3;
    document.getElementById('val-temperature').textContent = '0.3';
    updatePresetChipsUI('config-temperature', 3);
  }

  // 3. Quiz Questions: 5
  const quizQSlider = document.getElementById('config-quiz-questions');
  if (quizQSlider) {
    quizQSlider.value = 5;
    document.getElementById('val-quiz-questions').textContent = '5 câu';
    updatePresetChipsUI('config-quiz-questions', 5);
  }

  // 4. Pass Percentage: 60%
  const passSlider = document.getElementById('config-pass-percentage');
  if (passSlider) {
    passSlider.value = 60;
    document.getElementById('val-pass-percentage').textContent = '60%';
    updatePresetChipsUI('config-pass-percentage', 60);
  }

  // 5. Star Thresholds: 60, 80, 100
  const star1 = document.getElementById('config-star1');
  const star2 = document.getElementById('config-star2');
  const star3 = document.getElementById('config-star3');
  if (star1) star1.value = 60;
  if (star2) star2.value = 80;
  if (star3) star3.value = 100;

  // 6. Gen count: 5
  const genSlider = document.getElementById('config-default-gen-count');
  if (genSlider) {
    genSlider.value = 5;
    document.getElementById('val-default-gen-count').textContent = '5 từ';
    updatePresetChipsUI('config-default-gen-count', 5);
  }

  // 7. Auto cache: true
  const autoCache = document.getElementById('config-auto-cache');
  if (autoCache) autoCache.checked = true;

  updateQuizRulePreview();
  validateModelSelection();
  validateStarThresholds();
  checkFormDirty();

  showToast('Đã khôi phục các tham số mặc định trên giao diện! Nhấn "Lưu Cấu Hình Hệ Thống" để áp dụng vào CSDL.', 'info');
}

/**
 * Benchmark Test Model (gửi prompt sinh 1 từ JSON, đo ms, timeout 30s)
 */
async function testOllamaModel() {
  const modelSelect = document.getElementById('config-model-select');
  const modelName = modelSelect ? modelSelect.value : 'qwen2.5:7b';
  const btn = document.getElementById('btn-test-model');
  const resultBox = document.getElementById('test-model-result');
  const resultBadge = document.getElementById('test-result-badge');
  const resultMsg = document.getElementById('test-result-msg');
  const resultJson = document.getElementById('test-result-json');

  if (!btn) return;
  const originalHtml = btn.innerHTML;
  btn.disabled = true;
  btn.innerHTML = '<i class="fa-solid fa-spinner fa-spin"></i> Đang test model (tối đa 30s)...';

  // Prompt cố định chuẩn theo yêu cầu
  const fixedPrompt = 'Generate a JSON object with 1 IELTS vocabulary word containing exact keys: "word", "meaning", "example". Example: {"word": "resilient", "meaning": "kiên cường, có khả năng phục hồi", "example": "She remained resilient in the face of difficulties."}. Output JSON only, no markdown, no other text.';

  try {
    let res;
    try {
      res = await apiRequest('/admin/ai-config/test-model', {
        method: 'POST',
        body: JSON.stringify({ model_name: modelName, test_prompt: fixedPrompt }),
      });
    } catch {
      res = await apiRequest('/admin/vocab-config/test-model', {
        method: 'POST',
        body: JSON.stringify({ model_name: modelName, test_prompt: fixedPrompt }),
      });
    }

    resultBox.style.display = 'block';

    if (res.success) {
      const latencyClass = res.latency_ms < 3000 ? 'badge-success' : (res.latency_ms < 8000 ? 'badge-warning' : 'badge-danger');
      resultBadge.className = `latency-badge ${latencyClass}`;
      resultBadge.textContent = `${res.latency_ms} ms`;
      resultMsg.className = 'latency-msg text-success font-weight-bold';
      resultMsg.textContent = res.message;

      // Hiển thị và format JSON
      let formattedJson = res.sample_response || '';
      try {
        const parsed = JSON.parse(formattedJson);
        formattedJson = JSON.stringify(parsed, null, 2);
      } catch {
        // Raw text nếu đã parse rồi
      }
      resultJson.textContent = formattedJson || '{"status": "valid"}';
      showToast(`Model ${modelName} phản hồi hợp lệ trong ${res.latency_ms}ms!`, 'success');
    } else {
      resultBadge.className = 'latency-badge badge-danger';
      resultBadge.textContent = 'Thất bại';
      resultMsg.className = 'latency-msg text-danger font-weight-bold';
      resultMsg.textContent = res.message || 'Lỗi xử lý JSON hoặc kết nối';
      resultJson.textContent = res.sample_response || 'Model không trả về JSON hợp lệ hoặc tiến trình bị ngắt.';
      showToast(`Test model thất bại: ${res.message}`, 'error');
    }
  } catch (err) {
    resultBox.style.display = 'block';
    resultBadge.className = 'latency-badge badge-danger';
    resultBadge.textContent = 'Lỗi kết nối';
    resultMsg.className = 'latency-msg text-danger font-weight-bold';
    resultMsg.textContent = err.message || 'Không thể gửi yêu cầu kiểm tra';
    resultJson.textContent = 'Lỗi khi gửi yêu cầu tới endpoint test-model. Kiểm tra server backend và Ollama.';
    showToast(`Test model thất bại: ${err.message}`, 'error');
  } finally {
    btn.disabled = false;
    btn.innerHTML = originalHtml;
  }
}


// Gắn các hàm gọi từ inline onclick vào window để đảm bảo tương thích mọi trình duyệt
window.openLessonModal = openLessonModal;
window.handleDeleteLesson = handleDeleteLesson;
window.addQuestionItem = addQuestionItem;
window.removeQuestionItem = removeQuestionItem;
window.openImportModal = openImportModal;
window.downloadTemplate = downloadTemplate;
window.speakWord = speakWord;
window.handleDeleteUser = handleDeleteUser;

// ─────────────────────────────────────────────────────────────
// PHÂN HỆ QUẢN LÝ LỊCH SỬ CHẤM ĐIỂM & GIẢI THÍCH AI QWEN
// ─────────────────────────────────────────────────────────────

let aiSearchDebounceTimer = null;

function initAiGradingEventListeners() {
  // 1. Feature Pills
  document.querySelectorAll('#ai-feature-pills .ai-pill').forEach(pill => {
    pill.addEventListener('click', () => {
      document.querySelectorAll('#ai-feature-pills .ai-pill').forEach(p => p.classList.remove('active'));
      pill.classList.add('active');
      state.aiLogSelectedFeature = pill.getAttribute('data-feature') || 'all';
      state.aiLogPage = 1;
      loadAiGradingLogs();
    });
  });

  // 2. Tìm kiếm (Debounce 350ms)
  const searchInput = document.getElementById('ai-log-search-input');
  if (searchInput) {
    searchInput.addEventListener('input', (e) => {
      clearTimeout(aiSearchDebounceTimer);
      aiSearchDebounceTimer = setTimeout(() => {
        state.aiLogSearchTerm = e.target.value.trim();
        state.aiLogPage = 1;
        loadAiGradingLogs();
      }, 350);
    });
  }

  // 3. Bộ lọc trạng thái
  const statusFilter = document.getElementById('ai-status-filter');
  if (statusFilter) {
    statusFilter.addEventListener('change', (e) => {
      state.aiLogSelectedStatus = e.target.value;
      state.aiLogPage = 1;
      loadAiGradingLogs();
    });
  }

  // 4. Bộ lọc nguồn (AI suy luận vs Cache)
  const cacheFilter = document.getElementById('ai-cache-filter');
  if (cacheFilter) {
    cacheFilter.addEventListener('change', (e) => {
      state.aiLogSelectedCache = e.target.value;
      state.aiLogPage = 1;
      loadAiGradingLogs();
    });
  }

  // 5. Xóa bộ lọc
  const resetBtn = document.getElementById('btn-reset-ai-filters');
  if (resetBtn) {
    resetBtn.addEventListener('click', () => {
      state.aiLogSelectedFeature = 'all';
      state.aiLogSelectedStatus = 'all';
      state.aiLogSelectedCache = 'all';
      state.aiLogSearchTerm = '';
      state.aiLogPage = 1;

      document.querySelectorAll('#ai-feature-pills .ai-pill').forEach(p => {
        p.classList.toggle('active', p.getAttribute('data-feature') === 'all');
      });
      if (searchInput) searchInput.value = '';
      if (statusFilter) statusFilter.value = 'all';
      if (cacheFilter) cacheFilter.value = 'all';

      loadAiGradingLogs();
      showToast('Đã xóa toàn bộ bộ lọc lịch sử AI!', 'info');
    });
  }

  // 6. Làm mới dữ liệu
  const refreshBtn = document.getElementById('btn-refresh-ai-logs');
  if (refreshBtn) {
    refreshBtn.addEventListener('click', () => {
      loadAiGradingData();
      showToast('Đã làm mới lịch sử chấm điểm AI!', 'success');
    });
  }

  // 7. Xuất file CSV
  const exportBtn = document.getElementById('btn-export-ai-logs-csv');
  if (exportBtn) {
    exportBtn.addEventListener('click', handleExportAiLogsCsv);
  }

  // 8. Chọn tất cả checkbox
  const checkAllBox = document.getElementById('check-all-ai-logs');
  if (checkAllBox) {
    checkAllBox.addEventListener('change', (e) => {
      const isChecked = e.target.checked;
      document.querySelectorAll('.ai-log-row-check').forEach(cb => {
        cb.checked = isChecked;
        const id = cb.getAttribute('data-id');
        if (isChecked) {
          state.selectedLogIds.add(id);
        } else {
          state.selectedLogIds.delete(id);
        }
      });
      updateBulkDeleteUI();
    });
  }

  // 9. Nút xóa hàng loạt
  const bulkDeleteBtn = document.getElementById('btn-bulk-delete-ai-logs');
  if (bulkDeleteBtn) {
    bulkDeleteBtn.addEventListener('click', handleBulkDeleteAiLogs);
  }

  // 10. Phân trang Prev / Next
  const prevBtn = document.getElementById('btn-ai-logs-prev');
  if (prevBtn) {
    prevBtn.addEventListener('click', () => {
      if (state.aiLogPage > 1) {
        state.aiLogPage--;
        loadAiGradingLogs();
      }
    });
  }
  const nextBtn = document.getElementById('btn-ai-logs-next');
  if (nextBtn) {
    nextBtn.addEventListener('click', () => {
      if (state.aiLogPage < state.aiLogTotalPages) {
        state.aiLogPage++;
        loadAiGradingLogs();
      }
    });
  }

  // 11. Xóa bản ghi trong Modal
  const deleteThisBtn = document.getElementById('btn-delete-this-log');
  if (deleteThisBtn) {
    deleteThisBtn.addEventListener('click', () => {
      if (state.currentViewingLogId) {
        handleDeleteAiLog(state.currentViewingLogId, true);
      }
    });
  }
}

async function loadAiGradingData() {
  await Promise.all([
    loadAiGradingStats(),
    loadAiGradingLogs(),
  ]);
}

async function loadAiGradingStats() {
  try {
    const stats = await apiRequest('/admin/ai-grading/stats');
    if (!stats) return;

    // Tổng số request
    document.getElementById('ai-stat-total').textContent = (stats.total_requests || 0).toLocaleString();
    const fc = stats.feature_counts || {};
    document.getElementById('ai-stat-feature-breakdown').textContent = 
      `Writing: ${fc.writing_grading || 0} · Reading: ${fc.reading_explain || 0} · Listening: ${fc.listening_explain || 0} · Vocab: ${fc.vocab_sentence || 0}`;

    // Tỷ lệ trạng thái
    const sc = stats.status_counts || {};
    const successTotal = sc.success || 0;
    const total = stats.total_requests || 0;
    const successRate = total > 0 ? Math.round((successTotal / total) * 100) : 100;
    document.getElementById('ai-stat-status-ratio').textContent = `${successRate}%`;
    document.getElementById('ai-stat-status-counts').textContent = 
      `Thành công: ${successTotal} · Fallback: ${sc.fallback || 0} · Lỗi: ${sc.error || 0}`;

    // Độ trễ & Cache
    document.getElementById('ai-stat-latency').textContent = `${stats.avg_latency_ms || 0} ms`;
    document.getElementById('ai-stat-cache-rate').textContent = 
      `Cache Hit: ${stats.cache_hits || 0} (${stats.cache_hit_rate || 0}%)`;

    // Điểm trung bình
    const writingBand = stats.writing_avg_band ? `Band ${stats.writing_avg_band}` : 'Band --';
    document.getElementById('ai-stat-avg-score').textContent = writingBand;
    const vocabScore = stats.vocab_avg_score ? `${stats.vocab_avg_score}/100` : '--/100';
    document.getElementById('ai-stat-avg-vocab').textContent = `Câu từ vựng: ${vocabScore}`;
  } catch (err) {
    console.error('Lỗi tải thống kê AI:', err);
  }
}

async function loadAiGradingLogs() {
  const tbody = document.getElementById('ai-logs-table-body');
  if (!tbody) return;

  tbody.innerHTML = `
    <tr>
      <td colspan="9" class="text-center py-4" style="color: var(--text-muted);">
        <i class="fa-solid fa-spinner fa-spin"></i> Đang tải dữ liệu...
      </td>
    </tr>
  `;

  try {
    const params = new URLSearchParams({
      page: state.aiLogPage,
      page_size: state.aiLogPageSize,
    });

    if (state.aiLogSelectedFeature && state.aiLogSelectedFeature !== 'all') {
      params.append('feature', state.aiLogSelectedFeature);
    }
    if (state.aiLogSelectedStatus && state.aiLogSelectedStatus !== 'all') {
      params.append('status', state.aiLogSelectedStatus);
    }
    if (state.aiLogSelectedCache && state.aiLogSelectedCache !== 'all') {
      params.append('from_cache', state.aiLogSelectedCache);
    }
    if (state.aiLogSearchTerm) {
      params.append('search', state.aiLogSearchTerm);
    }

    const res = await apiRequest(`/admin/ai-grading/logs?${params.toString()}`);
    state.aiLogs = res.items || [];
    state.aiLogTotal = res.total || 0;
    state.aiLogPage = res.page || 1;
    state.aiLogTotalPages = res.total_pages || 1;

    // Reset selection khi đổi trang
    state.selectedLogIds.clear();
    const checkAll = document.getElementById('check-all-ai-logs');
    if (checkAll) checkAll.checked = false;
    updateBulkDeleteUI();

    renderAiGradingTable();
    updateAiGradingPaginationUI();
  } catch (err) {
    tbody.innerHTML = `
      <tr>
        <td colspan="9" class="text-center py-4 text-danger">
          <i class="fa-solid fa-triangle-exclamation"></i> Lỗi tải danh sách log: ${escapeHtml(err.message)}
        </td>
      </tr>
    `;
  }
}

function renderAiGradingTable() {
  const tbody = document.getElementById('ai-logs-table-body');
  if (!tbody) return;

  if (state.aiLogs.length === 0) {
    tbody.innerHTML = `
      <tr>
        <td colspan="9" class="text-center py-5" style="color: var(--text-muted);">
          <i class="fa-regular fa-folder-open fa-2x mb-2" style="display:block; opacity: 0.5;"></i>
          Không tìm thấy lượt chấm điểm nào khớp với bộ lọc hiện tại.
        </td>
      </tr>
    `;
    return;
  }

  tbody.innerHTML = state.aiLogs.map(item => {
    // 1. Phân loại feature badge
    let featureBadge = '';
    if (item.feature === 'writing_grading') {
      featureBadge = '<span class="badge-feature writing"><i class="fa-solid fa-pen-nib"></i> Writing</span>';
    } else if (item.feature === 'reading_explain') {
      featureBadge = '<span class="badge-feature reading"><i class="fa-solid fa-book-open"></i> Reading</span>';
    } else if (item.feature === 'listening_explain') {
      featureBadge = '<span class="badge-feature listening"><i class="fa-solid fa-headphones"></i> Listening</span>';
    } else if (item.feature === 'vocab_sentence') {
      featureBadge = '<span class="badge-feature vocab"><i class="fa-solid fa-brain"></i> Từ Vựng</span>';
    } else {
      featureBadge = `<span class="badge-feature">${escapeHtml(item.feature)}</span>`;
    }

    // 2. Định dạng ngày giờ
    const d = new Date(item.created_at);
    const dateStr = d.toLocaleDateString('vi-VN', { day: '2-digit', month: '2-digit', year: 'numeric' });
    const timeStr = d.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });

    // 3. Hiển thị đối tượng (Tiêu đề bài hoặc từ vựng)
    const subject = item.lesson_title || item.vocab_word || item.lesson_id || '(Không rõ)';
    const subText = item.vocab_level ? `Cấp độ ${item.vocab_level}` : (item.lesson_id ? `Mã: ${item.lesson_id}` : '');

    // 4. Kết quả (Band / Điểm / Đúng-Sai)
    let resultHtml = '';
    if (item.feature === 'writing_grading') {
      resultHtml = `<strong style="color: #2563eb; font-size: 13.5px;">Band ${item.band_score || '--'}</strong>`;
    } else if (item.feature === 'vocab_sentence') {
      resultHtml = `<strong style="color: #7c3aed;">${item.score_numeric !== null ? item.score_numeric : '--'}/100</strong>`;
    } else {
      resultHtml = item.is_correct 
        ? '<span class="badge-ai-status success"><i class="fa-solid fa-check"></i> Đúng</span>'
        : '<span class="badge-ai-status fallback"><i class="fa-solid fa-xmark"></i> Chưa đúng</span>';
    }

    // 5. Badge Trạng thái & Model
    let statusBadge = '';
    if (item.status === 'success') {
      statusBadge = '<span class="badge-ai-status success"><i class="fa-solid fa-circle-check"></i> AI Thành công</span>';
    } else if (item.status === 'fallback') {
      statusBadge = '<span class="badge-ai-status fallback"><i class="fa-solid fa-shield-halved"></i> Fallback</span>';
    } else {
      statusBadge = '<span class="badge-ai-status error"><i class="fa-solid fa-circle-xmark"></i> Lỗi</span>';
    }
    const cacheBadge = item.from_cache ? '<span class="badge-cache" title="Lấy từ Cache"><i class="fa-solid fa-bolt"></i> Cache</span>' : '';

    return `
      <tr class="${state.selectedLogIds.has(item.id) ? 'selected-row' : ''}">
        <td class="text-center">
          <input type="checkbox" class="ai-log-row-check" data-id="${item.id}" ${state.selectedLogIds.has(item.id) ? 'checked' : ''} />
        </td>
        <td style="font-size: 12px; color: #475569;">
          <div><strong>${timeStr}</strong></div>
          <div style="font-size: 11px; color: #94a3b8;">${dateStr}</div>
        </td>
        <td>
          <div style="font-weight: 600; color: #1e293b;">${escapeHtml(item.username || 'Khách')}</div>
        </td>
        <td>${featureBadge}</td>
        <td>
          <div style="font-weight: 600; color: #0f172a; max-width: 240px; overflow: hidden; text-overflow: ellipsis; white-space: nowrap;" title="${escapeHtml(subject)}">
            ${escapeHtml(subject)}
          </div>
          ${subText ? `<div style="font-size: 11px; color: #64748b;">${escapeHtml(subText)}</div>` : ''}
        </td>
        <td class="text-center">${resultHtml}</td>
        <td>
          <div style="font-size: 12px; font-weight: 500; color: #334155;">${escapeHtml(item.model_name || 'qwen2.5:7b')}</div>
          <div style="margin-top: 3px;">${statusBadge}${cacheBadge}</div>
        </td>
        <td class="text-center" style="font-size: 12px; font-weight: 600; color: ${item.latency_ms > 10000 ? '#ea580c' : '#475569'};">
          ${item.from_cache ? '<span style="color:#059669;">~0 ms</span>' : `${item.latency_ms.toLocaleString()} ms`}
        </td>
        <td class="text-center">
          <div style="display: inline-flex; gap: 6px;">
            <button class="btn btn-outline btn-sm" onclick="openAiLogDetail('${item.id}')" title="Xem chi tiết kết quả AI">
              <i class="fa-solid fa-eye"></i>
            </button>
            <button class="btn btn-outline btn-sm text-danger" onclick="handleDeleteAiLog('${item.id}', false)" title="Xóa bản ghi này">
              <i class="fa-solid fa-trash-can"></i>
            </button>
          </div>
        </td>
      </tr>
    `;
  }).join('');

  // Gắn sự kiện checkbox từng hàng
  document.querySelectorAll('.ai-log-row-check').forEach(cb => {
    cb.addEventListener('change', (e) => {
      const id = e.target.getAttribute('data-id');
      if (e.target.checked) {
        state.selectedLogIds.add(id);
      } else {
        state.selectedLogIds.delete(id);
      }
      updateBulkDeleteUI();
    });
  });
}

function updateBulkDeleteUI() {
  const count = state.selectedLogIds.size;
  const btn = document.getElementById('btn-bulk-delete-ai-logs');
  const countSpan = document.getElementById('bulk-selected-count');
  if (btn && countSpan) {
    if (count > 0) {
      countSpan.textContent = count;
      btn.style.display = 'inline-flex';
    } else {
      btn.style.display = 'none';
    }
  }
}

function updateAiGradingPaginationUI() {
  renderPaginationBar({
    barId: 'ai-logs-pagination',
    infoId: 'ai-logs-pagination-info',
    actionsId: 'ai-logs-pagination-actions',
    currentPage: state.aiLogPage,
    pageSize: state.aiLogPageSize,
    totalItems: state.aiLogTotal,
    pageSizeOptions: [10, 20, 50, 100],
    onPageChange: (newPage) => {
      state.aiLogPage = newPage;
      loadAiGradingLogs();
    },
    onPageSizeChange: (newSize) => {
      state.aiLogPageSize = newSize;
      state.aiLogPage = 1;
      loadAiGradingLogs();
    }
  });
}

// ─────────────────────────────────────────────────────────────
// MODAL CHI TIẾT KẾT QUẢ AI
// ─────────────────────────────────────────────────────────────

async function openAiLogDetail(logId) {
  state.currentViewingLogId = logId;
  const modal = document.getElementById('ai-log-detail-modal');
  const modalBody = document.getElementById('ai-log-modal-body');
  if (!modal || !modalBody) return;

  modal.classList.add('active');
  modalBody.innerHTML = `
    <div class="text-center py-5" style="color: var(--text-muted);">
      <i class="fa-solid fa-spinner fa-spin fa-2x mb-2" style="display:block;"></i>
      Đang tải chi tiết lượt chấm...
    </div>
  `;

  try {
    const data = await apiRequest(`/admin/ai-grading/logs/${logId}`);
    renderAiLogDetailContent(data);
  } catch (err) {
    modalBody.innerHTML = `
      <div class="text-center py-4 text-danger">
        <i class="fa-solid fa-triangle-exclamation fa-2x mb-2"></i>
        <p>Lỗi tải chi tiết: ${escapeHtml(err.message)}</p>
      </div>
    `;
  }
}

function renderAiLogDetailContent(item) {
  const modalBody = document.getElementById('ai-log-modal-body');
  if (!modalBody) return;

  const resJson = item.result_json || {};
  const d = new Date(item.created_at);
  const timeFormatted = d.toLocaleString('vi-VN');

  // Metadata Box
  const metaHtml = `
    <div class="ai-detail-meta-grid">
      <div class="ai-meta-item">
        <span class="ai-meta-title">Học viên</span>
        <span class="ai-meta-value">${escapeHtml(item.username || 'Khách')}</span>
      </div>
      <div class="ai-meta-item">
        <span class="ai-meta-title">Thời gian thực hiện</span>
        <span class="ai-meta-value">${timeFormatted}</span>
      </div>
      <div class="ai-meta-item">
        <span class="ai-meta-title">Mô hình AI</span>
        <span class="ai-meta-value">${escapeHtml(item.model_name || 'qwen2.5:7b')}</span>
      </div>
      <div class="ai-meta-item">
        <span class="ai-meta-title">Thời gian phản hồi</span>
        <span class="ai-meta-value">${item.from_cache ? '0 ms (Cache hit)' : `${item.latency_ms.toLocaleString()} ms`}</span>
      </div>
      <div class="ai-meta-item">
        <span class="ai-meta-title">Trạng thái</span>
        <span class="ai-meta-value">${item.status === 'success' ? '✅ Thành công' : (item.status === 'fallback' ? '⚠️ Fallback' : '❌ Lỗi')}</span>
      </div>
      <div class="ai-meta-item">
        <span class="ai-meta-title">Tokens sử dụng</span>
        <span class="ai-meta-value">In: ${item.prompt_tokens || '--'} · Out: ${item.completion_tokens || '--'}</span>
      </div>
    </div>
  `;

  // Input Box (Bài viết hoặc Câu đặt)
  let inputTitle = 'Dữ liệu học viên nộp vào';
  if (item.feature === 'writing_grading') {
    inputTitle = `Bài viết IELTS Writing (${item.input_word_count || 0} từ)`;
  } else if (item.feature === 'vocab_sentence') {
    inputTitle = `Câu luyện tập với từ "${escapeHtml(item.vocab_word || '')}"`;
  } else {
    inputTitle = `Lựa chọn của học viên: "${escapeHtml(item.input_text || '')}"`;
  }

  const inputHtml = `
    <div class="ai-detail-section">
      <div class="ai-detail-section-title">
        <i class="fa-solid fa-file-lines text-primary"></i> ${inputTitle}
      </div>
      <div class="ai-input-card">${escapeHtml(item.input_text || '(Không có nội dung)')}</div>
    </div>
  `;

  // Output Breakdown Section
  let outputSectionHtml = '';
  if (item.feature === 'writing_grading') {
    outputSectionHtml = renderWritingDetailHtml(item, resJson);
  } else if (item.feature === 'vocab_sentence') {
    outputSectionHtml = renderVocabSentenceDetailHtml(item, resJson);
  } else {
    outputSectionHtml = renderExplainDetailHtml(item, resJson);
  }

  // Raw JSON Collapsible
  const jsonHtml = `
    <details class="ai-json-collapsible">
      <summary><i class="fa-solid fa-code"></i> Xem toàn bộ dữ liệu JSON phản hồi</summary>
      <pre class="ai-json-pre">${escapeHtml(JSON.stringify(resJson, null, 2))}</pre>
    </details>
  `;

  modalBody.innerHTML = metaHtml + inputHtml + outputSectionHtml + jsonHtml;
}

function renderWritingDetailHtml(item, resJson) {
  const fb = resJson || {};
  const criteriaList = [
    { name: 'Task Achievement / Response', band: fb.task_response_band, comment: fb.task_response_comment },
    { name: 'Coherence & Cohesion', band: fb.coherence_band, comment: fb.coherence_comment },
    { name: 'Lexical Resource', band: fb.lexical_band, comment: fb.lexical_comment },
    { name: 'Grammatical Range & Accuracy', band: fb.grammar_band, comment: fb.grammar_comment },
  ];

  const criteriaCardsHtml = criteriaList.map(c => `
    <div class="ai-criteria-card">
      <div class="ai-criteria-header">
        <span class="ai-criteria-name">${c.name}</span>
        <span class="ai-band-badge">Band ${c.band !== undefined ? c.band : '--'}</span>
      </div>
      <div class="ai-criteria-comment">${escapeHtml(c.comment || 'Chưa có nhận xét.')}</div>
    </div>
  `).join('');

  // Errors list
  const errors = fb.errors || [];
  let errorsHtml = '';
  if (errors.length > 0) {
    errorsHtml = `
      <div class="ai-detail-section" style="margin-top: 16px;">
        <div class="ai-detail-section-title">
          <i class="fa-solid fa-triangle-exclamation text-danger"></i> Chi tiết lỗi ngữ pháp & từ vựng (${errors.length} lỗi đã kiểm tra chống Hallucination)
        </div>
        <div class="ai-error-list">
          ${errors.map(e => `
            <div class="ai-error-item">
              <div class="ai-error-quote">❌ Trích nguyên văn: "${escapeHtml(e.quote || '')}"</div>
              <div class="ai-error-fix">✅ Sửa thành: "${escapeHtml(e.fix || '')}"</div>
              ${e.explain_vi ? `<div class="ai-error-explain">💡 Giải thích: ${escapeHtml(e.explain_vi)}</div>` : ''}
            </div>
          `).join('')}
        </div>
      </div>
    `;
  }

  // Strengths & Improvements
  const strengths = fb.strengths || [];
  const improvements = fb.improvements || [];
  let feedbackListsHtml = '';
  if (strengths.length > 0 || improvements.length > 0) {
    feedbackListsHtml = `
      <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); gap: 14px; margin-top: 16px;">
        <div style="background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 8px; padding: 12px 14px;">
          <strong style="color: #16a34a; font-size: 13px; display: block; margin-bottom: 6px;">
            <i class="fa-solid fa-thumbs-up"></i> Điểm mạnh nổi bật
          </strong>
          <ul style="margin: 0; padding-left: 18px; font-size: 12.5px; color: #166534; line-height: 1.5;">
            ${strengths.map(s => `<li>${escapeHtml(s)}</li>`).join('')}
          </ul>
        </div>
        <div style="background: #fffbeb; border: 1px solid #fef3c7; border-radius: 8px; padding: 12px 14px;">
          <strong style="color: #d97706; font-size: 13px; display: block; margin-bottom: 6px;">
            <i class="fa-solid fa-lightbulb"></i> Hướng cải thiện nâng Band
          </strong>
          <ul style="margin: 0; padding-left: 18px; font-size: 12.5px; color: #92400e; line-height: 1.5;">
            ${improvements.map(i => `<li>${escapeHtml(i)}</li>`).join('')}
          </ul>
        </div>
      </div>
    `;
  }

  // Improved Paragraph Band 8.0+
  let improvedParagraphHtml = '';
  if (fb.improved_paragraph) {
    improvedParagraphHtml = `
      <div class="ai-detail-section" style="margin-top: 16px;">
        <div class="ai-detail-section-title">
          <i class="fa-solid fa-wand-magic-sparkles" style="color: #8b5cf6;"></i> Đoạn văn nâng cấp gợi ý (Mức Band 8.0+)
        </div>
        <div style="background: #f5f3ff; border: 1px solid #ddd6fe; border-radius: 8px; padding: 12px 14px; font-size: 13px; color: #4c1d95; line-height: 1.6;">
          ${escapeHtml(fb.improved_paragraph)}
        </div>
      </div>
    `;
  }

  return `
    <div class="ai-detail-section">
      <div class="ai-detail-section-title" style="justify-content: space-between;">
        <span><i class="fa-solid fa-award text-primary"></i> Đánh giá 4 Tiêu Chí IELTS Writing</span>
        <span class="ai-band-badge" style="font-size: 14px; padding: 4px 12px;">Band Tổng: ${item.band_score || '--'}</span>
      </div>
      <div class="ai-criteria-grid">${criteriaCardsHtml}</div>
      ${feedbackListsHtml}
      ${errorsHtml}
      ${improvedParagraphHtml}
    </div>
  `;
}

function renderVocabSentenceDetailHtml(item, resJson) {
  const corrected = resJson.corrected_sentence || item.input_text;
  const feedbackVi = resJson.feedback_vi || '';
  const score = resJson.score !== undefined ? resJson.score : item.score_numeric;
  const band = resJson.estimated_band || item.band_score || '--';

  const collocations = resJson.key_collocations_used || [];
  let collsHtml = '';
  if (collocations.length > 0) {
    collsHtml = `
      <div style="margin-top: 12px;">
        <strong style="font-size: 12px; color: #64748b; text-transform: uppercase;">Collocations gợi ý:</strong>
        <div style="display: flex; gap: 6px; flex-wrap: wrap; margin-top: 4px;">
          ${collocations.map(c => `<span style="background: #f1f5f9; padding: 3px 8px; border-radius: 6px; font-size: 12px; font-weight: 600; color: #334155;">${escapeHtml(c)}</span>`).join('')}
        </div>
      </div>
    `;
  }

  return `
    <div class="ai-detail-section">
      <div class="ai-detail-section-title" style="justify-content: space-between;">
        <span><i class="fa-solid fa-chart-simple text-primary"></i> Kết quả Đánh Giá Đặt Câu</span>
        <span class="ai-band-badge" style="font-size: 13px;">${score}/100 · Band ${band}</span>
      </div>

      <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px 14px; margin-bottom: 14px;">
        <div style="font-size: 13px; color: #16a34a; font-weight: 600;">
          <i class="fa-solid fa-check"></i> Câu đã sửa hoàn thiện:
        </div>
        <div style="font-size: 13.5px; color: #1e293b; margin-top: 4px; font-weight: 500;">
          "${escapeHtml(corrected)}"
        </div>
        ${feedbackVi ? `<div style="font-size: 12.5px; color: #475569; margin-top: 8px; line-height: 1.5; border-top: 1px dashed #e2e8f0; padding-top: 6px;">💡 <strong>Nhận xét:</strong> ${escapeHtml(feedbackVi)}</div>` : ''}
        ${collsHtml}
      </div>

      <div class="ai-detail-section-title">
        <i class="fa-solid fa-stairs" style="color: #7c3aed;"></i> Thang nâng cấp câu 3 bậc (Word Upgrade Ladder)
      </div>
      <div class="ai-upgrade-ladder">
        <div class="ai-ladder-step basic">
          <div class="ladder-step-tag basic"><i class="fa-solid fa-seedling"></i> Bậc Cơ Bản (Band 5.0 - 5.5)</div>
          <div class="ladder-step-text">${escapeHtml(resJson.upgraded_basic || item.input_text || '')}</div>
        </div>
        <div class="ai-ladder-step intermediate">
          <div class="ladder-step-tag intermediate"><i class="fa-solid fa-arrow-trend-up"></i> Bậc Trung Cấp (Band 6.5)</div>
          <div class="ladder-step-text">${escapeHtml(resJson.upgraded_intermediate || item.input_text || '')}</div>
        </div>
        <div class="ai-ladder-step advanced">
          <div class="ladder-step-tag advanced"><i class="fa-solid fa-crown"></i> Bậc Nâng Cao / Học Thuật (Band 8.0+)</div>
          <div class="ladder-step-text">${escapeHtml(resJson.upgraded_advanced || item.input_text || '')}</div>
        </div>
      </div>
    </div>
  `;
}

function renderExplainDetailHtml(item, resJson) {
  const isCorrect = item.is_correct || resJson.is_correct;
  const whyCorrect = resJson.why_correct || '';
  const whyTrap = resJson.why_trap || '';
  const strategy = resJson.strategy_tips || '';
  const vocabList = resJson.key_vocabulary || [];

  return `
    <div class="ai-detail-section">
      <div class="ai-detail-section-title" style="justify-content: space-between;">
        <span><i class="fa-solid fa-comments text-primary"></i> Giải Thích Chi Tiết &amp; Phân Tích Bẫy</span>
        <span class="badge-ai-status ${isCorrect ? 'success' : 'fallback'}" style="font-size: 13px;">
          ${isCorrect ? '✅ Học viên chọn ĐÚNG' : '⚠️ Học viên chọn CHƯA ĐÚNG'}
        </span>
      </div>

      ${whyCorrect ? `
        <div style="background: #f0fdf4; border: 1px solid #bbf7d0; border-radius: 8px; padding: 12px 14px; margin-bottom: 12px;">
          <strong style="color: #166534; font-size: 13px;"><i class="fa-solid fa-circle-check"></i> Dẫn chứng câu gốc vì sao đúng:</strong>
          <div style="font-size: 12.5px; color: #14532d; margin-top: 4px; line-height: 1.5;">${escapeHtml(whyCorrect)}</div>
        </div>
      ` : ''}

      ${whyTrap ? `
        <div style="background: #fffbeb; border: 1px solid #fef3c7; border-radius: 8px; padding: 12px 14px; margin-bottom: 12px;">
          <strong style="color: #b45309; font-size: 13px;"><i class="fa-solid fa-triangle-exclamation"></i> Phân tích bẫy phương án:</strong>
          <div style="font-size: 12.5px; color: #78350f; margin-top: 4px; line-height: 1.5;">${escapeHtml(whyTrap)}</div>
        </div>
      ` : ''}

      ${strategy ? `
        <div style="background: #f8fafc; border: 1px solid #e2e8f0; border-radius: 8px; padding: 12px 14px; margin-bottom: 12px;">
          <strong style="color: #334155; font-size: 13px;"><i class="fa-solid fa-lightbulb" style="color: #f59e0b;"></i> Mẹo &amp; Chiến thuật làm bài:</strong>
          <div style="font-size: 12.5px; color: #475569; margin-top: 4px; line-height: 1.5;">${escapeHtml(strategy)}</div>
        </div>
      ` : ''}

      ${vocabList.length > 0 ? `
        <div style="margin-top: 14px;">
          <div class="ai-detail-section-title"><i class="fa-solid fa-book-bookmark text-primary"></i> Từ vựng / Paraphrase mở rộng</div>
          <div style="display: flex; flex-direction: column; gap: 6px;">
            ${vocabList.map(v => `
              <div style="background: white; border: 1px solid #e2e8f0; border-radius: 6px; padding: 8px 12px; font-size: 12.5px;">
                <strong style="color: #0f172a;">${escapeHtml(v.word || '')}</strong>: <span style="color: #475569;">${escapeHtml(v.meaning || '')}</span>
                ${v.paraphrase_with ? `<span style="color: #059669; margin-left: 8px;">(Paraphrase: <em>${escapeHtml(v.paraphrase_with)}</em>)</span>` : ''}
              </div>
            `).join('')}
          </div>
        </div>
      ` : ''}
    </div>
  `;
}

// ─────────────────────────────────────────────────────────────
// XÓA BẢN GHI LOG AI
// ─────────────────────────────────────────────────────────────

async function handleDeleteAiLog(logId, fromModal = false) {
  if (!confirm('Bạn có chắc chắn muốn xóa bản ghi log chấm điểm này không?')) {
    return;
  }

  try {
    await apiRequest(`/admin/ai-grading/logs/${logId}`, { method: 'DELETE' });
    showToast('Đã xóa bản ghi log AI thành công!', 'success');
    if (fromModal) {
      document.getElementById('ai-log-detail-modal').classList.remove('active');
    }
    loadAiGradingData();
  } catch (err) {
    showToast(`Xóa thất bại: ${err.message}`, 'error');
  }
}

async function handleBulkDeleteAiLogs() {
  const ids = Array.from(state.selectedLogIds);
  if (ids.length === 0) return;

  if (!confirm(`Bạn có chắc muốn xóa vĩnh viễn ${ids.length} bản ghi log AI đã chọn?`)) {
    return;
  }

  try {
    const res = await apiRequest('/admin/ai-grading/logs/bulk-delete', {
      method: 'POST',
      body: JSON.stringify({ ids }),
    });
    showToast(res.message || `Đã xóa ${ids.length} bản ghi!`, 'success');
    state.selectedLogIds.clear();
    loadAiGradingData();
  } catch (err) {
    showToast(`Lỗi xóa hàng loạt: ${err.message}`, 'error');
  }
}

function handleExportAiLogsCsv() {
  const params = new URLSearchParams();
  if (state.aiLogSelectedFeature && state.aiLogSelectedFeature !== 'all') {
    params.append('feature', state.aiLogSelectedFeature);
  }
  if (state.aiLogSelectedStatus && state.aiLogSelectedStatus !== 'all') {
    params.append('status', state.aiLogSelectedStatus);
  }
  if (state.aiLogSearchTerm) {
    params.append('search', state.aiLogSearchTerm);
  }

  const token = state.token;
  const url = `${API_BASE}/admin/ai-grading/export-csv?${params.toString()}`;

  // Tải file trực tiếp với fetch để đính kèm Authorization header
  fetch(url, {
    headers: {
      'Authorization': `Bearer ${token}`,
    },
  })
    .then(res => {
      if (!res.ok) throw new Error(`HTTP ${res.status}`);
      return res.blob();
    })
    .then(blob => {
      const a = document.createElement('a');
      const objectUrl = window.URL.createObjectURL(blob);
      a.href = objectUrl;
      const d = new Date().toISOString().slice(0, 10);
      a.download = `qwen_grading_history_${d}.csv`;
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      window.URL.revokeObjectURL(objectUrl);
      showToast('Đã xuất file CSV thành công!', 'success');
    })
    .catch(err => {
      showToast(`Lỗi xuất CSV: ${err.message}`, 'error');
    });
}

window.openAiLogDetail = openAiLogDetail;
window.handleDeleteAiLog = handleDeleteAiLog;

