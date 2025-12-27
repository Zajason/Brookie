from django.db import models

# Create your models here.
from django.db import models

# --- RAG sources ---
class DocSource(models.Model):
    path = models.CharField(max_length=512, unique=True)
    title = models.CharField(max_length=256)
    meta = models.JSONField(default=dict)

class DocChunk(models.Model):
    source = models.ForeignKey(DocSource, on_delete=models.CASCADE)
    chunk_id = models.CharField(max_length=64)
    text = models.TextField()
    ord = models.IntegerField()

# --- Regions & Places (GPS MVP) ---
class Region(models.Model):
    key = models.CharField(max_length=32, unique=True)  # e.g., "glyfada"
    name = models.CharField(max_length=64)
    min_lat = models.FloatField(); max_lat = models.FloatField()
    min_lng = models.FloatField(); max_lng = models.FloatField()

class Place(models.Model):
    name = models.CharField(max_length=128)
    region = models.ForeignKey(Region, on_delete=models.CASCADE)
    category = models.CharField(max_length=32)  # "food" | "groceries"
    price_level = models.IntegerField(default=2)  # 1..4
    rating = models.FloatField(default=0)
    lat = models.FloatField(); lng = models.FloatField()
    notes = models.TextField(blank=True)
