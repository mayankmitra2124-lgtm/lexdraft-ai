// Landing Page View Component for Unauthenticated Visitors
const LandingPage = {
  render() {
    return `
      <div class="min-h-screen bg-[#15171C] text-[#EDEAE3] selection:bg-[#B98A46] selection:text-[#15171C] font-sans flex flex-col">
        
        <!-- Navigation Bar -->
        <header class="sticky top-0 z-40 bg-[#15171C]/90 backdrop-blur-md border-b border-white/5 px-6 sm:px-10 py-4">
          <div class="max-w-7xl mx-auto flex items-center justify-between">
            
            <!-- Brand Typography Logo -->
            <div class="flex flex-col cursor-pointer" onclick="App.navigate('landing')">
              <span class="font-serif font-bold text-lg sm:text-xl tracking-[0.18em] text-[#B98A46] uppercase leading-none">LEXDRAFT AI</span>
              <span class="text-[10px] text-[#9CA3AF] font-sans tracking-widest lowercase pt-1 font-normal">precision legal evidence</span>
            </div>

            <!-- Nav Links & Auth CTAs -->
            <div class="flex items-center space-x-5 sm:space-x-6">
              <button onclick="App.openAuthModal('signin')" class="text-xs font-semibold text-[#9CA3AF] hover:text-[#EDEAE3] transition">
                Log In
              </button>
              <button onclick="App.openAuthModal('signup')" class="px-5 py-2 rounded-full bg-[#B98A46] hover:bg-[#c99a56] text-[#15171C] font-medium text-xs transition shadow-lg shadow-[#B98A46]/10 flex items-center space-x-1.5">
                <span>Start Free Trial</span>
              </button>
            </div>

          </div>
        </header>

        <!-- Hero Section -->
        <section class="relative min-h-[85vh] bg-[#15171C] text-[#EDEAE3] flex flex-col justify-center items-center px-6 overflow-hidden">
          <!-- Engraved Legal Heritage Backdrop -->
          <div class="absolute inset-0 bg-cover bg-bottom bg-no-repeat opacity-30 pointer-events-none select-none" style="background-image: url('images/legal-heritage-bg.jpg');"></div>

          <!-- Subtle Background Curves -->
          <svg
            class="absolute inset-0 w-full h-full pointer-events-none opacity-20"
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 1440 800"
            fill="none"
          >
            <path
              d="M-100,400 C300,200 600,600 1000,350 C1300,150 1500,450 1600,400"
              stroke="#B98A46"
              stroke-width="1.2"
            />
            <path
              d="M-100,450 C350,260 650,620 1050,380 C1350,200 1480,480 1600,450"
              stroke="#B98A46"
              stroke-width="0.8"
            />
          </svg>

          <!-- Hero Content -->
          <div class="relative z-10 max-w-3xl text-center flex flex-col items-center py-12">
            <h1 class="font-serif text-4xl sm:text-5xl md:text-6xl tracking-tight leading-tight text-[#EDEAE3]">
              Saboot bikhre hue, <br />
              <span class="italic font-normal text-[#B98A46]">
                par kahani ek honi chahiye.
              </span>
            </h1>

            <p class="mt-6 text-lg sm:text-xl text-[#9CA3AF] max-w-xl font-sans">
              Integrate dispersed data. Build your court-ready narrative.
            </p>

            <button onclick="App.openAuthModal('signup')" class="mt-8 px-8 py-3.5 rounded-full bg-[#B98A46] text-[#15171C] font-medium hover:bg-[#c99a56] transition-colors shadow-lg shadow-[#B98A46]/10">
              Start Free Trial
            </button>

            <!-- Minimal Trust Strip -->
            <div class="mt-20 flex flex-wrap justify-center items-center gap-x-8 gap-y-3 text-xs sm:text-sm text-[#9CA3AF]/80 border-t border-white/5 pt-8 font-sans">
              <span>Indian Evidence Act Section 65B / BSA 2023 Compliant</span>
              <span class="text-white/20">•</span>
              <span>Per-User Encrypted Data Isolation</span>
              <span class="text-white/20">•</span>
              <span>Multi-Model AI Verification Against Source Documents</span>
            </div>
          </div>
        </section>

        <!-- "Trusted By" Section Header -->
        <div class="relative py-12 text-center overflow-hidden bg-[#15171C]">
          <h3 class="font-serif text-2xl sm:text-3xl font-bold text-[#B98A46] tracking-wide inline-block drop-shadow-[0_0_20px_rgba(185,138,70,0.35)]">
            Trusted By
          </h3>
          <!-- Decorative 4-point star sparkle -->
          <div class="absolute right-8 sm:right-20 top-1/2 -translate-y-1/2 text-slate-600 opacity-60 pointer-events-none">
            <svg class="w-7 h-7 fill-current text-[#B98A46]/60" viewBox="0 0 24 24">
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
