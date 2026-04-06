class MonthlyIncome {
  final String month; // "2026-03"
  final double income;

  const MonthlyIncome({required this.month, required this.income});

  factory MonthlyIncome.fromMap(Map<String, dynamic> m) => MonthlyIncome(
        month: m['month'] as String,
        income: (m['income'] as num).toDouble(),
      );

  /// "Th3" / "Th12"
  String get shortLabel {
    final parts = month.split('-');
    return 'Th${int.parse(parts[1])}';
  }
}

class TeacherIncomeModel {
  final double totalIncome;
  final double thisMonthIncome;
  final double lastMonthIncome;
  final int completedClasses;
  final List<MonthlyIncome> monthlyBreakdown;

  const TeacherIncomeModel({
    required this.totalIncome,
    required this.thisMonthIncome,
    required this.lastMonthIncome,
    required this.completedClasses,
    required this.monthlyBreakdown,
  });

  factory TeacherIncomeModel.fromMap(Map<String, dynamic> m) =>
      TeacherIncomeModel(
        totalIncome: (m['total_income'] as num).toDouble(),
        thisMonthIncome: (m['this_month_income'] as num).toDouble(),
        lastMonthIncome: (m['last_month_income'] as num).toDouble(),
        completedClasses: (m['completed_classes'] as num).toInt(),
        monthlyBreakdown: (m['monthly_breakdown'] as List<dynamic>)
            .map((e) => MonthlyIncome.fromMap(e as Map<String, dynamic>))
            .toList(),
      );
}
