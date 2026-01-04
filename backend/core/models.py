from django.db import models
from django.contrib.auth.models import AbstractUser

class User(AbstractUser):
    # Existing
    full_name = models.CharField(max_length=120, blank=True)
    age = models.PositiveIntegerField(null=True, blank=True)

    # ✅ New fields
    date_of_birth = models.DateField(null=True, blank=True)
    city = models.CharField(max_length=120, blank=True)
    country = models.CharField(max_length=120, blank=True)
    university = models.CharField(max_length=180, blank=True)

    def __str__(self):
        return self.username

class Category(models.TextChoices):
    RENT = "rent", "Rent"
    UTILITIES = "utilities", "Utilities"
    ENTERTAINMENT = "entertainment", "Entertainment"
    GROCERIES = "groceries", "Groceries"
    TRANSPORTATION = "transportation", "Transportation"
    HEALTHCARE = "healthcare", "Healthcare"
    SAVINGS = "savings", "Savings"
    OTHER = "other", "Other"


class Budget(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="budgets")
    category = models.CharField(max_length=32, choices=Category.choices)
    amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    class Meta:
        unique_together = ("user", "category")

    def __str__(self):
        return f"{self.user.username} - {self.category}: {self.amount}"


class Spending(models.Model):
    """
    For now: a single variable per category, per user.
    Later: you can store bank_spent + receipt_spent separately and compute total.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="spending")
    category = models.CharField(max_length=32, choices=Category.choices)
    amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)

    class Meta:
        unique_together = ("user", "category")

    def __str__(self):
        return f"{self.user.username} - {self.category}: {self.amount}"