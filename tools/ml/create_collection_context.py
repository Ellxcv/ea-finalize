#!/usr/bin/env python3
"""Create the auditable sidecar required for a retained TS7 Strategy Tester run."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Sequence


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def artifact(path: Path, name: str | None = None) -> dict[str, str | int]:
    resolved = path.resolve()
    if not resolved.is_file():
        raise ValueError(f"Artifact does not exist: {resolved}")
    return {
        "name": name or resolved.name,
        "sha256": sha256_file(resolved),
        "bytes": resolved.stat().st_size,
    }


def dependency(value: str) -> tuple[str, Path]:
    if "=" not in value:
        raise argparse.ArgumentTypeError("Dependency must use NAME=PATH")
    name, path_text = value.split("=", 1)
    if not name or not path_text:
        raise argparse.ArgumentTypeError("Dependency must use non-empty NAME=PATH")
    return name.replace("\\", "/"), Path(path_text)


def tester_date(value: str) -> str:
    if not re.fullmatch(r"\d{4}\.\d{2}\.\d{2}", value):
        raise argparse.ArgumentTypeError("Date must use YYYY.MM.DD")
    try:
        datetime.strptime(value, "%Y.%m.%d")
    except ValueError as exc:
        raise argparse.ArgumentTypeError(str(exc)) from exc
    return value


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--run-dir", type=Path, required=True)
    parser.add_argument("--from-date", type=tester_date, required=True)
    parser.add_argument("--to-date", type=tester_date, required=True)
    parser.add_argument(
        "--model",
        default="EVERY_TICK_BASED_ON_REAL_TICKS",
        choices=("EVERY_TICK_BASED_ON_REAL_TICKS",),
    )
    parser.add_argument("--initial-deposit", type=float, required=True)
    parser.add_argument("--final-balance", type=float, required=True)
    parser.add_argument("--currency", required=True)
    parser.add_argument("--leverage", required=True)
    parser.add_argument("--candidate-count", type=int, required=True)
    parser.add_argument("--bars", type=int)
    parser.add_argument("--ticks", type=int)
    parser.add_argument("--deal-events", type=int)
    parser.add_argument("--history-quality-percent", type=float)
    parser.add_argument(
        "--termination-status",
        choices=("COMPLETED", "EARLY_STOP", "MARGIN_CALL", "UNKNOWN"),
        default="UNKNOWN",
    )
    parser.add_argument("--preset", type=Path, required=True)
    parser.add_argument("--ea-ex5", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--dependency", type=dependency, action="append", default=[])
    parser.add_argument("--notes", default="")
    parser.add_argument("--replace", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    run_dir = args.run_dir.resolve()
    manifest_path = run_dir / "run_manifest.json"
    if not manifest_path.is_file():
        print(f"ERROR: Missing run manifest: {manifest_path}", file=sys.stderr)
        return 3
    try:
        manifest = json.loads(manifest_path.read_text(encoding="utf-8-sig"))
        if manifest.get("run_id") != run_dir.name:
            raise ValueError(
                f"Run directory {run_dir.name!r} differs from manifest "
                f"{manifest.get('run_id')!r}"
            )
        output_path = run_dir / "collection_context.json"
        if output_path.exists() and not args.replace:
            raise ValueError(f"Context already exists: {output_path}")
        if datetime.strptime(args.from_date, "%Y.%m.%d") >= datetime.strptime(
            args.to_date, "%Y.%m.%d"
        ):
            raise ValueError("--from-date must be earlier than --to-date")
        if not math.isfinite(args.initial_deposit) or args.initial_deposit <= 0:
            raise ValueError("--initial-deposit must be finite and > 0")
        if not math.isfinite(args.final_balance):
            raise ValueError("--final-balance must be finite")
        if (
            args.history_quality_percent is not None
            and (
                not math.isfinite(args.history_quality_percent)
                or args.history_quality_percent < 0
                or args.history_quality_percent > 100
            )
        ):
            raise ValueError("--history-quality-percent must be between 0 and 100")
        if args.candidate_count < 0:
            raise ValueError("--candidate-count cannot be negative")
        dependency_names = [name for name, _ in args.dependency]
        if len(dependency_names) != len(set(dependency_names)):
            raise ValueError("Duplicate --dependency names are not allowed")
        dependencies = [
            artifact(path, name) for name, path in sorted(args.dependency)
        ]
        context = {
            "context_version": "ts7_collection_context_v1",
            "created_at_utc": datetime.now(timezone.utc).replace(microsecond=0).isoformat(),
            "run_id": manifest["run_id"],
            "tester": {
                "from": args.from_date,
                "to": args.to_date,
                "model": args.model,
                "initial_deposit": args.initial_deposit,
                "final_balance": args.final_balance,
                "currency": args.currency,
                "leverage": args.leverage,
                "candidate_count": args.candidate_count,
                "bars": args.bars,
                "ticks": args.ticks,
                "deal_events": args.deal_events,
                "history_quality_percent": args.history_quality_percent,
                "termination_status": args.termination_status,
            },
            "artifacts": {
                "preset": artifact(args.preset),
                "ea_ex5": artifact(args.ea_ex5),
                "report": artifact(args.report),
                "dependencies": dependencies,
            },
            "notes": args.notes,
        }
        if context["artifacts"]["preset"]["sha256"] != str(
            manifest["preset_sha256"]
        ).upper():
            raise ValueError(
                "Preset SHA-256 does not match run_manifest.json; context was not written"
            )
        output_path.write_text(
            json.dumps(context, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
    except (OSError, KeyError, ValueError, json.JSONDecodeError) as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 3
    print(f"TS7_ML_CONTEXT|RunId={manifest['run_id']}|Output={output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
