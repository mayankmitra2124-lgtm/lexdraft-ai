// "What Changed" Visual Diff Inspector Component
const DiffInspector = {
  render(caseData, diffs = []) {
    return `
      <div class="space-y-6 animate-fadeIn">
        
        <!-- Header Banner (Clean Light Style) -->
        <div class="bg-white border border-slate-200 p-6 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-2">
          <div class="flex items-center space-x-2">
            <span class="px-2.5 py-0.5 rounded bg-emerald-50 text-emerald-600 border border-emerald-200/50 text-[11px] font-bold uppercase tracking-wider">
              Incremental Synthesis & Diff Audit
            </span>
            <span class="text-xs text-slate-400">Section 4 Compliance</span>
          </div>
          <h2 class="font-serif text-xl font-bold text-slate-900">Summary Evolution & "What Changed" Tracker</h2>
          <p class="text-xs text-slate-550 max-w-3xl leading-relaxed">
            When new evidence is introduced, only that new file is processed and merged. This inspector visualizes every modification, new timeline addition, and shift in cause of action across synthesis versions.
          </p>
        </div>

        <!-- Diffs History Feed -->
        <div class="space-y-6">
          ${diffs.length === 0 ? `
            <div class="p-12 text-center bg-white border border-slate-200 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-3">
              <div class="w-12 h-12 rounded-full bg-slate-50 flex items-center justify-center mx-auto text-emerald-500">
                <i data-lucide="git-branch" class="w-6 h-6"></i>
              </div>
              <h3 class="font-serif text-base font-bold text-slate-800">No Summary Updates Logged Yet</h3>
              <p class="text-xs text-slate-400 max-w-md mx-auto">As you add new evidence files to this case, incremental synthesis diffs will be logged and highlighted here.</p>
            </div>
          ` : diffs.map(d => DiffInspector.renderDiffCard(d)).join('')}
        </div>

      </div>
    `;
  },

  renderDiffCard(d) {
    const addedEvents = d.added_chronology || [];

    return `
      <div class="bg-white border border-slate-200 p-6 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-4 relative overflow-hidden">
        <div class="absolute top-0 left-0 bottom-0 w-1.5 bg-emerald-500"></div>

        <!-- Diff Card Header -->
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-2 border-b border-slate-100 pb-3">
          <div class="space-y-0.5">
            <div class="flex items-center space-x-2">
              <span class="font-serif text-base font-bold text-slate-800">Version ${d.summary_version} Update</span>
              <span class="px-2 py-0.5 rounded bg-emerald-50 text-emerald-600 font-mono text-[11px] font-bold border border-emerald-100">
                Triggered by: ${escapeHtml(d.file_name || 'Evidence')}
              </span>
            </div>
            <p class="text-xs text-slate-500">${escapeHtml(d.diff_summary || 'Incremental merge completed')}</p>
          </div>
          <span class="text-xs text-slate-400 font-mono">${formatTimeAgo(d.created_at)}</span>
        </div>

        <!-- Section 1: Newly Added Chronology Entries -->
        ${addedEvents.length > 0 ? `
          <div class="space-y-2">
            <h4 class="text-xs font-bold uppercase tracking-wider text-emerald-600 flex items-center gap-1.5">
              <i data-lucide="plus-circle" class="w-3.5 h-3.5"></i>
              New Chronology Events Introduced (${addedEvents.length})
            </h4>
            <div class="space-y-2">
              ${addedEvents.map(ev => `
                <div class="p-3 rounded-xl bg-emerald-50/10 border border-emerald-200 text-xs space-y-1">
                  <div class="flex items-center justify-between">
                    <span class="font-mono font-bold text-amber-600">${escapeHtml(ev.date || 'Undated')}</span>
                    ${ev.is_critical_flag ? `<span class="px-1.5 py-0.5 rounded bg-amber-500 text-slate-950 text-[10px] font-bold">CRITICAL EVIDENCE</span>` : ''}
                  </div>
                  <p class="font-serif text-slate-800 font-medium">${escapeHtml(ev.event)}</p>
                  <p class="text-[11px] text-slate-600"><strong>Legal Significance:</strong> ${escapeHtml(ev.legal_relevance)}</p>
                  <p class="text-[10px] text-slate-400 font-mono">Supporting Reference: ${escapeHtml(ev.supporting_document)}</p>
                </div>
              `).join('')}
            </div>
          </div>
        ` : ''}

        <!-- Section 2: Modified Facts Impact -->
        <div class="p-3.5 rounded-xl bg-slate-50 border border-slate-100 text-xs space-y-1">
          <span class="font-bold text-slate-600 uppercase tracking-wider text-[10px]">Material Facts Impact:</span>
          <p class="text-slate-700">${escapeHtml(d.modified_facts || 'Facts narrative synchronized with new evidence.')}</p>
        </div>

        <!-- Section 3: Cause of Action Evolution -->
        <div class="p-3.5 rounded-xl bg-slate-50 border border-slate-100 text-xs space-y-1">
          <span class="font-bold text-slate-600 uppercase tracking-wider text-[10px]">Cause of Action Development:</span>
          <p class="text-slate-700">${escapeHtml(d.shift_in_cause_of_action || 'No fundamental change in cause of action.')}</p>
        </div>

      </div>
    `;
  }
};
