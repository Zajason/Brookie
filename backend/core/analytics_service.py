from django.db.models import Avg
from decimal import Decimal
from .models import Spending, Budget, User, Category


class AnalyticsService:
    """Service for computing analytics and peer comparisons."""
    
    @staticmethod
    def get_peer_averages(exclude_user_id=None) -> dict:
        """
        Calculate average spending per category across all users.
        
        Args:
            exclude_user_id: Optional user ID to exclude (for comparing against others)
            
        Returns:
            Dict like {'rent': 500.00, 'groceries': 150.00, ...}
        """
        queryset = Spending.objects.all()
        
        if exclude_user_id:
            queryset = queryset.exclude(user_id=exclude_user_id)
        
        averages = {}
        
        for category_key, category_label in Category.choices:
            avg = queryset.filter(category=category_key).aggregate(
                avg_amount=Avg('amount')
            )['avg_amount']
            
            # Default to 0 if no data
            averages[category_key] = float(avg or 0)
        
        return averages
    
    @staticmethod
    def get_user_financial_data(user) -> dict:
        """
        Get all financial data for a user in a structured format.
        
        Returns:
            Dict with budgets, spending, and profile info
        """
        budgets = list(Budget.objects.filter(user=user).values('category', 'amount'))
        spending = list(Spending.objects.filter(user=user).values('category', 'amount'))
        
        # Convert Decimal to float for JSON serialization
        for item in budgets:
            item['amount'] = float(item['amount'])
        for item in spending:
            item['amount'] = float(item['amount'])
        
        return {
            'budgets': budgets,
            'spending': spending,
            'profile': {
                'age': user.age,
                'city': user.city,
                'country': user.country,
                'university': user.university,
                'full_name': user.full_name
            }
        }
    
    @staticmethod
    def get_category_insights(user) -> list:
        """
        Generate insights for each spending category.
        
        Returns:
            List of dicts like:
            [
                {
                    'category': 'groceries',
                    'spending': 200.00,
                    'budget': 150.00,
                    'peer_average': 180.00,
                    'budget_percentage': 133.33,  # 33% over budget
                    'peer_percentage': 111.11,     # 11% more than peers
                    'insight': 'You are 33% over budget and spending 11% more than peers'
                },
                ...
            ]
        """
        # Get user's spending and budgets
        user_spending = {s.category: float(s.amount) for s in Spending.objects.filter(user=user)}
        user_budgets = {b.category: float(b.amount) for b in Budget.objects.filter(user=user)}
        
        # Get peer averages
        peer_averages = AnalyticsService.get_peer_averages(exclude_user_id=user.id)
        
        insights = []
        
        for category_key, category_label in Category.choices:
            spending = user_spending.get(category_key, 0)
            budget = user_budgets.get(category_key, 0)
            peer_avg = peer_averages.get(category_key, 0)
            
            # Skip if no spending in this category
            if spending == 0:
                continue
            
            # Calculate percentages
            budget_percentage = (spending / budget * 100) if budget > 0 else 0
            peer_percentage = (spending / peer_avg * 100) if peer_avg > 0 else 0
            
            # Generate insight text
            insight_text = AnalyticsService._generate_category_insight_text(
                category_label,
                spending,
                budget,
                peer_avg,
                budget_percentage,
                peer_percentage
            )
            
            insights.append({
                'category': category_key,
                'category_label': category_label,
                'spending': spending,
                'budget': budget,
                'peer_average': peer_avg,
                'budget_percentage': budget_percentage,
                'peer_percentage': peer_percentage,
                'insight': insight_text
            })
        
        return insights
    
    @staticmethod
    def _generate_category_insight_text(category, spending, budget, peer_avg, 
                                       budget_pct, peer_pct) -> str:
        """
        Generate human-readable insight text for a category.
        """
        insights = []
        
        # Budget comparison
        if budget > 0:
            if budget_pct > 110:  # More than 10% over budget
                over_pct = int(budget_pct - 100)
                insights.append(f"⚠️ {over_pct}% over budget")
            elif budget_pct < 90:  # More than 10% under budget
                under_pct = int(100 - budget_pct)
                insights.append(f"✅ {under_pct}% under budget")
            else:
                insights.append("✅ On track with budget")
        
        # Peer comparison
        if peer_avg > 0:
            if peer_pct > 120:  # Spending 20% more than peers
                over_pct = int(peer_pct - 100)
                insights.append(f"📊 {over_pct}% more than peers")
            elif peer_pct < 80:  # Spending 20% less than peers
                under_pct = int(100 - peer_pct)
                insights.append(f"🎉 {under_pct}% less than peers")
        
        # Combine insights
        if insights:
            return " • ".join(insights)
        else:
            return "💰 Spending looks balanced"
