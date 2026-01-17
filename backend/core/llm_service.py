# backend/core/llm_service.py

import os
import json
from typing import Dict, List, Any

from django.conf import settings
from openai import OpenAI

def _get_api_key() -> str:
    return os.getenv("OPENAI_API_KEY") or getattr(settings, "OPENAI_API_KEY", "")

# OpenAI client (openai-python >= 1.0.0)
client = OpenAI(api_key=_get_api_key())


class LLMService:
    """Service for generating financial insights and advice using OpenAI."""

    # Good default: fast + cheap + strong
    MODEL = "gpt-4o-mini"

    # -----------------------------
    # Core helper (THIS fixes your _chat missing issue)
    # -----------------------------
    @staticmethod
    def _chat(messages: List[Dict[str, str]], max_tokens: int, temperature: float) -> str:
        resp = client.chat.completions.create(
            model=LLMService.MODEL,
            messages=messages,
            max_tokens=max_tokens,
            temperature=temperature,
        )
        return (resp.choices[0].message.content or "").strip()

    # -----------------------------
    # One-line dashboard insight
    # -----------------------------
    @staticmethod
    def generate_one_line_insight(user_data: Dict, peer_averages: Dict) -> str:
        prompt = f"""
You are a financial advisor for students. Generate ONE concise insight (max 15 words) based on this data:

USER SPENDING:
{LLMService._format_spending(user_data.get('spending', []))}

USER BUDGET:
{LLMService._format_budgets(user_data.get('budgets', []))}

PEER AVERAGES (other students):
{LLMService._format_peer_averages(peer_averages)}

USER PROFILE:
- Age: {user_data.get('profile', {}).get('age', 'N/A')}
- City: {user_data.get('profile', {}).get('city', 'N/A')}
- University: {user_data.get('profile', {}).get('university', 'N/A')}

Rules:
1. One sentence only, max 15 words
2. Be encouraging if doing well, constructive if overspending
3. Compare to peers or budget when relevant
4. Make it actionable
"""

        try:
            return LLMService._chat(
                messages=[
                    {"role": "system", "content": "You are a helpful financial advisor for students. Be concise and encouraging."},
                    {"role": "user", "content": prompt},
                ],
                max_tokens=60,
                temperature=0.7,
            )
        except Exception as e:
            print(f"Error generating insight: {e}")
            return "Keep tracking your spending to build better financial habits! 💰"

    # -----------------------------
    # Category insight (short)
    # -----------------------------
    @staticmethod
    def generate_category_insight(
        category: str,
        spending: float,
        budget: float,
        peer_average: float,
        user_profile: Dict
    ) -> str:
        budget_diff = ((spending - budget) / budget * 100) if budget > 0 else 0
        peer_diff = ((spending - peer_average) / peer_average * 100) if peer_average > 0 else 0

        prompt = f"""
Generate ONE short insight (max 20 words) for this spending category:

Category: {category.title()}
User Spending: ${spending:.2f}
User Budget: ${budget:.2f}
Peer Average: ${peer_average:.2f}

Budget Status: {budget_diff:+.0f}% ({'over' if budget_diff > 0 else 'under'} budget)
Peer Comparison: {peer_diff:+.0f}% ({'more' if peer_diff > 0 else 'less'} than peers)

Rules:
1. Maximum 20 words
2. Be specific about percentages
3. Use emojis (✅ for good, ⚠️ for concerning)
4. Be encouraging if doing well, constructive if overspending
"""

        try:
            return LLMService._chat(
                messages=[
                    {"role": "system", "content": "You are a financial advisor. Be concise and specific with numbers."},
                    {"role": "user", "content": prompt},
                ],
                max_tokens=90,
                temperature=0.7,
            )
        except Exception as e:
            print(f"Error generating category insight: {e}")
            # Fallback rule-based
            if budget > 0 and spending > budget * 1.1:
                over = int((spending - budget) / budget * 100)
                return f"⚠️ {over}% over budget in {category}"
            if peer_average > 0 and spending < peer_average * 0.8:
                under = int((peer_average - spending) / peer_average * 100)
                return f"✅ {under}% less than peers - great work!"
            return f"💰 {category.title()} spending looks balanced"

    # -----------------------------
    # Chat assistant (Markdown + Places support)
    # -----------------------------
    @staticmethod
    def chat_financial_advice(
        user_data: Dict,
        peer_averages: Dict,
        conversation_history: List[Dict[str, str]],
        user_message: str,
        extra_context: str = "",
    ) -> str:
        """
        conversation_history format:
          [{"role":"user","content":"..."}, {"role":"assistant","content":"..."}]
        extra_context:
          optional text injected into system prompt (e.g., REAL LOCAL PLACES list).
        """

        context = f"""
You are a friendly financial advisor chatbot for college students.

Output MUST be Markdown:
- Use short paragraphs
- Use bullet lists when listing options
- Use **bold** for emphasis
- If you include links, format as [Text](https://...)

Here is the user's financial context:

CURRENT SPENDING:
{LLMService._format_spending(user_data.get('spending', []))}

BUDGET:
{LLMService._format_budgets(user_data.get('budgets', []))}

PEER AVERAGES:
{LLMService._format_peer_averages(peer_averages)}

USER INFO:
- Age: {user_data.get('profile', {}).get('age', 'N/A')}
- City: {user_data.get('profile', {}).get('city', 'N/A')}
- University: {user_data.get('profile', {}).get('university', 'N/A')}

Rules:
1) Be encouraging and actionable; reference their numbers when relevant.
2) Keep it concise (2–6 short lines).
3) If the user asks for restaurants/shops AND a REAL LOCAL PLACES list is provided below:
   - Recommend ONLY from that list (do not invent places).
   - Provide 3–5 options max.
   - Use Markdown bullets.
   - Include the provided [Maps](...) link for each.
4) If REAL LOCAL PLACES is NOT provided and they ask for specific places:
   - Ask for their city or enable Places API.

{extra_context}
""".strip()

        messages: List[Dict[str, str]] = [{"role": "system", "content": context}]

        # Add last 10 messages for continuity
        if conversation_history:
            messages.extend(conversation_history[-10:])

        messages.append({"role": "user", "content": user_message})

        try:
            return LLMService._chat(messages=messages, max_tokens=320, temperature=0.8)
        except Exception as e:
            print(f"Error in chat: {e}")
            return "I'm having trouble connecting right now. Please try again in a moment!"

    # -----------------------------
    # (Optional) GPT-only recommendations fallback (not ideal without Places API)
    # -----------------------------
    @staticmethod
    def recommend_local_places(user_data: Dict, category: str) -> List[Dict[str, Any]]:
        """
        NOTE: This can hallucinate if you don't back it with a real Places API.
        Prefer: fetch real places server-side, then have chat_financial_advice rank them.
        """
        city = user_data.get('profile', {}).get('city') or "your area"

        prompt = f"""
List 5 budget-friendly {category} places in {city} for college students.

Return ONLY valid JSON array with fields:
- name
- type
- estimated_cost
- tip
"""

        try:
            txt = LLMService._chat(
                messages=[
                    {"role": "system", "content": "You are a local guide helping students find budget-friendly places."},
                    {"role": "user", "content": prompt},
                ],
                max_tokens=450,
                temperature=0.7,
            )
            return json.loads(txt)
        except Exception as e:
            print(f"Error generating recommendations: {e}")
            return [{
                "name": "Local Budget Options",
                "type": "General",
                "estimated_cost": "Varies",
                "tip": "Check student discount apps like UNiDAYS or Student Beans"
            }]

    # -----------------------------
    # Helpers
    # -----------------------------
    @staticmethod
    def _format_spending(spending_list: List[Dict]) -> str:
        lines = []
        for item in spending_list:
            cat = str(item.get("category", "")).title()
            amt = item.get("amount", 0)
            lines.append(f"- {cat}: ${amt}")
        return "\n".join(lines) if lines else "No spending recorded"

    @staticmethod
    def _format_budgets(budget_list: List[Dict]) -> str:
        lines = []
        for item in budget_list:
            cat = str(item.get("category", "")).title()
            amt = item.get("amount", 0)
            lines.append(f"- {cat}: ${amt}")
        return "\n".join(lines) if lines else "No budget set"

    @staticmethod
    def _format_peer_averages(averages: Dict) -> str:
        lines = []
        for category, amount in (averages or {}).items():
            try:
                amount_f = float(amount)
            except Exception:
                amount_f = 0.0
            lines.append(f"- {str(category).title()}: ${amount_f:.2f}")
        return "\n".join(lines) if lines else "No peer data available"
