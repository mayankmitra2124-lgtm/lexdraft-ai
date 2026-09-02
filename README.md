# Case Evidence Organizer (Feature 1)

**Case Evidence Organizer** is a purpose-built legal technology web application designed for Indian advocates, senior counsels, and litigation firms. It automates the ingestion of mixed-format case evidence (up to 4GB per case), extracts structured legal facts via Gemini's multi-modal File API, and synthesizes court-ready master summaries featuring an interactive chronological timeline, critical evidence tags, and visual diff tracking.

---

## 🏛️ System Architecture

```
                               ┌──────────────────────────────────────────────┐
                               │             Case Setup Screen                │
                               │  - Case Objective (Free text prompt)         │
                               │  - Case & Parties Info (Free text prompt)    │
                               └──────────────────────┬───────────────────────┘
                                                      │
                                                      ▼
 ┌───────────────────────────┐         ┌──────────────────────────────┐
 │   Mixed Evidence Upload   │ ──────> │ Local Object Storage / Vault │
 │ (PDFs, WhatsApp, Audio,   │         │ (Streaming writes, up to 4GB)│
 │   Video, Images, Memos)   │         └──────────────┬───────────────┘
 └───────────────────────────┘                        │
                                                      ▼
                                       ┌──────────────────────────────┐
                                       │ 10-15 Min Media Chunker      │
                                       │ (Splits large media / chats) │
                                       └──────────────┬───────────────┘
                                                      │
                                                      ▼
                                       ┌──────────────────────────────┐
                                       │ Parallel Gemini Extraction   │
                                       │ (Shared Context + File API)  │
                                       └──────────────┬───────────────┘
                                                      │
                                                      ▼
                                       ┌──────────────────────────────┐
                                       │ Incremental Aggregation      │
                                       │ (Lightweight Master Merge)   │
                                       └──────────────┬───────────────┘
                                                      │
              ┌───────────────────────────────────────┴───────────────────────────────────────┐
              ▼                                       ▼                                       ▼
┌───────────────────────────┐           ┌───────────────────────────┐           ┌───────────────────────────┐
│ Master Chronology Table   │           │ Material Facts Narrative  │           │ "What Changed" Diff Audit │
│ & Visual Timeline Nodes   │           │ & Jurisdiction Grounds    │           │ & Court-Ready Export View │
└───────────────────────────┘           └───────────────────────────┘           └───────────────────────────┘
```

---

## 🚀 Key Features Built

### 1. Case Setup Screen & Reusable Context
- **Case Objective**: Prompt: *"What is this case about, and what outcome are you seeking?"*
- **Case & Parties Information**: Prompt: *"Share whatever you know about the parties involved — names, roles (petitioner, respondent, witness, accused), relationships, and any relevant background."*
- Both fields are permanently editable and automatically injected into every subsequent Gemini extraction prompt as shared baseline context.
- Includes manual court calendar / upcoming hearing date tracker.

### 2. Evidence Upload & Ingestion Pipeline (Up to 4GB per Case)
- Supports mixed formats: PDFs, images (JPEG/PNG/WebP), WhatsApp exports (`.txt`), audio (`.mp3`, `.m4a`, `.wav`), video (`.mp4`), and word documents.
- Files are streamed directly into an isolated object storage vault (`uploads/`) — never held as a monolithic memory blob.
- Large media files (>10MB / >15 min) are segmented into 10–15 minute discrete chunks to maintain high extraction speed and respect token windows.
- All file extraction tasks execute in parallel on a background worker queue with live status tracking (`Queued` $\to$ `Processing` $\to$ `Complete` $\to$ `Failed (with retry)`).
- Enforces configurable tier limits (Basic: 500MB / 10 files; Pro: 4GB / 100 files).

### 3. Gemini Extraction Schema (JSON)
Each file is analyzed in the context of Indian substantive and procedural laws (CPC, Indian Evidence Act / BSA, Negotiable Instruments Act, Commercial Courts Act, Arbitration Act) to produce:
- **Parties**: Names, addresses, petitioner/respondent/accused/witness status, relationships, and newly revealed party details.
- **Jurisdiction**: Territorial, pecuniary, and statutory basis flagged *only* when the evidence specifically offers proof (no guessing).
- **Chronology of Events**: Exact date, event description, actors, precise document reference (page number or timestamp), legal relevance under Indian law, and critical evidence flag.
- **Facts**: Material narrative summary of what the file proves.
- **Cause of Action Indicators**: Specific acts or omissions, dates, and locations.
- **File Summary**: One-line synthesis.
- **Ambiguity Flags**: Explicit warnings when handwriting is illegible, timestamps are unverified, or Section 65B electronic evidence certificates are required.

### 4. Incremental Aggregation & "What Changed" Diff Engine
- When a new evidence file is uploaded to an existing case, **only that new file is processed** — the entire case is never re-processed from scratch.
- The aggregation engine merges the new structured output into the existing Master Summary:
  - Deduplicates parties.
  - Consolidates jurisdiction grounds.
  - Inserts new events into the strictly sorted master timeline.
  - Updates the coherent narrative of material facts.
- **Visual Diff Highlighting**: Visually flags newly added timeline rows with green/gold badges, highlights altered factual paragraphs, and logs an audit trail in the **"What Changed"** tab.
- **Interactive Citations**: Clicking any supporting document reference in the timeline opens the citation inspector showing the exact source snippet.

### 5. Indian Legal Tech UI & Design Direction
- **Charcoal & Gold Legal Palette**: `#141416` base surfaces with refined `#2F2F37` borders and warm yellow `#F4B400` / `#FFC72C` accents for critical evidence tags and timeline nodes.
- **Typography**: Classic Indian court serif headings (`Cinzel` / `Georgia`) with ultra-crisp sans-serif body (`Inter`).
- **Court-Ready Export**: Formats the entire master summary into a formal legal brief matching Indian High Court petition standards (Court Header, Memo of Parties, Synopsis, List of Dates & Events, List of Annexures) with 1-click **Print to PDF** and **Copy Draft**.

---

## 🏃 Running the Application

### 1. Launch the Server
```bash
./start.sh
# Or directly:
ruby server.rb
```

### 2. Access the Web App
Open your browser and navigate to:
```
http://localhost:8080
```

### 3. Pre-loaded Landmark Cases
The application automatically seeds two realistic Indian legal cases for instant testing:
1. **Commercial Injunction & Arbitration**: *M/s Apex Infrastructure Ltd. v. Delhi Metro Real Estate Pvt. Ltd.* (High Court of Delhi, Section 9 Arbitration Petition involving EPC contract, Architect milestone certificates, WhatsApp admissions, and threatened Bank Guarantee invocation).
2. **Negotiable Instruments Act**: *Sunil Grover v. Mehta Tex-Fab Industries & Anr.* (Saket District Courts, Section 138 Cheque Dishonour, Bank Return Memo, and Statutory 15-day Demand Notice).

---

## 🔮 Roadmap: Feature 2 Architecture (RAG Strategy Layer)

The system is designed with modular separation to easily plug in **Feature 2 (RAG-based Strategy Layer over Indian Case Law)**:
- `extractions` and `master_summaries` tables provide structured, clean JSON chunks ideal for vector embedding generation.
- Future endpoints (`/api/cases/:id/strategy` and `/api/cases/:id/precedents`) can query Indian Supreme Court & High Court SCC/Manupatra vector databases using the consolidated **Cause of Action** and **Facts Narrative** as semantic query vectors.
