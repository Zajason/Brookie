from openai import OpenAI
import json

from financial_model import BudgetScorer
from geo_retrieval import load_places_jsonl, retrieve_nearby_budget_places
from rag_assistant import load_budget_kb_jsonl, simple_kb_retrieve  # or wherever you put these

client = OpenAI()

PLACES = load_places_jsonl("places_synthetic.jsonl")
KB = load_budget_kb_jsonl("budget_kb.jsonl")
SCORER = BudgetScorer()

INSTRUCTIONS = """
You are a personal budgeting assistant for Greek students.
- Always reference the provided metrics (savings_rate, rent_share, wants_share, groceries_share).
- Be practical and non-judgmental.
- If user asks for nearby places, use ONLY the provided Nearby Places list. Never invent places.
Return a short response.
"""

def test_once():
    user_budget = {
        "total_spending": 1250,
        "rent": 560,
        "utilities": 85,
        "entertainment": 220,
        "groceries": 260,
        "transportation": 55,
        "savings": 40,
        "healthcare": 15,
        "other": 15
    }

    # 1) score + metrics
    metrics_bundle = SCORER.evaluate(user_budget)
    metrics = metrics_bundle["metrics"]

    # 2) retrieve KB
    kb_docs = simple_kb_retrieve(
        KB,
        query=f"low savings high wants groceries {metrics['savings_rate']} {metrics['wants_share']} {metrics['groceries_share']}",
        k=5
    )

    # 3) (optional) geo retrieval
    user_lat, user_lon = 37.9838, 23.7275  # Athens center-ish
    places_payload = retrieve_nearby_budget_places(
        places=PLACES,
        metrics=metrics,
        user_lat=user_lat,
        user_lon=user_lon,
        city="Athens",
        radius_m=2000.0,
        max_results=5
    )

    # 4) build a single prompt (no tool calling yet, just a straight test)
    prompt = f"""
USER: I want advice to save more and also cheap lunch options near me.

METRICS_BUNDLE:
{json.dumps(metrics_bundle, ensure_ascii=False, indent=2)}

KB_SNIPPETS:
{json.dumps(kb_docs, ensure_ascii=False, indent=2)}

NEARBY_PLACES (use only these):
{json.dumps(places_payload['results'], ensure_ascii=False, indent=2)}
"""

    resp = client.responses.create(
        model="gpt-5.2",
        instructions=INSTRUCTIONS,
        input=prompt
    )

    print(resp.output_text)

if __name__ == "__main__":
    test_once()
