# budget_scoring.py
from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, Any
import numpy as np


CATEGORIES = [
    "rent",
    "utilities",
    "entertainment",
    "groceries",
    "transportation",
    "savings",
    "healthcare",
    "other",
]

REQUIRED_COLUMNS = ["total_spending"] + CATEGORIES

def _safe_float(x, default=0.0) -> float:
    try:
        if x is None or (isinstance(x, float) and np.isnan(x)):
            return float(default)
        return float(x)
    except Exception:
        return float(default)


def _clamp(x: float, lo: float, hi: float) -> float:
    return max(lo, min(hi, x))


@dataclass
class Thresholds:
    # Savings rate thresholds (savings / total_spending)
    savings_green: float = 0.15
    savings_yellow: float = 0.05

    # Rent share thresholds (rent / total_spending)
    rent_yellow: float = 0.40
    rent_red: float = 0.45

    # Wants share thresholds ((entertainment + other) / total_spending)
    wants_yellow: float = 0.30
    wants_red: float = 0.35


class BudgetScorer:
    """
    Computes metrics + an explainable score (0-100).
    No insights/suggestions: intended to feed a later RAG conversational layer.
    """

    def __init__(self, thresholds: Thresholds | None = None):
        self.t = thresholds or Thresholds()

    def compute_metrics(self, row: Dict[str, Any]) -> Dict[str, float]:
        # Normalize total to avoid division issues
        total = _safe_float(row.get("total_spending", 0.0), 0.0)
        total = max(total, 1.0)

        # Raw category values
        vals = {k: _safe_float(row.get(k, 0.0), 0.0) for k in CATEGORIES}

        # Shares
        shares = {f"{k}_share": vals[k] / total for k in CATEGORIES}

        needs = vals["rent"] + vals["utilities"] + vals["groceries"] + vals["transportation"] + vals["healthcare"]
        wants = vals["entertainment"] + vals["other"]

        metrics = {
            "total_spending": float(_safe_float(row.get("total_spending", 0.0), 0.0)),
            "needs": float(needs),
            "wants": float(wants),
            "needs_share": float(needs / total),
            "wants_share": float(wants / total),
            "savings_rate": float(vals["savings"] / total),
        }
        metrics.update({k: float(v) for k, v in shares.items()})

        # Add optional convenience metrics your RAG will love
        metrics["discretionary_after_savings"] = float(max(0.0, total - vals["savings"] - needs))
        metrics["wants_to_savings_ratio"] = float(wants / max(vals["savings"], 1.0))

        return metrics

    def score(self, metrics: Dict[str, float]) -> Dict[str, float]:
        """
        Returns score and component penalties so the frontend (or RAG) can explain it later if needed.
        """
        t = self.t
        score = 100.0

        savings = metrics["savings_rate"]
        rent = metrics["rent_share"]
        wants = metrics["wants_share"]

        penalties = {
            "savings_penalty": 0.0,
            "rent_penalty": 0.0,
            "wants_penalty": 0.0,
        }

        # Savings penalty
        if savings < t.savings_yellow:
            penalties["savings_penalty"] = 25.0
        elif savings < t.savings_green:
            penalties["savings_penalty"] = 12.0

        # Rent penalty
        if rent > t.rent_red:
            penalties["rent_penalty"] = 18.0
        elif rent > t.rent_yellow:
            penalties["rent_penalty"] = 8.0

        # Wants penalty (stronger only when savings not healthy)
        if wants > t.wants_red and savings < t.savings_green:
            penalties["wants_penalty"] = 15.0
        elif wants > t.wants_yellow and savings < t.savings_green:
            penalties["wants_penalty"] = 8.0

        score -= sum(penalties.values())
        score = _clamp(score, 0, 100)

        return {
            "score": float(score),
            **penalties,
        }

    def evaluate(self, row: Dict[str, Any]) -> Dict[str, Any]:
        """
        One-call function: row -> {score, metrics, penalties}
        """
        metrics = self.compute_metrics(row)
        scoring = self.score(metrics)
        return {
            "score": int(round(scoring["score"])),
            "penalties": {
                "savings_penalty": scoring["savings_penalty"],
                "rent_penalty": scoring["rent_penalty"],
                "wants_penalty": scoring["wants_penalty"],
            },
            "metrics": metrics,
        }


# ---------------- Example ----------------
if __name__ == "__main__":
    example = {
        "total_spending": 1200,
        "rent": 520,
        "utilities": 70,
        "entertainment": 180,
        "groceries": 240,
        "transportation": 60,
        "savings": 60,
        "healthcare": 20,
        "other": 50,
    }

    scorer = BudgetScorer()
    out = scorer.evaluate(example)

    import json
    print(json.dumps(out, indent=2, ensure_ascii=False))
