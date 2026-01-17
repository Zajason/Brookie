from datetime import date
from .models import Budget, Spending, Category, User

def ensure_user_rows(user: User) -> None:
    for cat in Category.values:
        # Budgets: Still 1 row per category, so get_or_create is fine
        Budget.objects.get_or_create(user=user, category=cat, defaults={"amount": 0})

        # Spending: NOW allows multiple rows (history).
        # We only create a placeholder if the user has ZERO history for this category.
        if not Spending.objects.filter(user=user, category=cat).exists():
            Spending.objects.create(
                user=user, 
                category=cat, 
                amount=0, 
                date=date.today()
            )