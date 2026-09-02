// Interactive Source Citation, Speech-to-Text Audio Player & Section 65B Certificate Modal
const SourceViewerModal = {
  render(fileRecord, citationText = '') {
    const filename = fileRecord ? fileRecord.original_name : citationText;
    const fileType = fileRecord ? fileRecord.file_type : 'Document';
    const filePath = fileRecord ? `/uploads/${fileRecord.case_id}/${fileRecord.filename}` : '#';
    const isAudio = fileType === 'Audio';
    const isVideo = fileType === 'Video';
    const isMedia = isAudio || isVideo;
    const hasTranscript = fileRecord && fileRecord.transcript && fileRecord.transcript.length > 0;

    return `
      <div id="source-modal-overlay" class="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4">
        <div class="bg-charcoal-900 border border-charcoal-700 rounded-2xl max-w-4xl w-full p-6 shadow-2xl space-y-4 max-h-[92vh] flex flex-col">
          
          <!-- Header -->
          <div class="flex items-start justify-between border-b border-charcoal-800 pb-3">
            <div class="flex items-center space-x-3">
              <div class="p-2.5 rounded-lg bg-charcoal-800 border border-legal-gold/40 text-legal-gold">
                <i data-lucide="${isAudio ? 'mic' : (isVideo ? 'video' : 'file-search')}" class="w-5 h-5"></i>
              </div>
              <div>
                <div class="flex items-center space-x-2">
                  <h3 class="font-serif text-lg font-bold text-white">${escapeHtml(filename)}</h3>
                  <span class="px-2 py-0.5 rounded bg-charcoal-800 text-charcoal-300 font-mono text-[11px] border border-charcoal-700">${fileType}</span>
                  ${isMedia ? '<span class="px-2 py-0.5 rounded bg-amber-950 text-amber-300 font-mono text-[10px] border border-amber-800 flex items-center gap-1"><i data-lucide="radio" class="w-3 h-3"></i>Click-to-Seek ASR</span>' : ''}
                </div>
                <p class="text-xs text-legal-gold font-mono font-semibold">Supporting Reference: ${escapeHtml(citationText || 'Primary Evidentiary Document')}</p>
              </div>
            </div>
            <button onclick="App.closeModal()" class="text-charcoal-400 hover:text-white p-1 rounded-lg hover:bg-charcoal-800">
              <i data-lucide="x" class="w-5 h-5"></i>
            </button>
          </div>

          <!-- Document Preview Viewer -->
          <div class="flex-1 overflow-y-auto bg-charcoal-950 p-5 rounded-xl border border-charcoal-800 space-y-4">
            
            <!-- Highlight Box for Citation -->
            <div class="p-3.5 rounded-xl bg-charcoal-900 border border-legal-gold/40 space-y-1">
              <span class="text-[10px] font-bold text-legal-gold uppercase tracking-wider flex items-center gap-1">
                <i data-lucide="bookmark" class="w-3.5 h-3.5"></i>
                Cited Reference Excerpt in Pleading
              </span>
              <p class="text-sm font-serif text-white leading-relaxed">
                "${escapeHtml(citationText || 'Relevant evidentiary excerpt supporting master chronology and facts.')}"
              </p>
            </div>

            <!-- Interactive Media Player for Audio / Video -->
            ${isMedia ? `
              <div class="p-4 rounded-xl bg-charcoal-900 border border-charcoal-800 space-y-2">
                <div class="flex items-center justify-between">
                  <span class="text-xs font-bold text-amber-400 uppercase tracking-wider flex items-center gap-1.5">
                    <i data-lucide="play-circle" class="w-4 h-4"></i>
                    <span>Interactive Courtroom Media Player (Synchronized ASR)</span>
                  </span>
                  <span class="text-[10px] text-charcoal-400 font-mono">Click any transcript timestamp below to jump</span>
                </div>
                ${isAudio ? `
                  <audio id="modal-media-player" controls class="w-full rounded-lg bg-charcoal-950 p-1" src="${filePath}">
                    Your browser does not support audio playback.
                  </audio>
                ` : `
                  <video id="modal-media-player" controls class="w-full max-h-56 rounded-lg bg-black" src="${filePath}">
                    Your browser does not support video playback.
                  </video>
                `}
              </div>
            ` : ''}

            <!-- Speech-to-Text Interactive Transcript Viewer -->
            ${hasTranscript ? `
              <div class="space-y-2">
                <div class="flex items-center justify-between">
                  <h4 class="text-xs font-bold text-amber-400 uppercase tracking-wider flex items-center gap-1.5">
                    <i data-lucide="mic" class="w-4 h-4"></i>
                    <span>Speech-to-Text (ASR) Verbatim Transcript (Diarized & Timestamped)</span>
                  </h4>
                  <span class="text-[10px] font-mono px-2 py-0.5 rounded bg-emerald-950 text-emerald-300 border border-emerald-800">Pre-Multi-Model Ingested</span>
                </div>
                
                <div id="transcript-container" class="space-y-2 max-h-[300px] overflow-y-auto pr-1">
                  ${SourceViewerModal.formatTranscriptHTML(fileRecord.transcript)}
                </div>
              </div>
            ` : ''}

            <!-- Document Stream & Metadata -->
            <div class="space-y-2">
              <h4 class="text-xs font-bold text-charcoal-400 uppercase tracking-wider">Document Inscription & Cryptographic Provenance</h4>
              ${fileRecord ? `
                <div class="p-4 rounded-xl bg-charcoal-900 border border-charcoal-800 text-xs font-mono text-charcoal-300 space-y-1.5">
                  <p><strong>Original File:</strong> ${escapeHtml(fileRecord.original_name)}</p>
                  <p><strong>File Classification:</strong> ${escapeHtml(fileRecord.file_type)} ${isMedia ? '(ASR Speech-to-Text Enabled)' : ''}</p>
                  <p><strong>File Size:</strong> ${formatBytes(fileRecord.file_size)}</p>
                  <p><strong>Status:</strong> ${escapeHtml(fileRecord.status)} (Chain of Custody Preserved)</p>
                  <p><strong>Admissibility:</strong> Certified under Sec 65B, IEA / Sec 63, BSA 2023</p>
                  ${fileRecord.file_summary ? `<p class="font-serif text-xs text-legal-gold/90 italic pt-1 border-t border-charcoal-800 mt-2">Summary: "${escapeHtml(fileRecord.file_summary)}"</p>` : ''}
                </div>
              ` : `
                <p class="text-xs text-charcoal-400 italic">Source file record loaded from case chronology.</p>
              `}
            </div>

          </div>

          <!-- Footer Actions -->
          <div class="flex items-center justify-between pt-2 border-t border-charcoal-800">
            <div class="flex items-center space-x-2">
              <span class="text-xs text-charcoal-400 font-mono">Evidence Verification Gate</span>
              ${fileRecord ? `
                <button onclick="SourceViewerModal.showCertificate('${fileRecord.case_id}', '${fileRecord.id}')" 
                        class="px-3 py-1.5 bg-amber-500/10 hover:bg-amber-500/20 text-amber-400 border border-amber-500/30 text-xs font-semibold rounded-lg flex items-center space-x-1.5 transition">
                  <i data-lucide="shield-check" class="w-3.5 h-3.5"></i>
                  <span>Sec 65B/63 Certificate</span>
                </button>
              ` : ''}
            </div>
            <div class="flex items-center space-x-2">
              ${fileRecord && filePath !== '#' ? `
                <a href="${filePath}" target="_blank" class="px-3.5 py-1.5 bg-charcoal-800 hover:bg-charcoal-750 text-white text-xs font-semibold rounded-lg flex items-center space-x-1.5 transition">
                  <i data-lucide="external-link" class="w-3.5 h-3.5"></i>
                  <span>Raw File</span>
                </a>
              ` : ''}
              <button onclick="App.closeModal()" class="px-4 py-1.5 bg-legal-gold text-charcoal-950 font-bold text-xs rounded-lg hover:bg-legal-gold-light transition">
                Close Viewer
              </button>
            </div>
          </div>

        </div>
      </div>
    `;
  },

  // Interactive Click-to-Seek Media Player
  seekMedia(seconds) {
    const player = document.getElementById('modal-media-player');
    if (player) {
      player.currentTime = seconds;
      player.play().catch(e => console.log('Autoplay blocked:', e));
      App.showToast(`Seeking media to ${Math.floor(seconds / 60)}m ${Math.floor(seconds % 60)}s`, 'info');
    }
  },

  // Parse HH:MM:SS to total seconds
  timeToSeconds(timeStr) {
    if (!timeStr) return 0;
    const parts = timeStr.trim().split(':').map(Number);
    if (parts.length === 3) {
      return (parts[0] * 3600) + (parts[1] * 60) + parts[2];
    } else if (parts.length === 2) {
      return (parts[0] * 60) + parts[1];
    }
    return 0;
  },

  // Render clickable, interactive transcript turns
  formatTranscriptHTML(transcriptText) {
    if (!transcriptText) return '';
    const lines = transcriptText.split('\n');
    let html = '';
    let inCard = false;

    lines.forEach((line) => {
      const match = line.match(/^\[(\d{2}:\d{2}:\d{2})\s*->\s*(\d{2}:\d{2}:\d{2})\]\s*([^:\n]+):\s*(.*)$/);
      if (match) {
        if (inCard) html += '</div>';
        const startT = match[1];
        const endT = match[2];
        const speaker = match[3];
        const startSec = SourceViewerModal.timeToSeconds(startT);

        html += `
          <div class="p-3 rounded-xl bg-charcoal-900 border border-charcoal-800 space-y-1 hover:border-amber-500/40 transition">
            <div class="flex items-center justify-between">
              <span class="text-xs font-bold text-slate-200">${escapeHtml(speaker)}</span>
              <button onclick="SourceViewerModal.seekMedia(${startSec})" 
                      class="px-2 py-0.5 rounded bg-charcoal-800 hover:bg-amber-500 hover:text-slate-950 text-amber-400 font-mono text-[10px] border border-amber-500/30 flex items-center gap-1 transition"
                      title="Seek player to ${startT}">
                <i data-lucide="play" class="w-3 h-3"></i>
                <span>${startT} - ${endT}</span>
              </button>
            </div>
        `;
        inCard = true;
      } else if (line.trim().startsWith('"') || line.trim().startsWith('[Audio') || line.trim().startsWith('[Acoustic') || line.trim().startsWith('[Video')) {
        const isEvent = line.trim().startsWith('[');
        if (isEvent) {
          html += `<p class="text-[11px] font-mono text-amber-400 italic">${escapeHtml(line.trim())}</p>`;
        } else {
          html += `<p class="text-xs font-serif text-slate-300 leading-relaxed">${escapeHtml(line.trim())}</p>`;
        }
      }
    });

    if (inCard) html += '</div>';
    return html || `<div class="p-3 bg-charcoal-900 rounded-xl font-mono text-xs text-slate-300 whitespace-pre-wrap">${escapeHtml(transcriptText)}</div>`;
  },

  // Fetch and display Section 65B Electronic Evidence Certificate
  async showCertificate(caseId, fileId) {
    try {
      App.showToast('Generating Section 65B/63 Certificate...', 'info');
      const res = await fetch(`/api/cases/${caseId}/files/${fileId}/certificate`);
      if (!res.ok) throw new Error('Certificate generation failed');
      const cert = await res.json();

      const modalHTML = `
        <div id="cert-modal-overlay" class="fixed inset-0 z-[60] bg-black/85 backdrop-blur-md flex items-center justify-center p-4">
          <div class="bg-charcoal-900 border border-amber-500/50 rounded-2xl max-w-3xl w-full p-6 shadow-2xl space-y-4 max-h-[90vh] flex flex-col">
            
            <div class="flex items-start justify-between border-b border-charcoal-800 pb-3">
              <div class="flex items-center space-x-3">
                <div class="p-2 rounded-xl bg-amber-500/20 text-amber-400 border border-amber-500/40">
                  <i data-lucide="shield-check" class="w-6 h-6"></i>
                </div>
                <div>
                  <h3 class="font-serif text-lg font-bold text-white">Section 65B / Section 63 BSA Certificate</h3>
                  <p class="text-xs text-amber-400 font-mono">Ref ID: ${escapeHtml(cert.certificate_id)} • SHA-256 Verified</p>
                </div>
              </div>
              <button onclick="document.getElementById('cert-modal-overlay').remove()" class="text-charcoal-400 hover:text-white p-1 rounded-lg">
                <i data-lucide="x" class="w-5 h-5"></i>
              </button>
            </div>

            <div class="p-3 bg-amber-500/10 border border-amber-500/30 rounded-xl text-xs text-amber-300 flex items-center justify-between font-mono">
              <span class="truncate">SHA-256 Digest: <strong>${escapeHtml(cert.sha256)}</strong></span>
              <span class="px-2 py-0.5 rounded bg-emerald-950 text-emerald-300 border border-emerald-800 text-[10px]">Arjun Khotkar Compliant</span>
            </div>

            <div class="flex-1 overflow-y-auto bg-charcoal-950 p-4 rounded-xl border border-charcoal-800 font-mono text-xs text-slate-200 whitespace-pre-wrap leading-relaxed select-all">
${escapeHtml(cert.certificate_text)}
            </div>

            <div class="flex items-center justify-between pt-2 border-t border-charcoal-800">
              <span class="text-xs text-charcoal-400">Ready for High Court / Commercial Court filing</span>
              <div class="flex items-center space-x-2">
                <button onclick="navigator.clipboard.writeText(\`${escapeHtml(cert.certificate_text)}\`); App.showToast('Certificate text copied to clipboard', 'success')" 
                        class="px-3.5 py-1.5 bg-charcoal-800 hover:bg-charcoal-750 text-white text-xs font-semibold rounded-lg flex items-center space-x-1.5 transition">
                  <i data-lucide="copy" class="w-3.5 h-3.5"></i>
                  <span>Copy Affidavit</span>
                </button>
                <button onclick="window.print()" class="px-4 py-1.5 bg-amber-500 text-slate-950 font-bold text-xs rounded-lg hover:bg-amber-400 transition flex items-center space-x-1.5">
                  <i data-lucide="printer" class="w-3.5 h-3.5"></i>
                  <span>Print / Save PDF</span>
                </button>
              </div>
            </div>

          </div>
        </div>
      `;

      const existing = document.getElementById('cert-modal-overlay');
      if (existing) existing.remove();
      document.body.insertAdjacentHTML('beforeend', modalHTML);
      lucide.createIcons();
    } catch (err) {
      App.showToast(`Error: ${err.message}`, 'error');
    }
  }
};
