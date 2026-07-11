"""
sps_backend/events.py — realtime event bus (Channels/Redis pe).

Production pattern: jab bhi data CHANGE ho, ek chhota event push hota hai
WebSocket clients ko; client sirf wohi data refetch karta hai jo badla.
Polling fallback ban jati hai, primary mechanism nahi.

Groups:
    events_site_{site_id} : us site ke cashiers + owner (slots, bookings,
                            payments ki changes)
    events_user_{user_id} : app user (uski bookings, wallet, notifications)
    events_admin          : admins (sab kuch high-level)

Emit ALWAYS best-effort hai — Redis down ho ya layer na ho, request
kabhi fail nahi hoti; clients apne polling fallback pe chal lete hain.
"""
import logging

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer

logger = logging.getLogger(__name__)


def emit(event, *, site_id=None, user_id=None, admin=False, data=None):
    """
    emit("slots.changed", site_id=slot.parking_site_id)
    emit("wallet.changed", user_id=user.id)
    emit("bookings.changed", site_id=sid, admin=True)
    """
    try:
        layer = get_channel_layer()
        if layer is None:
            return
        message = {
            "type": "broadcast_event",   # -> EventsConsumer.broadcast_event
            "event": event,
            "data": data or {},
        }
        send = async_to_sync(layer.group_send)
        if site_id:
            send(f"events_site_{site_id}", message)
        if user_id:
            send(f"events_user_{user_id}", message)
        if admin:
            send("events_admin", message)
    except Exception:  # noqa: BLE001
        # Realtime is an enhancement, never a point of failure.
        logger.warning("events.emit failed", exc_info=True)
