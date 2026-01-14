import openai
import os
from typing import Dict, List
from django.conf import settings

# Initialize OpenAI
openai.api_key = os.getenv('OPENAI_API_KEY') or getattr(settings, 'OPENAI_API_KEY', '')


class LLMService:
    """Service for generating financial insights and advice using OpenAI."""
    
    MODEL = "gpt-3.5-turbo"  # or "gpt-4" if you have access
    
    @staticmethod
    def generate_one_line_insight(user_data: Dict, peer_averages: Dict) -> str:
        """
        Generate a short, actionable one-line insight.
        
        Args:
            user_data: {
                'budgets': [{'category': 'rent', 'amount': 500}, ...],
                'spending': [{'category': 'rent', 'amount': 450}, ...],
                'profile': {'age': 22, 'city': 'Boston', 'university': 'MIT'}
            }
            peer_averages: {
                'rent': 600,
                'groceries': 200,
                ...
            }
        
        Returns:
            String with one-line insight
        """
        
        prompt = f"""
You are a financial advisor for students. Generate ONE concise insight (max 15 words) based on this data:

USER SPENDING:
{LLMService._format_spending(user_data['spending'])}

USER BUDGET:
{LLMService._format_budgets(user_data['budgets'])}

PEER AVERAGES (other students):
{LLMService._format_peer_averages(peer_averages)}

USER PROFILE:
- Age: {user_data['profile'].get('age', 'N/A')}
- City: {user_data['profile'].get('city', 'N/A')}
- University: {user_data['profile'].get('university', 'N/A')}

Rules:
1. One sentence only, max 15 words
2. Be encouraging if doing well, constructive if overspending
3. Compare to peers or budget when relevant
4. Make it actionable

Example outputs:
- "You're spending 30% less on groceries than peers—great job! 🎉"
- "Entertainment spending is 2x your budget. Try cutting back this week."
- "On track in all categories. Keep it up! 💪"
"""
        
        try:
            response = openai.ChatCompletion.create(
                model=LLMService.MODEL,
                messages=[
                    {"role": "system", "content": "You are a helpful financial advisor for students. Be concise and encouraging."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=50,
                temperature=0.7
            )
            
            insight = response.choices[0].message.content.strip()
            return insight
            
        except Exception as e:
            print(f"Error generating insight: {e}")
            return "Keep tracking your spending to build better financial habits! 💰"
    
    @staticmethod
    def generate_category_insight(category: str, spending: float, budget: float, 
                                  peer_average: float, user_profile: Dict) -> str:
        """
        Generate a short insight for a specific category.
        
        Args:
            category: e.g., 'groceries'
            spending: User's spending in this category
            budget: User's budget for this category
            peer_average: Average spending of peers
            user_profile: User's demographic info
            
        Returns:
            Short insight text (max 20 words)
        """
        
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

Examples:
- "⚠️ You're spending 45% more than your budget in groceries. Try meal planning!"
- "✅ Great job! You're spending 30% less than peers on entertainment."
- "⚠️ Rent is 20% over budget and 15% above peer average."
"""
        
        try:
            response = openai.ChatCompletion.create(
                model=LLMService.MODEL,
                messages=[
                    {"role": "system", "content": "You are a financial advisor. Be concise and specific with numbers."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=40,
                temperature=0.7
            )
            
            return response.choices[0].message.content.strip()
            
        except Exception as e:
            print(f"Error generating category insight: {e}")
            # Fallback to rule-based insight
            if budget > 0 and spending > budget * 1.1:
                over = int((spending - budget) / budget * 100)
                return f"⚠️ {over}% over budget in {category}"
            elif peer_average > 0 and spending < peer_average * 0.8:
                under = int((peer_average - spending) / peer_average * 100)
                return f"✅ {under}% less than peers - great work!"
            else:
                return f"💰 {category.title()} spending looks balanced"
    
    @staticmethod
    def chat_financial_advice(user_data: Dict, peer_averages: Dict, 
                             conversation_history: List[Dict], user_message: str) -> str:
        """
        Have a conversation about budgeting and financial advice.
        
        Args:
            user_data: Same as above
            peer_averages: Same as above
            conversation_history: [{'role': 'user', 'content': '...'}, {'role': 'assistant', 'content': '...'}]
            user_message: The current user's question
            
        Returns:
            AI response
        """
        
        context = f"""
You are a friendly financial advisor chatbot for college students. Here's the user's financial data:

CURRENT SPENDING:
{LLMService._format_spending(user_data['spending'])}

BUDGET:
{LLMService._format_budgets(user_data['budgets'])}

PEER AVERAGES:
{LLMService._format_peer_averages(peer_averages)}

USER INFO:
- Age: {user_data['profile'].get('age', 'N/A')}
- City: {user_data['profile'].get('city', 'N/A')}
- University: {user_data['profile'].get('university', 'N/A')}

Guidelines:
1. Be encouraging and supportive
2. Give specific, actionable advice
3. Reference their actual numbers when relevant
4. Suggest realistic student-friendly tips
5. Keep responses concise (2-4 sentences)
"""
        
        messages = [
            {"role": "system", "content": context}
        ]
        
        # Add conversation history (last 10 messages to avoid token limits)
        messages.extend(conversation_history[-10:])
        
        # Add current message
        messages.append({"role": "user", "content": user_message})
        
        try:
            response = openai.ChatCompletion.create(
                model=LLMService.MODEL,
                messages=messages,
                max_tokens=250,
                temperature=0.8
            )
            
            return response.choices[0].message.content.strip()
            
        except Exception as e:
            print(f"Error in chat: {e}")
            return "I'm having trouble connecting right now. Please try again in a moment!"
    
    @staticmethod
    def recommend_local_places(user_data: Dict, category: str) -> List[Dict]:
        """
        Recommend budget-friendly local places based on user's city and category.
        Note: This uses GPT to generate suggestions. For real location data,
        integrate Google Places API or similar.
        
        Args:
            user_data: User profile data
            category: 'groceries', 'entertainment', 'food', etc.
            
        Returns:
            List of recommendations with name, type, and estimated budget
        """
        
        city = user_data['profile'].get('city', 'your area')
        
        prompt = f"""
List 5 budget-friendly {category} places in {city} for college students.
Format as JSON array with: name, type, estimated_cost, tip

Example format:
[
  {{"name": "Trader Joe's", "type": "Grocery Store", "estimated_cost": "$30-50/week", "tip": "Great for affordable healthy snacks"}},
  ...
]

Make it realistic for {city}. If you don't know {city}, use generic student-friendly tips.
"""
        
        try:
            response = openai.ChatCompletion.create(
                model=LLMService.MODEL,
                messages=[
                    {"role": "system", "content": "You are a local guide helping students find budget-friendly places."},
                    {"role": "user", "content": prompt}
                ],
                max_tokens=400,
                temperature=0.7
            )
            
            import json
            recommendations = json.loads(response.choices[0].message.content.strip())
            return recommendations
            
        except Exception as e:
            print(f"Error generating recommendations: {e}")
            return [
                {
                    "name": "Local Budget Options",
                    "type": "General",
                    "estimated_cost": "Varies",
                    "tip": "Check student discount apps like UNiDAYS or Student Beans"
                }
            ]
    
    # Helper methods
    @staticmethod
    def _format_spending(spending_list: List[Dict]) -> str:
        """Format spending list for prompt."""
        lines = []
        for item in spending_list:
            lines.append(f"- {item['category'].title()}: ${item['amount']}")
        return "\n".join(lines) if lines else "No spending recorded"
    
    @staticmethod
    def _format_budgets(budget_list: List[Dict]) -> str:
        """Format budget list for prompt."""
        lines = []
        for item in budget_list:
            lines.append(f"- {item['category'].title()}: ${item['amount']}")
        return "\n".join(lines) if lines else "No budget set"
    
    @staticmethod
    def _format_peer_averages(averages: Dict) -> str:
        """Format peer averages for prompt."""
        lines = []
        for category, amount in averages.items():
            lines.append(f"- {category.title()}: ${amount:.2f}")
        return "\n".join(lines) if lines else "No peer data available"
