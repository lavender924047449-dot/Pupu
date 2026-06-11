import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pupu/features/archive/log_session_meta.dart';
import 'package:pupu/features/archive/logs_day_utils.dart';
import 'package:pupu/features/archive/widgets/log_now_button.dart';
import 'package:pupu/features/questionnaire/questionnaire_codec.dart';
import 'package:pupu/features/questionnaire/questionnaire_flow.dart';
import 'package:pupu/features/questionnaire/questionnaire_layout_tokens.dart';
import 'package:pupu/features/questionnaire/widgets/questionnaire_interactive_panel.dart';
import 'package:pupu/features/questionnaire/widgets/questionnaire_overlay.dart';
import 'package:pupu/features/questionnaire/widgets/questionnaire_readonly_panel.dart';
import 'package:pupu/models/bowel_record.dart';

class LogsCard extends StatefulWidget {
  final DateTime currentDay;
  final List<BowelRecord> dayRecords;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;
  final Future<void> Function(
    BowelRecord record,
    Map<String, List<int>> answers,
  ) onSubmitAnswers;
  final ValueChanged<bool>? onOverlayVisibilityChanged;

  const LogsCard({
    super.key,
    required this.currentDay,
    required this.dayRecords,
    required this.onPreviousDay,
    required this.onNextDay,
    required this.onSubmitAnswers,
    this.onOverlayVisibilityChanged,
  });

  @override
  State<LogsCard> createState() => _LogsCardState();
}

class _LogsCardState extends State<LogsCard> with TickerProviderStateMixin {
  static const double _fixedHeaderHeight = 72;

  final QuestionnaireFlow _flow = QuestionnaireFlow();
  BowelRecord? _editingRecord;
  bool _isSubmitting = false;
  bool _pinTopDateNav = false;
  OverlayEntry? _overlayEntry;
  final GlobalKey<QuestionnaireOverlayState> _overlayKey =
      GlobalKey<QuestionnaireOverlayState>();
  late final AnimationController _finishLoggingController;
  late final ScrollController _contentScrollController;

  @override
  void initState() {
    super.initState();
    _finishLoggingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    _contentScrollController = ScrollController();
    _contentScrollController.addListener(_handleContentScroll);
  }

  @override
  void didUpdateWidget(LogsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentDay != widget.currentDay) {
      if (_contentScrollController.hasClients) {
        _contentScrollController.jumpTo(0);
      }
      if (_pinTopDateNav) {
        setState(() => _pinTopDateNav = false);
      }
    }
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _contentScrollController.removeListener(_handleContentScroll);
    _contentScrollController.dispose();
    _finishLoggingController.dispose();
    _flow.dispose();
    super.dispose();
  }

  void _handleContentScroll() {
    if (!_contentScrollController.hasClients) return;
    final shouldPin = _contentScrollController.offset > 8;
    if (shouldPin != _pinTopDateNav) {
      setState(() => _pinTopDateNav = shouldPin);
    }
  }

  void _openOverlay(BowelRecord record) {
    _flow.reset();
    setState(() => _editingRecord = record);
    widget.onOverlayVisibilityChanged?.call(true);

    _overlayEntry?.remove();
    _overlayEntry = OverlayEntry(
      builder: (overlayContext) => QuestionnaireOverlay(
        key: _overlayKey,
        onDismiss: _removeOverlay,
        child: QuestionnaireInteractivePanel(
          flow: _flow,
          layout: const QuestionnaireLayoutTokens.compact(),
          onFinish: _handleFinish,
          finishOpacityAnimation: _finishLoggingController,
        ),
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _flow.reset();
    setState(() => _editingRecord = null);
    widget.onOverlayVisibilityChanged?.call(false);
  }

  Future<void> _dismissOverlay({bool animated = false}) async {
    if (_isSubmitting && !animated) return;
    if (_overlayEntry == null) return;
    await _overlayKey.currentState?.dismiss(animated: animated);
    if (_overlayEntry != null) {
      _removeOverlay();
    }
  }

  Future<void> _handleFinish() async {
    if (_editingRecord == null) return;
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);
    final answers = encodeAnswers(_flow.selectedAnswers, _flow.visibleQuestions);
    try {
      await widget.onSubmitAnswers(_editingRecord!, answers);
      if (!mounted) return;
      await _dismissOverlay(animated: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildDateNavigator({bool compact = false}) {
    final dateText = DateFormat(
      compact ? 'MMM d, yyyy' : 'MMMM d, yyyy',
    ).format(widget.currentDay);

    final row = Row(
      children: [
        GestureDetector(
          onTap: widget.onPreviousDay,
          child: Padding(
            padding: EdgeInsets.all(compact ? 4 : 8),
            child: Text(
              '〈',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 12 : 15,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            dateText,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.fade,
            softWrap: false,
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 11 : 15,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w700,
              letterSpacing: compact ? 0.5 : 1.2,
            ),
          ),
        ),
        const SizedBox(width: 4),
        GestureDetector(
          onTap: widget.onNextDay,
          child: Padding(
            padding: EdgeInsets.all(compact ? 4 : 8),
            child: Text(
              '〉',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 12 : 15,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );

    if (!compact) return row;

    return Container(
      width: 220,
      height: 24,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(50),
        border: Border.all(color: Colors.white24, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: row,
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
          child: _pinTopDateNav
              ? Center(
                  key: const ValueKey('pinned-date-only'),
                  child: _buildDateNavigator(compact: true),
                )
              : const Center(
                  key: ValueKey('pinned-title-only'),
                  child: Text(
                    'Logs',
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

  Widget _buildLogList() {
    const compactLayout = QuestionnaireLayoutTokens.compact();
    final localeName = Localizations.localeOf(context).toLanguageTag();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(widget.dayRecords.length, (index) {
        final record = widget.dayRecords[index];
        final hasAnswers = hasQuestionnaireAnswers(record);
        final metaText = formatLogSessionMeta(record, localeName);
        return Padding(
          padding: EdgeInsets.only(
            bottom: index == widget.dayRecords.length - 1 ? 0 : 18,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 15,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    'Log ${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF0088FF),
                      fontSize: 20,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.20,
                    ),
                  ),
                  Text(
                    metaText,
                    softWrap: true,
                    style: const TextStyle(
                      color: Color(0xFFF0F0F0),
                      fontSize: 14,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (!hasAnswers) LogNowButton(onTap: () => _openOverlay(record)),
              if (hasAnswers)
                QuestionnaireReadonlyPanel(
                  answers: record.questionnaireAnswers!,
                  layout: compactLayout,
                ),
            ],
          ),
        );
      }),
    );
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
                    padding: const EdgeInsets.fromLTRB(21, 6, 21, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!_pinTopDateNav) ...[
                          Transform.translate(
                            offset: const Offset(0, -4),
                            child: _buildDateNavigator(),
                          ),
                          const SizedBox(height: 14),
                        ],
                        if (widget.dayRecords.isEmpty)
                          const SizedBox(
                            height: 420,
                            child: Center(
                              child: Text(
                                'No Logs Yet',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontFamily: 'SF Pro',
                                  fontWeight: FontWeight.w300,
                                ),
                              ),
                            ),
                          )
                        else
                          _buildLogList(),
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
}
