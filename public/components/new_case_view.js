// Dedicated New Case Creation View Component
const NewCaseView = {
  render() {
    return `
      <div class="max-w-4xl mx-auto space-y-6 animate-fadeIn">
        
        <!-- Header Banner (Clean Light Style) -->
        <div class="bg-white border border-slate-200 p-6 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-2 relative overflow-hidden">
          <div class="flex items-center space-x-2">
            <span class="px-2.5 py-0.5 rounded-full bg-amber-50 text-amber-600 border border-amber-200/50 text-[10px] font-bold uppercase tracking-wider">
              Litigation Onboarding • Feature 1
            </span>
            <span class="text-xs text-slate-400">Multi-Modal AI Ingestion</span>
          </div>
          <h2 class="font-serif text-2xl font-bold text-slate-900 tracking-wide">Create New Case & Evidence Vault</h2>
          <p class="text-xs text-slate-500 max-w-2xl leading-relaxed">
            Provide the foundational case objective and party details. This shared context guides all multi-modal evidence extractions, timeline synthesis, and fact reconciliation for up to 4GB of evidence.
          </p>
        </div>

        <!-- Main Form Card (Neat & Clean White Card) -->
        <div class="bg-white border border-slate-200 p-8 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-6">
          
          <form id="new-case-full-form" onsubmit="App.handleCreateNewCase(event)" class="space-y-6">
            
            <!-- Basic Meta Row -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
              <div class="space-y-1.5">
                <label class="block text-xs font-bold uppercase tracking-wider text-slate-700">
                  Case Title / Matter Name <span class="text-amber-500">*</span>
                </label>
                <input type="text" name="name" required placeholder="e.g. Apex Infrastructure Ltd. v. Delhi Metro Real Estate" 
                  class="w-full bg-slate-50 border border-slate-200 rounded-xl px-4 py-2.5 text-sm text-slate-800 focus:outline-none focus:border-amber-500 transition shadow-inner">
                <p class="text-[11px] text-slate-400">Formal title of the dispute or petition.</p>
              </div>

              <div class="space-y-1.5">
                <label class="block text-xs font-bold uppercase tracking-wider text-slate-700">
                  Target Court / Tribunal / Forum <span class="text-amber-500">*</span>
                </label>
                <select name="court_name" class="w-full bg-slate-50 border border-slate-200 rounded-xl px-4 py-2.5 text-sm text-slate-700 focus:outline-none focus:border-amber-500 transition shadow-inner">
                  <option value="High Court of Delhi at New Delhi">High Court of Delhi at New Delhi</option>
                  <option value="Supreme Court of India, New Delhi">Supreme Court of India, New Delhi</option>
                  <option value="High Court of Judicature at Bombay">High Court of Judicature at Bombay</option>
                  <option value="National Company Law Tribunal (NCLT)">National Company Law Tribunal (NCLT)</option>
                  <option value="National Company Law Appellate Tribunal (NCLAT)">National Company Law Appellate Tribunal (NCLAT)</option>
                  <option value="Saket District Courts, New Delhi">Saket District Courts, New Delhi</option>
                  <option value="Patiala House Courts, New Delhi">Patiala House Courts, New Delhi</option>
                  <option value="City Civil Court, Bengaluru">City Civil Court, Bengaluru</option>
                  <option value="Commercial Court / Arbitral Tribunal">Commercial Court / Arbitral Tribunal</option>
                </select>
                <p class="text-[11px] text-slate-400">Jurisdiction forum for statutory assessment.</p>
              </div>
            </div>

            <!-- Core Setup Field 1: Case Objective -->
            <div class="space-y-2 bg-slate-50 p-5 rounded-2xl border border-slate-100">
              <div class="flex items-center justify-between">
                <label class="block text-xs font-bold uppercase tracking-wider text-amber-600 flex items-center gap-2">
                  <i data-lucide="target" class="w-4 h-4"></i>
                  1. Case Objective (Free Text)
                </label>
                <span class="text-[10px] text-slate-400 font-mono bg-slate-200 px-2 py-0.5 rounded">Editable anytime</span>
              </div>
              <p class="text-xs text-slate-500 italic font-reading">
                "What is this case about, and what outcome are you seeking?"
              </p>
              <textarea name="objective" rows="3" required placeholder="e.g. Urgent Section 9 petition seeking ad-interim injunction restraining the Respondent from invoking Performance Bank Guarantees worth ₹14.5 Crores, and restraining creation of third-party encumbrances over Skyline Corporate Tower, Sector 62..."
                class="w-full bg-white border border-slate-200 rounded-xl p-3.5 text-sm text-slate-800 focus:outline-none focus:border-amber-500 transition shadow-inner font-sans leading-relaxed"></textarea>
            </div>

            <!-- Core Setup Field 2: Case & Parties Information -->
            <div class="space-y-2 bg-slate-50 p-5 rounded-2xl border border-slate-100">
              <div class="flex items-center justify-between">
                <label class="block text-xs font-bold uppercase tracking-wider text-amber-600 flex items-center gap-2">
                  <i data-lucide="users" class="w-4 h-4"></i>
                  2. Case & Parties Information (Free Text)
                </label>
                <span class="text-[10px] text-slate-400 font-mono bg-slate-200 px-2 py-0.5 rounded">Open-ended context</span>
              </div>
              <p class="text-xs text-slate-500 italic font-reading">
                "Share whatever you know about the parties involved — names, roles (petitioner, respondent, witness, accused), relationships, and any relevant background."
              </p>
              <textarea name="parties_info" rows="4" required placeholder="e.g. Petitioner: M/s Apex Infrastructure Ltd. (EPC Contractor, Registered Office: Connaught Place, New Delhi, MD Rajeshwar Sharma). Respondent: Delhi Metro Real Estate Pvt. Ltd. (Developer, MD Vikramaditya Singhania). Third party architect: Ar. Sunil Bhasin..."
                class="w-full bg-white border border-slate-200 rounded-xl p-3.5 text-sm text-slate-800 focus:outline-none focus:border-amber-500 transition shadow-inner font-sans leading-relaxed"></textarea>
            </div>

            <!-- Multi-Modal Evidence Upload Dropzone (Optional Initial Upload up to 4GB) -->
            <div class="space-y-2">
              <label class="block text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-2">
                <i data-lucide="upload-cloud" class="w-4 h-4 text-amber-500"></i>
                Initial Evidence Ingestion (Up to 4GB, Mixed Formats)
              </label>
              <div class="border-2 border-dashed border-slate-200 hover:border-amber-500 rounded-2xl p-6 text-center transition cursor-pointer bg-slate-50 flex flex-col items-center justify-center space-y-3"
                   onclick="document.getElementById('new-case-files').click()">
                <input type="file" id="new-case-files" multiple class="hidden" 
                       accept=".pdf,.jpg,.jpeg,.png,.webp,.txt,.mp3,.wav,.m4a,.mp4,.mov,.docx,.zip"
                       onchange="NewCaseView.handleFilesPicked(this)">
                
                <div class="w-12 h-12 rounded-xl bg-slate-100 border border-slate-200 flex items-center justify-center text-slate-500">
                  <i data-lucide="folder-up" class="w-6 h-6"></i>
                </div>
                <div>
                  <p class="text-xs font-semibold text-slate-700">Attach mixed-format evidence files</p>
                  <p class="text-[11px] text-slate-400">PDF contracts, WhatsApp exports (.txt), Site photos, Audio/Video transcripts</p>
                </div>
                <div id="file-selection-badge" class="hidden text-xs font-mono text-amber-600 font-semibold bg-amber-50 px-3 py-1 rounded-full border border-amber-200">
                  0 files selected
                </div>
              </div>
            </div>

            <!-- Hearing Date & Storage Capacity Tier Row -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div class="p-4 rounded-xl bg-slate-50 border border-slate-200 space-y-1">
                <label class="block text-xs font-bold uppercase tracking-wider text-slate-700">Next Hearing Date (Manual Tracker)</label>
                <input type="date" name="hearing_date" class="w-full bg-white border border-slate-200 rounded-lg px-3 py-2 text-xs text-slate-800 focus:outline-none focus:border-amber-500 transition">
              </div>

              <div class="p-4 rounded-xl bg-slate-50 border border-slate-200 space-y-1">
                <label class="block text-xs font-bold uppercase tracking-wider text-slate-700">Storage & Evidence Limit</label>
                <select name="tier" class="w-full bg-white border border-slate-200 rounded-lg px-3 py-2 text-xs text-amber-600 font-semibold focus:outline-none">
                  <option value="pro">Enterprise Pro (4.0 GB / 100 Files)</option>
                  <option value="basic">Basic Tier (500 MB / 10 Files)</option>
                </select>
              </div>
            </div>

            <!-- Action Buttons -->
            <div class="flex items-center justify-end space-x-4 pt-4 border-t border-slate-200">
              <button type="button" onclick="App.navigate('dashboard')" class="px-5 py-2.5 rounded-xl bg-slate-100 text-slate-700 text-xs font-semibold hover:bg-slate-200 transition">
                Cancel
              </button>
              <button type="submit" class="px-6 py-2.5 rounded-xl bg-gradient-gold text-slate-950 font-bold text-xs hover:brightness-105 transition shadow-lg shadow-amber-500/15 flex items-center space-x-2">
                <i data-lucide="sparkles" class="w-4 h-4"></i>
                <span>Initialize Case & Start AI Ingestion</span>
              </button>
            </div>

          </form>

        </div>

      </div>
    `;
  },

  handleFilesPicked(input) {
    const badge = document.getElementById('file-selection-badge');
    if (input.files.length > 0) {
      badge.textContent = `${input.files.length} evidence file(s) selected (${Array.from(input.files).map(f => f.name).join(', ')})`;
      badge.classList.remove('hidden');
    } else {
      badge.classList.add('hidden');
    }
  }
};
