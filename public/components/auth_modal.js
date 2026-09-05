// Interactive Auth Modal Component supporting Sign In & Sign Up
const AuthModal = {
  currentMode: 'signin', // 'signin' or 'signup'
  errorMessage: null,
  isSubmitting: false,

  render(mode = 'signin', error = null) {
    this.currentMode = mode;
    this.errorMessage = error;

    const isSignUp = this.currentMode === 'signup';

    return `
      <div id="auth-modal-overlay" class="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 animate-fadeIn">
        <div class="bg-[#0F172A] border border-slate-700/80 rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-5 relative overflow-hidden">
          
          <!-- Close Button -->
          <button onclick="App.closeAuthModal()" class="absolute top-4 right-4 text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800 transition">
            <i data-lucide="x" class="w-5 h-5"></i>
          </button>

          <!-- Top Brand Header -->
          <div class="text-center space-y-1 pt-1">
            <div class="w-12 h-12 rounded-xl bg-gradient-gold flex items-center justify-center text-slate-950 font-bold mx-auto shadow-lg shadow-amber-500/20 mb-2">
              <i data-lucide="scale" class="w-6 h-6"></i>
            </div>
            <h2 class="font-serif text-xl font-bold text-white">
              ${isSignUp ? 'Create Chamber Account' : 'Sign In to LexDraft AI'}
            </h2>
            <p class="text-xs text-slate-400 font-sans">
              ${isSignUp ? 'Enter your details to initialize your isolated legal vault.' : 'Enter your credentials to access your active matters.'}
            </p>
          </div>

          <!-- Mode Toggle Tabs -->
          <div class="flex items-center p-1 bg-slate-900 rounded-xl border border-slate-800 text-xs font-semibold">
            <button onclick="AuthModal.switchMode('signin')" class="flex-1 py-2 rounded-lg transition ${!isSignUp ? 'bg-slate-800 text-amber-400 shadow' : 'text-slate-400 hover:text-white'}">
              Sign In
            </button>
            <button onclick="AuthModal.switchMode('signup')" class="flex-1 py-2 rounded-lg transition ${isSignUp ? 'bg-slate-800 text-amber-400 shadow' : 'text-slate-400 hover:text-white'}">
              Sign Up
            </button>
          </div>

          <!-- Error Alert Banner -->
          ${this.errorMessage ? `
            <div class="p-3 rounded-xl bg-rose-500/10 border border-rose-500/30 flex items-start space-x-2 text-xs text-rose-300">
              <i data-lucide="alert-circle" class="w-4 h-4 text-rose-400 shrink-0 mt-0.5"></i>
              <span>${escapeHtml(this.errorMessage)}</span>
            </div>
          ` : ''}

          <!-- Form Body -->
          ${isSignUp ? this.renderSignUpForm() : this.renderSignInForm()}

          <!-- Security Footer Note -->
          <div class="pt-2 border-t border-slate-800 text-center text-[10px] text-slate-500 font-mono flex items-center justify-center space-x-1.5">
            <i data-lucide="shield-check" class="w-3.5 h-3.5 text-emerald-500"></i>
            <span>256-bit PBKDF2 Password Hashing • End-to-End Isolated Vault</span>
          </div>

        </div>
      </div>
    `;
  },

  renderSignInForm() {
    return `
      <form id="signin-form" onsubmit="event.preventDefault(); App.handleSignIn(event); return false;" class="space-y-4">
        
        <div class="space-y-1">
          <label class="block text-xs font-semibold text-slate-300">Email Address</label>
          <div class="relative">
            <i data-lucide="mail" class="w-4 h-4 absolute left-3.5 top-3 text-slate-400"></i>
            <input type="email" id="signin-email" name="email" required placeholder="advocate@chambers.in" autofocus
              class="w-full bg-slate-900 border border-slate-700/80 rounded-xl pl-10 pr-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-amber-500 font-sans shadow-inner">
          </div>
        </div>

        <div class="space-y-1">
          <div class="flex items-center justify-between">
            <label class="block text-xs font-semibold text-slate-300">Password</label>
            <button type="button" onclick="AuthModal.showForgotPassword()" class="text-[11px] text-amber-400 hover:text-amber-300">
              Forgot password?
            </button>
          </div>
          <div class="relative">
            <i data-lucide="lock" class="w-4 h-4 absolute left-3.5 top-3 text-slate-400"></i>
            <input type="password" id="signin-password" name="password" required placeholder="••••••••"
              class="w-full bg-slate-900 border border-slate-700/80 rounded-xl pl-10 pr-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-amber-500 font-sans shadow-inner">
          </div>
        </div>

        <button type="button" onclick="App.handleSignIn(event)" ${this.isSubmitting ? 'disabled' : ''} class="w-full py-2.5 rounded-xl bg-gradient-gold text-slate-950 font-bold text-xs hover:brightness-110 transition shadow-lg shadow-amber-500/20 flex items-center justify-center space-x-1.5">
          ${this.isSubmitting ? '<i data-lucide="loader-2" class="w-4 h-4 animate-spin"></i><span>Signing In...</span>' : '<i data-lucide="log-in" class="w-4 h-4"></i><span>Sign In to Chamber</span>'}
        </button>

      </form>
    `;
  },

  renderSignUpForm() {
    return `
      <form id="signup-form" onsubmit="event.preventDefault(); App.handleSignUp(event); return false;" class="space-y-3.5">
        
        <!-- Name Inputs Grid -->
        <div class="grid grid-cols-2 gap-3">
          <div class="space-y-1">
            <label class="block text-[11px] font-semibold text-slate-300">First Name</label>
            <input type="text" id="signup-firstname" name="first_name" required placeholder="Mayank" autofocus
              class="w-full bg-slate-900 border border-slate-700/80 rounded-xl px-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-amber-500 font-sans shadow-inner">
          </div>

          <div class="space-y-1">
            <label class="block text-[11px] font-semibold text-slate-300">Last Name</label>
            <input type="text" id="signup-lastname" name="last_name" required placeholder="Mitra"
              class="w-full bg-slate-900 border border-slate-700/80 rounded-xl px-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-amber-500 font-sans shadow-inner">
          </div>
        </div>

        <!-- Email -->
        <div class="space-y-1">
          <label class="block text-[11px] font-semibold text-slate-300">Email Address</label>
          <div class="relative">
            <i data-lucide="mail" class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-400"></i>
            <input type="email" id="signup-email" name="email" required placeholder="advocate@chambers.in"
              class="w-full bg-slate-900 border border-slate-700/80 rounded-xl pl-9 pr-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-amber-500 font-sans shadow-inner">
          </div>
        </div>

        <!-- Password -->
        <div class="space-y-1">
          <label class="block text-[11px] font-semibold text-slate-300">Password (min 8 characters)</label>
          <div class="relative">
            <i data-lucide="lock" class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-400"></i>
            <input type="password" id="signup-password" name="password" required placeholder="••••••••" oninput="AuthModal.checkPasswordStrength(this.value)"
              class="w-full bg-slate-900 border border-slate-700/80 rounded-xl pl-9 pr-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-amber-500 font-sans shadow-inner">
          </div>
          <div id="password-strength-indicator" class="text-[10px] text-slate-400 pt-0.5">Use at least 8 characters with numbers or symbols.</div>
        </div>

        <!-- Confirm Password -->
        <div class="space-y-1">
          <label class="block text-[11px] font-semibold text-slate-300">Confirm Password</label>
          <div class="relative">
            <i data-lucide="check-check" class="w-3.5 h-3.5 absolute left-3 top-2.5 text-slate-400"></i>
            <input type="password" id="signup-confirm" name="password_confirmation" required placeholder="••••••••"
              class="w-full bg-slate-900 border border-slate-700/80 rounded-xl pl-9 pr-3 py-2 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-amber-500 font-sans shadow-inner">
          </div>
        </div>

        <button type="button" onclick="App.handleSignUp(event)" ${this.isSubmitting ? 'disabled' : ''} class="w-full py-2.5 rounded-xl bg-gradient-gold text-slate-950 font-bold text-xs hover:brightness-110 transition shadow-lg shadow-amber-500/20 flex items-center justify-center space-x-1.5 mt-2">
          ${this.isSubmitting ? '<i data-lucide="loader-2" class="w-4 h-4 animate-spin"></i><span>Creating Account...</span>' : '<i data-lucide="user-check" class="w-4 h-4"></i><span>Create Chamber Account</span>'}
        </button>

      </form>
    `;
  },

  checkPasswordStrength(val) {
    const el = document.getElementById('password-strength-indicator');
    if (!el) return;

    if (!val || val.length === 0) {
      el.innerHTML = '<span class="text-slate-400">Use at least 8 characters with numbers or symbols.</span>';
      return;
    }

    const hasNumOrSym = /[0-9]/.test(val) || /[^A-Za-z0-9]/.test(val);
    if (val.length >= 8 && hasNumOrSym) {
      el.innerHTML = '<span class="text-emerald-400 font-semibold">✓ Strong password</span>';
    } else if (val.length >= 8) {
      el.innerHTML = '<span class="text-amber-400 font-semibold">⚠ Add a number or symbol for strength.</span>';
    } else {
      el.innerHTML = `<span class="text-rose-400 font-semibold">Too short (${val.length}/8 chars)</span>`;
    }
  },

  switchMode(mode) {
    this.currentMode = mode;
    this.errorMessage = null;
    const modalRoot = document.getElementById('modal-root');
    if (modalRoot) {
      modalRoot.innerHTML = this.render(mode);
      lucide.createIcons();
    }
  },

  showForgotPassword() {
    const modalRoot = document.getElementById('modal-root');
    if (!modalRoot) return;

    modalRoot.innerHTML = `
      <div id="auth-modal-overlay" class="fixed inset-0 z-50 bg-black/80 backdrop-blur-sm flex items-center justify-center p-4 animate-fadeIn">
        <div class="bg-[#0F172A] border border-slate-700/80 rounded-2xl max-w-md w-full p-6 shadow-2xl space-y-4 relative">
          
          <button onclick="App.closeAuthModal()" class="absolute top-4 right-4 text-slate-400 hover:text-white p-1 rounded-lg hover:bg-slate-800 transition">
            <i data-lucide="x" class="w-5 h-5"></i>
          </button>

          <div class="space-y-1">
            <div class="w-10 h-10 rounded-xl bg-amber-500/10 border border-amber-500/20 flex items-center justify-center text-amber-400 mb-2">
              <i data-lucide="key-round" class="w-5 h-5"></i>
            </div>
            <h3 class="font-serif text-lg font-bold text-white">Reset Chamber Password</h3>
            <p class="text-xs text-slate-400 leading-relaxed">
              Enter your registered chamber email address to receive secure password recovery instructions.
            </p>
          </div>

          <form onsubmit="App.handleForgotPassword(event)" class="space-y-4">
            <div class="space-y-1">
              <label class="block text-xs font-semibold text-slate-300">Chamber Email</label>
              <input type="email" name="email" required placeholder="advocate@chambers.in" autofocus
                class="w-full bg-slate-900 border border-slate-700/80 rounded-xl px-3.5 py-2.5 text-xs text-white placeholder-slate-500 focus:outline-none focus:border-amber-500 font-sans shadow-inner">
            </div>

            <button type="submit" class="w-full py-2.5 rounded-xl bg-gradient-gold text-slate-950 font-bold text-xs hover:brightness-110 transition shadow-lg shadow-amber-500/20 flex items-center justify-center space-x-1.5">
              <i data-lucide="send" class="w-4 h-4"></i>
              <span>Send Recovery Link</span>
            </button>
          </form>

          <div class="text-center pt-2">
            <button onclick="AuthModal.switchMode('signin')" class="text-xs text-amber-400 hover:text-amber-300">
              Back to Sign In
            </button>
          </div>

        </div>
      </div>
    `;
    lucide.createIcons();
  }
};
