# Hand-written. Same category as bookings 0009/0010: "transaction_id" is a
# legacy column not mapped by the Payment model (payment_reference is the
# field actually used for this concept). NOT NULL with no default meant
# every Payment.objects.create() — e.g. PaymentView.post — failed.
from django.db import migrations


class Migration(migrations.Migration):

    dependencies = [
        ("payments", "0002_payment_created_at_payment_payment_channel_and_more"),
    ]

    operations = [
        migrations.RunSQL(
            sql='ALTER TABLE "payments" ALTER COLUMN "transaction_id" DROP NOT NULL;',
            reverse_sql='ALTER TABLE "payments" ALTER COLUMN "transaction_id" SET NOT NULL;',
        ),
    ]
