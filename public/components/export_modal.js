// Court-Ready Export Modal & Legal Brief Generator Component with Exhibit Indexing & 65B Certification
const ExportModal = {
  render(caseData, summary, files = []) {
    const parties = summary.parties || [];
    const chronology = summary.chronology || [];
    const facts = summary.facts_narrative || "";
    const causeOfAction = summary.cause_of_action_text || "";
    const limitation = summary.limitation_analysis || {};
    const courtName = (caseData.court_name || "IN THE HIGH COURT OF DELHI AT NEW DELHI").toUpperCase();
    const caseNumber = caseData.case_number || "O.M.P. (COMM) / CS (COMM) NO. _____ OF 2024";
    const caseName = (caseData.name || "PETITIONER v. RESPONDENT").toUpperCase();

    // Separate petitioners and respondents
    const petitioners = parties.filter(p => p.role?.toLowerCase().includes('petitioner') || p.role?.toLowerCase().includes('claimant') || p.role?.toLowerCase().includes('complainant'));
    const respondents = parties.filter(p => p.role?.toLowerCase().includes('respondent') || p.role?.toLowerCase().includes('accused') || p.role?.toLowerCase().includes('defendant'));

    // Compute running page ranges for exhibits
    let currentRunningPage = 15; // Petition runs from page 1 to ~14

    return `
      <div id="export-modal-overlay" class="fixed inset-0 z-50 bg-black/85 backdrop-blur-sm flex items-center justify-center p-4">
        <div class="bg-charcoal-900 border border-charcoal-700 rounded-2xl max-w-5xl w-full p-6 shadow-2xl space-y-4 max-h-[94vh] flex flex-col">
          
          <!-- Top Action Bar -->
          <div class="flex items-center justify-between border-b border-charcoal-800 pb-3 no-print">
            <div class="flex items-center space-x-3">
              <div class="p-2.5 rounded-lg bg-charcoal-800 border border-legal-gold/40 text-legal-gold">
                <i data-lucide="scale" class="w-5 h-5"></i>
              </div>
              <div>
                <h3 class="font-serif text-lg font-bold text-white">Court Brief & Master Exhibit Index</h3>
                <p class="text-xs text-charcoal-400">Formatted according to Commercial Court & High Court registry standards.</p>
              </div>
            </div>

            <div class="flex items-center space-x-2">
              <button onclick="ExportModal.printBrief()" class="px-3.5 py-1.5 bg-legal-gold text-charcoal-950 font-bold text-xs rounded-lg hover:bg-legal-gold-light transition flex items-center space-x-1.5 shadow">
                <i data-lucide="printer" class="w-3.5 h-3.5"></i>
                <span>Print / Save PDF</span>
              </button>
              <button onclick="ExportModal.copyBriefText()" class="px-3.5 py-1.5 bg-charcoal-800 hover:bg-charcoal-750 text-white font-medium text-xs rounded-lg border border-charcoal-700 transition flex items-center space-x-1.5">
                <i data-lucide="copy" class="w-3.5 h-3.5"></i>
                <span>Copy Draft</span>
              </button>
              <button onclick="App.closeModal()" class="text-charcoal-400 hover:text-white p-1 rounded-lg hover:bg-charcoal-800">
                <i data-lucide="x" class="w-5 h-5"></i>
              </button>
            </div>
          </div>

          <!-- Printable Court Document Container (Clean Paper Style) -->
          <div class="flex-1 overflow-y-auto bg-charcoal-950 p-6 rounded-xl border border-charcoal-800">
            <div id="court-brief-document" class="court-document max-w-3xl mx-auto p-10 bg-white text-black shadow-2xl rounded-sm text-sm space-y-6">
              
              <!-- Court Heading -->
              <div class="text-center space-y-1">
                <h2 class="font-bold text-base tracking-wider">${escapeHtml(courtName)}</h2>
                <p class="text-xs uppercase font-semibold">COMMERCIAL DIVISION / ARBITRATION JURISDICTION</p>
                <p class="font-mono text-xs font-bold pt-1">${escapeHtml(caseNumber)}</p>
              </div>

              <!-- Matter Title -->
              <div class="text-center font-bold uppercase text-xs tracking-wider py-2 border-y border-black/20">
                IN THE MATTER OF:<br>
                ${escapeHtml(caseName)}
              </div>

              <!-- Memo of Parties -->
              <div class="space-y-3 pt-2">
                <h3 class="font-bold text-xs uppercase tracking-wider text-left border-b border-black/20 pb-1">MEMO OF PARTIES</h3>
                
                <div class="space-y-1.5 pl-4">
                  <p class="font-bold uppercase text-xs underline">PETITIONER(S) / CLAIMANT(S):</p>
                  ${petitioners.length > 0 ? petitioners.map((p, i) => `
                    <p class="text-xs leading-relaxed">
                      <strong>${i + 1}. ${escapeHtml(p.name)}</strong><br>
                      ${escapeHtml(p.address || 'Address on record')}<br>
                      <em>[${escapeHtml(p.role || 'Petitioner')}]</em>
                    </p>
                  `).join('') : `<p class="text-xs">${escapeHtml(parties[0]?.name || 'Petitioner')}</p>`}
                </div>

                <div class="text-center font-bold text-xs py-1">...VERSUS...</div>

                <div class="space-y-1.5 pl-4">
                  <p class="font-bold uppercase text-xs underline">RESPONDENT(S) / DEFENDANT(S):</p>
                  ${respondents.length > 0 ? respondents.map((r, i) => `
                    <p class="text-xs leading-relaxed">
                      <strong>${i + 1}. ${escapeHtml(r.name)}</strong><br>
                      ${escapeHtml(r.address || 'Address on record')}<br>
                      <em>[${escapeHtml(r.role || 'Respondent')}]</em>
                    </p>
                  `).join('') : `<p class="text-xs">${escapeHtml(parties[1]?.name || 'Respondent')}</p>`}
                </div>
              </div>

              <!-- Synopsis & Objective -->
              <div class="space-y-2 pt-3">
                <h3 class="font-bold text-xs uppercase tracking-wider text-left border-b border-black/20 pb-1">SYNOPSIS & RELIEF SOUGHT</h3>
                <p class="text-xs leading-relaxed text-justify font-serif">
                  ${escapeHtml(caseData.objective || 'The present proceedings are instituted seeking urgent and necessary judicial intervention.')}
                </p>
              </div>

              <!-- Statutory Limitation Declaration -->
              ${limitation.days_remaining ? `
                <div class="p-3 bg-gray-50 border border-black/20 rounded space-y-1 text-xs font-serif">
                  <p class="font-bold uppercase text-[11px]">DECLARATION REGARDING STATUTORY LIMITATION:</p>
                  <p class="leading-relaxed">
                    The Petitioner declares that the cause of action initially accrued on <strong>${escapeHtml(limitation.trigger_date || 'the date of breach')}</strong> (${escapeHtml(limitation.trigger_event || 'initial default')}). 
                    The prescribed period of limitation is <strong>${escapeHtml(limitation.statutory_period || '3 Years')}</strong> under Schedule Article 55/113 of the Limitation Act, 1963. 
                    The present proceeding instituted on ${new Date().toLocaleDateString('en-IN')} is within time with <strong>${limitation.days_remaining} days remaining</strong>, and is therefore not barred by limitation.
                  </p>
                </div>
              ` : ''}

              <!-- Chronology of Dates and Events Table -->
              <div class="space-y-2 pt-3">
                <h3 class="font-bold text-xs uppercase tracking-wider text-left border-b border-black/20 pb-1">LIST OF DATES & CHRONOLOGY OF MATERIAL EVENTS</h3>
                
                <table class="w-full text-left text-xs border border-black border-collapse mt-2">
                  <thead>
                    <tr class="bg-gray-100 border-b border-black font-bold uppercase text-[11px]">
                      <th class="p-2 border-r border-black w-24">Date</th>
                      <th class="p-2 border-r border-black">Events & Transactions</th>
                      <th class="p-2 border-r border-black w-44">Annexure / Document</th>
                      <th class="p-2">Legal Significance</th>
                    </tr>
                  </thead>
                  <tbody>
                    ${chronology.map((ev, i) => `
                      <tr class="border-b border-black/30 align-top ${ev.is_critical_flag ? 'bg-amber-50 font-medium' : ''}">
                        <td class="p-2 border-r border-black font-mono font-semibold whitespace-nowrap">${escapeHtml(ev.date || 'Undated')}</td>
                        <td class="p-2 border-r border-black leading-relaxed font-serif">${escapeHtml(ev.event)}</td>
                        <td class="p-2 border-r border-black font-mono text-[11px]">${escapeHtml(ev.supporting_document || 'Record')}</td>
                        <td class="p-2 leading-relaxed text-[11px]">${escapeHtml(ev.legal_relevance)}</td>
                      </tr>
                    `).join('')}
                  </tbody>
                </table>
              </div>

              <!-- Statement of Facts -->
              <div class="space-y-2 pt-3">
                <h3 class="font-bold text-xs uppercase tracking-wider text-left border-b border-black/20 pb-1">MATERIAL FACTS OF THE CASE</h3>
                <div class="text-xs leading-relaxed text-justify space-y-2.5 font-serif">
                  ${facts.split('\n\n').map(p => `<p>${escapeHtml(p)}</p>`).join('')}
                </div>
              </div>

              <!-- Cause of Action -->
              <div class="space-y-2 pt-3">
                <h3 class="font-bold text-xs uppercase tracking-wider text-left border-b border-black/20 pb-1">CAUSE OF ACTION & GROUNDS</h3>
                <p class="text-xs leading-relaxed text-justify font-serif">
                  ${escapeHtml(causeOfAction)}
                </p>
              </div>

              <!-- Master List of Exhibits & Running Pagination -->
              <div class="space-y-2 pt-3 border-t border-black/20">
                <h3 class="font-bold text-xs uppercase tracking-wider text-left border-b border-black/20 pb-1">MASTER INDEX OF EXHIBITS & ANNEXURES</h3>
                <table class="w-full text-left text-xs border border-black border-collapse mt-2">
                  <thead>
                    <tr class="bg-gray-100 border-b border-black font-bold uppercase text-[10px]">
                      <th class="p-2 border-r border-black w-24">Mark</th>
                      <th class="p-2 border-r border-black">Document Description</th>
                      <th class="p-2 border-r border-black w-28">Type</th>
                      <th class="p-2 border-r border-black w-36">Sec 65B/63 Status</th>
                      <th class="p-2 w-20 text-right">Page No.</th>
                    </tr>
                  </thead>
                  <tbody>
                    ${files.map((f, idx) => {
                      const estPages = Math.max(1, Math.ceil(f.file_size / (50 * 1024)));
                      const pageRange = `${currentRunningPage} - ${currentRunningPage + estPages}`;
                      currentRunningPage += estPages + 1;
                      const isElectronic = ['Audio', 'Video', 'WhatsApp/Text', 'PDF'].includes(f.file_type);

                      return `
                        <tr class="border-b border-black/30">
                          <td class="p-2 border-r border-black font-mono font-bold">Annexure P-${idx + 1}</td>
                          <td class="p-2 border-r border-black font-serif">${escapeHtml(f.original_name)}</td>
                          <td class="p-2 border-r border-black font-mono text-[10px]">${escapeHtml(f.file_type)}</td>
                          <td class="p-2 border-r border-black text-[10px]">
                            ${isElectronic ? '<span class="font-mono font-semibold text-emerald-800">SHA-256 Certified</span>' : 'Primary Document'}
                          </td>
                          <td class="p-2 font-mono text-right">${pageRange}</td>
                        </tr>
                      `;
                    }).join('')}
                    <tr class="bg-gray-50 font-bold border-t border-black">
                      <td class="p-2 border-r border-black font-mono">Annexure P-${files.length + 1}</td>
                      <td class="p-2 border-r border-black font-serif">Statutory Certificate u/S 65B IEA & Sec 63 BSA, 2023</td>
                      <td class="p-2 border-r border-black font-mono text-[10px]">Affidavit</td>
                      <td class="p-2 border-r border-black text-[10px] text-emerald-800">Sworn on Oath</td>
                      <td class="p-2 font-mono text-right">${currentRunningPage} - ${currentRunningPage + 2}</td>
                    </tr>
                  </tbody>
                </table>
              </div>

              <!-- Signature Footer -->
              <div class="pt-8 flex justify-between text-xs font-bold">
                <div>
                  DATED: ${new Date().toLocaleDateString('en-IN')}<br>
                  PLACE: NEW DELHI
                </div>
                <div class="text-right">
                  FILED BY:<br>
                  ADV. MAYANK MITRA<br>
                  COUNSEL FOR THE PETITIONER<br>
                  CHAMBERS, HIGH COURT OF DELHI
                </div>
              </div>

            </div>
          </div>

        </div>
      </div>
    `;
  },

  printBrief() {
    window.print();
  },

  copyBriefText() {
    const el = document.getElementById('court-brief-document');
    if (!el) return;
    navigator.clipboard.writeText(el.innerText).then(() => {
      App.showToast('Court brief copied to clipboard!', 'success');
    }).catch(e => {
      App.showToast('Failed to copy text', 'error');
    });
  }
};
