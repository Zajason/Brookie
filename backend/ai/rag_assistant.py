# rag_assistant.py
from __future__ import annotations

from typing import Dict, Any, List, Optional
import json
import re

from geo_retrieval import load_places_jsonl, retrieve_nearby_budget_places


# ---------------------------
# KB loading + retrieval
# ---------------------------
def load_budget_kb_jsonl(path: str) -> List[Dict[str, Any]]:
    docs = []
    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                docs.append(json.loads(line))
    return docs


def simple_kb_retrieve(docs: List[Dict[str, Any]], query: str, k: int = 5) -> List[Dict[str, Any]]:
    """
    Tiny lexical retriever: scores docs by token overlap with query.
    Upgrade later to embeddings, but this works well for a prototype.
    """
    q = set(re.findall(r"[a-zA-Zα-ωΑ-Ω0-9]+", query.lower()))
    scored = []
    for d in docs:
        text = (d.get("text", "") + " " + " ".join(d.get("tags", [])) + " " + d.get("topic", "")).lower()
        t = set(re.findall(r"[a-zA-Zα-ωΑ-Ω0-9]+", text))
        overlap = len(q & t)
        if overlap > 0:
            scored.append((overlap, d))
    scored.sort(key=lambda x: x[0], reverse=True)
    return [d for _, d in scored[:k]]


# ---------------------------
# Conversation intent routing
# ---------------------------
PLACE_INTENT_PATTERNS = [
    r"\bnear me\b", r"\bnearby\b", r"\baround here\b",
    r"\bκοντά μου\b", r"\bκοντά\b",
    r"\bcheap\b", r"\bvalue\b", r"\bstudent deal\b",
    r"\brestaurant\b", r"\bfood\b", r"\bsouvlaki\b", r"\bcoffee\b",
    r"\bsupermarket\b", r"\bmini market\b", r"\bbakery\b", r"\bproduce\b", r"\bpharmacy\b",
    r"\bσουβλάκι\b", r"\bσούπερ\b", r"\bφούρνος\b", r"\bλαϊκή\b", r"\bφαρμακείο\b"
]

def user_wants_places(user_message: str) -> bool:
    m = user_message.lower()
    return any(re.search(p, m) for p in PLACE_INTENT_PATTERNS)


def should_proactively_suggest_places(metrics: Dict[str, Any]) -> bool:
    """
    When conversation is budgeting-related, you can proactively add a small list of places
    if a category is clearly high and the user has GPS available.
    """
    groceries_share = float(metrics.get("groceries_share", 0.0))
    wants_share = float(metrics.get("wants_share", 0.0))
    savings_rate = float(metrics.get("savings_rate", 0.0))

    if savings_rate < 0.05 and (groceries_share > 0.28 or wants_share > 0.35):
        return True
    if groceries_share > 0.30:
        return True
    return False


# ---------------------------
# RAG Assistant
# ---------------------------
SYSTEM_STYLE = """
You are a personal budgeting assistant for Greek students.

Rules:
- ALWAYS ground your advice in the provided metrics. Mention key metrics explicitly (e.g., savings_rate, wants_share, rent_share).
- Give actionable, practical, non-judgmental advice.
- If place recommendations are provided, use ONLY the provided places list; do NOT invent businesses or addresses.
- If GPS is missing, ask the user to enable location (briefly) and still give general tips.
- Keep it concise: 5–12 short bullet points or a short structured response.
"""

def build_metrics_summary(metrics_bundle: Dict[str, Any]) -> str:
    score = metrics_bundle.get("score")
    m = metrics_bundle.get("metrics", metrics_bundle)  # allow passing metrics only

    return (
        f"Score: {score}\n"
        f"savings_rate={m.get('savings_rate', 0):.3f}, rent_share={m.get('rent_share', 0):.3f}, "
        f"wants_share={m.get('wants_share', 0):.3f}, groceries_share={m.get('groceries_share', 0):.3f}, "
        f"transportation_share={m.get('transportation_share', 0):.3f}\n"
        f"total_spending={m.get('total_spending', 0):.2f}, needs_share={m.get('needs_share', 0):.3f}\n"
    )


def compose_context(
    user_message: str,
    metrics_bundle: Dict[str, Any],
    kb_docs: List[Dict[str, Any]],
    places_payload: Optional[Dict[str, Any]] = None,
) -> str:
    metrics_text = build_metrics_summary(metrics_bundle)

    kb_text = ""
    if kb_docs:
        kb_text = "\n".join([f"- {d['topic']} ({','.join(d.get('tags', []))}): {d['text']}" for d in kb_docs])

    places_text = ""
    if places_payload and places_payload.get("results"):
        lines = []
        for p in places_payload["results"][:8]:
            lines.append(
                f"- {p['name']} | {p['subcategory']} | price_level={p['price_level']} | "
                f"distance_m={p.get('distance_m', 0):.0f} | tags={p.get('budget_tags', [])} | address={p.get('address','')}"
            )
        needs = places_payload.get("retrieval_needs", {})
        places_text = (
            f"Geo Retrieval Needs: priority={needs.get('priority_categories')} tags={needs.get('desired_tags')}\n"
            "Nearby Places (DO NOT INVENT OTHERS):\n" + "\n".join(lines)
        )

    context = (
        f"{SYSTEM_STYLE}\n\n"
        f"USER_MESSAGE:\n{user_message}\n\n"
        f"METRICS:\n{metrics_text}\n"
        f"BUDGET_KB:\n{kb_text if kb_text else '(none)'}\n\n"
        f"{places_text if places_text else ''}"
    )
    return context


# ---------------------------
# LLM Interface (plug yours)
# ---------------------------
def call_llm(prompt: str) -> str:
    """
    Replace this with your actual LLM call.
    Keep the contract: input prompt -> output assistant message.
    """
    raise NotImplementedError("Hook up your LLM provider here.")


# ---------------------------
# Main chat function
# ---------------------------
def chat(
    user_message: str,
    metrics_bundle: Dict[str, Any],
    kb: List[Dict[str, Any]],
    places: List[Dict[str, Any]],
    user_lat: Optional[float] = None,
    user_lon: Optional[float] = None,
    city: Optional[str] = None,
) -> str:
    # Retrieve KB docs based on message + metrics drivers
    # (simple trick: append metric keywords to query to pull the right docs)
    m = metrics_bundle.get("metrics", metrics_bundle)
    query_aug = (
        user_message
        + f" savings_rate {m.get('savings_rate', 0)} wants_share {m.get('wants_share', 0)} "
        + f" rent_share {m.get('rent_share', 0)} groceries_share {m.get('groceries_share', 0)}"
    )
    kb_docs = simple_kb_retrieve(kb, query_aug, k=5)

    # Decide if we do geo retrieval
    want_places = user_wants_places(user_message)
    proactive_places = should_proactively_suggest_places(m)
    do_geo = (want_places or proactive_places) and (user_lat is not None and user_lon is not None)

    places_payload = None
    if do_geo:
        places_payload = retrieve_nearby_budget_places(
            places=places,
            metrics=m,
            user_lat=user_lat,
            user_lon=user_lon,
            city=city,          # if you know it; otherwise set None
            radius_m=2000.0,
            max_results=8,
        )

    prompt = compose_context(
        user_message=user_message,
        metrics_bundle=metrics_bundle,
        kb_docs=kb_docs,
        places_payload=places_payload,
    )

    # If user asks for places but we don't have GPS
    if (want_places or proactive_places) and (user_lat is None or user_lon is None):
        # You can still call LLM but with a note that location is missing
        prompt += "\n\nNOTE: GPS is missing; ask the user to enable location, then provide general alternatives."

    return call_llm(prompt)
