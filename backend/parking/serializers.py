from rest_framework import serializers
from .models import ParkingSite,ParkingSlot,Vehicle

class ParkingSiteSerializer(serializers.ModelSerializer):
    owner = serializers.StringRelatedField(read_only=True)

    # parkroo_app (Flutter) reads "rate_per_hour" — backend_ali's model field
    # name for what this backend stores as "price_per_hour". Alias instead of
    # a second column so the two names can't drift out of sync.
    rate_per_hour = serializers.DecimalField(
        source='price_per_hour', max_digits=10, decimal_places=2,
        read_only=True,
    )

    # Live counts from actual ParkingSlot rows, not the declared/target
    # capacity fields above — what Flutter needs to know what's bookable now.
    available_slots = serializers.SerializerMethodField()

    class Meta:
        model = ParkingSite
        fields = [
            'id', 'owner', 'name',
            'location', 'address', 'city',
            'phone', 'email', 'contact_number',
            'capacity', 'total_slots', 'total_floors',
            'opening_time', 'closing_time', 'status',
            'price_per_hour', 'rate_per_hour',
            'available_slots',
            'created_at', 'updated_at',
        ]
        read_only_fields = ['id', 'created_at', 'updated_at', 'available_slots']

    def get_available_slots(self, obj):
        return obj.slots.filter(is_occupied=False, is_reserved=False).count()


class ParkingSlotSerializer(serializers.ModelSerializer):
    
    class Meta:
        model=ParkingSlot
        fields = ['id', 'parking_site', 'slot_number', 'slot_type', 
                  'is_occupied', 'is_reserved', 'price_per_hour', 'updated_at']
        read_only_fields = ['id', 'updated_at','parking_site']

class VehicleSerializer(serializers.ModelSerializer):
    user = serializers.StringRelatedField(read_only=True)

    class Meta:
        model = Vehicle
        fields = ['id', 'user', 'name', 'plate_number', 
                  'vehicle_type', 'color', 'created_at']
        read_only_fields = ['id', 'created_at']