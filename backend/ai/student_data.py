import numpy as np
import pandas as pd

def generate_greek_student_budget_data(n=5000, seed=42):
    rng = np.random.default_rng(seed)

    # City mix (affects rent a bit)
    cities = rng.choice(
        ["Athens", "Thessaloniki", "Patras", "Heraklion", "Ioannina", "Other"],
        size=n,
        p=[0.40, 0.22, 0.12, 0.08, 0.06, 0.12]
    )

    # Student "type" influences spending style
    student_type = rng.choice(
        ["frugal", "average", "social", "high_spend"],
        size=n,
        p=[0.25, 0.50, 0.18, 0.07]
    )

    # Base monthly budget (money available for all outflows incl. savings)
    # Roughly 700–1,800 typical range depending on rent + lifestyle
    base_budget = rng.normal(loc=1100, scale=250, size=n)
    base_budget = np.clip(base_budget, 650, 1900)

    # Rent: city-adjusted; higher for Athens; shared-room-ish distribution
    city_rent_shift = np.select(
        [cities == "Athens", cities == "Thessaloniki", cities == "Heraklion"],
        [80, 20, 10],
        default=-30
    )
    rent = rng.normal(loc=470, scale=120, size=n) + city_rent_shift
    rent = np.clip(rent, 180, 950)

    # Utilities: depends on rent size + season-ish noise
    utilities = rng.normal(loc=70, scale=18, size=n) + 0.03 * (rent - 450)
    utilities = np.clip(utilities, 25, 160)

    # Groceries: typically 150–300 range; lifestyle shift
    groceries = rng.normal(loc=230, scale=55, size=n)
    groceries += np.select(
        [student_type == "frugal", student_type == "social", student_type == "high_spend"],
        [-35, 15, 35],
        default=0
    )
    groceries = np.clip(groceries, 120, 420)

    # Transportation: students often use public transport; some spend more
    transportation = rng.normal(loc=55, scale=20, size=n)
    transportation += np.select(
        [cities == "Other", student_type == "high_spend"],
        [10, 20],
        default=0
    )
    transportation = np.clip(transportation, 10, 180)

    # Entertainment: big variance by type
    entertainment = rng.normal(loc=110, scale=60, size=n)
    entertainment += np.select(
        [student_type == "frugal", student_type == "social", student_type == "high_spend"],
        [-45, 55, 90],
        default=0
    )
    entertainment = np.clip(entertainment, 10, 450)

    # Healthcare: mostly low but occasional spikes
    healthcare = rng.gamma(shape=1.6, scale=18, size=n)  # right-skewed
    healthcare = np.clip(healthcare, 0, 220)

    # Other: subscriptions, clothes, phone, books, random purchases
    other = rng.normal(loc=95, scale=55, size=n)
    other += np.select(
        [student_type == "frugal", student_type == "high_spend"],
        [-25, 45],
        default=0
    )
    other = np.clip(other, 15, 400)

    # Compute "needed" spending excluding savings
    core_spend = rent + utilities + groceries + transportation + entertainment + healthcare + other

    # Savings: what's left from budget, but realistic behavior:
    # - some months save little even if possible
    # - frugal saves more, social saves less
    leftover = base_budget - core_spend
    # convert leftover to savings with a propensity factor + noise
    propensity = np.select(
        [student_type == "frugal", student_type == "average", student_type == "social", student_type == "high_spend"],
        [0.75, 0.55, 0.35, 0.25]
    )
    savings = leftover * propensity + rng.normal(loc=20, scale=35, size=n)
    savings = np.clip(savings, 0, 550)

    total_spending = core_spend + savings

    df = pd.DataFrame({
        "student_id": np.arange(1, n+1),
        "city": cities,
        "student_type": student_type,
        "total_spending": np.round(total_spending, 2),
        "rent": np.round(rent, 2),
        "utilities": np.round(utilities, 2),
        "entertainment": np.round(entertainment, 2),
        "groceries": np.round(groceries, 2),
        "transportation": np.round(transportation, 2),
        "savings": np.round(savings, 2),
        "healthcare": np.round(healthcare, 2),
        "other": np.round(other, 2),
    })

    # If you want *exact* column set requested, drop city/student_type:
    df_min = df[[
        "student_id","total_spending","rent","utilities","entertainment",
        "groceries","transportation","savings","healthcare","other"
    ]]

    return df_min, df

df_min, df_full = generate_greek_student_budget_data(n=5000, seed=42)

# Save to CSV
df_min.to_csv("greek_students_budget_synthetic.csv", index=False)

print(df_min.head(10).to_string(index=False))
print("\nSaved: greek_students_budget_synthetic.csv")
