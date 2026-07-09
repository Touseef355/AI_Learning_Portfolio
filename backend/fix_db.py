import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sps_backend.settings')
django.setup()

from django.db import connection

try:
    with connection.cursor() as cursor:
        cursor.execute("ALTER TABLE payments ADD COLUMN IF NOT EXISTS currency VARCHAR(10) DEFAULT 'PKR';")
        cursor.execute("ALTER TABLE payments ADD COLUMN IF NOT EXISTS payment_reference VARCHAR(100) DEFAULT NULL;")
        cursor.execute("ALTER TABLE payments ADD COLUMN IF NOT EXISTS refund_amount DECIMAL(10, 2) DEFAULT NULL;")
    print('Columns added successfully')
except Exception as e:
    print('Error:', e)
