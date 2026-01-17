from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from . import views

urlpatterns = [
    # Auth
    path("auth/register/", views.register),
    path("auth/login/", TokenObtainPairView.as_view()),
    path("auth/refresh/", TokenRefreshView.as_view()),

    # User
    path("me/", views.me),

    # Budgets
    path("budgets/", views.budgets_list),
    path("budgets/update/", views.budget_update),

    # Spending
    path("spending/", views.spending_list),
    path("spending/update/", views.spending_update),
    path('spending/add-receipt/', views.add_spending, name='add-receipt'),
    
    # Leaderboard
    path("leaderboard/", views.leaderboard),

    # Analytics & Insights
    path("analytics/peer-averages/", views.peer_averages),
    path("insights/categories/", views.category_insights),           # ✅ NEW: Per-category insights
    path("insights/category-ai/", views.category_insight_ai),        # ✅ NEW: AI insight for one category
    path("insights/daily/", views.daily_insight),                    # General overview insight
    
    # Chat & Recommendations
    # Analytics & Insights
    path("analytics/peer-averages/", views.peer_averages),
    path("insights/categories/", views.category_insights),           # ✅ NEW: Per-category insights
    path("insights/category-ai/", views.category_insight_ai),        # ✅ NEW: AI insight for one category
    path("insights/daily/", views.daily_insight),                    # General overview insight
]
