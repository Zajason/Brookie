from django.core.management.base import BaseCommand
from core.models import User, Spending, Budget
from datetime import date, timedelta
from decimal import Decimal
import random


class Command(BaseCommand):
    help = 'Seed spending and budget data for all superusers'

    def handle(self, *args, **options):
        superusers = User.objects.filter(is_superuser=True)
        
        if not superusers.exists():
            self.stdout.write(self.style.WARNING('No superusers found'))
            return
        
        self.stdout.write(f'Found {superusers.count()} superuser(s):')
        for su in superusers:
            self.stdout.write(f'  - {su.username} ({su.email})')
        
        today = date.today()
        
        for user in superusers:
            # Clear existing spending for this user
            deleted_count = Spending.objects.filter(user=user).delete()[0]
            self.stdout.write(f'\n{user.username}: Deleted {deleted_count} old records')
            
            created_count = 0
            
            # Create spending records for the last 30 days
            for i in range(30):
                day = today - timedelta(days=i)
                
                # Groceries - daily small purchases (70% of days)
                if random.random() > 0.3:
                    Spending.objects.create(
                        user=user,
                        category='groceries',
                        amount=Decimal(str(round(random.uniform(5, 25), 2))),
                        date=day
                    )
                    created_count += 1
                
                # Entertainment - occasional (30% of days)
                if random.random() > 0.7:
                    Spending.objects.create(
                        user=user,
                        category='entertainment',
                        amount=Decimal(str(round(random.uniform(10, 50), 2))),
                        date=day
                    )
                    created_count += 1
                
                # Transportation - most days (60% of days)
                if random.random() > 0.4:
                    Spending.objects.create(
                        user=user,
                        category='transportation',
                        amount=Decimal(str(round(random.uniform(3, 15), 2))),
                        date=day
                    )
                    created_count += 1
                
                # Healthcare - rare (10% of days)
                if random.random() > 0.9:
                    Spending.objects.create(
                        user=user,
                        category='healthcare',
                        amount=Decimal(str(round(random.uniform(15, 80), 2))),
                        date=day
                    )
                    created_count += 1

            # Monthly bills (at start of month)
            Spending.objects.create(
                user=user, 
                category='rent', 
                amount=Decimal('450.00'), 
                date=today.replace(day=1)
            )
            created_count += 1
            
            Spending.objects.create(
                user=user, 
                category='utilities', 
                amount=Decimal('65.00'), 
                date=today.replace(day=1)
            )
            created_count += 1

            # Set budgets for the user
            budgets = {
                'groceries': 300,
                'entertainment': 100,
                'transportation': 150,
                'utilities': 80,
                'healthcare': 50,
                'rent': 500,
                'savings': 200,
                'other': 100,
            }

            for cat, amount in budgets.items():
                Budget.objects.update_or_create(
                    user=user,
                    category=cat,
                    defaults={'amount': Decimal(str(amount))}
                )

            self.stdout.write(
                self.style.SUCCESS(f'{user.username}: Created {created_count} spending records + 8 budgets')
            )
        
        self.stdout.write(self.style.SUCCESS('\nDone seeding superusers!'))
