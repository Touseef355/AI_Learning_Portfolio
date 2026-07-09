# Hand-written. Found during Phase 7 end-to-end validation: the live
# "booking_id" column (a legacy human-readable ID, unrelated to and
# unmapped by either backend's Booking model) is NOT NULL with no default
# and a UNIQUE constraint — meaning every booking creation through the
# Django app was failing with an IntegrityError, since Django never
# supplies a value for a column it doesn't know about. Nothing reads or
# writes this column; making it nullable is the minimal fix (NULLs don't
# violate the existing UNIQUE constraint).
from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("bookings", "0008_add_vehicle_fk"),
    ]

    operations = [
        migrations.RunSQL(
            sql='ALTER TABLE "bookings" ALTER COLUMN "booking_id" DROP NOT NULL;',
            reverse_sql='ALTER TABLE "bookings" ALTER COLUMN "booking_id" SET NOT NULL;',
        ),
    ]
