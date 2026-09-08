"""Mirrors the Flutter/drift schema. ⚠ Every table carries updated_at and
deleted_at. Soft deletes only — a hard-deleted row leaves nothing to tell the
other device it is gone, so it syncs straight back."""
from django.db import models


class SyncedModel(models.Model):
    # ⚠ THE SERVER STAMPS updated_at. Clients NEVER set it. If the phone and
    # the Mac disagree by minutes, client-set timestamps make last-write-wins
    # pick the wrong winner and an edit vanishes silently. One clock.
    updated_at = models.DateTimeField(auto_now=True, db_index=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        abstract = True


class Person(SyncedModel):
    name = models.CharField(max_length=200)
    company = models.CharField(max_length=200, blank=True, default="")
    wa_number = models.CharField(max_length=40, blank=True, default="")
    wechat_id = models.CharField(max_length=100, blank=True, default="")
    preferred_channel = models.CharField(max_length=10, default="wa")
    met_where = models.CharField(max_length=200, blank=True, default="")
    met_when = models.DateTimeField(null=True, blank=True)
    notes = models.TextField(blank=True, default="")
    # Comma-joined tag list, same encoding as the client.
    occasion_tags = models.CharField(max_length=300, blank=True, default="")
    ping_date = models.DateTimeField(null=True, blank=True)
    ping_note = models.CharField(max_length=300, blank=True, default="")

    def __str__(self):
        return self.name


class Occasion(SyncedModel):
    name = models.CharField(max_length=120)
    date = models.DateTimeField()
    tag = models.CharField(max_length=40)
    country = models.CharField(max_length=20, blank=True, default="")

    class Meta:
        ordering = ["date"]

    def __str__(self):
        return f"{self.name} {self.date:%Y-%m-%d}"


class Engagement(SyncedModel):
    name = models.CharField(max_length=200)
    # ⚠ Not a pipeline. Ralali is a jv, not a deal.
    type = models.CharField(max_length=20, default="deal")
    counterparty_id = models.IntegerField(null=True, blank=True)
    # ⚠ FREE TEXT ON PURPOSE. A dropdown of stages makes this a sales tool.
    status = models.CharField(max_length=200, blank=True, default="")
    value_minor = models.BigIntegerField(null=True, blank=True)
    currency = models.CharField(max_length=8, blank=True, default="")
    notes = models.TextField(blank=True, default="")

    def __str__(self):
        return self.name


class Money(SyncedModel):
    date = models.DateTimeField()
    direction = models.CharField(max_length=4)  # in | out
    amount_minor = models.BigIntegerField()     # integer minor units, never float
    currency = models.CharField(max_length=8, default="CNY")
    label = models.CharField(max_length=200)
    status = models.CharField(max_length=10, default="expected")
    engagement_id = models.IntegerField(null=True, blank=True)
    person_id = models.IntegerField(null=True, blank=True)
    occasion_tag = models.CharField(max_length=40, blank=True, default="")

    class Meta:
        verbose_name_plural = "money"

    def __str__(self):
        return f"{self.label} {self.amount_minor}"


class Note(SyncedModel):
    date = models.DateTimeField()
    text = models.TextField(blank=True, default="")
    person_id = models.IntegerField(null=True, blank=True)
    engagement_id = models.IntegerField(null=True, blank=True)
    tag = models.CharField(max_length=40, blank=True, default="")


class Touch(SyncedModel):
    person_id = models.IntegerField()
    date = models.DateTimeField()
    one_line = models.CharField(max_length=300, blank=True, default="")
