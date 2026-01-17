class Expense {
  final String merchant;
  final double amount;
  final String category;
  final DateTime date;

  Expense({
    required this.merchant,
    required this.amount,
    required this.category,
    required this.date,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      merchant: json['merchant'] ?? 'Unknown',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      category: json['category'] ?? 'Other',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'merchant': merchant,
    'amount': amount,
    'category': category,
    'date': date.toIso8601String().split('T')[0],
  };
}