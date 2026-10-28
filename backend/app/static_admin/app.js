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
  mappings: [],
  users: [],
  selectedImportFile: null,
  activeQuestions: [], // Dùng trong modal soạn câu hỏi trắc nghiệm
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
      renderSkillLessons();
    });
  });

  // Tab Skills: Search Box
  document.getElementById('skill-search-input').addEventListener('input', (e) => {
    state.skillSearchTerm = e.target.value.trim().toLowerCase();
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
  document.getElementById('vocab-search-input').addEventListener('input', renderVocabTable);
  document.getElementById('vocab-band-filter').addEventListener('change', renderVocabTable);
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
    'tab-skills': 'Quản lý 4 Kỹ Năng & 5 Ải Vượt Bài IELTS',
    'tab-vocab': 'Kho 82 Từ Vựng AI Nhận Diện Vật Thể',
    'tab-users': 'Quản lý Người Dùng & Phân Quyền (RBAC)',
  };
  document.getElementById('page-title').textContent = titles[tabId] || 'Quản trị viên';
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
    const res = await fetch(`${API_BASE}/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ username, password }),
    });

    const data = await res.json();
    if (!res.ok) {
      throw new Error(data.detail || 'Tài khoản hoặc mật khẩu không đúng!');
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
  ]);
}

async function loadKPIS() {
  try {
    const data = await apiRequest('/admin/kpis');
    document.getElementById('kpi-mappings').textContent = data.total_mappings || 82;
    document.getElementById('kpi-learners').textContent = data.total_learners || 0;
    document.getElementById('kpi-users').textContent = data.total_users || 0;
    document.getElementById('kpi-notebook').textContent = data.total_notebook_items || 0;

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
  }
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

  if (filtered.length === 0) {
    container.innerHTML = `
      <div style="text-align: center; padding: 48px 20px; background: white; border-radius: 16px; border: 1px solid var(--border);">
        <i class="fa-solid fa-folder-open" style="font-size: 42px; color: #94a3b8; margin-bottom: 12px;"></i>
        <h4 style="font-weight: 800; font-size: 16px;">Chưa có đề thi nào cho bộ lọc này</h4>
        <p style="color: var(--muted); font-size: 13px; margin-top: 4px;">
          Bấm "<strong>Thêm Đề Thi / Ải Mới</strong>" hoặc "<strong>Import File Đề Thi</strong>" để nạp nội dung.
        </p>
      </div>
    `;
    return;
  }

  container.innerHTML = filtered.map(l => {
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
      detailSummary = `Dạng: <strong>${content.taskType || 'Task 2'}</strong> • Có văn mẫu Band 8.0+`;
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
            <button class="btn-icon edit" onclick="openLessonModal('${escapeHtml(String(l.id))}')" title="Chỉnh sửa đề thi">
              <i class="fa-solid fa-pen-to-square"></i>
            </button>
            <button class="btn-icon delete" onclick="handleDeleteLesson('${escapeHtml(String(l.id))}', '${escapeHtml(l.title || '')}')" title="Xóa đề thi">
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
    if (!lesson) return;
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
    contentContainer.innerHTML = `
      <div class="form-group">
        <label>Dạng bài Writing</label>
        <select id="writing-task-type" class="form-select">
          <option value="Task 1" ${content.taskType === 'Task 1' ? 'selected' : ''}>Writing Task 1 (Mô tả biểu đồ / bản đồ / quy trình)</option>
          <option value="Task 2" ${content.taskType !== 'Task 1' ? 'selected' : ''}>Writing Task 2 (Bài luận Essay 250 từ)</option>
        </select>
      </div>
      <div class="form-group">
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

async function handleSaveLesson(e) {
  e.preventDefault();
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

  const btn = document.getElementById('btn-save-lesson');
  btn.disabled = true;
  btn.innerHTML = `<i class="fa-solid fa-spinner fa-spin"></i> Đang lưu...`;

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

async function handleDeleteLesson(lessonId, lessonTitle) {
  if (!confirm(`Bạn có chắc muốn xóa đề thi "${lessonTitle}" không? Hành động này không thể hoàn tác.`)) {
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

  tbody.innerHTML = filtered.map(m => `
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
  tbody.innerHTML = state.users.map(u => {
    const isCurrent = state.user && state.user.id === u.id;
    const isAdmin = u.role === 'admin';
    const dateStr = u.created_at ? u.created_at.substring(0, 10) : 'N/A';

    return `
      <tr>
        <td>#${u.id}</td>
        <td>
          <strong>${escapeHtml(u.username)}</strong>
          ${isCurrent ? `<span style="margin-left: 6px; font-size: 10px; background: var(--primary-light); color: var(--primary); padding: 2px 6px; border-radius: 4px; font-weight: 700;">HIỆN TẠI</span>` : ''}
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
