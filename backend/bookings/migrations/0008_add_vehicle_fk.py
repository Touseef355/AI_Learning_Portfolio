# The one genuinely new piece: a real UUID FK column, distinct from the
# legacy "vehicle_id" varchar column (now tracked as legacy_vehicle_plate).
# Also (re)creates the entry_time index, since neither the old nor new name
# actually exists on the live table (it was apparently never created).
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("bookings", "0007_sync_state_with_live_schema"),
        ("parking", "0004_alter_systemsettings_id"),
    ]

    operations = [
        migrations.AddField(
            model_name="booking",
            name="vehicle",
            field=models.ForeignKey(
                blank=True,
                null=True,
                on_delete=django.db.models.deletion.SET_NULL,
                related_name="bookings",
                to="parking.vehicle",
                db_column="vehicle_fk_id",
            ),
        ),
        migrations.AddIndex(
            model_name="booking",
            index=models.Index(fields=["entry_time"], name="bookings_entry_d_a2caad_idx"),
        ),
    ]
