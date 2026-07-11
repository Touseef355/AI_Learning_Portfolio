import logging

logger = logging.getLogger(__name__)


from sps_backend.events import emit


def notify(user, title, message="", notification_type="general"):
    """
    Create an in-app notification for `user`.

    Deliberately swallows every exception: a notification failure must
    NEVER break the payment/booking transaction that triggered it.
    Returns the Notification or None.

    NOTE: if called inside transaction.atomic() and that transaction later
    rolls back, the notification rolls back with it — which is exactly the
    behaviour we want (no "payment successful" notification for a payment
    that never committed).
    """
    if user is None:
        return None
    try:
        # Local import so a broken app registry at import-time of the
        # caller module can't take the whole view module down.
        from .models import Notification
        n = Notification.objects.create(
            user=user,
            title=title[:120],
            message=(message or "")[:255],
            notification_type=notification_type,
        )
        emit("notification", user_id=user.id,
             data={"notification_type": notification_type, "title": title})
        return n
    except Exception:
        logger.exception("notify() failed — suppressed")
        return None
