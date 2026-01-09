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
]
