// Dashboard View Component (Clio / Harvey AI Inspired Legal Tech Dashboard)
const Dashboard = {
  render(cases = [], notifications = []) {
    const totalCases = cases.length;
    const totalFiles = cases.reduce((acc, c) => acc + (c.total_files || 0), 0);
    const pendingPipeline = cases.reduce((acc, c) => acc + (c.pending_files || 0), 0);

    return `
      <div class="space-y-8 animate-fadeIn">
        
        <!-- Welcome & Chamber Header -->
        <div class="space-y-1.5">
          <h2 class="font-serif text-3xl font-semibold text-slate-900 tracking-wide">Good morning, Advocate</h2>
          <p class="text-xs text-slate-500 font-sans">Here's an overview of your legal workspace.</p>
        </div>

        <!-- 1. StatsCards (Row of 4 Cards matching User Image) -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
          
          <!-- Active Cases -->
          <div class="bg-white border border-slate-200 rounded-2xl p-5 flex items-center justify-between shadow-[0_4px_20px_rgba(0,0,0,0.02)]">
            <div class="space-y-1">
              <span class="text-xs font-semibold text-slate-400 font-sans">Active Cases</span>
              <p class="text-3xl font-bold text-slate-900 font-sans">${totalCases > 0 ? totalCases : 24}</p>
              <p class="text-[11px] text-slate-500 font-medium">+3 this week</p>
            </div>
            <div class="w-10 h-10 rounded-xl bg-amber-50 border border-amber-200/50 flex items-center justify-center text-amber-500">
              <i data-lucide="file-text" class="w-5 h-5"></i>
            </div>
          </div>

          <!-- Total Clients -->
          <div class="bg-white border border-slate-200 rounded-2xl p-5 flex items-center justify-between shadow-[0_4px_20px_rgba(0,0,0,0.02)]">
            <div class="space-y-1">
              <span class="text-xs font-semibold text-slate-400 font-sans">Total Clients</span>
              <p class="text-3xl font-bold text-slate-900 font-sans">156</p>
              <p class="text-[11px] text-slate-500 font-medium">+12 this month</p>
            </div>
            <div class="w-10 h-10 rounded-xl bg-slate-100 border border-slate-200/50 flex items-center justify-center text-slate-500">
              <i data-lucide="users" class="w-5 h-5"></i>
            </div>
          </div>

          <!-- Drafts in Progress -->
          <div class="bg-white border border-slate-200 rounded-2xl p-5 flex items-center justify-between shadow-[0_4px_20px_rgba(0,0,0,0.02)]">
            <div class="space-y-1">
              <span class="text-xs font-semibold text-slate-400 font-sans">Drafts in Progress</span>
              <p class="text-3xl font-bold text-slate-900 font-sans">${pendingPipeline > 0 ? pendingPipeline : 3}</p>
              <p class="text-[11px] text-slate-500 font-medium">3 due today</p>
            </div>
            <div class="w-10 h-10 rounded-xl bg-orange-50 border border-orange-200/50 flex items-center justify-center text-orange-500">
              <i data-lucide="clock" class="w-5 h-5"></i>
            </div>
          </div>

          <!-- Completed Drafts -->
          <div class="bg-white border border-slate-200 rounded-2xl p-5 flex items-center justify-between shadow-[0_4px_20px_rgba(0,0,0,0.02)]">
            <div class="space-y-1">
              <span class="text-xs font-semibold text-slate-400 font-sans">Completed Drafts</span>
              <p class="text-3xl font-bold text-slate-900 font-sans">342</p>
              <p class="text-[11px] text-emerald-600 font-semibold">95% on time</p>
            </div>
            <div class="w-10 h-10 rounded-xl bg-emerald-50 border border-emerald-200/50 flex items-center justify-center text-emerald-500">
              <i data-lucide="check-circle" class="w-5 h-5"></i>
            </div>
          </div>

        </div>

        <!-- 2. QuickActions (Row of 4 Styled Tiles matching User Image) -->
        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-5">
          
          <!-- New Case (Gold Accent Gradient Button) -->
          <button onclick="App.navigate('new-case')" class="bg-gradient-gold text-left p-5 rounded-2xl shadow-lg shadow-amber-500/15 flex items-start space-x-4 transition hover:brightness-105 active:scale-[0.98]">
            <div class="w-9 h-9 rounded-xl bg-black/10 flex items-center justify-center text-slate-950 mt-0.5">
              <i data-lucide="file-plus" class="w-5 h-5"></i>
            </div>
            <div>
              <p class="text-sm font-bold text-slate-950 font-sans">New Case</p>
              <p class="text-[11px] text-slate-900 font-medium opacity-90 mt-0.5">Start a new petition or case from scratch</p>
            </div>
          </button>

          <!-- Upload Document -->
          <button onclick="App.navigate('new-case')" class="bg-white border border-slate-200 text-left p-5 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] flex items-start space-x-4 transition hover:border-slate-350 hover:bg-slate-50 active:scale-[0.98]">
            <div class="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center text-slate-500 mt-0.5">
              <i data-lucide="upload" class="w-5 h-5"></i>
            </div>
            <div>
              <p class="text-sm font-bold text-slate-800 font-sans">Upload Document</p>
              <p class="text-[11px] text-slate-400 mt-0.5">Import evidence from PDF or Word</p>
            </div>
          </button>

          <!-- Voice Dictation -->
          <button onclick="App.showToast('Voice dictation module coming soon!', 'info')" class="bg-white border border-slate-200 text-left p-5 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] flex items-start space-x-4 transition hover:border-slate-350 hover:bg-slate-50 active:scale-[0.98]">
            <div class="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center text-slate-500 mt-0.5">
              <i data-lucide="mic" class="w-5 h-5"></i>
            </div>
            <div>
              <p class="text-sm font-bold text-slate-800 font-sans">Voice Dictation</p>
              <p class="text-[11px] text-slate-400 mt-0.5">Dictate your case details directly</p>
            </div>
          </button>

          <!-- Use Template -->
          <button onclick="App.showToast('Select templates from settings or case view', 'info')" class="bg-white border border-slate-200 text-left p-5 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] flex items-start space-x-4 transition hover:border-slate-350 hover:bg-slate-50 active:scale-[0.98]">
            <div class="w-9 h-9 rounded-xl bg-slate-100 flex items-center justify-center text-slate-500 mt-0.5">
              <i data-lucide="file-text" class="w-5 h-5"></i>
            </div>
            <div>
              <p class="text-sm font-bold text-slate-800 font-sans">Use Template</p>
              <p class="text-[11px] text-slate-400 mt-0.5">Start from a vetted court template</p>
            </div>
          </button>

        </div>

        <!-- 3. Split Layout: Recent Drafts (Left) + Activity (Right) -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          
          <!-- Recent Drafts List (Left 2 Columns) -->
          <div class="lg:col-span-2 bg-white border border-slate-200 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] overflow-hidden">
            <div class="px-5 py-4 border-b border-slate-200 flex items-center justify-between">
              <h3 class="font-serif text-lg font-semibold text-slate-900">Recent Cases & Drafts</h3>
              <button onclick="App.navigate('cases-list')" class="text-xs text-slate-400 hover:text-slate-800 font-semibold flex items-center gap-1">
                <span>View all</span>
                <i data-lucide="chevron-right" class="w-3.5 h-3.5"></i>
              </button>
            </div>

            <div class="divide-y divide-slate-100">
              ${cases.length === 0 ? `
                <div class="p-12 text-center space-y-3">
                  <div class="w-12 h-12 rounded-full bg-slate-50 flex items-center justify-center mx-auto text-slate-400">
                    <i data-lucide="folder-open" class="w-6 h-6"></i>
                  </div>
                  <h4 class="font-serif text-base font-semibold text-slate-800">No active case vaults</h4>
                  <p class="text-xs text-slate-400 max-w-sm mx-auto">Create a new case setup to begin compiling chronology timelines.</p>
                  <button onclick="App.navigate('new-case')" class="px-4 py-2 bg-gradient-gold text-slate-900 font-bold text-xs rounded-xl">Create New Case</button>
                </div>
              ` : cases.map(c => `
                <div class="px-5 py-4 flex items-center justify-between hover:bg-slate-50 cursor-pointer transition" onclick="App.openCase('${c.id}')">
                  <div class="flex items-center space-x-3.5 min-w-0">
                    <div class="w-9 h-9 rounded-xl bg-slate-50 border border-slate-100 flex items-center justify-center text-slate-400 shrink-0">
                      <i data-lucide="file-text" class="w-4 h-4"></i>
                    </div>
                    <div class="min-w-0">
                      <p class="text-xs font-bold text-slate-800 truncate">${escapeHtml(c.name)}</p>
                      <p class="text-[11px] text-slate-400 mt-0.5 truncate">${escapeHtml(c.court_name || 'Delhi High Court')} • ${c.total_files || 0} Files</p>
                    </div>
                  </div>

                  <div class="flex items-center space-x-4 shrink-0">
                    <span class="px-2.5 py-0.5 rounded text-[10px] font-bold ${
                      c.pending_files > 0 ? 'bg-amber-50 text-amber-600 border border-amber-100' : 'bg-emerald-50 text-emerald-600 border border-emerald-100'
                    }">
                      ${c.pending_files > 0 ? 'In Progress' : 'Completed'}
                    </span>
                    <span class="text-[11px] text-slate-400 font-sans">${formatTimeAgo(c.updated_at || c.created_at)}</span>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>

          <!-- Activity Feed (Right 1 Column) -->
          <div class="bg-white border border-slate-200 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] p-5 space-y-4">
            <div class="border-b border-slate-100 pb-2">
              <h3 class="font-serif text-lg font-semibold text-slate-900">Activity</h3>
            </div>

            <div class="space-y-4">
              ${notifications.length === 0 ? `
                <p class="text-xs text-slate-400 text-center py-6">No recent workspace activity.</p>
              ` : notifications.slice(0, 5).map(n => `
                <div class="flex items-start space-x-3 text-xs">
                  <div class="w-7 h-7 rounded-full bg-slate-50 border border-slate-100 flex items-center justify-center shrink-0 mt-0.5">
                    <i data-lucide="${n.type === 'diff' ? 'git-commit' : 'check-circle'}" class="w-3.5 h-3.5 text-emerald-500"></i>
                  </div>
                  <div class="space-y-0.5 min-w-0">
                    <p class="text-slate-800 font-semibold line-clamp-2">${escapeHtml(n.message)}</p>
                    <p class="text-[10px] text-slate-400">${formatTimeAgo(n.created_at)}</p>
                  </div>
                </div>
              `).join('')}
            </div>
          </div>

        </div>

      </div>
    `;
  },

  renderRecentCaseCard(c) {
    const hasDiff = c.has_unread_changes === 1;
    const completedCount = c.completed_files || 0;
    const totalFiles = c.total_files || 0;

    return `
      <div class="bg-white border border-slate-200 p-5 rounded-2xl cursor-pointer relative overflow-hidden group hover:border-slate-355 transition shadow-[0_4px_20px_rgba(0,0,0,0.02)] ${hasDiff ? 'border-emerald-500/40 bg-emerald-50/10' : ''}" onclick="App.openCase('${c.id}')">
        
        ${hasDiff ? `
          <div class="absolute top-0 right-0 bg-emerald-50 border-b border-l border-emerald-250 px-3 py-1 rounded-bl-xl flex items-center space-x-1.5 text-emerald-600 text-[10px] font-bold">
            <span class="w-1.5 h-1.5 rounded-full bg-emerald-500 animate-ping"></span>
            <span>New Evidence Merged</span>
          </div>
        ` : ''}

        <div class="space-y-3.5">
          
          <div class="flex items-start justify-between pr-28">
            <div class="space-y-1">
              <h4 class="font-serif text-base font-bold text-slate-800 group-hover:text-amber-600 transition">${escapeHtml(c.name)}</h4>
              <p class="text-xs text-slate-500 flex items-center gap-1.5">
                <i data-lucide="landmark" class="w-3.5 h-3.5 text-amber-500"></i>
                ${escapeHtml(c.court_name || 'High Court of Delhi')}
              </p>
            </div>
          </div>

          <!-- Objective Excerpt -->
          <div class="bg-slate-50 rounded-xl p-3 border border-slate-100">
            <p class="text-xs text-slate-600 line-clamp-2 italic font-reading">
              "${escapeHtml(c.objective || 'No objective specified yet.')}"
            </p>
          </div>

          <!-- Bottom Metadata Row -->
          <div class="flex flex-wrap items-center justify-between pt-2 border-t border-slate-100 text-xs text-slate-500 gap-3">
            <div class="flex items-center space-x-4">
              <span class="flex items-center space-x-1.5">
                <i data-lucide="files" class="w-3.5 h-3.5 text-slate-400"></i>
                <span class="text-slate-800 font-semibold">${completedCount}/${totalFiles}</span>
                <span>files processed</span>
              </span>
              <span class="flex items-center space-x-1.5">
                <i data-lucide="hard-drive" class="w-3.5 h-3.5 text-slate-400"></i>
                <span class="text-slate-800 font-mono">${c.total_size_formatted || '0 B'}</span>
                <span class="text-slate-400">/ ${c.max_storage_formatted || '4 GB'}</span>
              </span>
            </div>

            <div class="flex items-center space-x-2">
              <button onclick="event.stopPropagation(); App.openCase('${c.id}')" class="px-3 py-1 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 font-medium text-xs transition flex items-center space-x-1">
                <span>Open Evidence Locker</span>
                <i data-lucide="arrow-right" class="w-3.5 h-3.5 text-amber-500"></i>
              </button>
            </div>
          </div>

        </div>
      </div>
    `;
  }
};
