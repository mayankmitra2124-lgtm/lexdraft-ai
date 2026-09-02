# frozen_string_literal: true

require_relative 'database'
require_relative '../services/storage_service'
require_relative '../services/media_chunker'
require_relative '../services/gemini_service'
require_relative '../services/aggregation_service'

module SeedData
  def self.seed!
    Database.init
    StorageService.init

    # Check if Case 1 exists already
    existing = Database.get_case('case_apex_v_delhimetro')
    if existing
      puts "Seed data already present. Skipping."
      return
    end

    puts "Seeding high-fidelity Indian legal cases..."

    # =========================================================================
    # CASE 1: Commercial Injunction & Section 9 Arbitration Petition
    # =========================================================================
    case1 = Database.create_case({
      'id' => 'case_apex_v_delhimetro',
      'name' => 'Apex Infrastructure Ltd. v. Delhi Metro Real Estate Pvt. Ltd.',
      'case_number' => 'OMP (I) (COMM) No. 342/2024',
      'court_name' => 'High Court of Delhi at New Delhi (Commercial Division)',
      'objective' => 'Petition under Section 9 of the Arbitration & Conciliation Act, 1996 seeking urgent ad-interim injunction restraining the Respondent from invoking/encashing Bank Guarantees worth ₹14.5 Crores, and restraining creation of third-party rights over Commercial Tower Project, Sector 62.',
      'parties_info' => 'Petitioner: M/s Apex Infrastructure Ltd. (EPC Contractor, Registered Office: Barakhamba Road, Connaught Place, New Delhi). Respondent: Delhi Metro Real Estate Pvt. Ltd. (Project Developer, Registered Office: Nehru Place, New Delhi). Key Individuals: Rajeshwar Sharma (Managing Director, Apex Infrastructure), Vikramaditya Singhania (Managing Director, Delhi Metro Real Estate), Ar. Sunil Bhasin (Independent Supervising Architect).',
      'hearing_date' => '2026-09-04',
      'tier' => 'pro'
    })

    # Evidence File 1: Master EPC Contract
    contract_text = <<~TXT
      COMMERCIAL EPC CONTRACT AGREEMENT
      THIS AGREEMENT executed on 14th January 2023 at New Delhi BETWEEN:
      1. M/s Apex Infrastructure Ltd., New Delhi (hereinafter "Contractor")
      2. M/s Delhi Metro Real Estate Pvt. Ltd., New Delhi (hereinafter "Employer")
      
      WHEREAS Employer awarded construction of 'Skyline Corporate Tower', Sector 62 (Total Value: ₹98,00,00,000/-).
      
      KEY CLAUSES:
      Clause 4.2 (Site Handover): Employer shall provide hindrance-free site possession within 30 days of signing.
      Clause 9.1 (Payment Terms): RA Bills shall be certified by Architect within 14 days and paid by Employer within 21 days.
      Clause 19.3 (Bank Guarantees): Performance Bank Guarantee of ₹14.50 Crores shall remain valid till Virtual Completion. Invocation permitted only upon uncured material breach after 30 days formal notice.
      Clause 28.1 (Dispute Resolution & Jurisdiction): All disputes shall be referred to Sole Arbitration seated in New Delhi. Courts of Delhi alone have exclusive supervisory jurisdiction.
    TXT

    f1_storage = StorageService.save_stream(case1['id'], 'Master_EPC_Contract_14Jan2023.pdf', contract_text, 'application/pdf')
    f1 = Database.create_file({
      'case_id' => case1['id'],
      'filename' => f1_storage['filename'],
      'original_name' => 'Master_EPC_Contract_14Jan2023.pdf',
      'file_type' => 'PDF',
      'file_size' => f1_storage['file_size'],
      'storage_path' => f1_storage['storage_path'],
      'status' => 'Complete',
      'progress' => 100,
      'is_critical_evidence' => 0
    })
    Database.save_extraction(f1['id'], case1['id'], {
      "file_summary" => "Master EPC Contract dated 14.01.2023 specifying project milestones, Clause 19.3 BG conditional invocation, and Clause 28 New Delhi arbitration agreement.",
      "parties" => [
        { "name" => "M/s Apex Infrastructure Ltd.", "role" => "Petitioner / Contractor", "address" => "Barakhamba Road, Connaught Place, New Delhi", "relationship" => "EPC Contractor", "conflicts_or_notes" => "Sole Claimant" },
        { "name" => "M/s Delhi Metro Real Estate Pvt. Ltd.", "role" => "Respondent / Employer", "address" => "Nehru Place, New Delhi", "relationship" => "Project Developer", "conflicts_or_notes" => "Sole Respondent" }
      ],
      "jurisdiction" => {
        "relevant" => true,
        "basis" => "Express Jurisdiction & Seat of Arbitration Clause 28.1",
        "details" => "Contract executed at New Delhi with express submission to Courts of Delhi and New Delhi arbitral seat.",
        "court_reference" => "High Court of Delhi"
      },
      "chronology" => [
        {
          "date" => "2023-01-14",
          "event" => "Execution of Master EPC Contract for ₹98 Crores between Apex Infrastructure and Delhi Metro Real Estate.",
          "who_involved" => "Rajeshwar Sharma (Apex) and Vikramaditya Singhania (Delhi Metro)",
          "supporting_document_ref" => "Master_EPC_Contract_14Jan2023.pdf, Page 1",
          "legal_relevance" => "Establishes primary contractual matrix, Clause 19.3 conditional BG invocation, and Clause 28 Delhi arbitration clause.",
          "is_critical_flag" => false
        }
      ],
      "facts" => [
        "Binding contract executed between parties on 14.01.2023 for ₹98 Crores.",
        "Clause 19.3 explicitly prohibits encashment of Performance Bank Guarantees without 30-day cure notice.",
        "Clause 28 confers exclusive jurisdiction on High Court of Delhi."
      ],
      "cause_of_action" => {
        "act_or_omission" => "Contractual engagement defining milestone benchmarks and security instruments.",
        "when_occurred" => "14 January 2023",
        "where_occurred" => "New Delhi",
        "legal_claim_basis" => "Indian Contract Act, 1872 & Arbitration & Conciliation Act, 1996"
      },
      "people_entities" => ["M/s Apex Infrastructure Ltd.", "M/s Delhi Metro Real Estate Pvt. Ltd.", "Rajeshwar Sharma", "Vikramaditya Singhania"],
      "ambiguities" => ["Requires comparison against subsequent supplemental milestone extension letters."]
    })

    # Evidence File 2: Architect Milestone Completion Certificate
    cert_text = <<~TXT
      OFFICE OF SUNIL BHASIN & ASSOCIATES
      Chartered Architects & Project Monitoring Consultants
      Date: 28th June 2024
      
      MILESTONE COMPLETION CERTIFICATE (STAGE-IV)
      Project: Skyline Corporate Tower, Sector 62
      Contractor: M/s Apex Infrastructure Ltd.
      
      This is to certify that M/s Apex Infrastructure Ltd. has satisfactorily completed 85.4% of civil and structural work up to 24th Floor as on 25th June 2024.
      RA Bill No. 14 for ₹6,24,18,500/- is hereby certified for immediate disbursement by Employer under Clause 9.1.
      
      Remarks: Structural stability and material tests comply with IS 456:2000 standards. Delays in HVAC shafts occurred due to delayed clearance of Southern Corridor by Employer.
      (Signed) Ar. Sunil Bhasin, Lead Supervising Consultant
    TXT

    f2_storage = StorageService.save_stream(case1['id'], 'Architect_Milestone_Certificate_28June2024.pdf', cert_text, 'application/pdf')
    f2 = Database.create_file({
      'case_id' => case1['id'],
      'filename' => f2_storage['filename'],
      'original_name' => 'Architect_Milestone_Certificate_28June2024.pdf',
      'file_type' => 'PDF',
      'file_size' => f2_storage['file_size'],
      'storage_path' => f2_storage['storage_path'],
      'status' => 'Complete',
      'progress' => 100,
      'is_critical_evidence' => 1
    })
    Database.save_extraction(f2['id'], case1['id'], {
      "file_summary" => "Independent Architect Certificate dated 28.06.2024 certifying 85.4% project completion and RA Bill 14 approval for ₹6.24 Crores, noting delay was caused by Employer.",
      "parties" => [
        { "name" => "Ar. Sunil Bhasin", "role" => "Independent Supervising Architect / Expert Witness", "address" => "New Delhi", "relationship" => "Contractual Certifying Authority", "conflicts_or_notes" => "Neutral third-party expert" }
      ],
      "jurisdiction" => {
        "relevant" => true,
        "basis" => "Site inspection and certification of work within National Capital Region",
        "details" => "Work carried out and certified under Delhi supervisory contract.",
        "court_reference" => "High Court of Delhi"
      },
      "chronology" => [
        {
          "date" => "2024-06-28",
          "event" => "Supervising Architect Sunil Bhasin issues Milestone Completion Certificate confirming 85.4% structural completion and certifies RA Bill 14 of ₹6.24 Cr.",
          "who_involved" => "Ar. Sunil Bhasin, Apex Infrastructure, Delhi Metro Real Estate",
          "supporting_document_ref" => "Architect_Milestone_Certificate_28June2024.pdf, Page 1",
          "legal_relevance" => "Vital evidence disproving allegations of contractor abandonment; proves substantial performance and establishes Employer's unpaid liability.",
          "is_critical_flag" => true
        }
      ],
      "facts" => [
        "Independent Architect certified 85.4% structural completion on 28.06.2024.",
        "RA Bill 14 for ₹6,24,18,500/- remains wrongfully withheld by the Respondent.",
        "Architect notes that corridor handover delays were attributable solely to the Employer."
      ],
      "cause_of_action" => {
        "act_or_omission" => "Failure of Employer to disburse certified RA Bill No. 14 within mandatory 21 days of certification.",
        "when_occurred" => "19 July 2024 (expiration of 21-day payment window)",
        "where_occurred" => "New Delhi",
        "legal_claim_basis" => "Section 73 Indian Contract Act & Specific Relief Act"
      },
      "people_entities" => ["Ar. Sunil Bhasin", "M/s Apex Infrastructure Ltd.", "M/s Delhi Metro Real Estate Pvt. Ltd."],
      "ambiguities" => []
    })

    # Evidence File 3: WhatsApp Chat Export (Admission of Delay)
    chat_text = <<~TXT
      [12/07/2024, 14:15:22] Rajeshwar Sharma (Apex MD): Vikramaditya ji, RA Bill 14 is overdue by 3 weeks. Labour payments are held up. Please release the ₹6.24 Cr certified by Sunil Bhasin.
      [12/07/2024, 14:32:05] Vikramaditya Singhania (Delhi Metro MD): Rajeshwar, our bank credit line from HDFC got delayed because our board meeting was postponed. We will clear the ₹6.24 Cr by July 25. Please don't stop the glazing work.
      [12/07/2024, 14:34:10] Rajeshwar Sharma (Apex MD): We have kept 350 workers on site. Please confirm in writing by email so we can show suppliers.
      [12/07/2024, 14:40:18] Vikramaditya Singhania (Delhi Metro MD): You have my word. We know the southern corridor clearance was delayed from our side. Don't worry, no adverse action will be taken on BGs.
      [05/08/2024, 11:20:12] Rajeshwar Sharma (Apex MD): Vikramaditya ji, today is Aug 5. Payment not received and your CFO sent a termination warning! This is complete breach of faith.
      [05/08/2024, 11:45:00] Vikramaditya Singhania: Management is under pressure from investors. We have to invoke the BGs if project is not handed over by Aug 31.
    TXT

    f3_storage = StorageService.save_stream(case1['id'], 'WhatsApp_Chat_Export_Singhania_Rajeshwar.txt', chat_text, 'text/plain')
    f3 = Database.create_file({
      'case_id' => case1['id'],
      'filename' => f3_storage['filename'],
      'original_name' => 'WhatsApp_Chat_Export_Singhania_Rajeshwar.txt',
      'file_type' => 'WhatsApp/Text',
      'file_size' => f3_storage['file_size'],
      'storage_path' => f3_storage['storage_path'],
      'status' => 'Complete',
      'progress' => 100,
      'is_critical_evidence' => 1
    })
    Database.save_extraction(f3['id'], case1['id'], {
      "file_summary" => "WhatsApp chat transcript (July-August 2024) containing express admission by Respondent MD admitting fund liquidity issues, admitting corridor handover delay, and assuring no BG invocation.",
      "parties" => [
        { "name" => "Rajeshwar Sharma", "role" => "Managing Director, Apex (Claimant Representative)", "address" => "New Delhi", "relationship" => "Claimant MD", "conflicts_or_notes" => "Sender" },
        { "name" => "Vikramaditya Singhania", "role" => "Managing Director, Delhi Metro Real Estate (Respondent Representative)", "address" => "New Delhi / Gurugram", "relationship" => "Respondent MD", "conflicts_or_notes" => "Gave written admission of delay and assurance against BG invocation" }
      ],
      "jurisdiction" => {
        "relevant" => true,
        "basis" => "Electronic communication between directors based in New Delhi",
        "details" => "Demonstrates continuous business negotiations within Delhi territorial jurisdiction.",
        "court_reference" => "High Court of Delhi"
      },
      "chronology" => [
        {
          "date" => "2024-07-12",
          "event" => "Respondent MD Vikramaditya Singhania admits delay in corridor handover and promises payment of ₹6.24 Cr by July 25, assuring 'no adverse action on BGs'.",
          "who_involved" => "Vikramaditya Singhania, Rajeshwar Sharma",
          "supporting_document_ref" => "WhatsApp_Chat_Export_Singhania_Rajeshwar.txt, Message at 14:40 IST",
          "legal_relevance" => "Direct admission of liability under Section 17/18 Indian Evidence Act; establishes promissory estoppel against fraudulent BG invocation.",
          "is_critical_flag" => true
        },
        {
          "date" => "2024-08-05",
          "event" => "Respondent threatens invocation of Bank Guarantees despite non-payment of certified bills.",
          "who_involved" => "Vikramaditya Singhania, Rajeshwar Sharma",
          "supporting_document_ref" => "WhatsApp_Chat_Export_Singhania_Rajeshwar.txt, Message at 11:45 IST",
          "legal_relevance" => "Establishes immediate apprehension of irreparable injury justifying urgent Section 9 relief.",
          "is_critical_flag" => true
        }
      ],
      "facts" => [
        "Respondent admitted on 12.07.2024 that delays in corridor handover originated from their end.",
        "Respondent gave explicit assurance that Performance Bank Guarantees would not be invoked.",
        "Respondent reneged on assurance on 05.08.2024 under investor pressure."
      ],
      "cause_of_action" => {
        "act_or_omission" => "Threatened fraudulent encashment of Performance Bank Guarantees in bad faith despite clear admission of Respondent's own default.",
        "when_occurred" => "05 August 2024",
        "where_occurred" => "New Delhi",
        "legal_claim_basis" => "Section 9 Arbitration Act & Principles of Fraud/Irretrievable Injustice (BSES Rajdhani / Svenska Handelsbanken doctrine)"
      },
      "people_entities" => ["Rajeshwar Sharma", "Vikramaditya Singhania", "HDFC Bank"],
      "ambiguities" => [
        "Certificate under Section 65B of Indian Evidence Act / Section 63 BSA required at time of filing affidavit."
      ]
    })

    # Evidence File 4: Bank Guarantee Invocation Letter
    threat_text = <<~TXT
      DELHI METRO REAL ESTATE PVT. LTD.
      Registered Office: Level 4, Eros Corporate Tower, Nehru Place, New Delhi - 110019
      
      Ref: DMRE/BG/2024/089
      Date: 18th August 2024
      
      To:
      The Branch Manager,
      State Bank of India, Commercial Branch, Parliament Street, New Delhi - 110001
      
      SUBJECT: INVOCATION OF PERFORMANCE BANK GUARANTEE NO. 04981BG2300189 DATED 16.01.2023 FOR ₹14,50,00,000/- (RUPEES FOURTEEN CRORES FIFTY LAKHS ONLY)
      
      Dear Sir,
      We hereby invoke the captioned Performance Bank Guarantee issued on behalf of M/s Apex Infrastructure Ltd. for ₹14.50 Crores. You are called upon to immediately remit the sum of ₹14,50,00,000/- into our Current A/c No. 9102938491 with ICICI Bank, Nehru Place within 24 hours of receipt of this notice.
      
      Yours faithfully,
      For Delhi Metro Real Estate Pvt. Ltd.
      (Vikramaditya Singhania)
      Managing Director
      
      Copy to: M/s Apex Infrastructure Ltd.
    TXT

    f4_storage = StorageService.save_stream(case1['id'], 'Bank_Guarantee_Invocation_Threat_Letter_18Aug2024.pdf', threat_text, 'application/pdf')
    f4 = Database.create_file({
      'case_id' => case1['id'],
      'filename' => f4_storage['filename'],
      'original_name' => 'Bank_Guarantee_Invocation_Threat_Letter_18Aug2024.pdf',
      'file_type' => 'PDF',
      'file_size' => f4_storage['file_size'],
      'storage_path' => f4_storage['storage_path'],
      'status' => 'Complete',
      'progress' => 100,
      'is_critical_evidence' => 1
    })
    Database.save_extraction(f4['id'], case1['id'], {
      "file_summary" => "Formal BG Invocation Letter dated 18.08.2024 issued by Respondent to SBI demanding immediate remittance of ₹14.50 Crores in breach of Clause 19.3 notice period.",
      "parties" => [
        { "name" => "State Bank of India", "role" => "Guarantor Bank", "address" => "Parliament Street, New Delhi", "relationship" => "Issuing Bank of BG", "conflicts_or_notes" => "Proforma Respondent" },
        { "name" => "ICICI Bank", "role" => "Beneficiary Bank", "address" => "Nehru Place, New Delhi", "relationship" => "Recipient Bank", "conflicts_or_notes" => "Target of remittance" }
      ],
      "jurisdiction" => {
        "relevant" => true,
        "basis" => "Location of Issuing Bank Branch & Place of Invocation",
        "details" => "State Bank of India branch situated at Parliament Street, New Delhi within territorial jurisdiction of Delhi High Court.",
        "court_reference" => "High Court of Delhi"
      },
      "chronology" => [
        {
          "date" => "2024-08-18",
          "event" => "Respondent issues formal letter to State Bank of India invoking ₹14.50 Crore Bank Guarantee without 30-day cure notice.",
          "who_involved" => "Vikramaditya Singhania, State Bank of India, Apex Infrastructure",
          "supporting_document_ref" => "Bank_Guarantee_Invocation_Threat_Letter_18Aug2024.pdf, Page 1",
          "legal_relevance" => "Culmination of breach; triggers immediate cause of action for ex-parte ad-interim stay under Section 9 Arbitration Act.",
          "is_critical_flag" => true
        }
      ],
      "facts" => [
        "Respondent served unilateral invocation letter on State Bank of India on 18.08.2024.",
        "Invocation was made without serving the mandatory 30-day cure notice prescribed under Clause 19.3 of EPC Contract.",
        "Action constitutes egregious fraud and irretrievable injustice given that Respondent owes ₹6.24 Cr to Petitioner."
      ],
      "cause_of_action" => {
        "act_or_omission" => "Unlawful and fraudulent invocation of Performance Bank Guarantee No. 04981BG2300189 for ₹14.50 Crores.",
        "when_occurred" => "18 August 2024",
        "where_occurred" => "Parliament Street, New Delhi",
        "legal_claim_basis" => "Section 9 of Arbitration and Conciliation Act, 1996 & Indian Contract Act"
      },
      "people_entities" => ["State Bank of India", "ICICI Bank", "Vikramaditya Singhania", "M/s Apex Infrastructure Ltd."],
      "ambiguities" => []
    })

    # Run Aggregation for Case 1
    AggregationService.aggregate_case_evidence(case1['id'], f4['id'])

    # =========================================================================
    # CASE 2: Section 138 NI Act Cheque Dishonour Complaint
    # =========================================================================
    case2 = Database.create_case({
      'id' => 'case_grover_v_mehta',
      'name' => 'Sunil Grover v. Mehta Tex-Fab Industries & Anr.',
      'case_number' => 'CC No. 8912/2024',
      'court_name' => 'Court of Metropolitan Magistrate, Saket Courts, New Delhi',
      'objective' => 'Criminal complaint under Section 138 read with Section 142 of the Negotiable Instruments Act, 1881 for dishonour of Cheque No. 491028 for ₹48,50,000/- issued towards discharge of admitted debt for supply of textile spinning machinery.',
      'parties_info' => 'Complainant: Sunil Grover (Proprietor, Grover Industrial Spares, Okhla Phase III, New Delhi). Accused No. 1: Mehta Tex-Fab Industries (Partnership Firm, Okhla Industrial Area, New Delhi). Accused No. 2: Alok Mehta (Managing Partner & Drawer/Signatory of dishonoured cheque). Accused No. 3: Rajiv Mehta (Partner).',
      'hearing_date' => '2026-09-12',
      'tier' => 'pro'
    })

    cheque_text = <<~TXT
      STATE BANK OF INDIA - CHEQUE RETURN MEMO
      Branch: Okhla Industrial Area, New Delhi
      Date: 10th July 2024
      
      Cheque No: 491028
      Date of Cheque: 05.07.2024
      Amount: ₹48,50,000/- (Rupees Forty-Eight Lakhs Fifty Thousand Only)
      Drawer: Mehta Tex-Fab Industries (A/c No. 30192847192)
      Payee: Grover Industrial Spares
      
      REASON FOR RETURN: [X] 01 - FUNDS INSUFFICIENT
      (Authorized Officer Signature)
    TXT

    f2_1_storage = StorageService.save_stream(case2['id'], 'SBI_Cheque_Return_Memo_10July2024.pdf', cheque_text, 'application/pdf')
    f2_1 = Database.create_file({
      'case_id' => case2['id'],
      'filename' => f2_1_storage['filename'],
      'original_name' => 'SBI_Cheque_Return_Memo_10July2024.pdf',
      'file_type' => 'PDF',
      'file_size' => f2_1_storage['file_size'],
      'storage_path' => f2_1_storage['storage_path'],
      'status' => 'Complete',
      'progress' => 100,
      'is_critical_evidence' => 1
    })
    Database.save_extraction(f2_1['id'], case2['id'], {
      "file_summary" => "Bank Return Memo dated 10.07.2024 issued by SBI returning Cheque No. 491028 for ₹48,50,000/- with remark 'FUNDS INSUFFICIENT'.",
      "parties" => [
        { "name" => "Sunil Grover", "role" => "Complainant / Payee", "address" => "Okhla Phase III, New Delhi", "relationship" => "Proprietor of Grover Industrial Spares", "conflicts_or_notes" => "Holder in due course" },
        { "name" => "Mehta Tex-Fab Industries", "role" => "Accused No. 1 / Drawer Firm", "address" => "Okhla Industrial Area, New Delhi", "relationship" => "Partnership Firm", "conflicts_or_notes" => "Primary Accused" },
        { "name" => "Alok Mehta", "role" => "Accused No. 2 / Signatory Partner", "address" => "Greater Kailash II, New Delhi", "relationship" => "Managing Partner", "conflicts_or_notes" => "Signatory of dishonoured cheque" }
      ],
      "jurisdiction" => {
        "relevant" => true,
        "basis" => "Section 142(2)(a) NI Act (Place of Complainant's Bank Branch)",
        "details" => "Cheque presented and dishonoured at SBI Okhla Branch falling within territorial jurisdiction of Metropolitan Magistrate, Saket Courts.",
        "court_reference" => "Saket Courts, New Delhi"
      },
      "chronology" => [
        {
          "date" => "2024-07-05",
          "event" => "Accused Alok Mehta issues Cheque No. 491028 for ₹48,50,000/- drawn on HDFC Bank Okhla towards machinery invoice.",
          "who_involved" => "Alok Mehta, Sunil Grover",
          "supporting_document_ref" => "SBI_Cheque_Return_Memo_10July2024.pdf, Ref Cheque #491028",
          "legal_relevance" => "Issuance of negotiable instrument creates statutory presumption of legally enforceable debt under Section 139 NI Act.",
          "is_critical_flag" => false
        },
        {
          "date" => "2024-07-10",
          "event" => "SBI issues Bank Return Memo dishonouring Cheque No. 491028 due to 'Funds Insufficient'.",
          "who_involved" => "SBI Okhla Branch, Grover Industrial Spares, Mehta Tex-Fab",
          "supporting_document_ref" => "SBI_Cheque_Return_Memo_10July2024.pdf, Page 1",
          "legal_relevance" => "Conclusive proof of dishonour under Section 146 NI Act; starts 30-day statutory notice countdown.",
          "is_critical_flag" => true
        }
      ],
      "facts" => [
        "Cheque No. 491028 for ₹48,50,000/- was presented within validity period.",
        "Cheque was dishonoured on 10.07.2024 with official bank remark 'Funds Insufficient'.",
        "Statutory presumption under Sections 118 and 139 NI Act operates in favour of Complainant."
      ],
      "cause_of_action" => {
        "act_or_omission" => "Dishonour of cheque issued towards discharge of admitted debt.",
        "when_occurred" => "10 July 2024",
        "where_occurred" => "Okhla, New Delhi",
        "legal_claim_basis" => "Section 138, 141, 142 of Negotiable Instruments Act, 1881"
      },
      "people_entities" => ["Sunil Grover", "Alok Mehta", "Mehta Tex-Fab Industries", "State Bank of India"],
      "ambiguities" => []
    })

    # Evidence File 2 for Case 2: Statutory Demand Notice
    notice_text = <<~TXT
      ADVOCATE CHAMBERS OF KAPOOR & ASSOCIATES
      Chamber No. 418, Lawyers Chambers, Saket Courts Complex, New Delhi - 110017
      
      Date: 19th July 2024
      BY SPEED POST A.D. & EMAIL
      
      LEGAL DEMAND NOTICE UNDER SECTION 138 OF NEGOTIABLE INSTRUMENTS ACT, 1881
      
      To:
      1. M/s Mehta Tex-Fab Industries, Plot 44, Okhla Phase II, New Delhi - 110020
      2. Mr. Alok Mehta, Managing Partner, E-12, Greater Kailash II, New Delhi - 110048
      
      Under instructions from our client, Mr. Sunil Grover, we hereby call upon you to pay the sum of ₹48,50,000/- (Rupees Forty-Eight Lakhs Fifty Thousand Only) within 15 (fifteen) days of receipt of this notice, failing which our client shall initiate criminal prosecution under Section 138 & 141 of the Negotiable Instruments Act, 1881.
      
      (Advocate Rohit Kapoor)
      Counsel for Complainant
    TXT

    f2_2_storage = StorageService.save_stream(case2['id'], 'Statutory_Demand_Notice_19July2024.pdf', notice_text, 'application/pdf')
    f2_2 = Database.create_file({
      'case_id' => case2['id'],
      'filename' => f2_2_storage['filename'],
      'original_name' => 'Statutory_Demand_Notice_19July2024.pdf',
      'file_type' => 'PDF',
      'file_size' => f2_2_storage['file_size'],
      'storage_path' => f2_2_storage['storage_path'],
      'status' => 'Complete',
      'progress' => 100,
      'is_critical_evidence' => 1
    })
    Database.save_extraction(f2_2['id'], case2['id'], {
      "file_summary" => "Statutory Demand Notice dated 19.07.2024 served via Speed Post and Email demanding ₹48.50 Lakhs within mandatory 15-day period.",
      "parties" => [
        { "name" => "Advocate Rohit Kapoor", "role" => "Legal Counsel for Complainant", "address" => "Saket Courts Complex, New Delhi", "relationship" => "Legal Representative", "conflicts_or_notes" => "Notice Drafter" }
      ],
      "jurisdiction" => {
        "relevant" => true,
        "basis" => "Service of statutory notice within Delhi jurisdiction",
        "details" => "Speed post dispatched and delivered within New Delhi postal circles.",
        "court_reference" => "Saket District Courts, New Delhi"
      },
      "chronology" => [
        {
          "date" => "2024-07-19",
          "event" => "Statutory Demand Notice issued to Accused demanding payment of ₹48,50,000/- within 15 days.",
          "who_involved" => "Advocate Rohit Kapoor, Sunil Grover, Alok Mehta",
          "supporting_document_ref" => "Statutory_Demand_Notice_19July2024.pdf, Page 1",
          "legal_relevance" => "Fulfilment of mandatory pre-condition under Section 138(b) NI Act within 30 days of dishonour memo.",
          "is_critical_flag" => true
        },
        {
          "date" => "2024-08-04",
          "event" => "Expiration of 15-day notice period with zero payment received from Accused.",
          "who_involved" => "Mehta Tex-Fab Industries, Sunil Grover",
          "supporting_document_ref" => "Statutory_Demand_Notice_19July2024.pdf, Speed Post Tracking ED892182910IN",
          "legal_relevance" => "Offence under Section 138 NI Act crystallizes on 05.08.2024; starts 30-day limitation for filing complaint.",
          "is_critical_flag" => true
        }
      ],
      "facts" => [
        "Statutory notice was dispatched on 19.07.2024, within 9 days of dishonour memo (well within 30-day limit).",
        "Accused received notice and failed to tender payment within mandatory 15 days.",
        "Cause of action for criminal complaint fully accrued on 05.08.2024."
      ],
      "cause_of_action" => {
        "act_or_omission" => "Failure of drawer to pay the cheque amount of ₹48,50,000/- within 15 days of receipt of statutory demand notice.",
        "when_occurred" => "05 August 2024",
        "where_occurred" => "Saket / Okhla, New Delhi",
        "legal_claim_basis" => "Section 138 read with Section 142 of Negotiable Instruments Act, 1881"
      },
      "people_entities" => ["Advocate Rohit Kapoor", "Sunil Grover", "Alok Mehta", "Mehta Tex-Fab Industries"],
      "ambiguities" => []
    })

    AggregationService.aggregate_case_evidence(case2['id'], f2_2['id'])

    puts "Seed data creation complete! Cases loaded: #{Database.list_cases.size}"
  end
end
