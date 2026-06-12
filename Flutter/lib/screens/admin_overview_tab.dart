import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/admin_service.dart';
import '../widgets/stat_card.dart';

class AdminOverviewTab extends StatefulWidget {
  const AdminOverviewTab({super.key});

  @override
  State<AdminOverviewTab> createState() => _AdminOverviewTabState();
}

class _AdminOverviewTabState extends State<AdminOverviewTab> {
  final _svc = AdminService();

  bool _loading = true;
  Map<String, dynamic> _overview = {};
  List<dynamic> _dailyUsers = [];
  List<dynamic> _hourlyUsage = [];
  List<dynamic> _featureUsage = [];
  Map<String, dynamic> _roleData = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _svc.getOverview(),
        _svc.getDailyActiveUsers(),
        _svc.getUsageByHour(),
        _svc.getFeatureUsage(),
        _svc.getUsersByRole(),
      ]);
      setState(() {
        _overview = results[0] as Map<String, dynamic>;
        _dailyUsers = results[1] as List<dynamic>;
        _hourlyUsage = results[2] as List<dynamic>;
        _featureUsage = results[3] as List<dynamic>;
        _roleData = results[4] as Map<String, dynamic>;
      });
    } catch (_) {
      // silently fail; show empty state
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)));
    }

    return RefreshIndicator(
      color: const Color(0xFF4F46E5),
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Overview'),
            const SizedBox(height: 12),
            _statsGrid(),
            const SizedBox(height: 24),
            _sectionTitle('Daily Active Users (Last 30 days)'),
            const SizedBox(height: 12),
            _chartCard(_buildLineChart()),
            const SizedBox(height: 24),
            _sectionTitle("Today's Usage by Hour"),
            const SizedBox(height: 12),
            _chartCard(_buildHourlyBarChart()),
            const SizedBox(height: 24),
            _sectionTitle('Users by Role'),
            const SizedBox(height: 12),
            _chartCard(_buildPieChart(), height: 220),
            const SizedBox(height: 24),
            _sectionTitle('Feature Usage'),
            const SizedBox(height: 12),
            _chartCard(_buildFeatureBarChart()),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: const Color(0xFF1E293B),
        ),
      );

  Widget _chartCard(Widget child, {double height = 200}) => Container(
        height: height,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: child,
      );

  Widget _statsGrid() {
    final o = _overview;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        StatCard(
          icon: Icons.people_outline,
          label: 'Total Users',
          value: '${o['total_users'] ?? 0}',
          color: const Color(0xFF4F46E5),
        ),
        StatCard(
          icon: Icons.today_outlined,
          label: 'Active Today',
          value: '${o['active_users_today'] ?? 0}',
          color: const Color(0xFF10B981),
        ),
        StatCard(
          icon: Icons.person_add_outlined,
          label: 'New This Week',
          value: '${o['new_users_this_week'] ?? 0}',
          color: const Color(0xFF0EA5E9),
        ),
        StatCard(
          icon: Icons.block_outlined,
          label: 'Blocked',
          value: '${o['blocked_users_count'] ?? 0}',
          color: const Color(0xFFEF4444),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Charts
  // ---------------------------------------------------------------------------

  Widget _buildLineChart() {
    if (_dailyUsers.isEmpty) {
      return _emptyChart('No data for the last 30 days');
    }

    final spots = _dailyUsers.asMap().entries.map((e) {
      final count = (e.value['count'] as num?)?.toDouble() ?? 0;
      return FlSpot(e.key.toDouble(), count);
    }).toList();

    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0xFFE2E8F0),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              interval: (_dailyUsers.length / 5).ceilToDouble().clamp(1, double.infinity),
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= _dailyUsers.length) return const SizedBox.shrink();
                final dateStr = (_dailyUsers[idx]['date'] as String?)?.substring(5) ?? '';
                return Text(dateStr,
                    style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8)));
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: const Color(0xFF4F46E5),
            barWidth: 2.5,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(
              show: true,
              color: const Color(0xFF4F46E5).withValues(alpha: 0.08),
            ),
          ),
        ],
        minY: 0,
        maxY: maxY + 1,
      ),
    );
  }

  Widget _buildHourlyBarChart() {
    if (_hourlyUsage.isEmpty) {
      return _emptyChart("No usage data for today");
    }

    final barGroups = List.generate(24, (hour) {
      final entry = _hourlyUsage.firstWhere(
        (d) => (d['hour'] as num?)?.toInt() == hour,
        orElse: () => {'hour': hour, 'count': 0},
      );
      final count = (entry['count'] as num?)?.toDouble() ?? 0;
      return BarChartGroupData(
        x: hour,
        barRods: [
          BarChartRodData(
            toY: count,
            color: const Color(0xFF4F46E5),
            width: 6,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ],
      );
    });

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(
            color: Color(0xFFE2E8F0),
            strokeWidth: 1,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: 4,
              getTitlesWidget: (value, _) => Text(
                '${value.toInt()}h',
                style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8)),
              ),
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildPieChart() {
    final student = (_roleData['student'] as num?)?.toDouble() ?? 0;
    final doctor = (_roleData['doctor'] as num?)?.toDouble() ?? 0;
    final admin = (_roleData['it_admin'] as num?)?.toDouble() ?? 0;
    final total = student + doctor + admin;

    if (total == 0) return _emptyChart('No user data');

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: [
                PieChartSectionData(
                  value: student,
                  title: '${(student / total * 100).round()}%',
                  color: const Color(0xFF4F46E5),
                  radius: 65,
                  titleStyle: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                PieChartSectionData(
                  value: doctor,
                  title: '${(doctor / total * 100).round()}%',
                  color: const Color(0xFF0EA5E9),
                  radius: 65,
                  titleStyle: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                PieChartSectionData(
                  value: admin,
                  title: '${(admin / total * 100).round()}%',
                  color: const Color(0xFF7C3AED),
                  radius: 65,
                  titleStyle: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 30,
            ),
          ),
        ),
        const SizedBox(width: 16),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _legend(const Color(0xFF4F46E5), 'Students', student.toInt()),
            const SizedBox(height: 8),
            _legend(const Color(0xFF0EA5E9), 'Doctors', doctor.toInt()),
            const SizedBox(height: 8),
            _legend(const Color(0xFF7C3AED), 'Admins', admin.toInt()),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color color, String label, int count) => Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(
            '$label ($count)',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF475569)),
          ),
        ],
      );

  Widget _buildFeatureBarChart() {
    if (_featureUsage.isEmpty) return _emptyChart('No feature usage data');

    final barGroups = _featureUsage.asMap().entries.map((e) {
      final count = (e.value['count'] as num?)?.toDouble() ?? 0;
      final colors = [
        const Color(0xFF4F46E5),
        const Color(0xFF10B981),
        const Color(0xFF0EA5E9),
        const Color(0xFFF59E0B),
      ];
      return BarChartGroupData(
        x: e.key,
        barRods: [
          BarChartRodData(
            toY: count,
            color: colors[e.key % colors.length],
            width: 28,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          ),
        ],
      );
    }).toList();

    final labels = _featureUsage.map((d) => d['feature'] as String? ?? '').toList();

    return BarChart(
      BarChartData(
        barGroups: barGroups,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                return Text(
                  labels[idx],
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, _) => Text(
                value.toInt().toString(),
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
              ),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _emptyChart(String msg) => Center(
        child: Text(msg,
            style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8))),
      );
}
