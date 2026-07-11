"""
Single source of truth for parking charges.

Before this module existed, THREE different places computed a parking
amount independently and could disagree:
  1. The Flutter app's own `rate * hours` estimate shown before booking.
  2. `ai_module.views.calculate_amount` — flat-N-hours-then-hourly, but
     driven only by global settings.py values, ignoring any per-site
     customisation.
  3. `Booking.estimated_amount`, which used to be whatever the client sent
     (or nothing at all).

Now everything funnels through `calculate_amount()` below, so the number
quoted at booking time, the number charged at the gate on actual exit, and
the number used for refund previews are always the same formula.

Pricing model is chosen per `ParkingSite.pricing_type`:
  - "hourly": straight `rate x hours`, no flat window.
  - "flat" (default): first `flat_hours` hours cost `flat_price` total,
    then `extra_hour_rate` per hour (or partial slab, with a grace period)
    after that.
Both flat_price/extra_hour_rate/flat_hours are owner-configurable per site
(dashboard, Phase 4) and fall back to the global PARKING_* settings when
the owner hasn't customised them — so existing sites keep behaving exactly
as before until an owner explicitly changes their pricing.
"""
import math
from decimal import Decimal, ROUND_HALF_UP

from django.conf import settings

BASE_PRICE     = settings.PARKING_BASE_PRICE
EXTRA_PER_HOUR = settings.PARKING_EXTRA_PER_HOUR
GRACE_PERIOD   = settings.PARKING_GRACE_PERIOD
BASE_HOURS     = settings.PARKING_BASE_HOURS


def _q2(value):
    """Round to 2 decimal places, the way money should be rounded."""
    return float(Decimal(str(value)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP))


def _resolve_flat_settings(site, vehicle_type, is_booking, is_extended, slot=None):
    """
    (flat_hours, flat_price, extra_rate) for a site, falling back to global
    PARKING_* settings for anything the owner hasn't customised.

    FIX (slot-type pricing): agar owner ne SLOT ka apna price set kia hai
    (ParkingSlot.price_per_hour — VIP/Disabled slabs isi se bante hain), to
    flat-window ka price WOHI hai. Pehle ye field charge me kahin use hi
    nahi hota tha: app VIP slot pe "Rs. 100" dikhata tha lekin estimate/
    booking/exit sab site ka flat 50 hi charge karte the — har slot type
    ka total ek jaisa aata tha.

    Resolution order: slot ka price → site ka flat_price → global default.

    The extra_rate fallback preserves the historical hardcoded behaviour
    (10/hr for extended bookings, 20/hr otherwise) when the owner hasn't set
    `extra_hour_rate` — so un-migrated sites see identical numbers to before.
    """
    default_extra = 10 if (is_booking and is_extended) else 20

    slot_price = getattr(slot, "price_per_hour", None) if slot is not None else None

    if site is None:
        price = slot_price if slot_price is not None else BASE_PRICE.get(vehicle_type, 50)
        return BASE_HOURS, Decimal(str(price)), Decimal(str(default_extra))

    flat_hours = site.flat_hours or BASE_HOURS
    if slot_price is not None:
        flat_price = slot_price
    elif site.flat_price is not None:
        flat_price = site.flat_price
    else:
        flat_price = BASE_PRICE.get(vehicle_type, 50)
    extra_rate = (
        site.extra_hour_rate if site.extra_hour_rate is not None
        else default_extra
    )
    return flat_hours, Decimal(str(flat_price)), Decimal(str(extra_rate))


def _resolve_hourly_rate(site, vehicle_type, slot=None):
    # Hourly model me bhi slot ka apna rate pehle (VIP/hr > normal/hr).
    slot_price = getattr(slot, "price_per_hour", None) if slot is not None else None
    if slot_price is not None:
        return Decimal(str(slot_price))
    if site is not None and site.price_per_hour is not None:
        return Decimal(str(site.price_per_hour))
    return Decimal(str(BASE_PRICE.get(vehicle_type, 50)))


def calculate_amount(entry_time, exit_time, vehicle_type="car", site=None,
                      booked_exit_time=None, is_booking=False, is_extended=False,
                      slot=None):
    """
    Returns the amount (float, 2dp) owed for a stay from entry_time to
    exit_time.

    `site` should be the ParkingSite the vehicle parked at — pass it
    whenever available. If `site` is None, falls back to the old
    global-settings-only flat-rate behaviour (kept for any legacy caller
    that genuinely has no site context).
    """
    total_minutes = (exit_time - entry_time).total_seconds() / 60
    pricing_type = getattr(site, "pricing_type", "flat") if site is not None else "flat"

    # ── Hourly pricing: no flat window, no grace-period slabs ──
    if pricing_type == "hourly":
        rate = _resolve_hourly_rate(site, vehicle_type, slot=slot)
        hours = Decimal(str(total_minutes / 60))
        return _q2(rate * hours)

    # ── Flat pricing (default) ──────────────────────────────────────────
    flat_hours, flat_price, extra_rate = _resolve_flat_settings(
        site, vehicle_type, is_booking, is_extended, slot=slot
    )

    # Minimum charge — within grace period, base price only.
    if total_minutes <= GRACE_PERIOD:
        return _q2(flat_price)

    if booked_exit_time:
        # Booking case: charge is based on the *booked* window, not the
        # flat_hours window — early/late relative to what was reserved.
        booked_minutes = (booked_exit_time - entry_time).total_seconds() / 60

        if total_minutes <= booked_minutes + GRACE_PERIOD:
            return _q2(flat_price)

        extra_minutes = total_minutes - booked_minutes - GRACE_PERIOD
    else:
        # Walk-in case: charge is based on the site's flat_hours window.
        total_hours = total_minutes / 60
        if total_hours <= flat_hours:
            return _q2(flat_price)

        extra_minutes = total_minutes - (flat_hours * 60)

    # Each slab = 60 min + grace period; partial slabs beyond grace round up.
    extra_slabs = math.floor(extra_minutes / (60 + GRACE_PERIOD))
    remaining   = extra_minutes % (60 + GRACE_PERIOD)
    if remaining > GRACE_PERIOD:
        extra_slabs += 1

    extra = Decimal(extra_slabs) * extra_rate
    return _q2(flat_price + extra)


def preview_for_slot(slot, entry_time, exit_time, vehicle_type="car"):
    """
    Convenience wrapper for the booking-estimate use case (no booked_exit_time
    slab logic needed — this is a straight walk-in-style quote for a
    prospective booking window).
    """
    site = slot.parking_site if slot else None
    return calculate_amount(
        entry_time=entry_time,
        exit_time=exit_time,
        vehicle_type=vehicle_type,
        site=site,
        slot=slot,
    )