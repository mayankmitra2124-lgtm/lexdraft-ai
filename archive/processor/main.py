from fastapi import FastAPI, UploadFile, File, BackgroundTasks, HTTPException
from pydantic import BaseModel
import shutil
import os
import uuid
import hashlib
import asyncio
from typing import Optional, Dict, Any

from processor.schemas import EvidenceObject, SourceRef, EvidenceType
from processor.transcription import SpeechToTextService
from processor.orchestrator import MultiModelOrchestrator

app = FastAPI(title="LexDraft Evidence Processor")

# S3 Storage mock directory for local dev
STORAGE_DIR = "./s3_mock"
os.makedirs(STORAGE_DIR, exist_ok=True)

stt_service = SpeechToTextService()
orchestrator = MultiModelOrchestrator()

class IngestionResponse(BaseModel):
    evidence_id: str
    status: str
    file_type: str
    asr_completed: bool = False
    transcript_preview: Optional[str] = None

def generate_evidence_id(file_path: str) -> str:
    sha256_hash = hashlib.sha256()
    with open(file_path, "rb") as f:
        for byte_block in iter(lambda: f.read(4096), b""):
            sha256_hash.update(byte_block)
    return sha256_hash.hexdigest()

def process_file_task(evidence_id: str, file_path: str, file_type: str):
    """
    Ingestion & Verification Pipeline:
    For Audio & Video: Speech-to-Text ASR executes BEFORE multi-model ingestion.
    The resulting diarized, timestamped transcript is then fed into the Multi-Model Orchestrator.
    """
    content = ""
    metadata: Dict[str, Any] = {"file_type": file_type, "file_path": file_path}

    # Step 1: Speech-to-Text ASR for Audio/Video BEFORE Multi-Model Engine Ingestion
    if file_type.upper() in ["AUDIO", "VIDEO"]:
        print(f"[Processor] Executing Speech-to-Text ASR with Diarization on {evidence_id}...")
        asr_result = stt_service.transcribe(file_path, file_type)
        content = asr_result["full_transcript"]
        metadata["asr_completed"] = True
        metadata["transcript_segments"] = [s.dict() for s in asr_result["segments"]]
        print(f"[Processor] Speech-to-Text completed. Transcribed {len(asr_result['segments'])} diarized segments.")
    else:
        try:
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read(16384)
        except Exception as e:
            content = f"File content for {evidence_id}"

    # Step 2: Construct Normalized EvidenceObject
    ev_type = EvidenceType.AUDIO if file_type.upper() == "AUDIO" else (
        EvidenceType.VIDEO if file_type.upper() == "VIDEO" else EvidenceType.PDF
    )
    evidence = EvidenceObject(
        evidence_id=evidence_id,
        evidence_type=ev_type,
        content=content,
        metadata=metadata,
        source_ref=SourceRef(doc_id=evidence_id),
        original_file_uri=file_path
    )

    # Step 3: Multi-Model Ingestion (Gemini + GPT + Claude fan-out)
    print(f"[Processor] Ingesting normalized evidence (with ASR transcript) into Multi-Model Orchestrator...")
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    try:
        extractions = loop.run_until_complete(
            orchestrator.execute_extraction(evidence, {"name": "legal_facts"})
        )
        print(f"[Processor] Multi-model extraction completed: {len(extractions)} findings.")
    finally:
        loop.close()

@app.post("/api/v1/ingest", response_model=IngestionResponse)
async def ingest_evidence(background_tasks: BackgroundTasks, file: UploadFile = File(...)):
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file provided")
    
    # Classify basic type
    file_type = "UNKNOWN"
    content_t = (file.content_type or "").lower()
    ext = os.path.splitext(file.filename)[1].lower()

    if "pdf" in content_t or ext == ".pdf": file_type = "PDF"
    elif "image" in content_t or ext in [".jpg", ".jpeg", ".png", ".webp"]: file_type = "IMAGE"
    elif "audio" in content_t or ext in [".mp3", ".wav", ".m4a", ".ogg"]: file_type = "AUDIO"
    elif "video" in content_t or ext in [".mp4", ".mov", ".mkv", ".webm"]: file_type = "VIDEO"
    elif "text" in content_t or ext == ".txt": file_type = "CHAT"
    
    # Save stream to local S3 mock
    temp_filename = f"{uuid.uuid4()}_{file.filename}"
    temp_path = os.path.join(STORAGE_DIR, temp_filename)
    
    with open(temp_path, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    evidence_id = generate_evidence_id(temp_path)
    
    # Dispatch processing (ASR executes first for audio/video before multi-model ingestion)
    background_tasks.add_task(process_file_task, evidence_id, temp_path, file_type)
    
    return IngestionResponse(
        evidence_id=evidence_id,
        status="INGESTED_SPEECH_TO_TEXT_QUEUED" if file_type in ["AUDIO", "VIDEO"] else "INGESTED_PENDING_PROCESSING",
        file_type=file_type,
        asr_completed=False
    )

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
