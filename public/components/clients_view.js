// Clients Directory Component
const ClientsView = {
  searchQuery: '',

  clients: [
    {
      id: 'cli_apex',
      name: 'M/s Apex Infrastructure Ltd.',
      contactPerson: 'Mr. Rajeshwar Sharma (Managing Director)',
      email: 'legal@apexinfra.in',
      phone: '+91 98101 29384',
      address: 'Barakhamba Road, Connaught Place, New Delhi',
      activeMatters: ['Apex Infrastructure v. Delhi Metro Real Estate (High Court of Delhi)'],
      type: 'Corporate Entity'
    },
    {
      id: 'cli_grover',
      name: 'Sunil Grover',
      contactPerson: 'Mr. Sunil Grover (Proprietor)',
      email: 'grover.spares@gmail.com',
      phone: '+91 98112 48920',
      address: 'Okhla Industrial Area Phase III, New Delhi',
      activeMatters: ['Sunil Grover v. Mehta Tex-Fab Industries (Saket District Courts)'],
      type: 'Individual / Proprietorship'
    }
  ],

  render() {
    return `
      <div class="space-y-6 animate-fadeIn">
        
        <!-- Header Banner (Clean Light Style) -->
        <div class="bg-white border border-slate-200 p-6 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-2 relative overflow-hidden">
          <div class="flex items-center space-x-2">
            <span class="px-2.5 py-0.5 rounded-full bg-amber-50 text-amber-600 border border-amber-200/50 text-[10px] font-bold uppercase tracking-wider">
              Chamber Management
            </span>
            <span class="text-xs text-slate-400">Client Directory</span>
          </div>
          <h2 class="font-serif text-2xl font-bold text-slate-900 tracking-wide">Client Directory & Active Matters</h2>
          <p class="text-xs text-slate-500 max-w-2xl leading-relaxed">
            Manage corporate and individual litigation clients, counsel briefs, and cross-referenced evidence lockers.
          </p>
        </div>

        <!-- Client List Cards (Neat & Clean White Card) -->
        <div class="space-y-4">
          ${this.clients.map(c => `
            <div class="bg-white border border-slate-200 p-6 rounded-2xl shadow-[0_4px_20px_rgba(0,0,0,0.02)] space-y-4">
              <div class="flex flex-col md:flex-row md:items-start justify-between gap-2">
                <div class="space-y-1">
                  <div class="flex items-center space-x-2">
                    <span class="px-2 py-0.5 rounded bg-slate-100 text-slate-600 font-mono text-[10px] font-bold">${c.type}</span>
                  </div>
                  <h3 class="font-serif text-lg font-bold text-slate-800">${escapeHtml(c.name)}</h3>
                  <p class="text-xs text-slate-500"><strong>Contact:</strong> ${escapeHtml(c.contactPerson)} • ${escapeHtml(c.phone)} • ${escapeHtml(c.email)}</p>
                  <p class="text-xs text-slate-500"><strong>Address:</strong> ${escapeHtml(c.address)}</p>
                </div>
              </div>

              <div class="p-3.5 rounded-xl bg-slate-50 border border-slate-100 space-y-1">
                <span class="text-[10px] font-bold uppercase tracking-wider text-amber-600">Active Matters Linked:</span>
                ${c.activeMatters.map(m => `
                  <p class="text-xs text-slate-700 font-medium flex items-center gap-1.5">
                    <i data-lucide="briefcase" class="w-3.5 h-3.5 text-amber-500"></i>
                    ${escapeHtml(m)}
                  </p>
                `).join('')}
              </div>
            </div>
          `).join('')}
        </div>

      </div>
    `;
  }
};
