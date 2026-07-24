#!/usr/bin/env python3
"""Train reproducible TS7 Phase 3 baseline models using only the Python stdlib."""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import math
import random
import shutil
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Iterable, Mapping, Sequence


MODEL_STATUS = "EXPLORATORY_NOT_FROZEN"
EPSILON = 1e-12


class TrainingFailure(RuntimeError):
    """Raised when Phase 3 cannot produce an auditable experiment."""


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest().upper()


def utc_now_text() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat()


def parse_time(value: str) -> datetime:
    try:
        return datetime.strptime(value, "%Y.%m.%d %H:%M:%S")
    except ValueError as exc:
        raise TrainingFailure(f"Invalid candidate time: {value!r}") from exc


def parse_float(value: str, field: str) -> float:
    if value in ("", "NA", None):
        raise TrainingFailure(f"Required numeric feature {field} is missing")
    try:
        parsed = float(value)
    except (TypeError, ValueError) as exc:
        raise TrainingFailure(f"Feature {field} is not numeric: {value!r}") from exc
    if not math.isfinite(parsed):
        raise TrainingFailure(f"Feature {field} is not finite: {value!r}")
    return parsed


def parse_bool(value: str, field: str) -> float:
    lowered = str(value).lower()
    if lowered == "true":
        return 1.0
    if lowered == "false":
        return 0.0
    raise TrainingFailure(f"Feature {field} is not boolean: {value!r}")


def stable_sigmoid(value: float) -> float:
    if value >= 0:
        exp_value = math.exp(-min(value, 700.0))
        return 1.0 / (1.0 + exp_value)
    exp_value = math.exp(max(value, -700.0))
    return exp_value / (1.0 + exp_value)


def clipped_probability(value: float) -> float:
    return min(max(value, EPSILON), 1.0 - EPSILON)


def logit(value: float) -> float:
    probability = clipped_probability(value)
    return math.log(probability / (1.0 - probability))


def mean(values: Sequence[float]) -> float:
    return sum(values) / len(values) if values else math.nan


def safe_rate(numerator: int | float, denominator: int | float) -> float | None:
    return float(numerator) / float(denominator) if denominator else None


def read_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8-sig"))
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        raise TrainingFailure(f"Cannot read JSON {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise TrainingFailure(f"Expected a JSON object in {path}")
    return value


def merge_config(
    base: Mapping[str, Any], override: Mapping[str, Any]
) -> dict[str, Any]:
    merged: dict[str, Any] = dict(base)
    for key, value in override.items():
        if (
            key in merged
            and isinstance(merged[key], dict)
            and isinstance(value, Mapping)
        ):
            merged[key] = merge_config(merged[key], value)
        else:
            merged[key] = value
    return merged


def read_config(path: Path, seen: set[Path] | None = None) -> dict[str, Any]:
    resolved = path.resolve()
    visited = set() if seen is None else set(seen)
    if resolved in visited:
        raise TrainingFailure(f"Config inheritance cycle detected at {resolved}")
    visited.add(resolved)
    config = read_json(resolved)
    parent_name = config.pop("extends", None)
    if parent_name is None:
        return config
    if not isinstance(parent_name, str) or not parent_name.strip():
        raise TrainingFailure(f"Invalid extends value in {resolved}")
    parent_path = (resolved.parent / parent_name).resolve()
    parent = read_config(parent_path, visited)
    return merge_config(parent, config)


def read_dataset(path: Path, config: Mapping[str, Any]) -> list[dict[str, str]]:
    if not path.is_file():
        raise TrainingFailure(f"Dataset does not exist: {path}")
    try:
        with path.open("r", encoding="utf-8-sig", newline="") as handle:
            reader = csv.DictReader(handle)
            fieldnames = tuple(reader.fieldnames or ())
            rows = [dict(row) for row in reader]
    except (OSError, UnicodeError, csv.Error) as exc:
        raise TrainingFailure(f"Cannot read dataset {path}: {exc}") from exc
    if not rows:
        raise TrainingFailure("Dataset contains no rows")
    if len(rows) < int(config["minimum_rows"]):
        raise TrainingFailure(
            f"Dataset has {len(rows)} rows; minimum is {config['minimum_rows']}"
        )

    contract = config["feature_contract"]
    required = {
        "SchemaVersion", "SetupId", "StrategyVersion", "SourceRevision",
        "CandidateTime", "SignalTime",
        "BusinessOutcome", "OriginalNetProfit", "CycleNetProfit",
        *contract["numeric"], *contract["boolean"], *contract["categorical"],
        config["primary_label"]["column"],
    }
    missing = sorted(required - set(fieldnames))
    if missing:
        raise TrainingFailure("Dataset is missing columns: " + ", ".join(missing))

    allowed_labels = {
        config["primary_label"]["positive"],
        config["primary_label"]["negative"],
    }
    setup_ids: set[str] = set()
    for row in rows:
        if row["SchemaVersion"] != config["dataset_schema"]:
            raise TrainingFailure(
                f"Unexpected schema {row['SchemaVersion']!r} for {row['SetupId']}"
            )
        setup_id = row["SetupId"]
        if setup_id in setup_ids:
            raise TrainingFailure(f"Duplicate SetupId in processed dataset: {setup_id}")
        setup_ids.add(setup_id)
        label = row[config["primary_label"]["column"]]
        if label not in allowed_labels:
            raise TrainingFailure(f"Unsupported primary label {label!r} for {setup_id}")
        row["_CandidateDateTime"] = parse_time(row["CandidateTime"])  # type: ignore[assignment]

    rows.sort(key=lambda item: (item["_CandidateDateTime"], item["SetupId"]))
    return rows


def validate_config(config: Mapping[str, Any]) -> None:
    required = (
        "config_version", "dataset_schema", "minimum_rows", "primary_label",
        "feature_contract", "split", "models", "calibration",
        "threshold_selection", "reporting",
    )
    missing = [name for name in required if name not in config]
    if missing:
        raise TrainingFailure("Config is missing: " + ", ".join(missing))
    contract = config["feature_contract"]
    groups = {
        name: set(contract.get(name, []))
        for name in ("numeric", "boolean", "categorical", "forbidden")
    }
    if not groups["numeric"] or not groups["boolean"]:
        raise TrainingFailure("Numeric and boolean feature lists cannot be empty")
    feature_names = groups["numeric"] | groups["boolean"] | groups["categorical"]
    if len(feature_names) != sum(
        len(groups[name]) for name in ("numeric", "boolean", "categorical")
    ):
        raise TrainingFailure("A feature appears in more than one feature type")
    leakage = feature_names & groups["forbidden"]
    if leakage:
        raise TrainingFailure("Forbidden leakage feature enabled: " + ", ".join(sorted(leakage)))
    split = config["split"]
    if int(split["fold_count"]) < 2:
        raise TrainingFailure("fold_count must be at least 2")
    initial = float(split["initial_history_fraction"])
    evaluation = float(split["evaluation_fraction"])
    if initial <= 0 or evaluation <= 0:
        raise TrainingFailure("Split fractions must be positive")
    if initial + int(split["fold_count"]) * evaluation > 1.000001:
        raise TrainingFailure("Walk-forward folds exceed the dataset")
    validation = float(split["validation_fraction_of_history"])
    if validation <= 0 or validation >= 0.5:
        raise TrainingFailure("validation_fraction_of_history must be between 0 and 0.5")
    if int(split["purge_embargo_minutes"]) < 50:
        raise TrainingFailure("purge_embargo_minutes must be at least 50")


@dataclass
class Fold:
    number: int
    train: list[dict[str, str]]
    validation: list[dict[str, str]]
    evaluation: list[dict[str, str]]
    train_validation_boundary: datetime
    validation_evaluation_boundary: datetime


def group_key(row: Mapping[str, str], fields: Sequence[str]) -> tuple[str, ...]:
    return tuple(str(row[field]) for field in fields)


def align_boundary(
    rows: Sequence[dict[str, str]],
    target: int,
    group_fields: Sequence[str],
) -> int:
    target = min(max(target, 1), len(rows) - 1)
    previous = group_key(rows[target - 1], group_fields)
    while target < len(rows) and group_key(rows[target], group_fields) == previous:
        target += 1
    if target >= len(rows):
        raise TrainingFailure("Cannot place chronological boundary without splitting a group")
    return target


def make_walk_forward_folds(
    rows: Sequence[dict[str, str]],
    split_config: Mapping[str, Any],
) -> list[Fold]:
    count = len(rows)
    fold_count = int(split_config["fold_count"])
    initial = float(split_config["initial_history_fraction"])
    evaluation_fraction = float(split_config["evaluation_fraction"])
    validation_fraction = float(split_config["validation_fraction_of_history"])
    group_fields = list(split_config["group_fields"])
    gap = timedelta(minutes=int(split_config["purge_embargo_minutes"]))
    minimum = int(split_config["minimum_partition_rows"])
    folds: list[Fold] = []

    for fold_index in range(fold_count):
        history_target = round(count * (initial + fold_index * evaluation_fraction))
        evaluation_target = (
            count
            if fold_index == fold_count - 1
            else round(count * (initial + (fold_index + 1) * evaluation_fraction))
        )
        history_end = align_boundary(rows, history_target, group_fields)
        if evaluation_target >= count:
            evaluation_end = count
        else:
            evaluation_end = align_boundary(rows, evaluation_target, group_fields)
        validation_target = round(history_end * (1.0 - validation_fraction))
        validation_start = align_boundary(rows, validation_target, group_fields)

        validation_boundary = rows[validation_start]["_CandidateDateTime"]
        evaluation_boundary = rows[history_end]["_CandidateDateTime"]
        train = [
            row for row in rows[:validation_start]
            if row["_CandidateDateTime"] < validation_boundary - gap
        ]
        validation = [
            row for row in rows[validation_start:history_end]
            if row["_CandidateDateTime"] >= validation_boundary + gap
            and row["_CandidateDateTime"] < evaluation_boundary - gap
        ]
        evaluation = [
            row for row in rows[history_end:evaluation_end]
            if row["_CandidateDateTime"] >= evaluation_boundary + gap
        ]
        partitions = {"train": train, "validation": validation, "evaluation": evaluation}
        for name, partition in partitions.items():
            if len(partition) < minimum:
                raise TrainingFailure(
                    f"Fold {fold_index + 1} {name} has {len(partition)} rows; "
                    f"minimum is {minimum}"
                )
        group_sets = {
            name: {group_key(row, group_fields) for row in partition}
            for name, partition in partitions.items()
        }
        if (
            group_sets["train"] & group_sets["validation"]
            or group_sets["train"] & group_sets["evaluation"]
            or group_sets["validation"] & group_sets["evaluation"]
        ):
            raise TrainingFailure(f"Fold {fold_index + 1} splits a signal group")
        if max(row["_CandidateDateTime"] for row in train) >= min(
            row["_CandidateDateTime"] for row in validation
        ):
            raise TrainingFailure("Training and validation are not chronological")
        if max(row["_CandidateDateTime"] for row in validation) >= min(
            row["_CandidateDateTime"] for row in evaluation
        ):
            raise TrainingFailure("Validation and evaluation are not chronological")
        folds.append(
            Fold(
                fold_index + 1,
                train,
                validation,
                evaluation,
                validation_boundary,
                evaluation_boundary,
            )
        )
    return folds


@dataclass
class Preprocessor:
    numeric: list[str]
    boolean: list[str]
    categorical: list[str]
    means: dict[str, float]
    standard_deviations: dict[str, float]
    levels: dict[str, list[str]]
    expanded_features: list[str]

    @classmethod
    def fit(
        cls,
        rows: Sequence[Mapping[str, str]],
        contract: Mapping[str, Any],
    ) -> "Preprocessor":
        numeric = list(contract["numeric"])
        boolean = list(contract["boolean"])
        categorical = list(contract["categorical"])
        means: dict[str, float] = {}
        deviations: dict[str, float] = {}
        for field in numeric:
            values = [parse_float(row[field], field) for row in rows]
            field_mean = mean(values)
            variance = mean([(value - field_mean) ** 2 for value in values])
            means[field] = field_mean
            deviations[field] = math.sqrt(variance) if variance > EPSILON else 1.0
        levels = {
            field: sorted({str(row[field]) for row in rows})
            for field in categorical
        }
        expanded = [f"z:{field}" for field in numeric]
        expanded.extend(f"bool:{field}" for field in boolean)
        for field in categorical:
            expanded.extend(f"cat:{field}={level}" for level in levels[field])
        return cls(numeric, boolean, categorical, means, deviations, levels, expanded)

    def transform(self, row: Mapping[str, str]) -> list[float]:
        values = [
            (parse_float(row[field], field) - self.means[field])
            / self.standard_deviations[field]
            for field in self.numeric
        ]
        values.extend(parse_bool(row[field], field) for field in self.boolean)
        for field in self.categorical:
            actual = str(row[field])
            values.extend(1.0 if actual == level else 0.0 for level in self.levels[field])
        return values

    def as_dict(self) -> dict[str, Any]:
        return {
            "numeric": self.numeric,
            "boolean": self.boolean,
            "categorical": self.categorical,
            "means": self.means,
            "standard_deviations": self.standard_deviations,
            "categorical_levels_fit_on_train_only": self.levels,
            "expanded_features": self.expanded_features,
        }


def label_values(
    rows: Sequence[Mapping[str, str]],
    label_config: Mapping[str, str],
) -> list[int]:
    return [
        1 if row[label_config["column"]] == label_config["positive"] else 0
        for row in rows
    ]


def logistic_loss(
    matrix: Sequence[Sequence[float]],
    labels: Sequence[int],
    weights: Sequence[float],
    bias: float,
    l2: float,
    with_gradient: bool,
) -> tuple[float, list[float], float]:
    loss = 0.0
    gradient = [0.0] * len(weights)
    bias_gradient = 0.0
    for values, label in zip(matrix, labels):
        score = bias + sum(weight * value for weight, value in zip(weights, values))
        probability = stable_sigmoid(score)
        loss -= label * math.log(clipped_probability(probability))
        loss -= (1 - label) * math.log(clipped_probability(1.0 - probability))
        if with_gradient:
            error = probability - label
            bias_gradient += error
            for index, value in enumerate(values):
                gradient[index] += error * value
    count = len(labels)
    loss = loss / count + 0.5 * l2 * sum(weight * weight for weight in weights)
    if with_gradient:
        gradient = [
            value / count + l2 * weights[index]
            for index, value in enumerate(gradient)
        ]
        bias_gradient /= count
    return loss, gradient, bias_gradient


def fit_linear_logistic(
    matrix: Sequence[Sequence[float]],
    labels: Sequence[int],
    config: Mapping[str, Any],
) -> dict[str, Any]:
    if not matrix or not matrix[0]:
        raise TrainingFailure("Cannot train logistic regression on an empty matrix")
    if len(set(labels)) != 2:
        raise TrainingFailure("Logistic regression requires both classes")
    dimensions = len(matrix[0])
    weights = [0.0] * dimensions
    prevalence = clipped_probability(sum(labels) / len(labels))
    bias = logit(prevalence)
    l2 = float(config["l2"])
    rate = float(config["learning_rate"])
    tolerance = float(config["tolerance"])
    maximum = int(config["max_iterations"])
    loss, gradient, bias_gradient = logistic_loss(
        matrix, labels, weights, bias, l2, True
    )
    stable_iterations = 0
    completed = 0
    for iteration in range(maximum):
        completed = iteration + 1
        candidate_weights = [
            weight - rate * grad for weight, grad in zip(weights, gradient)
        ]
        candidate_bias = bias - rate * bias_gradient
        candidate_loss, _, _ = logistic_loss(
            matrix, labels, candidate_weights, candidate_bias, l2, False
        )
        if candidate_loss > loss + 1e-14:
            rate *= 0.5
            if rate < 1e-8:
                break
            continue
        improvement = loss - candidate_loss
        weights = candidate_weights
        bias = candidate_bias
        loss, gradient, bias_gradient = logistic_loss(
            matrix, labels, weights, bias, l2, True
        )
        rate = min(rate * 1.02, 0.5)
        stable_iterations = stable_iterations + 1 if improvement < tolerance else 0
        if stable_iterations >= 10:
            break
    return {
        "type": "logistic_regression",
        "weights": weights,
        "bias": bias,
        "l2": l2,
        "iterations": completed,
        "training_loss": loss,
    }


def predict_linear(model: Mapping[str, Any], matrix: Sequence[Sequence[float]]) -> list[float]:
    weights = model["weights"]
    bias = float(model["bias"])
    return [
        stable_sigmoid(bias + sum(weight * value for weight, value in zip(weights, row)))
        for row in matrix
    ]


def gini(positive: int, total: int) -> float:
    if total <= 0:
        return 0.0
    probability = positive / total
    return 2.0 * probability * (1.0 - probability)


def candidate_thresholds(values: Sequence[float], maximum: int) -> list[float]:
    unique = sorted(set(values))
    if len(unique) <= 1:
        return []
    possible = [
        (unique[index] + unique[index + 1]) / 2.0
        for index in range(len(unique) - 1)
    ]
    if len(possible) <= maximum:
        return possible
    selected = {
        possible[min(len(possible) - 1, round(i * (len(possible) - 1) / (maximum - 1)))]
        for i in range(maximum)
    }
    return sorted(selected)


def build_tree(
    matrix: Sequence[Sequence[float]],
    labels: Sequence[int],
    indices: Sequence[int],
    depth: int,
    config: Mapping[str, Any],
    rng: random.Random,
    importance: list[float],
) -> dict[str, Any]:
    positives = sum(labels[index] for index in indices)
    total = len(indices)
    probability = (positives + 1.0) / (total + 2.0)
    minimum_leaf = int(config["min_leaf"])
    if (
        depth >= int(config["max_depth"])
        or positives == 0
        or positives == total
        or total < minimum_leaf * 2
    ):
        return {"leaf": True, "probability": probability, "samples": total}

    dimensions = len(matrix[0])
    feature_count = max(1, round(math.sqrt(dimensions)))
    feature_indices = rng.sample(range(dimensions), min(feature_count, dimensions))
    parent_impurity = gini(positives, total)
    best: tuple[float, int, float, list[int], list[int]] | None = None
    for feature in feature_indices:
        values = [matrix[index][feature] for index in indices]
        for threshold in candidate_thresholds(values, int(config["max_thresholds"])):
            left = [index for index in indices if matrix[index][feature] <= threshold]
            right = [index for index in indices if matrix[index][feature] > threshold]
            if len(left) < minimum_leaf or len(right) < minimum_leaf:
                continue
            left_positive = sum(labels[index] for index in left)
            right_positive = positives - left_positive
            impurity = (
                len(left) / total * gini(left_positive, len(left))
                + len(right) / total * gini(right_positive, len(right))
            )
            gain = parent_impurity - impurity
            if best is None or gain > best[0] + 1e-15:
                best = (gain, feature, threshold, left, right)
    if best is None or best[0] <= EPSILON:
        return {"leaf": True, "probability": probability, "samples": total}
    gain, feature, threshold, left, right = best
    importance[feature] += gain * total
    return {
        "leaf": False,
        "feature": feature,
        "threshold": threshold,
        "gain": gain,
        "samples": total,
        "probability": probability,
        "left": build_tree(matrix, labels, left, depth + 1, config, rng, importance),
        "right": build_tree(matrix, labels, right, depth + 1, config, rng, importance),
    }


def fit_random_forest(
    matrix: Sequence[Sequence[float]],
    labels: Sequence[int],
    config: Mapping[str, Any],
    fold_number: int,
) -> dict[str, Any]:
    if len(set(labels)) != 2:
        raise TrainingFailure("Random forest requires both classes")
    rng = random.Random(int(config["seed"]) + fold_number)
    trees: list[dict[str, Any]] = []
    importance = [0.0] * len(matrix[0])
    for _ in range(int(config["trees"])):
        bootstrap = [rng.randrange(len(labels)) for _ in range(len(labels))]
        trees.append(build_tree(matrix, labels, bootstrap, 0, config, rng, importance))
    total_importance = sum(importance)
    normalized = [
        value / total_importance if total_importance > 0 else 0.0
        for value in importance
    ]
    return {
        "type": "shallow_random_forest",
        "trees": trees,
        "feature_importance": normalized,
        "seed": int(config["seed"]) + fold_number,
        "max_depth": int(config["max_depth"]),
        "min_leaf": int(config["min_leaf"]),
    }


def predict_tree(node: Mapping[str, Any], values: Sequence[float]) -> float:
    while not node["leaf"]:
        node = node["left"] if values[node["feature"]] <= node["threshold"] else node["right"]
    return float(node["probability"])


def predict_forest(model: Mapping[str, Any], matrix: Sequence[Sequence[float]]) -> list[float]:
    trees = model["trees"]
    return [
        mean([predict_tree(tree, values) for tree in trees])
        for values in matrix
    ]


def fit_platt_calibrator(
    probabilities: Sequence[float],
    labels: Sequence[int],
    config: Mapping[str, Any],
) -> dict[str, Any]:
    matrix = [[logit(probability)] for probability in probabilities]
    logistic_config = {
        "l2": config["l2"],
        "max_iterations": config["max_iterations"],
        "learning_rate": config["learning_rate"],
        "tolerance": config["tolerance"],
    }
    model = fit_linear_logistic(matrix, labels, logistic_config)
    return {
        "type": "platt_logit",
        "slope": model["weights"][0],
        "intercept": model["bias"],
        "iterations": model["iterations"],
        "training_loss": model["training_loss"],
    }


def apply_calibrator(
    calibrator: Mapping[str, Any],
    probabilities: Sequence[float],
) -> list[float]:
    slope = float(calibrator["slope"])
    intercept = float(calibrator["intercept"])
    return [
        stable_sigmoid(intercept + slope * logit(probability))
        for probability in probabilities
    ]


def roc_auc(labels: Sequence[int], probabilities: Sequence[float]) -> float | None:
    positives = sum(labels)
    negatives = len(labels) - positives
    if positives == 0 or negatives == 0:
        return None
    ordered = sorted(zip(probabilities, labels), key=lambda item: item[0])
    rank_sum = 0.0
    index = 0
    while index < len(ordered):
        end = index + 1
        while end < len(ordered) and ordered[end][0] == ordered[index][0]:
            end += 1
        average_rank = (index + 1 + end) / 2.0
        rank_sum += average_rank * sum(label for _, label in ordered[index:end])
        index = end
    return (rank_sum - positives * (positives + 1) / 2.0) / (positives * negatives)


def average_precision(labels: Sequence[int], probabilities: Sequence[float]) -> float | None:
    positives = sum(labels)
    if positives == 0:
        return None
    ordered = sorted(zip(probabilities, labels), key=lambda item: item[0], reverse=True)
    true_positive = 0
    precision_sum = 0.0
    for index, (_, label) in enumerate(ordered, start=1):
        if label:
            true_positive += 1
            precision_sum += true_positive / index
    return precision_sum / positives


def binary_metrics(
    labels: Sequence[int],
    probabilities: Sequence[float],
    threshold: float,
) -> dict[str, Any]:
    decisions = [probability >= threshold for probability in probabilities]
    confusion = confusion_metrics(labels, decisions)
    log_loss = -mean([
        label * math.log(clipped_probability(probability))
        + (1 - label) * math.log(clipped_probability(1.0 - probability))
        for label, probability in zip(labels, probabilities)
    ])
    return {
        "count": len(labels),
        "positive_rate": safe_rate(sum(labels), len(labels)),
        "roc_auc": roc_auc(labels, probabilities),
        "pr_auc": average_precision(labels, probabilities),
        "log_loss": log_loss,
        "brier_score": mean([
            (probability - label) ** 2
            for probability, label in zip(probabilities, labels)
        ]),
        "threshold": threshold,
        "threshold_mode": "FIXED",
        **confusion,
    }


def confusion_metrics(
    labels: Sequence[int],
    decisions: Sequence[bool],
) -> dict[str, Any]:
    true_positive = sum(decision and label == 1 for decision, label in zip(decisions, labels))
    false_positive = sum(decision and label == 0 for decision, label in zip(decisions, labels))
    true_negative = sum(not decision and label == 0 for decision, label in zip(decisions, labels))
    false_negative = sum(not decision and label == 1 for decision, label in zip(decisions, labels))
    return {
        "true_positive": true_positive,
        "false_positive": false_positive,
        "true_negative": true_negative,
        "false_negative": false_negative,
        "accuracy": safe_rate(true_positive + true_negative, len(labels)),
        "precision": safe_rate(true_positive, true_positive + false_positive),
        "recall": safe_rate(true_positive, true_positive + false_negative),
        "specificity": safe_rate(true_negative, true_negative + false_positive),
    }


def business_proxy_metrics(
    rows: Sequence[Mapping[str, str]],
    probabilities: Sequence[float],
    threshold: float,
) -> dict[str, Any]:
    allowed = [probability >= threshold for probability in probabilities]
    winners = [
        parse_float(row["OriginalNetProfit"], "OriginalNetProfit") > 0
        for row in rows
    ]
    deep_recovery = [row["BusinessOutcome"] == "RECOVERY_L4_PLUS" for row in rows]
    recovery = [row["BusinessOutcome"] != "NO_RECOVERY" for row in rows]
    allowed_indices = [index for index, decision in enumerate(allowed) if decision]
    winner_count = sum(winners)
    l4_count = sum(deep_recovery)
    baseline_recovery_rate = safe_rate(sum(recovery), len(rows))
    allowed_recovery_rate = safe_rate(
        sum(recovery[index] for index in allowed_indices), len(allowed_indices)
    )
    recovery_reduction = None
    if baseline_recovery_rate and allowed_recovery_rate is not None:
        recovery_reduction = (
            baseline_recovery_rate - allowed_recovery_rate
        ) / baseline_recovery_rate
    dates = {str(row["CandidateTime"])[:10] for row in rows}
    allowed_dates = {str(rows[index]["CandidateTime"])[:10] for index in allowed_indices}
    return {
        "retained_count": len(allowed_indices),
        "retained_fraction": safe_rate(len(allowed_indices), len(rows)),
        "winner_rejection_rate": safe_rate(
            sum(winner and not decision for winner, decision in zip(winners, allowed)),
            winner_count,
        ),
        "l4_plus_rejection_rate": safe_rate(
            sum(deep and not decision for deep, decision in zip(deep_recovery, allowed)),
            l4_count,
        ),
        "baseline_original_win_rate": safe_rate(winner_count, len(rows)),
        "allowed_original_win_rate": safe_rate(
            sum(winners[index] for index in allowed_indices), len(allowed_indices)
        ),
        "baseline_recovery_rate": baseline_recovery_rate,
        "allowed_recovery_rate": allowed_recovery_rate,
        "relative_recovery_rate_reduction": recovery_reduction,
        "allowed_no_recovery_rate": safe_rate(
            sum(not recovery[index] for index in allowed_indices), len(allowed_indices)
        ),
        "active_day_retention": safe_rate(len(allowed_dates), len(dates)),
        "allowed_original_net_sum_proxy": sum(
            parse_float(rows[index]["OriginalNetProfit"], "OriginalNetProfit")
            for index in allowed_indices
        ),
        "allowed_cycle_net_sum_proxy": sum(
            parse_float(rows[index]["CycleNetProfit"], "CycleNetProfit")
            for index in allowed_indices
        ),
    }


def choose_threshold(
    rows: Sequence[Mapping[str, str]],
    labels: Sequence[int],
    probabilities: Sequence[float],
    config: Mapping[str, Any],
) -> dict[str, Any]:
    candidates = sorted({0.0, 1.0, *probabilities})
    winner_limit = float(config["winner_rejection_max"])
    retained_minimum = float(config["minimum_retained_fraction"])
    best: tuple[tuple[float, ...], float, dict[str, Any], dict[str, Any]] | None = None
    fallback: tuple[tuple[float, ...], float, dict[str, Any], dict[str, Any]] | None = None
    for threshold in candidates:
        classification = binary_metrics(labels, probabilities, threshold)
        business = business_proxy_metrics(rows, probabilities, threshold)
        retained = business["retained_fraction"] or 0.0
        winner_rejection = business["winner_rejection_rate"]
        l4_rejection = business["l4_plus_rejection_rate"]
        feasible = (
            retained >= retained_minimum
            and winner_rejection is not None
            and winner_rejection <= winner_limit + 1e-12
        )
        objective = (
            l4_rejection if l4_rejection is not None else -1.0,
            business["relative_recovery_rate_reduction"]
            if business["relative_recovery_rate_reduction"] is not None else -1.0,
            business["allowed_no_recovery_rate"]
            if business["allowed_no_recovery_rate"] is not None else -1.0,
            classification["precision"] if classification["precision"] is not None else -1.0,
            -abs(retained - 0.8),
        )
        item = (objective, threshold, classification, business)
        if feasible and (best is None or objective > best[0]):
            best = item
        fallback_objective = (
            -(winner_rejection if winner_rejection is not None else 1.0),
            retained,
            classification["precision"] if classification["precision"] is not None else -1.0,
        )
        fallback_item = (fallback_objective, threshold, classification, business)
        if fallback is None or fallback_objective > fallback[0]:
            fallback = fallback_item
    selected = best or fallback
    if selected is None:
        raise TrainingFailure("Threshold search produced no candidate")
    return {
        "threshold": selected[1],
        "feasible": best is not None,
        "classification": selected[2],
        "business_proxy": selected[3],
        "selection_contract": dict(config),
    }


def calibration_curve(
    labels: Sequence[int],
    probabilities: Sequence[float],
    bins: int,
) -> list[dict[str, Any]]:
    grouped: list[list[tuple[float, int]]] = [[] for _ in range(bins)]
    for probability, label in zip(probabilities, labels):
        index = min(bins - 1, int(probability * bins))
        grouped[index].append((probability, label))
    return [
        {
            "bin": index,
            "lower": index / bins,
            "upper": (index + 1) / bins,
            "count": len(values),
            "mean_probability": mean([value for value, _ in values]) if values else None,
            "observed_rate": safe_rate(sum(label for _, label in values), len(values)),
        }
        for index, values in enumerate(grouped)
    ]


def date_range(rows: Sequence[Mapping[str, Any]]) -> dict[str, str]:
    times = [row["_CandidateDateTime"] for row in rows]
    return {
        "from": min(times).strftime("%Y.%m.%d %H:%M:%S"),
        "to": max(times).strftime("%Y.%m.%d %H:%M:%S"),
    }


def train_model(
    name: str,
    train_matrix: Sequence[Sequence[float]],
    train_labels: Sequence[int],
    config: Mapping[str, Any],
    fold_number: int,
) -> dict[str, Any]:
    if name == "logistic_regression":
        return fit_linear_logistic(train_matrix, train_labels, config)
    if name == "shallow_random_forest":
        return fit_random_forest(train_matrix, train_labels, config, fold_number)
    raise TrainingFailure(f"Unsupported model: {name}")


def predict_model(
    name: str,
    model: Mapping[str, Any],
    matrix: Sequence[Sequence[float]],
) -> list[float]:
    if name == "logistic_regression":
        return predict_linear(model, matrix)
    if name == "shallow_random_forest":
        return predict_forest(model, matrix)
    raise TrainingFailure(f"Unsupported model: {name}")


def prepare_output(output_dir: Path, repo_root: Path, replace: bool) -> None:
    output = output_dir.resolve()
    repository = repo_root.resolve()
    if output == repository or repository in output.parents:
        raise TrainingFailure("Experiment output must be outside the repository")
    if output.exists():
        if not replace:
            raise TrainingFailure(
                f"Output already exists; use --replace-output for this exact path: {output}"
            )
        if not output.is_dir():
            raise TrainingFailure(f"Output exists and is not a directory: {output}")
        marker = output / "experiment_manifest.json"
        if not marker.is_file():
            raise TrainingFailure(
                "Refusing to replace a directory without experiment_manifest.json"
            )
        manifest = read_json(marker)
        if manifest.get("manifest_version") != "ts7_ml_experiment_manifest_v1":
            raise TrainingFailure("Refusing to replace an unrelated output directory")
        shutil.rmtree(output)
    output.mkdir(parents=True)


def json_ready(value: Any) -> Any:
    if isinstance(value, datetime):
        return value.strftime("%Y.%m.%d %H:%M:%S")
    if isinstance(value, float) and not math.isfinite(value):
        return None
    if isinstance(value, dict):
        return {str(key): json_ready(item) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [json_ready(item) for item in value]
    return value


def write_json(path: Path, value: Any) -> None:
    path.write_text(
        json.dumps(json_ready(value), indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )


def write_csv(path: Path, rows: Sequence[Mapping[str, Any]], fields: Sequence[str]) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fields, extrasaction="ignore")
        writer.writeheader()
        for row in rows:
            writer.writerow({field: json_ready(row.get(field, "")) for field in fields})


def flatten_metrics(
    fold: int,
    model: str,
    partition: str,
    metrics: Mapping[str, Any],
    business: Mapping[str, Any],
) -> dict[str, Any]:
    return {
        "Fold": fold,
        "Model": model,
        "Partition": partition,
        **{f"ML_{key}": value for key, value in metrics.items()},
        **{f"Business_{key}": value for key, value in business.items()},
    }


def subgroup_rows(
    model: str,
    prediction_rows: Sequence[Mapping[str, Any]],
    config: Mapping[str, Any],
) -> list[dict[str, Any]]:
    output: list[dict[str, Any]] = []
    minimum = int(config["minimum_subgroup_rows"])
    for field in config["subgroup_fields"]:
        groups: dict[str, list[Mapping[str, Any]]] = defaultdict(list)
        for row in prediction_rows:
            groups[str(row[field])].append(row)
        for value in sorted(groups):
            group = groups[value]
            labels = [int(row["Label"]) for row in group]
            probabilities = [float(row["Probability"]) for row in group]
            decisions = [bool(row["Allowed"]) for row in group]
            output.append(
                {
                    "Model": model,
                    "Feature": field,
                    "Group": value,
                    "Count": len(group),
                    "MeetsMinimumCount": len(group) >= minimum,
                    "PositiveRate": safe_rate(sum(labels), len(labels)),
                    "AllowedRate": safe_rate(sum(decisions), len(decisions)),
                    "RocAuc": roc_auc(labels, probabilities),
                    "PRAuc": average_precision(labels, probabilities),
                    "NoRecoveryRate": safe_rate(
                        sum(row["BusinessOutcome"] == "NO_RECOVERY" for row in group),
                        len(group),
                    ),
                    "L4PlusRate": safe_rate(
                        sum(row["BusinessOutcome"] == "RECOVERY_L4_PLUS" for row in group),
                        len(group),
                    ),
                }
            )
    return output


def render_report(report: Mapping[str, Any]) -> str:
    lines = [
        "# TS7 Phase 3 Exploratory Baseline Models",
        "",
        f"- Status: `{report['status']}`",
        f"- Dataset rows: {report['dataset']['rows']}",
        f"- Dataset SHA-256: `{report['dataset']['sha256']}`",
        f"- Walk-forward folds: {len(report['folds'])}",
        f"- Purge/embargo: {report['split']['purge_embargo_minutes']} minutes per side",
        f"- Exploratory champion: `{report['exploratory_champion']}`",
        "",
        "Final OOS belum dibuka. Model dan threshold belum dibekukan atau diizinkan untuk runtime.",
        "",
        "## Aggregate evaluation",
        "",
        "| Model | Rows | ROC-AUC | PR-AUC | Log loss | Brier | Retained | Winner rejected | L4+ rejected |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for name, summary in report["aggregate_models"].items():
        ml = summary["classification"]
        business = summary["business_proxy"]
        def fmt(value: Any) -> str:
            return "NA" if value is None else f"{float(value):.4f}"
        lines.append(
            f"| {name} | {ml['count']} | {fmt(ml['roc_auc'])} | {fmt(ml['pr_auc'])} "
            f"| {fmt(ml['log_loss'])} | {fmt(ml['brier_score'])} "
            f"| {fmt(business['retained_fraction'])} "
            f"| {fmt(business['winner_rejection_rate'])} "
            f"| {fmt(business['l4_plus_rejection_rate'])} |"
        )
    lines.extend(
        [
            "",
            "## Fold coverage",
            "",
            "| Fold | Train | Validation | Evaluation | Train range | Evaluation range |",
            "| ---: | ---: | ---: | ---: | --- | --- |",
        ]
    )
    for fold in report["folds"]:
        lines.append(
            f"| {fold['fold']} | {fold['train_rows']} | {fold['validation_rows']} "
            f"| {fold['evaluation_rows']} | {fold['train_range']['from']}–"
            f"{fold['train_range']['to']} | {fold['evaluation_range']['from']}–"
            f"{fold['evaluation_range']['to']} |"
        )
    lines.extend(
        [
            "",
            "## Interpretation boundary",
            "",
            "- Semua preprocessing hanya di-fit pada train fold.",
            "- Platt calibration dan threshold dipilih pada validation fold.",
            "- Evaluation fold selalu berada setelah train/validation secara waktu.",
            "- Proxy P/L hasil filtering bukan hasil portofolio aktual.",
            "- ML_FILTER, ONNX, dan final OOS berada di fase berikutnya.",
            "",
        ]
    )
    return "\n".join(lines)


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
    folds = make_walk_forward_folds(rows, config["split"])
    label_config = config["primary_label"]
    all_predictions: dict[str, list[dict[str, Any]]] = defaultdict(list)
    fold_metric_rows: list[dict[str, Any]] = []
    threshold_rows: list[dict[str, Any]] = []
    fold_descriptions: list[dict[str, Any]] = []
    calibration_rows: list[dict[str, Any]] = []
    model_directory = output_dir / "models"
    model_directory.mkdir()

    for fold in folds:
        preprocessor = Preprocessor.fit(fold.train, config["feature_contract"])
        matrices = {
            "train": [preprocessor.transform(row) for row in fold.train],
            "validation": [preprocessor.transform(row) for row in fold.validation],
            "evaluation": [preprocessor.transform(row) for row in fold.evaluation],
        }
        labels = {
            "train": label_values(fold.train, label_config),
            "validation": label_values(fold.validation, label_config),
            "evaluation": label_values(fold.evaluation, label_config),
        }
        fold_descriptions.append(
            {
                "fold": fold.number,
                "train_rows": len(fold.train),
                "validation_rows": len(fold.validation),
                "evaluation_rows": len(fold.evaluation),
                "train_range": date_range(fold.train),
                "validation_range": date_range(fold.validation),
                "evaluation_range": date_range(fold.evaluation),
                "train_validation_boundary": fold.train_validation_boundary,
                "validation_evaluation_boundary": fold.validation_evaluation_boundary,
            }
        )

        for model_name, model_config in config["models"].items():
            model = train_model(
                model_name,
                matrices["train"],
                labels["train"],
                model_config,
                fold.number,
            )
            raw_validation = predict_model(model_name, model, matrices["validation"])
            calibrator = fit_platt_calibrator(
                raw_validation,
                labels["validation"],
                config["calibration"],
            )
            calibrated_validation = apply_calibrator(calibrator, raw_validation)
            threshold = choose_threshold(
                fold.validation,
                labels["validation"],
                calibrated_validation,
                config["threshold_selection"],
            )
            threshold_value = float(threshold["threshold"])
            raw_evaluation = predict_model(model_name, model, matrices["evaluation"])
            calibrated_evaluation = apply_calibrator(calibrator, raw_evaluation)

            validation_metrics = binary_metrics(
                labels["validation"], calibrated_validation, threshold_value
            )
            validation_business = business_proxy_metrics(
                fold.validation, calibrated_validation, threshold_value
            )
            evaluation_metrics = binary_metrics(
                labels["evaluation"], calibrated_evaluation, threshold_value
            )
            evaluation_business = business_proxy_metrics(
                fold.evaluation, calibrated_evaluation, threshold_value
            )
            fold_metric_rows.extend(
                [
                    flatten_metrics(
                        fold.number,
                        model_name,
                        "validation",
                        validation_metrics,
                        validation_business,
                    ),
                    flatten_metrics(
                        fold.number,
                        model_name,
                        "evaluation",
                        evaluation_metrics,
                        evaluation_business,
                    ),
                ]
            )
            threshold_rows.append(
                {
                    "Fold": fold.number,
                    "Model": model_name,
                    "Threshold": threshold_value,
                    "Feasible": threshold["feasible"],
                    **{
                        f"Validation_{key}": value
                        for key, value in threshold["business_proxy"].items()
                    },
                }
            )
            for partition, partition_labels, probabilities in (
                ("validation", labels["validation"], calibrated_validation),
                ("evaluation", labels["evaluation"], calibrated_evaluation),
            ):
                for item in calibration_curve(
                    partition_labels,
                    probabilities,
                    int(config["reporting"]["calibration_bins"]),
                ):
                    calibration_rows.append(
                        {
                            "Fold": fold.number,
                            "Model": model_name,
                            "Partition": partition,
                            **item,
                        }
                    )
            for row, label, raw_probability, probability in zip(
                fold.evaluation,
                labels["evaluation"],
                raw_evaluation,
                calibrated_evaluation,
            ):
                all_predictions[model_name].append(
                    {
                        "Fold": fold.number,
                        "Model": model_name,
                        "SetupId": row["SetupId"],
                        "CandidateTime": row["CandidateTime"],
                        "Direction": row["Direction"],
                        "CciSignalType": row["CciSignalType"],
                        "AsiaSession": row["AsiaSession"],
                        "LondonSession": row["LondonSession"],
                        "NewYorkSession": row["NewYorkSession"],
                        "DataIntegrityFlag": row["DataIntegrityFlag"],
                        "Label": label,
                        "Barrier50Outcome": row["Barrier50Outcome"],
                        "BusinessOutcome": row["BusinessOutcome"],
                        "OriginalNetProfit": row["OriginalNetProfit"],
                        "CycleNetProfit": row["CycleNetProfit"],
                        "RawProbability": raw_probability,
                        "Probability": probability,
                        "Threshold": threshold_value,
                        "Allowed": probability >= threshold_value,
                    }
                )
            artifact = {
                "status": MODEL_STATUS,
                "fold": fold.number,
                "model_name": model_name,
                "dataset_sha256": sha256_file(dataset_path),
                "preprocessor": preprocessor.as_dict(),
                "model": model,
                "calibrator": calibrator,
                "threshold": threshold,
                "training_range": date_range(fold.train),
                "validation_range": date_range(fold.validation),
                "evaluation_range": date_range(fold.evaluation),
            }
            write_json(model_directory / f"fold-{fold.number}_{model_name}.json", artifact)

    aggregate: dict[str, Any] = {}
    subgroup_output: list[dict[str, Any]] = []
    prediction_output: list[dict[str, Any]] = []
    for model_name, predictions in all_predictions.items():
        prediction_output.extend(predictions)
        aggregate_labels = [int(row["Label"]) for row in predictions]
        aggregate_probabilities = [float(row["Probability"]) for row in predictions]
        # Fold-specific decisions are retained; 0.5 here is not used for decision metrics.
        aggregate_threshold = 0.5
        ml_metrics = binary_metrics(
            aggregate_labels, aggregate_probabilities, aggregate_threshold
        )
        decisions = [bool(row["Allowed"]) for row in predictions]
        ml_metrics.update(confusion_metrics(aggregate_labels, decisions))
        ml_metrics["threshold"] = None
        ml_metrics["threshold_mode"] = "FOLD_SPECIFIC_VALIDATION_SELECTED"
        proxy_rows = [
            {
                "CandidateTime": row["CandidateTime"],
                "OriginalNetProfit": row["OriginalNetProfit"],
                "CycleNetProfit": row["CycleNetProfit"],
                "BusinessOutcome": row["BusinessOutcome"],
            }
            for row in predictions
        ]
        decision_probabilities = [1.0 if value else 0.0 for value in decisions]
        business = business_proxy_metrics(proxy_rows, decision_probabilities, 0.5)
        aggregate[model_name] = {
            "classification": ml_metrics,
            "business_proxy": business,
            "fold_specific_thresholds_used_for_business_proxy": True,
        }
        subgroup_output.extend(
            subgroup_rows(model_name, predictions, config["reporting"])
        )

    champion = min(
        aggregate,
        key=lambda name: (
            aggregate[name]["classification"]["brier_score"],
            aggregate[name]["classification"]["log_loss"],
            -(aggregate[name]["classification"]["pr_auc"] or -1.0),
        ),
    )
    report = {
        "status": MODEL_STATUS,
        "generated_utc": utc_now_text(),
        "config_version": config["config_version"],
        "dataset": {
            "path_name": dataset_path.name,
            "sha256": sha256_file(dataset_path),
            "rows": len(rows),
            "schema": config["dataset_schema"],
            "candidate_range": date_range(rows),
            "source_revisions": sorted({row["SourceRevision"] for row in rows}),
            "strategy_versions": sorted({row["StrategyVersion"] for row in rows}),
            "integrity_flags": dict(Counter(row["DataIntegrityFlag"] for row in rows)),
        },
        "split": dict(config["split"]),
        "folds": fold_descriptions,
        "aggregate_models": aggregate,
        "exploratory_champion": champion,
        "selection_note": (
            "Exploratory only. No final model or threshold is frozen; final OOS remains unopened."
        ),
    }

    prediction_fields = [
        "Fold", "Model", "SetupId", "CandidateTime", "Direction", "CciSignalType",
        "AsiaSession", "LondonSession", "NewYorkSession", "DataIntegrityFlag",
        "Label", "Barrier50Outcome", "BusinessOutcome", "OriginalNetProfit",
        "CycleNetProfit", "RawProbability", "Probability", "Threshold", "Allowed",
    ]
    write_csv(output_dir / "predictions.csv", prediction_output, prediction_fields)
    write_csv(
        output_dir / "fold_metrics.csv",
        fold_metric_rows,
        list(fold_metric_rows[0]),
    )
    write_csv(
        output_dir / "threshold_selection.csv",
        threshold_rows,
        list(threshold_rows[0]),
    )
    write_csv(
        output_dir / "calibration_curve.csv",
        calibration_rows,
        list(calibration_rows[0]),
    )
    write_csv(
        output_dir / "subgroup_metrics.csv",
        subgroup_output,
        list(subgroup_output[0]),
    )
    write_json(output_dir / "experiment_report.json", report)
    (output_dir / "experiment_report.md").write_text(
        render_report(report), encoding="utf-8"
    )
    write_json(output_dir / "config.snapshot.json", config)
    manifest = {
        "manifest_version": "ts7_ml_experiment_manifest_v1",
        "status": MODEL_STATUS,
        "generated_utc": report["generated_utc"],
        "dataset_sha256": report["dataset"]["sha256"],
        "config_sha256": sha256_file(output_dir / "config.snapshot.json"),
        "script_sha256": sha256_file(Path(__file__)),
        "artifacts": {
            str(path.relative_to(output_dir)).replace("\\", "/"): {
                "sha256": sha256_file(path),
                "bytes": path.stat().st_size,
            }
            for path in sorted(output_dir.rglob("*"))
            if path.is_file() and path.name != "experiment_manifest.json"
        },
    }
    write_json(output_dir / "experiment_manifest.json", manifest)
    return report


def parse_args(argv: Sequence[str] | None = None) -> argparse.Namespace:
    repo_root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(
        description="Train TS7 Phase 3 exploratory baseline models.",
    )
    parser.add_argument("--dataset", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument(
        "--config",
        type=Path,
        default=repo_root / "config" / "ml-phase3-baseline.json",
    )
    parser.add_argument("--replace-output", action="store_true")
    return parser.parse_args(argv)


def main(argv: Sequence[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        config = read_config(args.config)
        report = run_experiment(
            args.dataset,
            args.output_dir,
            config,
            Path(__file__).resolve().parents[2],
            replace_output=args.replace_output,
        )
    except TrainingFailure as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        return 3
    print(
        "TS7_ML_PHASE3"
        f"|Status={report['status']}"
        f"|Rows={report['dataset']['rows']}"
        f"|Folds={len(report['folds'])}"
        f"|Champion={report['exploratory_champion']}"
        f"|Output={args.output_dir.resolve()}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
