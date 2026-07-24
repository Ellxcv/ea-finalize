#!/usr/bin/env python3
"""Train TS7 dual business-target challengers without opening final OOS."""

from __future__ import annotations

import argparse
import base64
import itertools
import random
import shutil
import sys
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Mapping, Sequence


MODULE_DIRECTORY = Path(__file__).resolve().parent
if str(MODULE_DIRECTORY) not in sys.path:
    sys.path.insert(0, str(MODULE_DIRECTORY))

import train_baseline_models as baseline  # noqa: E402


STATUS_REJECTED = "REJECTED_NOT_FROZEN"
STATUS_PASSED = "DEVELOPMENT_GATE_PASSED_NOT_FROZEN"
MANIFEST_VERSION = "ts7_ml_dual_business_manifest_v2"
ALLOWED_BUSINESS_OUTCOMES = {
    "NO_RECOVERY",
    "RECOVERY_L1_L3",
    "RECOVERY_L4_PLUS",
}
TARGET_NAMES = ("no_recovery", "l4_risk")


def validate_config(config: Mapping[str, Any]) -> None:
    baseline.validate_config(config)
    required = (
        "dual_targets",
        "model_pairings",
        "dual_threshold_selection",
        "acceptance_gates",
    )
    missing = [field for field in required if field not in config]
    if missing:
        raise baseline.TrainingFailure(
            "Dual-target config is missing: " + ", ".join(missing)
        )
    if config["dataset_schema"] not in {
        "ts7_entry_candidate_v2",
        "ts7_entry_candidate_v3",
    }:
        raise baseline.TrainingFailure(
            "Dual-target challenger requires entry-candidate schema v2 or v3"
        )

    feature_contract = config["feature_contract"]
    feature_names = {
        *feature_contract["numeric"],
        *feature_contract["boolean"],
        *feature_contract["categorical"],
    }
    outcome_fields = {
        "BusinessOutcome",
        "OriginalNetProfit",
        "RecoveryNetProfit",
        "CycleNetProfit",
        "RecoveryStarted",
        "RecoveryEntries",
        "MaxRecoveryLevel",
        "CycleCompletionReason",
    }
    leakage = feature_names & outcome_fields
    if leakage:
        raise baseline.TrainingFailure(
            "Outcome leakage enabled as feature: " + ", ".join(sorted(leakage))
        )

    targets = config["dual_targets"]
    if not isinstance(targets, Mapping) or set(targets) != set(TARGET_NAMES):
        raise baseline.TrainingFailure(
            "dual_targets must contain exactly no_recovery and l4_risk"
        )
    for name in TARGET_NAMES:
        target = targets[name]
        positives = target.get("positive_outcomes")
        if (
            not isinstance(positives, list)
            or not positives
            or not set(positives) <= ALLOWED_BUSINESS_OUTCOMES
        ):
            raise baseline.TrainingFailure(
                f"Invalid positive outcomes for dual target {name}"
            )
        eligible = target.get(
            "eligible_outcomes", sorted(ALLOWED_BUSINESS_OUTCOMES)
        )
        if (
            not isinstance(eligible, list)
            or not eligible
            or not set(eligible) <= ALLOWED_BUSINESS_OUTCOMES
        ):
            raise baseline.TrainingFailure(
                f"Invalid eligible outcomes for dual target {name}"
            )
        if not set(positives) <= set(eligible):
            raise baseline.TrainingFailure(
                f"Positive outcomes must be eligible for dual target {name}"
            )
        if not isinstance(target.get("balance_training"), bool):
            raise baseline.TrainingFailure(
                f"balance_training must be boolean for {name}"
            )
        if not isinstance(target.get("balance_seed"), int):
            raise baseline.TrainingFailure(
                f"balance_seed must be an integer for {name}"
            )
    if set(targets["no_recovery"]["positive_outcomes"]) != {"NO_RECOVERY"}:
        raise baseline.TrainingFailure(
            "no_recovery target must use only NO_RECOVERY as positive"
        )
    if set(targets["l4_risk"]["positive_outcomes"]) != {"RECOVERY_L4_PLUS"}:
        raise baseline.TrainingFailure(
            "l4_risk target must use only RECOVERY_L4_PLUS as positive"
        )
    if config["config_version"] == "ts7_ml_phase3_dual_business_zero_l4_v3":
        if set(targets["l4_risk"].get("eligible_outcomes", [])) != {
            "RECOVERY_L1_L3",
            "RECOVERY_L4_PLUS",
        }:
            raise baseline.TrainingFailure(
                "Zero-L4 v3 must train l4_risk conditionally on recovery outcomes"
            )

    pairings = config["model_pairings"]
    if not isinstance(pairings, list) or not pairings:
        raise baseline.TrainingFailure("model_pairings must be a non-empty list")
    names: set[str] = set()
    for pairing in pairings:
        name = str(pairing.get("name", "")).strip()
        if not name or name in names:
            raise baseline.TrainingFailure("Pairing names must be unique and non-empty")
        names.add(name)
        for target_name in TARGET_NAMES:
            model_name = pairing.get(f"{target_name}_model")
            if model_name not in config["models"]:
                raise baseline.TrainingFailure(
                    f"Pairing {name} references unknown model {model_name!r}"
                )

    selection = config["dual_threshold_selection"]
    if int(selection["max_candidates_per_target"]) < 2:
        raise baseline.TrainingFailure(
            "max_candidates_per_target must be at least 2"
        )
    for field in ("minimum_retained_fraction", "active_day_retention_min"):
        value = float(selection[field])
        if not 0.0 <= value <= 1.0:
            raise baseline.TrainingFailure(f"{field} must be between 0 and 1")
    if "winner_rejection_max" in selection:
        value = float(selection["winner_rejection_max"])
        if not 0.0 <= value <= 1.0:
            raise baseline.TrainingFailure(
                "winner_rejection_max must be between 0 and 1"
            )
    if int(selection.get("allowed_l4_plus_max", 0)) < 0:
        raise baseline.TrainingFailure(
            "allowed_l4_plus_max cannot be negative"
        )
    objective_order = selection.get("objective_order")
    allowed_objectives = {
        "relative_recovery_rate_reduction",
        "original_win_rate_delta",
        "relative_l4_given_recovery_reduction",
        "l4_plus_rejection_rate",
    }
    if (
        not isinstance(objective_order, list)
        or set(objective_order) != allowed_objectives
        or len(objective_order) != len(allowed_objectives)
    ):
        raise baseline.TrainingFailure(
            "objective_order must contain each dual business objective exactly once"
        )

    gates = config["acceptance_gates"]
    for field in ("minimum_retained_fraction", "active_day_retention_min"):
        value = float(gates[field])
        if not 0.0 <= value <= 1.0:
            raise baseline.TrainingFailure(f"{field} must be between 0 and 1")
    for field in (
        "winner_rejection_max",
        "original_win_rate_delta_min",
        "relative_recovery_rate_reduction_min",
        "l4_plus_rejection_min",
        "relative_l4_given_recovery_reduction_min",
    ):
        if field in gates:
            value = float(gates[field])
            if not 0.0 <= value <= 1.0:
                raise baseline.TrainingFailure(
                    f"{field} must be between 0 and 1"
                )
    if int(gates.get("allowed_l4_plus_max", 0)) < 0:
        raise baseline.TrainingFailure(
            "allowed_l4_plus_max cannot be negative"
        )


def read_dataset(
    path: Path, config: Mapping[str, Any]
) -> list[dict[str, str]]:
    rows = baseline.read_dataset(path, config)
    for row in rows:
        if row["BusinessOutcome"] not in ALLOWED_BUSINESS_OUTCOMES:
            raise baseline.TrainingFailure(
                f"Unsupported BusinessOutcome for {row['SetupId']}: "
                f"{row['BusinessOutcome']!r}"
            )
    return rows


def target_labels(
    rows: Sequence[Mapping[str, str]],
    target_config: Mapping[str, Any],
) -> list[int]:
    positives = set(target_config["positive_outcomes"])
    return [1 if row["BusinessOutcome"] in positives else 0 for row in rows]


def target_population_indices(
    rows: Sequence[Mapping[str, str]],
    target_config: Mapping[str, Any],
) -> list[int]:
    eligible = set(
        target_config.get(
            "eligible_outcomes", sorted(ALLOWED_BUSINESS_OUTCOMES)
        )
    )
    return [
        index
        for index, row in enumerate(rows)
        if row["BusinessOutcome"] in eligible
    ]


def select_indices(
    values: Sequence[Any], indices: Sequence[int]
) -> list[Any]:
    return [values[index] for index in indices]


def balance_training_data(
    matrix: Sequence[Sequence[float]],
    labels: Sequence[int],
    enabled: bool,
    seed: int,
) -> tuple[list[list[float]], list[int], dict[str, Any]]:
    if len(matrix) != len(labels) or not matrix:
        raise baseline.TrainingFailure("Training matrix/label size mismatch")
    class_indices = {
        label: [index for index, actual in enumerate(labels) if actual == label]
        for label in (0, 1)
    }
    if not class_indices[0] or not class_indices[1]:
        raise baseline.TrainingFailure("Both target classes are required in training")
    original = {str(label): len(indices) for label, indices in class_indices.items()}
    if not enabled:
        return (
            [list(values) for values in matrix],
            list(labels),
            {
                "mode": "NONE",
                "seed": seed,
                "original_class_counts": original,
                "resampled_class_counts": dict(original),
            },
        )

    rng = random.Random(seed)
    target_count = max(len(indices) for indices in class_indices.values())
    expanded: list[int] = []
    for label in (0, 1):
        indices = class_indices[label]
        repeats, remainder = divmod(target_count, len(indices))
        expanded.extend(indices * repeats)
        if remainder:
            expanded.extend(rng.sample(indices, remainder))
    rng.shuffle(expanded)
    balanced_matrix = [list(matrix[index]) for index in expanded]
    balanced_labels = [labels[index] for index in expanded]
    return (
        balanced_matrix,
        balanced_labels,
        {
            "mode": "DETERMINISTIC_MINORITY_OVERSAMPLE",
            "seed": seed,
            "original_class_counts": original,
            "resampled_class_counts": {
                "0": balanced_labels.count(0),
                "1": balanced_labels.count(1),
            },
        },
    )


def require_xgboost() -> Any:
    try:
        import xgboost  # type: ignore[import-not-found]
    except ModuleNotFoundError as exc:
        raise baseline.TrainingFailure(
            "regularized_xgboost requires tools/ml/requirements.txt; "
            "run: python -m pip install -r tools/ml/requirements.txt"
        ) from exc
    return xgboost


def fit_regularized_xgboost(
    train_matrix: Sequence[Sequence[float]],
    train_labels: Sequence[int],
    validation_matrix: Sequence[Sequence[float]],
    validation_labels: Sequence[int],
    config: Mapping[str, Any],
    fold_number: int,
) -> dict[str, Any]:
    if len(set(train_labels)) != 2 or len(set(validation_labels)) != 2:
        raise baseline.TrainingFailure(
            "XGBoost requires both classes in train and validation"
        )
    xgboost = require_xgboost()
    training = xgboost.DMatrix(train_matrix, label=train_labels)
    validation = xgboost.DMatrix(
        validation_matrix, label=validation_labels
    )
    seed = int(config["seed"]) + fold_number
    parameters = {
        "objective": "binary:logistic",
        "eval_metric": "logloss",
        "tree_method": "hist",
        "max_depth": int(config["max_depth"]),
        "eta": float(config["learning_rate"]),
        "min_child_weight": float(config["min_child_weight"]),
        "subsample": float(config["subsample"]),
        "colsample_bytree": float(config["colsample_bytree"]),
        "alpha": float(config["reg_alpha"]),
        "lambda": float(config["reg_lambda"]),
        "gamma": float(config["gamma"]),
        "seed": seed,
        "nthread": int(config["threads"]),
        "verbosity": 0,
    }
    booster = xgboost.train(
        parameters,
        training,
        num_boost_round=int(config["boost_rounds"]),
        evals=[(validation, "validation")],
        early_stopping_rounds=int(config["early_stopping_rounds"]),
        verbose_eval=False,
    )
    best_iteration = int(booster.best_iteration)
    serialized = base64.b64encode(
        bytes(booster.save_raw(raw_format="ubj"))
    ).decode("ascii")
    return {
        "type": "regularized_xgboost",
        "version": str(xgboost.__version__),
        "seed": seed,
        "best_iteration": best_iteration,
        "best_score": float(booster.best_score),
        "parameters": parameters,
        "serialized_ubj_base64": serialized,
        "_booster": booster,
    }


def train_target_model(
    name: str,
    train_matrix: Sequence[Sequence[float]],
    train_labels: Sequence[int],
    validation_matrix: Sequence[Sequence[float]],
    validation_labels: Sequence[int],
    config: Mapping[str, Any],
    fold_number: int,
) -> dict[str, Any]:
    if name == "regularized_xgboost":
        return fit_regularized_xgboost(
            train_matrix,
            train_labels,
            validation_matrix,
            validation_labels,
            config,
            fold_number,
        )
    return baseline.train_model(
        name, train_matrix, train_labels, config, fold_number
    )


def predict_target_model(
    name: str,
    model: Mapping[str, Any],
    matrix: Sequence[Sequence[float]],
) -> list[float]:
    if name != "regularized_xgboost":
        return baseline.predict_model(name, model, matrix)
    xgboost = require_xgboost()
    booster = model.get("_booster")
    if booster is None:
        raise baseline.TrainingFailure(
            "In-memory XGBoost booster is unavailable"
        )
    best_iteration = int(model["best_iteration"])
    predictions = booster.predict(
        xgboost.DMatrix(matrix),
        iteration_range=(0, best_iteration + 1),
    )
    return [float(value) for value in predictions]


def serializable_model(model: Mapping[str, Any]) -> dict[str, Any]:
    return {
        key: value
        for key, value in model.items()
        if key != "_booster"
    }


def threshold_candidates(
    probabilities: Sequence[float], maximum: int
) -> list[float]:
    unique = sorted(set(float(value) for value in probabilities))
    if len(unique) > maximum:
        unique = sorted(
            {
                unique[
                    min(
                        len(unique) - 1,
                        round(index * (len(unique) - 1) / (maximum - 1)),
                    )
                ]
                for index in range(maximum)
            }
        )
    return sorted({0.0, 1.0, *unique})


def dual_decisions(
    no_recovery_probabilities: Sequence[float],
    l4_risk_probabilities: Sequence[float],
    no_recovery_threshold: float,
    l4_risk_threshold: float,
) -> list[bool]:
    if len(no_recovery_probabilities) != len(l4_risk_probabilities):
        raise baseline.TrainingFailure("Dual probability size mismatch")
    return [
        no_recovery >= no_recovery_threshold and l4_risk <= l4_risk_threshold
        for no_recovery, l4_risk in zip(
            no_recovery_probabilities, l4_risk_probabilities
        )
    ]


def business_metrics(
    rows: Sequence[Mapping[str, str]], decisions: Sequence[bool]
) -> dict[str, Any]:
    if len(rows) != len(decisions) or not rows:
        raise baseline.TrainingFailure("Business metric row/decision size mismatch")
    winners = [
        baseline.parse_float(row["OriginalNetProfit"], "OriginalNetProfit") > 0
        for row in rows
    ]
    recoveries = [row["BusinessOutcome"] != "NO_RECOVERY" for row in rows]
    deep = [row["BusinessOutcome"] == "RECOVERY_L4_PLUS" for row in rows]
    l1_l3 = [row["BusinessOutcome"] == "RECOVERY_L1_L3" for row in rows]
    allowed_indices = [
        index for index, decision in enumerate(decisions) if decision
    ]
    allowed_recovery_count = sum(recoveries[index] for index in allowed_indices)
    allowed_l4_count = sum(deep[index] for index in allowed_indices)
    baseline_recovery_rate = baseline.safe_rate(sum(recoveries), len(rows))
    allowed_recovery_rate = baseline.safe_rate(
        allowed_recovery_count, len(allowed_indices)
    )
    recovery_reduction = None
    if baseline_recovery_rate and allowed_recovery_rate is not None:
        recovery_reduction = (
            baseline_recovery_rate - allowed_recovery_rate
        ) / baseline_recovery_rate
    baseline_l4_given_recovery = baseline.safe_rate(
        sum(deep), sum(recoveries)
    )
    allowed_l4_given_recovery = baseline.safe_rate(
        allowed_l4_count, allowed_recovery_count
    )
    if allowed_recovery_count == 0:
        allowed_l4_given_recovery = 0.0
    l4_given_recovery_reduction = None
    if (
        baseline_l4_given_recovery
        and allowed_l4_given_recovery is not None
    ):
        l4_given_recovery_reduction = (
            baseline_l4_given_recovery - allowed_l4_given_recovery
        ) / baseline_l4_given_recovery
    baseline_win_rate = baseline.safe_rate(sum(winners), len(rows))
    allowed_win_rate = baseline.safe_rate(
        sum(winners[index] for index in allowed_indices),
        len(allowed_indices),
    )
    win_rate_delta = None
    if baseline_win_rate is not None and allowed_win_rate is not None:
        win_rate_delta = allowed_win_rate - baseline_win_rate
    all_dates = {str(row["CandidateTime"])[:10] for row in rows}
    allowed_dates = {
        str(rows[index]["CandidateTime"])[:10] for index in allowed_indices
    }
    return {
        "retained_count": len(allowed_indices),
        "retained_fraction": baseline.safe_rate(len(allowed_indices), len(rows)),
        "winner_rejection_rate": baseline.safe_rate(
            sum(winner and not decision for winner, decision in zip(winners, decisions)),
            sum(winners),
        ),
        "l4_plus_rejection_rate": baseline.safe_rate(
            sum(is_deep and not decision for is_deep, decision in zip(deep, decisions)),
            sum(deep),
        ),
        "baseline_l4_plus_count": sum(deep),
        "allowed_l4_plus_count": allowed_l4_count,
        "rejected_l4_plus_count": sum(deep) - allowed_l4_count,
        "baseline_original_win_rate": baseline_win_rate,
        "allowed_original_win_rate": allowed_win_rate,
        "original_win_rate_delta": win_rate_delta,
        "baseline_recovery_rate": baseline_recovery_rate,
        "allowed_recovery_rate": allowed_recovery_rate,
        "relative_recovery_rate_reduction": recovery_reduction,
        "baseline_l4_given_recovery_rate": baseline_l4_given_recovery,
        "allowed_l4_given_recovery_rate": allowed_l4_given_recovery,
        "relative_l4_given_recovery_reduction": l4_given_recovery_reduction,
        "allowed_l1_l3_given_recovery_rate": baseline.safe_rate(
            sum(l1_l3[index] for index in allowed_indices),
            allowed_recovery_count,
        ),
        "active_day_retention": baseline.safe_rate(
            len(allowed_dates), len(all_dates)
        ),
        "allowed_original_net_sum_proxy": sum(
            baseline.parse_float(
                rows[index]["OriginalNetProfit"], "OriginalNetProfit"
            )
            for index in allowed_indices
        ),
        "allowed_cycle_net_sum_proxy": sum(
            baseline.parse_float(
                rows[index]["CycleNetProfit"], "CycleNetProfit"
            )
            for index in allowed_indices
        ),
    }


def gate_results(
    metrics: Mapping[str, Any], gates: Mapping[str, Any]
) -> dict[str, bool]:
    def at_least(field: str, target: str) -> bool:
        value = metrics.get(field)
        return value is not None and float(value) + 1e-12 >= float(gates[target])

    def at_most(field: str, target: str) -> bool:
        value = metrics.get(field)
        return value is not None and float(value) <= float(gates[target]) + 1e-12

    results: dict[str, bool] = {
        "minimum_retained_fraction": at_least(
            "retained_fraction", "minimum_retained_fraction"
        ),
        "active_day_retention_min": at_least(
            "active_day_retention", "active_day_retention_min"
        ),
    }
    optional_minimums = {
        "original_win_rate_delta_min": "original_win_rate_delta",
        "relative_recovery_rate_reduction_min": (
            "relative_recovery_rate_reduction"
        ),
        "l4_plus_rejection_min": "l4_plus_rejection_rate",
        "relative_l4_given_recovery_reduction_min": (
            "relative_l4_given_recovery_reduction"
        ),
        "allowed_cycle_net_sum_proxy_min": (
            "allowed_cycle_net_sum_proxy"
        ),
    }
    for gate, metric in optional_minimums.items():
        if gate in gates:
            results[gate] = at_least(metric, gate)
    if "winner_rejection_max" in gates:
        results["winner_rejection_max"] = at_most(
            "winner_rejection_rate", "winner_rejection_max"
        )
    if "allowed_l4_plus_max" in gates:
        results["allowed_l4_plus_max"] = at_most(
            "allowed_l4_plus_count", "allowed_l4_plus_max"
        )
    results["all"] = all(results.values())
    return results


def normalized_gate_progress(
    metrics: Mapping[str, Any], gates: Mapping[str, Any]
) -> tuple[float, ...]:
    fields = (
        ("original_win_rate_delta", "original_win_rate_delta_min"),
        (
            "relative_recovery_rate_reduction",
            "relative_recovery_rate_reduction_min",
        ),
        ("l4_plus_rejection_rate", "l4_plus_rejection_min"),
        (
            "relative_l4_given_recovery_reduction",
            "relative_l4_given_recovery_reduction_min",
        ),
    )
    progress = []
    for metric, target in fields:
        if target not in gates:
            continue
        value = metrics.get(metric)
        denominator = float(gates[target])
        progress.append(
            float(value) / denominator
            if value is not None and denominator > 0
            else -1.0
        )
    return tuple(progress)


def numeric_metric(
    metrics: Mapping[str, Any], field: str, fallback: float = -1.0
) -> float:
    value = metrics.get(field)
    return fallback if value is None else float(value)


def choose_dual_thresholds(
    rows: Sequence[Mapping[str, str]],
    no_recovery_probabilities: Sequence[float],
    l4_risk_probabilities: Sequence[float],
    selection_config: Mapping[str, Any],
    acceptance_gates: Mapping[str, Any],
) -> dict[str, Any]:
    maximum = int(selection_config["max_candidates_per_target"])
    no_recovery_candidates = threshold_candidates(
        no_recovery_probabilities, maximum
    )
    l4_candidates = threshold_candidates(l4_risk_probabilities, maximum)
    best: tuple[tuple[float, ...], float, float, dict[str, Any]] | None = None
    fallback: tuple[tuple[float, ...], float, float, dict[str, Any]] | None = None
    evaluated = 0
    for no_recovery_threshold, l4_risk_threshold in itertools.product(
        no_recovery_candidates, l4_candidates
    ):
        evaluated += 1
        decisions = dual_decisions(
            no_recovery_probabilities,
            l4_risk_probabilities,
            no_recovery_threshold,
            l4_risk_threshold,
        )
        metrics = business_metrics(rows, decisions)
        retained = float(metrics["retained_fraction"] or 0.0)
        active_days = float(metrics["active_day_retention"] or 0.0)
        viable = (
            retained + 1e-12
            >= float(selection_config["minimum_retained_fraction"])
            and active_days + 1e-12
            >= float(selection_config["active_day_retention_min"])
        )
        if "winner_rejection_max" in selection_config:
            winner_rejection = metrics["winner_rejection_rate"]
            viable = (
                viable
                and winner_rejection is not None
                and float(winner_rejection)
                <= float(selection_config["winner_rejection_max"]) + 1e-12
            )
        zero_l4 = (
            int(metrics["allowed_l4_plus_count"])
            <= int(selection_config.get("allowed_l4_plus_max", 10**9))
        )
        net_viable = (
            float(metrics["allowed_cycle_net_sum_proxy"])
            + 1e-12
            >= float(
                selection_config.get(
                    "allowed_cycle_net_sum_proxy_min", float("-inf")
                )
            )
        )
        feasible = viable and zero_l4 and net_viable
        objective = (
            *(
                numeric_metric(metrics, field)
                for field in selection_config["objective_order"]
            ),
            retained,
        )
        if feasible and (best is None or objective > best[0]):
            best = (
                objective,
                no_recovery_threshold,
                l4_risk_threshold,
                metrics,
            )
        fallback_objective = (
            1.0 if viable and net_viable else 0.0,
            -float(metrics["allowed_l4_plus_count"]),
            numeric_metric(metrics, "l4_plus_rejection_rate"),
            numeric_metric(metrics, "relative_recovery_rate_reduction"),
            numeric_metric(metrics, "original_win_rate_delta"),
            active_days,
            retained,
        )
        if fallback is None or fallback_objective > fallback[0]:
            fallback = (
                fallback_objective,
                no_recovery_threshold,
                l4_risk_threshold,
                metrics,
            )
    selected = best or fallback
    if selected is None:
        raise baseline.TrainingFailure("Dual threshold search found no candidate")
    metrics = selected[3]
    return {
        "no_recovery_threshold": selected[1],
        "l4_risk_threshold": selected[2],
        "feasible": best is not None,
        "validation_business": metrics,
        "validation_gates": gate_results(metrics, acceptance_gates),
        "candidate_pairs_evaluated": evaluated,
        "selection_contract": dict(selection_config),
        "acceptance_gates": dict(acceptance_gates),
    }


def prepare_output(
    output_dir: Path, repo_root: Path, replace_output: bool
) -> None:
    output = output_dir.resolve()
    repository = repo_root.resolve()
    if output == repository or repository in output.parents:
        raise baseline.TrainingFailure(
            "Dual-target output must stay outside the repository"
        )
    if output.exists():
        if not replace_output:
            raise baseline.TrainingFailure(
                f"Output already exists: {output}"
            )
        marker = output / "experiment_manifest.json"
        if not marker.is_file():
            raise baseline.TrainingFailure(
                "Refusing to replace output without experiment_manifest.json"
            )
        manifest = baseline.read_json(marker)
        if manifest.get("manifest_version") != MANIFEST_VERSION:
            raise baseline.TrainingFailure(
                "Refusing to replace an unrelated experiment directory"
            )
        shutil.rmtree(output)
    output.mkdir(parents=True)


def target_metric_row(
    fold: int,
    pairing: str,
    partition: str,
    target: str,
    algorithm: str,
    labels: Sequence[int],
    probabilities: Sequence[float],
) -> dict[str, Any]:
    return {
        "Fold": fold,
        "Pairing": pairing,
        "Partition": partition,
        "Target": target,
        "Algorithm": algorithm,
        **baseline.binary_metrics(labels, probabilities, 0.5),
    }


def business_row(
    fold: int,
    pairing: str,
    partition: str,
    metrics: Mapping[str, Any],
    gates: Mapping[str, bool],
) -> dict[str, Any]:
    return {
        "Fold": fold,
        "Pairing": pairing,
        "Partition": partition,
        **metrics,
        **{f"Gate_{name}": value for name, value in gates.items()},
    }


def pairing_rank(
    summary: Mapping[str, Any], gates: Mapping[str, Any]
) -> tuple[float, ...]:
    metrics = summary["business"]
    results = summary["aggregate_gates"]
    return (
        float(summary["all_evaluation_folds_pass"]),
        float(sum(value for name, value in results.items() if name != "all")),
        -numeric_metric(metrics, "allowed_l4_plus_count", float("inf")),
        numeric_metric(metrics, "l4_plus_rejection_rate"),
        numeric_metric(metrics, "relative_recovery_rate_reduction"),
        numeric_metric(metrics, "original_win_rate_delta"),
        numeric_metric(metrics, "active_day_retention"),
        numeric_metric(metrics, "retained_fraction"),
        -numeric_metric(metrics, "winner_rejection_rate", 1.0),
    )


def render_report(report: Mapping[str, Any]) -> str:
    lines = [
        "# TS7 Dual Business-Target Challenger",
        "",
        f"- Status: `{report['status']}`",
        f"- Dataset rows: {report['dataset']['rows']}",
        f"- Dataset SHA-256: `{report['dataset']['sha256']}`",
        f"- Walk-forward folds: {len(report['folds'])}",
        f"- Development leader: `{report['development_leader']}`",
        "",
        "Entry diizinkan hanya bila P(NO_RECOVERY) >= threshold A dan "
        "P(L4_PLUS | recovery) <= threshold B.",
        "",
        "## Aggregate future-fold evaluation",
        "",
        "| Pairing | No-recovery AUC | L4-risk AUC | Retained | Winner rejected "
        "| Original WR delta | Recovery reduction | Allowed L4+ | L4+ rejected "
        "| L4/recovery reduction | All folds pass |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for name, summary in report["pairings"].items():
        business = summary["business"]
        targets = summary["target_metrics"]

        def percent(value: Any) -> str:
            return "NA" if value is None else f"{100.0 * float(value):.2f}%"

        def number(value: Any) -> str:
            return "NA" if value is None else f"{float(value):.4f}"

        lines.append(
            f"| {name} | {number(targets['no_recovery']['roc_auc'])} "
            f"| {number(targets['l4_risk']['roc_auc'])} "
            f"| {percent(business['retained_fraction'])} "
            f"| {percent(business['winner_rejection_rate'])} "
            f"| {percent(business['original_win_rate_delta'])} "
            f"| {percent(business['relative_recovery_rate_reduction'])} "
            f"| {business['allowed_l4_plus_count']} "
            f"| {percent(business['l4_plus_rejection_rate'])} "
            f"| {percent(business['relative_l4_given_recovery_reduction'])} "
            f"| {summary['all_evaluation_folds_pass']} |"
        )
    lines.extend(
        [
            "",
            "## Evaluation gates by fold",
            "",
            "| Fold | Pairing | Retained | Winner rejected | Original WR delta "
            "| Recovery reduction | Allowed L4+ | L4+ rejected "
            "| L4/recovery reduction | Pass |",
            "| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |",
        ]
    )
    for row in report["evaluation_fold_results"]:
        metrics = row["business"]

        def percent(value: Any) -> str:
            return "NA" if value is None else f"{100.0 * float(value):.2f}%"

        lines.append(
            f"| {row['fold']} | {row['pairing']} "
            f"| {percent(metrics['retained_fraction'])} "
            f"| {percent(metrics['winner_rejection_rate'])} "
            f"| {percent(metrics['original_win_rate_delta'])} "
            f"| {percent(metrics['relative_recovery_rate_reduction'])} "
            f"| {metrics['allowed_l4_plus_count']} "
            f"| {percent(metrics['l4_plus_rejection_rate'])} "
            f"| {percent(metrics['relative_l4_given_recovery_reduction'])} "
            f"| {row['gates']['all']} |"
        )
    lines.extend(
        [
            "",
            "## Boundary",
            "",
            "- Target L4+ hanya dilatih pada recovery L1-L3 versus L4+.",
            "- Class balancing hanya dilakukan pada training partition target L4+.",
            "- Calibration dan threshold selection memakai validation asli.",
            "- Evaluation tidak digunakan untuk fit, calibration, atau threshold selection.",
            "- Gate wajib lulus pada setiap evaluation fold sebelum kandidat dapat dibekukan.",
            "- Final OOS belum dibuka.",
        ]
    )
    return "\n".join(lines) + "\n"


def run_experiment(
    dataset_path: Path,
    output_dir: Path,
    config: Mapping[str, Any],
    repo_root: Path,
    replace_output: bool = False,
) -> dict[str, Any]:
    validate_config(config)
    rows = read_dataset(dataset_path, config)
    prepare_output(output_dir, repo_root, replace_output)
    folds = baseline.make_walk_forward_folds(rows, config["split"])
    model_directory = output_dir / "models"
    model_directory.mkdir()
    predictions_by_pairing: dict[str, list[dict[str, Any]]] = defaultdict(list)
    target_metric_rows: list[dict[str, Any]] = []
    business_rows: list[dict[str, Any]] = []
    threshold_rows: list[dict[str, Any]] = []
    fold_descriptions: list[dict[str, Any]] = []
    evaluation_fold_results: list[dict[str, Any]] = []

    for fold in folds:
        preprocessor = baseline.Preprocessor.fit(
            fold.train, config["feature_contract"]
        )
        partitions = {
            "train": fold.train,
            "validation": fold.validation,
            "evaluation": fold.evaluation,
        }
        matrices = {
            name: [preprocessor.transform(row) for row in partition]
            for name, partition in partitions.items()
        }
        target_views = {
            target_name: {
                partition_name: {
                    "indices": (
                        indices := target_population_indices(
                            partition,
                            config["dual_targets"][target_name],
                        )
                    ),
                    "matrix": select_indices(
                        matrices[partition_name], indices
                    ),
                    "labels": target_labels(
                        select_indices(partition, indices),
                        config["dual_targets"][target_name],
                    ),
                }
                for partition_name, partition in partitions.items()
            }
            for target_name in TARGET_NAMES
        }
        fold_descriptions.append(
            {
                "fold": fold.number,
                "train_rows": len(fold.train),
                "validation_rows": len(fold.validation),
                "evaluation_rows": len(fold.evaluation),
                "train_range": baseline.date_range(fold.train),
                "validation_range": baseline.date_range(fold.validation),
                "evaluation_range": baseline.date_range(fold.evaluation),
                "train_validation_boundary": fold.train_validation_boundary,
                "validation_evaluation_boundary": fold.validation_evaluation_boundary,
                "target_counts": {
                    target_name: {
                        partition_name: {
                            "eligible": len(view["labels"]),
                            "positive": sum(view["labels"]),
                            "negative": len(view["labels"])
                            - sum(view["labels"]),
                        }
                        for partition_name, view in target_partitions.items()
                    }
                    for target_name, target_partitions in target_views.items()
                },
            }
        )

        trained: dict[str, dict[str, dict[str, Any]]] = {
            target_name: {} for target_name in TARGET_NAMES
        }
        for target_index, target_name in enumerate(TARGET_NAMES):
            target_config = config["dual_targets"][target_name]
            train_view = target_views[target_name]["train"]
            validation_view = target_views[target_name]["validation"]
            evaluation_view = target_views[target_name]["evaluation"]
            balanced_matrix, balanced_labels, balance_metadata = (
                balance_training_data(
                    train_view["matrix"],
                    train_view["labels"],
                    bool(target_config["balance_training"]),
                    int(target_config["balance_seed"]) + fold.number,
                )
            )
            if len(set(validation_view["labels"])) != 2:
                raise baseline.TrainingFailure(
                    f"Fold {fold.number} validation lacks both {target_name} classes"
                )
            if len(set(evaluation_view["labels"])) != 2:
                raise baseline.TrainingFailure(
                    f"Fold {fold.number} evaluation lacks both {target_name} classes"
                )
            for model_name, model_config in config["models"].items():
                model = train_target_model(
                    model_name,
                    balanced_matrix,
                    balanced_labels,
                    validation_view["matrix"],
                    validation_view["labels"],
                    model_config,
                    fold.number + target_index * 100,
                )
                raw_validation = predict_target_model(
                    model_name, model, matrices["validation"]
                )
                calibrator = baseline.fit_platt_calibrator(
                    select_indices(
                        raw_validation, validation_view["indices"]
                    ),
                    validation_view["labels"],
                    config["calibration"],
                )
                trained[target_name][model_name] = {
                    "model": model,
                    "calibrator": calibrator,
                    "balance": balance_metadata,
                    "raw_validation": raw_validation,
                    "validation": baseline.apply_calibrator(
                        calibrator, raw_validation
                    ),
                    "raw_evaluation": predict_target_model(
                        model_name, model, matrices["evaluation"]
                    ),
                }
                trained[target_name][model_name]["evaluation"] = (
                    baseline.apply_calibrator(
                        calibrator,
                        trained[target_name][model_name]["raw_evaluation"],
                    )
                )

        for pairing in config["model_pairings"]:
            pairing_name = pairing["name"]
            algorithms = {
                target_name: pairing[f"{target_name}_model"]
                for target_name in TARGET_NAMES
            }
            target_outputs = {
                target_name: trained[target_name][algorithms[target_name]]
                for target_name in TARGET_NAMES
            }
            selected = choose_dual_thresholds(
                fold.validation,
                target_outputs["no_recovery"]["validation"],
                target_outputs["l4_risk"]["validation"],
                config["dual_threshold_selection"],
                config["acceptance_gates"],
            )
            thresholds = {
                "no_recovery": float(selected["no_recovery_threshold"]),
                "l4_risk": float(selected["l4_risk_threshold"]),
            }
            partition_decisions: dict[str, list[bool]] = {}
            partition_business: dict[str, dict[str, Any]] = {}
            partition_gates: dict[str, dict[str, bool]] = {}
            for partition_name in ("validation", "evaluation"):
                decisions = dual_decisions(
                    target_outputs["no_recovery"][partition_name],
                    target_outputs["l4_risk"][partition_name],
                    thresholds["no_recovery"],
                    thresholds["l4_risk"],
                )
                metrics = business_metrics(
                    partitions[partition_name], decisions
                )
                gates = gate_results(metrics, config["acceptance_gates"])
                partition_decisions[partition_name] = decisions
                partition_business[partition_name] = metrics
                partition_gates[partition_name] = gates
                business_rows.append(
                    business_row(
                        fold.number,
                        pairing_name,
                        partition_name,
                        metrics,
                        gates,
                    )
                )
                for target_name in TARGET_NAMES:
                    target_view = target_views[target_name][partition_name]
                    target_metric_rows.append(
                        target_metric_row(
                            fold.number,
                            pairing_name,
                            partition_name,
                            target_name,
                            algorithms[target_name],
                            target_view["labels"],
                            select_indices(
                                target_outputs[target_name][partition_name],
                                target_view["indices"],
                            ),
                        )
                    )
            evaluation_fold_results.append(
                {
                    "fold": fold.number,
                    "pairing": pairing_name,
                    "business": partition_business["evaluation"],
                    "gates": partition_gates["evaluation"],
                }
            )
            threshold_rows.append(
                {
                    "Fold": fold.number,
                    "Pairing": pairing_name,
                    "NoRecoveryModel": algorithms["no_recovery"],
                    "L4RiskModel": algorithms["l4_risk"],
                    "NoRecoveryThreshold": thresholds["no_recovery"],
                    "L4RiskThreshold": thresholds["l4_risk"],
                    "Feasible": selected["feasible"],
                    "CandidatePairsEvaluated": selected[
                        "candidate_pairs_evaluated"
                    ],
                    **{
                        f"Validation_{field}": value
                        for field, value in partition_business["validation"].items()
                    },
                    **{
                        f"ValidationGate_{field}": value
                        for field, value in partition_gates["validation"].items()
                    },
                }
            )
            for index, row in enumerate(fold.evaluation):
                predictions_by_pairing[pairing_name].append(
                    {
                        "Fold": fold.number,
                        "Pairing": pairing_name,
                        "SetupId": row["SetupId"],
                        "CandidateTime": row["CandidateTime"],
                        "Direction": row["Direction"],
                        "BusinessOutcome": row["BusinessOutcome"],
                        "OriginalNetProfit": row["OriginalNetProfit"],
                        "CycleNetProfit": row["CycleNetProfit"],
                        "NoRecoveryProbability": target_outputs["no_recovery"][
                            "evaluation"
                        ][index],
                        "L4RiskProbability": target_outputs["l4_risk"][
                            "evaluation"
                        ][index],
                        "NoRecoveryThreshold": thresholds["no_recovery"],
                        "L4RiskThreshold": thresholds["l4_risk"],
                        "Allowed": partition_decisions["evaluation"][index],
                    }
                )
            artifact = {
                "status": "DEVELOPMENT_ONLY_NOT_FROZEN",
                "fold": fold.number,
                "pairing": pairing_name,
                "dataset_sha256": baseline.sha256_file(dataset_path),
                "preprocessor": preprocessor.as_dict(),
                "targets": {
                    target_name: {
                        "algorithm": algorithms[target_name],
                        "positive_outcomes": config["dual_targets"][target_name][
                            "positive_outcomes"
                        ],
                        "eligible_outcomes": config["dual_targets"][
                            target_name
                        ].get(
                            "eligible_outcomes",
                            sorted(ALLOWED_BUSINESS_OUTCOMES),
                        ),
                        "balance": target_outputs[target_name]["balance"],
                        "model": serializable_model(
                            target_outputs[target_name]["model"]
                        ),
                        "calibrator": target_outputs[target_name]["calibrator"],
                    }
                    for target_name in TARGET_NAMES
                },
                "threshold_selection": selected,
                "training_range": baseline.date_range(fold.train),
                "validation_range": baseline.date_range(fold.validation),
                "evaluation_range": baseline.date_range(fold.evaluation),
            }
            baseline.write_json(
                model_directory
                / f"fold-{fold.number}_{pairing_name}.json",
                artifact,
            )

    pairing_summaries: dict[str, Any] = {}
    prediction_rows: list[dict[str, Any]] = []
    for pairing in config["model_pairings"]:
        name = pairing["name"]
        predictions = predictions_by_pairing[name]
        prediction_rows.extend(predictions)
        decisions = [bool(row["Allowed"]) for row in predictions]
        proxy_rows = [
            {
                "CandidateTime": row["CandidateTime"],
                "BusinessOutcome": row["BusinessOutcome"],
                "OriginalNetProfit": row["OriginalNetProfit"],
                "CycleNetProfit": row["CycleNetProfit"],
            }
            for row in predictions
        ]
        business = business_metrics(proxy_rows, decisions)
        aggregate_gates = gate_results(
            business, config["acceptance_gates"]
        )
        target_metrics = {}
        for target_name, probability_field in (
            ("no_recovery", "NoRecoveryProbability"),
            ("l4_risk", "L4RiskProbability"),
        ):
            target_config = config["dual_targets"][target_name]
            indices = target_population_indices(
                proxy_rows, target_config
            )
            target_rows = select_indices(proxy_rows, indices)
            labels_for_target = target_labels(
                target_rows, target_config
            )
            probabilities_all = [
                float(row[probability_field]) for row in predictions
            ]
            probabilities = select_indices(probabilities_all, indices)
            target_metrics[target_name] = baseline.binary_metrics(
                labels_for_target, probabilities, 0.5
            )
            target_metrics[target_name]["threshold"] = None
            target_metrics[target_name][
                "threshold_mode"
            ] = "DUAL_FOLD_SPECIFIC_VALIDATION_SELECTED"
        fold_results = [
            row
            for row in evaluation_fold_results
            if row["pairing"] == name
        ]
        all_folds_pass = all(row["gates"]["all"] for row in fold_results)
        pairing_summaries[name] = {
            "algorithms": {
                target_name: pairing[f"{target_name}_model"]
                for target_name in TARGET_NAMES
            },
            "target_metrics": target_metrics,
            "business": business,
            "aggregate_gates": aggregate_gates,
            "all_evaluation_folds_pass": all_folds_pass,
            "eligible_for_freeze_review": (
                aggregate_gates["all"] and all_folds_pass
            ),
        }

    leader = max(
        pairing_summaries,
        key=lambda name: pairing_rank(
            pairing_summaries[name], config["acceptance_gates"]
        ),
    )
    any_eligible = any(
        summary["eligible_for_freeze_review"]
        for summary in pairing_summaries.values()
    )
    status = STATUS_PASSED if any_eligible else STATUS_REJECTED
    report = {
        "status": status,
        "generated_utc": baseline.utc_now_text(),
        "config_version": config["config_version"],
        "dataset": {
            "path_name": dataset_path.name,
            "sha256": baseline.sha256_file(dataset_path),
            "rows": len(rows),
            "schema": config["dataset_schema"],
            "candidate_range": baseline.date_range(rows),
            "source_revisions": sorted(
                {row["SourceRevision"] for row in rows}
            ),
            "strategy_versions": sorted(
                {row["StrategyVersion"] for row in rows}
            ),
            "business_outcomes": dict(
                Counter(row["BusinessOutcome"] for row in rows)
            ),
        },
        "targets": dict(config["dual_targets"]),
        "acceptance_gates": dict(config["acceptance_gates"]),
        "split": dict(config["split"]),
        "folds": fold_descriptions,
        "pairings": pairing_summaries,
        "evaluation_fold_results": evaluation_fold_results,
        "development_leader": leader,
        "selection_note": (
            "Development only. Evaluation reports gate stability but is not "
            "used to fit models, calibrators, or thresholds. Final OOS remains unopened."
        ),
    }

    baseline.write_csv(
        output_dir / "predictions.csv",
        prediction_rows,
        list(prediction_rows[0]),
    )
    baseline.write_csv(
        output_dir / "target_metrics.csv",
        target_metric_rows,
        list(target_metric_rows[0]),
    )
    baseline.write_csv(
        output_dir / "business_metrics.csv",
        business_rows,
        list(business_rows[0]),
    )
    baseline.write_csv(
        output_dir / "threshold_selection.csv",
        threshold_rows,
        list(threshold_rows[0]),
    )
    baseline.write_json(output_dir / "experiment_report.json", report)
    (output_dir / "experiment_report.md").write_text(
        render_report(report), encoding="utf-8"
    )
    baseline.write_json(output_dir / "config.snapshot.json", config)
    manifest = {
        "manifest_version": MANIFEST_VERSION,
        "status": status,
        "generated_utc": report["generated_utc"],
        "dataset_sha256": report["dataset"]["sha256"],
        "config_sha256": baseline.sha256_file(
            output_dir / "config.snapshot.json"
        ),
        "script_sha256": baseline.sha256_file(Path(__file__)),
        "baseline_script_sha256": baseline.sha256_file(
            MODULE_DIRECTORY / "train_baseline_models.py"
        ),
        "artifacts": {
            path.relative_to(output_dir).as_posix(): {
                "sha256": baseline.sha256_file(path),
                "bytes": path.stat().st_size,
            }
            for path in sorted(output_dir.rglob("*"))
            if path.is_file() and path.name != "experiment_manifest.json"
        },
    }
    baseline.write_json(output_dir / "experiment_manifest.json", manifest)
    return report


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description="Train TS7 dual business-target development challengers."
    )
    parser.add_argument("--dataset", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--config",
        type=Path,
        default=(
            repo_root
            / "config"
            / "ml-phase3-dual-business-zero-l4-v3.json"
        ),
    )
    parser.add_argument("--replace-output", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        config = baseline.read_config(args.config)
        report = run_experiment(
            args.dataset.resolve(),
            args.output_dir.resolve(),
            config,
            Path(__file__).resolve().parents[2],
            replace_output=args.replace_output,
        )
    except baseline.TrainingFailure as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 3
    print(
        "TS7_ML_DUAL_BUSINESS"
        f"|Status={report['status']}"
        f"|Rows={report['dataset']['rows']}"
        f"|Folds={len(report['folds'])}"
        f"|Leader={report['development_leader']}"
        f"|Output={args.output_dir.resolve()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
