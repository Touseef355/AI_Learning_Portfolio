from django.urls import path
from .views import (
    BookingView, BookingDetailView, BookingExtendView, OwnerBookingView,
    AdminBookingView, RefundPreviewView, PassPreviewView, PassView, PassDetailView,
    BookingPriceEstimateView,
)

urlpatterns = [
    path('admin/', AdminBookingView.as_view(), name='admin-bookings'),
    path('owner/', OwnerBookingView.as_view(), name='owner-bookings'),
    path('estimate/', BookingPriceEstimateView.as_view(), name='booking-estimate'),
    path('passes/preview/', PassPreviewView.as_view(), name='pass-preview'),
    path('passes/', PassView.as_view(), name='passes'),
    path('passes/<uuid:pk>/', PassDetailView.as_view(), name='pass-detail'),
    path('', BookingView.as_view(), name='bookings'),
    
    path('<uuid:pk>/', BookingDetailView.as_view(), name='booking-detail'),
    path('<uuid:pk>/extend/',BookingExtendView.as_view(),name="Extend-time"),
    path('<uuid:pk>/refund-preview/', RefundPreviewView.as_view(), name='booking-refund-preview')
 
]