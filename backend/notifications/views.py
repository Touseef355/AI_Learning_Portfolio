from rest_framework import status
from rest_framework.views import APIView
from rest_framework.response import Response
from rest_framework.permissions import IsAuthenticated

from .models import Notification
from .serializers import NotificationSerializer


class NotificationListView(APIView):
    """
    GET /api/notifications/
    Returns the current user's notifications, newest first.
    Capped at 50 — the app screen is a simple list, not paginated.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        qs = Notification.objects.filter(user=request.user)[:50]
        return Response(
            NotificationSerializer(qs, many=True).data,
            status=status.HTTP_200_OK,
        )


class MarkAllReadView(APIView):
    """
    POST /api/notifications/mark-all-read/
    The app fires this automatically when NotificationsScreen opens.
    """
    permission_classes = [IsAuthenticated]

    def post(self, request):
        updated = Notification.objects.filter(
            user=request.user, is_read=False
        ).update(is_read=True)
        return Response({"marked_read": updated}, status=status.HTTP_200_OK)


class UnreadCountView(APIView):
    """
    GET /api/notifications/unread-count/
    Not called by the app yet — for the badge on the dashboard bell icon
    when you wire it up. Cheap indexed count query.
    """
    permission_classes = [IsAuthenticated]

    def get(self, request):
        count = Notification.objects.filter(
            user=request.user, is_read=False
        ).count()
        return Response({"unread": count}, status=status.HTTP_200_OK)
