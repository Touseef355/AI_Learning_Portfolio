# Hand-written. Same issue as 0009, two more legacy unmapped columns found
# by actually exercising booking creation end-to-end:
#   - customer_name: NOT NULL, no default, not used by any app code.
#   - vehicle_id: NOT NULL at the DB level, but the model's
#     legacy_vehicle_plate field (same column) declares null=True — the
#     live constraint was never relaxed to match, so any booking without a
#     legacy plate string (i.e. every booking created through the merged
#     vehicle-FK flow) failed to insert.
from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("bookings", "0009_booking_id_nullable"),
    ]

    operations = [
        migrations.RunSQL(
            sql='ALTER TABLE "bookings" ALTER COLUMN "customer_name" DROP NOT NULL;',
            reverse_sql='ALTER TABLE "bookings" ALTER COLUMN "customer_name" SET NOT NULL;',
        ),
        migrations.RunSQL(
            sql='ALTER TABLE "bookings" ALTER COLUMN "vehicle_id" DROP NOT NULL;',
            reverse_sql='ALTER TABLE "bookings" ALTER COLUMN "vehicle_id" SET NOT NULL;',
        ),
    ]
