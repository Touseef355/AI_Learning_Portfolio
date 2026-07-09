# Split out from the auto-generated migration: this one IS a real change —
# live system_settings.id is still a plain AutoField (int4); Django's
# current default_auto_field wants BigAutoField. Applied for real (singleton
# table, harmless widening).
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ('parking', '0003_sync_existing_columns'),
    ]

    operations = [
        migrations.AlterField(
            model_name='systemsettings',
            name='id',
            field=models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID'),
        ),
    ]
