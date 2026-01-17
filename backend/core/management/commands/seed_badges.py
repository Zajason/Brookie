from django.core.management.base import BaseCommand
from core.models import Badge


class Command(BaseCommand):
    help = 'Seed initial badge definitions'

    def handle(self, *args, **options):
        badges_data = [
            {
                'badge_type': 'budget_master',
                'title': 'Budget Master',
                'description': 'Stayed within grocery budget for a month',
                'icon': 'restaurant_rounded',
                'gradient_start': '#4ADE80',
                'gradient_end': '#10B981',
                'target_value': 30,
                'category': 'groceries',
            },
            {
                'badge_type': 'savings_champion',
                'title': 'Savings Champion',
                'description': 'Spent less than peers for a full year',
                'icon': 'emoji_events_rounded',
                'gradient_start': '#FACC15',
                'gradient_end': '#F97316',
                'target_value': 12,
                'category': None,
            },
            {
                'badge_type': 'thrifty_shopper',
                'title': 'Thrifty Shopper',
                'description': 'Stayed within entertainment budget for a month',
                'icon': 'auto_awesome_rounded',
                'gradient_start': '#C084FC',
                'gradient_end': '#EC4899',
                'target_value': 30,
                'category': 'entertainment',
            },
            {
                'badge_type': 'goal_crusher',
                'title': 'Goal Crusher',
                'description': 'Met your monthly savings goal',
                'icon': 'track_changes_rounded',
                'gradient_start': '#60A5FA',
                'gradient_end': '#22D3EE',
                'target_value': 100,  # 100% of savings goal
                'category': 'savings',
            },
            {
                'badge_type': 'spending_slayer',
                'title': 'Spending Slayer',
                'description': 'Reduced spending by 20% this month',
                'icon': 'trending_down_rounded',
                'gradient_start': '#F87171',
                'gradient_end': '#FB7185',
                'target_value': 100,  # 100% = 20% reduction achieved
                'category': None,
            },
            {
                'badge_type': 'elite_saver',
                'title': 'Elite Saver',
                'description': 'Beat peer average spending 6 months in a row',
                'icon': 'workspace_premium_rounded',
                'gradient_start': '#818CF8',
                'gradient_end': '#A855F7',
                'target_value': 6,
                'category': None,
            },
            {
                'badge_type': 'social_saver',
                'title': 'Social Saver',
                'description': 'Stayed within entertainment budget for a month',
                'icon': 'people_alt_rounded',
                'gradient_start': '#2DD4BF',
                'gradient_end': '#22C55E',
                'target_value': 30,
                'category': 'entertainment',
            },
            {
                'badge_type': 'year_legend',
                'title': 'Year Legend',
                'description': 'Stayed within total budget for 365 days',
                'icon': 'calendar_month_rounded',
                'gradient_start': '#FB923C',
                'gradient_end': '#EF4444',
                'target_value': 365,
                'category': None,
            },
        ]

        created_count = 0
        updated_count = 0

        for badge_data in badges_data:
            badge, created = Badge.objects.update_or_create(
                badge_type=badge_data['badge_type'],
                defaults=badge_data
            )
            if created:
                created_count += 1
            else:
                updated_count += 1

        self.stdout.write(
            self.style.SUCCESS(
                f'Seeded badges: {created_count} created, {updated_count} updated'
            )
        )
