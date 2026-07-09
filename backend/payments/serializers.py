from rest_framework import serializers
from .models import Payment


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = ['id', 'booking', 'amount', 'payment_method',
            'payment_type', 'payment_channel', 'status', 'paid_at',
            'currency', 'payment_reference', 'refund_amount']

        read_only_fields = ['id', 'status', 'paid_at', 'payment_reference']

    def validate_amount(self, value):
        if value < 0:
            raise serializers.ValidationError("Amount must be greater than 0")
        return value

    def validate(self, data):
        # booking is optional now (topup/refund payments aren't tied to one)
        booking = data.get('booking')
        if booking:
            if booking.payment_status == "paid":
                raise serializers.ValidationError("This booking is already paid")
            if booking.status == "cancelled":
                raise serializers.ValidationError("Cannot create payment for cancelled booking")
        return data
