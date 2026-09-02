// Case Setup & Edit Modal Component
const CaseSetupModal = {
  render(caseData = null) {
    const isEdit = !!caseData;
    const title = isEdit ? "Edit Case Context & Setup" : "Create New Legal Case";
    const name = caseData ? caseData.name : "";
    const caseNumber = caseData ? caseData.case_number || "" : "";
    const courtName = caseData ? caseData.court_name || "High Court of Delhi" : "High Court of Delhi";
    const objective = caseData ? caseData.objective || "" : "";
    const partiesInfo = caseData ? caseData.parties_info || "" : "";
    const hearingDate = caseData ? caseData.hearing_date || "" : "";
    const tier = caseData ? caseData.tier || "pro" : "pro";

    return `
      <div id="setup-modal-overlay" class="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 overflow-y-auto">
        <div class="bg-charcoal-900 border border-charcoal-700 rounded-2xl max-w-2xl w-full p-6 shadow-2xl space-y-6 relative my-8">
          
          <!-- Header -->
          <div class="flex items-start justify-between border-b border-charcoal-800 pb-4">
            <div class="flex items-center space-x-3">
              <div class="p-2.5 rounded-lg bg-charcoal-800 border border-legal-gold/30 text-legal-gold">
                <i data-lucide="folder-plus" class="w-5 h-5"></i>
              </div>
              <div>
                <h2 class="font-serif text-xl font-bold text-white">${title}</h2>
                <p class="text-xs text-charcoal-400">Context provided here is shared across all AI extractions for this case.</p>
              </div>
            </div>
            <button onclick="App.closeModal()" class="text-charcoal-400 hover:text-white p-1 rounded-lg hover:bg-charcoal-800">
              <i data-lucide="x" class="w-5 h-5"></i>
            </button>
          </div>

          <!-- Form -->
          <form id="case-setup-form" onsubmit="App.handleSaveCase(event, ${isEdit ? `'${caseData.id}'` : 'null'})" class="space-y-5">
            
            <!-- Basic Meta Grid -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold uppercase tracking-wider text-charcoal-300 mb-1.5">Case Title / Matter Name *</label>
                <input type="text" name="name" value="${escapeHtml(name)}" required placeholder="e.g. Apex Infra v. Delhi Metro Real Estate" 
                  class="w-full bg-charcoal-850 border border-charcoal-700 rounded-lg px-3.5 py-2 text-sm text-white focus:outline-none focus:border-legal-gold transition">
              </div>
              <div>
                <label class="block text-xs font-semibold uppercase tracking-wider text-charcoal-300 mb-1.5">Case / Petition No.</label>
                <input type="text" name="case_number" value="${escapeHtml(caseNumber)}" placeholder="e.g. OMP (COMM) 342/2024" 
                  class="w-full bg-charcoal-850 border border-charcoal-700 rounded-lg px-3.5 py-2 text-sm text-white focus:outline-none focus:border-legal-gold transition">
              </div>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div>
                <label class="block text-xs font-semibold uppercase tracking-wider text-charcoal-300 mb-1.5">Court / Tribunal / Forum</label>
                <input type="text" name="court_name" value="${escapeHtml(courtName)}" placeholder="e.g. High Court of Delhi / NCLT" 
                  class="w-full bg-charcoal-850 border border-charcoal-700 rounded-lg px-3.5 py-2 text-sm text-white focus:outline-none focus:border-legal-gold transition">
              </div>
              <div>
                <label class="block text-xs font-semibold uppercase tracking-wider text-charcoal-300 mb-1.5">Next Hearing / Diary Date</label>
                <input type="date" name="hearing_date" value="${escapeHtml(hearingDate)}" 
                  class="w-full bg-charcoal-850 border border-charcoal-700 rounded-lg px-3.5 py-2 text-sm text-white focus:outline-none focus:border-legal-gold transition">
              </div>
            </div>

            <!-- Core Setup Field 1: Case Objective -->
            <div class="space-y-1.5">
              <div class="flex items-center justify-between">
                <label class="block text-xs font-bold uppercase tracking-wider text-legal-gold flex items-center gap-1.5">
                  <i data-lucide="target" class="w-3.5 h-3.5"></i>
                  1. Case Objective (Free Text)
                </label>
                <div class="flex justify-between items-center mt-2">
                  <span class="text-[11px] text-charcoal-400">Editable later & re-used for AI extraction</span>
                </div>
              </div>
              <p class="text-xs text-charcoal-400 italic">"What is this case about, and what outcome are you seeking?"</p>
              <textarea name="objective" rows="3" placeholder="e.g. Urgent Section 9 petition seeking ad-interim injunction against wrongful invocation of Bank Guarantees worth ₹14.5 Cr and specific performance of EPC contract milestones..."
                class="w-full bg-charcoal-850 border border-charcoal-700 rounded-lg p-3 text-sm text-white focus:outline-none focus:border-legal-gold transition">${escapeHtml(objective)}</textarea>
            </div>

            <!-- Core Setup Field 2: Case & Parties Information -->
            <div class="space-y-1.5">
              <div class="flex items-center justify-between">
                <label class="block text-xs font-bold uppercase tracking-wider text-legal-gold flex items-center gap-1.5">
                  <i data-lucide="users" class="w-3.5 h-3.5"></i>
                  2. Case & Parties Information (Free Text)
                </label>
                <span class="text-[11px] text-charcoal-400">Open-ended context</span>
              </div>
              <p class="text-xs text-charcoal-400 italic">"Share whatever you know about the parties involved — names, roles (petitioner, respondent, witness, accused), relationships, and any relevant background."</p>
              <textarea name="parties_info" rows="4" placeholder="e.g. Petitioner: M/s Apex Infrastructure Ltd. (EPC Contractor, MD Rajeshwar Sharma). Respondent: Delhi Metro Real Estate Pvt. Ltd. (Developer, MD Vikramaditya Singhania). Third party architect: Ar. Sunil Bhasin..."
                class="w-full bg-charcoal-850 border border-charcoal-700 rounded-lg p-3 text-sm text-white focus:outline-none focus:border-legal-gold transition">${escapeHtml(partiesInfo)}</textarea>
            </div>

            <!-- Storage Capacity Tiering -->
            <div class="p-3.5 rounded-xl bg-charcoal-850 border border-charcoal-700 flex items-center justify-between">
              <div>
                <p class="text-xs font-bold text-white uppercase tracking-wider">Storage & Evidence Tier</p>
                <p class="text-xs text-charcoal-400">Pro tier supports up to 4GB mixed-format evidence per case</p>
              </div>
              <select name="tier" class="bg-charcoal-800 border border-charcoal-600 rounded-lg px-3 py-1.5 text-xs text-legal-gold font-semibold focus:outline-none">
                <option value="pro" ${tier === 'pro' ? 'selected' : ''}>Pro Tier (4 GB Max / 100 Files)</option>
                <option value="basic" ${tier === 'basic' ? 'selected' : ''}>Basic Tier (500 MB Max / 10 Files)</option>
              </select>
            </div>

            <!-- Action Buttons -->
            <div class="flex items-center justify-end space-x-3 pt-3 border-t border-charcoal-800">
              <button type="button" onclick="App.closeModal()" class="px-4 py-2 rounded-lg bg-charcoal-800 text-charcoal-300 text-sm font-medium hover:bg-charcoal-700 transition">Cancel</button>
              <button type="submit" class="px-5 py-2 rounded-lg bg-legal-gold text-charcoal-950 font-bold text-sm hover:bg-legal-gold-light transition shadow-lg flex items-center space-x-2">
                <i data-lucide="check" class="w-4 h-4"></i>
                <span>${isEdit ? "Update Case Context" : "Initialize Case"}</span>
              </button>
            </div>

          </form>

        </div>
      </div>
    `;
  }
};
