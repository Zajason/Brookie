import os
import requests
from django.conf import settings

GOOGLE_PLACES_KEY = os.getenv("GOOGLE_PLACES_API_KEY") or getattr(settings, "GOOGLE_PLACES_API_KEY", "")

class PlacesService:
    @staticmethod
    def search_restaurants(city: str, max_results: int = 5, cheap_only: bool = True):
        if not GOOGLE_PLACES_KEY:
            return []

        # Text Search: "cheap restaurants in Athens"
        query = f"{'cheap ' if cheap_only else ''}restaurants in {city}".strip()

        url = "https://maps.googleapis.com/maps/api/place/textsearch/json"
        params = {
            "query": query,
            "key": GOOGLE_PLACES_KEY,
        }

        r = requests.get(url, params=params, timeout=10)
        r.raise_for_status()
        data = r.json()

        results = data.get("results", [])[:max_results]

        # Keep only the fields we need
        places = []
        for p in results:
            places.append({
                "name": p.get("name"),
                "address": p.get("formatted_address"),
                "rating": p.get("rating"),
                "price_level": p.get("price_level"),  # 0-4
                "place_id": p.get("place_id"),
                "maps_url": f"https://www.google.com/maps/search/?api=1&query_place_id={p.get('place_id')}" if p.get("place_id") else None
            })
        return places
