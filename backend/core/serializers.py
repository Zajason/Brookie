from django.contrib.auth import get_user_model
from rest_framework import serializers
from .models import Budget, Spending, Category
from .services import ensure_user_rows

User = get_user_model()

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)

    class Meta:
        model = User
        fields = ("username", "email", "password", "full_name", "age")

    def create(self, validated_data):
        password = validated_data.pop("password")
        user = User(**validated_data)
        user.set_password(password)
        user.save()
        ensure_user_rows(user)
        return user


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = ("id", "username", "email", "full_name", "age")


class BudgetSerializer(serializers.ModelSerializer):
    category_label = serializers.SerializerMethodField()

    class Meta:
        model = Budget
        fields = ("category", "category_label", "amount")

    def get_category_label(self, obj):
        return obj.get_category_display()


class SpendingSerializer(serializers.ModelSerializer):
    category_label = serializers.SerializerMethodField()

    class Meta:
        model = Spending
        fields = ("category", "category_label", "amount")

    def get_category_label(self, obj):
        return obj.get_category_display()


class BudgetUpdateSerializer(serializers.Serializer):
    category = serializers.ChoiceField(choices=Category.choices)
    amount = serializers.DecimalField(max_digits=12, decimal_places=2)


class SpendingUpdateSerializer(serializers.Serializer):
    category = serializers.ChoiceField(choices=Category.choices)
    amount = serializers.DecimalField(max_digits=12, decimal_places=2)
