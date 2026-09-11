"""
URL configuration for crm project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/6.1/topics/http/urls/
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
import os

from django.contrib import admin
from django.conf import settings
from django.urls import path
from core.sync import sync

# /sync is the whole point of this server, and BearerTokenMiddleware guards it.
urlpatterns = [path('sync', sync)]

# ⚠ /admin is NOT covered by BearerTokenMiddleware — it is a browser surface
# and a browser cannot send an Authorization header. Its only protection is a
# Django superuser password, on a public IP, at a URL every scanner tries.
#
# The clients do not need it: the Dart seedIfEmpty() builds the occasion
# calendar on each device, so admin is a convenience for bulk edits rather than
# a dependency. So it is mounted in development, and in production only if you
# ask for it by name.
if settings.DEBUG or os.environ.get("DJANGO_ENABLE_ADMIN") == "1":
    urlpatterns.append(path('admin/', admin.site.urls))
