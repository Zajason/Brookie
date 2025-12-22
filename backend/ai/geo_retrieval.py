# geo_retrieval.py
from __future__ import annotations

from typing import Dict, Any, List, Optional, Tuple
import math
import json


# -------------------------
# 1) Distance (Haversine)
# -------------------------
def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    """
    Great-circle distance between two points on Earth.
    Returns meters.
    """
    R = 6371000.0  # meters
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    dphi = math.radians(lat2 - lat1)
    dlambda = math.radians(lon2 - lon1)

    a = math.sin(dphi / 2.0) ** 2 + math.cos(phi1) * math.cos(phi2) * math.sin(dlambda / 2.0) ** 2
    c = 2.0 * math.atan2(math.sqrt(a), math.sqrt(1.0 - a))
    return R * c


# --------------------------------
# 2) Load JSONL dataset into memory
# --------------------------------
def load_places_jsonl(path: str) -> List[Dict[str, Any]]:
    places = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            places.append(json.loads(line))
    return places


# -------------------------
# 3) Geo filter + annotate
# -------------------------
def places_within_radius(
    places: List[Dict[str, Any]],
    user_lat: float,
    user_lon: float,
    radius_m: float = 2000.0,
    city: Optional[str] = None,
) -> List[Dict[str, Any]]:
    """
    Returns places within radius_m, with a new field: distance_m
    Optional city filter (recommended so you don't mix far-away cities if dataset has many)
    """
    out = []
    for p in places:
        if city and p.get("city") != city:
            continue
        lat = float(p["latitude"])
        lon = float(p["longitude"])
        d = haversine_m(user_lat, user_lon, lat, lon)
        if d <= radius_m:
            p2 = dict(p)
            p2["distance_m"] = float(d)
            out.append(p2)
    out.sort(key=lambda x: x["distance_m"])
    return out


# --------------------------------------------
# 4) Metric-driven "need" -> retrieval settings
# --------------------------------------------
def infer_retrieval_needs(metrics: Dict[str, Any]) -> Dict[str, Any]:
    """
    Convert metrics into retrieval intent.
    Keeps it simple and explainable.
    """
    savings_rate = float(metrics.get("savings_rate", 0.0))
    wants_share = float(metrics.get("wants_share", 0.0))
    groceries_share = float(metrics.get("groceries_share", 0.0))
    transportation_share = float(metrics.get("transportation_share", 0.0))

    # Decide what category to prioritize
    priority = []
    tags = set()

    # If savings low, push cheap essentials first
    if savings_rate < 0.05:
        tags.update(["cheap", "good_value"])
        # Focus on biggest controllables: groceries + entertainment + other
        priority.extend(["groceries", "entertainment", "other"])

    # Wants high -> cheaper entertainment/food out
    if wants_share > 0.35:
        tags.update(["cheap", "student_deal"])
        priority.insert(0, "entertainment")

    # Groceries high -> meal prep + produce market
    if groceries_share > 0.28:
        tags.update(["meal_prep", "bulk_discounts", "cheap"])
        priority.insert(0, "groceries")

    # Transport high -> target "cheap" + maybe nearby (distance)
    if transportation_share > 0.10:
        tags.update(["cheap"])

    if not priority:
        # default: give a mix
        priority = ["groceries", "entertainment"]

    return {
        "priority_categories": list(dict.fromkeys(priority)),  # preserve order, dedupe
        "desired_tags": sorted(tags) if tags else ["good_value"],
    }


# ------------------------------------------------
# 5) Rank candidates with simple, robust scoring
# ------------------------------------------------
def rank_places(
    candidates: List[Dict[str, Any]],
    desired_categories: List[str],
    desired_tags: List[str],
    max_results: int = 10,
) -> List[Dict[str, Any]]:
    """
    Ranks by:
    - category match (categories_supported)
    - tag match (budget_tags)
    - distance (closer better)
    - price_level (lower better)
    """
    desired_categories_set = set(desired_categories)
    desired_tags_set = set(desired_tags)

    ranked: List[Tuple[float, Dict[str, Any]]] = []
    for p in candidates:
        cats = set(p.get("categories_supported", []))
        tags = set(p.get("budget_tags", []))

        cat_score = 1.0 if (cats & desired_categories_set) else 0.0
        tag_score = len(tags & desired_tags_set) / max(len(desired_tags_set), 1)

        distance_m = float(p.get("distance_m", 999999.0))
        # distance score: 1.0 at 0m, decays to ~0.0 at ~2km
        dist_score = max(0.0, 1.0 - (distance_m / 2000.0))

        price_level = float(p.get("price_level", 2))
        price_score = max(0.0, 1.0 - ((price_level - 1.0) / 3.0))  # 1->1.0, 4->0.0

        # Weighted sum (tune these)
        score = (
            0.40 * cat_score +
            0.25 * tag_score +
            0.20 * dist_score +
            0.15 * price_score
        )

        ranked.append((score, p))

    ranked.sort(key=lambda x: x[0], reverse=True)
    return [p for _, p in ranked[:max_results]]


# ---------------------------------------------
# 6) One-call retrieval: metrics + GPS -> places
# ---------------------------------------------
def retrieve_nearby_budget_places(
    places: List[Dict[str, Any]],
    metrics: Dict[str, Any],
    user_lat: float,
    user_lon: float,
    city: Optional[str] = None,
    radius_m: float = 2000.0,
    max_results: int = 10,
) -> Dict[str, Any]:
    needs = infer_retrieval_needs(metrics)
    candidates = places_within_radius(places, user_lat, user_lon, radius_m=radius_m, city=city)
    ranked = rank_places(
        candidates,
        desired_categories=needs["priority_categories"],
        desired_tags=needs["desired_tags"],
        max_results=max_results,
    )
    return {
        "retrieval_needs": needs,
        "radius_m": radius_m,
        "results": ranked,
    }


# -------------------------
# Example usage
# -------------------------
if __name__ == "__main__":
    places = load_places_jsonl("places_synthetic.jsonl")

    # Example metrics coming from your BudgetScorer output
    metrics = {
        "savings_rate": 0.03,
        "wants_share": 0.39,
        "groceries_share": 0.29,
        "transportation_share": 0.07,
    }

    # Example user GPS (Athens center-ish)
    user_lat, user_lon = 37.9838, 23.7275

    out = retrieve_nearby_budget_places(
        places=places,
        metrics=metrics,
        user_lat=user_lat,
        user_lon=user_lon,
        city="Athens",
        radius_m=2000.0,
        max_results=8,
    )

    # Print top picks
    for p in out["results"]:
        print(f"{p['name']} | {p['subcategory']} | € level {p['price_level']} | {p['distance_m']:.0f}m | tags={p['budget_tags']}")
