"""
URL configuration for sps_backend project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.0/topics/http/urls/
Examples:
Function views
    1. Add an import:  from my_app import views
    2. Add a URL to urlpatterns:  path('', views.home, name='home')
Class-based views
    1. Add an import:  from other_app.views import Home
    2. Add a URL to urlpatterns:  path('', Home.as_view(), name='home')
Including another URLconf
    1. Import the include() function: from django.urls import include, path
    2. Add a URL to urlpatterns:  path('blog/', include('blog.urls'))
"""

from django.contrib import admin
from django.urls import path, include, re_path
from django.conf import settings
from django.conf.urls.static import static
from django.views.static import serve
import os
from pathlib import Path

from payments.views import AppConfigView

BASE_DIR = Path(__file__).resolve().parent.parent
LANDING_PAGE_DIR = os.path.join(BASE_DIR.parent, 'landing-page')

urlpatterns = [
    path("admin/", admin.site.urls),
        path("api/auth/", include('accounts.urls')),
    path('api/parking/', include('parking.urls')),
    path('api/bookings/', include('bookings.urls')),
    path('api/payments/', include('payments.urls')),
    path('api/ai/', include('ai_module.urls')),
    path('api/notifications/', include('notifications.urls')),

    # backend_ali wrote this view but never wired it in — parkroo_app
    # (Flutter) already calls GET /api/config/ on boot and silently falls
    # back to 'mock' when it 404s.
    path('api/config/', AppConfigView.as_view(), name='app-config'),

    # Serve landing page directly from Django backend
    re_path(r'^landing/(?P<path>.*)$', serve, {'document_root': LANDING_PAGE_DIR}),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)
