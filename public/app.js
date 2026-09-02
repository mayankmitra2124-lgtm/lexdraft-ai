// Bulletproof HTTP client replacing fetch to eliminate WebKit / Safari DOMException 12 errors
window.fetch = function(url, options = {}) {
  return new Promise((resolve, reject) => {
    try {
      const xhr = new XMLHttpRequest();
      const method = options.method || 'GET';
      xhr.open(method, url, true);
      
      // Only set explicit headers when body is NOT FormData
      // (FormData requires browser to auto-set multipart/form-data with boundary)
      const isFormData = options.body instanceof FormData;
      if (options.headers && !isFormData) {
        for (const [key, value] of Object.entries(options.headers)) {
          xhr.setRequestHeader(key, value);
        }
      }
      
      xhr.onload = function() {
        resolve({
          ok: xhr.status >= 200 && xhr.status < 300,
          status: xhr.status,
          statusText: xhr.statusText,
          json: () => {
            try {
              return Promise.resolve(JSON.parse(xhr.responseText || '{}'));
            } catch (e) {
              return Promise.resolve({});
            }
          },
          text: () => Promise.resolve(xhr.responseText || '')
        });
      };
      
      xhr.onerror = function() {
        reject(new Error(`Network request to ${url} failed (status ${xhr.status})`));
      };
      
      xhr.ontimeout = function() {
        reject(new Error(`Request to ${url} timed out`));
      };

      xhr.send(options.body || null);
    } catch (err) {
      reject(err);
    }
  });
};

// LexDraft AI & Case Evidence Organizer — Core Frontend State Store & Router
const App = {
  state: {
    currentRoute: 'dashboard', // dashboard, new-case, cases-list, case-detail, research, arguments, delay-prediction, case-analysis, templates, clients, settings
    activeCaseId: null,
    activeCaseTab: 'chronology', // chronology, summary, evidence, diffs
    sidebarCollapsed: false,
    cases: [],
    currentCase: null,
    currentFiles: [],
    currentSummary: null,
    currentDiffs: [],
    notifications: [],
    sseConnection: null,
    settings: {
      ai_api_key_configured: false,
      ai_model: 'gemini-2.0-flash'
    }
  },

  async init() {
    await this.fetchSettings();
    await this.loadDashboardData();
    this.navigate('dashboard');
  },

  // ==========================================
  // Router & Navigation
  // ==========================================
  async navigate(route, param = null) {
    this.state.currentRoute = route;

    // Update active highlight on sidebar items
    document.querySelectorAll('.nav-item').forEach(el => {
      if (el.getAttribute('data-route') === route) {
        el.className = 'nav-item flex items-center space-x-3 w-full px-3 py-2.5 rounded-xl text-xs font-semibold transition bg-accent/15 text-accent border-l-2 border-accent shadow-sm';
      } else {
        el.className = 'nav-item flex items-center space-x-3 w-full px-3 py-2.5 rounded-xl text-xs font-semibold transition text-slate-400 hover:text-white hover:bg-sidebar-accent';
      }
    });

    if (route === 'dashboard') {
      this.closeSSE();
      this.state.activeCaseId = null;
      await this.loadDashboardData();
      this.renderDashboard();
    } else if (route === 'new-case') {
      this.closeSSE();
      this.renderNewCase();
    } else if (route === 'cases-list') {
      this.closeSSE();
      await this.loadDashboardData();
      this.renderCasesList();
    } else if (route === 'case-detail' && param) {
      this.state.activeCaseId = param;
      await this.loadCaseData(param);
      this.setupSSE(param);
      this.renderCaseDetailView();

    } else if (route === 'clients') {
      this.closeSSE();
      this.renderClients();
    } else if (route === 'settings') {
      this.closeSSE();
      this.renderSettings();
    }

    lucide.createIcons();
    window.scrollTo({ top: 0, behavior: 'smooth' });
  },

  async openCase(caseId) {
    this.state.activeCaseTab = 'chronology';
    await this.navigate('case-detail', caseId);
  },

  setCaseTab(tab) {
    this.state.activeCaseTab = tab;
    this.renderCaseDetailView();
  },

  toggleSidebar() {
    this.state.sidebarCollapsed = !this.state.sidebarCollapsed;
    const sidebar = document.getElementById('app-sidebar');
    const toggleIcon = document.getElementById('sidebar-toggle-icon');
    const labels = document.querySelectorAll('.sidebar-label');

    if (this.state.sidebarCollapsed) {
      sidebar.classList.remove('w-[260px]');
      sidebar.classList.add('w-[68px]');
      labels.forEach(l => l.classList.add('hidden'));
      if (toggleIcon) toggleIcon.setAttribute('data-lucide', 'panel-left-open');
    } else {
      sidebar.classList.remove('w-[68px]');
      sidebar.classList.add('w-[260px]');
      labels.forEach(l => l.classList.remove('hidden'));
      if (toggleIcon) toggleIcon.setAttribute('data-lucide', 'panel-left-close');
    }
    lucide.createIcons();
  },

  refreshCurrentView() {
    this.navigate(this.state.currentRoute, this.state.activeCaseId);
  },

  // ==========================================
  // API Fetching
  // ==========================================
  async loadDashboardData() {
    try {
      const [casesRes, notifsRes] = await Promise.all([
        fetch('/api/cases'),
        fetch('/api/notifications')
      ]);
      this.state.cases = await casesRes.json();
      this.state.notifications = await notifsRes.json();
      this.updateNotificationBadge();
    } catch (e) {
      console.error('Error fetching dashboard:', e);
    }
  },

  async loadCaseData(caseId) {
    try {
      const [caseRes, filesRes, sumRes, diffsRes] = await Promise.all([
        fetch(`/api/cases/${caseId}`),
        fetch(`/api/cases/${caseId}/files`),
        fetch(`/api/cases/${caseId}/summary`),
        fetch(`/api/cases/${caseId}/diffs`)
      ]);

      const caseData = await caseRes.json();
      const filesData = await filesRes.json();
      const sumData = await sumRes.json();
      const diffsData = await diffsRes.json();

      // Defensive fallbacks — never let these become undefined/null
      this.state.currentCase = (caseData && caseData.id) ? caseData : this.state.currentCase;
      this.state.currentFiles = Array.isArray(filesData) ? filesData : [];
      this.state.currentSummary = (sumData && typeof sumData === 'object' && !Array.isArray(sumData)) ? sumData : null;
      this.state.currentDiffs = Array.isArray(diffsData) ? diffsData : [];
    } catch (e) {
      console.error('Error loading case data:', e);
      this.showToast(`Error loading case: ${e.message}`, 'error');
      // Ensure arrays are safe even after error
      if (!Array.isArray(this.state.currentFiles)) this.state.currentFiles = [];
      if (!Array.isArray(this.state.currentDiffs)) this.state.currentDiffs = [];
    }
  },

  async refreshCaseData(caseId) {
    if (this.state.activeCaseId === caseId) {
      await this.loadCaseData(caseId);
      this.renderCaseDetailView();
    }
  },

  async fetchSettings() {
    try {
      const res = await fetch('/api/settings');
      this.state.settings = await res.json();
    } catch (e) {
      console.error('Settings error:', e);
    }
  },

  // ==========================================
  // Live Updates via Polling (replaces SSE which WEBrick can't stream)
  // ==========================================
  setupSSE(caseId) {
    this.closeSSE(); // clears any previous poller
    this._startPolling(caseId);
  },

  _startPolling(caseId) {
    // Poll every 3 seconds while files are pending
    const poll = async () => {
      // Stop if we navigated away from this case
      if (this.state.activeCaseId !== caseId) return;

      try {
        const res = await fetch(`/api/cases/${caseId}/files`);
        const files = await res.json();
        if (!Array.isArray(files)) return;

        const prevPending = (this.state.currentFiles || []).filter(f => f.status === 'Queued' || f.status === 'Processing').length;
        const nowPending = files.filter(f => f.status === 'Queued' || f.status === 'Processing').length;
        const nowComplete = files.filter(f => f.status === 'Complete').length;
        const totalFiles = files.length;

        this.state.currentFiles = files;

        // If something just completed, fetch full case data to get updated summary
        if (prevPending > 0 && nowPending < prevPending) {
          await this.loadCaseData(caseId);
          this.renderCaseDetailView();
          if (nowComplete > 0) {
            this.showToast(`AI extraction complete: ${nowComplete}/${totalFiles} file(s) processed.`, 'success');
          }
        } else if (nowPending > 0) {
          // Files still processing — just re-render progress
          this.renderCaseDetailView();
        }

        // Check for any failures
        const nowFailed = files.filter(f => f.status === 'Failed').length;
        if (nowFailed > 0 && prevPending > 0 && nowPending <= 0) {
          this.showToast(`${nowFailed} file(s) failed extraction. Check Evidence Pipeline tab.`, 'error');
        }

        // Continue polling if files still pending
        if (nowPending > 0 && this.state.activeCaseId === caseId) {
          this.state.sseConnection = setTimeout(poll, 3000);
        } else {
          this.state.sseConnection = null;
        }
      } catch (e) {
        console.error('Polling error:', e);
        // Retry on error
        if (this.state.activeCaseId === caseId) {
          this.state.sseConnection = setTimeout(poll, 5000);
        }
      }
    };

    // Start polling after 2 seconds to let the upload register
    this.state.sseConnection = setTimeout(poll, 2000);
  },

  closeSSE() {
    if (this.state.sseConnection) {
      clearTimeout(this.state.sseConnection);
      this.state.sseConnection = null;
    }
  },

  // ==========================================
  // Renderers
  // ==========================================
  renderDashboard() {
    const root = document.getElementById('app-root');
    root.innerHTML = Dashboard.render(this.state.cases, this.state.notifications);
  },

  renderNewCase() {
    const root = document.getElementById('app-root');
    root.innerHTML = NewCaseView.render();
  },

  renderCasesList() {
    const root = document.getElementById('app-root');
    root.innerHTML = `
      <div class="space-y-6 animate-fadeIn">
        <div class="flex items-center justify-between">
          <div>
            <h2 class="font-serif text-2xl font-bold text-white">Case Evidence Vaults (4GB Multi-Modal)</h2>
            <p class="text-xs text-slate-400">All registered active litigation matters and evidence lockers.</p>
          </div>
          <button onclick="App.navigate('new-case')" class="px-4 py-2 bg-gradient-gold text-slate-950 font-bold text-xs rounded-xl shadow">
            Create New Case
          </button>
        </div>

        <div class="space-y-3.5">
          ${this.state.cases.map(c => Dashboard.renderRecentCaseCard(c)).join('')}
        </div>
      </div>
    `;
  },

  renderCaseDetailView() {
    const root = document.getElementById('app-root');
    const c = this.state.currentCase;
    if (!c) return;

    const activeTab = this.state.activeCaseTab;
    const summary = this.state.currentSummary;
    const files = this.state.currentFiles;
    const diffs = this.state.currentDiffs;
    const hasUnread = c.has_unread_changes === 1;

    root.innerHTML = `
      <div class="space-y-6 animate-fadeIn">
        
        <!-- Case Top Header -->
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-slate-200 pb-4">
          <div class="flex items-center space-x-3">
            <button onclick="App.navigate('dashboard')" class="p-2 rounded-xl bg-white hover:bg-slate-50 text-slate-500 hover:text-slate-800 border border-slate-200 transition" title="Back to Dashboard">
              <i data-lucide="arrow-left" class="w-4 h-4"></i>
            </button>
            <div>
              <h2 class="font-serif text-xl font-bold text-slate-800 tracking-wide">${escapeHtml(c.name)}</h2>
              <p class="text-xs text-slate-500 flex items-center gap-2">
                <span>${escapeHtml(c.court_name || 'Court of Record')}</span>
                <span>•</span>
                <span>Tier: <strong class="uppercase text-amber-600">${c.tier || 'pro'}</strong> (Max ${c.max_storage_formatted})</span>
                ${c.hearing_date ? `<span>•</span><span class="text-amber-600 font-semibold">Next Hearing: ${c.hearing_date}</span>` : ''}
              </p>
            </div>
          </div>

          <div class="flex items-center space-x-3">
            <button onclick="App.openExportModal()" class="px-4 py-2 rounded-xl bg-gradient-gold text-slate-950 font-bold text-xs hover:brightness-110 transition shadow-md shadow-amber-500/20 flex items-center space-x-2">
              <i data-lucide="printer" class="w-4 h-4"></i>
              <span>Export Court Brief</span>
            </button>
          </div>
        </div>

        <!-- Shared Context Banner (Case Objective & Parties Information) -->
        <div class="bg-white border border-slate-200 p-5 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-3">
          <div class="flex items-center justify-between border-b border-slate-100 pb-2">
            <span class="text-[11px] uppercase font-bold tracking-widest text-amber-600 flex items-center gap-1.5">
              <i data-lucide="sparkles" class="w-3.5 h-3.5"></i>
              Shared Extraction Context (Prompts 1 & 2)
            </span>
          </div>

          <div class="grid grid-cols-1 md:grid-cols-2 gap-4 text-xs">
            <div class="p-3.5 rounded-xl bg-slate-50 border border-slate-150 space-y-1">
              <span class="font-bold text-slate-700 text-[11px] uppercase tracking-wider">1. Case Objective</span>
              <p class="text-slate-600 italic font-reading leading-relaxed">"${escapeHtml(c.objective || 'No objective specified.')}"</p>
            </div>
            <div class="p-3.5 rounded-xl bg-slate-50 border border-slate-150 space-y-1">
              <span class="font-bold text-slate-700 text-[11px] uppercase tracking-wider">2. Case & Parties Background</span>
              <p class="text-slate-600 font-sans leading-relaxed">${escapeHtml(c.parties_info || 'No party details specified.')}</p>
            </div>
          </div>
        </div>

        <!-- Case Detail Tabs Navigation -->
        <div class="flex items-center space-x-2 border-b border-slate-200 pb-1">
          <button onclick="App.setCaseTab('chronology')" class="px-4 py-2.5 rounded-t-xl text-xs font-bold uppercase tracking-wider flex items-center space-x-2 transition ${activeTab === 'chronology' ? 'bg-white text-amber-600 border-t-2 border-amber-500 shadow-sm border border-slate-200 border-b-transparent' : 'text-slate-500 hover:text-slate-800'}">
            <i data-lucide="calendar-check-2" class="w-4 h-4"></i>
            <span>Master Chronology & Timeline</span>
            <span class="px-1.5 py-0.2 rounded bg-slate-100 text-[10px] text-slate-600 font-mono">${summary?.chronology?.length || 0}</span>
          </button>

          <button onclick="App.setCaseTab('summary')" class="px-4 py-2.5 rounded-t-xl text-xs font-bold uppercase tracking-wider flex items-center space-x-2 transition ${activeTab === 'summary' ? 'bg-white text-amber-600 border-t-2 border-amber-500 shadow-sm border border-slate-200 border-b-transparent' : 'text-slate-500 hover:text-slate-800'}">
            <i data-lucide="file-text" class="w-4 h-4"></i>
            <span>Master Case Summary</span>
          </button>

          <button onclick="App.setCaseTab('evidence')" class="px-4 py-2.5 rounded-t-xl text-xs font-bold uppercase tracking-wider flex items-center space-x-2 transition ${activeTab === 'evidence' ? 'bg-white text-amber-600 border-t-2 border-amber-500 shadow-sm border border-slate-200 border-b-transparent' : 'text-slate-500 hover:text-slate-800'}">
            <i data-lucide="upload-cloud" class="w-4 h-4"></i>
            <span>Evidence Pipeline (4GB)</span>
            <span class="px-1.5 py-0.2 rounded bg-slate-100 text-[10px] text-slate-600 font-mono">${(files || []).length}</span>
          </button>

          <button onclick="App.setCaseTab('diffs')" class="px-4 py-2.5 rounded-t-xl text-xs font-bold uppercase tracking-wider flex items-center space-x-2 transition ${activeTab === 'diffs' ? 'bg-white text-amber-600 border-t-2 border-amber-500 shadow-sm border border-slate-200 border-b-transparent' : 'text-slate-500 hover:text-slate-800'}">
            <i data-lucide="git-compare" class="w-4 h-4"></i>
            <span>"What Changed" Diffs</span>
            ${hasUnread ? `<span class="w-2 h-2 rounded-full bg-emerald-500 animate-ping"></span>` : ''}
            <span class="px-1.5 py-0.2 rounded bg-slate-100 text-[10px] text-slate-600 font-mono">${(diffs || []).length}</span>
          </button>
        </div>

        <!-- Dynamic Tab Content -->
        <div id="case-tab-content">
          ${activeTab === 'chronology' ? TimelineView.render(c, summary) : ''}
          ${activeTab === 'summary' ? SummaryView.render(c, summary, files) : ''}
          ${activeTab === 'evidence' ? EvidenceManager.render(c, files) : ''}
          ${activeTab === 'diffs' ? DiffInspector.render(c, diffs) : ''}
        </div>

      </div>
    `;
    lucide.createIcons();
  },



  renderClients() {
    const root = document.getElementById('app-root');
    root.innerHTML = ClientsView.render();
  },

  renderSettings() {
    const root = document.getElementById('app-root');
    root.innerHTML = SettingsView.render(this.state.settings);
  },

  // ==========================================
  // Case Creation Handler
  // ==========================================
  async handleCreateNewCase(e) {
    e.preventDefault();
    const form = e.target;
    const formData = new FormData(form);
    
    const payload = {
      name: formData.get('name'),
      court_name: formData.get('court_name'),
      objective: formData.get('objective'),
      parties_info: formData.get('parties_info'),
      hearing_date: formData.get('hearing_date'),
      tier: formData.get('tier') || 'pro'
    };

    try {
      App.showToast('Initializing matter and setting up 4GB vault...', 'info');
      const res = await fetch('/api/cases', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      if (res.ok) {
        const createdCase = await res.json();

        // Clear any stale case data before loading the new case
        this.state.currentCase = null;
        this.state.currentFiles = [];
        this.state.currentSummary = null;
        this.state.currentDiffs = [];
        
        // Check if any initial files were attached
        const fileInput = document.getElementById('new-case-files');
        if (fileInput && fileInput.files.length > 0) {
          App.showToast(`Uploading ${fileInput.files.length} evidence file(s) for AI ingestion...`, 'info');
          await EvidenceManager.uploadFiles(createdCase.id, fileInput.files);
        }

        App.showToast(`Case '${createdCase.name}' initialized. AI ingestion starting...`, 'success');
        await this.openCase(createdCase.id);
      } else {
        const err = await res.json();
        App.showToast(err.error || 'Failed to create case', 'error');
      }
    } catch (err) {
      App.showToast(`Error: ${err.message}`, 'error');
    }
  },

  async handleSaveSettings(e) {
    e.preventDefault();
    const key = e.target.ai_api_key.value.trim();
    if (key) {
      await fetch('/api/settings', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ ai_api_key: key })
      });
      await this.fetchSettings();
      this.showToast('AI Engine settings updated.', 'success');
    }
    this.navigate('settings');
  },

  async reloadSeedData() {
    if (!confirm('Reload landmark sample Indian legal cases?')) return;
    try {
      await fetch('/api/seed/reset', { method: 'POST' });
      this.showToast('Landmark Indian legal cases refreshed.', 'success');
      await this.loadDashboardData();
      this.navigate('dashboard');
    } catch (e) {
      this.showToast(`Failed: ${e.message}`, 'error');
    }
  },

  openSourceViewer(fileId, citationText) {
    const file = this.state.currentFiles.find(f => f.id === fileId);
    document.getElementById('modal-root').innerHTML = SourceViewerModal.render(file, citationText);
    lucide.createIcons();
  },

  openExportModal() {
    if (!this.state.currentCase || !this.state.currentSummary) {
      this.showToast('Please process case evidence before exporting brief.', 'warning');
      return;
    }
    document.getElementById('modal-root').innerHTML = ExportModal.render(
      this.state.currentCase,
      this.state.currentSummary,
      this.state.currentFiles
    );
    lucide.createIcons();
  },

  async openRecentExport() {
    if (this.state.cases.length === 0) {
      this.showToast('Please create a case first.', 'warning');
      return;
    }
    const recent = this.state.cases[0];
    await this.loadCaseData(recent.id);
    this.openExportModal();
  },

  closeModal() {
    document.getElementById('modal-root').innerHTML = '';
  },

  // ==========================================
  // Notifications & Global Search
  // ==========================================
  toggleNotificationDrawer() {
    const drawer = document.getElementById('notif-drawer');
    const isHidden = drawer.classList.contains('hidden');
    if (isHidden) {
      drawer.classList.remove('hidden');
      this.renderNotificationDrawer();
    } else {
      drawer.classList.add('hidden');
    }
  },

  renderNotificationDrawer() {
    const list = document.getElementById('notif-list');
    if (!list) return;

    if (this.state.notifications.length === 0) {
      list.innerHTML = `<p class="text-xs text-slate-500 text-center py-6">No notifications on record.</p>`;
      return;
    }

    list.innerHTML = this.state.notifications.map(n => `
      <div class="p-3 hover:bg-slate-850 transition space-y-1">
        <div class="flex items-center justify-between">
          <span class="text-xs font-bold ${n.type === 'diff' ? 'text-emerald-400' : 'text-accent'} flex items-center gap-1">
            <i data-lucide="${n.type === 'diff' ? 'git-commit' : 'sparkles'}" class="w-3.5 h-3.5"></i>
            ${escapeHtml(n.title)}
          </span>
          <span class="text-[10px] text-slate-500 font-mono">${formatTimeAgo(n.created_at)}</span>
        </div>
        <p class="text-xs text-slate-300 leading-relaxed">${escapeHtml(n.message)}</p>
        ${n.case_name ? `<p class="text-[10px] text-slate-400 font-mono">Matter: ${escapeHtml(n.case_name)}</p>` : ''}
      </div>
    `).join('');

    lucide.createIcons();
  },

  async markAllNotificationsRead() {
    await fetch('/api/notifications/read', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({})
    });
    this.state.notifications.forEach(n => n.is_read = 1);
    this.updateNotificationBadge();
    this.renderNotificationDrawer();
    this.showToast('All notifications marked read', 'info');
  },

  updateNotificationBadge() {
    const badge = document.getElementById('notif-badge');
    const unread = this.state.notifications.filter(n => n.is_read === 0).length;
    if (badge) {
      if (unread > 0) {
        badge.textContent = unread > 9 ? '9+' : unread;
        badge.classList.remove('hidden');
      } else {
        badge.classList.add('hidden');
      }
    }
  },

  handleGlobalSearch(query) {
    if (!query) return;
    const q = query.toLowerCase().trim();
    if (q.length >= 3 && this.state.currentRoute === 'dashboard') {
      const cards = document.querySelectorAll('#app-root .card-legal');
      cards.forEach(card => {
        const text = card.textContent.toLowerCase();
        card.style.display = text.includes(q) ? 'block' : 'none';
      });
    }
  },

  showToast(message, type = 'info') {
    const container = document.getElementById('toast-container');
    if (!container) return;

    const id = `toast-${Date.now()}`;
    const colors = {
      success: 'bg-slate-900 border-emerald-500/50 text-emerald-300',
      error: 'bg-slate-900 border-rose-500/50 text-rose-300',
      warning: 'bg-slate-900 border-amber-500/50 text-amber-300',
      info: 'bg-slate-900 border-accent/50 text-accent'
    };

    const icons = {
      success: 'check-circle',
      error: 'alert-circle',
      warning: 'alert-triangle',
      info: 'sparkles'
    };

    const toast = document.createElement('div');
    toast.id = id;
    toast.className = `p-3.5 rounded-xl border shadow-2xl flex items-center space-x-2.5 text-xs font-semibold pointer-events-auto transform transition-all duration-300 translate-y-2 opacity-0 ${colors[type] || colors.info}`;
    toast.innerHTML = `
      <i data-lucide="${icons[type] || 'info'}" class="w-4 h-4 shrink-0"></i>
      <span>${escapeHtml(message)}</span>
    `;

    container.appendChild(toast);
    lucide.createIcons();

    setTimeout(() => {
      toast.classList.remove('translate-y-2', 'opacity-0');
    }, 10);

    setTimeout(() => {
      toast.classList.add('opacity-0', 'translate-y-2');
      setTimeout(() => toast.remove(), 300);
    }, 4000);
  }
};

// Utility Helpers
function escapeHtml(text) {
  if (text === null || text === undefined) return '';
  return String(text)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#039;');
}

function formatBytes(bytes) {
  if (!bytes || bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return parseFloat((bytes / Math.pow(k, i)).toFixed(1)) + ' ' + sizes[i];
}

function formatTimeAgo(dateString) {
  if (!dateString) return 'recently';
  const now = new Date();
  const past = new Date(dateString);
  const diffSec = Math.floor((now - past) / 1000);

  if (diffSec < 60) return 'just now';
  if (diffSec < 3600) return `${Math.floor(diffSec / 60)}m ago`;
  if (diffSec < 86400) return `${Math.floor(diffSec / 3600)}h ago`;
  return past.toLocaleDateString('en-IN', { day: 'numeric', month: 'short' });
}

// Boot application
document.addEventListener('DOMContentLoaded', () => {
  App.init();
});
