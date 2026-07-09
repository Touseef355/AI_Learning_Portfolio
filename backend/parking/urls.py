from django.urls import path,include
from .views import (
    ParkingSiteView,
    ParkingSiteDetailView,
    ParkingSlotView,
    ParkingSlotDetailView,
    BulkGenerateSlotsView,
    BulkDeleteSlotsView,
    BulkUpdateRateView,
    VehicleView,
    VehicleDetailView,
    AdminSystemSettingsView
)



urlpatterns = [
    # Parking Sites
    path('sites/', ParkingSiteView.as_view(), name='parking-sites'),
    path('sites/<uuid:pk>/', ParkingSiteDetailView.as_view(), name='parking-site-detail'),

    # Parking Slots
    path('sites/<uuid:site_id>/slots/', ParkingSlotView.as_view(), name='parking-slots'),
    path('slots/<uuid:pk>/', ParkingSlotDetailView.as_view(), name='parking-slot-detail'),

    # Bulk Slot Management
    path('sites/<uuid:site_id>/slots/bulk-generate/', BulkGenerateSlotsView.as_view(), name='bulk-generate-slots'),
    path('sites/<uuid:site_id>/slots/bulk-delete/', BulkDeleteSlotsView.as_view(), name='bulk-delete-slots'),
    path('sites/<uuid:site_id>/slots/bulk-update-rate/', BulkUpdateRateView.as_view(), name='bulk-update-rate'),

    # Vehicles
    path('vehicles/', VehicleView.as_view(), name='vehicles'),
    path('vehicles/<uuid:pk>/', VehicleDetailView.as_view(), name='vehicle-detail'),

    # ── Admin ──────────────────────────────────────────────────────────────
    # GET /api/parking/admin/settings/   → fetch current settings
    # PUT /api/parking/admin/settings/   → save settings
    path('admin/settings/', AdminSystemSettingsView.as_view(), name='admin-system-settings'),

]