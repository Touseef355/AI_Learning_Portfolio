import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'sps_backend.settings')
django.setup()

from rest_framework.test import APIClient
from accounts.models import User
from parking.models import ParkingSite
import json

client = APIClient()
admin = User.objects.filter(role='admin').first()
client.force_authenticate(user=admin)

endpoints = [
    ('/api/auth/admin/users/', 'Users List'),
    ('/api/auth/admin/stats/', 'Stats'),
    ('/api/parking/sites/', 'Sites'),
    ('/api/payments/admin/', 'Admin Payments'),
    ('/api/auth/admin/registration-queries/', 'Queries List'),
    ('/api/auth/admin/logs/', 'System Logs'),
    ('/api/parking/admin/settings/', 'Settings')
]

for url, name in endpoints:
    try:
        res = client.get(url)
        print(f'{name} ({url}) STATUS:', res.status_code)
        if res.status_code >= 400:
            print('ERROR DATA:', res.data)
    except Exception as e:
        print(f'{name} ({url}) EXCEPTION:', type(e).__name__, e)
