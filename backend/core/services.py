from .models import Budget, Spending, Category, User

def ensure_user_rows(user: User) -> None:
    for cat in Category.values:
        Budget.objects.get_or_create(user=user, category=cat, defaults={"amount": 0})
        Spending.objects.get_or_create(user=user, category=cat, defaults={"amount": 0})
