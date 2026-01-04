from django.contrib import admin
from django.contrib.auth import get_user_model
from .models import Budget, Spending

User = get_user_model()

@admin.register(User)
class UserAdmin(admin.ModelAdmin):
    list_display = ("id", "username", "email", "full_name", "city", "country", "university")
    search_fields = ("username", "email", "full_name")
    list_filter = ("country", "university")


@admin.register(Budget)
class BudgetAdmin(admin.ModelAdmin):
    list_display = ("user", "category", "amount")
    list_filter = ("category",)
    search_fields = ("user__username",)


@admin.register(Spending)
class SpendingAdmin(admin.ModelAdmin):
    list_display = ("user", "category", "amount")
    list_filter = ("category",)
    search_fields = ("user__username",)
