from __future__ import annotations

import re
import unittest
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]


class RecoveryHardAbortContractTests(unittest.TestCase):
    def test_feature_is_default_off_and_grouped_with_risk_controls(self) -> None:
        source = (REPO_ROOT / "Include" / "TS7" / "Inputs.mqh").read_text()
        group = source.index('input group "Recovery Risk Control"')
        setting = source.index("InpRecoveryAbortBeforeLevel")

        self.assertGreater(setting, group)
        self.assertRegex(
            source,
            r"InpRecoveryAbortBeforeLevel\s*=\s*0\s*;",
        )

    def test_every_grid_entry_path_checks_abort_before_order(self) -> None:
        source = (
            REPO_ROOT / "Include" / "TS7" / "Recovery" / "RecoveryGrid.mqh"
        ).read_text()

        self.assertEqual(
            len(re.findall(r"TryTriggerRecoveryHardAbort\(", source)),
            4,
        )
        for order_call in ("g_trade.Buy", "g_trade.Sell"):
            self.assertIn(order_call, source)

    def test_abort_is_fail_closed_and_has_distinct_completion_reason(self) -> None:
        utils = (
            REPO_ROOT / "Include" / "TS7" / "Recovery" / "RecoveryUtils.mqh"
        ).read_text()
        manager = (
            REPO_ROOT / "Include" / "TS7" / "Recovery" / "RecoveryManager.mqh"
        ).read_text()

        self.assertIn('ResetRecoveryState("HARD_ABORT_BEFORE_LEVEL")', utils)
        self.assertIn("g_recoveryHardAbortPending", manager)
        self.assertIn("ContinueRecoveryHardAbortCleanup();", manager)
        self.assertIn("IsRecoveryComment(g_positionInfo.Comment())", utils)


if __name__ == "__main__":
    unittest.main()
