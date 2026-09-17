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

from django.urls import path

from core.auth import delete_account, login, logout, me, register
from core.sync import sync

# ⚠ No /admin. See INSTALLED_APPS in settings.py for why it was removed rather
# than merely hidden.
#
# /auth/register and /auth/login are the only unauthenticated routes; everything
# else goes through BearerTokenMiddleware.
urlpatterns = [
    path('auth/register', register),
    path('auth/login', login),
    path('auth/logout', logout),
    path('auth/me', me),
    path('auth/delete', delete_account),
    path('sync', sync),
]
