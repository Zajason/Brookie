# generate_places.py
import random
import json
from datetime import date

random.seed(42)

CITY_CENTERS = {
    "Athens": (37.9838, 23.7275),
    "Thessaloniki": (40.6401, 22.9444),
    "Patras": (38.2466, 21.7346),
    "Heraklion": (35.3387, 25.1442),
    "Ioannina": (39.6650, 20.8537),
}

RESTAURANT_SUBCATS = ["souvlaki", "coffee", "pizza", "burger", "student_canteen", "asian", "bakery_cafe"]
SHOP_SUBCATS = ["supermarket", "mini_market", "bakery", "produce_market", "pharmacy", "gym_supplements", "thrift_store"]

BUDGET_TAGS_POOL = [
    "cheap", "student_deal", "big_portions", "meal_prep", "late_open",
    "study_friendly", "essentials", "bulk_discounts", "good_value"
]

def jitter_latlon(lat, lon, km_radius=4.0):
    # rough conversion: 1 deg lat ~ 111km; 1 deg lon ~ 111km*cos(lat)
    # random point in circle
    r = km_radius * (random.random() ** 0.5)
    theta = random.random() * 2 * 3.1415926535
    dlat = (r * (1/111.0)) * (random.choice([-1, 1])) * abs(random.cos(theta)) if hasattr(random, "cos") else (r * (1/111.0)) * (random.choice([-1, 1]))
    # simpler (no trig dependency): use box jitter instead
    dlat = (random.uniform(-1, 1) * km_radius) / 111.0
    dlon = (random.uniform(-1, 1) * km_radius) / (111.0 * max(0.2, abs(__import__("math").cos(lat))))
    return lat + dlat, lon + dlon

def make_name(subcat, city, kind):
    prefixes = {
        "souvlaki": ["Pita", "Souvlaki", "Gyros", "Skewer"],
        "coffee": ["Coffee", "Brew", "Roast", "Bean"],
        "pizza": ["Slice", "Oven", "Crust", "Pizza"],
        "burger": ["Burger", "Grill", "Stack", "Patty"],
        "student_canteen": ["Campus", "Student", "Uni", "Canteen"],
        "asian": ["Noodle", "Wok", "Sushi", "Ramen"],
        "bakery_cafe": ["Bakery", "Croissant", "Bread", "Boulangerie"],
        "supermarket": ["Budget", "Daily", "Family", "Market"],
        "mini_market": ["Corner", "Mini", "Express", "24/7"],
        "bakery": ["Koulouri", "Bread", "Bakery", "Oven"],
        "produce_market": ["Fresh", "Green", "Produce", "Farm"],
        "pharmacy": ["Pharma", "Health", "Care", "Medi"],
        "gym_supplements": ["Fit", "Protein", "Supps", "Fuel"],
        "thrift_store": ["Thrift", "Second Chance", "Vintage", "Rewear"],
    }
    a = random.choice(prefixes.get(subcat, ["Place"]))
    b = random.choice(["Corner", "Lab", "House", "Stop", "Point", "Hub", "Spot"])
    suffix = city[:4].upper()
    return f"{a} {b} {suffix}" if kind == "restaurant" else f"{a} {b}"

def categories_supported(kind, subcat):
    if kind == "shop":
        if subcat in ["supermarket","mini_market","bakery","produce_market"]:
            return ["groceries"]
        if subcat == "pharmacy":
            return ["healthcare"]
        return ["other"]
    else:
        # restaurant: mostly entertainment; sometimes groceries if "meal_prep"/cheap
        if subcat in ["student_canteen","souvlaki","pizza"]:
            return ["entertainment","groceries"]
        return ["entertainment"]

def price_level_for(subcat):
    if subcat in ["student_canteen","souvlaki","mini_market","produce_market","bakery","supermarket","thrift_store"]:
        return random.choices([1,2], weights=[0.75,0.25])[0]
    if subcat in ["coffee","pizza","burger","asian","pharmacy","gym_supplements"]:
        return random.choices([1,2,3], weights=[0.25,0.60,0.15])[0]
    return 2

def pick_tags(price_level, kind):
    tags = set()
    if price_level == 1:
        tags.add("cheap")
        if random.random() < 0.25:
            tags.add("student_deal")
    if random.random() < 0.25:
        tags.add("late_open")
    if kind == "restaurant" and random.random() < 0.20:
        tags.add("big_portions")
    if kind == "shop" and random.random() < 0.25:
        tags.add("meal_prep")
    if kind == "restaurant" and random.random() < 0.15:
        tags.add("study_friendly")
    while len(tags) < random.randint(2, 4):
        tags.add(random.choice(BUDGET_TAGS_POOL))
    return sorted(tags)

def make_address(city):
    streets = ["Panepistimiou", "Solonos", "Stadiou", "Akadimias", "Athinas", "Egnatia", "Tsimiski", "Korai", "Ippokratous", "Ermou"]
    return f"{random.randint(1, 80)} {random.choice(streets)} St, {city}"

def generate_places(n_per_city=250, out_path="places_synthetic.jsonl"):
    today = str(date.today())
    place_id_counter = 1

    with open(out_path, "w", encoding="utf-8") as f:
        for city, (clat, clon) in CITY_CENTERS.items():
            for _ in range(n_per_city):
                kind = random.choices(["restaurant","shop"], weights=[0.55,0.45])[0]
                subcat = random.choice(RESTAURANT_SUBCATS if kind == "restaurant" else SHOP_SUBCATS)

                lat = clat + random.uniform(-0.03, 0.03)
                lon = clon + random.uniform(-0.03, 0.03)

                price_level = price_level_for(subcat)
                tags = pick_tags(price_level, kind)

                rec = {
                    "place_id": f"{city[:4].lower()}-{kind[0]}-{place_id_counter:05d}",
                    "name": make_name(subcat, city, kind),
                    "type": kind,
                    "subcategory": subcat,
                    "city": city,
                    "address": make_address(city),
                    "latitude": round(lat, 6),
                    "longitude": round(lon, 6),
                    "price_level": price_level,
                    "budget_tags": tags,
                    "categories_supported": categories_supported(kind, subcat),
                    "opening_hours": random.choice(["Daily 08:00-23:00","Mon-Sat 08:00-21:00","Daily 12:00-01:00","Mon-Fri 09:00-20:00"]),
                    "notes": random.choice([
                        "Good value option.",
                        "Student-friendly pricing.",
                        "Great for meal-prep weeks.",
                        "Convenient location; watch impulse buys.",
                        "Solid budget pick near campus."
                    ]),
                    "data_source": "synthetic",
                    "last_updated": today
                }

                f.write(json.dumps(rec, ensure_ascii=False) + "\n")
                place_id_counter += 1

    print(f"Saved {n_per_city * len(CITY_CENTERS)} places to {out_path}")

if __name__ == "__main__":
    generate_places(n_per_city=300, out_path="places_synthetic.jsonl")
