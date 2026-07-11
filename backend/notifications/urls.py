from django.urls import path
from .views import NotificationListView, MarkAllReadView, UnreadCountView

urlpatterns = [
    path("", NotificationListView.as_view(), name="notifications"),
    path("mark-all-read/", MarkAllReadView.as_view(), name="notifications-mark-all-read"),
    path("unread-count/", UnreadCountView.as_view(), name="notifications-unread-count"),
]
