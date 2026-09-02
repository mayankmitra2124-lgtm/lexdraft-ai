// Interactive Master Chronology & Timeline View Component
const TimelineView = {
  activeViewMode: 'table', // 'table' or 'visual'
  criticalOnly: false,
  searchQuery: '',

  render(caseData, summary) {
    if (!summary || !summary.chronology || summary.chronology.length === 0) {
      return `
        <div class="p-12 text-center bg-white border border-slate-200 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-4">
          <div class="w-12 h-12 rounded-full bg-slate-50 flex items-center justify-center mx-auto text-amber-500">
            <i data-lucide="calendar-clock" class="w-6 h-6"></i>
          </div>
          <h3 class="font-serif text-lg font-bold text-slate-800">No Chronological Events Extracted</h3>
          <p class="text-xs text-slate-550 max-w-md mx-auto">Upload evidence files to automatically extract chronological dates, events, and legal relevance.</p>
        </div>
      `;
    }

    const allEvents = summary.chronology || [];
    const criticalCount = allEvents.filter(e => e.is_critical_flag).length;

    // Filter logic
    let filteredEvents = allEvents;
    if (this.criticalOnly) {
      filteredEvents = filteredEvents.filter(e => e.is_critical_flag);
    }
    if (this.searchQuery) {
      const q = this.searchQuery.toLowerCase();
      filteredEvents = filteredEvents.filter(e => 
        (e.event && e.event.toLowerCase().includes(q)) ||
        (e.date && e.date.toLowerCase().includes(q)) ||
        (e.who_involved && e.who_involved.toLowerCase().includes(q)) ||
        (e.supporting_document && e.supporting_document.toLowerCase().includes(q)) ||
        (e.legal_relevance && e.legal_relevance.toLowerCase().includes(q))
      );
    }

    return `
      <div class="space-y-6 animate-fadeIn">
        
        <!-- Controls & Filters Bar (Clean Light Style) -->
        <div class="bg-white border border-slate-200 rounded-2xl p-4 shadow-[0_4px_20px_rgba(0,0,0,0.02)] flex flex-col md:flex-row md:items-center justify-between gap-4">
          
          <!-- Search & Filter Controls -->
          <div class="flex flex-wrap items-center gap-3">
            
            <!-- Search Input -->
            <div class="relative w-72">
              <i data-lucide="search" class="w-4 h-4 absolute left-3 top-2.5 text-slate-400"></i>
              <input type="text" value="${escapeHtml(this.searchQuery)}" oninput="TimelineView.handleSearch(this.value)" placeholder="Search events, dates, acts..." 
                class="w-full bg-slate-50 border border-slate-200 rounded-lg pl-9 pr-3 py-1.5 text-xs text-slate-800 placeholder-slate-400 focus:outline-none focus:border-amber-500">
            </div>

            <!-- Critical Evidence Only Toggle -->
            <button onclick="TimelineView.toggleCriticalOnly()" class="px-3 py-1.5 rounded-lg border text-xs font-semibold flex items-center space-x-2 transition ${this.criticalOnly ? 'bg-gradient-gold text-slate-950 border-amber-500 font-bold shadow-md' : 'bg-slate-50 text-slate-700 border-slate-200 hover:border-amber-500'}">
              <i data-lucide="star" class="w-3.5 h-3.5 ${this.criticalOnly ? 'text-slate-950 fill-slate-950' : 'text-amber-500'}"></i>
              <span>Critical Evidence Only (${criticalCount})</span>
            </button>
          </div>

          <!-- View Mode Switcher -->
          <div class="flex items-center space-x-1 bg-slate-50 p-1 rounded-xl border border-slate-200">
            <button onclick="TimelineView.setViewMode('table')" class="px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center space-x-1.5 transition ${this.activeViewMode === 'table' ? 'bg-white text-slate-800 shadow border border-slate-200/50' : 'text-slate-500 hover:text-slate-800'}">
              <i data-lucide="table-2" class="w-3.5 h-3.5"></i>
              <span>Court Table</span>
            </button>
            <button onclick="TimelineView.setViewMode('visual')" class="px-3 py-1.5 rounded-lg text-xs font-semibold flex items-center space-x-1.5 transition ${this.activeViewMode === 'visual' ? 'bg-white text-slate-800 shadow border border-slate-200/50' : 'text-slate-500 hover:text-slate-800'}">
              <i data-lucide="git-commit" class="w-3.5 h-3.5"></i>
              <span>Visual Timeline</span>
            </button>
          </div>

        </div>

        <!-- Feature 4: Statutory Limitation Clock & Legal Trigger Calculator Widget -->
        ${this.renderLimitationClockWidget(summary.limitation_analysis)}

        <!-- Render Table or Visual Timeline -->
        ${this.activeViewMode === 'table' ? this.renderTableView(filteredEvents) : this.renderVisualView(filteredEvents)}

      </div>
    `;
  },

  renderLimitationClockWidget(limitation) {
    if (!limitation || !limitation.days_remaining) return '';

    const isUrgent = limitation.status === 'CRITICAL_URGENT' || limitation.status === 'EXPIRED';
    const isExpiringSoon = limitation.status === 'EXPIRING_SOON';
    const statusColor = isUrgent ? 'border-rose-300 bg-rose-50/50' : (isExpiringSoon ? 'border-amber-300 bg-amber-50/50' : 'border-emerald-300 bg-emerald-50/30');
    const badgeColor = isUrgent ? 'bg-rose-100 text-rose-800 border-rose-300' : (isExpiringSoon ? 'bg-amber-100 text-amber-800 border-amber-300' : 'bg-emerald-100 text-emerald-800 border-emerald-300');

    return `
      <div class="rounded-2xl border p-4 shadow-sm space-y-3 ${statusColor}">
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-2 border-b border-slate-200/60 pb-2.5">
          <div class="flex items-center space-x-2.5">
            <div class="p-2 rounded-xl bg-white border border-slate-200 shadow-sm text-amber-500">
              <i data-lucide="hourglass" class="w-5 h-5"></i>
            </div>
            <div>
              <div class="flex items-center space-x-2">
                <h4 class="font-serif text-sm font-bold text-slate-800">Statutory Limitation Clock</h4>
                <span class="px-2 py-0.5 rounded-full text-[10px] font-mono font-bold border ${badgeColor}">
                  ${limitation.days_remaining > 0 ? `${limitation.days_remaining} Days Remaining` : 'LIMITATION EXPIRED'}
                </span>
              </div>
              <p class="text-[11px] text-slate-500 font-mono">${escapeHtml(limitation.governing_statute || 'Limitation Act, 1963')}</p>
            </div>
          </div>

          <div class="flex items-center space-x-2 text-xs font-mono">
            <span class="text-slate-500">Limitation Bar Date:</span>
            <span class="font-bold text-slate-800 bg-white px-2.5 py-1 rounded-lg border border-slate-200">${escapeHtml(limitation.limitation_expiry_date || 'Calculated')}</span>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs">
          <div class="bg-white/80 p-2.5 rounded-xl border border-slate-200/80">
            <span class="text-[10px] text-slate-400 font-semibold uppercase">Cause of Action Trigger</span>
            <p class="font-medium text-slate-700 truncate mt-0.5">${escapeHtml(limitation.trigger_event || 'Contractual breach / notice')}</p>
            <p class="text-[10px] font-mono text-slate-500 mt-0.5">Trigger Date: ${escapeHtml(limitation.trigger_date || 'N/A')}</p>
          </div>

          <div class="bg-white/80 p-2.5 rounded-xl border border-slate-200/80">
            <span class="text-[10px] text-slate-400 font-semibold uppercase">Prescribed Statutory Period</span>
            <p class="font-medium text-slate-700 mt-0.5">${escapeHtml(limitation.statutory_period || '3 Years (36 Months)')}</p>
            <p class="text-[10px] font-mono text-emerald-600 mt-0.5">Commercial Courts Act Sec 12A PIMS Gate</p>
          </div>

          <div class="bg-white/80 p-2.5 rounded-xl border border-slate-200/80">
            <span class="text-[10px] text-slate-400 font-semibold uppercase">Court Counsel Recommendation</span>
            <p class="font-serif text-[11px] text-slate-800 mt-0.5 leading-snug">${escapeHtml(limitation.remedy_guidance || 'Action is strictly within statutory limitation.')}</p>
          </div>
        </div>
      </div>
    `;
  },

  renderTableView(events) {
    if (events.length === 0) {
      return `
        <div class="p-8 text-center bg-white border border-slate-200 rounded-2xl text-xs text-slate-400">
          No events match the current filter criteria.
        </div>
      `;
    }

    return `
      <div class="bg-white border border-slate-200 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] overflow-hidden">
        <div class="p-4 bg-slate-50 border-b border-slate-200 flex items-center justify-between">
          <div class="flex items-center space-x-2">
            <i data-lucide="list-ordered" class="w-4 h-4 text-amber-500"></i>
            <h3 class="font-serif text-sm font-bold text-slate-800 uppercase tracking-wider">Chronology of Dates & Material Events (Court-Ready)</h3>
          </div>
          <span class="text-xs text-slate-500 font-mono">${events.length} chronological items</span>
        </div>

        <div class="overflow-x-auto">
          <table class="w-full text-left text-xs border-collapse">
            <thead class="bg-slate-50 text-slate-600 uppercase tracking-wider font-semibold border-b border-slate-200">
              <tr>
                <th class="p-3.5 w-28">Date</th>
                <th class="p-3.5">Event / Transaction</th>
                <th class="p-3.5 w-64">Supporting Document / Annexure</th>
                <th class="p-3.5">Legal Significance & Relevance</th>
                <th class="p-3.5 w-24 text-center">Status</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-slate-100 text-slate-700">
              ${events.map((ev, idx) => {
                const isCritical = ev.is_critical_flag;
                const isNew = ev.is_new_addition;

                return `
                  <tr class="hover:bg-slate-50/50 transition ${isCritical ? 'critical-evidence-border bg-amber-50/10' : ''} ${isNew ? 'new-diff-border bg-emerald-50/10' : ''}">
                    
                    <!-- Date Column -->
                    <td class="p-3.5 font-mono font-semibold ${isCritical ? 'text-amber-600' : 'text-slate-800'} whitespace-nowrap">
                      ${escapeHtml(ev.date || 'Undated')}
                    </td>

                    <!-- Event Column -->
                    <td class="p-3.5 leading-relaxed">
                      <p class="font-serif text-slate-850 font-medium text-xs mb-1">${escapeHtml(ev.event)}</p>
                      ${ev.who_involved ? `<p class="text-[11px] text-slate-500 flex items-center gap-1"><i data-lucide="user-check" class="w-3.5 h-3.5 text-amber-500"></i> ${escapeHtml(ev.who_involved)}</p>` : ''}
                    </td>

                    <!-- Supporting Document Citation (Clickable) -->
                    <td class="p-3.5">
                      <button onclick="App.openSourceViewer('${ev.file_id || ''}', '${escapeHtml(ev.supporting_document)}')" class="text-left group flex items-start space-x-1.5 p-2 rounded-lg bg-slate-50 hover:bg-slate-100 border border-slate-200 hover:border-amber-500 transition w-full">
                        <i data-lucide="file-text" class="w-3.5 h-3.5 text-amber-500 shrink-0 mt-0.5 group-hover:scale-110 transition"></i>
                        <div class="overflow-hidden">
                          <p class="text-[11px] font-mono text-amber-600 font-semibold truncate group-hover:underline">${escapeHtml(ev.supporting_document || ev.file_name || 'Document')}</p>
                          <p class="text-[10px] text-slate-400">Click to view source</p>
                        </div>
                      </button>
                    </td>

                    <!-- Legal Relevance -->
                    <td class="p-3.5 text-slate-600 leading-relaxed font-sans text-xs">
                      ${escapeHtml(ev.legal_relevance || 'Corroborates sequence of events.')}
                    </td>

                    <!-- Tags / Badges -->
                    <td class="p-3.5 text-center">
                      <div class="flex flex-col items-center space-y-1">
                        ${isCritical ? `
                          <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-amber-500 text-slate-950 shadow-sm">
                            CRITICAL
                          </span>
                        ` : `
                          <span class="px-1.5 py-0.5 rounded text-[10px] text-slate-500 bg-slate-100">
                            STANDARD
                          </span>
                        `}
                        ${isNew ? `
                          <span class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-emerald-50 text-emerald-600 border border-emerald-100">
                            NEW
                          </span>
                        ` : ''}
                        ${ev.grounding_status === 'UNVERIFIED_TOKEN_DRIFT' ? `
                          <span class="px-1.5 py-0.5 rounded text-[9px] font-mono font-semibold bg-rose-50 text-rose-700 border border-rose-200 flex items-center gap-0.5" title="Reverse Grounding Warning: Numbers/dates unconfirmed in source document">
                            <i data-lucide="alert-triangle" class="w-2.5 h-2.5"></i>Drift
                          </span>
                        ` : `
                          <span class="px-1.5 py-0.5 rounded text-[9px] font-mono font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 flex items-center gap-0.5" title="Deterministic Reverse Grounding: Numbers, dates and clauses verified in source document">
                            <i data-lucide="check-check" class="w-2.5 h-2.5"></i>Grounded
                          </span>
                        `}
                      </div>
                    </td>

                  </tr>
                `;
              }).join('')}
            </tbody>
          </table>
        </div>
      </div>
    `;
  },

  renderVisualView(events) {
    return `
      <div class="bg-white border border-slate-200 rounded-2xl p-6 shadow-[0_4px_20px_rgba(0,0,0,0.02)] relative">
        <div class="timeline-stem" style="background-color: #E2E8F0; width: 2px; left: 29px; position: absolute; top: 24px; bottom: 24px;"></div>
        <div class="space-y-6">
          ${events.map((ev, idx) => {
            const isCritical = ev.is_critical_flag;
            const isNew = ev.is_new_addition;

            return `
              <div class="relative pl-12 group">
                
                <!-- Node Marker -->
                <div class="absolute left-2.5 top-1.5 w-6 h-6 rounded-full border-2 ${isCritical ? 'bg-amber-500 border-white shadow-md ring-4 ring-amber-100' : 'bg-slate-100 border-slate-300'} flex items-center justify-center -translate-x-1/2 transition z-10">
                  <i data-lucide="${isCritical ? 'star' : 'circle'}" class="w-3 h-3 ${isCritical ? 'text-slate-950 fill-slate-950' : 'text-slate-400'}"></i>
                </div>

                <!-- Event Content Card -->
                <div class="p-4 rounded-xl bg-white border ${isCritical ? 'border-amber-500/50 bg-amber-50/10 shadow-sm critical-evidence-border' : 'border-slate-200'} space-y-2.5 transition group-hover:border-slate-350">
                  
                  <div class="flex flex-wrap items-center justify-between gap-2 border-b border-slate-100 pb-2">
                    <div class="flex items-center space-x-2">
                      <span class="font-mono text-xs font-bold text-amber-600">${escapeHtml(ev.date)}</span>
                      ${isCritical ? `<span class="px-2 py-0.5 rounded bg-amber-500 text-slate-950 text-[10px] font-bold">CRITICAL EVIDENCE</span>` : ''}
                      ${isNew ? `<span class="px-1.5 py-0.5 rounded bg-emerald-50 text-emerald-600 text-[10px] font-bold border border-emerald-100">RECENTLY ADDED</span>` : ''}
                    </div>

                    <!-- Source Citation Button -->
                    <button onclick="App.openSourceViewer('${ev.file_id || ''}', '${escapeHtml(ev.supporting_document)}')" class="text-[11px] font-mono text-amber-600 hover:underline flex items-center gap-1 bg-slate-50 px-2 py-1 rounded border border-slate-200">
                      <i data-lucide="paperclip" class="w-3 h-3"></i>
                      <span>${escapeHtml(ev.supporting_document || 'Source')}</span>
                    </button>
                  </div>

                  <p class="font-serif text-sm text-slate-800 font-medium">${escapeHtml(ev.event)}</p>

                  <div class="grid grid-cols-1 md:grid-cols-2 gap-2 text-xs pt-1 text-slate-600">
                    <div class="flex items-center gap-1.5">
                      <span class="text-slate-400 font-semibold">Involved:</span>
                      <span>${escapeHtml(ev.who_involved || 'Parties of Record')}</span>
                    </div>
                    <div>
                      <span class="text-slate-400 font-semibold">Legal Impact:</span>
                      <span>${escapeHtml(ev.legal_relevance || 'Corroborates timeline')}</span>
                    </div>
                  </div>

                </div>
              </div>
            `;
          }).join('')}
        </div>
      </div>
    `;
  },

  setViewMode(mode) {
    this.activeViewMode = mode;
    App.refreshCurrentView();
  },

  toggleCriticalOnly() {
    this.criticalOnly = !this.criticalOnly;
    App.refreshCurrentView();
  },

  handleSearch(query) {
    this.searchQuery = query;
    App.refreshCurrentView();
  }
};
