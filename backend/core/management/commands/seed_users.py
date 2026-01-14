# backend/core/management/commands/seed_users.py

from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.db import transaction

from core.models import Budget, Spending, Category  # adjust if your app label differs
from decimal import Decimal, ROUND_HALF_UP
import random
import string


# ---------- Helpers ----------

def D(x) -> Decimal:
    # Always quantize to cents
    return Decimal(str(x)).quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def clamp(v, lo, hi):
    return max(lo, min(hi, v))


def pick_weighted(options):
    """
    options: list of (value, weight)
    """
    total = sum(w for _, w in options)
    r = random.uniform(0, total)
    upto = 0
    for val, w in options:
        upto += w
        if upto >= r:
            return val
    return options[-1][0]


def slugify_username(s: str) -> str:
    allowed = string.ascii_lowercase + string.digits + "._"
    s = s.lower().replace(" ", ".")
    s = "".join(ch for ch in s if ch in allowed)
    s = s.strip(".")
    if len(s) < 3:
        s = s + "".join(random.choice(string.ascii_lowercase) for _ in range(3 - len(s)))
    return s[:24]


# ---------- Real-ish data pools ----------

FIRST_NAMES = [
    "Alex", "Maria", "Nikos", "Eleni", "George", "Sofia", "Kostas", "Anna",
    "John", "Emily", "Michael", "Sarah", "Daniel", "Olivia", "David", "Chloe",
    "Andreas", "Giannis", "Dimitris", "Katerina", "Christina", "Panagiotis",
    "Marios", "Irene", "Mark", "Ethan", "Liam", "Noah", "Emma", "Mia",
]

LAST_NAMES = [
    "Papadopoulos", "Ioannidis", "Nikolaou", "Georgiou", "Pappas", "Karamanlis",
    "Zachariou", "Konstantinou", "Sarris", "Vasiliou", "Kotsis", "Doukas",
    "Smith", "Johnson", "Brown", "Taylor", "Anderson", "Thomas", "Jackson",
    "Martin", "Lee", "Walker", "Hall", "Allen",
]

CITIES = [
    ("Athens", "Greece"), ("Thessaloniki", "Greece"), ("Patras", "Greece"),
    ("Heraklion", "Greece"), ("London", "UK"), ("Berlin", "Germany"),
    ("Paris", "France"), ("Milan", "Italy"), ("Madrid", "Spain"),
    ("New York", "USA"), ("San Francisco", "USA"),
]

UNIS = [
    "NTUA", "AUTH", "University of Patras", "AUEB",
    "University of Athens", "TU Munich", "UCL", "Imperial College London",
    "NYU", "UC Berkeley",
]

# Personas influence budgets/spending behaviors
PERSONAS = [
    ("student", 18),
    ("young_professional", 30),
    ("family", 18),
    ("frugal", 16),
    ("spender", 18),
]


# ---------- Budget / Spending generation ----------

CATS = [
    Category.RENT,
    Category.UTILITIES,
    Category.ENTERTAINMENT,
    Category.GROCERIES,
    Category.TRANSPORTATION,
    Category.HEALTHCARE,
    Category.SAVINGS,
    Category.OTHER,
]


def generate_monthly_income(persona: str) -> Decimal:
    # Monthly income tiers (net-ish), tuned by persona
    if persona == "student":
        base = pick_weighted([(450, 35), (650, 35), (900, 20), (1200, 10)])
    elif persona == "family":
        base = pick_weighted([(2200, 25), (2800, 30), (3500, 25), (4500, 15), (6000, 5)])
    else:
        base = pick_weighted([(1200, 25), (1700, 30), (2300, 25), (3200, 15), (5000, 5)])
    # Add a bit of randomness
    base = base * random.uniform(0.92, 1.10)
    return D(base)


def budget_shares(persona: str):
    """
    Returns target shares for each category.
    Sums to <= 1.00; "Other" absorbs slack a bit.
    """
    # Baseline shares (roughly realistic)
    shares = {
        Category.RENT: 0.30,
        Category.GROCERIES: 0.12,
        Category.UTILITIES: 0.06,
        Category.TRANSPORTATION: 0.06,
        Category.HEALTHCARE: 0.04,
        Category.ENTERTAINMENT: 0.06,
        Category.SAVINGS: 0.12,
        Category.OTHER: 0.06,
    }

    if persona == "student":
        shares[Category.RENT] = 0.35
        shares[Category.SAVINGS] = 0.06
        shares[Category.ENTERTAINMENT] = 0.08
        shares[Category.OTHER] = 0.07
    elif persona == "family":
        shares[Category.RENT] = 0.28
        shares[Category.GROCERIES] = 0.18
        shares[Category.HEALTHCARE] = 0.06
        shares[Category.ENTERTAINMENT] = 0.04
        shares[Category.SAVINGS] = 0.10
    elif persona == "frugal":
        shares[Category.SAVINGS] = 0.18
        shares[Category.ENTERTAINMENT] = 0.03
        shares[Category.OTHER] = 0.04
    elif persona == "spender":
        shares[Category.SAVINGS] = 0.06
        shares[Category.ENTERTAINMENT] = 0.10
        shares[Category.OTHER] = 0.10

    # Small noise
    for k in shares:
        shares[k] *= random.uniform(0.90, 1.15)

    # Normalize to about 0.90-0.97 of income (so there’s some untracked slack)
    total = sum(shares.values())
    target_total = random.uniform(0.90, 0.97)
    factor = target_total / total
    for k in shares:
        shares[k] *= factor

    return shares


def generate_budgets(income: Decimal, persona: str):
    shares = budget_shares(persona)
    budgets = {}
    for cat in CATS:
        budgets[cat] = D(income * D(shares[cat]))
    # Make rent more “chunky” (round to nearest 10)
    budgets[Category.RENT] = D((budgets[Category.RENT] / D(10)).quantize(Decimal("1")) * D(10))
    return budgets


def generate_spending(budgets: dict, persona: str):
    """
    Spending is derived from budget with persona-driven over/under patterns.
    """
    spending = {}

    # Base multipliers by persona: frugal under, spender over
    if persona == "frugal":
        base = 0.85
        vol = 0.10
    elif persona == "spender":
        base = 1.10
        vol = 0.18
    elif persona == "student":
        base = 1.00
        vol = 0.20
    else:
        base = 0.98
        vol = 0.14

    for cat, b in budgets.items():
        # Category-specific behavior
        if cat == Category.RENT:
            mult = random.uniform(0.98, 1.02)  # usually fixed
        elif cat == Category.SAVINGS:
            # spender saves less, frugal saves more
            if persona == "spender":
                mult = random.uniform(0.30, 0.80)
            elif persona == "frugal":
                mult = random.uniform(1.00, 1.35)
            else:
                mult = random.uniform(0.75, 1.15)
        elif cat == Category.ENTERTAINMENT:
            mult = random.uniform(base - 0.05, base + vol + 0.10)
        elif cat == Category.GROCERIES:
            mult = random.uniform(base - 0.08, base + vol)
        elif cat == Category.UTILITIES:
            mult = random.uniform(0.85, 1.20)
        else:
            mult = random.uniform(base - 0.06, base + vol)

        # Occasional “oops” overspend on random non-rent categories
        if cat not in (Category.RENT, Category.SAVINGS) and random.random() < 0.12:
            mult *= random.uniform(1.15, 1.60)

        amt = D(b * D(mult))
        spending[cat] = amt

    return spending


# ---------- Command ----------

class Command(BaseCommand):
    help = "Seed the database with realistic users + budgets + spending."

    def add_arguments(self, parser):
        parser.add_argument("--n", type=int, default=200, help="How many users to create (default: 200)")
        parser.add_argument("--password", type=str, default="Test12345!", help="Password for all seeded users")
        parser.add_argument("--seed", type=int, default=42, help="Random seed (default: 42)")
        parser.add_argument(
            "--reset",
            action="store_true",
            help="Delete all non-superusers and their budgets/spending before seeding (DANGEROUS)",
        )
        parser.add_argument(
            "--prefix",
            type=str,
            default="seed",
            help="Username prefix (default: seed) => seed.alex.smith.0001",
        )

    @transaction.atomic
    def handle(self, *args, **options):
        n = options["n"]
        password = options["password"]
        seed = options["seed"]
        reset = options["reset"]
        prefix = options["prefix"]

        random.seed(seed)

        User = get_user_model()

        if reset:
            self.stdout.write(self.style.WARNING("Reset enabled: deleting non-superusers..."))
            User.objects.filter(is_superuser=False).delete()
            Budget.objects.all().delete()
            Spending.objects.all().delete()

        created = 0
        skipped = 0

        self.stdout.write(f"Seeding {n} users...")

        for i in range(1, n + 1):
            first = random.choice(FIRST_NAMES)
            last = random.choice(LAST_NAMES)
            full_name = f"{first} {last}"

            city, country = random.choice(CITIES)
            university = random.choice(UNIS) if random.random() < 0.55 else ""

            persona = pick_weighted([(p, w) for (p, w) in PERSONAS])

            # age / dob: keep plausible
            if persona == "student":
                age = random.randint(18, 25)
            elif persona == "family":
                age = random.randint(28, 45)
            else:
                age = random.randint(22, 38)

            # Rough DOB (not perfect calendar logic, but okay for seed)
            year = 2026 - age
            month = random.randint(1, 12)
            day = random.randint(1, 28)
            dob = f"{year:04d}-{month:02d}-{day:02d}"

            # Create unique username/email
            base_u = slugify_username(f"{prefix}.{first}.{last}.{i:04d}")
            username = base_u
            email = f"{username}@example.com"

            if User.objects.filter(username=username).exists():
                skipped += 1
                continue

            user = User.objects.create_user(
                username=username,
                email=email,
                password=password,
            )
            # Fill your custom fields (safe even if blank)
            if hasattr(user, "full_name"):
                user.full_name = full_name
            if hasattr(user, "age"):
                user.age = age
            if hasattr(user, "date_of_birth"):
                user.date_of_birth = dob
            if hasattr(user, "city"):
                user.city = city
            if hasattr(user, "country"):
                user.country = country
            if hasattr(user, "university"):
                user.university = university
            user.save()

            # Generate budgets + spendings for all categories across 12 months
            income = generate_monthly_income(persona)
            budgets = generate_budgets(income, persona)

            budget_objs = []
            spending_objs = []

            # Create budgets (one per category)
            for cat in CATS:
                budget_objs.append(
                    Budget(user=user, category=cat, amount=budgets[cat])
                )

            Budget.objects.bulk_create(budget_objs)

            # Create spending records for each of the past 12 months
            from datetime import date, timedelta
            today = date(2026, 1, 14)
            
            for months_ago in range(12):
                # Calculate the date for this month
                month = today.month - months_ago
                year = today.year
                while month <= 0:
                    month += 12
                    year -= 1
                month_date = date(year, month, random.randint(1, 28))
                
                # Generate spending with slight variation each month
                spendings = generate_spending(budgets, persona)
                
                for cat in CATS:
                    spending_objs.append(
                        Spending(user=user, category=cat, amount=spendings[cat], date=month_date)
                    )

            Spending.objects.bulk_create(spending_objs)

            created += 1

            if created % 50 == 0:
                self.stdout.write(f"  created {created}/{n}...")

        self.stdout.write(self.style.SUCCESS(f"Done. Created={created}, skipped={skipped}."))
        self.stdout.write(self.style.SUCCESS(f"All seeded users share password: {password}"))
        self.stdout.write("Example login: seed.alex.smith.0001@example.com (or username) depending on your frontend login field.")
