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
    path('spending/add-receipt/', views.add_receipt_spending, name='add-receipt'),
    path('analyze-receipt/', views.analyze_receipt, name='analyze-receipt'),
    
    # Leaderboard
    path("leaderboard/", views.leaderboard),

    # Analytics & Insights
    path("analytics/peer-averages/", views.peer_averages),
    path("insights/categories/", views.category_insights),           # ✅ NEW: Per-category insights
    path("insights/category-ai/", views.category_insight_ai),        # ✅ NEW: AI insight for one category
    path("insights/daily/", views.daily_insight),                    # General overview insight
    
    # Analytics & Insights
    path("analytics/peer-averages/", views.peer_averages),
    path("insights/categories/", views.category_insights),
    path("insights/category-ai/", views.category_insight_ai),
    path("insights/daily/", views.daily_insight),
    
    # Badges
    path("badges/", views.badges_list),
    path("insights/categories/", views.category_insights),           # ✅ NEW: Per-category insights
    path("insights/category-ai/", views.category_insight_ai),        # ✅ NEW: AI insight for one category
    path("insights/daily/", views.daily_insight),                    # General overview insight


    path("chat/threads/", views.chat_threads),                 # list/create
    path("chat/threads/<int:thread_id>/", views.chat_thread),  # get history
    path("chat/threads/<int:thread_id>/message/", views.chat_message),  # send message
    path("recommendations/places/", views.recommend_places),

    
]
