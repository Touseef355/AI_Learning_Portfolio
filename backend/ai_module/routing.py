from django.urls import re_path
from . import consumers

websocket_urlpatterns = [
    re_path(r"ws/parking/entry/$", consumers.EntryConsumer.as_asgi()),
    re_path(r"ws/parking/exit/$",consumers.ExitConsumer.as_asgi()),
    re_path(r"ws/events/$", consumers.EventsConsumer.as_asgi()),
]
