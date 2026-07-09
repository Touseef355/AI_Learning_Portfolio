import json
import asyncio
from channels.generic.websocket import AsyncWebsocketConsumer
from channels.db import database_sync_to_async
from rest_framework_simplejwt.tokens import AccessToken
from rest_framework_simplejwt.exceptions import InvalidToken, TokenError
from django.contrib.auth import get_user_model

User = get_user_model()


@database_sync_to_async
def get_user_from_token(token_key):
    try:
        token   = AccessToken(token_key)
        user_id = token["user_id"]
        user    = User.objects.get(id=user_id)
        return user if user.is_active else None
    except (InvalidToken, TokenError, User.DoesNotExist):
        return None


class EntryConsumer(AsyncWebsocketConsumer):

    async def connect(self):
        self.authenticated      = False
        self.scope["user"]      = None
        self.auth_timeout_task  = None

        await self.accept()
        await self.send(text_data=json.dumps({
            "type"   : "auth_required",
            "message": "Send auth token to continue"
        }))
        self.auth_timeout_task = asyncio.create_task(self._auth_timeout())

    async def _auth_timeout(self):
        await asyncio.sleep(10)
        if not self.authenticated:
            await self.close(code=4008)

    async def disconnect(self, close_code):
        if self.auth_timeout_task:
            self.auth_timeout_task.cancel()
            try:
                await self.auth_timeout_task
            except asyncio.CancelledError:
                pass

        if self.authenticated:
            await self.channel_layer.group_discard(
                "parking_entry",
                self.channel_name
            )
        print(f"Entry Dashboard disconnected — code: {close_code}")

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            await self.close(code=4000)
            return

        msg_type = data.get("type")

        if msg_type == "auth":
            # Block re-authentication
            if self.authenticated:
                await self.send(text_data=json.dumps({
                    "type"   : "error",
                    "message": "Already authenticated"
                }))
                return

            token_key = data.get("token")
            if not token_key:
                await self.send(text_data=json.dumps({
                    "type"   : "auth_failed",
                    "message": "Token missing"
                }))
                await self.close(code=4001)
                return

            user = await get_user_from_token(token_key)
            if user is None:
                await self.send(text_data=json.dumps({
                    "type"   : "auth_failed",
                    "message": "Invalid or expired token"
                }))
                await self.close(code=4003)
                return

            if user.role not in ["cashier", "admin","entry_cashier"]:
                await self.send(text_data=json.dumps({
                    "type"   : "auth_failed",
                    "message": "Access denied"
                }))
                await self.close(code=4004)
                return

            self.authenticated = True
            self.scope["user"] = user

            if self.auth_timeout_task:
                self.auth_timeout_task.cancel()

            await self.channel_layer.group_add(
                "parking_entry",
                self.channel_name
            )
            await self.send(text_data=json.dumps({
                "type"   : "auth_success",
                "message": f"Welcome {user.full_name}",
                "role"   : user.role
            }))
            print(f"Entry WS authenticated — {user.email}")
            return

        if not self.authenticated:
            await self.send(text_data=json.dumps({
                "type"   : "auth_required",
                "message": "Authenticate first"
            }))
            await self.close(code=4001)
            return

    async def entry_detected(self, event):
        if not self.authenticated:
            return
        try:
            await self.send(text_data=json.dumps({
                "type"         : "entry_detected",
                "ai_log_id"    : event["ai_log_id"],
                "plate_number" : event["plate_number"],
                "confidence"   : event["confidence"],
                "image_url"    : event["image_url"],
                "cropped_plate": event["cropped_plate"],
                "has_booking"  : event["has_booking"],
                "booking_info" : event["booking_info"],
                "vehicle_type" : event["vehicle_type"],
                "pre_assigned_slot": event.get("assigned_slot"),
                "entry_time"   : event.get("entry_time"),
            }))
        except Exception:
            return


class ExitConsumer(AsyncWebsocketConsumer):

    async def connect(self):
        self.authenticated      = False
        self.scope["user"]      = None
        self.auth_timeout_task  = None

        await self.accept()
        await self.send(text_data=json.dumps({
            "type"   : "auth_required",
            "message": "Send auth token to continue"
        }))
        self.auth_timeout_task = asyncio.create_task(self._auth_timeout())

    async def _auth_timeout(self):
        await asyncio.sleep(10)
        if not self.authenticated:
            await self.close(code=4008)

    async def disconnect(self, close_code):
        if self.auth_timeout_task:
            self.auth_timeout_task.cancel()
            try:
                await self.auth_timeout_task
            except asyncio.CancelledError:
                pass

        if self.authenticated:
            await self.channel_layer.group_discard(
                "parking_exit",
                self.channel_name
            )
        print(f"Exit Dashboard disconnected — code: {close_code}")

    async def receive(self, text_data):
        try:
            data = json.loads(text_data)
        except json.JSONDecodeError:
            await self.close(code=4000)
            return

        msg_type = data.get("type")

        if msg_type == "auth":
            if self.authenticated:
                await self.send(text_data=json.dumps({
                    "type"   : "error",
                    "message": "Already authenticated"
                }))
                return

            token_key = data.get("token")
            if not token_key:
                await self.send(text_data=json.dumps({
                    "type"   : "auth_failed",
                    "message": "Token missing"
                }))
                await self.close(code=4001)
                return

            user = await get_user_from_token(token_key)
            if user is None:
                await self.send(text_data=json.dumps({
                    "type"   : "auth_failed",
                    "message": "Invalid or expired token"
                }))
                await self.close(code=4003)
                return

            if user.role not in ["cashier", "admin","exit_cashier"]:
                await self.send(text_data=json.dumps({
                    "type"   : "auth_failed",
                    "message": "Access denied"
                }))
                await self.close(code=4004)
                return

            self.authenticated = True
            self.scope["user"] = user

            if self.auth_timeout_task:
                self.auth_timeout_task.cancel()

            await self.channel_layer.group_add(
                "parking_exit",
                self.channel_name
            )
            await self.send(text_data=json.dumps({
                "type"   : "auth_success",
                "message": f"Welcome {user.full_name}",
                "role"   : user.role
            }))
            print(f"Exit WS authenticated — {user.email}")
            return

        if not self.authenticated:
            await self.send(text_data=json.dumps({
                "type"   : "auth_required",
                "message": "Authenticate first"
            }))
            await self.close(code=4001)
            return

    async def exit_detected(self, event):
        if not self.authenticated:
            return
        await self.send(text_data=json.dumps({
            "type"         : "exit_detected",
            "ai_log_id"    : event["ai_log_id"],
            "plate_number" : event["plate_number"],
            "confidence"   : event["confidence"],
            "image_url"    : event["image_url"],
            "cropped_plate": event["cropped_plate"],
            "amount"       : event.get("amount"),
            "entry_time"   : event.get("entry_time", ""),
            "vehicle_name" : event.get("vehicle_name", ""),
            "vehicle_type" : event.get("vehicle_type", "car"),
            "slot"         : event.get("slot", ""),
            "is_extended"  : event.get("is_extended", False),
            "booking_id"   : event.get("booking_id", ""),
            "booking_info" : event.get("booking_info"),
            "entry_found"  : event.get("entry_found", False),
        }))