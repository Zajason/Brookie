from django.core.management.base import BaseCommand
from django.contrib.auth import get_user_model
from django.db import transaction
from django.utils import timezone
from django.db import models

from core.models import Budget, Spending, Category  # adjust if needed

from decimal import Decimal, ROUND_HALF_UP
import random
from datetime import date
from dateutil.relativedelta import relativedelta


# ---------- Helpers ----------

CENT = Decimal("0.01")


def D(x) -> Decimal:
    return Decimal(str(x)).quantize(CENT, rounding=ROUND_HALF_UP)


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


# ---------- Realistic-ish pools ----------

PERSONAS = [
    ("student", 18),
    ("young_professional", 30),
    ("family", 18),
    ("frugal", 16),
    ("spender", 18),
]

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


def infer_persona_for_user(u) -> str:
    """
    Heuristic only (since User model doesn't store persona).
    We map from age/university presence to a persona distribution.
    """
    age = getattr(u, "age", None)
    university = (getattr(u, "university", "") or "").strip()

    # Strong student signal
    if university and (age is None or age <= 25):
        return pick_weighted([("student", 60), ("frugal", 15), ("spender", 15), ("young_professional", 10)])

    # Age-based guesses
    if age is not None:
        if age <= 25:
            return pick_weighted([("student", 35), ("young_professional", 30), ("spender", 20), ("frugal", 15)])
        if 26 <= age <= 38:
            return pick_weighted([("young_professional", 45), ("spender", 25), ("frugal", 20), ("family", 10)])
        if age >= 39:
            return pick_weighted([("family", 50), ("frugal", 25), ("young_professional", 15), ("spender", 10)])

    # Fallback distribution
    return pick_weighted(PERSONAS)


def generate_monthly_income(persona: str) -> Decimal:
    # Monthly income tiers (net-ish), tuned by persona
    if persona == "student":
        base = pick_weighted([(450, 35), (650, 35), (900, 20), (1200, 10)])
    elif persona == "family":
        base = pick_weighted([(2200, 25), (2800, 30), (3500, 25), (4500, 15), (6000, 5)])
    else:
        base = pick_weighted([(1200, 25), (1700, 30), (2300, 25), (3200, 15), (5000, 5)])

    base = base * random.uniform(0.92, 1.10)
    return D(base)


def budget_shares(persona: str):
    """
    Returns target shares for each category.
    Sums to ~0.90-0.97 so there is slack.
    """
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

    # Add small noise
    for k in shares:
        shares[k] *= random.uniform(0.90, 1.15)

    # Normalize to 0.90-0.97
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

    # Make rent "chunky": nearest 10
    budgets[Category.RENT] = D((budgets[Category.RENT] / D(10)).quantize(Decimal("1")) * D(10))
    return budgets


def generate_spending_for_month(budgets: dict, persona: str):
    """
    Spending derived from budgets with persona-driven patterns.
    """
    spending = {}

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
        if cat == Category.RENT:
            mult = random.uniform(0.98, 1.02)
        elif cat == Category.SAVINGS:
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

        # occasional overspend on non-rent/non-savings
        if cat not in (Category.RENT, Category.SAVINGS) and random.random() < 0.12:
            mult *= random.uniform(1.15, 1.60)

        spending[cat] = D(b * D(mult))

    return spending


def month_anchor_dates(months: int, day_mode: str, start_from: date):
    """
    Returns list of dates, one per month, going back `months` months inclusive.
    day_mode:
      - "fixed15": always day 15
      - "random": random day 1..28
      - "monthend": day 28 (safe)
    """
    dates = []
    for m in range(months):
        dt = start_from - relativedelta(months=m)
        if day_mode == "fixed15":
            d = 15
        elif day_mode == "monthend":
            d = 28
        else:
            d = random.randint(1, 28)
        dates.append(date(dt.year, dt.month, d))
    return dates


# ---------- Command ----------

class Command(BaseCommand):
    help = "Seed realistic budgets + spendings for EXISTING users only."

    def add_arguments(self, parser):
        parser.add_argument("--months", type=int, default=12, help="How many months of spendings to create (default: 12)")
        parser.add_argument("--seed", type=int, default=42, help="Random seed (default: 42)")

        parser.add_argument(
            "--day-mode",
            type=str,
            default="random",
            choices=["random", "fixed15", "monthend"],
            help="Date day for each month (default: random)",
        )

        parser.add_argument(
            "--users",
            type=str,
            default="all",
            help='Which users: "all" (default) or a comma list of usernames/emails',
        )
        parser.add_argument(
            "--exclude-superusers",
            action="store_true",
            help="Skip superusers",
        )

        parser.add_argument(
            "--update-budgets",
            action="store_true",
            help="If set: overwrite existing Budget.amount values. Otherwise only create missing budgets.",
        )

        parser.add_argument(
            "--overwrite-spending",
            action="store_true",
            help="If set: delete spending in the target months range first, then recreate.",
        )

        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Compute everything but do not write to DB.",
        )

    @transaction.atomic
    def handle(self, *args, **opts):
        months = opts["months"]
        seed = opts["seed"]
        day_mode = opts["day_mode"]
        users_arg = (opts["users"] or "all").strip().lower()
        exclude_superusers = opts["exclude_superusers"]
        update_budgets = opts["update_budgets"]
        overwrite_spending = opts["overwrite_spending"]
        dry_run = opts["dry_run"]

        random.seed(seed)

        User = get_user_model()

        qs = User.objects.all()
        if exclude_superusers:
            qs = qs.filter(is_superuser=False)

        if users_arg != "all":
            tokens = [t.strip() for t in users_arg.split(",") if t.strip()]
            qs = qs.filter(models.Q(username__in=tokens) | models.Q(email__in=tokens))

        users = list(qs)
        if not users:
            self.stdout.write(self.style.WARNING("No users matched your filters. Nothing to do."))
            return

        today = timezone.now().date()
        anchors = month_anchor_dates(months=months, day_mode=day_mode, start_from=today)
        oldest = min(anchors)
        newest = max(anchors)

        self.stdout.write(
            f"Seeding spending for {len(users)} existing users, months={months}, range={oldest}..{newest}"
            + (" (DRY RUN)" if dry_run else "")
        )

        total_budget_created = 0
        total_budget_updated = 0
        total_spending_created = 0
        total_spending_skipped = 0
        total_spending_deleted = 0

        # If overwrite spending, we delete in-range per user
        if overwrite_spending and not dry_run:
            user_ids = [u.id for u in users]
            deleted, _ = Spending.objects.filter(
                user_id__in=user_ids,
                date__in=anchors,
            ).delete()
            total_spending_deleted += deleted
            self.stdout.write(self.style.WARNING(f"Overwrite enabled: deleted {deleted} Spending rows in target range."))

        # Preload budgets per user
        existing_budgets = Budget.objects.filter(user__in=users)
        budget_map = {}  # (user_id, cat) -> Budget
        for b in existing_budgets:
            budget_map[(b.user_id, b.category)] = b

        # Process each user
        for idx, u in enumerate(users, start=1):
            persona = infer_persona_for_user(u)
            income = generate_monthly_income(persona)
            budgets = generate_budgets(income, persona)

            # Ensure budgets exist
            budgets_to_create = []
            budgets_to_update = []
            for cat in CATS:
                key = (u.id, cat)
                if key not in budget_map:
                    budgets_to_create.append(Budget(user=u, category=cat, amount=budgets[cat]))
                else:
                    if update_budgets:
                        b = budget_map[key]
                        b.amount = budgets[cat]
                        budgets_to_update.append(b)

            if not dry_run:
                if budgets_to_create:
                    Budget.objects.bulk_create(budgets_to_create, ignore_conflicts=True)
                    total_budget_created += len(budgets_to_create)
                if budgets_to_update:
                    Budget.objects.bulk_update(budgets_to_update, fields=["amount"])
                    total_budget_updated += len(budgets_to_update)

            # Determine which spending rows already exist (unless overwrite deleted them)
            existing_spend_keys = set()
            if not overwrite_spending:
                existing = Spending.objects.filter(user=u, date__in=anchors).values_list("category", "date")
                existing_spend_keys = set(existing)

            spending_to_create = []
            for month_date in anchors:
                # per-month slight variation
                spendings = generate_spending_for_month(budgets, persona)
                for cat in CATS:
                    key = (cat, month_date)
                    if key in existing_spend_keys:
                        total_spending_skipped += 1
                        continue
                    spending_to_create.append(
                        Spending(user=u, category=cat, amount=spendings[cat], date=month_date)
                    )

            if not dry_run and spending_to_create:
                # ignore_conflicts protects against uniqueness collisions if concurrent runs happen
                Spending.objects.bulk_create(spending_to_create, ignore_conflicts=True)
                total_spending_created += len(spending_to_create)
            else:
                total_spending_created += len(spending_to_create) if dry_run else 0

            if idx % 50 == 0 or idx == len(users):
                self.stdout.write(f"  processed {idx}/{len(users)} users...")

        self.stdout.write(self.style.SUCCESS("Done."))
        self.stdout.write(
            self.style.SUCCESS(
                f"Budgets: created={total_budget_created}, updated={total_budget_updated}"
            )
        )
        if overwrite_spending:
            self.stdout.write(self.style.WARNING(f"Spending: deleted={total_spending_deleted} (overwrite mode)"))
        self.stdout.write(
            self.style.SUCCESS(
                f"Spending: created={total_spending_created}, skipped(existing)={total_spending_skipped}"
            )
        )
