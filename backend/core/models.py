from django.db import models
from django.contrib.auth.models import AbstractUser
from django.conf import settings



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
    
class ChatThread(models.Model):
    user = models.ForeignKey(settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name="chat_threads")
    title = models.CharField(max_length=120, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

class ChatMessage(models.Model):
    thread = models.ForeignKey(ChatThread, on_delete=models.CASCADE, related_name="messages")
    role = models.CharField(max_length=20, choices=[("user","user"), ("assistant","assistant")])
    content = models.TextField()
    created_at = models.DateTimeField(auto_now_add=True)

class Meta:
        ordering = ["created_at"]




class Spending(models.Model):
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="spending")
    category = models.CharField(max_length=32, choices=Category.choices)
    amount = models.DecimalField(max_digits=12, decimal_places=2, default=0)
    date = models.DateField(default=None, null=True, blank=True)

    class Meta:
        constraints = [
            models.UniqueConstraint(fields=["user", "category", "date"], name="uniq_spending_user_cat_date"),
        ]
        indexes = [
            models.Index(fields=["user", "date"]),
            models.Index(fields=["category", "date"]),
        ]

    def __str__(self):
        return f"{self.user.username} - {self.category}: {self.amount} ({self.date})"


class BadgeType(models.TextChoices):
    BUDGET_MASTER = "budget_master", "Budget Master"
    SAVINGS_CHAMPION = "savings_champion", "Savings Champion"
    THRIFTY_SHOPPER = "thrifty_shopper", "Thrifty Shopper"
    GOAL_CRUSHER = "goal_crusher", "Goal Crusher"
    SPENDING_SLAYER = "spending_slayer", "Spending Slayer"
    ELITE_SAVER = "elite_saver", "Elite Saver"
    SOCIAL_SAVER = "social_saver", "Social Saver"
    YEAR_LEGEND = "year_legend", "Year Legend"


class Badge(models.Model):
    """
    Badge definitions - each badge type with its metadata.
    """
    badge_type = models.CharField(max_length=32, choices=BadgeType.choices, unique=True)
    title = models.CharField(max_length=100)
    description = models.TextField()
    icon = models.CharField(max_length=50)  # Flutter icon name
    gradient_start = models.CharField(max_length=10)  # Hex color
    gradient_end = models.CharField(max_length=10)  # Hex color
    target_value = models.IntegerField(default=30)  # Target to earn (e.g., 30 days)
    category = models.CharField(max_length=32, choices=Category.choices, null=True, blank=True)  # Related category if applicable

    def __str__(self):
        return self.title


class UserBadge(models.Model):
    """
    Tracks user progress toward badges and whether they've earned them.
    """
    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name="badges")
    badge = models.ForeignKey(Badge, on_delete=models.CASCADE, related_name="user_badges")
    progress = models.IntegerField(default=0)  # Current progress value
    earned = models.BooleanField(default=False)
    earned_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        unique_together = ("user", "badge")

    def __str__(self):
        status = "✓" if self.earned else f"{self.progress}/{self.badge.target_value}"
        return f"{self.user.username} - {self.badge.title}: {status}"