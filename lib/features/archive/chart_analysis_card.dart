import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:pupu/features/archive/chart_analysis_logic.dart';
import 'package:pupu/features/archive/logs_day_utils.dart';
import 'package:pupu/features/archive/status_scoring.dart';
import 'package:pupu/models/bowel_record.dart';

class ChartAnalysisCard extends StatefulWidget {
  final List<BowelRecord> records;

  const ChartAnalysisCard({super.key, required this.records});

  @override
  State<ChartAnalysisCard> createState() => _ChartAnalysisCardState();
}

class _ChartAnalysisCardState extends State<ChartAnalysisCard> {
  static const double _fixedHeaderHeight = 72;
  bool _chart1Past7Days = true;
  bool _pinTopRangeSelector = false;
  int _statusDistributionWindowOffset = 0;
  int _statusTrendsWindowOffset = 0;
  int _issueWindowOffset = 0;
  int? _selectedTrendIndex;
  late final ScrollController _contentScrollController;
  late final ScrollController _statusTrendScrollController;
  late final ScrollController _issueTrendScrollController;
  bool _pendingStatusTrendScrollToEnd = false;
  bool _pendingIssueTrendScrollToEnd = false;

  static const Color _physicalColor = Color(0xFFFEBE2E);
  static const Color _psychologicalColor = Color(0xFF18C0E8);
  static const Color _externalColor = Color(0xFFC73AED);

  List<BowelRecord> get _effectiveRecords => widget.records;

  @override
  void initState() {
    super.initState();
    _contentScrollController = ScrollController();
    _contentScrollController.addListener(_handleContentScroll);
    _statusTrendScrollController = ScrollController();
    _issueTrendScrollController = ScrollController();
  }

  @override
  void dispose() {
    _contentScrollController.removeListener(_handleContentScroll);
    _contentScrollController.dispose();
    _statusTrendScrollController.dispose();
    _issueTrendScrollController.dispose();
    super.dispose();
  }

  void _handleContentScroll() {
    if (!_contentScrollController.hasClients) return;
    final shouldPin = _contentScrollController.offset > 8;
    if (shouldPin != _pinTopRangeSelector) {
      setState(() => _pinTopRangeSelector = shouldPin);
    }
  }

  void _scheduleScrollToRight(ScrollController controller) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !controller.hasClients) return;
      controller.jumpTo(controller.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 326,
      height: 620,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33000000),
                  blurRadius: 0,
                  offset: Offset(0, 4),
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: const Alignment(0, 0.1),
                        colors: [
                          Colors.white.withValues(alpha: 0.25),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned.fill(
                  top: _fixedHeaderHeight,
                  child: SingleChildScrollView(
                    controller: _contentScrollController,
                    padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!_pinTopRangeSelector) ...[
                          Transform.translate(
                            offset: const Offset(0, -4),
                            child: _buildTimeRangeSelector(
                              isPast7Days: _chart1Past7Days,
                              onChanged: (value) {
                                setState(() {
                                  _chart1Past7Days = value;
                                  _statusDistributionWindowOffset = 0;
                                  _statusTrendsWindowOffset = 0;
                                  _issueWindowOffset = 0;
                                  _selectedTrendIndex = null;
                                });
                                if (!value) {
                                  _pendingStatusTrendScrollToEnd = true;
                                  _pendingIssueTrendScrollToEnd = true;
                                }
                              },
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        _buildDividerLine(),
                        const SizedBox(height: 14),
                        const Text(
                          'Bowel Movement Stats',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Color(0xFF0088FF),
                            fontSize: 21,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 18),
                        _buildDividerLine(),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Overall Status Distribution',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildWindowNavigator(
                          window: _resolveWindow(
                            records: _effectiveRecords,
                            days: _chart1Past7Days ? 7 : 30,
                            offsetDays: _statusDistributionWindowOffset,
                          ),
                          onCalendarTap: () => _showHeatmapDialog(
                            context: context,
                            days: _chart1Past7Days ? 7 : 30,
                            initialOffset: _statusDistributionWindowOffset,
                            mode: _HeatmapDialogMode.statusDistribution,
                          ),
                          onPrevious: () {
                            final days = _chart1Past7Days ? 7 : 30;
                            final window = _resolveWindow(
                              records: _effectiveRecords,
                              days: days,
                              offsetDays: _statusDistributionWindowOffset,
                            );
                            if (!window.canGoOlder) return;
                            setState(() {
                              _statusDistributionWindowOffset += days;
                            });
                          },
                          onNext: () {
                            if (_statusDistributionWindowOffset <= 0) return;
                            final days = _chart1Past7Days ? 7 : 30;
                            setState(() {
                              _statusDistributionWindowOffset = math.max(
                                  0, _statusDistributionWindowOffset - days);
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildOptionalChartDataNotice(
                          _distributionNotice(
                            days: _chart1Past7Days ? 7 : 30,
                            offsetDays: _statusDistributionWindowOffset,
                          ),
                        ),
                        _buildChartGlassShell(
                          child: _buildStatusDistributionChart(
                            days: _chart1Past7Days ? 7 : 30,
                            offsetDays: _statusDistributionWindowOffset,
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildDividerLine(),
                        const SizedBox(height: 16),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Status Trends',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildWindowNavigator(
                          window: _resolveWindow(
                            records: _effectiveRecords,
                            days: _chart1Past7Days ? 7 : 30,
                            offsetDays: _statusTrendsWindowOffset,
                          ),
                          onPrevious: () {
                            final days = _chart1Past7Days ? 7 : 30;
                            final window = _resolveWindow(
                              records: _effectiveRecords,
                              days: days,
                              offsetDays: _statusTrendsWindowOffset,
                            );
                            if (!window.canGoOlder) return;
                            setState(() {
                              _statusTrendsWindowOffset += days;
                              _selectedTrendIndex = null;
                            });
                            if (days == 30) {
                              _pendingStatusTrendScrollToEnd = true;
                            }
                          },
                          onNext: () {
                            if (_statusTrendsWindowOffset <= 0) return;
                            final days = _chart1Past7Days ? 7 : 30;
                            setState(() {
                              _statusTrendsWindowOffset =
                                  math.max(0, _statusTrendsWindowOffset - days);
                              _selectedTrendIndex = null;
                            });
                            if (days == 30) {
                              _pendingStatusTrendScrollToEnd = true;
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                        _buildOptionalChartDataNotice(
                          _trendsNotice(
                            days: _chart1Past7Days ? 7 : 30,
                            offsetDays: _statusTrendsWindowOffset,
                          ),
                        ),
                        _buildStatusTrendsChart(),
                        const SizedBox(height: 32),
                        _buildDividerLine(),
                        const SizedBox(height: 20),
                        const Text(
                          'Bowel Issue Breakdown',
                          style: TextStyle(
                            color: Color(0xFF0088FF),
                            fontSize: 21,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildDividerLine(),
                        const SizedBox(height: 16),
                        _buildIssueBreakdownSection(records: _effectiveRecords),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
                _buildPinnedHeader(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDividerLine() {
    return Container(
      width: double.infinity,
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            Color.lerp(
              Colors.black.withValues(alpha: 0.2),
              Colors.white.withValues(alpha: 0.66),
              0.5,
            )!,
            Colors.transparent,
          ],
        ),
      ),
    );
  }

  Widget _buildPinnedHeader() {
    return Positioned(
      left: 20,
      right: 20,
      top: 0,
      height: _fixedHeaderHeight,
      child: Center(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: _pinTopRangeSelector
              ? Center(
                  key: const ValueKey('pinned-range-only'),
                  child: _buildTimeRangeSelector(
                    isPast7Days: _chart1Past7Days,
                    compact: true,
                    onChanged: (value) {
                      setState(() {
                        _chart1Past7Days = value;
                        _statusDistributionWindowOffset = 0;
                        _statusTrendsWindowOffset = 0;
                        _issueWindowOffset = 0;
                        _selectedTrendIndex = null;
                      });
                      if (!value) {
                        _pendingStatusTrendScrollToEnd = true;
                        _pendingIssueTrendScrollToEnd = true;
                      }
                    },
                  ),
                )
              : const Center(
                  key: ValueKey('pinned-title-only'),
                  child: Text(
                    'Chart Analysis',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector({
    required bool isPast7Days,
    required ValueChanged<bool> onChanged,
    bool compact = false,
  }) {
    return Container(
      width: compact ? 172 : 280,
      height: compact ? 24 : 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(true),
              child: Container(
                decoration: BoxDecoration(
                  color: isPast7Days
                      ? const Color(0xFF0088FF)
                      : const Color(0xFF0088FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(50),
                ),
                alignment: Alignment.center,
                child: Text(
                  compact ? '7 days' : 'Past 7 days',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 11 : 15,
                    fontFamily: 'SF Pro',
                    fontWeight: isPast7Days ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: compact ? 0.5 : 1,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(false),
              child: Container(
                decoration: BoxDecoration(
                  color: !isPast7Days
                      ? const Color(0xFF0088FF)
                      : const Color(0xFF0088FF).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(50),
                ),
                alignment: Alignment.center,
                child: Text(
                  compact ? '30 days' : 'Past 30 days',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 11 : 15,
                    fontFamily: 'SF Pro',
                    fontWeight:
                        !isPast7Days ? FontWeight.w600 : FontWeight.w400,
                    letterSpacing: compact ? 0.5 : 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWindowNavigator({
    required _DateWindow window,
    required VoidCallback onPrevious,
    required VoidCallback onNext,
    VoidCallback? onCalendarTap,
  }) {
    Color arrowColor(bool enabled) =>
        Colors.white.withValues(alpha: enabled ? 0.9 : 0.32);

    return Row(
      children: [
        Expanded(
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: window.canGoOlder ? onPrevious : null,
                  icon: Icon(Icons.chevron_left,
                      color: arrowColor(window.canGoOlder)),
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                ),
                const SizedBox(width: 4),
                Text(
                  window.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: window.canGoNewer ? onNext : null,
                  icon: Icon(Icons.chevron_right,
                      color: arrowColor(window.canGoNewer)),
                  splashRadius: 16,
                  padding: EdgeInsets.zero,
                  constraints:
                      const BoxConstraints.tightFor(width: 28, height: 28),
                ),
              ],
            ),
          ),
        ),
        if (onCalendarTap != null)
          GestureDetector(
            onTap: onCalendarTap,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(
                Icons.grid_on,
                size: 15,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildChartGlassShell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      child: child,
    );
  }

  /// Shared copy for sparse or empty chart windows across Chart Analysis sections.
  Widget? _buildChartDataNotice(_ChartDataNoticeKind kind) {
    final String message;
    switch (kind) {
      case _ChartDataNoticeKind.empty:
        message = 'No questionnaire data in this period.';
      case _ChartDataNoticeKind.limited:
        message =
            'Limited data (fewer than 3 days with records). Insights may be less reliable.';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          message,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 12,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w400,
            height: 1.3,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionalChartDataNotice(_ChartDataNoticeKind? kind) {
    if (kind == null) return const SizedBox.shrink();
    return _buildChartDataNotice(kind)!;
  }

  _ChartDataNoticeKind? _distributionNotice({
    required int days,
    required int offsetDays,
  }) {
    final distribution = computeStatusDistributionSession(
      records: _effectiveRecords,
      days: days,
      offsetDays: offsetDays,
    );
    final total = distribution.values.fold<int>(0, (sum, value) => sum + value);
    return total == 0 ? _ChartDataNoticeKind.empty : null;
  }

  _ChartDataNoticeKind? _trendsNotice({
    required int days,
    required int offsetDays,
  }) {
    final trend = computeTrendSeries(
      records: _effectiveRecords,
      days: days,
      offsetDays: offsetDays,
    );
    return trend.points.isEmpty ? _ChartDataNoticeKind.empty : null;
  }

  _ChartDataNoticeKind? _issueBreakdownNotice(_IssuePeriodData data) {
    if (data.validRecords == 0) return _ChartDataNoticeKind.empty;
    if (data.hasLimitedData) return _ChartDataNoticeKind.limited;
    return null;
  }

  Widget _buildStatusDistributionChart({
    required int days,
    required int offsetDays,
  }) {
    final distribution = computeStatusDistributionSession(
      records: _effectiveRecords,
      days: days,
      offsetDays: offsetDays,
    );
    final total = distribution.values.fold<int>(0, (sum, value) => sum + value);
    final ratios = [
      total == 0 ? 0.0 : (distribution[StatusLabel.ideal]! / total),
      total == 0 ? 0.0 : (distribution[StatusLabel.dryHard]! / total),
      total == 0 ? 0.0 : (distribution[StatusLabel.incompleteNotSmooth]! / total),
      total == 0 ? 0.0 : (distribution[StatusLabel.softUrgent]! / total),
      total == 0 ? 0.0 : (distribution[StatusLabel.unsuccessful]! / total),
    ];
    final percents = formatDistributionPercents(ratios);

    final categories = [
      (
        'Ideal',
        const Color(0xFF27C840),
        ratios[0],
        percents[0],
      ),
      (
        'Dry / Hard',
        const Color(0xFFFEBC2F),
        ratios[1],
        percents[1],
      ),
      (
        'Incomplete / Not Smooth',
        const Color(0xFFFF8D28),
        ratios[2],
        percents[2],
      ),
      (
        'Soft / Urgent',
        const Color(0xFF00C0E8),
        ratios[3],
        percents[3],
      ),
      (
        'Unsuccessful',
        const Color(0xFFCB30E0),
        ratios[4],
        percents[4],
      ),
    ];

    return Column(
      children: categories.map((item) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: item.$2,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 90,
                child: Text(
                  item.$1,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w400,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 15,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D9D9),
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: FractionallySizedBox(
                    alignment: Alignment.centerLeft,
                    widthFactor: item.$3,
                    child: Container(
                      decoration: BoxDecoration(
                        color: item.$2,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 34,
                child: Text(
                  '${item.$4}%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatusTrendsChart() {
    final days = _chart1Past7Days ? 7 : 30;
    final trendData = computeTrendSeries(
      records: _effectiveRecords,
      days: days,
      offsetDays: _statusTrendsWindowOffset,
    );
    final trend = _TrendSeriesData(
      points: trendData.points
          .map(
            (p) => _TrendPoint(
              dayIndex: p.dayIndex,
              label: p.label,
              score: p.score,
              breakdown: p.breakdown,
            ),
          )
          .toList(),
      labels: trendData.labels,
      totalDays: trendData.totalDays,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24, width: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          SizedBox(
            height: 170,
            width: double.infinity,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final viewportWidth = constraints.maxWidth;
                final canvasWidth = days == 30
                    ? math.max(viewportWidth, 760).toDouble()
                    : viewportWidth;
                final chartWidth = canvasWidth -
                    _TrendsChartPainter.leftPadding -
                    _TrendsChartPainter.rightPadding;
                final dayDivisor =
                    trend.totalDays > 1 ? (trend.totalDays - 1) : 1;

                double pointX(int dayIndex) =>
                    _TrendsChartPainter.leftPadding +
                    chartWidth * (dayIndex / dayDivisor);
                double pointY(double score) {
                  const top = _TrendsChartPainter.topPadding;
                  const bottom = 170 - _TrendsChartPainter.bottomPadding;
                  const height = bottom - top;
                  return bottom - height * (score.clamp(0.0, 100.0) / 100);
                }

                bool isInsidePlotArea(Offset p) {
                  return p.dx >= _TrendsChartPainter.leftPadding &&
                      p.dx <= canvasWidth - _TrendsChartPainter.rightPadding &&
                      p.dy >= _TrendsChartPainter.topPadding &&
                      p.dy <= 170 - _TrendsChartPainter.bottomPadding;
                }

                final hasSelected = _selectedTrendIndex != null &&
                    _selectedTrendIndex! >= 0 &&
                    _selectedTrendIndex! < trend.points.length;
                final selected =
                    hasSelected ? trend.points[_selectedTrendIndex!] : null;

                final chartContent = SizedBox(
                  width: canvasWidth,
                  height: 170,
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onTapDown: (details) {
                      if (trend.points.isEmpty || chartWidth <= 0) {
                        if (_selectedTrendIndex != null &&
                            isInsidePlotArea(details.localPosition)) {
                          setState(() => _selectedTrendIndex = null);
                        }
                        return;
                      }

                      final tap = details.localPosition;
                      double bestDist = double.infinity;
                      int best = -1;
                      for (int i = 0; i < trend.points.length; i++) {
                        final dx = pointX(trend.points[i].dayIndex);
                        final dy = pointY(trend.points[i].score);
                        final dist = (Offset(dx, dy) - tap).distance;
                        if (dist < bestDist) {
                          bestDist = dist;
                          best = i;
                        }
                      }

                      // Only near-point taps are valid for selecting/opening.
                      if (best >= 0 && bestDist <= 9) {
                        setState(() => _selectedTrendIndex = best);
                      } else if (_selectedTrendIndex != null &&
                          isInsidePlotArea(tap)) {
                        // Tap anywhere on non-blank plot area to collapse info.
                        setState(() => _selectedTrendIndex = null);
                      }
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            size: Size(canvasWidth, 170),
                            painter: _TrendsChartPainter(
                              scores: trend.points,
                              labels: trend.labels,
                              totalDays: trend.totalDays,
                              selectedIndex: _selectedTrendIndex,
                            ),
                          ),
                        ),
                        if (selected != null)
                          _buildTrendPopup(
                            selected,
                            pointX(selected.dayIndex),
                            pointY(selected.score),
                            canvasWidth,
                          ),
                      ],
                    ),
                  ),
                );

                if (days == 30) {
                  if (_pendingStatusTrendScrollToEnd) {
                    _pendingStatusTrendScrollToEnd = false;
                    _scheduleScrollToRight(_statusTrendScrollController);
                  }
                  return SingleChildScrollView(
                    controller: _statusTrendScrollController,
                    scrollDirection: Axis.horizontal,
                    child: chartContent,
                  );
                }
                return chartContent;
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrendPopup(
    _TrendPoint point,
    double pointX,
    double pointY,
    double fullWidth,
  ) {
    String f(double v) => v.toStringAsFixed(1);
    const popupWidth = 180.0;
    const popupHeight = 96.0;
    final left = math.max(
        0.0, math.min(pointX - popupWidth / 2, fullWidth - popupWidth));
    final top = math.max(2.0, pointY - popupHeight - 10);

    return Positioned(
      left: left,
      top: top,
      child: Container(
        width: popupWidth,
        height: popupHeight,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Colors.white.withValues(alpha: 0.30), width: 0.7),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
            height: 1.2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Date: ${point.label}   Total: ${f(point.score)}'),
              const SizedBox(height: 3),
              Text('Result (20%): ${f(point.breakdown.resultWeighted)}'),
              Text('Straining (15%): ${f(point.breakdown.strainingWeighted)}'),
              Text(
                  'Evacuation (20%): ${f(point.breakdown.evacuationWeighted)}'),
              Text(
                  'Consistency (20%): ${f(point.breakdown.consistencyWeighted)}'),
              Text(
                  'Pain & Discomfort (25%): ${f(point.breakdown.painDiscomfortWeighted)}'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showHeatmapDialog({
    required BuildContext context,
    required int days,
    required int initialOffset,
    required _HeatmapDialogMode mode,
  }) async {
    var localOffset = initialOffset;
    DateTime? selectedDay;
    final columns = days == 7 ? 7 : 6;

    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final resolvedWindow = resolveChartWindow(
              records: _effectiveRecords,
              days: days,
              offsetDays: localOffset,
            );
            localOffset = resolvedWindow.offsetDays;
            final window = _DateWindow(
              days: resolvedWindow.days,
              offsetDays: resolvedWindow.offsetDays,
              title: resolvedWindow.title,
              canGoOlder: resolvedWindow.canGoOlder,
              canGoNewer: resolvedWindow.canGoNewer,
            );
            final cells = _buildHeatmapCells(
              records: _effectiveRecords,
              days: days,
              offsetDays: localOffset,
              mode: mode,
            );
            final isStatusGrid = mode == _HeatmapDialogMode.statusDistribution;
            _HeatmapCell? selectedCell;
            var selectedIndex = -1;
            if (selectedDay != null) {
              selectedIndex = cells.indexWhere(
                (cell) =>
                    cell.day.year == selectedDay!.year &&
                    cell.day.month == selectedDay!.month &&
                    cell.day.day == selectedDay!.day,
              );
              if (selectedIndex >= 0) {
                selectedCell = cells[selectedIndex];
              }
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (selectedDay == null) return;
                  setDialogState(() => selectedDay = null);
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.72,
                      ),
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.20),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24, width: 0.6),
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isStatusGrid ? 'Status Grid' : 'Bowel Issue Grid',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 8),
                            _buildWindowNavigator(
                              window: window,
                              onPrevious: () {
                                if (!window.canGoOlder) return;
                                setDialogState(() {
                                  localOffset += days;
                                  selectedDay = null;
                                });
                              },
                              onNext: () {
                                if (localOffset <= 0) return;
                                setDialogState(() {
                                  localOffset = math.max(0, localOffset - days);
                                  selectedDay = null;
                                });
                              },
                            ),
                            const SizedBox(height: 12),
                            LayoutBuilder(
                              builder: (context, constraints) {
                                final bubbleEnabled = isStatusGrid && selectedCell != null;
                                const bubbleMaxHeight = 132.0;
                                final gridWidth = constraints.maxWidth;
                                final cellWidth = gridWidth / columns;
                                final cellHeight = cellWidth / 0.9;
                                final rowCount = (cells.length / columns).ceil();
                                final gridHeight = rowCount * cellHeight;
                                final bubbleTop = selectedIndex >= 0
                                    ? (((selectedIndex ~/ columns) * cellHeight) + 24)
                                    : 0.0;
                                final bubbleCenter = selectedIndex >= 0
                                    ? ((selectedIndex % columns) * cellWidth) + (cellWidth / 2)
                                    : 0.0;
                                final bubbleWidth = math.min(248.0, gridWidth - 8);
                                final bubbleLeft = bubbleEnabled
                                    ? (bubbleCenter - (bubbleWidth / 2))
                                        .clamp(4.0, gridWidth - bubbleWidth - 4)
                                        .toDouble()
                                    : 0.0;
                                final bubbleHeight = bubbleEnabled
                                  ? math.max(0.0, bubbleTop + bubbleMaxHeight - gridHeight)
                                  : 0.0;

                                return SizedBox(
                                  height: gridHeight + bubbleHeight,
                                  child: Stack(
                                    clipBehavior: Clip.none,
                                    children: [
                                      GridView.builder(
                                        shrinkWrap: true,
                                        physics: const NeverScrollableScrollPhysics(),
                                        itemCount: cells.length,
                                        gridDelegate:
                                            SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: columns,
                                          mainAxisSpacing: 0,
                                          crossAxisSpacing: 0,
                                          childAspectRatio: 0.9,
                                        ),
                                        itemBuilder: (context, index) {
                                          final cell = cells[index];
                                          final day = cell.day;
                                          final label = DateFormat('d').format(day);
                                          final isSelected = selectedDay != null &&
                                              day.year == selectedDay!.year &&
                                              day.month == selectedDay!.month &&
                                              day.day == selectedDay!.day;

                                          return Column(
                                            mainAxisAlignment: MainAxisAlignment.start,
                                            children: [
                                              GestureDetector(
                                                onTap: () {
                                                  if (isStatusGrid) {
                                                    setDialogState(() {
                                                      if (isSelected) {
                                                        selectedDay = null;
                                                      } else {
                                                        selectedDay = day;
                                                      }
                                                    });
                                                  } else {
                                                    // For Issue Grid, show popup dialog
                                                    _showIssueRecordBreakdownDialog(
                                                      context: context,
                                                      cell: cell,
                                                    );
                                                  }
                                                },
                                                behavior: HitTestBehavior.opaque,
                                                child: Container(
                                                  width: 24,
                                                  height: 24,
                                                  decoration: BoxDecoration(
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: isSelected
                                                        ? Border.all(
                                                            color: Colors.white
                                                                .withValues(alpha: 0.85),
                                                            width: 1,
                                                          )
                                                        : null,
                                                  ),
                                                  padding: isSelected
                                                      ? const EdgeInsets.all(1)
                                                      : EdgeInsets.zero,
                                                  child: ClipRRect(
                                                    borderRadius: BorderRadius.circular(6),
                                                    child: isStatusGrid
                                                        ? (cell.statusEntries.isNotEmpty
                                                            ? _buildStatusGridCell(cell)
                                                            : Container(
                                                                color: Colors.white.withValues(
                                                                  alpha: (0.14 +
                                                                          (cell.recordCount
                                                                                  .clamp(0, 4) *
                                                                              0.10))
                                                                      .clamp(0.14, 0.52)
                                                                      .toDouble(),
                                                                ),
                                                              ))
                                                        : _buildIssueGridCell(cell),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                label,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: Colors.white.withValues(alpha: 0.82),
                                                  fontSize: 9,
                                                  fontFamily: 'SF Pro',
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                      if (bubbleEnabled)
                                        Positioned(
                                          left: bubbleLeft,
                                          top: bubbleTop,
                                          child: _buildStatusGridBubble(
                                            cell: selectedCell,
                                            width: bubbleWidth,
                                            anchorX: bubbleCenter - bubbleLeft,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            if (isStatusGrid) ...[
                              const SizedBox(height: 10),
                              _buildStatusGridLegend(),
                            ] else ...[
                              const SizedBox(height: 10),
                              _buildIssueGridLegend(),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  List<_HeatmapCell> _buildHeatmapCells({
    required List<BowelRecord> records,
    required int days,
    required int offsetDays,
    required _HeatmapDialogMode mode,
  }) {
    final latest = _latestRecordDay(records);
    final end = latest.subtract(Duration(days: offsetDays));
    final start = end.subtract(Duration(days: days - 1));

    final counter = <DateTime, int>{};
    final statusEntries = <DateTime, List<_StatusGridEntry>>{};
    for (final r in records) {
      final day = normalizeDay(r.dateTime);
      if (day.isBefore(start) || day.isAfter(end)) continue;
      counter[day] = (counter[day] ?? 0) + 1;

      if (mode == _HeatmapDialogMode.statusDistribution) {
        final score = StatusScoring.scoreRecord(r);
        final resolved = StatusScoring.resolveDistributionLabel(score);
        if (score == null || resolved == null) continue;
        statusEntries.putIfAbsent(day, () => <_StatusGridEntry>[]).add(
              _StatusGridEntry(
                record: r,
                primaryLabels: score.primaryLabels,
                secondaryLabels: score.secondaryLabels,
              ),
            );
      }
    }

    return List<_HeatmapCell>.generate(days, (i) {
      final day = start.add(Duration(days: i));
      final dayEntries = statusEntries[day] ?? const <_StatusGridEntry>[];
      final shares = <_HeatmapStatusShare>[];
      double physicalPct = 0.0, psychologicalPct = 0.0, externalPct = 0.0;
      final issueBreakdowns = <_IssueRecordBreakdown>[];
      
      if (mode == _HeatmapDialogMode.statusDistribution) {
        final map = <StatusLabel, int>{};
        for (final entry in dayEntries) {
          final score = StatusScoring.scoreRecord(entry.record);
          final label = StatusScoring.resolveDistributionLabel(score);
          if (label == null) continue;
          map[label] = (map[label] ?? 0) + 1;
        }
        final mapEntries = map.entries.toList()
          ..sort((a, b) {
            final countCompare = b.value.compareTo(a.value);
            if (countCompare != 0) return countCompare;
            return _statusOrder(a.key).compareTo(_statusOrder(b.key));
          });
        for (final entry in mapEntries) {
          shares.add(_HeatmapStatusShare(status: entry.key, count: entry.value));
        }
      } else if (mode == _HeatmapDialogMode.generic) {
        // Calculate Issue breakdown percentages for this day
        final windowRecords = records.where((r) {
          final rDay = normalizeDay(r.dateTime);
          return rDay.year == day.year &&
              rDay.month == day.month &&
              rDay.day == day.day;
        }).toList();
        
        if (windowRecords.isNotEmpty) {
          final daily = StatusScoring.computeIssueBreakdownDaily(windowRecords);
          if (daily != null) {
            physicalPct = daily.physicalPercent;
            psychologicalPct = daily.psychologicalPercent;
            externalPct = daily.externalLifestylePercent;
          }
          
          // Calculate per-record Issue breakdowns for popup
          for (int idx = 0; idx < windowRecords.length; idx++) {
            final record = windowRecords[idx];
            final breakdown = StatusScoring.computeIssueBreakdown(record);
            if (breakdown != null) {
              final total = breakdown.physical +
                  breakdown.psychological +
                  breakdown.externalLifestyle;
              issueBreakdowns.add(_IssueRecordBreakdown(
                recordIndex: idx,
                physicalPercent:
                    total == 0 ? 0.0 : (breakdown.physical / total) * 100,
                psychologicalPercent: total == 0
                    ? 0.0
                    : (breakdown.psychological / total) * 100,
                externalPercent: total == 0
                    ? 0.0
                    : (breakdown.externalLifestyle / total) * 100,
              ));
            }
          }
        }
      }
      
      return _HeatmapCell(
        day: day,
        recordCount: counter[day] ?? 0,
        statusShares: shares,
        statusEntries: dayEntries,
        physicalPercent: physicalPct,
        psychologicalPercent: psychologicalPct,
        externalPercent: externalPct,
        issueRecordBreakdowns: issueBreakdowns,
      );
    });
  }

  int _statusOrder(StatusLabel label) {
    switch (label) {
      case StatusLabel.ideal:
        return 0;
      case StatusLabel.dryHard:
        return 1;
      case StatusLabel.incompleteNotSmooth:
        return 2;
      case StatusLabel.softUrgent:
        return 3;
      case StatusLabel.unsuccessful:
        return 4;
    }
  }

  Color _statusColor(StatusLabel label) {
    switch (label) {
      case StatusLabel.ideal:
        return const Color(0xFF27C840);
      case StatusLabel.dryHard:
        return const Color(0xFFFEBC2F);
      case StatusLabel.incompleteNotSmooth:
        return const Color(0xFFFF8D28);
      case StatusLabel.softUrgent:
        return const Color(0xFF00C0E8);
      case StatusLabel.unsuccessful:
        return const Color(0xFFCB30E0);
    }
  }

  Widget _buildStatusGridLegend() {
    return Wrap(
      spacing: 10,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem('Ideal', const Color(0xFF27C840)),
        _buildLegendItem('Dry / Hard', const Color(0xFFFEBC2F)),
        _buildLegendItem('Incomplete / Not Smooth', const Color(0xFFFF8D28)),
        _buildLegendItem('Soft / Urgent', const Color(0xFF00C0E8)),
        _buildLegendItem('Unsuccessful', const Color(0xFFCB30E0)),
      ],
    );
  }

  Widget _buildIssueGridLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        _buildLegendItem('Physiological', _physicalColor),
        _buildLegendItem('Psychological', _psychologicalColor),
        _buildLegendItem('External', _externalColor),
      ],
    );
  }

  Widget _buildStatusGridCell(_HeatmapCell cell) {
    final shares = [...cell.statusShares];
    if (shares.isEmpty) {
      return Container(color: Colors.white.withValues(alpha: 0.18));
    }

    return Row(
      children: shares.map((share) {
        return Expanded(
          flex: share.count,
          child: Container(
            decoration: BoxDecoration(
              color: _shadeStatusColor(_statusColor(share.status), share.count),
              border: Border(
                right: BorderSide(
                  color: Colors.black.withValues(alpha: 0.10),
                  width: 0.35,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Color _shadeStatusColor(Color color, int count) {
    final depth = ((count - 1) * 0.12).clamp(0.0, 0.36);
    return Color.lerp(color, Colors.black, depth) ?? color;
  }

  Widget _buildIssueGridCell(_HeatmapCell cell) {
    // If no data, return the light color
    if (cell.physicalPercent == 0 && cell.psychologicalPercent == 0 && cell.externalPercent == 0) {
      return Container(color: Colors.white.withValues(alpha: 0.18));
    }

    // Build color segments based on percentages
    final segments = <({Color color, double percent})>[];
    
    if (cell.physicalPercent > 0) {
      segments.add((color: _physicalColor, percent: cell.physicalPercent));
    }
    if (cell.psychologicalPercent > 0) {
      segments.add((color: _psychologicalColor, percent: cell.psychologicalPercent));
    }
    if (cell.externalPercent > 0) {
      segments.add((color: _externalColor, percent: cell.externalPercent));
    }

    if (segments.isEmpty) {
      return Container(color: Colors.white.withValues(alpha: 0.18));
    }

    // If only one color, fill entire cell with that color
    if (segments.length == 1) {
      return Container(color: segments[0].color);
    }

    // If two colors, split 50-50
    if (segments.length == 2) {
      return Row(
        children: [
          Expanded(
            flex: 1,
            child: Container(color: segments[0].color),
          ),
          Expanded(
            flex: 1,
            child: Container(color: segments[1].color),
          ),
        ],
      );
    }

    // If three colors, split 33-33-33
    return Row(
      children: segments.map((segment) {
        return Expanded(
          flex: 1,
          child: Container(color: segment.color),
        );
      }).toList(),
    );
  }

  Future<void> _showIssueRecordBreakdownDialog({
    required BuildContext context,
    required _HeatmapCell cell,
  }) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 60),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.72,
                  maxWidth: 280,
                ),
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.20),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white24, width: 0.6),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Text(
                        DateFormat('MMM d, yyyy').format(cell.day),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${cell.issueRecordBreakdowns.length} record${cell.issueRecordBreakdowns.length != 1 ? 's' : ''}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                          fontFamily: 'SF Pro',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Records with bar charts
                      ...List<Widget>.generate(
                        cell.issueRecordBreakdowns.length,
                        (index) {
                          final breakdown = cell.issueRecordBreakdowns[index];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _buildIssueRecordChart(
                              recordIndex: index + 1,
                              breakdown: breakdown,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildIssueRecordChart({
    required int recordIndex,
    required _IssueRecordBreakdown breakdown,
  }) {
    // Values are already in 0-100 range
    final phys = breakdown.physicalPercent;
    final psych = breakdown.psychologicalPercent;
    final external = breakdown.externalPercent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Record $recordIndex:',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        
        // Vertical bar chart
        SizedBox(
          height: 180,
          width: double.infinity,
          child: CustomPaint(
            painter: _VerticalBarChartPainter(
              values: [
                (label: 'Phys', value: phys, color: _physicalColor),
                (label: 'Psych', value: psych, color: _psychologicalColor),
                (label: 'Ext', value: external, color: _externalColor),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusGridBubble({
    required _HeatmapCell cell,
    required double width,
    required double anchorX,
  }) {
    final recordCount = cell.statusEntries.length;
    return GestureDetector(
      onTap: () {},
      child: CustomPaint(
        painter: _BubbleBorderPainter(
          anchorX: anchorX,
          color: Colors.black.withValues(alpha: 0.36),
          width: 0.5,
        ),
        child: ClipPath(
          clipper: _BubbleShapeClipper(anchorX: anchorX),
          child: Container(
            width: width,
            constraints: const BoxConstraints(maxHeight: 132),
            padding: const EdgeInsets.fromLTRB(12, 15, 12, 10),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.32),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Data: ${DateFormat('yyyy-MM-dd').format(cell.day)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '$recordCount record${recordCount == 1 ? '' : 's'}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.74),
                      fontSize: 11,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (recordCount > 0) ...[
                    const SizedBox(height: 6),
                    ...cell.statusEntries.asMap().entries.map((entry) {
                      final index = entry.key + 1;
                      final primary =
                          _formatStatusLabels(entry.value.primaryLabels);
                      final secondary =
                          _formatStatusLabels(entry.value.secondaryLabels);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Overall Status$index: ${primary.isEmpty ? 'N/A' : primary}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontFamily: 'SF Pro',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (secondary.isNotEmpty)
                              Text(
                                'Secondary Status$index: $secondary',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.86),
                                  fontSize: 11,
                                  fontFamily: 'SF Pro',
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _formatStatusLabels(List<StatusLabel> labels) {
    if (labels.isEmpty) return '';
    return labels.map(_statusDisplayName).join(', ');
  }

  String _statusDisplayName(StatusLabel label) {
    switch (label) {
      case StatusLabel.ideal:
        return 'Ideal';
      case StatusLabel.dryHard:
        return 'Dry / Hard';
      case StatusLabel.incompleteNotSmooth:
        return 'Incomplete / Not Smooth';
      case StatusLabel.softUrgent:
        return 'Soft / Urgent';
      case StatusLabel.unsuccessful:
        return 'Unsuccessful';
    }
  }

  DateTime _latestRecordDay(List<BowelRecord> records) {
    return chartToday();
  }

  _DateWindow _resolveWindow({
    required List<BowelRecord> records,
    required int days,
    required int offsetDays,
  }) {
    final window = resolveChartWindow(
      records: records,
      days: days,
      offsetDays: offsetDays,
    );
    return _DateWindow(
      days: window.days,
      offsetDays: window.offsetDays,
      title: window.title,
      canGoOlder: window.canGoOlder,
      canGoNewer: window.canGoNewer,
    );
  }

  int _maxOffsetForDays({
    required List<BowelRecord> records,
    required int days,
  }) {
    return maxChartOffsetDays(records: records, days: days);
  }

  _TrendSeriesData _computeTrendScoreSeries({
    required List<BowelRecord> records,
    required int days,
    int offsetDays = 0,
  }) {
    final trend = computeTrendSeries(
      records: records,
      days: days,
      offsetDays: offsetDays,
    );
    return _TrendSeriesData(
      points: trend.points
          .map(
            (p) => _TrendPoint(
              dayIndex: p.dayIndex,
              label: p.label,
              score: p.score,
              breakdown: p.breakdown,
            ),
          )
          .toList(),
      labels: trend.labels,
      totalDays: trend.totalDays,
    );
  }

  Widget _buildIssueBreakdownSection({required List<BowelRecord> records}) {
    final days = _chart1Past7Days ? 7 : 30;
    final window = _resolveWindow(
      records: records,
      days: days,
      offsetDays: _issueWindowOffset,
    );
    final active = _computeIssuePeriodData(
      records: records,
      days: days,
      offsetDays: window.offsetDays,
    );
    final secondaryTitle = days == 7 ? 'Stacked Bar View' : 'Line View';

    void onPrevious() {
      if (!window.canGoOlder) return;
      setState(() {
        _issueWindowOffset += days;
      });
      if (days == 30) {
        _pendingIssueTrendScrollToEnd = true;
      }
    }

    void onNext() {
      if (_issueWindowOffset <= 0) return;
      setState(() {
        _issueWindowOffset = math.max(0, _issueWindowOffset - days);
      });
      if (days == 30) {
        _pendingIssueTrendScrollToEnd = true;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Radar View',
            style: TextStyle(
              color: Color(0xFFE6E6E6),
              fontSize: 15,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildWindowNavigator(
          window: window,
          onPrevious: onPrevious,
          onNext: onNext,
        ),
        const SizedBox(height: 12),
        _buildOptionalChartDataNotice(_issueBreakdownNotice(active)),
        _buildChartGlassShell(
          child: _buildIssueRadarCard(
            data: active,
          ),
        ),
        const SizedBox(height: 18),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            secondaryTitle,
            style: const TextStyle(
              color: Color(0xFFE6E6E6),
              fontSize: 15,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _buildWindowNavigator(
          window: window,
          onCalendarTap: () => _showHeatmapDialog(
            context: context,
            days: days,
            initialOffset: _issueWindowOffset,
            mode: _HeatmapDialogMode.generic,
          ),
          onPrevious: onPrevious,
          onNext: onNext,
        ),
        const SizedBox(height: 14),
        if (days == 7)
          _buildChartGlassShell(child: _buildIssueStackedBarCard(data: active))
        else
          _buildChartGlassShell(child: _buildIssueLineTrendCard(data: active)),
      ],
    );
  }

  Widget _buildIssueRadarCard({required _IssuePeriodData data}) {
    return SizedBox(
      height: 350,
      child: CustomPaint(
        painter: _IssueRadarPainter(
          physical: data.physicalAveragePercent,
          psychological: data.psychologicalAveragePercent,
          external: data.externalAveragePercent,
          physicalColor: _physicalColor,
          psychologicalColor: _psychologicalColor,
          externalColor: _externalColor,
        ),
      ),
    );
  }

  Widget _buildIssueStackedBarCard({required _IssuePeriodData data}) {
    return SizedBox(
      width: double.infinity,
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: _IssueStackedBarPainter(
                  points: data.points,
                  physicalColor: _physicalColor,
                  psychologicalColor: _psychologicalColor,
                  externalColor: _externalColor,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: _buildIssueChartLegend(),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueLineTrendCard({required _IssuePeriodData data}) {
    final canvasWidth = math.max(720, data.points.length * 28).toDouble();
    if (_pendingIssueTrendScrollToEnd) {
      _pendingIssueTrendScrollToEnd = false;
      _scheduleScrollToRight(_issueTrendScrollController);
    }
    return SizedBox(
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
              controller: _issueTrendScrollController,
              scrollDirection: Axis.horizontal,
              child: SizedBox(
                width: canvasWidth,
                height: 220,
                child: CustomPaint(
                  painter: _IssueLineTrendPainter(
                    points: data.points,
                    physicalColor: _physicalColor,
                    psychologicalColor: _psychologicalColor,
                    externalColor: _externalColor,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.center,
            child: _buildIssueChartLegend(),
          ),
        ],
      ),
    );
  }

  Widget _buildIssueChartLegend() {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _buildLegendItem('Physiological', _physicalColor),
        _buildLegendItem('Psychological', _psychologicalColor),
        _buildLegendItem('External', _externalColor),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendDot(color),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 13,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w400,
            )),
      ],
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 10,
      height: 10,
      decoration:
          BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
    );
  }

  _IssuePeriodData _computeIssuePeriodData({
    required List<BowelRecord> records,
    required int days,
    int offsetDays = 0,
  }) {
    final data = computeChartIssuePeriodData(
      records: records,
      days: days,
      offsetDays: offsetDays,
    );
    return _IssuePeriodData(
      days: data.days,
      points: data.points
          .map(
            (p) => _IssuePercentPoint(
              label: p.label,
              physicalPercent: p.physicalPercent,
              psychologicalPercent: p.psychologicalPercent,
              externalPercent: p.externalPercent,
              hasData: p.hasData,
            ),
          )
          .toList(),
      validRecords: data.validRecords,
      daysWithRecords: data.daysWithRecords,
      physicalAveragePercent: data.physicalAveragePercent,
      psychologicalAveragePercent: data.psychologicalAveragePercent,
      externalAveragePercent: data.externalAveragePercent,
    );
  }
}

class _TrendPoint {
  final int dayIndex;
  final String label;
  final double score;
  final TrendScoreBreakdown breakdown;

  const _TrendPoint({
    required this.dayIndex,
    required this.label,
    required this.score,
    required this.breakdown,
  });
}

class _DateWindow {
  final int days;
  final int offsetDays;
  final String title;
  final bool canGoOlder;
  final bool canGoNewer;

  const _DateWindow({
    required this.days,
    required this.offsetDays,
    required this.title,
    required this.canGoOlder,
    required this.canGoNewer,
  });
}

class _TrendSeriesData {
  final List<_TrendPoint> points;
  final List<String> labels;
  final int totalDays;

  const _TrendSeriesData({
    required this.points,
    required this.labels,
    required this.totalDays,
  });
}

class _IssuePercentPoint {
  final String label;
  final double physicalPercent;
  final double psychologicalPercent;
  final double externalPercent;
  final bool hasData;

  const _IssuePercentPoint({
    required this.label,
    required this.physicalPercent,
    required this.psychologicalPercent,
    required this.externalPercent,
    required this.hasData,
  });
}

class _IssuePeriodData {
  final int days;
  final int validRecords;
  final int daysWithRecords;
  final List<_IssuePercentPoint> points;
  final double physicalAveragePercent;
  final double psychologicalAveragePercent;
  final double externalAveragePercent;

  const _IssuePeriodData({
    required this.days,
    required this.validRecords,
    required this.daysWithRecords,
    required this.points,
    required this.physicalAveragePercent,
    required this.psychologicalAveragePercent,
    required this.externalAveragePercent,
  });

  bool get hasLimitedData => daysWithRecords < 3;
}

enum _ChartDataNoticeKind { empty, limited }

enum _HeatmapDialogMode { generic, statusDistribution }

class _IssueRecordBreakdown {
  final int recordIndex;
  final double physicalPercent;
  final double psychologicalPercent;
  final double externalPercent;

  const _IssueRecordBreakdown({
    required this.recordIndex,
    required this.physicalPercent,
    required this.psychologicalPercent,
    required this.externalPercent,
  });
}

class _HeatmapCell {
  final DateTime day;
  final int recordCount;
  final List<_HeatmapStatusShare> statusShares;
  final List<_StatusGridEntry> statusEntries;
  final double physicalPercent;
  final double psychologicalPercent;
  final double externalPercent;
  final List<_IssueRecordBreakdown> issueRecordBreakdowns;

  const _HeatmapCell({
    required this.day,
    required this.recordCount,
    this.statusShares = const [],
    this.statusEntries = const [],
    this.physicalPercent = 0.0,
    this.psychologicalPercent = 0.0,
    this.externalPercent = 0.0,
    this.issueRecordBreakdowns = const [],
  });
}

class _StatusGridEntry {
  final BowelRecord record;
  final List<StatusLabel> primaryLabels;
  final List<StatusLabel> secondaryLabels;

  const _StatusGridEntry({
    required this.record,
    required this.primaryLabels,
    required this.secondaryLabels,
  });
}

class _HeatmapStatusShare {
  final StatusLabel status;
  final int count;

  const _HeatmapStatusShare({
    required this.status,
    required this.count,
  });
}

class _IssueRadarPainter extends CustomPainter {
  final double physical;
  final double psychological;
  final double external;
  final Color physicalColor;
  final Color psychologicalColor;
  final Color externalColor;

  _IssueRadarPainter({
    required this.physical,
    required this.psychological,
    required this.external,
    required this.physicalColor,
    required this.psychologicalColor,
    required this.externalColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 4);
    final radius = math.min(size.width, size.height) * 0.50;

    final gridPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15;
    final axisPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.25;

    const levels = [0.2, 0.4, 0.6, 0.8, 1.0];
    for (final level in levels) {
      final r = radius * level;
      final path = Path();
      for (int i = 0; i < 3; i++) {
        final angle = -math.pi / 2 + i * (2 * math.pi / 3);
        final p = Offset(
            center.dx + math.cos(angle) * r, center.dy + math.sin(angle) * r);
        if (i == 0) {
          path.moveTo(p.dx, p.dy);
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    for (int i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / 3);
      final end = Offset(center.dx + math.cos(angle) * radius,
          center.dy + math.sin(angle) * radius);
      canvas.drawLine(center, end, axisPaint);
    }

    // Radial tick labels: 20%, 40%, 60%, 80%, 100%
    for (final level in levels) {
      final y = center.dy - radius * level;
      final tick = '${(level * 100).round()}%';
      final tp = TextPainter(
        text: TextSpan(
          text: tick,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 7,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(center.dx - tp.width - 8, y - tp.height / 2));
    }

    final labels = <({String name, int max, Color color})>[
      (name: 'Physiological', max: 15, color: physicalColor),
      (name: 'External', max: 10, color: externalColor),
      (name: 'Psychological', max: 10, color: psychologicalColor),
    ];
    final values = [physical, external, psychological];

    for (int i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / 3);
      final labelData = labels[i];
      final percent = values[i];
      final maxValue = labelData.max;
      final actualValue = percent / 100 * maxValue;

      final labelR = radius * 1.10;
      final labelYOffset = i == 0 ? -12.0 : 0.0;
      final labelPos = Offset(
        center.dx + math.cos(angle) * labelR,
        center.dy + math.sin(angle) * labelR + labelYOffset,
      );

      final mainText = '${labelData.name} ${percent.toStringAsFixed(0)}%';
      final mainPainter = TextPainter(
        text: TextSpan(
          text: mainText,
          style: TextStyle(
            color: labelData.color,
            fontSize: 8,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final valuePainter = TextPainter(
        text: TextSpan(
          text: '(${actualValue.toStringAsFixed(1)}/$maxValue)',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 7,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

        // Keep corner labels inside canvas and avoid clipping.
        final safeMainX = (labelPos.dx - mainPainter.width / 2)
          .clamp(2.0, size.width - mainPainter.width - 2.0)
          .toDouble();
        final safeMainY = (labelPos.dy - mainPainter.height / 2)
          .clamp(2.0, size.height - mainPainter.height - valuePainter.height - 4)
          .toDouble();

        final mainX = safeMainX;
        final mainY = safeMainY;
      mainPainter.paint(canvas, Offset(mainX, mainY));

          // Keep value centered to the main label line for cleaner alignment.
          final valueX = (mainX + (mainPainter.width - valuePainter.width) / 2)
            .clamp(2.0, size.width - valuePainter.width - 2.0)
            .toDouble();
        final valueY = (mainY + mainPainter.height + 1)
          .clamp(2.0, size.height - valuePainter.height - 2.0)
          .toDouble();
      valuePainter.paint(canvas, Offset(valueX, valueY));
    }

    final normalizedValues = values
        .map((v) => (v.clamp(0.0, 100.0) / 100.0).toDouble())
        .toList();

    final fillPath = Path();
    final points = <Offset>[];
    for (int i = 0; i < 3; i++) {
      final angle = -math.pi / 2 + i * (2 * math.pi / 3);
      final p = Offset(
        center.dx + math.cos(angle) * radius * normalizedValues[i],
        center.dy + math.sin(angle) * radius * normalizedValues[i],
      );
      points.add(p);
      if (i == 0) {
        fillPath.moveTo(p.dx, p.dy);
      } else {
        fillPath.lineTo(p.dx, p.dy);
      }
    }
    fillPath.close();

    final gradient = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          physicalColor.withValues(alpha: 0.35),
          psychologicalColor.withValues(alpha: 0.35),
          externalColor.withValues(alpha: 0.35),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawPath(fillPath, gradient);

    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8;
    canvas.drawPath(fillPath, strokePaint);

    final dotPaint = Paint()..color = Colors.white;
    for (final p in points) {
      canvas.drawCircle(p, 3, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _IssueRadarPainter oldDelegate) {
    return oldDelegate.physical != physical ||
        oldDelegate.psychological != psychological ||
        oldDelegate.external != external;
  }
}

class _IssueStackedBarPainter extends CustomPainter {
  final List<_IssuePercentPoint> points;
  final Color physicalColor;
  final Color psychologicalColor;
  final Color externalColor;

  _IssueStackedBarPainter({
    required this.points,
    required this.physicalColor,
    required this.psychologicalColor,
    required this.externalColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0;
    const right = 10.0;
    const top = 10.0;
    const bottom = 34.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 0.6;

    canvas.drawLine(
      const Offset(left, top), Offset(left, top + chartHeight), axisPaint);
    canvas.drawLine(Offset(left, top + chartHeight),
        Offset(left + chartWidth, top + chartHeight), axisPaint);

    const yTicks = [0, 25, 50, 75, 100];
    for (final tick in yTicks) {
      final y = top + chartHeight - chartHeight * (tick / 100);
      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: '$tick%',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 8,
            fontFamily: 'SF Pro',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    if (points.isEmpty) return;
    final step = chartWidth / points.length;
    final barWidth = math.min(18.0, step * 0.62);

    for (int i = 0; i < points.length; i++) {
      final p = points[i];
      final x = left + step * i + (step - barWidth) / 2;
      final baseY = top + chartHeight;

      // Days without questionnaire data keep the x-axis label only.
      if (!p.hasData) {
        final emptyDayLabel = TextPainter(
          text: TextSpan(
            text: p.label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.86),
              fontSize: 9,
              fontFamily: 'SF Pro',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: step);
        emptyDayLabel.paint(
          canvas,
          Offset(x + (barWidth - emptyDayLabel.width) / 2, baseY + 6),
        );
        continue;
      }

      final physicalH =
          chartHeight * (p.physicalPercent.clamp(0.0, 100.0) / 100);
      final psychologicalH =
          chartHeight * (p.psychologicalPercent.clamp(0.0, 100.0) / 100);
      final externalH =
          chartHeight * (p.externalPercent.clamp(0.0, 100.0) / 100);

      double currentTop = baseY;

      void drawSegment(double h, Color color, String text) {
        if (h <= 0) return;
        final rect = Rect.fromLTWH(x, currentTop - h, barWidth, h);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          Paint()..color = color,
        );
        final tp = TextPainter(
          text: TextSpan(
            text: text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 7,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: barWidth + 10);
        tp.paint(
            canvas,
            Offset(x + (barWidth - tp.width) / 2,
                currentTop - h / 2 - tp.height / 2));
        currentTop -= h;
      }

      drawSegment(
          physicalH, physicalColor, '${p.physicalPercent.toStringAsFixed(0)}%');
      drawSegment(psychologicalH, psychologicalColor,
          '${p.psychologicalPercent.toStringAsFixed(0)}%');
      drawSegment(
          externalH, externalColor, '${p.externalPercent.toStringAsFixed(0)}%');

      final label = TextPainter(
        text: TextSpan(
          text: p.label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.86),
            fontSize: 9,
            fontFamily: 'SF Pro',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: step);
      label.paint(canvas, Offset(x + (barWidth - label.width) / 2, baseY + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _IssueStackedBarPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _IssueLineTrendPainter extends CustomPainter {
  final List<_IssuePercentPoint> points;
  final Color physicalColor;
  final Color psychologicalColor;
  final Color externalColor;

  _IssueLineTrendPainter({
    required this.points,
    required this.physicalColor,
    required this.psychologicalColor,
    required this.externalColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const left = 28.0;
    const right = 10.0;
    const top = 10.0;
    const bottom = 28.0;
    final chartWidth = size.width - left - right;
    final chartHeight = size.height - top - bottom;

    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 0.8;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12)
      ..strokeWidth = 0.6;

    canvas.drawLine(
      const Offset(left, top), Offset(left, top + chartHeight), axisPaint);
    canvas.drawLine(Offset(left, top + chartHeight),
        Offset(left + chartWidth, top + chartHeight), axisPaint);

    const yTicks = [0, 25, 50, 75, 100];
    for (final tick in yTicks) {
      final y = top + chartHeight - chartHeight * (tick / 100);
      canvas.drawLine(Offset(left, y), Offset(left + chartWidth, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: '$tick%',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 8,
            fontFamily: 'SF Pro',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    if (points.isEmpty) return;
    final step =
        points.length > 1 ? chartWidth / (points.length - 1) : chartWidth;

    void drawSeries(Color color, double Function(_IssuePercentPoint p) pick) {
      final path = Path();
      var hasStarted = false;
      for (int i = 0; i < points.length; i++) {
        if (!points[i].hasData) {
          continue;
        }
        final x = left + step * i;
        final y = top +
            chartHeight -
            chartHeight * (pick(points[i]).clamp(0.0, 100.0) / 100);
        if (!hasStarted) {
          path.moveTo(x, y);
          hasStarted = true;
        } else {
          path.lineTo(x, y);
        }
      }
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 1.8
        ..style = PaintingStyle.stroke;
      canvas.drawPath(path, linePaint);

      final dotPaint = Paint()..color = color;
      for (int i = 0; i < points.length; i++) {
        if (!points[i].hasData) continue;
        final x = left + step * i;
        final y = top +
            chartHeight -
            chartHeight * (pick(points[i]).clamp(0.0, 100.0) / 100);
        canvas.drawCircle(Offset(x, y), 2.2, dotPaint);
        
        // Draw percentage label above the dot
        final value = pick(points[i]);
        if (value > 0) {
          final textPainter = TextPainter(
            text: TextSpan(
              text: value.toStringAsFixed(0),
              style: TextStyle(
                color: color,
                fontSize: 7,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w500,
              ),
            ),
            textDirection: TextDirection.ltr,
          )..layout();
          textPainter.paint(canvas, Offset(x - textPainter.width / 2, y - 10));
        }
      }
    }

    drawSeries(physicalColor, (p) => p.physicalPercent);
    drawSeries(psychologicalColor, (p) => p.psychologicalPercent);
    drawSeries(externalColor, (p) => p.externalPercent);

    // Draw x-axis tick marks for all data points
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = 0.8;
    for (int i = 0; i < points.length; i++) {
      final x = left + step * i;
      canvas.drawLine(
        Offset(x, top + chartHeight),
        Offset(x, top + chartHeight + 4),
        tickPaint,
      );
    }

    final labelStep = points.length <= 10 ? 1 : 3;
    for (int i = 0; i < points.length; i += labelStep) {
      final x = left + step * i;
      final tp = TextPainter(
        text: TextSpan(
          text: points[i].label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 8,
            fontFamily: 'SF Pro',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, top + chartHeight + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _IssueLineTrendPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}

class _TrendsChartPainter extends CustomPainter {
  static const double leftPadding = 34;
  static const double rightPadding = 8;
  static const double topPadding = 18;
  static const double bottomPadding = 24;

  final List<_TrendPoint> scores;
  final List<String> labels;
  final int totalDays;
  final int? selectedIndex;

  _TrendsChartPainter({
    required this.scores,
    required this.labels,
    required this.totalDays,
    required this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const chartLeft = leftPadding;
    final chartRight = size.width - rightPadding;
    const chartTop = topPadding;
    final chartBottom = size.height - bottomPadding;
    final chartWidth = chartRight - chartLeft;
    final chartHeight = chartBottom - chartTop;

    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..strokeWidth = 0.8;
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.10)
      ..strokeWidth = 0.5;
    final linePaint = Paint()
      ..color = const Color(0xFF0088FF)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final pointPaint = Paint()..color = const Color(0xFF0088FF);
    final selectedPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    canvas.drawLine(
      const Offset(chartLeft, chartTop),
      Offset(chartLeft, chartBottom),
      axisPaint,
    );
    canvas.drawLine(
      Offset(chartLeft, chartBottom),
      Offset(chartRight, chartBottom),
      axisPaint,
    );

    const yTicks = [0, 25, 50, 75, 100];
    for (final tick in yTicks) {
      final y = chartBottom - chartHeight * (tick / 100);
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: '$tick%',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.75),
            fontSize: 9,
            fontFamily: 'SF Pro',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(2, y - tp.height / 2));
    }

    if (scores.isEmpty) return;
    final divisor = totalDays > 1 ? (totalDays - 1) : 1;
    final path = Path();
    final points = <Offset>[];
    for (int i = 0; i < scores.length; i++) {
      final x = chartLeft + chartWidth * (scores[i].dayIndex / divisor);
      final y =
          chartBottom - chartHeight * (scores[i].score.clamp(0.0, 100.0) / 100);
      final p = Offset(x, y);
      points.add(p);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    for (int i = 0; i < points.length; i++) {
      canvas.drawCircle(points[i], 2.8, pointPaint);
      final scoreText = scores[i].score.toStringAsFixed(0);
      final scorePainter = TextPainter(
        text: TextSpan(
          text: scoreText,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.86),
            fontSize: 8,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final textLeft = (points[i].dx - scorePainter.width / 2)
          .clamp(0.0, size.width - scorePainter.width);
      final textTop =
          (points[i].dy - 14).clamp(0.0, size.height - scorePainter.height);
      scorePainter.paint(
        canvas,
        Offset(textLeft, textTop),
      );
      if (selectedIndex == i) {
        canvas.drawCircle(points[i], 5.2, selectedPaint);
      }
    }

    // Draw x-axis tick marks for all data points
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.30)
      ..strokeWidth = 0.8;
    for (int i = 0; i < labels.length; i++) {
      final x = chartLeft + chartWidth * (i / divisor);
      canvas.drawLine(
        Offset(x, chartBottom),
        Offset(x, chartBottom + 4),
        tickPaint,
      );
    }

    final labelStep = labels.length <= 8 ? 1 : 3;
    for (int i = 0; i < labels.length; i += labelStep) {
      final x = chartLeft + chartWidth * (i / divisor);
      final tp = TextPainter(
        text: TextSpan(
          text: labels[i],
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.80),
            fontSize: 9,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartBottom + 10));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendsChartPainter oldDelegate) {
    return oldDelegate.scores != scores ||
        oldDelegate.labels != labels ||
        oldDelegate.totalDays != totalDays ||
        oldDelegate.selectedIndex != selectedIndex;
  }
}
class _BubbleShapeClipper extends CustomClipper<Path> {
  static const _arrowWidth = 14.0;
  static const _arrowHeight = 7.0;
  static const _borderRadius = 12.0;

  final double anchorX;

  _BubbleShapeClipper({
    required this.anchorX,
  });

  @override
  Path getClip(Size size) {
    final path = Path();

    const r = _borderRadius;
    const top = _arrowHeight;
    final arrowCenter =
        anchorX.clamp(r + _arrowWidth / 2, size.width - r - _arrowWidth / 2);

    path.moveTo(r, top);
    path.lineTo(arrowCenter - _arrowWidth / 2, top);
    path.lineTo(arrowCenter, 0); // arrow tip
    path.lineTo(arrowCenter + _arrowWidth / 2, top);
    path.lineTo(size.width - r, top);
    path.arcToPoint(Offset(size.width, top + r), radius: const Radius.circular(r));
    path.lineTo(size.width, size.height - r);
    path.arcToPoint(
      Offset(size.width - r, size.height),
      radius: const Radius.circular(r),
    );
    path.lineTo(r, size.height);
    path.arcToPoint(Offset(0, size.height - r), radius: const Radius.circular(r));
    path.lineTo(0, top + r);
    path.arcToPoint(const Offset(r, top), radius: const Radius.circular(r));
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant _BubbleShapeClipper oldClipper) => oldClipper.anchorX != anchorX;
}

class _VerticalBarChartPainter extends CustomPainter {
  final List<({String label, double value, Color color})> values;

  _VerticalBarChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 30.0; // Bottom padding for X-axis labels
    const leftPadding = 25.0; // Left padding for Y-axis
    const topPadding = 10.0; // Top padding
    const barWidth = 28.0;
    const barSpacing = 8.0;

    final chartHeight = size.height - padding - topPadding;
    final chartWidth = size.width - leftPadding;

    // Y-axis line
    final axisPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 0.8;
    
    canvas.drawLine(
      Offset(leftPadding, topPadding),
      Offset(leftPadding, size.height - padding),
      axisPaint,
    );

    // X-axis line
    canvas.drawLine(
      Offset(leftPadding, size.height - padding),
      Offset(size.width, size.height - padding),
      axisPaint,
    );

    // Y-axis ticks and labels (0%, 25%, 50%, 75%, 100%)
    final tickPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 0.8;

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    for (int i = 0; i <= 4; i++) {
      final percent = i * 25;
      final y = size.height - padding - (chartHeight * (percent / 100));
      
      // Tick mark
      canvas.drawLine(
        Offset(leftPadding - 4, y),
        Offset(leftPadding, y),
        tickPaint,
      );

      // Label
      textPainter.text = TextSpan(
        text: '$percent%',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.7),
          fontSize: 8,
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w400,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(leftPadding - textPainter.width - 8, y - textPainter.height / 2),
      );
    }

    // Draw bars
    final totalWidth = (barWidth * values.length) + (barSpacing * (values.length - 1));
    final startX = leftPadding + (chartWidth - totalWidth) / 2;

    for (int i = 0; i < values.length; i++) {
      final item = values[i];
      final barX = startX + (i * (barWidth + barSpacing));
      final barHeightPx = chartHeight * (item.value.clamp(0.0, 100.0) / 100);
      final barY = size.height - padding - barHeightPx;

      // Draw bar
      final barPaint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      canvas.drawRRect(
        RRect.fromLTRBR(
          barX,
          barY,
          barX + barWidth,
          size.height - padding,
          const Radius.circular(3),
        ),
        barPaint,
      );

      // Draw percentage text inside bar
      final displayPercent = item.value.toStringAsFixed(0);
      textPainter.text = TextSpan(
        text: '$displayPercent%',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9,
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w600,
        ),
      );
      textPainter.layout();
      
      // Center text in bar
      final textX = barX + (barWidth - textPainter.width) / 2;
      if (barHeightPx > 20) {
        // Large bars: display text inside
        final textY = barY + (barHeightPx - textPainter.height) / 2;
        textPainter.paint(canvas, Offset(textX, textY));
      } else if (item.value > 0) {
        // Small bars: display text above bar
        final textY = (barY - textPainter.height - 2)
            .clamp(topPadding, size.height - padding - textPainter.height)
            .toDouble();
        textPainter.paint(canvas, Offset(textX, textY));
      }

      // Draw X-axis label
      textPainter.text = TextSpan(
        text: item.label,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 9,
          fontFamily: 'SF Pro',
          fontWeight: FontWeight.w500,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          barX + (barWidth - textPainter.width) / 2,
          size.height - padding + 6,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _VerticalBarChartPainter oldDelegate) {
    return oldDelegate.values != values;
  }
}

class _BubbleBorderPainter extends CustomPainter {
  final double anchorX;
  final Color color;
  final double width;

  _BubbleBorderPainter({
    required this.anchorX,
    required this.color,
    required this.width,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final clipper = _BubbleShapeClipper(anchorX: anchorX);
    final path = clipper.getClip(size);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..color = color
      ..strokeWidth = width;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _BubbleBorderPainter oldDelegate) {
    return oldDelegate.anchorX != anchorX ||
        oldDelegate.color != color ||
        oldDelegate.width != width;
  }
}
