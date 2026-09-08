"""The Django admin doubles as a bulk-edit surface. ⚠ Its main job is seeding
the occasion calendar — the one thing that, if it runs dry, fails silently."""
from django.contrib import admin
from .models import Person, Occasion, Engagement, Money, Note, Touch


@admin.register(Person)
class PersonAdmin(admin.ModelAdmin):
    list_display = ("name", "company", "preferred_channel", "occasion_tags",
                    "ping_date", "updated_at", "deleted_at")
    search_fields = ("name", "company", "wa_number", "wechat_id")
    list_filter = ("preferred_channel",)


@admin.register(Occasion)
class OccasionAdmin(admin.ModelAdmin):
    list_display = ("name", "date", "tag", "country", "updated_at")
    list_filter = ("tag", "country")
    ordering = ("date",)


@admin.register(Engagement)
class EngagementAdmin(admin.ModelAdmin):
    list_display = ("name", "type", "status", "value_minor", "currency")
    list_filter = ("type",)


@admin.register(Money)
class MoneyAdmin(admin.ModelAdmin):
    list_display = ("date", "direction", "amount_minor", "currency", "label", "status")
    list_filter = ("direction", "status", "currency")


admin.site.register(Note)
admin.site.register(Touch)
admin.site.site_header = "Personal CRM"
