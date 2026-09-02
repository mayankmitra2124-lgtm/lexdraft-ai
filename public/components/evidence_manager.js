// Evidence Ingestion & Pipeline Manager Component (4GB Multi-format Pipeline)
const EvidenceManager = {
  render(caseData, files = []) {
    const totalFiles = files.length;
    const totalSizeFormatted = caseData.total_size_formatted || "0 B";
    const maxStorageFormatted = caseData.max_storage_formatted || "4.0 GB";
    const usagePct = caseData.storage_usage_pct || 0;
    const isBasicTier = caseData.tier === 'basic';

    return `
      <div class="space-y-8 animate-fadeIn">
        
        <!-- Storage Quota & Capacity Tier Bar -->
        <div class="bg-white border border-slate-200 p-6 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-4">
          <div class="flex flex-col md:flex-row md:items-center justify-between gap-3">
            <div class="space-y-1">
              <div class="flex items-center space-x-2">
                <span class="px-2.5 py-0.5 rounded bg-slate-50 border border-slate-200 text-slate-700 text-[10px] font-bold uppercase tracking-wider">
                  ${isBasicTier ? 'Basic Tier (500 MB Cap)' : 'Enterprise Pro Tier (4.0 GB Cap)'}
                </span>
                <span class="text-xs text-slate-400 font-sans">Object Storage Pipeline</span>
              </div>
              <h3 class="font-serif text-lg font-bold text-slate-850">Case Evidence Vault & Ingestion</h3>
            </div>

            <!-- Storage Meter Numbers -->
            <div class="text-right">
              <p class="text-sm font-mono font-bold text-slate-800">${totalSizeFormatted} <span class="text-xs text-slate-400 font-sans">used of</span> ${maxStorageFormatted}</p>
              <p class="text-xs text-slate-400">${totalFiles} / ${caseData.max_files || 100} files uploaded</p>
            </div>
          </div>

          <!-- Progress Bar -->
          <div class="w-full bg-slate-100 rounded-full h-2 overflow-hidden border border-slate-200">
            <div class="bg-gradient-gold h-2 rounded-full transition-all duration-500" style="width: ${Math.min(usagePct, 100)}%"></div>
          </div>
        </div>

        <!-- Drag and Drop Ingestion Dropzone & Manual Paste Options -->
        <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
          
          <!-- File Dropzone (Left 2 Cols) -->
          <div class="lg:col-span-2 bg-white border-2 border-dashed border-slate-200 hover:border-amber-500 p-8 rounded-2xl text-center transition cursor-pointer group flex flex-col items-center justify-center space-y-4"
               onclick="document.getElementById('evidence-file-input').click()"
               ondragover="event.preventDefault(); this.classList.add('border-amber-500')"
               ondragleave="this.classList.remove('border-amber-500')"
               ondrop="EvidenceManager.handleDrop(event, '${caseData.id}')">
            
            <input type="file" id="evidence-file-input" multiple class="hidden" 
                   accept=".pdf,.jpg,.jpeg,.png,.webp,.txt,.mp3,.wav,.m4a,.mp4,.mov,.docx,.zip"
                   onchange="EvidenceManager.handleFileSelect(event, '${caseData.id}')">
            
            <div class="w-16 h-16 rounded-2xl bg-slate-50 border border-slate-200 flex items-center justify-center text-amber-500 group-hover:scale-110 transition shadow-inner">
              <i data-lucide="upload-cloud" class="w-8 h-8"></i>
            </div>

            <div class="space-y-1 max-w-md">
              <h4 class="font-serif text-base font-bold text-slate-800 group-hover:text-amber-600 transition">Upload Case Evidence (Up to 4GB)</h4>
              <p class="text-xs text-slate-400">Drag & drop multiple files or click to browse. PDFs, WhatsApp chat exports (.txt), Site Photos, Bank Memos, Audio/Video recordings.</p>
            </div>

            <div class="flex flex-wrap items-center justify-center gap-2 pt-2">
              <span class="px-2 py-0.5 rounded bg-slate-50 text-slate-600 text-[10px] font-mono border border-slate-200">PDFs</span>
              <span class="px-2 py-0.5 rounded bg-slate-50 text-slate-600 text-[10px] font-mono border border-slate-200">WhatsApp (.txt)</span>
              <span class="px-2 py-0.5 rounded bg-slate-50 text-slate-600 text-[10px] font-mono border border-slate-200">Images (JPEG/PNG)</span>
              <span class="px-2 py-0.5 rounded bg-slate-50 text-slate-600 text-[10px] font-mono border border-slate-200">Audio (.mp3/.m4a)</span>
              <span class="px-2 py-0.5 rounded bg-slate-50 text-slate-600 text-[10px] font-mono border border-slate-200">Video (.mp4)</span>
            </div>

          </div>

          <!-- Quick Paste Text / WhatsApp Export Box (Right 1 Col) -->
          <div class="bg-white border border-slate-200 p-5 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-3 flex flex-col justify-between">
            <div class="space-y-2">
              <div class="flex items-center space-x-2">
                <i data-lucide="clipboard-copy" class="w-4 h-4 text-amber-500"></i>
                <h4 class="font-serif text-sm font-bold text-slate-800">Quick Paste Electronic Evidence</h4>
              </div>
              <p class="text-[11px] text-slate-400">Paste raw WhatsApp transcripts, email chains, or statutory notice text directly.</p>
              
              <input type="text" id="paste-filename-input" placeholder="Document Name (e.g. WhatsApp_Chat_Aug2024.txt)" 
                     class="w-full bg-slate-50 border border-slate-200 rounded-lg px-3 py-1.5 text-xs text-slate-800 placeholder-slate-400 focus:outline-none focus:border-amber-500">
              
              <textarea id="paste-content-input" rows="4" placeholder="[14/08/2024, 15:30:12] Advocate: Please release payment..." 
                        class="w-full bg-slate-50 border border-slate-200 rounded-lg p-2.5 text-xs text-slate-800 placeholder-slate-400 focus:outline-none focus:border-amber-500 font-sans"></textarea>
            </div>

            <button onclick="EvidenceManager.handleDirectPaste('${caseData.id}')" class="w-full py-2 bg-slate-50 hover:bg-slate-100 border border-slate-200 text-amber-600 text-xs font-bold rounded-lg transition flex items-center justify-center space-x-2">
              <i data-lucide="plus-circle" class="w-4 h-4"></i>
              <span>Queue Pasted Evidence</span>
            </button>
          </div>

        </div>

        <!-- Live Evidence Files Queue & Status List -->
        <div class="bg-white border border-slate-200 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] overflow-hidden space-y-4">
          <div class="p-4 bg-slate-50 border-b border-slate-200 flex items-center justify-between">
            <div class="flex items-center space-x-2.5">
              <i data-lucide="layers" class="w-4 h-4 text-amber-500"></i>
              <h3 class="font-serif text-sm font-bold text-slate-800 uppercase tracking-wider">Ingested Files & Live Extraction Status</h3>
            </div>
            <span class="text-xs text-slate-450 font-mono">${files.length} Total Registered Files</span>
          </div>

          <div class="divide-y divide-slate-100 p-2">
            ${files.length === 0 ? `
              <p class="text-xs text-slate-400 text-center py-8">No files uploaded for this case yet.</p>
            ` : files.map(f => EvidenceManager.renderFileRow(f, caseData.id)).join('')}
          </div>
        </div>

      </div>
    `;
  },

  renderFileRow(f, caseId) {
    const status = f.status;
    const isProcessing = status === 'Processing';
    const isComplete = status === 'Complete';
    const isFailed = status === 'Failed';
    const isCritical = f.is_critical_evidence === 1;
    const chunks = f.chunks || [];

    return `
      <div class="p-4 rounded-xl hover:bg-slate-50/50 transition space-y-3 ${isCritical ? 'critical-evidence-border bg-amber-50/10' : ''}">
        
        <!-- Top File Info Line -->
        <div class="flex flex-col md:flex-row md:items-center justify-between gap-2">
          
          <div class="flex items-center space-x-3">
            <div class="p-2.5 rounded-lg bg-slate-50 border border-slate-200 text-amber-500">
              <i data-lucide="${EvidenceManager.getFileIcon(f.file_type)}" class="w-5 h-5"></i>
            </div>
            <div>
              <div class="flex items-center space-x-2">
                <span class="text-sm font-bold text-slate-800">${escapeHtml(f.original_name)}</span>
                <span class="px-2 py-0.5 rounded bg-slate-50 text-slate-600 font-mono text-[10px] border border-slate-200">${f.file_type}</span>
                ${(f.file_type === 'Audio' || f.file_type === 'Video') && f.transcript ? `<span class="px-2 py-0.5 rounded bg-emerald-50 text-emerald-700 text-[10px] font-bold border border-emerald-200 flex items-center gap-1"><i data-lucide="mic" class="w-3 h-3"></i>ASR TRANSCRIBED</span>` : ''}
                ${isCritical ? `<span class="px-2 py-0.5 rounded bg-amber-500 text-slate-950 text-[10px] font-bold">CRITICAL EVIDENCE</span>` : ''}
              </div>
              <p class="text-xs text-slate-455 flex items-center gap-2 mt-0.5 font-sans">
                <span>${formatBytes(f.file_size)}</span>
                <span>•</span>
                <span>Uploaded ${formatTimeAgo(f.uploaded_at)}</span>
                ${chunks.length > 1 ? `<span>•</span><span class="text-amber-600 font-mono">${chunks.length} Chunks (10-15m segments)</span>` : ''}
              </p>
            </div>
          </div>

          <!-- Status & Actions -->
          <div class="flex items-center space-x-3">
            
            <!-- Live Status Pill -->
            <div class="flex items-center space-x-2">
              ${isProcessing ? `
                <span class="px-2.5 py-1 rounded-full bg-amber-50 text-amber-600 border border-amber-200/50 text-xs font-bold flex items-center space-x-1.5 animate-pulse">
                  <i data-lucide="loader-2" class="w-3.5 h-3.5 animate-spin"></i>
                  <span>Processing (${f.progress || 50}%)</span>
                </span>
              ` : isComplete ? `
                <span class="px-2.5 py-1 rounded-full bg-emerald-50 text-emerald-600 border border-emerald-200/50 text-xs font-bold flex items-center space-x-1.5">
                  <i data-lucide="check-circle" class="w-3.5 h-3.5"></i>
                  <span>Complete</span>
                </span>
              ` : isFailed ? `
                <span class="px-2.5 py-1 rounded-full bg-rose-50 text-rose-600 border border-rose-200/50 text-xs font-bold flex items-center space-x-1.5">
                  <i data-lucide="alert-circle" class="w-3.5 h-3.5"></i>
                  <span>Failed</span>
                </span>
              ` : `
                <span class="px-2.5 py-1 rounded-full bg-slate-50 text-slate-655 border border-slate-200 text-xs font-semibold">
                  Queued
                </span>
              `}
            </div>

            <!-- Action Buttons -->
            <div class="flex items-center space-x-2">
              ${(f.transcript || f.file_type === 'Audio' || f.file_type === 'Video') ? `
                <button onclick="App.openSourceViewer('${f.id}', 'Speech-to-Text Verbatim Transcript')" class="p-1.5 rounded-lg bg-amber-50 hover:bg-amber-100 text-amber-700 border border-amber-200 text-xs font-semibold flex items-center space-x-1 transition" title="Inspect Speech-to-Text (ASR) Transcript & Player">
                  <i data-lucide="play" class="w-3.5 h-3.5 text-amber-600"></i>
                  <span class="hidden sm:inline">Play & ASR</span>
                </button>
              ` : ''}

              <button onclick="SourceViewerModal.showCertificate('${caseId}', '${f.id}')" class="p-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-700 border border-emerald-200 text-xs font-semibold flex items-center space-x-1 transition" title="Export Section 65B / 63 Electronic Evidence Certificate">
                <i data-lucide="shield-check" class="w-3.5 h-3.5 text-emerald-600"></i>
                <span class="hidden sm:inline">Sec 65B Cert</span>
              </button>

              ${f.has_extraction ? `
                <button onclick="EvidenceManager.viewRawExtraction('${caseId}', '${f.id}')" class="p-1.5 rounded-lg bg-slate-50 hover:bg-slate-100 text-slate-700 hover:text-slate-800 border border-slate-200 text-xs font-semibold flex items-center space-x-1 transition" title="Inspect Structured JSON Extraction">
                  <i data-lucide="code" class="w-4 h-4 text-amber-500"></i>
                  <span class="hidden sm:inline">JSON</span>
                </button>
              ` : ''}

              ${isFailed ? `
                <button onclick="EvidenceManager.retryFile('${f.id}')" class="p-1.5 rounded-lg bg-slate-50 hover:bg-slate-100 text-amber-600 border border-slate-200 text-xs font-semibold flex items-center space-x-1 transition" title="Retry Processing">
                  <i data-lucide="rotate-cw" class="w-4 h-4"></i>
                  <span>Retry</span>
                </button>
              ` : ''}

              <button onclick="EvidenceManager.deleteFile('${caseId}', '${f.id}')" class="p-1.5 rounded-lg bg-slate-50 hover:bg-rose-50 text-slate-500 hover:text-rose-600 border border-slate-200 hover:border-rose-200 transition" title="Remove File">
                <i data-lucide="trash-2" class="w-4 h-4"></i>
              </button>
            </div>

          </div>

        </div>

        <!-- Processing Progress Bar if In-Flight -->
        ${isProcessing ? `
          <div class="w-full bg-slate-100 rounded-full h-1.5 overflow-hidden">
            <div class="bg-amber-500 h-1.5 rounded-full transition-all duration-300" style="width: ${f.progress || 40}%"></div>
          </div>
        ` : ''}

        <!-- One-line Summary Snippet if extracted -->
        ${f.file_summary ? `
          <div class="bg-slate-50 rounded-lg p-2.5 border border-slate-150 text-xs text-slate-600 italic font-reading">
            "${escapeHtml(f.file_summary)}"
          </div>
        ` : ''}

        <!-- Error Message if failed -->
        ${f.error_message ? `
          <div class="p-2.5 rounded-lg bg-rose-50 border border-rose-200 text-xs text-rose-600">
            <strong>Error:</strong> ${escapeHtml(f.error_message)}
          </div>
        ` : ''}

      </div>
    `;
  },

  getFileIcon(type) {
    switch (type) {
      case 'PDF': return 'file-text';
      case 'Image': return 'image';
      case 'Audio': return 'mic';
      case 'Video': return 'video';
      case 'WhatsApp/Text': return 'message-square';
      default: return 'file';
    }
  },

  handleDrop(e, caseId) {
    e.preventDefault();
    e.currentTarget.classList.remove('border-amber-500');
    const files = e.dataTransfer.files;
    if (files.length > 0) {
      EvidenceManager.uploadFiles(caseId, files);
    }
  },

  handleFileSelect(e, caseId) {
    const files = e.target.files;
    if (files.length > 0) {
      EvidenceManager.uploadFiles(caseId, files);
    }
  },

  async uploadFiles(caseId, files) {
    const formData = new FormData();
    for (let i = 0; i < files.length; i++) {
      formData.append('files', files[i]);
    }

    App.showToast(`Uploading ${files.length} evidence file(s)...`, 'info');

    try {
      const res = await fetch(`/api/cases/${caseId}/evidence`, {
        method: 'POST',
        body: formData
      });

      const data = await res.json();
      if (res.ok) {
        App.showToast(`Successfully queued ${files.length} file(s) for AI extraction.`, 'success');
        App.refreshCaseData(caseId);
      } else {
        App.showToast(data.error || 'Upload error', 'error');
      }
    } catch (e) {
      App.showToast(`Network or upload failure: ${e.message}`, 'error');
    }
  },

  async handleDirectPaste(caseId) {
    const nameInput = document.getElementById('paste-filename-input');
    const contentInput = document.getElementById('paste-content-input');
    
    const filename = nameInput.value.trim() || `Electronic_Evidence_${Date.now()}.txt`;
    const content = contentInput.value.trim();

    if (!content) {
      App.showToast('Please paste or type evidence text.', 'warning');
      return;
    }

    try {
      const res = await fetch(`/api/cases/${caseId}/evidence`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename, content, file_type: 'WhatsApp/Text' })
      });

      if (res.ok) {
        App.showToast(`Queued '${filename}' for AI extraction.`, 'success');
        nameInput.value = '';
        contentInput.value = '';
        App.refreshCaseData(caseId);
      } else {
        const d = await res.json();
        App.showToast(d.error || 'Failed to queue evidence', 'error');
      }
    } catch (e) {
      App.showToast(`Error: ${e.message}`, 'error');
    }
  },

  async retryFile(fileId) {
    try {
      const res = await fetch(`/api/files/${fileId}/retry`, { method: 'POST' });
      if (res.ok) {
        App.showToast('Extraction pipeline re-triggered.', 'info');
        App.refreshCurrentView();
      }
    } catch (e) {
      App.showToast(`Retry failed: ${e.message}`, 'error');
    }
  },

  async deleteFile(caseId, fileId) {
    if (!confirm('Are you sure you want to remove this evidence file? The master summary will be re-aggregated.')) return;
    try {
      const res = await fetch(`/api/files/${fileId}`, { method: 'DELETE' });
      if (res.ok) {
        App.showToast('File removed and summary re-aggregated.', 'info');
        App.refreshCaseData(caseId);
      }
    } catch (e) {
      App.showToast(`Delete failed: ${e.message}`, 'error');
    }
  },

  async viewRawExtraction(caseId, fileId) {
    try {
      const res = await fetch(`/api/cases/${caseId}/extractions/${fileId}`);
      const data = await res.json();
      
      const modalHtml = `
        <div id="json-modal-overlay" class="fixed inset-0 z-50 bg-black/50 backdrop-blur-sm flex items-center justify-center p-4">
          <div class="bg-white border border-slate-200 max-w-3xl w-full p-6 rounded-2xl shadow-2xl space-y-4 max-h-[85vh] flex flex-col">
            <div class="flex items-center justify-between border-b border-slate-200 pb-3">
              <div class="flex items-center space-x-2">
                <i data-lucide="code" class="w-5 h-5 text-amber-500"></i>
                <h3 class="font-serif text-base font-bold text-slate-800">Structured Legal JSON Extraction</h3>
              </div>
              <button onclick="App.closeModal()" class="text-slate-400 hover:text-slate-600"><i data-lucide="x" class="w-5 h-5"></i></button>
            </div>
            <div class="flex-1 overflow-y-auto bg-slate-50 p-4 rounded-xl border border-slate-200">
              <pre class="text-xs font-mono text-emerald-700 whitespace-pre-wrap">${escapeHtml(JSON.stringify(data, null, 2))}</pre>
            </div>
            <div class="flex justify-end pt-2">
              <button onclick="App.closeModal()" class="px-4 py-2 bg-slate-100 hover:bg-slate-200 text-slate-700 text-xs font-semibold rounded-lg">Close</button>
            </div>
          </div>
        </div>
      `;
      document.getElementById('modal-root').innerHTML = modalHtml;
      lucide.createIcons();
    } catch (e) {
      App.showToast(`Failed to load extraction: ${e.message}`, 'error');
    }
  }
};
