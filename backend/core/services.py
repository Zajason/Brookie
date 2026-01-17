from django.utils import timezone
from django.db.models import Sum
from .models import Spending, Budget, Category

def ensure_user_rows(user):
    for cat, _ in Category.choices:
        Budget.objects.get_or_create(user=user, category=cat, defaults={"amount": 0})

    today = timezone.now().date()
    month_start = today.replace(day=1)

    for cat, _ in Category.choices:
        qs = Spending.objects.filter(user=user, category=cat, date=month_start)
        if qs.exists():
            if qs.count() > 1:
                total = qs.aggregate(total=Sum("amount"))["total"] or 0
                keep = qs.order_by("id").first()
                keep.amount = total
                keep.save(update_fields=["amount"])
                qs.exclude(id=keep.id).delete()
        else:
            Spending.objects.create(user=user, category=cat, date=month_start, amount=0)