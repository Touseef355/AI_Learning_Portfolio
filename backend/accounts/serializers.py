from rest_framework import serializers
from django.contrib.auth import get_user_model
from .models import OwnerRegistrationQuery

User = get_user_model()


class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True, min_length=8)
    confirm_password = serializers.CharField(write_only=True)

    class Meta:
        model = User
        fields = ['email', 'full_name', 'phone_number',
                  'password', 'confirm_password']

    def validate(self, data):
        if data['password'] != data['confirm_password']:
            raise serializers.ValidationError("Passwords do not match")
        return data

    def create(self, validated_data):
        # `role` is intentionally not a serializer field — self-registration
        # always creates a plain "user" account. Admin/owner/cashier accounts
        # are created through the admin-onboarding and owner-cashier flows,
        # which set role explicitly server-side.
        validated_data.pop("confirm_password")
        validated_data["role"] = "user"
        user = User.objects.create_user(**validated_data)
        return user


class OwnerRegistrationQuerySerializer(serializers.ModelSerializer):
    class Meta:
        model = OwnerRegistrationQuery
        fields = [
            "id", "full_name", "email", "phone_number",
            "query_type", "proposed_site_name", "site_capacity",
            "message", "admin_response", "status", "created_at",
        ]
        read_only_fields = ["id", "status", "admin_response", "created_at"]