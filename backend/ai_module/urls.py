from django.urls import path


from .views import (
    EntryView, ExitView, AiLogListView,
    AdminAiLogListView,
    ApproveEntryView, RejectEntryView,
    ApproveExitView, RejectExitView,
    PendingLogView, PendingExitView,
    CheckPlateView, CheckEntryPlateView,
    ManualEntryView, ManualExitView,
)

urlpatterns = [
    path('entry/',              EntryView.as_view(),            name='entry'),
    path('exit/',                ExitView.as_view(),             name='exit'),
    path('manual-entry/',        ManualEntryView.as_view(),      name='manual-entry'),
    path('manual-exit/',         ManualExitView.as_view(),       name='manual-exit'),
    path('approve/',             ApproveEntryView.as_view(),     name='approve'),
    path('reject/',              RejectEntryView.as_view(),      name='reject'),
    path('approve-exit/',        ApproveExitView.as_view(),      name='approve-exit'),
    path('reject-exit/',         RejectExitView.as_view(),       name='reject-exit'),
    path('check-plate/',         CheckPlateView.as_view(),       name='check-plate'),
    path('check-entry-plate/',   CheckEntryPlateView.as_view(),  name='check-entry-plate'),
    path('logs/',                AiLogListView.as_view(),        name='ai-logs'),
    path('pending/',             PendingLogView.as_view(),       name='pending'),
    path('pending-exit/',        PendingExitView.as_view(),      name='pending-exit'),
    path('admin/logs/',          AdminAiLogListView.as_view(),   name='admin-ai-logs'),
]