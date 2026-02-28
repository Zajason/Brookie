import base64
import json
import os
import random
import logging
from openai import OpenAI
from django.conf import settings
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from decimal import Decimal
from django.db.models import Sum
from .llm_service import LLMService
from .analytics_service import AnalyticsService
from .models import ChatThread, ChatMessage
from .places_service import PlacesService
from django.utils import timezone
from datetime import datetime

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

logger = logging.getLogger(__name__)

def _is_place_request(text: str) -> bool:
    t = text.lower()
    keywords = [
        "restaurant", "restaurants", "food", "eat", "cheap", "dinner", "lunch",
        "cafe", "coffee", "bar", "souvlaki", "pizza", "burger",
        "supermarket", "groceries", "store", "shop", "shopping"
    ]
    return any(k in t for k in keywords)


def _price_level_to_hint(level):
    # Google price_level: 0-4 (not always present)
    if level is None:
        return "€"
    try:
        lvl = int(level)
    except:
        return "€"
    return ["€", "€€", "€€€", "€€€€", "€€€€€"][max(0, min(lvl, 4))]

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


from django.utils import timezone

from django.utils import timezone
from django.db.models import Sum

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def spending_list(request):
    ensure_user_rows(request.user)

    today = timezone.now().date()
    month_start = today.replace(day=1)

    # Sum all daily rows in the current month, grouped by category
    monthly = (
        Spending.objects
        .filter(user=request.user, date__gte=month_start, date__lte=today)
        .values("category")
        .annotate(amount=Sum("amount"))
        .order_by("category")
    )

    # Build response in the same shape your Flutter expects
    # (category, amount, category_label)
    rows = []
    for item in monthly:
        cat = item["category"]
        rows.append({
            "category": cat,
            "amount": float(item["amount"] or 0),
            "category_label": cat.capitalize(),  # or map properly if you have choices
        })

    # Ensure ALL categories exist (so wheel always has full list)
    # budgets_list already ensures categories, but we also guarantee spendings list returns 8 cats
    existing = {r["category"] for r in rows}
    all_cats = ["rent", "utilities", "entertainment", "groceries",
                "transportation", "healthcare", "savings", "other"]

    for cat in all_cats:
        if cat not in existing:
            rows.append({
                "category": cat,
                "amount": 0.0,
                "category_label": cat.capitalize(),
            })

    rows.sort(key=lambda x: x["category"])
    return Response(rows)


@api_view(["PATCH"])
@permission_classes([IsAuthenticated])
def spending_update(request):
    serializer = SpendingUpdateSerializer(data=request.data)
    serializer.is_valid(raise_exception=True)

    cat = serializer.validated_data["category"]
    amount = serializer.validated_data["amount"]

    today = timezone.now().date()
    month_start = today.replace(day=1)

    obj, _ = Spending.objects.get_or_create(
        user=request.user,
        category=cat,
        date=month_start,
        defaults={"amount": 0},
    )
    obj.amount = amount
    obj.save()
    return Response(SpendingSerializer(obj).data)

from django.utils import timezone

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def add_receipt_spending(request):
    cat = request.data.get("category")
    amount_str = request.data.get("amount")
    date_str = request.data.get("date")  # ✅ NEW: Get the date from the phone

    if not cat or amount_str is None:
        return Response({"error": "Category and amount required"}, status=400)

    try:
        amount_to_add = Decimal(str(amount_str))
    except:
        return Response({"error": "Invalid amount format"}, status=400)

    # ✅ NEW: Parse the specific date, or fallback to today
    if date_str:
        try:
            target_date = datetime.strptime(date_str, "%Y-%m-%d").date()
        except ValueError:
            target_date = timezone.now().date()
    else:
        target_date = timezone.now().date()

    # Normalize to the start of the month if your app only tracks monthly totals,
    # BUT since your model constraint is (user, category, date), 
    # we should probably update that SPECIFIC day's row.
    
    # Logic: Find the row for that specific Date + Category and add to it.
    obj, created = Spending.objects.get_or_create(
        user=request.user,
        category=cat,
        date=target_date, # Use the receipt date
        defaults={"amount": 0},
    )
    
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


# ─────────────────────────────────────────────────────────────────────────────
# BADGE ENDPOINTS
# ─────────────────────────────────────────────────────────────────────────────

from .models import Badge, UserBadge, Category
from django.utils import timezone
from datetime import timedelta
from django.db.models import Count


def calculate_badge_progress(user, badge):
    """
    Calculate the current progress for a user towards a specific badge.
    Returns (current_progress, is_earned).
    """
    now = timezone.now().date()
    badge_type = badge.badge_type
    target = badge.target_value
    
    if badge_type == "budget_master":
        # Stayed within grocery budget for a month (30 days)
        # Count days where daily grocery spending <= daily budget allocation
        budget = Budget.objects.filter(user=user, category="groceries").first()
        if not budget or budget.amount == 0:
            return 0, False
        
        # Count days in current month with groceries spending
        start_of_month = now.replace(day=1)
        days_in_budget = 0
        
        # Get all grocery spending this month grouped by day
        daily_spending = (
            Spending.objects.filter(user=user, category="groceries", date__gte=start_of_month)
            .values('date')
            .annotate(daily_total=Sum('amount'))
        )
        
        daily_budget = float(budget.amount) / 30  # Approximate daily budget
        
        for day_data in daily_spending:
            if day_data['daily_total'] <= Decimal(str(daily_budget * 1.1)):  # 10% tolerance
                days_in_budget += 1
        
        # Also count days with no spending as "within budget"
        days_with_spending = daily_spending.count()
        days_elapsed = (now - start_of_month).days + 1
        days_no_spending = days_elapsed - days_with_spending
        days_in_budget += days_no_spending
        
        progress = min(days_in_budget, target)
        return progress, progress >= target
    
    elif badge_type == "savings_champion":
        # Spent less than peers for 12 months
        peer_averages = AnalyticsService.get_peer_averages(exclude_user_id=user.id)
        total_peer_avg = sum(peer_averages.values())
        
        months_beating_peers = 0
        
        for i in range(12):
            # Calculate spending for each of the last 12 months
            month_start = (now.replace(day=1) - timedelta(days=30*i)).replace(day=1)
            if i == 0:
                month_end = now
            else:
                month_end = (month_start + timedelta(days=32)).replace(day=1) - timedelta(days=1)
            
            user_spending = Spending.objects.filter(
                user=user, 
                date__gte=month_start, 
                date__lte=month_end
            ).aggregate(total=Sum('amount'))['total'] or 0
            
            if float(user_spending) < total_peer_avg:
                months_beating_peers += 1
        
        return months_beating_peers, months_beating_peers >= target
    
    elif badge_type == "thrifty_shopper":
        # Stayed within entertainment budget for a month
        budget = Budget.objects.filter(user=user, category="entertainment").first()
        if not budget or budget.amount == 0:
            return 0, False
        
        start_of_month = now.replace(day=1)
        daily_budget = float(budget.amount) / 30
        
        daily_spending = (
            Spending.objects.filter(user=user, category="entertainment", date__gte=start_of_month)
            .values('date')
            .annotate(daily_total=Sum('amount'))
        )
        
        days_in_budget = 0
        for day_data in daily_spending:
            if day_data['daily_total'] <= Decimal(str(daily_budget * 1.1)):
                days_in_budget += 1
        
        days_with_spending = daily_spending.count()
        days_elapsed = (now - start_of_month).days + 1
        days_in_budget += (days_elapsed - days_with_spending)
        
        progress = min(days_in_budget, target)
        return progress, progress >= target
    
    elif badge_type == "goal_crusher":
        # Met monthly savings goal (based on savings category)
        budget = Budget.objects.filter(user=user, category="savings").first()
        if not budget or budget.amount == 0:
            return 0, False
        
        start_of_month = now.replace(day=1)
        
        # Calculate total spending this month
        total_spending = Spending.objects.filter(
            user=user, date__gte=start_of_month
        ).aggregate(total=Sum('amount'))['total'] or 0
        
        # Get total budget
        total_budget = Budget.objects.filter(user=user).aggregate(total=Sum('amount'))['total'] or 0
        
        # Savings = budget - spending
        actual_savings = float(total_budget) - float(total_spending)
        savings_goal = float(budget.amount)
        
        progress = int((actual_savings / savings_goal) * target) if savings_goal > 0 else 0
        progress = max(0, min(progress, target))
        
        return progress, actual_savings >= savings_goal
    
    elif badge_type == "spending_slayer":
        # Reduced spending by 20% compared to last month
        start_of_month = now.replace(day=1)
        last_month_start = (start_of_month - timedelta(days=1)).replace(day=1)
        last_month_end = start_of_month - timedelta(days=1)
        
        this_month_spending = Spending.objects.filter(
            user=user, date__gte=start_of_month
        ).aggregate(total=Sum('amount'))['total'] or 0
        
        last_month_spending = Spending.objects.filter(
            user=user, date__gte=last_month_start, date__lte=last_month_end
        ).aggregate(total=Sum('amount'))['total'] or 1  # Avoid division by zero
        
        if float(last_month_spending) == 0:
            return 0, False
        
        reduction_pct = (1 - float(this_month_spending) / float(last_month_spending)) * 100
        progress = int(reduction_pct / 20 * target)  # Scale to target
        progress = max(0, min(progress, target))
        
        return progress, reduction_pct >= 20
    
    elif badge_type == "elite_saver":
        # Beat peer average 6 months in a row
        peer_averages = AnalyticsService.get_peer_averages(exclude_user_id=user.id)
        total_peer_avg = sum(peer_averages.values())
        
        consecutive_months = 0
        
        for i in range(6):
            month_start = (now.replace(day=1) - timedelta(days=30*i)).replace(day=1)
            if i == 0:
                month_end = now
            else:
                month_end = (month_start + timedelta(days=32)).replace(day=1) - timedelta(days=1)
            
            user_spending = Spending.objects.filter(
                user=user, date__gte=month_start, date__lte=month_end
            ).aggregate(total=Sum('amount'))['total'] or 0
            
            if float(user_spending) < total_peer_avg:
                consecutive_months += 1
            else:
                break  # Must be consecutive
        
        return consecutive_months, consecutive_months >= target
    
    elif badge_type == "social_saver":
        # Stayed within entertainment budget for a month
        budget = Budget.objects.filter(user=user, category="entertainment").first()
        if not budget or budget.amount == 0:
            return 0, False
        
        start_of_month = now.replace(day=1)
        
        total_entertainment = Spending.objects.filter(
            user=user, category="entertainment", date__gte=start_of_month
        ).aggregate(total=Sum('amount'))['total'] or 0
        
        days_elapsed = (now - start_of_month).days + 1
        
        if float(total_entertainment) <= float(budget.amount):
            progress = days_elapsed
        else:
            # Calculate what percentage of budget used
            pct_used = float(total_entertainment) / float(budget.amount)
            progress = int(days_elapsed / pct_used)
        
        progress = min(progress, target)
        return progress, progress >= target and float(total_entertainment) <= float(budget.amount)
    
    elif badge_type == "year_legend":
        # Stayed within total budget for 365 days
        start_date = now - timedelta(days=365)
        
        days_in_budget = 0
        total_budget = Budget.objects.filter(user=user).aggregate(total=Sum('amount'))['total'] or 0
        
        if total_budget == 0:
            return 0, False
        
        daily_budget = float(total_budget) / 30  # Monthly budget / 30 for daily
        
        # Group spending by date
        daily_totals = (
            Spending.objects.filter(user=user, date__gte=start_date)
            .values('date')
            .annotate(daily_total=Sum('amount'))
        )
        
        for day_data in daily_totals:
            if day_data['daily_total'] <= Decimal(str(daily_budget * 1.2)):  # 20% tolerance
                days_in_budget += 1
        
        # Days with no spending count as in budget
        days_with_spending = daily_totals.count()
        days_elapsed = min(365, (now - start_date).days + 1)
        days_in_budget += (days_elapsed - days_with_spending)
        
        progress = min(days_in_budget, target)
        return progress, progress >= target
    
    return 0, False


@api_view(["GET"])
@permission_classes([IsAuthenticated])
def badges_list(request):
    """
    Get all badges with user's progress for each.
    """
    badges = Badge.objects.all()
    
    result = []
    earned_count = 0
    
    for badge in badges:
        # Get or create user badge record
        user_badge, created = UserBadge.objects.get_or_create(
            user=request.user,
            badge=badge,
            defaults={'progress': 0, 'earned': False}
        )
        
        # Calculate current progress
        progress, is_earned = calculate_badge_progress(request.user, badge)
        
        # Update if progress changed or newly earned
        if user_badge.progress != progress or (is_earned and not user_badge.earned):
            user_badge.progress = progress
            if is_earned and not user_badge.earned:
                user_badge.earned = True
                user_badge.earned_at = timezone.now()
            user_badge.save()
        
        if user_badge.earned:
            earned_count += 1
        
        # Calculate progress percentage
        progress_pct = (progress / badge.target_value * 100) if badge.target_value > 0 else 0
        
        # Format requirement string
        if badge.badge_type in ["goal_crusher"]:
            requirement = f"${progress}/${badge.target_value}"
        elif badge.badge_type in ["savings_champion", "elite_saver"]:
            requirement = f"{progress}/{badge.target_value} months"
        else:
            requirement = f"{progress}/{badge.target_value} days"
        
        result.append({
            "id": badge.id,
            "badge_type": badge.badge_type,
            "title": badge.title,
            "description": badge.description,
            "icon": badge.icon,
            "gradient_start": badge.gradient_start,
            "gradient_end": badge.gradient_end,
            "progress": progress_pct,
            "earned": user_badge.earned,
            "requirement": requirement,
            "earned_at": user_badge.earned_at.isoformat() if user_badge.earned_at else None,
        })
    
    return Response({
        "badges": result,
        "earned_count": earned_count,
        "total_count": len(badges),
    })
@api_view(["GET", "POST"])
@permission_classes([IsAuthenticated])
def chat_threads(request):
    if request.method == "POST":
        t = ChatThread.objects.create(user=request.user, title=request.data.get("title",""))
        return Response({"id": t.id, "title": t.title}, status=201)

    qs = ChatThread.objects.filter(user=request.user).order_by("-created_at")[:50]
    return Response([{"id": t.id, "title": t.title, "created_at": t.created_at} for t in qs])

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def chat_thread(request, thread_id: int):
    t = ChatThread.objects.filter(user=request.user, id=thread_id).first()
    if not t:
        return Response({"error":"Not found"}, status=404)

    msgs = t.messages.all()[:200]
    return Response({
        "id": t.id,
        "title": t.title,
        "messages": [{"role": m.role, "content": m.content, "created_at": m.created_at} for m in msgs]
    })

@api_view(["POST"])
@permission_classes([IsAuthenticated])
def chat_message(request, thread_id: int):
    t = ChatThread.objects.filter(user=request.user, id=thread_id).first()
    if not t:
        return Response({"error": "Not found"}, status=status.HTTP_404_NOT_FOUND)

    text = (request.data.get("message") or "").strip()
    if not text:
        return Response({"error": "Message required"}, status=status.HTTP_400_BAD_REQUEST)

    ensure_user_rows(request.user)

    # Store user message
    ChatMessage.objects.create(thread=t, role="user", content=text)

    # Build history for LLM (last 10 messages)
    history_qs = t.messages.all().order_by("-created_at")[:10]
    conversation_history = [{"role": m.role, "content": m.content} for m in reversed(history_qs)]

    user_data = AnalyticsService.get_user_financial_data(request.user)
    peer_averages = AnalyticsService.get_peer_averages(exclude_user_id=request.user.id)

    # -------- NEW: Real places context (restaurants/shops) --------
    extra_context = ""
    if _is_place_request(text):
        city = (user_data.get("profile") or {}).get("city") or request.user.city or ""
        country = (user_data.get("profile") or {}).get("country") or request.user.country or ""
        location = ", ".join([x for x in [city, country] if x]).strip() or "your area"

        # Decide query type
        t_lower = text.lower()
        if any(k in t_lower for k in ["supermarket", "grocer", "groceries", "store", "shopping", "shop"]):
            query = f"cheap grocery stores in {location}"
            kind = "grocery"
        else:
            query = f"cheap restaurants in {location}"
            kind = "restaurant"

        places = []
        try:
            places = PlacesService.search_places(query=query, max_results=6)
        except Exception as e:
            # Don't crash chat; just skip places if API fails
            print(f"Places API error: {e}")
            places = []

        if places:
            lines = []
            for p in places:
                price_hint = _price_level_to_hint(p.get("price_level"))
                rating = p.get("rating", "?")
                addr = p.get("address", "")
                url = p.get("maps_url", "")
                # Markdown line that Flutter will render nicely
                lines.append(f"- **{p['name']}** ({price_hint}, ⭐ {rating}) — {addr} — [Maps]({url})")

            extra_context = (
                f"\n\nREAL LOCAL PLACES (use ONLY these for recommendations):\n"
                + "\n".join(lines)
                + "\n\nRules for places:\n"
                  "- Recommend 3–5 options max.\n"
                  "- Use Markdown bullet list.\n"
                  "- Include the Maps link exactly as provided.\n"
                  "- Do NOT invent places not in the list.\n"
            )
        else:
            extra_context = (
                "\n\nNote: No real place data is available right now. "
                "If the user asks for specific places, ask for city or enable Places API.\n"
            )

    # -------- Call LLM (force Markdown formatting via prompt in LLMService) --------
    answer = LLMService.chat_financial_advice(
        user_data=user_data,
        peer_averages=peer_averages,
        conversation_history=conversation_history[:-1],  # excludes current user msg
        user_message=text,
        extra_context=extra_context,
    )

    # Store assistant message
    ChatMessage.objects.create(thread=t, role="assistant", content=answer)

    return Response({"reply": answer}, status=status.HTTP_200_OK)

@api_view(["GET"])
@permission_classes([IsAuthenticated])
def recommend_places(request):
    ensure_user_rows(request.user)
    category = request.GET.get("category", "restaurants")  # restaurants | groceries | etc

    user_data = AnalyticsService.get_user_financial_data(request.user)

    # TODO: call Google Places / Foursquare here using user city (or lat/lng if you have it)
    places = []  # list of dicts from the API

    # Then ask GPT to pick top 5 from `places` and explain why (no hallucination)
    # For now, you can keep your GPT-only fallback if places == []
    recs = LLMService.recommend_local_places(user_data, category)

    return Response({"category": category, "recommendations": recs})

# ─────────────────────────────────────────────────────────────────────────────
# AI RECEIPT ANALYSIS
# ─────────────────────────────────────────────────────────────────────────────

@api_view(['POST'])
@permission_classes([IsAuthenticated])
def analyze_receipt(request):
    # 1. Get the image from the request
    image_data = request.data.get('image') # Expecting base64 string
    if not image_data:
        return Response({"error": "No image provided"}, status=status.HTTP_400_BAD_REQUEST)

    # 2. Setup OpenAI Client
    # Ensure OPENAI_API_KEY is set in your Render Dashboard Environment Variables
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        return Response({"error": "Server configuration error: Missing API Key"}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
    client = OpenAI(api_key=api_key) 

    prompt_text = (
        "Analyze this receipt. Return ONLY a JSON object. "
        "Categorize this expense into EXACTLY one of these labels: "
        "rent, utilities, entertainment, groceries, transportation, healthcare, savings, other. "
        "Format: {'merchant': 'string', 'amount': number, 'category': 'string', 'date': 'YYYY-MM-DD'} "
        "If the date is missing on the receipt, use today's date."
    )

    try:
        # 3. Call OpenAI from the Server
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            response_format={"type": "json_object"},
            messages=[
                {
                    "role": "user",
                    "content": [
                        {"type": "text", "text": prompt_text},
                        {
                            "type": "image_url",
                            "image_url": {"url": f"data:image/jpeg;base64,{image_data}"}
                        }
                    ]
                }
            ],
            max_tokens=500,
        )

        # 4. Clean and parse the response
        content = response.choices[0].message.content
        return Response(json.loads(content))

    except Exception as e:
        print(f"OpenAI Error: {e}")
        return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
    
@api_view(['POST'])
@permission_classes([IsAuthenticated])
def generate_backfill(request):
    # 📝 1. Initialize Log Collection (The "Echo" Logic)
    debug_logs = []
    
    def log(msg):
        print(msg)  # Print to Render/Terminal logs
        debug_logs.append(str(msg))  # Add to list to send back to phone

    log("🚀 STARTING BACKFILL (ECHO DEBUG MODE)...")
    
    # 2. Setup
    account_type = request.data.get('account_type', 'Checking')
    api_key = os.environ.get("OPENAI_API_KEY")
    
    if not api_key:
        log("❌ Critical Error: Missing OPENAI_API_KEY")
        return Response({
            "error": "Server missing API Key", 
            "debug_logs": debug_logs
        }, status=500)
        
    client = OpenAI(api_key=api_key)
    today = timezone.now().date().isoformat()
    
    # 3. Construct the Prompt (Persona Logic)
    if account_type == 'Savings':
        log("🤖 Mode: Savings Account")
        prompt = f"""
        Generate 5 realistic transactions for a Savings Account.
        Return ONLY a JSON object with a key "transactions" containing a list.
        Inner Keys: "amount" (float), "category" (must be "savings"), "date" (YYYY-MM-DD), "merchant".
        
        Transactions should be things like: "Interest Payment", "Monthly Deposit", "Transfer from Checking", "Goal Contribution".
        Category must be exactly: "savings".
        Amounts should be between 20.00 and 2000.00.
        Dates: Randomly spaced over last 60 days from {today}.
        """
    else:
        # Checking Account - Use Personas
        personas = [
            "a foodie who eats at restaurants constantly",
            "a fitness enthusiast who buys supplements and gym gear",
            "a tech lover who buys gadgets and subscriptions",
            "a parent buying lots of groceries and kids' stuff",
            "a traveler with hotel and airline expenses",
            "a student with small, frugal transactions",
        ]
        random_persona = random.choice(personas)
        log(f"🤖 Mode: Checking Account | Persona: {random_persona}")

        prompt = f"""
        Generate 15 realistic bank transactions for a user who is **{random_persona}**.
        Return ONLY a JSON object with a key "transactions" containing a list.
        Keys: "merchant", "amount" (float), "category", "date" (YYYY-MM-DD).
        
        CRITICAL RULES:
        1. Mix these categories: rent, utilities, savings, healthcare, groceries, transportation, entertainment, other.
        2. Do NOT generate more than 1 'rent' transaction.
        3. 'groceries' or 'entertainment' should appear at least 5 times.
        4. Dates must be varied over the last 30 days relative to {today}.
        
        Example format: {{"transactions": [{{"merchant": "Whole Foods", "amount": 45.20, "category": "groceries", "date": "{today}"}}]}}
        """

    try:
        # 4. Call OpenAI
        log("⏳ Asking OpenAI...")
        response = client.chat.completions.create(
            model="gpt-4o-mini",
            response_format={"type": "json_object"},
            messages=[{"role": "user", "content": prompt}],
        )
        
        content = response.choices[0].message.content
        # Log first 100 chars to verify we got JSON
        log(f"📩 RAW AI RESPONSE (Snippet): {content[:100]}...") 

        # 5. Parse JSON
        data = json.loads(content)
        transactions = data.get('transactions', [])
        log(f"📊 Parsed {len(transactions)} transactions from AI.")

        # 6. Save to Database Loop
        saved_count = 0
        valid_cats = ["rent", "utilities", "entertainment", "groceries", 
                      "transportation", "healthcare", "savings", "other"]

        for i, t in enumerate(transactions):
            try:
                # Extract Raw Data
                cat_raw = t.get('category', 'unknown')
                amt_raw = t.get('amount', 0)
                date_raw = t.get('date', today)
                merchant_raw = t.get('merchant', 'Unknown') # Not saved to DB, but good for logs
                
                log(f"   [{i}] Processing: {merchant_raw} | {cat_raw} | {amt_raw}")

                # Normalize Category
                cat = cat_raw.lower().strip()
                if cat not in valid_cats:
                    log(f"      ⚠️ Invalid category '{cat}'. Mapping to 'other'.")
                    cat = "other"

                # Parse Amount
                amount = Decimal(str(amt_raw))

                # Parse Date
                try:
                    date_obj = datetime.strptime(date_raw, "%Y-%m-%d").date()
                except ValueError:
                    log(f"      ⚠️ Date format error for '{date_raw}'. Using today.")
                    date_obj = timezone.now().date()

                # DB Operation: Update existing day or create new
                obj, created = Spending.objects.get_or_create(
                    user=request.user,
                    category=cat,
                    date=date_obj,
                    defaults={'amount': 0}
                )
                
                old_amount = obj.amount
                obj.amount += amount
                obj.save()
                
                log(f"      ✅ Saved! New Total: {obj.amount}")
                saved_count += 1

            except Exception as inner_e:
                log(f"      ❌ FAILED item {i}: {inner_e}")

        # 7. Final Response
        log(f"🏁 FINISHED. Successfully saved {saved_count}/{len(transactions)}")
        
        return Response({
            "count": saved_count, 
            "message": "Debug complete",
            "debug_logs": debug_logs 
        })

    except Exception as e:
        log(f"🔥 CRITICAL ERROR: {e}")
        return Response({
            "error": str(e), 
            "debug_logs": debug_logs
        }, status=500)