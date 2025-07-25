"""
URL configuration for goit project.

The `urlpatterns` list routes URLs to views. For more information please see:
    https://docs.djangoproject.com/en/5.2/topics/http/urls/
"""
from django.contrib import admin
from django.urls import path
from django.http import HttpResponse

def health_check(request):
    return HttpResponse("OK", status=200)

def home(request):
    return HttpResponse("Welcome to the Django App!", status=200)

urlpatterns = [
    path("health/", health_check, name="health"),
    path("", home, name="home"),
    path("admin/", admin.site.urls),
]