from __future__ import annotations

import importlib.util
import re
import sys
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
AUDIT_PATH = REPO_ROOT / "tools" / "ml" / "audit_dataset.py"
SPEC = importlib.util.spec_from_file_location("ts7_schema_audit", AUDIT_PATH)
assert SPEC and SPEC.loader
AUDIT = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = AUDIT
SPEC.loader.exec_module(AUDIT)


class SchemaV2ContractTests(unittest.TestCase):
    def test_mql_header_matches_python_audit_contract(self) -> None:
        source = (
            REPO_ROOT / "Include" / "TS7" / "ML" / "DatasetLogger.mqh"
        ).read_text(encoding="utf-8")
        version = re.search(
            r'TS7_ML_SCHEMA_VERSION\s*=\s*"([^"]+)"', source
        )
        self.assertIsNotNone(version)
        self.assertEqual(version.group(1), AUDIT.SCHEMA_VERSION_V2)

        header_match = re.search(
            r"string\s+MlCandidateHeader\(\)\s*\{(.*?)"
            r"bool\s+MlInitializeDatasetLogger",
            source,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(header_match)
        literals = re.findall(r'"([^"]*)"', header_match.group(1))
        header = tuple("".join(literals).split(","))

        self.assertEqual(header, AUDIT.CANDIDATE_HEADER_V2)
        self.assertEqual(len(header), 97)
        self.assertEqual(len(header), len(set(header)))

    def test_v2_fields_are_written_by_candidate_row(self) -> None:
        source = (
            REPO_ROOT / "Include" / "TS7" / "ML" / "DatasetLogger.mqh"
        ).read_text(encoding="utf-8")
        row_match = re.search(
            r"string\s+row\s*=(.*?)MlWriteRow\(g_mlCandidateFile,\s*row\)",
            source,
            flags=re.DOTALL,
        )
        self.assertIsNotNone(row_match)
        row_source = row_match.group(1)

        expected_tokens = {
            "FeatureReadyV2": "featureReadyV2",
            "AdxValue": "adxValue",
            "AdxSlope1": "adxSlope1",
            "DiGapDir": "diGapDir",
            "DiGapSlopeDir": "diGapSlopeDir",
            "CciSlope1Dir": "cciSlope1Dir",
            "CciSlope3Dir": "cciSlope3Dir",
            "ATRChange1": "atrChange1",
            "HiLoDistanceATR": "hiloDistanceAtr",
            "HiLoLineSlopeATR": "hiloLineSlopeAtr",
            "PsarDistanceATR": "psarDistanceAtr",
            "PsarLineSlopeATR": "psarLineSlopeAtr",
            "STDistanceATR": "stDistanceAtr",
            "STLineSlopeATR": "stLineSlopeAtr",
            "STMTFDistanceATR": "stMtfDistanceAtr",
            "STMTFLineSlopeATR": "stMtfLineSlopeAtr",
        }
        for field, token in expected_tokens.items():
            with self.subTest(field=field):
                self.assertIn(token, row_source)


if __name__ == "__main__":
    unittest.main()
