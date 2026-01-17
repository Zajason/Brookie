from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from decimal import Decimal
from datetime import date
from django.db.models import Sum
from .llm_service import LLMService
from .analytics_service import AnalyticsService

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
    
    # Group by category and SUM the amounts
    qs = Spending.objects.filter(user=request.user) \
        .values('category') \
        .annotate(amount=Sum('amount')) \
        .order_by('category')
        
    # 'qs' is now a list of dictionaries: [{'category': 'rent', 'amount': 500}, ...]
    # This matches what the frontend expects for the wheel
    return Response(qs)


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
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def peer_averages(request):
    """
    Get average spending across all users by category.
    """
    averages = AnalyticsService.get_peer_averages(exclude_user_id=request.user.id)
    return Response(averages)


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def category_insights(request):
    """
    Get insights for each spending category.
    Returns detailed comparison with budget and peers.
    """
    ensure_user_rows(request.user)
    
    insights = AnalyticsService.get_category_insights(request.user)
    
    return Response({"insights": insights})


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def category_insight_ai(request):
    """
    Get AI-generated insight for a specific category.
    Query params: ?category=groceries
    """
    ensure_user_rows(request.user)
    
    category = request.GET.get("category")
    if not category:
        return Response({"error": "Category parameter required"}, status=status.HTTP_400_BAD_REQUEST)
    
    # Get user data
    user_spending = Spending.objects.filter(user=request.user, category=category).first()
    user_budget = Budget.objects.filter(user=request.user, category=category).first()
    
    spending_amount = float(user_spending.amount) if user_spending else 0
    budget_amount = float(user_budget.amount) if user_budget else 0
    
    # Get peer average for this category
    peer_averages = AnalyticsService.get_peer_averages(exclude_user_id=request.user.id)
    peer_avg = peer_averages.get(category, 0)
    
    # Get user profile
    user_profile = {
        'age': request.user.age,
        'city': request.user.city,
        'university': request.user.university
    }
    
    # Generate AI insight
    insight = LLMService.generate_category_insight(
        category,
        spending_amount,
        budget_amount,
        peer_avg,
        user_profile
    )
    
    return Response({
        "category": category,
        "insight": insight,
        "spending": spending_amount,
        "budget": budget_amount,
        "peer_average": peer_avg
    })


# Keep the old daily_insight but make it simpler
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def daily_insight(request):
    """
    Generate a general one-line financial insight for the dashboard.
    This is an overall summary, not category-specific.
    """
    ensure_user_rows(request.user)
    
    user_data = AnalyticsService.get_user_financial_data(request.user)
    peer_averages = AnalyticsService.get_peer_averages(exclude_user_id=request.user.id)
    
    insight = LLMService.generate_one_line_insight(user_data, peer_averages)
    
    return Response({"insight": insight})

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def add_spending(request):
    user = request.user
    data = request.data

    category = data.get('category', '').lower()
    try:
        amount = Decimal(str(data.get('amount', 0)))
    except:
        return Response({"error": "Invalid amount"}, status=status.HTTP_400_BAD_REQUEST)

    # Date Handling
    date_str = data.get('date')
    if date_str:
        try:
            spending_date = date.fromisoformat(date_str)
        except ValueError:
            return Response({"error": "Invalid date format"}, status=status.HTTP_400_BAD_REQUEST)
    else:
        spending_date = date.today()

    if amount <= 0:
        return Response({"error": "Amount must be positive"}, status=status.HTTP_400_BAD_REQUEST)
    
    # Logic: Get existing or Create new
    spending_entry, created = Spending.objects.get_or_create(
        user=user,
        category=category,
        date=spending_date,
        defaults={'amount': amount}
    )

    if not created:
        spending_entry.amount += amount
        spending_entry.save()
        message = f"Updated {category} for {spending_date}. New total: {spending_entry.amount}"
    else:
        message = f"Created {category} for {spending_date} with {amount}"

    return Response({
        "message": message,
        "amount": str(spending_entry.amount),
        "date": str(spending_entry.date),
        "category": spending_entry.category
    }, status=status.HTTP_201_CREATED)