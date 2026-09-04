// Landing Page View Component for Unauthenticated Visitors
const LandingPage = {
  render() {
    return `
      <div class="min-h-screen bg-[#0A0E1A] text-slate-100 selection:bg-amber-500 selection:text-slate-950 font-sans flex flex-col">
        
        <!-- Navigation Bar -->
        <header class="sticky top-0 z-40 bg-[#0A0E1A]/85 backdrop-blur-md border-b border-slate-800 px-6 py-4">
          <div class="max-w-7xl mx-auto flex items-center justify-between">
            
            <!-- Brand Logo -->
            <div class="flex items-center space-x-3 cursor-pointer" onclick="App.navigate('landing')">
              <div class="w-10 h-10 rounded-xl bg-gradient-gold flex items-center justify-center text-slate-950 font-bold shadow-lg shadow-amber-500/20 shrink-0">
                <i data-lucide="scale" class="w-5 h-5"></i>
              </div>
              <div>
                <span class="font-serif font-bold text-lg tracking-wide text-white leading-tight block">LexDraft AI</span>
                <span class="text-[10px] text-amber-500 font-mono tracking-wider uppercase">Case Evidence Organizer</span>
              </div>
            </div>

            <!-- Nav Links & Auth CTAs -->
            <div class="flex items-center space-x-3 sm:space-x-4">
              <button onclick="App.openAuthModal('signin')" class="px-4 py-2 text-xs font-semibold text-slate-300 hover:text-white hover:bg-slate-800/80 rounded-xl transition">
                Sign In
              </button>
              <button onclick="App.openAuthModal('signup')" class="px-4 py-2 rounded-xl bg-gradient-gold text-slate-950 font-bold text-xs hover:brightness-110 transition shadow-lg shadow-amber-500/20 flex items-center space-x-1.5">
                <i data-lucide="user-plus" class="w-3.5 h-3.5"></i>
                <span>Get Started Free</span>
              </button>
            </div>

          </div>
        </header>

        <!-- Hero Section -->
        <section class="relative pt-16 pb-20 px-6 overflow-hidden flex-1 flex flex-col justify-center">
          <!-- Background Glow Effect -->
          <div class="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[600px] h-[350px] bg-amber-500/10 rounded-full blur-3xl pointer-events-none"></div>

          <div class="max-w-5xl mx-auto text-center space-y-6 relative z-10">
            
            <!-- Badge -->
            <div class="inline-flex items-center space-x-2 px-3.5 py-1.5 rounded-full bg-slate-900/90 border border-amber-500/30 text-xs text-amber-400 font-mono shadow-sm">
              <span class="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
              <span>Indian Evidence Act (Sec 65B) & BSA 2023 Compliant</span>
            </div>

            <!-- Main Heading -->
            <h1 class="font-serif text-4xl sm:text-5xl lg:text-6xl font-extrabold text-white tracking-tight leading-tight">
              Defense-Grade Legal Evidence Synthesis & Verification
            </h1>

            <!-- Subtitle -->
            <p class="text-sm sm:text-base text-slate-400 max-w-3xl mx-auto leading-relaxed">
              Transform gigabytes of messy contracts, WhatsApp exports, audio calls, and bank statements into court-admissible chronologies, Section 65B affidavits, and petition annexures. Built specifically for Indian High Courts, Commercial Courts, and Arbitral Tribunals.
            </p>

            <!-- Hero CTAs -->
            <div class="flex flex-col sm:flex-row items-center justify-center gap-3.5 pt-4">
              <button onclick="App.openAuthModal('signup')" class="w-full sm:w-auto px-7 py-3.5 rounded-xl bg-gradient-gold text-slate-950 font-bold text-sm hover:brightness-110 transition shadow-xl shadow-amber-500/25 flex items-center justify-center space-x-2">
                <i data-lucide="shield-check" class="w-4 h-4"></i>
                <span>Create Chamber Account</span>
              </button>
              <button onclick="App.openAuthModal('signin')" class="w-full sm:w-auto px-7 py-3.5 rounded-xl bg-slate-900 hover:bg-slate-850 text-white font-semibold text-sm border border-slate-750 hover:border-amber-500/50 transition flex items-center justify-center space-x-2">
                <i data-lucide="log-in" class="w-4 h-4 text-amber-500"></i>
                <span>Sign In to Existing Vault</span>
              </button>
            </div>

            <!-- Social Proof / Compliance Bar -->
            <div class="pt-8 flex flex-wrap items-center justify-center gap-6 text-xs text-slate-500 font-mono">
              <span class="flex items-center gap-1.5"><i data-lucide="lock" class="w-3.5 h-3.5 text-emerald-500"></i> Per-User Encrypted Isolation</span>
              <span class="flex items-center gap-1.5"><i data-lucide="check-circle" class="w-3.5 h-3.5 text-emerald-500"></i> Arjun Khotkar (2020) Standard</span>
              <span class="flex items-center gap-1.5"><i data-lucide="cpu" class="w-3.5 h-3.5 text-amber-500"></i> 3-Model Cascading Fan-Out</span>
            </div>

          </div>
        </section>

        <!-- Feature Pillars Grid -->
        <section class="py-16 px-6 bg-[#0E1322] border-t border-slate-850">
          <div class="max-w-6xl mx-auto space-y-12">
            
            <div class="text-center space-y-2">
              <h2 class="font-serif text-2xl sm:text-3xl font-bold text-white">Engineered for Indian Judicial Practice</h2>
              <p class="text-xs text-slate-400 max-w-xl mx-auto">Every module is structured around procedural court admissibility, limitation periods, and electronic evidence standards.</p>
            </div>

            <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
              
              <!-- Feature 1 -->
              <div class="p-6 rounded-2xl bg-[#13192B] border border-slate-800 hover:border-amber-500/40 transition space-y-3 shadow-lg">
                <div class="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
                  <i data-lucide="file-check-2" class="w-5 h-5"></i>
                </div>
                <h3 class="font-serif font-bold text-base text-white">Section 65B & 63 BSA Certificate Generator</h3>
                <p class="text-xs text-slate-400 leading-relaxed">
                  Computes SHA-256 cryptographic hashes for WhatsApp chats, PDFs, and recordings. Auto-generates court-ready electronic affidavits compliant with Supreme Court precedents.
                </p>
              </div>

              <!-- Feature 2 -->
              <div class="p-6 rounded-2xl bg-[#13192B] border border-slate-800 hover:border-amber-500/40 transition space-y-3 shadow-lg">
                <div class="w-10 h-10 rounded-xl bg-emerald-500/10 border border-emerald-500/20 flex items-center justify-center text-emerald-400">
                  <i data-lucide="mic" class="w-5 h-5"></i>
                </div>
                <h3 class="font-serif font-bold text-base text-white">Speech-to-Text with Click-to-Seek Player</h3>
                <p class="text-xs text-slate-400 leading-relaxed">
                  Automatic speech recognition with speaker diarization for audio and video calls. Click any timestamp in the transcript to jump immediately to the spoken verbal admission.
                </p>
              </div>

              <!-- Feature 3 -->
              <div class="p-6 rounded-2xl bg-[#13192B] border border-slate-800 hover:border-amber-500/40 transition space-y-3 shadow-lg">
                <div class="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400">
                  <i data-lucide="shield-alert" class="w-5 h-5"></i>
                </div>
                <h3 class="font-serif font-bold text-base text-white">Zero-Tolerance Reverse Grounding</h3>
                <p class="text-xs text-slate-400 leading-relaxed">
                  Deterministic token verification scans extracted figures (e.g. ₹40,00,000) and dates against the underlying source file. Flags unverified numbers with Token Drift warnings.
                </p>
              </div>

              <!-- Feature 4 -->
              <div class="p-6 rounded-2xl bg-[#13192B] border border-slate-800 hover:border-amber-500/40 transition space-y-3 shadow-lg">
                <div class="w-10 h-10 rounded-xl bg-rose-500/10 border border-rose-500/20 flex items-center justify-center text-rose-400">
                  <i data-lucide="hourglass" class="w-5 h-5"></i>
                </div>
                <h3 class="font-serif font-bold text-base text-white">Statutory Limitation Clock</h3>
                <p class="text-xs text-slate-400 leading-relaxed">
                  Calculates 3-Year limitation windows under Schedule Article 55/113 of the Limitation Act, 1963 and Commercial Courts Act 2015. Live countdown of days remaining before limitation bar.
                </p>
              </div>

              <!-- Feature 5 -->
              <div class="p-6 rounded-2xl bg-[#13192B] border border-slate-800 hover:border-amber-500/40 transition space-y-3 shadow-lg">
                <div class="w-10 h-10 rounded-xl bg-purple-500/10 border border-purple-500/20 flex items-center justify-center text-purple-400">
                  <i data-lucide="layers" class="w-5 h-5"></i>
                </div>
                <h3 class="font-serif font-bold text-base text-white">Cascading Early-Exit Multi-Model</h3>
                <p class="text-xs text-slate-400 leading-relaxed">
                  Tier-1 fast pass with Gemini 2.0 Flash early-exits when confidence is ≥ 0.90, cutting token costs by ~65%. Escalates to GPT-4o and Claude 3.5 Sonnet only for ambiguous documents.
                </p>
              </div>

              <!-- Feature 6 -->
              <div class="p-6 rounded-2xl bg-[#13192B] border border-slate-800 hover:border-amber-500/40 transition space-y-3 shadow-lg">
                <div class="w-10 h-10 rounded-xl bg-cyan-500/10 border border-cyan-500/20 flex items-center justify-center text-cyan-400">
                  <i data-lucide="printer" class="w-5 h-5"></i>
                </div>
                <h3 class="font-serif font-bold text-base text-white">Court Brief Exhibit Indexing</h3>
                <p class="text-xs text-slate-400 leading-relaxed">
                  Export court-ready petitions with automatic Master Exhibit Indexing (Annexure P-1, P-2), running pagination, statutory limitation declarations, and affidavit attachments.
                </p>
              </div>

            </div>

          </div>
        </section>

        <!-- Footer -->
        <footer class="py-8 px-6 bg-[#0A0E1A] border-t border-slate-850 text-center text-xs text-slate-500 font-mono">
          <div class="max-w-5xl mx-auto flex flex-col sm:flex-row items-center justify-between gap-4">
            <p>© ${new Date().getFullYear()} LexDraft AI • Indian Legal Tech Evidence Ingestion & Synthesis Engine</p>
            <div class="flex items-center space-x-4">
              <span class="hover:text-slate-400 cursor-pointer" onclick="App.openAuthModal('signin')">Chamber Sign In</span>
              <span>•</span>
              <span class="hover:text-slate-400 cursor-pointer" onclick="App.openAuthModal('signup')">Create Account</span>
            </div>
          </div>
        </footer>

      </div>
    `;
  }
};
