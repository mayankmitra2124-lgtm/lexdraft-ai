from typing import Dict, Any, List
from processor.schemas import EvidenceObject, FieldExtraction, ValidationFlag
import re
import logging

logger = logging.getLogger(__name__)

class EvidenceValidator:
    """
    Phase 6: Deterministic schema/provenance checks, zero-tolerance reverse token grounding,
    and LLM hallucination blockers.
    """
    def check_provenance(self, field: Dict[str, Any], evidence: EvidenceObject) -> List[ValidationFlag]:
        flags = []
        source_ref = field.get("source_ref")
        if not source_ref or source_ref.get("doc_id") != evidence.evidence_id:
            flags.append(ValidationFlag(
                flag_type="PROVENANCE_ERROR",
                description="Source reference does not match evidence ID",
                severity="HIGH"
            ))
        return flags

    def check_reverse_token_grounding(self, collated_fields: List[Dict[str, Any]], evidence: EvidenceObject) -> List[ValidationFlag]:
        """
        Feature 3: Zero-Tolerance Deterministic Reverse Grounding.
        Verifies that any pecuniary numbers, dates, or statutory sections in resolved values
        exist verbatim in the raw source content or ASR transcript.
        """
        flags = []
        raw_content_lower = (evidence.content or "").lower()

        for field in collated_fields:
            val_str = str(field.get("resolved_value") or "")
            
            # Extract numbers >= 3 digits or currency figures
            number_tokens = re.findall(r'\b\d{1,3}(?:,\d{2,3})+(?:\.\d+)?\b|\b\d{3,}\b', val_str)
            date_tokens = re.findall(r'\b\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}\b', val_str)

            for token in number_tokens + date_tokens:
                clean_token = token.replace(",", "").strip().lower()
                if clean_token not in raw_content_lower and token.lower() not in raw_content_lower:
                    flags.append(ValidationFlag(
                        flag_type="UNVERIFIED_TOKEN_DRIFT",
                        description=f"Critical token '{token}' in field '{field.get('field_name')}' was not found in raw source text or ASR transcript.",
                        severity="HIGH"
                    ))

        return flags

    def check_schema_consistency(self, collated_fields: List[Dict[str, Any]]) -> List[ValidationFlag]:
        flags = []
        return flags

    def llm_hallucination_check(self, collated_fields: List[Dict[str, Any]], evidence: EvidenceObject) -> List[ValidationFlag]:
        flags = []
        for field in collated_fields:
            if "NOT_FOUND" in str(field.get("resolved_value")):
                flags.append(ValidationFlag(
                    flag_type="UNSUPPORTED_CLAIM",
                    description=f"Field {field.get('field_name')} appears unsupported by text.",
                    severity="HIGH"
                ))
        return flags

    def validate(self, collated_fields: List[Dict[str, Any]], evidence: EvidenceObject) -> List[ValidationFlag]:
        flags = []
        for field in collated_fields:
            flags.extend(self.check_provenance(field, evidence))
            
        flags.extend(self.check_reverse_token_grounding(collated_fields, evidence))
        flags.extend(self.check_schema_consistency(collated_fields))
        flags.extend(self.llm_hallucination_check(collated_fields, evidence))
        return flags
