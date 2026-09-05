from celery import Celery
import logging
import time

logger = logging.getLogger(__name__)

# Configure Celery with Redis as broker and backend
celery_app = Celery(
    "evidence_processor",
    broker="redis://localhost:6379/0",
    backend="redis://localhost:6379/1"
)

celery_app.conf.update(
    task_serializer="json",
    accept_content=["json"],
    result_serializer="json",
    timezone="UTC",
    enable_utc=True,
)

@celery_app.task(name="chunk_media")
def chunk_media_task(evidence_id: str, file_path: str):
    """
    Phase 2: Port of media_chunker.rb to Python.
    Segments audio/video files into 10-15 minute chunks for transcription.
    """
    logger.info(f"Chunking media for {evidence_id} at {file_path}")
    # Mocking chunking process
    time.sleep(2)
    
    # Trigger transcription
    transcribe_media_task.delay(evidence_id, [f"{file_path}_chunk1", f"{file_path}_chunk2"])
    return f"Chunked {evidence_id}"

@celery_app.task(name="transcribe_media")
def transcribe_media_task(evidence_id: str, chunk_paths: list):
    """
    Phase 2: Transcription layer mapping Google Speech-to-Text with Diarization
    to the TranscriptSegment schema.
    """
    logger.info(f"Transcribing {len(chunk_paths)} chunks for {evidence_id}")
    # Mocking transcription
    time.sleep(5)
    return "Transcription Complete"
