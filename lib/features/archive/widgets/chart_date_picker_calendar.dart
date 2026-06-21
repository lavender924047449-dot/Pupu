import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:pupu/features/archive/chart_analysis_logic.dart';
import 'package:pupu/features/archive/logs_day_utils.dart';

enum _ChartPickerMode { month, year }

/// Custom month calendar for Chart Analysis date picker.
/// Matches Material dark calendar layout; supports log-day marks and year list.
class ChartDatePickerCalendar extends StatefulWidget {
  final DateTime selectedDate;
  final DateTime today;
  final Set<DateTime> logDays;
  final DateTime minDate;
  final DateTime maxDate;
  final ValueChanged<DateTime> onSelectedDateChanged;

  const ChartDatePickerCalendar({
    super.key,
    required this.selectedDate,
    required this.today,
    required this.logDays,
    required this.minDate,
    required this.maxDate,
    required this.onSelectedDateChanged,
  });

  @override
  State<ChartDatePickerCalendar> createState() =>
      _ChartDatePickerCalendarState();
}

class _ChartDatePickerCalendarState extends State<ChartDatePickerCalendar> {
  static const Color _accentColor = Color(0xFF0088FF);
  static const Color _emphasisColor = _accentColor;
  static const double _cellSize = 36;
  static const double _yearRowHeight = 44;

  late DateTime _displayMonth;
  _ChartPickerMode _mode = _ChartPickerMode.month;
  ScrollController? _yearScrollController;

  int get _minYear => widget.minDate.year;
  int get _maxYear => widget.maxDate.year;

  @override
  void initState() {
    super.initState();
    final anchor = normalizeDay(widget.selectedDate);
    _displayMonth = DateTime(anchor.year, anchor.month);
  }

  @override
  void dispose() {
    _yearScrollController?.dispose();
    super.dispose();
  }

  DateTime _clampDay(DateTime day) {
    final normalized = normalizeDay(day);
    if (normalized.isBefore(widget.minDate)) return widget.minDate;
    if (normalized.isAfter(widget.maxDate)) return widget.maxDate;
    return normalized;
  }

  bool _isDaySelectable(DateTime day) {
    final normalized = normalizeDay(day);
    return !normalized.isBefore(widget.minDate) &&
        !normalized.isAfter(widget.maxDate);
  }

  bool get _canGoPreviousMonth {
    final previous = DateTime(_displayMonth.year, _displayMonth.month - 1);
    return !previous.isBefore(DateTime(_minYear, widget.minDate.month));
  }

  bool get _canGoNextMonth {
    final next = DateTime(_displayMonth.year, _displayMonth.month + 1);
    return !next.isAfter(DateTime(_maxYear, widget.maxDate.month));
  }

  void _goToPreviousMonth() {
    if (!_canGoPreviousMonth) return;
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
    });
  }

  void _goToNextMonth() {
    if (!_canGoNextMonth) return;
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
    });
  }

  void _openYearPicker() {
    final currentYear = _displayMonth.year;
    final index = (currentYear - _minYear).clamp(0, _maxYear - _minYear);
    _yearScrollController?.dispose();
    _yearScrollController = ScrollController(
      initialScrollOffset: index * _yearRowHeight,
    );
    setState(() => _mode = _ChartPickerMode.year);
  }

  void _selectYear(int year) {
    setState(() {
      _displayMonth = DateTime(year, _displayMonth.month);
      _mode = _ChartPickerMode.month;
    });
    _yearScrollController?.dispose();
    _yearScrollController = null;
  }

  void _selectDay(DateTime day) {
    if (!_isDaySelectable(day)) return;
    widget.onSelectedDateChanged(_clampDay(day));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: _mode == _ChartPickerMode.month
          ? _buildMonthView()
          : _buildYearView(),
    );
  }

  Widget _buildMonthView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMonthHeader(),
        const SizedBox(height: 8),
        _buildWeekdayHeader(),
        const SizedBox(height: 4),
        _buildDayGrid(),
      ],
    );
  }

  Widget _buildMonthHeader() {
    final monthLabel = DateFormat('MMMM').format(_displayMonth);

    return Row(
      children: [
        IconButton(
          onPressed: _canGoPreviousMonth ? _goToPreviousMonth : null,
          icon: Icon(
            Icons.chevron_left,
            color: Colors.white
                .withValues(alpha: _canGoPreviousMonth ? 0.9 : 0.32),
            size: 22,
          ),
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        ),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                monthLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: _openYearPicker,
                behavior: HitTestBehavior.opaque,
                child: Text(
                  '${_displayMonth.year}',
                  style: const TextStyle(
                    color: _emphasisColor,
                    fontSize: 14,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: _canGoNextMonth ? _goToNextMonth : null,
          icon: Icon(
            Icons.chevron_right,
            color:
                Colors.white.withValues(alpha: _canGoNextMonth ? 0.9 : 0.32),
            size: 22,
          ),
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        ),
      ],
    );
  }

  Widget _buildWeekdayHeader() {
    const labels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: labels
          .map(
            (label) => SizedBox(
              width: _cellSize,
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 12,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  Widget _buildDayGrid() {
    final firstDayOfMonth =
        DateTime(_displayMonth.year, _displayMonth.month, 1);
    final lastDayOfMonth =
        DateTime(_displayMonth.year, _displayMonth.month + 1, 0);
    final leadingEmpty = firstDayOfMonth.weekday % 7;
    final daysInMonth = lastDayOfMonth.day;

    final cells = <Widget>[];
    for (var i = 0; i < leadingEmpty; i++) {
      cells.add(const SizedBox(width: _cellSize, height: _cellSize));
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_displayMonth.year, _displayMonth.month, day);
      cells.add(_buildDayCell(date));
    }

    final rowCount = (cells.length / 7).ceil();
    final rows = <Widget>[];
    for (var row = 0; row < rowCount; row++) {
      final start = row * 7;
      final end = math.min(start + 7, cells.length);
      final rowChildren = List<Widget>.from(cells.sublist(start, end));
      while (rowChildren.length < 7) {
        rowChildren.add(const SizedBox(width: _cellSize, height: _cellSize));
      }
      rows.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: rowChildren,
          ),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: rows);
  }

  Widget _buildDayCell(DateTime date) {
    final selectable = _isDaySelectable(date);
    final style = resolveChartPickerDayStyle(
      day: date,
      today: widget.today,
      selected: widget.selectedDate,
      logDays: widget.logDays,
    );

    final textColor = !selectable
        ? Colors.white.withValues(alpha: 0.28)
        : style.useTodayTextColor
            ? _emphasisColor
            : Colors.white;

    return GestureDetector(
      onTap: selectable ? () => _selectDay(date) : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: _cellSize,
        height: _cellSize,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: style.showLogBackground && selectable
                ? _accentColor.withValues(alpha: 0.5)
                : Colors.transparent,
            shape: BoxShape.circle,
            border: style.showSelectionRing && selectable
                ? Border.all(color: Colors.white, width: 1.5)
                : null,
          ),
          child: Center(
            child: Text(
              '${date.day}',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYearView() {
    final years = List<int>.generate(
      _maxYear - _minYear + 1,
      (i) => _minYear + i,
    );
    final controller = _yearScrollController ?? ScrollController();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Select Year',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.85),
            fontSize: 14,
            fontFamily: 'SF Pro',
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: ListView.builder(
            controller: controller,
            itemCount: years.length,
            itemBuilder: (context, index) {
              final year = years[index];
              final isSelected = year == _displayMonth.year;
              return InkWell(
                onTap: () => _selectYear(year),
                child: Container(
                  height: _yearRowHeight,
                  alignment: Alignment.center,
                  decoration: isSelected
                      ? BoxDecoration(
                          color: _accentColor.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        )
                      : null,
                  child: Text(
                    '$year',
                    style: TextStyle(
                      color: isSelected ? _emphasisColor : Colors.white,
                      fontSize: 16,
                      fontFamily: 'SF Pro',
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        TextButton(
          onPressed: () {
            setState(() => _mode = _ChartPickerMode.month);
            _yearScrollController?.dispose();
            _yearScrollController = null;
          },
          child: const Text(
            'Back to calendar',
            style: TextStyle(
              color: Colors.white70,
              fontFamily: 'SF Pro',
            ),
          ),
        ),
      ],
    );
  }
}
