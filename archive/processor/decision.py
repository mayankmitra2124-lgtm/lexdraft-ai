from processor.schemas import EvidenceDecision, DecisionStatus, DecisionAction, ValidationFlag
from typing import List, Dict, Any

class DecisionEngine:
    """
    Phase 7: Deterministic rule table evaluating Collation + Validator + Risk scores.
    NO LLM inside this decision logic.
    """
    
    def evaluate(self, evidence_id: str, collated_fields: List[Dict[str, Any]], flags: List[ValidationFlag], risk_score: str) -> EvidenceDecision:
        high_severity_flags = [f for f in flags if f.severity == "HIGH"]
        escalated_fields = [f for f in collated_fields if f.get("resolution") == "ESCALATE"]
        
        if high_severity_flags or escalated_fields:
            return EvidenceDecision(
                evidence_id=evidence_id,
                status=DecisionStatus.CONFLICTED,
                action=DecisionAction.FLAG_HUMAN_REVIEW,
                confidence_score=0.4,
                reasoning="High severity validation flags or escalation from collation engine.",
                flags=flags
            )
            
        if flags: # minor flags
            return EvidenceDecision(
                evidence_id=evidence_id,
                status=DecisionStatus.PARTIALLY_SUPPORTED,
                action=DecisionAction.FLAG_HUMAN_REVIEW if risk_score == "High" else DecisionAction.AUTO_ADMIT,
                confidence_score=0.75,
                reasoning="Minor validation flags present. Admitted based on risk score.",
                flags=flags
            )
            
        return EvidenceDecision(
            evidence_id=evidence_id,
            status=DecisionStatus.VERIFIED,
            action=DecisionAction.AUTO_ADMIT,
            confidence_score=0.98,
            reasoning="All fields confirmed with no validation flags.",
            flags=[]
        )
