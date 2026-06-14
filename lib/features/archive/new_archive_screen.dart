/// 新档案页面
/// 背景: hug_1.png + 排便日历热力图 / 图表分析
/// 入口: 主页右下角星星光晕
/// 交互: 左右滑动切换日历/图表
library;

import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pupu/core/app_typography.dart';
import 'package:pupu/features/archive/day_records_sheet.dart';
import 'package:pupu/features/archive/logs_card.dart';
import 'package:pupu/features/archive/logs_day_utils.dart';
import 'package:pupu/features/timer/session_record_utils.dart';
import 'package:pupu/models/bowel_record.dart';
import 'package:pupu/providers/records_provider.dart';
import 'package:pupu/features/archive/chart_analysis_card.dart';

class NewArchiveScreen extends ConsumerStatefulWidget {
  const NewArchiveScreen({super.key});

  @override
  ConsumerState<NewArchiveScreen> createState() => _NewArchiveScreenState();
}

class _NewArchiveScreenState extends ConsumerState<NewArchiveScreen> {
  late DateTime _currentMonth;
  DateTime? _currentDay;
  late PageController _pageController;
  int _currentPage = 0;
  bool _archiveOverlayVisible = false;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime.now();
    _pageController = PageController();
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  void _previousDay() {
    setState(() {
      _currentDay = normalizeDay(
        (_currentDay ?? DateTime.now()).subtract(const Duration(days: 1)),
      );
    });
  }

  void _nextDay() {
    setState(() {
      _currentDay = normalizeDay(
        (_currentDay ?? DateTime.now()).add(const Duration(days: 1)),
      );
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final asyncRecords = ref.watch(recordsWithRefreshProvider);

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 背景图片 hug_1.png (100%透明度) - 固定不变
          Image.asset(
            'assets/images/hug_1.png',
            fit: BoxFit.cover,
          ),
          // 内容层
          SafeArea(
            child: Column(
              children: [
                // 顶部导航栏
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.arrow_back_ios,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const Spacer(),
                      // 页面指示器
                      Row(
                        children: [
                          _buildPageIndicator(0),
                          const SizedBox(width: 8),
                          _buildPageIndicator(1),
                          const SizedBox(width: 8),
                          _buildPageIndicator(2),
                        ],
                      ),
                      const Spacer(),
                      const SizedBox(width: 24), // 平衡返回按钮
                    ],
                  ),
                ),
                // PageView - 左右滑动切换日历/图表
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: _archiveOverlayVisible
                        ? const NeverScrollableScrollPhysics()
                        : null,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      // 第一页：日历热力图
                      Center(
                        child: asyncRecords.when(
                          loading: () => const CircularProgressIndicator(
                              color: Colors.white),
                          error: (e, _) => Text('$e',
                              style: const TextStyle(color: Colors.white)),
                          data: (records) {
                            final Map<String, int> dailyCounts = {};
                            final Map<String, List<BowelRecord>> dailyRecords = {};

                            for (final record in records) {
                              final dateKey = DateFormat('yyyy-MM-dd')
                                  .format(record.dateTime);
                              dailyCounts[dateKey] =
                                  (dailyCounts[dateKey] ?? 0) + 1;
                              dailyRecords.putIfAbsent(dateKey, () => []);
                              dailyRecords[dateKey]!.add(record);
                            }

                            return _LogCalendarCard(
                              currentMonth: _currentMonth,
                              dailyCounts: dailyCounts,
                              dailyRecords: dailyRecords,
                              onPreviousMonth: _previousMonth,
                              onNextMonth: _nextMonth,
                              onDayTap: (date, dayRecords) =>
                                  _showDayRecords(context, date, dayRecords),
                            );
                          },
                        ),
                      ),
                      // 第二页：图表分析
                      Center(
                        child: asyncRecords.when(
                          loading: () => const CircularProgressIndicator(
                              color: Colors.white),
                          error: (e, _) => Text(
                            '$e',
                            style: const TextStyle(color: Colors.white),
                          ),
                          data: (records) =>
                              ChartAnalysisCard(records: records),
                        ),
                      ),
                      Center(
                        child: asyncRecords.when(
                          loading: () => const CircularProgressIndicator(
                              color: Colors.white),
                          error: (e, _) => Text(
                            '$e',
                            style: const TextStyle(color: Colors.white),
                          ),
                          data: (records) {
                            final currentDay =
                                _currentDay ?? defaultDayFromRecords(records);
                            if (_currentDay == null) {
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                setState(() {
                                  _currentDay = currentDay;
                                });
                              });
                            }
                            final dayRecords = recordsForDay(records, currentDay);
                            return LogsCard(
                              currentDay: currentDay,
                              dayRecords: dayRecords,
                              onPreviousDay: _previousDay,
                              onNextDay: _nextDay,
                              onOverlayVisibilityChanged: (visible) {
                                if (!mounted) return;
                                setState(() => _archiveOverlayVisible = visible);
                              },
                              onSubmitAnswers: (record, answers) async {
                                await mergeQuestionnaireAnswers(
                                  recordId: record.id,
                                  answers: answers,
                                );
                                if (!mounted) return;
                                bumpRecordsRefresh(ref);
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageIndicator(int index) {
    final isActive = _currentPage == index;
    return GestureDetector(
      onTap: () {
        _pageController.animateToPage(
          index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      },
      child: Container(
        width: isActive ? 20 : 8,
        height: 8,
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.white.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  void _showDayRecords(
      BuildContext context, DateTime date, List<BowelRecord> dayRecords) {
    if (dayRecords.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${DateFormat('MMM d, yyyy').format(date)} - No records',
            style: AppTypography.body(),
          ),
          backgroundColor: Colors.grey[800],
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => DayRecordsSheet(
        date: date,
        records: dayRecords,
        onOverlayVisibilityChanged: (visible) {
          if (!mounted) return;
          setState(() => _archiveOverlayVisible = visible);
        },
        onSubmitAnswers: (record, answers) async {
          await mergeQuestionnaireAnswers(
            recordId: record.id,
            answers: answers,
          );
          if (!mounted) return;
          bumpRecordsRefresh(ref);
        },
      ),
    );
  }
}

/// 日历热力图卡片 - 大液体玻璃 + 小液体玻璃
class _LogCalendarCard extends StatelessWidget {
  final DateTime currentMonth;
  final Map<String, int> dailyCounts;
  final Map<String, List<BowelRecord>> dailyRecords;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final void Function(DateTime, List<BowelRecord>) onDayTap;

  const _LogCalendarCard({
    required this.currentMonth,
    required this.dailyCounts,
    required this.dailyRecords,
    required this.onPreviousMonth,
    required this.onNextMonth,
    required this.onDayTap,
  });

  static const Color _heatmapColor = Color(0xFF0088FF);

  double _getOpacity(int count) {
    if (count <= 0) return 0.0;
    if (count >= 5) return 1.0;
    return count * 0.2;
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 326,
      height: 620, // 加长下方长度
      child: Stack(
        children: [
          // 大液体玻璃卡片
          Positioned(
            left: 0,
            top: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                // 降低模糊度，提高清晰度
                filter: ImageFilter.blur(sigmaX: 1, sigmaY: 1),
                child: Container(
                  width: 326,
                  height: 620,
                  decoration: BoxDecoration(
                    // 更白更通透的颜色
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
                      // inner shadow
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: const Alignment(0, 0.1),
                              colors: [
                                Colors.white.withValues(alpha: 0.30),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 标题: Log Calendar
                      const Positioned(
                        left: 61,
                        top: 46,
                        child: Text(
                          'Log Calendar',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 25,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.bold,
                            letterSpacing: 5,
                          ),
                        ),
                      ),
                      // 月份导航 - 可点击快速选择日期
                      Positioned(
                        left: 21,
                        right: 21,
                        top: 96,
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: onPreviousMonth,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  '〈',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                DateFormat('MMMM d, yyyy').format(currentMonth),
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.fade,
                                softWrap: false,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontFamily: 'SF Pro',
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: onNextMonth,
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Text(
                                  '〉',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // 星期标题行
                      const Positioned(
                        left: 47,
                        top: 134,
                        child: Text(
                          'S    M    T    W    T    F    S',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontFamily: 'SF Pro',
                            fontWeight: FontWeight.w600,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      // 小液体玻璃 - 日期网格区域
                      Positioned(
                        left: 21,
                        top: 152,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                            child: Container(
                              width: 284,
                              height: 275,
                              decoration: BoxDecoration(
                                // 更白更通透的颜色
                                color: Colors.white.withValues(alpha: 0.25),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x33000000),
                                    blurRadius: 40,
                                    offset: Offset(0, 8),
                                    spreadRadius: 0,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 16),
                                child: _buildCalendarGrid(),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Past Month Activity 标题 - 横向居中
                      const Positioned(
                        left: 0,
                        right: 0,
                        top: 445,
                        child: Center(
                          child: Text(
                            'Past Month Activity',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontFamily: 'SF Pro',
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // 色调卡
                      Positioned(
                        left: 21,
                        right: 21,
                        top: 475,
                        child: _buildColorScaleCard(),
                      ),
                      // Tip 文本 - 最下方居中
                      const Positioned(
                        left: 11,
                        right: 11,
                        bottom: 16,
                        child: SizedBox(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: 'Tip',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      ': A darker shade simply means more logs that day——it\'s about frequency, not a measure of health.',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontFamily: 'SF Pro',
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColorScaleCard() {
    return SizedBox(
      width: 284,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Less',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(width: 12),
          // 渐变色块
          Expanded(
            child: Container(
              height: 20,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: LinearGradient(
                  colors: [
                    _heatmapColor.withValues(alpha: 0.0),
                    _heatmapColor.withValues(alpha: 0.2),
                    _heatmapColor.withValues(alpha: 0.4),
                    _heatmapColor.withValues(alpha: 0.6),
                    _heatmapColor.withValues(alpha: 0.8),
                    _heatmapColor.withValues(alpha: 1.0),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'More',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid() {
    final firstDayOfMonth = DateTime(currentMonth.year, currentMonth.month, 1);
    final lastDayOfMonth =
        DateTime(currentMonth.year, currentMonth.month + 1, 0);
    final firstWeekday = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final List<Widget> rows = [];
    int dayCounter = 1;
    final totalCells = firstWeekday + daysInMonth;
    final rowCount = (totalCells / 7).ceil();

    for (int row = 0; row < rowCount; row++) {
      final List<Widget> cells = [];
      for (int col = 0; col < 7; col++) {
        final cellIndex = row * 7 + col;
        if (cellIndex < firstWeekday || dayCounter > daysInMonth) {
          cells.add(const SizedBox(width: 34, height: 36));
        } else {
          final day = dayCounter;
          final date = DateTime(currentMonth.year, currentMonth.month, day);
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final count = dailyCounts[dateKey] ?? 0;
          final opacity = _getOpacity(count);
          final records = dailyRecords[dateKey] ?? [];

          cells.add(
            GestureDetector(
              onTap: () => onDayTap(date, records),
              child: Container(
                width: 34,
                height: 36,
                decoration: BoxDecoration(
                  color: opacity > 0
                      ? _heatmapColor.withValues(alpha: opacity)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$day',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                    letterSpacing: 5,
                  ),
                ),
              ),
            ),
          );
          dayCounter++;
        }
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: cells,
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      children: rows,
    );
  }
}

