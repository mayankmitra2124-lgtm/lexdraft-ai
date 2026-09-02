import asyncio
import json
import logging
from typing import Dict, Any

logger = logging.getLogger(__name__)

# Phase 11: Decommissioning & Parallel Validation
# Compares outputs of the legacy Ruby engine with the new Python pipeline.

LEGACY_RUBY_API = "http://localhost:3000/api/ingest_legacy"
NEW_PYTHON_API = "http://localhost:8000/api/v1/ingest"

class ParallelValidator:
    def diff_extractions(self, legacy_output: Dict[str, Any], new_output: Dict[str, Any]) -> Dict[str, Any]:
        """
        Deep diff between the flat Ruby extraction and the multi-model graph output.
        """
        diff = {
            "missing_in_new": [],
            "missing_in_legacy": [],
            "value_mismatches": [],
            "validation_flags_triggered": new_output.get("flags", [])
        }
        
        legacy_timeline = legacy_output.get("timeline", [])
        new_timeline = new_output.get("timeline", [])
        
        # In a real scenario, this would align events by temporal proximity and check for drift
        if len(legacy_timeline) != len(new_timeline):
            logger.warning(f"Event count mismatch: Legacy={len(legacy_timeline)}, New={len(new_timeline)}")
            
        return diff

    async def run_parallel_validation_bundle(self, test_files: list[str]):
        """
        Runs N sample evidence bundles through both pipelines and logs diffs.
        """
        results = []
        for file_path in test_files:
            logger.info(f"Running parallel validation for {file_path}")
            # Mocking the HTTP requests to both pipelines
            legacy_result = {"timeline": [{"event": "Contract Signed", "date": "2024-01-01"}]}
            new_result = {
                "timeline": [{"event": "Contract Signed", "date": "2024-01-01", "source_ref": {"doc_id": "1"}}],
                "flags": []
            }
            
            diff = self.diff_extractions(legacy_result, new_result)
            results.append({
                "file": file_path,
                "diff": diff
            })
            
        return results

if __name__ == "__main__":
    validator = ParallelValidator()
    # To run this, place sample files in a directory and pass them here
    asyncio.run(validator.run_parallel_validation_bundle(["test_contract.pdf", "whatsapp_chat.txt"]))
