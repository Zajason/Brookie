# rag_openai_budget_assistant.py
from __future__ import annotations

import json
import os
from typing import Any, Dict, List, Optional

from openai import OpenAI

# Your modules from earlier:
from financial_model import BudgetScorer
from geo_retrieval import load_places_jsonl, retrieve_nearby_budget_places
from rag_assistant import load_budget_kb_jsonl, simple_kb_retrieve  # or keep in same file

client = OpenAI()

# Load resources once at startup
PLACES = load_places_jsonl("places_synthetic.jsonl")
KB = load_budget_kb_jsonl("budget_kb.jsonl")
SCORER = BudgetScorer()


# ----------------------------
# Tool implementations (yours)
# ----------------------------
def tool_get_budget_metrics(user_budget: Dict[str, Any]) -> Dict[str, Any]:
    """
    user_budget should include: total_spending, rent, utilities, entertainment, groceries,
    transportation, savings, healthcare, other
    """
    return SCORER.evaluate(user_budget)


def tool_search_budget_kb(query: str, k: int = 5) -> Dict[str, Any]:
    docs = simple_kb_retrieve(KB, query, k=k)
    # Keep only fields you want the model to see
    return {"results": [{"doc_id": d["doc_id"], "topic": d["topic"], "tags": d.get("tags", []), "text": d["text"]} for d in docs]}


def tool_geo_retrieve_places(
    metrics: Dict[str, Any],
    lat: float,
    lon: float,
    city: Optional[str] = None,
    radius_m: float = 2000.0,
    max_results: int = 8,
) -> Dict[str, Any]:
    return retrieve_nearby_budget_places(
        places=PLACES,
        metrics=metrics,
        user_lat=lat,
        user_lon=lon,
        city=city,
        radius_m=radius_m,
        max_results=max_results,
    )


# ----------------------------
# Tool schema for the model
# ----------------------------
TOOLS = [
    {
        "type": "function",
        "name": "get_budget_metrics",
        "description": "Compute budgeting metrics and a score from a user's monthly spending breakdown.",
        "parameters": {
            "type": "object",
            "properties": {
                "user_budget": {
                    "type": "object",
                    "properties": {
                        "total_spending": {"type": "number"},
                        "rent": {"type": "number"},
                        "utilities": {"type": "number"},
                        "entertainment": {"type": "number"},
                        "groceries": {"type": "number"},
                        "transportation": {"type": "number"},
                        "savings": {"type": "number"},
                        "healthcare": {"type": "number"},
                        "other": {"type": "number"},
                    },
                    "required": ["total_spending","rent","utilities","entertainment","groceries","transportation","savings","healthcare","other"],
                }
            },
            "required": ["user_budget"]
        },
    },
    {
        "type": "function",
        "name": "search_budget_kb",
        "description": "Retrieve budgeting tips and guidance snippets relevant to the user's situation.",
        "parameters": {
            "type": "object",
            "properties": {
                "query": {"type": "string"},
                "k": {"type": "integer", "default": 5}
            },
            "required": ["query"]
        },
    },
    {
        "type": "function",
        "name": "geo_retrieve_places",
        "description": "Suggest nearby budget-friendly places (shops/restaurants) based on user location and spending metrics. Use ONLY for local place recommendations.",
        "parameters": {
            "type": "object",
            "properties": {
                "metrics": {"type": "object", "description": "Metrics object returned by get_budget_metrics (or equivalent)."},
                "lat": {"type": "number"},
                "lon": {"type": "number"},
                "city": {"type": "string"},
                "radius_m": {"type": "number", "default": 2000},
                "max_results": {"type": "integer", "default": 8}
            },
            "required": ["metrics","lat","lon"]
        },
    },
]


# ----------------------------
# Assistant instructions
# ----------------------------
INSTRUCTIONS = """
You are a personal budgeting assistant for Greek students.

You MUST:
- Comment based on the user's category spending and metrics (savings_rate, rent_share, wants_share, groceries_share).
- Be practical and non-judgmental.
- When suggesting places, call geo_retrieve_places and ONLY recommend places returned by the tool. Never invent a place.
- If the user asks for “near me/κοντά μου” and location is missing, ask them to enable location or share an area.

Response style:
- Short sections: "What I notice", "What to do next", and optionally "Nearby picks".
- Give 2–5 concrete actions with approximate € impact when possible.
"""


# ----------------------------
# The main chat loop (1 turn)
# ----------------------------
def respond(
    user_message: str,
    user_budget: Optional[Dict[str, Any]] = None,
    user_location: Optional[Dict[str, float]] = None,
    city: Optional[str] = None,
) -> str:
    """
    user_budget: pass if you want the model to compute metrics this turn.
    user_location: {"lat":..., "lon":...} if available.
    """

    # We feed the model the user's message + optional structured context
    input_payload: List[Dict[str, Any]] = [{"role": "user", "content": user_message}]

    if user_budget is not None:
        input_payload.append({
            "role": "user",
            "content": f"User monthly budget JSON (use get_budget_metrics): {json.dumps(user_budget, ensure_ascii=False)}"
        })

    if user_location is not None:
        input_payload.append({
            "role": "user",
            "content": f"User location: lat={user_location['lat']}, lon={user_location['lon']}, city={city or 'unknown'}"
        })

    # First model call (may request tool calls)
    resp = client.responses.create(
        model="gpt-5.2",
        instructions=INSTRUCTIONS,
        input=input_payload,
        tools=TOOLS,
    )

    # Tool-calling loop: keep executing tool calls until the model returns final text
    while True:
        # If the model produced a final answer, it will be in output_text
        if getattr(resp, "output_text", None):
            return resp.output_text

        # Otherwise, look for function/tool calls in resp.output
        tool_calls = []
        for item in resp.output:
            # SDK structures can vary by version; we keep it defensive
            if getattr(item, "type", None) == "tool_call":
                tool_calls.append(item)

        if not tool_calls:
            # Fallback: if no tool calls and no output_text, return a safe message
            return "I couldn’t generate a response this time — can you retry?"

        tool_outputs = []
        for call in tool_calls:
            name = call.name
            args = call.arguments
            if isinstance(args, str):
                args = json.loads(args)

            if name == "get_budget_metrics":
                out = tool_get_budget_metrics(args["user_budget"])

            elif name == "search_budget_kb":
                out = tool_search_budget_kb(args["query"], k=args.get("k", 5))

            elif name == "geo_retrieve_places":
                # If city exists from the app, pass it through
                if city and "city" not in args:
                    args["city"] = city
                out = tool_geo_retrieve_places(
                    metrics=args["metrics"],
                    lat=args["lat"],
                    lon=args["lon"],
                    city=args.get("city"),
                    radius_m=args.get("radius_m", 2000.0),
                    max_results=args.get("max_results", 8),
                )
            else:
                out = {"error": f"Unknown tool: {name}"}

            tool_outputs.append({
                "type": "tool_result",
                "tool_call_id": call.id,
                "output": out
            })

        # Send tool outputs back to the model
        resp = client.responses.create(
            model="gpt-5.2",
            instructions=INSTRUCTIONS,
            input=input_payload,
            tools=TOOLS,
            previous_response_id=resp.id,
            tool_results=tool_outputs,
        )
