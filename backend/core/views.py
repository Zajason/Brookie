from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response

from .models import Budget, Spending
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
