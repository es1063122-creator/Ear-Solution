import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/theme/app_colors.dart';

final recordsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final raw = prefs.getString('records') ?? '[]';
  final list = jsonDecode(raw) as List;
  return list.cast<Map<String, dynamic>>();
});

class AnalysisScreen extends ConsumerWidget {
  const AnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(recordsProvider);

    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: const Text('패턴 분석'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(recordsProvider),
          ),
        ],
      ),
      body: recordsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.green)),
        error: (e, _) => Center(child: Text('오류: $e')),
        data: (records) {
          if (records.isEmpty) return _EmptyState();
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _ChartCard(title: '이명 강도 추이', child: _IntensityChart(records: records)),
              const SizedBox(height: 12),
              _InsightCards(records: records),
              const SizedBox(height: 12),
              _ChartCard(title: '수면 시간 추이', child: _SleepChart(records: records)),
            ]),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.bar_chart, size: 64, color: AppColors.greenLight),
      const SizedBox(height: 16),
      const Text('기록이 없어요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
      const SizedBox(height: 8),
      const Text('기록 탭에서 오늘 기록을 남기면\n패턴 분석이 시작됩니다',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 14, color: AppColors.textLight, height: 1.5)),
    ]),
  );
}

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.white, borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.greenLight)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
      const SizedBox(height: 16),
      child,
    ]),
  );
}

class _IntensityChart extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _IntensityChart({required this.records});

  @override
  Widget build(BuildContext context) {
    final spots = records.asMap().entries.map((e) =>
      FlSpot(e.key.toDouble(), (e.value['intensity'] as num).toDouble())).toList();

    return SizedBox(
      height: 160,
      child: LineChart(LineChartData(
        gridData: FlGridData(
          show: true, horizontalInterval: 2, drawVerticalLine: false,
          getDrawingHorizontalLine: (v) => FlLine(color: AppColors.greenLight, strokeWidth: 0.5)),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, interval: 2, reservedSize: 28,
            getTitlesWidget: (v, _) => Text('${v.round()}',
              style: const TextStyle(fontSize: 10, color: AppColors.textLight)))),
          bottomTitles: AxisTitles(sideTitles: SideTitles(
            showTitles: true, interval: 3, reservedSize: 20,
            getTitlesWidget: (v, _) {
              final idx = v.round();
              if (idx >= 0 && idx < records.length) {
                final d = records[idx]['date'] as String;
                final parts = d.split('-');
                return Text('${parts[1]}/${parts[2]}',
                  style: const TextStyle(fontSize: 9, color: AppColors.textLight));
              }
              return const SizedBox();
            })),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        minY: 0, maxY: 10,
        lineBarsData: [LineChartBarData(
          spots: spots, isCurved: true,
          color: AppColors.green, barWidth: 2.5,
          belowBarData: BarAreaData(show: true, color: AppColors.green.withOpacity(0.1)),
          dotData: FlDotData(show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 3, color: AppColors.green, strokeWidth: 0)),
        )],
      )),
    );
  }
}

class _SleepChart extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _SleepChart({required this.records});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 120,
    child: BarChart(BarChartData(
      gridData: const FlGridData(show: false),
      borderData: FlBorderData(show: false),
      titlesData: const FlTitlesData(
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      barGroups: records.asMap().entries.map((e) {
        final hours = (e.value['sleepHours'] as num).toDouble();
        return BarChartGroupData(x: e.key, barRods: [BarChartRodData(
          toY: hours,
          color: hours >= 7 ? AppColors.green : AppColors.gold,
          width: 8, borderRadius: BorderRadius.circular(2),
        )]);
      }).toList(),
    )),
  );
}

class _InsightCards extends StatelessWidget {
  final List<Map<String, dynamic>> records;
  const _InsightCards({required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.length < 3) return const SizedBox();

    final avgIntensity = records.map((r) => (r['intensity'] as num).toDouble())
      .reduce((a, b) => a + b) / records.length;

    final highStress = records.where((r) => (r['stress'] as num) >= 4).toList();
    final lowStress  = records.where((r) => (r['stress'] as num) <= 2).toList();
    final highStressAvg = highStress.isEmpty ? 0.0
      : highStress.map((r) => (r['intensity'] as num).toDouble()).reduce((a,b) => a+b) / highStress.length;
    final lowStressAvg = lowStress.isEmpty ? 0.0
      : lowStress.map((r) => (r['intensity'] as num).toDouble()).reduce((a,b) => a+b) / lowStress.length;

    return Column(children: [
      Row(children: [
        Expanded(child: _InsightTile(
          label: '평균 이명 강도',
          value: avgIntensity.toStringAsFixed(1),
          unit: '/ 10',
          color: AppColors.intensityColor(avgIntensity.round()),
        )),
        const SizedBox(width: 10),
        Expanded(child: _InsightTile(
          label: '총 기록일',
          value: '${records.length}',
          unit: '일',
          color: AppColors.green,
        )),
      ]),
      if (highStress.isNotEmpty && lowStress.isNotEmpty) ...[
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.white, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.greenLight)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('스트레스와 이명 관계', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.greenDark)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.gold.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('스트레스 높음\n${highStressAvg.toStringAsFixed(1)}점',
                  style: const TextStyle(fontSize: 12, color: AppColors.gold, fontWeight: FontWeight.w500)),
              )),
              const SizedBox(width: 8),
              Expanded(child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text('스트레스 낮음\n${lowStressAvg.toStringAsFixed(1)}점',
                  style: const TextStyle(fontSize: 12, color: AppColors.green, fontWeight: FontWeight.w500)),
              )),
            ]),
          ]),
        ),
      ],
    ]);
  }
}

class _InsightTile extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _InsightTile({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.white, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.greenLight)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
      const SizedBox(height: 6),
      Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: color)),
        const SizedBox(width: 4),
        Padding(padding: const EdgeInsets.only(bottom: 4),
          child: Text(unit, style: const TextStyle(fontSize: 12, color: AppColors.textLight))),
      ]),
    ]),
  );
}
