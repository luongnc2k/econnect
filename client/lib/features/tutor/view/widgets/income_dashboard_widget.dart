import 'package:client/features/tutor/model/teacher_income_model.dart';
import 'package:flutter/material.dart';

class IncomeDashboardWidget extends StatelessWidget {
  final TeacherIncomeModel? income;
  final bool isLoading;

  const IncomeDashboardWidget({
    super.key,
    required this.income,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primary, cs.primary.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: isLoading
          ? const SizedBox(
              height: 140,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Icon(Icons.wallet_rounded,
                        color: Colors.white70, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Thu nhập',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const Spacer(),
                    if (income != null)
                      _CompletedBadge(count: income!.completedClasses),
                  ],
                ),

                const SizedBox(height: 8),

                // Total income
                Text(
                  income != null ? _formatVnd(income!.totalIncome) : '--',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 16),

                // This month vs last month
                Row(
                  children: [
                    Expanded(
                      child: _MonthCard(
                        label: 'Tháng này',
                        value: income != null
                            ? _formatVnd(income!.thisMonthIncome)
                            : '--',
                        trend: income != null
                            ? _trend(
                                income!.thisMonthIncome,
                                income!.lastMonthIncome,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MonthCard(
                        label: 'Tháng trước',
                        value: income != null
                            ? _formatVnd(income!.lastMonthIncome)
                            : '--',
                      ),
                    ),
                  ],
                ),

                // 6-month bar chart
                if (income != null &&
                    income!.monthlyBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _BarChart(data: income!.monthlyBreakdown),
                ],
              ],
            ),
    );
  }

  double? _trend(double current, double previous) {
    if (previous == 0) return null;
    return ((current - previous) / previous) * 100;
  }

  static String _formatVnd(double amount) {
    if (amount == 0) return '0đ';
    if (amount >= 1000000) {
      final m = amount / 1000000;
      return '${m % 1 == 0 ? m.toInt() : m.toStringAsFixed(1)}tr đ';
    }
    final str = amount.toInt().toString();
    final buf = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) buf.write('.');
      buf.write(str[i]);
    }
    return '${buf.toString()}đ';
  }
}

// ─── Sub-widgets ─────────────────────────────────────────────────────────────

class _CompletedBadge extends StatelessWidget {
  final int count;
  const _CompletedBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 13, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            '$count lớp đã dạy',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  final String label;
  final String value;
  final double? trend; // % change vs reference

  const _MonthCard({required this.label, required this.value, this.trend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.75),
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (trend != null) ...[
            const SizedBox(height: 4),
            _TrendBadge(percent: trend!),
          ],
        ],
      ),
    );
  }
}

class _TrendBadge extends StatelessWidget {
  final double percent;
  const _TrendBadge({required this.percent});

  @override
  Widget build(BuildContext context) {
    final isUp = percent >= 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
          size: 11,
          color: isUp ? Colors.greenAccent : Colors.redAccent,
        ),
        const SizedBox(width: 2),
        Text(
          '${percent.abs().toStringAsFixed(1)}%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: isUp ? Colors.greenAccent : Colors.redAccent,
          ),
        ),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  final List<MonthlyIncome> data;
  const _BarChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final maxIncome = data.fold(0.0, (m, e) => e.income > m ? e.income : m);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '6 tháng gần nhất',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: data.map((m) {
            final ratio = maxIncome > 0 ? m.income / maxIncome : 0.0;
            final barH = 4.0 + ratio * 36;
            final isLast = m == data.last;
            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 400),
                      height: barH,
                      decoration: BoxDecoration(
                        color: isLast
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.shortLabel,
                      style: TextStyle(
                        fontSize: 10,
                        color: isLast
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.6),
                        fontWeight: isLast
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
