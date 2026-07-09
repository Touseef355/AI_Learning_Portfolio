# Hand-split from the auto-generated migration. These operations describe
# columns that already exist on the live Supabase table (added previously
# outside Django's migration system — see fix_db.py / fix_fks.py in
# backend_friend) — this migration is applied with --fake, never run for
# real. See 0004 for the one operation here that's actually new.
import django.db.models.deletion
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('parking', '0002_systemsettings'),
    ]

    operations = [
        migrations.AddField(
            model_name='parkingsite',
            name='address',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='parkingsite',
            name='city',
            field=models.TextField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='parkingsite',
            name='closing_time',
            field=models.TimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='parkingsite',
            name='contact_number',
            field=models.CharField(blank=True, max_length=20, null=True),
        ),
        migrations.AddField(
            model_name='parkingsite',
            name='email',
            field=models.CharField(blank=True, max_length=100, null=True),
        ),
        migrations.AddField(
            model_name='parkingsite',
            name='opening_time',
            field=models.TimeField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='parkingsite',
            name='phone',
            field=models.CharField(blank=True, max_length=20, null=True),
        ),
        migrations.AddField(
            model_name='parkingsite',
            name='price_per_hour',
            field=models.DecimalField(blank=True, decimal_places=2, max_digits=10, null=True),
        ),
        migrations.AddField(
            model_name='parkingsite',
            name='status',
            field=models.CharField(blank=True, max_length=50, null=True),
        ),
        migrations.AddField(
            model_name='parkingsite',
            name='total_floors',
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='parkingsite',
            name='total_slots',
            field=models.IntegerField(blank=True, null=True),
        ),
        migrations.AddField(
            model_name='parkingsite',
            name='updated_at',
            field=models.DateTimeField(auto_now=True),
        ),
        migrations.AlterField(
            model_name='parkingslot',
            name='parking_site',
            field=models.ForeignKey(db_column='site_id', on_delete=django.db.models.deletion.CASCADE, related_name='slots', to='parking.parkingsite'),
        ),
    ]
