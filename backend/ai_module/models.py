import uuid
import secrets
from django.db import models
from django.core.validators import MinValueValidator, MaxValueValidator

class AiLog(models.Model):
    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    image_url = models.TextField(null=True,blank=True)
    cropped_plate = models.TextField(null=True, blank=True)
    detected_plate_number = models.CharField(max_length=20)
    # Added validators to restrict confidence_score between 0.0 and 1.0
    confidence_score = models.FloatField(
        validators=[MinValueValidator(0.0), MaxValueValidator(1.0)]
    )
    processed_model_name = models.CharField(max_length=50)
    detected_at = models.DateTimeField(auto_now_add=True)
    # Site jis ke gate pe yeh detection hui — saari queues/logs isi se
    # scope hoti hain (cross-site data leak prevention).
    parking_site = models.ForeignKey(
        'parking.ParkingSite',
        on_delete=models.SET_NULL,
        related_name='ai_logs',
        null=True, blank=True,
    )
    entry_exit_point = models.CharField(
        max_length=50,
        null=True,
        blank=True,
        help_text="Camera location or entry/exit gate name"
    )
    booking = models.ForeignKey(
        'bookings.Booking',
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="ai_logs"
    )
    vehicle_type = models.CharField(
    max_length=20,
    null=True,
    blank=True,
    default="car"
    )
    assigned_slot = models.CharField(
        max_length=20,
        null=True,
        blank=True,
        help_text="Slot reserved at detection time, before cashier approval"
    )
    log_type = models.CharField(
    max_length=10,
    choices=[("entry", "Entry"), ("exit", "Exit")],
    default="entry"
    )
    
    status = models.CharField(
        max_length=20, 
    choices=[
        ("pending",  "Pending"),
        ("approved", "Approved"),
        ("rejected", "Rejected"),
    ],
    default="pending"
    )

    class Meta:
        db_table = "ai_logs"
        indexes = [
            models.Index(fields=['detected_plate_number']),
        ]

    def __str__(self):
        return self.detected_plate_number

class CameraAPIKey(models.Model):
    key=models.CharField(max_length=64, unique=True)
    camera_name=models.CharField(max_length=50)
    # Multi-site isolation: har key EK site se bandhi hai — key se hi
    # pata chalta hai ke detection kis site ke gate se aayi.
    parking_site = models.ForeignKey(
        'parking.ParkingSite',
        on_delete=models.CASCADE,
        related_name='camera_keys',
        null=True, blank=True,
    )
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table="camera_api_keys"

    def __str__ (self):
        return self.camera_name