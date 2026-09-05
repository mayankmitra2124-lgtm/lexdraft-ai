// Landing Page View Component for Unauthenticated Visitors
const LandingPage = {
  render() {
    return `
      <div class="min-h-screen bg-[#0C0F17] text-slate-100 selection:bg-[#B98A46] selection:text-slate-950 font-sans flex flex-col">
        
        <!-- Navigation Bar -->
        <header class="sticky top-0 z-40 bg-[#0C0F17]/90 backdrop-blur-md border-b border-slate-850/80 px-6 sm:px-10 py-4">
          <div class="max-w-7xl mx-auto flex items-center justify-between">
            
            <!-- Brand Typography Logo -->
            <div class="flex flex-col cursor-pointer" onclick="App.navigate('landing')">
              <span class="font-serif font-bold text-lg sm:text-xl tracking-[0.18em] text-[#C59B63] uppercase leading-none">LEXDRAFT AI</span>
              <span class="text-[10px] text-slate-400 font-sans tracking-widest lowercase pt-1 font-normal">precision legal evidence</span>
            </div>

            <!-- Nav Links & Auth CTAs -->
            <div class="flex items-center space-x-5 sm:space-x-6">
              <button onclick="App.openAuthModal('signin')" class="text-xs font-semibold text-slate-300 hover:text-white transition">
                Log In
              </button>
              <button onclick="App.openAuthModal('signup')" class="px-5 py-2 rounded-full bg-[#B98A46] hover:bg-[#C59B63] text-slate-950 font-bold text-xs hover:brightness-105 transition shadow-lg shadow-amber-950/30 flex items-center space-x-1.5">
                <span>Start Free Trial</span>
              </button>
            </div>

          </div>
        </header>

        <!-- Main Hero Section: Two-Column Split Layout -->
        <section class="relative pt-8 sm:pt-12 pb-10 px-6 sm:px-10 overflow-hidden flex-1 flex flex-col justify-center">
          <!-- Background Ambient Golden Glow behind Scales -->
          <div class="absolute top-1/3 right-1/4 w-[500px] h-[400px] bg-amber-500/10 rounded-full blur-3xl pointer-events-none"></div>

          <div class="max-w-7xl mx-auto w-full grid grid-cols-1 lg:grid-cols-12 gap-8 lg:gap-12 items-center relative z-10">
            
            <!-- Left Column: Copy & Primary CTA -->
            <div class="lg:col-span-6 space-y-6 text-left">
              <h1 class="font-serif text-4xl sm:text-5xl lg:text-[54px] font-normal text-white tracking-tight leading-[1.18]">
                Saboot bikhre hue, par<br>
                kahani ek honi chahiye.
              </h1>

              <p class="text-base sm:text-lg text-slate-400 font-sans leading-relaxed max-w-lg font-normal">
                Integrate dispersed data. Build your court-ready narrative.
              </p>

              <div class="pt-2">
                <button onclick="App.openAuthModal('signup')" class="px-8 py-3.5 rounded-full bg-[#B98A46] hover:bg-[#C59B63] text-slate-950 font-bold text-sm transition shadow-xl shadow-amber-950/40 hover:brightness-105 active:scale-[0.98] inline-flex items-center space-x-2">
                  <span>Create Chronology</span>
                </button>
              </div>
            </div>

            <!-- Right Column: 3D Scales of Justice Illustration -->
            <div class="lg:col-span-6 flex justify-center lg:justify-end relative">
              <div class="relative w-full max-w-[500px]">
                <img src="images/hero_scales.png" alt="LexDraft AI - Physical vs Digital Evidence Synthesis" class="w-full h-auto object-contain select-none drop-shadow-2xl">
              </div>
            </div>

          </div>
        </section>

        <!-- Compliance & Evidence Standards Ribbon -->
        <div class="w-full border-t border-b border-slate-800/80 bg-[#0E121E]/75 backdrop-blur-sm py-4 px-6">
          <div class="max-w-6xl mx-auto flex flex-wrap items-center justify-center gap-6 sm:gap-8 text-xs text-slate-400 font-sans">
            <div class="flex items-center space-x-2.5">
              <i data-lucide="file-text" class="w-4 h-4 text-slate-400 shrink-0"></i>
              <span>Indian Evidence Act Section 65B / 2023 Compliant</span>
            </div>
            <span class="text-slate-700 hidden sm:inline">|</span>
            <div class="flex items-center space-x-2.5">
              <i data-lucide="lock" class="w-4 h-4 text-slate-400 shrink-0"></i>
              <span>Per-User Encrypted Data Isolation</span>
            </div>
            <span class="text-slate-700 hidden sm:inline">|</span>
            <div class="flex items-center space-x-2.5">
              <i data-lucide="cpu" class="w-4 h-4 text-slate-400 shrink-0"></i>
              <span>Multi-Model AI Verification Against Source Documents</span>
            </div>
          </div>
        </div>

        <!-- "Trusted By" Section Header -->
        <div class="relative py-12 text-center overflow-hidden">
          <h3 class="font-serif text-2xl sm:text-3xl font-bold text-[#C59B63] tracking-wide inline-block drop-shadow-[0_0_20px_rgba(197,155,99,0.35)]">
            Trusted By
          </h3>
          <!-- Decorative 4-point star sparkle -->
          <div class="absolute right-8 sm:right-20 top-1/2 -translate-y-1/2 text-slate-600 opacity-60 pointer-events-none">
            <svg class="w-7 h-7 fill-current text-[#C59B63]/60" viewBox="0 0 24 24">
              <path d="M12 0L14.5 9.5L24 12L14.5 14.5L12 24L9.5 14.5L0 12L9.5 9.5L12 0Z"/>
            </svg>
          </div>
        </div>

        <!-- Feature Pillars Grid -->
        <section class="py-16 px-6 bg-[#0E1322] border-t border-slate-850">
          <div class="max-w-6xl mx-auto space-y-12">
            
            <div class="text-center space-y-2">
              <h2 class="font-serif text-2xl sm:text-3xl font-bold text-white">Built for Indian judicial practice</h2>
              <p class="text-xs text-slate-400 max-w-xl mx-auto">Structured around procedural court admissibility, statutory limitation deadlines, and electronic evidence standards.</p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              
              <!-- Feature 1 -->
              <div class="p-6 rounded-2xl bg-[#13192B] border border-slate-800 hover:border-amber-500/40 transition space-y-3 shadow-lg">
                <div class="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
                  <i data-lucide="file-check-2" class="w-5 h-5"></i>
                </div>
                <h3 class="font-serif font-bold text-base text-white">Section 65B & 63 BSA Certificates</h3>
                <p class="text-xs text-slate-400 leading-relaxed font-sans">
                  Generates court-ready electronic evidence certificates for WhatsApp chats, PDFs, and recordings — drafted to match Supreme Court precedent, ready to file with your petition.
                </p>
              </div>

              <!-- Feature 2 -->
              <div class="p-6 rounded-2xl bg-[#13192B] border border-slate-800 hover:border-amber-500/40 transition space-y-3 shadow-lg">
                <div class="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
                  <i data-lucide="mic" class="w-5 h-5"></i>
                </div>
                <h3 class="font-serif font-bold text-base text-white">Searchable Audio & Video Transcripts</h3>
                <p class="text-xs text-slate-400 leading-relaxed font-sans">
                  Every recorded call or video is transcribed with speakers identified. Click any line of the transcript to jump straight to that moment in the original recording.
                </p>
              </div>

              <!-- Feature 3 -->
              <div class="p-6 rounded-2xl bg-[#13192B] border border-slate-800 hover:border-amber-500/40 transition space-y-3 shadow-lg">
                <div class="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
                  <i data-lucide="shield-check" class="w-5 h-5"></i>
                </div>
                <h3 class="font-serif font-bold text-base text-white">Every Fact Verified Against Source</h3>
                <p class="text-xs text-slate-400 leading-relaxed font-sans">
                  Every figure and date the system extracts — a payment of ₹40,00,000, a disputed clause, a call date — is checked back against your original documents before it reaches your timeline. Anything unverified is flagged, never assumed.
                </p>
              </div>

              <!-- Feature 4 -->
              <div class="p-6 rounded-2xl bg-[#13192B] border border-slate-800 hover:border-amber-500/40 transition space-y-3 shadow-lg">
                <div class="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
                  <i data-lucide="hourglass" class="w-5 h-5"></i>
                </div>
                <h3 class="font-serif font-bold text-base text-white">Limitation Period Tracking</h3>
                <p class="text-xs text-slate-400 leading-relaxed font-sans">
                  A live countdown to the statutory limitation deadline for each matter, calculated under the Limitation Act, 1963 and the Commercial Courts Act, 2015 — so a filing window never closes unnoticed.
                </p>
              </div>

              <!-- Feature 5 -->
              <div class="p-6 rounded-2xl bg-[#13192B] border border-slate-800 hover:border-amber-500/40 transition space-y-3 shadow-lg">
                <div class="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
                  <i data-lucide="layers" class="w-5 h-5"></i>
                </div>
                <h3 class="font-serif font-bold text-base text-white">Built for Complex, High-Volume Matters</h3>
                <p class="text-xs text-slate-400 leading-relaxed font-sans">
                  Handles dense, high-volume case files — contracts, correspondence, financial records — without slowing down or losing accuracy on the details that matter most.
                </p>
              </div>

              <!-- Feature 6 -->
              <div class="p-6 rounded-2xl bg-[#13192B] border border-slate-800 hover:border-amber-500/40 transition space-y-3 shadow-lg">
                <div class="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
                  <i data-lucide="file-text" class="w-5 h-5"></i>
                </div>
                <h3 class="font-serif font-bold text-base text-white">Exhibit Indexing for Court Filing</h3>
                <p class="text-xs text-slate-400 leading-relaxed font-sans">
                  Exports petitions with exhibits numbered and paginated automatically, limitation declarations attached, and affidavits in place — ready to file, not just ready to read.
                </p>
              </div>

            </div>

          </div>
        </section>

        <!-- Footer -->
        <footer class="py-8 px-6 bg-[#0A0E1A] border-t border-slate-850 text-center text-xs text-slate-500 font-mono">
          <div class="max-w-5xl mx-auto">
            <p>© 2026 LexDraft AI — Evidence Intelligence for Indian Legal Practice</p>
          </div>
        </footer>

      </div>
    `;
  }
};
