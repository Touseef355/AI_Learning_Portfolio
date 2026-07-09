import os
import django

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "sps_backend.settings")
django.setup()

from django.conf import settings
from django.core.mail import send_mail

try:
    send_mail(
        subject="Test from SmartPark",
        message="This is a test email.",
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=["touseef355@gmail.com"],
        fail_silently=False,
    )
    print("Email sent successfully!")
except Exception as e:
    print(f"Email failed: {e}")
