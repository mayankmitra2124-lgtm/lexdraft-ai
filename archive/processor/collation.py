from typing import List, Dict, Any, Tuple
from processor.schemas import FieldExtraction
from collections import defaultdict
import logging

logger = logging.getLogger(__name__)

# Reliability weights updated via Phase 10 Audit Log loop
MODEL_RELIABILITY = {
    "Gemini": 1.0,
    "GPT": 1.1,
    "Claude": 1.15
}

class CollationEngine:
    """
    Phase 5: Pure Python deterministic logic, zero LLM calls.
    """
    
    def normalize_for_comparison(self, value: Any) -> str:
        # Basic normalization for conflict detection
        if isinstance(value, str):
            return value.strip().lower()
        return str(value)

    def determine_conflict_type(self, extractions: List[FieldExtraction]) -> str:
        if not extractions:
            return "NO_DATA"
            
        norms = [self.normalize_for_comparison(e.normalized_value) for e in extractions]
        unique_norms = set(norms)
        
        if len(unique_norms) == 1:
            return "AGREEMENT"
            
        # Check abstention (e.g. one model returned None/Empty)
        if any(not n for n in norms):
            return "MODEL_ABSTENTION"
            
        # If lengths are identical but small case diffs remain, it might be formatting, 
        # but normalize_for_comparison handles basic cases. Assume true mismatch.
        return "TRUE_MISMATCH"

    def resolve_mismatch(self, extractions: List[FieldExtraction]) -> Tuple[Any, str]:
        # Weighted voting on true mismatches
        votes = defaultdict(float)
        value_map = {}
        
        for ext in extractions:
            norm = self.normalize_for_comparison(ext.normalized_value)
            weight = MODEL_RELIABILITY.get(ext.model, 1.0) * ext.confidence
            votes[norm] += weight
            value_map[norm] = ext.normalized_value
            
        winning_norm = max(votes, key=votes.get)
        
        # Check if the win is marginal
        sorted_votes = sorted(votes.values(), reverse=True)
        if len(sorted_votes) > 1 and sorted_votes[0] - sorted_votes[1] < 0.2:
            return None, "ESCALATE"
            
        return value_map[winning_norm], "CONFIRMED_VOTING"

    def collate_field(self, field_name: str, extractions: List[FieldExtraction]) -> Dict[str, Any]:
        conflict_type = self.determine_conflict_type(extractions)
        
        if conflict_type == "AGREEMENT":
            return {
                "field_name": field_name,
                "resolved_value": extractions[0].normalized_value,
                "resolution": "CONFIRMED_AGREEMENT",
                "source_ref": extractions[0].source_ref.dict()
            }
            
        resolved_val, resolution = self.resolve_mismatch(extractions)
        
        return {
            "field_name": field_name,
            "resolved_value": resolved_val,
            "resolution": resolution,
            "source_ref": extractions[0].source_ref.dict() if resolved_val else None
        }
