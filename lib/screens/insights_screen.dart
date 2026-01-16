import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/design_tokens.dart';

/// Insights screen showing observation history for a learner.
/// Displays mock data with visualizations to demonstrate the app's purpose.
class InsightsScreen extends StatelessWidget {
  final String learnerId;
  final String learnerAlias;

  const InsightsScreen({
    super.key,
    required this.learnerId,
    required this.learnerAlias,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Mock data - demonstrating what real insights would look like
    final mockSessions = [
      _MockSession(
        date: 'Today, 2:30 PM',
        activity: 'Focus Tap',
        patterns: [
          _MockPattern(
            name: 'Consistent attention',
            confidence: 'moderate',
            icon: Icons.center_focus_strong,
            description: 'Response times remained steady throughout the activity, '
                'suggesting sustained focus during the task.',
            support: 'Continue with similar activity lengths. '
                'This learner appears comfortable with 2-3 minute sessions.',
          ),
        ],
      ),
      _MockSession(
        date: 'Yesterday, 4:15 PM',
        activity: 'Focus Tap',
        patterns: [
          _MockPattern(
            name: 'Quick starter',
            confidence: 'high',
            icon: Icons.bolt,
            description: 'Initial responses were notably faster than average, '
                'indicating strong engagement at the start.',
            support: 'Leverage early enthusiasm by front-loading '
                'important information in activities.',
          ),
          _MockPattern(
            name: 'Gradual slowing',
            confidence: 'low',
            icon: Icons.trending_down,
            description: 'Response times increased slightly toward the end, '
                'which may indicate natural fatigue.',
            support: 'Consider shorter sessions or adding brief breaks. '
                'This is common and not a concern.',
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Observations'),
        centerTitle: true,
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.sm),
        children: [
          // Learner Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    learnerAlias.isNotEmpty ? learnerAlias[0].toUpperCase() : '?',
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      learnerAlias,
                      style: theme.textTheme.titleLarge,
                    ),
                    Text(
                      '${mockSessions.length} sessions recorded',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppSpacing.md),

          // ═══════════════════════════════════════════════════════════════════
          // RESPONSE TIME TREND CHART
          // ═══════════════════════════════════════════════════════════════════
          _SectionHeader(title: 'Response time trend'),
          const SizedBox(height: AppSpacing.xs),
          const _ResponseTimeChart(),

          const SizedBox(height: AppSpacing.lg),

          // ═══════════════════════════════════════════════════════════════════
          // ENGAGEMENT METRICS
          // ═══════════════════════════════════════════════════════════════════
          _SectionHeader(title: 'Engagement overview'),
          const SizedBox(height: AppSpacing.xs),
          const _EngagementMetricsRow(),

          const SizedBox(height: AppSpacing.lg),

          // ═══════════════════════════════════════════════════════════════════
          // CONSISTENCY CHART
          // ═══════════════════════════════════════════════════════════════════
          _SectionHeader(title: 'Consistency across sessions'),
          const SizedBox(height: AppSpacing.xs),
          const _ConsistencyBarChart(),

          const SizedBox(height: AppSpacing.lg),

          // ═══════════════════════════════════════════════════════════════════
          // TREND SUMMARY
          // ═══════════════════════════════════════════════════════════════════
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withOpacity(0.08),
                  AppColors.primary.withOpacity(0.03),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.insights,
                      size: 20,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Overall trend',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Attention appears consistent across sessions. '
                  'The learner shows good initial engagement with activities '
                  'and maintains focus well throughout short tasks.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),

          // Session History Header
          _SectionHeader(title: 'Session details'),
          const SizedBox(height: AppSpacing.sm),

          // Session Cards
          ...mockSessions.map((session) => _SessionCard(session: session)),

          const SizedBox(height: AppSpacing.lg),

          // Disclaimer
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.border.withOpacity(0.3),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(height: 8),
                Text(
                  'These are observational insights, not diagnoses. '
                  'Patterns may vary based on mood, environment, and time of day. '
                  'Consult qualified professionals for any concerns.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.md),

          // Demo Notice
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Demo data — Complete activities to see real observations',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.accent,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SECTION HEADER
// ═══════════════════════════════════════════════════════════════════════════════

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// RESPONSE TIME LINE CHART
// ═══════════════════════════════════════════════════════════════════════════════

class _ResponseTimeChart extends StatelessWidget {
  const _ResponseTimeChart();

  @override
  Widget build(BuildContext context) {
    // Mock response time data (in ms) over 10 taps across 2 sessions
    final session1Data = [420.0, 380.0, 350.0, 340.0, 360.0, 350.0, 345.0, 340.0, 355.0, 350.0];
    final session2Data = [380.0, 320.0, 310.0, 330.0, 350.0, 370.0, 390.0, 400.0, 410.0, 420.0];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Legend
            Row(
              children: [
                _LegendItem(color: AppColors.primary, label: 'Today'),
                const SizedBox(width: 16),
                _LegendItem(color: AppColors.accent, label: 'Yesterday'),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 100,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.border.withOpacity(0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 2,
                        getTitlesWidget: (value, meta) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Tap ${value.toInt() + 1}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 45,
                        interval: 100,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}ms',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: 0,
                  maxX: 9,
                  minY: 250,
                  maxY: 500,
                  lineBarsData: [
                    // Session 1 (Today)
                    LineChartBarData(
                      spots: session1Data.asMap().entries.map((e) =>
                        FlSpot(e.key.toDouble(), e.value)
                      ).toList(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                    // Session 2 (Yesterday)
                    LineChartBarData(
                      spots: session2Data.asMap().entries.map((e) =>
                        FlSpot(e.key.toDouble(), e.value)
                      ).toList(),
                      isCurved: true,
                      color: AppColors.accent,
                      barWidth: 3,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.accent.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Lower response times indicate quicker reactions. Today\'s session shows more consistent timing.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 3,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ENGAGEMENT METRICS ROW
// ═══════════════════════════════════════════════════════════════════════════════

class _EngagementMetricsRow extends StatelessWidget {
  const _EngagementMetricsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(
            label: 'Avg. Response',
            value: '352ms',
            icon: Icons.speed,
            trend: TrendDirection.stable,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Consistency',
            value: '87%',
            icon: Icons.balance,
            trend: TrendDirection.up,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetricCard(
            label: 'Completion',
            value: '100%',
            icon: Icons.check_circle_outline,
            trend: TrendDirection.stable,
          ),
        ),
      ],
    );
  }
}

enum TrendDirection { up, down, stable }

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final TrendDirection trend;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.trend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    IconData trendIcon;
    Color trendColor;
    switch (trend) {
      case TrendDirection.up:
        trendIcon = Icons.trending_up;
        trendColor = AppColors.primary;
        break;
      case TrendDirection.down:
        trendIcon = Icons.trending_down;
        trendColor = AppColors.accent;
        break;
      case TrendDirection.stable:
        trendIcon = Icons.trending_flat;
        trendColor = AppColors.textSecondary;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, size: 18, color: AppColors.textSecondary),
                Icon(trendIcon, size: 14, color: trendColor),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONSISTENCY BAR CHART
// ═══════════════════════════════════════════════════════════════════════════════

class _ConsistencyBarChart extends StatelessWidget {
  const _ConsistencyBarChart();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 150,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (_) => AppColors.textPrimary,
                      tooltipPadding: const EdgeInsets.all(8),
                      tooltipMargin: 8,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        final labels = ['Focus', 'Speed', 'Steadiness'];
                        return BarTooltipItem(
                          '${labels[groupIndex]}\n${rod.toY.toInt()}%',
                          const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final labels = ['Focus', 'Speed', 'Steadiness'];
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              labels[value.toInt()],
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          );
                        },
                        reservedSize: 30,
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 35,
                        interval: 25,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.textSecondary,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 25,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: AppColors.border.withOpacity(0.5),
                      strokeWidth: 1,
                    ),
                  ),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: 85,
                          color: AppColors.primary,
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: 78,
                          color: AppColors.primary.withOpacity(0.7),
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 2,
                      barRods: [
                        BarChartRodData(
                          toY: 92,
                          color: AppColors.primary.withOpacity(0.85),
                          width: 24,
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Scores based on variability in responses. Higher is more consistent.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════════════════

class _MockSession {
  final String date;
  final String activity;
  final List<_MockPattern> patterns;

  _MockSession({
    required this.date,
    required this.activity,
    required this.patterns,
  });
}

class _MockPattern {
  final String name;
  final String confidence;
  final IconData icon;
  final String description;
  final String support;

  _MockPattern({
    required this.name,
    required this.confidence,
    required this.icon,
    required this.description,
    required this.support,
  });
}

// ═══════════════════════════════════════════════════════════════════════════════
// SESSION CARD
// ═══════════════════════════════════════════════════════════════════════════════

class _SessionCard extends StatelessWidget {
  final _MockSession session;

  const _SessionCard({required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Session header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.touch_app_outlined,
                      size: 16,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      session.activity,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Text(
                  session.date,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),

            const SizedBox(height: AppSpacing.sm),
            const Divider(height: 1),
            const SizedBox(height: AppSpacing.sm),

            // Patterns
            ...session.patterns.map((pattern) => _PatternTile(pattern: pattern)),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// PATTERN TILE (EXPANDABLE)
// ═══════════════════════════════════════════════════════════════════════════════

class _PatternTile extends StatefulWidget {
  final _MockPattern pattern;

  const _PatternTile({required this.pattern});

  @override
  State<_PatternTile> createState() => _PatternTileState();
}

class _PatternTileState extends State<_PatternTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pattern = widget.pattern;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row
              Row(
                children: [
                  Icon(
                    pattern.icon,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      pattern.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  _ConfidenceBadge(confidence: pattern.confidence),
                  const SizedBox(width: 8),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),

              // Expanded content
              if (_expanded) ...[
                const SizedBox(height: 12),
                Text(
                  pattern.description,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          pattern.support,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// CONFIDENCE BADGE
// ═══════════════════════════════════════════════════════════════════════════════

class _ConfidenceBadge extends StatelessWidget {
  final String confidence;

  const _ConfidenceBadge({required this.confidence});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Color color;
    switch (confidence) {
      case 'high':
        color = AppColors.primary;
        break;
      case 'moderate':
        color = AppColors.textSecondary;
        break;
      default:
        color = AppColors.border;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        confidence,
        style: theme.textTheme.bodySmall?.copyWith(
          color: color,
          fontSize: 11,
        ),
      ),
    );
  }
}
