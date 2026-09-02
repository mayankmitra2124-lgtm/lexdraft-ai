from pydantic import BaseModel, Field
from typing import Optional, Any, Dict, List, Tuple
from enum import Enum

class EvidenceType(str, Enum):
    PDF = "PDF"
    DOC = "DOC"
    IMAGE = "IMAGE"
    CHAT = "CHAT"
    AUDIO = "AUDIO"
    VIDEO = "VIDEO"

class SourceRef(BaseModel):
    doc_id: str
    page: Optional[int] = None
    bbox: Optional[Tuple[float, float, float, float]] = None
    msg_id: Optional[str] = None
    start_time: Optional[float] = None
    end_time: Optional[float] = None

class EvidenceObject(BaseModel):
    evidence_id: str
    evidence_type: EvidenceType
    content: str
    metadata: Dict[str, Any] = Field(default_factory=dict)
    source_ref: SourceRef
    original_file_uri: str

class TranscriptSegment(BaseModel):
    speaker: Optional[str] = None
    text: str
    start_time: float
    end_time: float
    confidence: float

class FieldExtraction(BaseModel):
    field_name: str
    raw_value: str
    normalized_value: Any
    model: str
    confidence: float
    source_ref: SourceRef

class ValidationFlag(BaseModel):
    flag_type: str
    description: str
    severity: str

class DecisionStatus(str, Enum):
    VERIFIED = "VERIFIED"
    PARTIALLY_SUPPORTED = "PARTIALLY_SUPPORTED"
    CONFLICTED = "CONFLICTED"
    UNVERIFIED = "UNVERIFIED"

class DecisionAction(str, Enum):
    AUTO_ADMIT = "AUTO_ADMIT"
    REPROCESS = "REPROCESS"
    FLAG_HUMAN_REVIEW = "FLAG_HUMAN_REVIEW"

class EvidenceDecision(BaseModel):
    evidence_id: str
    status: DecisionStatus
    action: DecisionAction
    confidence_score: float
    reasoning: str
    flags: List[ValidationFlag] = Field(default_factory=list)
