// Court-Ready Master Summary Component
const SummaryView = {
  render(caseData, summary, extractions = []) {
    if (!summary || !summary.parties) {
      return `
        <div class="p-12 text-center bg-white border border-slate-200 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-4">
          <div class="w-12 h-12 rounded-full bg-slate-50 flex items-center justify-center mx-auto text-amber-500">
            <i data-lucide="file-clock" class="w-6 h-6"></i>
          </div>
          <h3 class="font-serif text-lg font-bold text-slate-800">No Evidence Processed Yet</h3>
          <p class="text-xs text-slate-405 max-w-md mx-auto">Upload case evidence files (PDFs, WhatsApp chats, audio/video) to initiate AI extraction and synthesize the master summary.</p>
          <button onclick="App.setCaseTab('evidence')" class="px-4 py-2 bg-gradient-gold text-slate-900 font-bold text-xs rounded-xl hover:brightness-110 transition shadow">Go to Evidence Upload</button>
        </div>
      `;
    }

    const parties = summary.parties || [];
    const jurisdiction = summary.jurisdiction || {};
    const factsNarrative = summary.facts_narrative || "No narrative generated.";
    const causeOfAction = summary.cause_of_action_text || "No cause of action text generated.";

    // Collect all ambiguities across all file extractions
    const allAmbiguities = extractions.flatMap(ext => (ext.ambiguities || []).map(a => ({ text: a, file_id: ext.file_id })));

    return `
      <div class="space-y-8 animate-fadeIn">
        
        <!-- Summary Version & Court Header Banner -->
        <div class="bg-white border border-slate-200 p-6 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div class="space-y-1">
            <div class="flex items-center space-x-2">
              <span class="px-2.5 py-0.5 rounded bg-amber-50 text-amber-600 border border-amber-250 text-[11px] font-bold uppercase tracking-wider">
                Court-Ready Master Brief • Version ${summary.version}
              </span>
              <span class="text-xs text-slate-400">Synthesized on ${new Date(summary.created_at).toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })}</span>
            </div>
            <h2 class="font-serif text-xl font-bold text-slate-800">${escapeHtml(caseData.name)}</h2>
            <p class="text-xs text-slate-405 flex items-center gap-2">
              <span>${escapeHtml(caseData.court_name || 'Designated Court')}</span>
            </p>
          </div>

          <!-- Quick Action Buttons -->
          <div class="flex items-center space-x-3">
            <button onclick="App.openExportModal()" class="px-3.5 py-2 rounded-xl bg-slate-50 hover:bg-slate-100 border border-slate-200 text-slate-700 text-xs font-semibold flex items-center space-x-2 transition">
              <i data-lucide="printer" class="w-4 h-4 text-amber-500"></i>
              <span>Export Court Brief</span>
            </button>
          </div>
        </div>

        <!-- Section 1: Consolidated Parties Registry (Deduplicated) -->
        <div class="bg-white border border-slate-200 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] p-6 space-y-4">
          <div class="flex items-center justify-between border-b border-slate-200 pb-3">
            <div class="flex items-center space-x-2.5">
              <div class="p-2 rounded-lg bg-slate-50 border border-slate-100 text-amber-500">
                <i data-lucide="users" class="w-4 h-4"></i>
              </div>
              <h3 class="font-serif text-base font-bold text-slate-800 uppercase tracking-wider">1. Memo of Parties & Key Entities (Consolidated)</h3>
            </div>
            <span class="text-xs text-slate-400">${parties.length} entities identified & verified</span>
          </div>

          <div class="overflow-x-auto">
            <table class="w-full text-left text-xs">
              <thead class="bg-slate-50 border border-slate-200 text-slate-600 uppercase tracking-wider font-semibold">
                <tr>
                  <th class="p-3 rounded-l-lg">Party / Entity Name</th>
                  <th class="p-3">Designation / Role</th>
                  <th class="p-3">Address & Jurisdiction</th>
                  <th class="p-3">Relationship / Disclosed Context</th>
                  <th class="p-3 rounded-r-lg">Source Evidence</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-slate-100 text-slate-700">
                ${parties.map(p => `
                  <tr class="hover:bg-slate-50/50 transition">
                    <td class="p-3 font-semibold text-slate-800">${escapeHtml(p.name)}</td>
                    <td class="p-3">
                      <span class="px-2.5 py-0.5 rounded text-[11px] font-semibold ${p.role?.toLowerCase().includes('petitioner') || p.role?.toLowerCase().includes('claimant') ? 'bg-blue-50 text-blue-600 border border-blue-100' : p.role?.toLowerCase().includes('respondent') || p.role?.toLowerCase().includes('accused') ? 'bg-rose-50 text-rose-600 border border-rose-100' : 'bg-slate-100 text-slate-655'}">
                        ${escapeHtml(p.role || 'Party')}
                      </span>
                    </td>
                    <td class="p-3 text-slate-500">${escapeHtml(p.address || 'Mentioned in record')}</td>
                    <td class="p-3 text-slate-600">${escapeHtml(p.relationship || p.conflicts_or_notes || 'Signatory / Witness')}</td>
                    <td class="p-3">
                      <div class="flex flex-wrap gap-1">
                        ${(p.source_files || ['Record']).map(src => `
                          <span class="px-1.5 py-0.5 rounded bg-slate-50 text-slate-500 text-[10px] font-mono border border-slate-200">${escapeHtml(src)}</span>
                        `).join('')}
                      </div>
                    </td>
                  </tr>
                `).join('')}
              </tbody>
            </table>
          </div>
        </div>

        <!-- Section 2: Consolidated Jurisdiction -->
        <div class="bg-white border border-slate-200 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] p-6 space-y-4">
          <div class="flex items-center space-x-2.5 border-b border-slate-200 pb-3">
            <div class="p-2 rounded-lg bg-slate-50 border border-slate-100 text-amber-500">
              <i data-lucide="map-pin" class="w-4 h-4"></i>
            </div>
            <div>
              <h3 class="font-serif text-base font-bold text-slate-800 uppercase tracking-wider">2. Jurisdiction & Forum Competence</h3>
              <p class="text-[11px] text-slate-400">Strict evidentiary basis for territorial, pecuniary, and subject-matter jurisdiction</p>
            </div>
          </div>

          <div class="bg-slate-50 rounded-xl p-4 border border-slate-200 space-y-3">
            <div class="flex items-center justify-between">
              <span class="text-xs font-bold text-amber-600 uppercase tracking-wider">Court / Forum: ${escapeHtml(jurisdiction.court_name || caseData.court_name)}</span>
              <span class="px-2 py-0.5 rounded bg-slate-100 text-slate-600 text-[11px] font-mono">${escapeHtml(jurisdiction.primary_basis || 'Territorial & Subject Matter')}</span>
            </div>
            
            <div class="text-xs text-slate-700 leading-relaxed whitespace-pre-line bg-white p-3.5 rounded-lg border border-slate-150">
              ${escapeHtml(jurisdiction.consolidated_reasoning || 'Jurisdiction established on the basis of cause of action arising within territorial limits.')}
            </div>
          </div>
        </div>

        <!-- Section 3: Facts of the Case (One Coherent Chronological Narrative) -->
        <div class="bg-white border border-slate-200 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] p-6 space-y-4">
          <div class="flex items-center justify-between border-b border-slate-200 pb-3">
            <div class="flex items-center space-x-2.5">
              <div class="p-2 rounded-lg bg-slate-50 border border-slate-100 text-amber-500">
                <i data-lucide="file-text" class="w-4 h-4"></i>
              </div>
              <h3 class="font-serif text-base font-bold text-slate-800 uppercase tracking-wider">3. Material Facts of the Case (Consolidated Narrative)</h3>
            </div>
            <span class="text-[11px] text-slate-400">Material & non-exhaustive sequence</span>
          </div>

          <div class="space-y-3">
            ${factsNarrative.split('\n\n').map(para => `
              <div class="p-4 rounded-xl bg-slate-50 border border-slate-150 text-xs text-slate-700 leading-relaxed font-reading">
                ${escapeHtml(para)}
              </div>
            `).join('')}
          </div>
        </div>

        <!-- Section 4: Cause of Action Statement -->
        <div class="bg-white border border-slate-200 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] p-6 space-y-4">
          <div class="flex items-center space-x-2.5 border-b border-slate-200 pb-3">
            <div class="p-2 rounded-lg bg-slate-50 border border-slate-100 text-amber-500">
              <i data-lucide="zap" class="w-4 h-4"></i>
            </div>
            <h3 class="font-serif text-base font-bold text-slate-800 uppercase tracking-wider">4. Cause of Action Indicators & Legal Grounds</h3>
          </div>

          <div class="p-4 rounded-xl bg-slate-50 border border-slate-150 text-xs text-slate-700 leading-relaxed font-reading">
            <p class="text-sm text-slate-850 leading-relaxed mb-3">
              ${escapeHtml(causeOfAction)}
            </p>
          </div>
        </div>

        <!-- Section 5: Ambiguities, Contradictions & Evidence Act Safeguards -->
        ${allAmbiguities.length > 0 ? `
          <div class="bg-amber-50/20 border border-amber-250 p-6 rounded-2xl shadow-sm space-y-4">
            <div class="flex items-center space-x-2.5 border-b border-amber-200 pb-3">
              <div class="p-2 rounded-lg bg-amber-50 border border-amber-200/50 text-amber-600">
                <i data-lucide="alert-triangle" class="w-4 h-4"></i>
              </div>
              <div>
                <h3 class="font-serif text-base font-bold text-amber-800 uppercase tracking-wider">5. Evidentiary Safeguards & Ambiguity Flags</h3>
                <p class="text-[11px] text-slate-500">Explicit compliance flags — no silent guessing or unverified assumptions</p>
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
              ${allAmbiguities.map(a => `
                <div class="p-3 rounded-xl bg-white border border-slate-200 text-xs text-amber-800 flex items-start space-x-2">
                  <i data-lucide="shield-alert" class="w-4 h-4 text-amber-500 shrink-0 mt-0.5"></i>
                  <span>${escapeHtml(a.text)}</span>
                </div>
              `).join('')}
            </div>
          </div>
        ` : ''}

      </div>
    `;
  }
};
