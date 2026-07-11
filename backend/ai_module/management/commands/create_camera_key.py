"""
Site-bound camera API key generate karo:

    python manage.py create_camera_key --site <SITE_UUID> --name "Site A Entry"

Key ek hi dafa print hoti hai — .env mein daal lo:
    ENTRY_CAMERA_API_KEY=<printed key>
"""
import secrets

from django.core.management.base import BaseCommand, CommandError

from ai_module.models import CameraAPIKey
from parking.models import ParkingSite


class Command(BaseCommand):
    help = "Create a camera API key bound to a parking site"

    def add_arguments(self, parser):
        parser.add_argument("--site", required=True, help="ParkingSite UUID")
        parser.add_argument("--name", required=True, help="Camera name, e.g. 'Site A Entry'")

    def handle(self, *args, **opts):
        try:
            site = ParkingSite.objects.get(pk=opts["site"])
        except (ParkingSite.DoesNotExist, ValueError):
            raise CommandError(f"ParkingSite '{opts['site']}' not found")

        key = secrets.token_hex(32)
        CameraAPIKey.objects.create(
            key=key, camera_name=opts["name"], parking_site=site,
        )
        self.stdout.write(self.style.SUCCESS(
            f"Camera key created for site '{site.name}' ({opts['name']}):"))
        self.stdout.write(key)
        self.stdout.write("Store it in your camera client's .env — it won't be shown again.")
