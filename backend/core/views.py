from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from decimal import Decimal
from django.db.models import Sum

from .models import Budget, Spending, User
from .serializers import (
    RegisterSerializer,
    UserSerializer,
    BudgetSerializer,
    SpendingSerializer,
    BudgetUpdateSerializer,
    SpendingUpdateSerializer,
)
from .services import ensure_user_rows


@api_view(["POST"])
@permission_classes([AllowAny])
def register(request):
    serializer = RegisterSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)
    user = serializer.save()
    return Response(UserSerializer(user).data, status=status.HTTP_201_CREATED)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def me(request):
    # Make sure rows exist even if user was created another way
    ensure_user_rows(request.user)
    return Response(UserSerializer(request.user).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def budgets_list(request):
    ensure_user_rows(request.user)
    qs = Budget.objects.filter(user=request.user).order_by("category")
    return Response(BudgetSerializer(qs, many=True).data)


@api_view(["PATCH"])
@permission_classes([IsAuthenticated])
def budget_update(request):
    serializer = BudgetUpdateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    cat = serializer.validated_data["category"]
    amount = serializer.validated_data["amount"]

    obj, _ = Budget.objects.get_or_create(user=request.user, category=cat)
    obj.amount = amount
    obj.save()
    return Response(BudgetSerializer(obj).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def spending_list(request):
    ensure_user_rows(request.user)
    qs = Spending.objects.filter(user=request.user).order_by("category")
    return Response(SpendingSerializer(qs, many=True).data)


@api_view(["PATCH"])
@permission_classes([IsAuthenticated])
def spending_update(request):
    """
    For now, you can update spending directly (e.g., simulate bank sync or receipt add).
    Later you will compute this from bank txns + receipt txns.
    """
    serializer = SpendingUpdateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    cat = serializer.validated_data["category"]
    amount = serializer.validated_data["amount"]

    obj, _ = Spending.objects.get_or_create(user=request.user, category=cat)
    obj.amount = amount
    obj.save()
    return Response(SpendingSerializer(obj).data)

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def add_receipt_spending(request):
    """
    Increments the spending for a category based on a scanned receipt.
    """
    cat = request.data.get("category")
    amount_str = request.data.get("amount")
    
    if not cat or amount_str is None:
        return Response({"error": "Category and amount required"}, status=status.HTTP_400_BAD_REQUEST)

    try:
        amount_to_add = Decimal(str(amount_str))
    except:
        return Response({"error": "Invalid amount format"}, status=status.HTTP_400_BAD_REQUEST)

    # Get the existing row or create a new one starting at 0
    obj, _ = Spending.objects.get_or_create(user=request.user, category=cat, defaults={'amount': 0})
    
    # Increment the total
    obj.amount += amount_to_add
    obj.save()
    
    return Response(SpendingSerializer(obj).data)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def leaderboard(request):
    """
    Returns top 10 users by total spending (lowest = best) and current user's rank.
    Optional query params: 
      - ?category=groceries (filter by category)
      - ?period=month or ?period=year (filter by time period)
    """
    from django.utils import timezone
    from datetime import timedelta
    
    category = request.GET.get("category", None)
    period = request.GET.get("period", "month")  # default to month
    
    # Calculate date range based on period
    now = timezone.now().date()
    if period == "year":
        # Last 12 months (approximately 365 days)
        start_date = now - timedelta(days=365)
    else:  # month (default)
        start_date = now.replace(day=1)
    
    # Build aggregation query with date filtering
    base_qs = Spending.objects.filter(date__gte=start_date)
    
    if category and category != "total":
        # Filter by specific category
        user_totals = (
            base_qs.filter(category=category)
            .values("user_id")
            .annotate(total=Sum("amount"))
            .order_by("total")
        )
    else:
        # Total across all categories
        user_totals = (
            base_qs.values("user_id")
            .annotate(total=Sum("amount"))
            .order_by("total")
        )
    
    # Convert to list for ranking
    ranked_list = list(user_totals)
    
    # Get top 10
    top_10_data = ranked_list[:10]
    
    # Build top 10 response with user details
    top_10 = []
    for idx, entry in enumerate(top_10_data):
        user = User.objects.get(id=entry["user_id"])
        top_10.append({
            "rank": idx + 1,
            "user_id": user.id,
            "username": user.username,
            "full_name": user.full_name or user.username,
            "amount": float(entry["total"] or 0),
        })
    
    # Find current user's rank and amount
    current_user_rank = None
    current_user_amount = 0
    for idx, entry in enumerate(ranked_list):
        if entry["user_id"] == request.user.id:
            current_user_rank = idx + 1
            current_user_amount = float(entry["total"] or 0)
            break
    
    # If user has no spending yet
    if current_user_rank is None:
        current_user_rank = len(ranked_list) + 1
        current_user_amount = 0
    
    return Response({
        "top_10": top_10,
        "current_user": {
            "rank": current_user_rank,
            "user_id": request.user.id,
            "username": request.user.username,
            "full_name": request.user.full_name or request.user.username,
            "amount": current_user_amount,
        },
        "total_users": len(ranked_list) if ranked_list else 1,
    })