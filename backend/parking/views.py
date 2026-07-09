from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated
from .models import ParkingSite, ParkingSlot, Vehicle
from .serializers import ParkingSiteSerializer, ParkingSlotSerializer, VehicleSerializer


class ParkingSiteView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        if request.user.role == "parking_owner":
            sites = ParkingSite.objects.filter(owner=request.user)
        else:
            sites = ParkingSite.objects.all()
        serializer = ParkingSiteSerializer(sites, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        #  Role check
        if request.user.role not in ["parking_owner", "admin"]:
            return Response(
                {"error": "Only parking owners and admins can create sites"},
                status=status.HTTP_403_FORBIDDEN
            )
        serializer = ParkingSiteSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(owner=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class ParkingSiteDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, user):
        try:
            if user.role == "admin":
                return ParkingSite.objects.get(pk=pk)
            return ParkingSite.objects.get(pk=pk, owner=user)
        except ParkingSite.DoesNotExist:
            return None

    def get(self, request, pk):
        site = self.get_object(pk, request.user)
        if site is None:
            return Response({"error": "Site not found"}, status=status.HTTP_404_NOT_FOUND)
        serializer = ParkingSiteSerializer(site)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def put(self, request, pk):
        site = self.get_object(pk, request.user)
        if site is None:
            return Response({"error": "Site not found"}, status=status.HTTP_404_NOT_FOUND)
        serializer = ParkingSiteSerializer(site, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        site = self.get_object(pk, request.user)
        if site is None:
            return Response({"error": "Site not found"}, status=status.HTTP_404_NOT_FOUND)
        site.delete()
        return Response({"message": "Site deleted successfully"}, status=status.HTTP_200_OK)


class ParkingSlotView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request, site_id):
        slots = ParkingSlot.objects.filter(parking_site=site_id)
        serializer = ParkingSlotSerializer(slots, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request, site_id):
    # Only owner ya admin create slots
        if request.user.role not in ["parking_owner", "admin"]:
            return Response(
                {"error": "Only parking owners or admins can create slots"},
                status=status.HTTP_403_FORBIDDEN
            )
        try:
            site = ParkingSite.objects.get(pk=site_id)
        except ParkingSite.DoesNotExist:
            return Response(
                {"error": "Site not found"},
                status=status.HTTP_403_FORBIDDEN
            )
        if request.user.role == "parking_owner" and site.owner != request.user:
            return Response({"error": "Not your site"}, status=status.HTTP_403_FORBIDDEN)

        existing_count = ParkingSlot.objects.filter(parking_site=site).count()
        if existing_count + 1 > (site.capacity or 9999):
            return Response({
                "error": f"Exceeds capacity. Site capacity is full ({site.capacity} slots)."
            }, status=status.HTTP_400_BAD_REQUEST)

        serializer = ParkingSlotSerializer(data=request.data)
        if serializer.is_valid():
            # Prevent 500 error on duplicate slots
            slot_num = serializer.validated_data.get('slot_number')
            if ParkingSlot.objects.filter(parking_site=site, slot_number=slot_num).exists():
                return Response({"error": f"Slot {slot_num} already exists in this site."}, status=status.HTTP_400_BAD_REQUEST)
                
            try:
                serializer.save(parking_site=site)
                return Response(serializer.data, status=status.HTTP_201_CREATED)
            except Exception as e:
                import traceback
                traceback.print_exc()
                return Response({"error": str(e)}, status=status.HTTP_500_INTERNAL_SERVER_ERROR)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class ParkingSlotDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk):
        try:
            return ParkingSlot.objects.get(pk=pk)
        except ParkingSlot.DoesNotExist:
            return None

    def _can_modify(self, user, slot):
        # Flagged in the merge audit: neither source backend checked
        # ownership here, so any authenticated user of any role could edit
        # or delete any slot by UUID. Same rule as the bulk slot endpoints.
        return user.role == "admin" or (
            user.role == "parking_owner" and slot.parking_site.owner == user
        )

    def get(self, request, pk):
        slot = self.get_object(pk)
        if slot is None:
            return Response({"error": "Slot not found"}, status=status.HTTP_404_NOT_FOUND)
        serializer = ParkingSlotSerializer(slot)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def put(self, request, pk):
        slot = self.get_object(pk)
        if slot is None:
            return Response({"error": "Slot not found"}, status=status.HTTP_404_NOT_FOUND)
        if not self._can_modify(request.user, slot):
            return Response({"error": "Not your site"}, status=status.HTTP_403_FORBIDDEN)
        serializer = ParkingSlotSerializer(slot, data=request.data, partial=True)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        slot = self.get_object(pk)
        if slot is None:
            return Response({"error": "Slot not found"}, status=status.HTTP_404_NOT_FOUND)
        if not self._can_modify(request.user, slot):
            return Response({"error": "Not your site"}, status=status.HTTP_403_FORBIDDEN)
        slot.delete()
        return Response({"message": "Slot deleted successfully"}, status=status.HTTP_200_OK)


class BulkGenerateSlotsView(APIView):
    """
    POST /api/parking/sites/<site_id>/slots/bulk-generate/
    Body: { "normal": 50, "vip": 10, "disabled": 5,
            "normal_rate": 100, "vip_rate": 250, "disabled_rate": 80 }
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, site_id):
        if request.user.role not in ["parking_owner", "admin"]:
            return Response({"error": "Permission denied"}, status=status.HTTP_403_FORBIDDEN)

        try:
            site = ParkingSite.objects.get(pk=site_id)
        except ParkingSite.DoesNotExist:
            return Response({"error": "Site not found"}, status=status.HTTP_404_NOT_FOUND)

        # Only owner of this site or admin
        if request.user.role == "parking_owner" and site.owner != request.user:
            return Response({"error": "Not your site"}, status=status.HTTP_403_FORBIDDEN)

        normal_count = int(request.data.get("normal", 0))
        vip_count = int(request.data.get("vip", 0))
        disabled_count = int(request.data.get("disabled", 0))
        normal_rate = float(request.data.get("normal_rate", 100))
        vip_rate = float(request.data.get("vip_rate", 250))
        disabled_rate = float(request.data.get("disabled_rate", 80))

        total_requested = normal_count + vip_count + disabled_count
        existing_count = ParkingSlot.objects.filter(parking_site=site).count()

        if total_requested + existing_count > (site.capacity or 9999):
            return Response({
                "error": f"Exceeds capacity. Site capacity: {site.capacity}, "
                         f"existing slots: {existing_count}, requested: {total_requested}"
            }, status=status.HTTP_400_BAD_REQUEST)

        # Find the highest existing slot numbers for each type
        existing_slots = ParkingSlot.objects.filter(parking_site=site)
        
        def get_next_number(prefix):
            """Find highest existing number for a prefix like N-, V-, D-"""
            max_num = 0
            for s in existing_slots:
                sn = s.slot_number
                if sn.startswith(prefix):
                    try:
                        num = int(sn[len(prefix):])
                        if num > max_num:
                            max_num = num
                    except ValueError:
                        pass
            return max_num + 1

        slots_to_create = []
        
        # Normal slots: N-001, N-002, ...
        start = get_next_number("N-")
        for i in range(normal_count):
            slots_to_create.append(ParkingSlot(
                parking_site=site,
                slot_number=f"N-{start + i:03d}",
                slot_type="normal",
                is_occupied=False,
                is_reserved=False,
                price_per_hour=normal_rate
            ))

        # VIP slots: V-001, V-002, ...
        start = get_next_number("V-")
        for i in range(vip_count):
            slots_to_create.append(ParkingSlot(
                parking_site=site,
                slot_number=f"V-{start + i:03d}",
                slot_type="vip",
                is_occupied=False,
                is_reserved=False,
                price_per_hour=vip_rate
            ))

        # Disabled slots: D-001, D-002, ...
        start = get_next_number("D-")
        for i in range(disabled_count):
            slots_to_create.append(ParkingSlot(
                parking_site=site,
                slot_number=f"D-{start + i:03d}",
                slot_type="disabled",
                is_occupied=False,
                is_reserved=False,
                price_per_hour=disabled_rate
            ))

        created = ParkingSlot.objects.bulk_create(slots_to_create)
        
        return Response({
            "message": f"Successfully generated {len(created)} slots",
            "created": len(created),
            "normal": normal_count,
            "vip": vip_count,
            "disabled": disabled_count,
            "total_slots": existing_count + len(created),
            "capacity": site.capacity
        }, status=status.HTTP_201_CREATED)


class BulkDeleteSlotsView(APIView):
    """
    POST /api/parking/sites/<site_id>/slots/bulk-delete/
    Deletes all unoccupied slots (or specific type if provided).
    Body (optional): { "type": "normal" }  — delete only normal unoccupied slots
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, site_id):
        if request.user.role not in ["parking_owner", "admin"]:
            return Response({"error": "Permission denied"}, status=status.HTTP_403_FORBIDDEN)

        try:
            site = ParkingSite.objects.get(pk=site_id)
        except ParkingSite.DoesNotExist:
            return Response({"error": "Site not found"}, status=status.HTTP_404_NOT_FOUND)

        if request.user.role == "parking_owner" and site.owner != request.user:
            return Response({"error": "Not your site"}, status=status.HTTP_403_FORBIDDEN)

        slot_type = request.data.get("type", None)
        qs = ParkingSlot.objects.filter(parking_site=site, is_occupied=False)
        
        if slot_type:
            qs = qs.filter(slot_type=slot_type)

        count = qs.count()
        qs.delete()

        remaining = ParkingSlot.objects.filter(parking_site=site).count()
        return Response({
            "message": f"Deleted {count} unoccupied slots",
            "deleted": count,
            "remaining": remaining
        }, status=status.HTTP_200_OK)


class BulkUpdateRateView(APIView):
    """
    POST /api/parking/sites/<site_id>/slots/bulk-update-rate/
    Body: { "type": "vip", "rate": 300 }
    Updates price_per_hour for all slots of the given type.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request, site_id):
        if request.user.role not in ["parking_owner", "admin"]:
            return Response({"error": "Permission denied"}, status=status.HTTP_403_FORBIDDEN)

        try:
            site = ParkingSite.objects.get(pk=site_id)
        except ParkingSite.DoesNotExist:
            return Response({"error": "Site not found"}, status=status.HTTP_404_NOT_FOUND)

        if request.user.role == "parking_owner" and site.owner != request.user:
            return Response({"error": "Not your site"}, status=status.HTTP_403_FORBIDDEN)

        slot_type = request.data.get("type")
        rate = request.data.get("rate")
        
        if not slot_type or rate is None:
            return Response({"error": "type and rate are required"}, status=status.HTTP_400_BAD_REQUEST)

        updated = ParkingSlot.objects.filter(
            parking_site=site, slot_type=slot_type
        ).update(price_per_hour=float(rate))

        return Response({
            "message": f"Updated rate for {updated} {slot_type} slots to {rate}",
            "updated": updated
        }, status=status.HTTP_200_OK)


class VehicleView(APIView):
    permission_classes = [IsAuthenticated]

    def get(self, request):
        vehicles = Vehicle.objects.filter(user=request.user)
        serializer = VehicleSerializer(vehicles, many=True)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def post(self, request):
        serializer = VehicleSerializer(data=request.data)
        if serializer.is_valid():
            serializer.save(user=request.user)
            return Response(serializer.data, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)


class VehicleDetailView(APIView):
    permission_classes = [IsAuthenticated]

    def get_object(self, pk, user):
        try:
            return Vehicle.objects.get(pk=pk, user=user)
        except Vehicle.DoesNotExist:
            return None

    def get(self, request, pk):
        vehicle = self.get_object(pk, request.user)
        if vehicle is None:
            return Response({"error": "Vehicle not found"}, status=status.HTTP_404_NOT_FOUND)
        serializer = VehicleSerializer(vehicle)
        return Response(serializer.data, status=status.HTTP_200_OK)

    def put(self, request, pk):
        vehicle = self.get_object(pk, request.user)
        if vehicle is None:
            return Response({"error": "Vehicle not found"}, status=status.HTTP_404_NOT_FOUND)
        serializer = VehicleSerializer(vehicle, data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response(serializer.data, status=status.HTTP_200_OK)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

    def delete(self, request, pk):
        vehicle = self.get_object(pk, request.user)
        if vehicle is None:
            return Response({"error": "Vehicle not found"}, status=status.HTTP_404_NOT_FOUND)
        vehicle.delete()
        return Response({"message": "Vehicle deleted successfully"}, status=status.HTTP_200_OK)

# ─── Admin: System Settings ───────────────────────────────────────────────────
from accounts.permissions import IsAdmin
from .models import SystemSettings

class AdminSystemSettingsView(APIView):
    """
    GET  /api/parking/admin/settings/  → return current settings
    PUT  /api/parking/admin/settings/  → update settings (partial update supported)
    """
    permission_classes = [IsAuthenticated, IsAdmin]

    def get(self, request):
        s = SystemSettings.get()
        return Response(self._serialize(s), status=status.HTTP_200_OK)

    def put(self, request):
        s = SystemSettings.get()
        data = request.data

        # ── Parking / Overstay ─────────────────────────────────────────
        if "grace_period_minutes" in data:
            s.grace_period_minutes     = int(data["grace_period_minutes"])
        if "overstay_rate_per_hour" in data:
            s.overstay_rate_per_hour   = float(data["overstay_rate_per_hour"])
        if "reservation_lock_minutes" in data:
            s.reservation_lock_minutes = int(data["reservation_lock_minutes"])
        if "max_booking_days" in data:
            s.max_booking_days         = int(data["max_booking_days"])

        # ── Payment Methods ────────────────────────────────────────────
        if "cash_enabled" in data:
            s.cash_enabled             = bool(data["cash_enabled"])
        if "easypaisa_enabled" in data:
            s.easypaisa_enabled        = bool(data["easypaisa_enabled"])
        if "card_enabled" in data:
            s.card_enabled             = bool(data["card_enabled"])

        # ── Refund Policy ─────────────────────────────────────────────
        if "refund_100_before_start" in data:
            s.refund_100_before_start  = bool(data["refund_100_before_start"])
        if "refund_percent" in data:
            s.refund_percent           = int(data["refund_percent"])
        if "refund_window_minutes" in data:
            s.refund_window_minutes    = int(data["refund_window_minutes"])

        # ── Notifications ──────────────────────────────────────────────
        if "notify_new_owner" in data:
            s.notify_new_owner         = bool(data["notify_new_owner"])
        if "notify_overstay" in data:
            s.notify_overstay          = bool(data["notify_overstay"])
        if "notify_payment_received" in data:
            s.notify_payment_received  = bool(data["notify_payment_received"])
        if "notify_manual_override" in data:
            s.notify_manual_override   = bool(data["notify_manual_override"])

        # ── Security ──────────────────────────────────────────────────
        if "require_phone_otp" in data:
            s.require_phone_otp        = bool(data["require_phone_otp"])
        if "session_timeout_minutes" in data:
            s.session_timeout_minutes  = int(data["session_timeout_minutes"])
        if "max_login_attempts" in data:
            s.max_login_attempts       = int(data["max_login_attempts"])

        # ── Display ───────────────────────────────────────────────────
        if "show_confidence_score" in data:
            s.show_confidence_score    = bool(data["show_confidence_score"])
        if "show_owner_revenue" in data:
            s.show_owner_revenue       = bool(data["show_owner_revenue"])

        s.save()
        return Response(
            {"message": "Settings saved successfully.", **self._serialize(s)},
            status=status.HTTP_200_OK,
        )

    @staticmethod
    def _serialize(s):
        return {
            "parking": {
                "grace_period_minutes":     s.grace_period_minutes,
                "overstay_rate_per_hour":   str(s.overstay_rate_per_hour),
                "reservation_lock_minutes": s.reservation_lock_minutes,
                "max_booking_days":         s.max_booking_days,
            },
            "payments": {
                "cash_enabled":             s.cash_enabled,
                "easypaisa_enabled":        s.easypaisa_enabled,
                "card_enabled":             s.card_enabled,
                "refund_100_before_start":  s.refund_100_before_start,
                "refund_percent":           s.refund_percent,
                "refund_window_minutes":    s.refund_window_minutes,
            },
            "notifications": {
                "notify_new_owner":         s.notify_new_owner,
                "notify_overstay":          s.notify_overstay,
                "notify_payment_received":  s.notify_payment_received,
                "notify_manual_override":   s.notify_manual_override,
            },
            "security": {
                "require_phone_otp":        s.require_phone_otp,
                "session_timeout_minutes":  s.session_timeout_minutes,
                "max_login_attempts":       s.max_login_attempts,
            },
            "display": {
                "show_confidence_score":    s.show_confidence_score,
                "show_owner_revenue":       s.show_owner_revenue,
            },
            "updated_at": s.updated_at,
        }
