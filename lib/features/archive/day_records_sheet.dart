import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pupu/core/widgets/timer_blue_glass_panel.dart';
import 'package:pupu/features/archive/logs_day_utils.dart';
import 'package:pupu/features/archive/widgets/log_now_button.dart';
import 'package:pupu/features/questionnaire/questionnaire_codec.dart';
import 'package:pupu/features/questionnaire/questionnaire_flow.dart';
import 'package:pupu/features/questionnaire/questionnaire_layout_tokens.dart';
import 'package:pupu/features/questionnaire/widgets/questionnaire_interactive_panel.dart';
import 'package:pupu/features/questionnaire/widgets/questionnaire_overlay.dart';
import 'package:pupu/features/questionnaire/widgets/questionnaire_readonly_panel.dart';
import 'package:pupu/models/bowel_record.dart';
import 'package:pupu/providers/records_provider.dart';

class DayRecordsSheet extends ConsumerStatefulWidget {
  final DateTime date;
  final List<BowelRecord> records;
  final ValueChanged<bool>? onOverlayVisibilityChanged;
  final Future<void> Function(
    BowelRecord record,
    Map<String, List<int>> answers,
  ) onSubmitAnswers;

  const DayRecordsSheet({
    super.key,
    required this.date,
    required this.records,
    required this.onSubmitAnswers,
    this.onOverlayVisibilityChanged,
  });

  @override
  ConsumerState<DayRecordsSheet> createState() => _DayRecordsSheetState();
}

class _DayRecordsSheetState extends ConsumerState<DayRecordsSheet>
    with TickerProviderStateMixin {
  final QuestionnaireFlow _flow = QuestionnaireFlow();
  final ScrollController _readonlyScrollController = ScrollController();
  final GlobalKey<QuestionnaireOverlayState> _overlayKey =
      GlobalKey<QuestionnaireOverlayState>();
  OverlayEntry? _overlayEntry;
  BowelRecord? _editingRecord;
  bool _isSubmitting = false;
  late final AnimationController _finishLoggingController;

  @override
  void initState() {
    super.initState();
    _finishLoggingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _readonlyScrollController.dispose();
    _finishLoggingController.dispose();
    _flow.dispose();
    super.dispose();
  }

  void _openOverlay(Widget child) {
    _overlayEntry?.remove();
    widget.onOverlayVisibilityChanged?.call(true);
    _overlayEntry = OverlayEntry(
      builder: (_) => QuestionnaireOverlay(
        key: _overlayKey,
        onDismiss: _removeOverlay,
        child: child,
      ),
    );
    Overlay.of(context, rootOverlay: true).insert(_overlayEntry!);
  }

  void _openReadonlyOverlay(BowelRecord record) {
    if (!hasQuestionnaireAnswers(record)) return;
    _flow.reset();
    if (_readonlyScrollController.hasClients) {
      _readonlyScrollController.jumpTo(0);
    }
    setState(() => _editingRecord = null);
    _openOverlay(
      QuestionnaireReadonlyPanel(
        answers: record.questionnaireAnswers!,
        layout: const QuestionnaireLayoutTokens.compact(),
        scrollController: _readonlyScrollController,
      ),
    );
  }

  void _openInteractiveOverlay(BowelRecord record) {
    _flow.reset();
    setState(() => _editingRecord = record);
    _openOverlay(
      QuestionnaireInteractivePanel(
        flow: _flow,
        layout: const QuestionnaireLayoutTokens.compact(),
        onFinish: _handleFinish,
        finishOpacityAnimation: _finishLoggingController,
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _flow.reset();
    if (mounted) {
      setState(() => _editingRecord = null);
    }
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
    final record = _editingRecord;
    if (record == null || _isSubmitting) return;
    setState(() => _isSubmitting = true);
    final answers = encodeAnswers(_flow.selectedAnswers, _flow.visibleQuestions);
    try {
      await widget.onSubmitAnswers(record, answers);
      if (!mounted) return;
      await _dismissOverlay(animated: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  void _onRowTap(BowelRecord record) {
    if (hasQuestionnaireAnswers(record)) {
      _openReadonlyOverlay(record);
      return;
    }
    _openInteractiveOverlay(record);
  }

  @override
  Widget build(BuildContext context) {
    final asyncRecords = ref.watch(recordsWithRefreshProvider);
    final records = asyncRecords.maybeWhen(
      data: (all) => recordsForDay(all, widget.date),
      orElse: () => widget.records,
    );
    final maxSheetHeight = MediaQuery.sizeOf(context).height * 0.55;
    return TimerBlueGlassPanel(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxSheetHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                DateFormat('MMMM d, yyyy').format(widget.date),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            Flexible(
              child: ListView.builder(
                itemCount: records.length,
                itemBuilder: (_, i) {
                  final record = records[i];
                  final hasAnswers = hasQuestionnaireAnswers(record);
                  return InkWell(
                    onTap: () => _onRowTap(record),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFF0088FF),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'SF Pro',
                          ),
                        ),
                      ),
                      title: Text(
                        DateFormat('HH:mm').format(record.dateTime),
                        style: const TextStyle(
                          color: Colors.white,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                      subtitle: Text(
                        '${record.displayMinutes} min ${record.displaySeconds} sec',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontFamily: 'SF Pro',
                        ),
                      ),
                      trailing: hasAnswers
                          ? const Icon(Icons.chevron_right, color: Colors.white54)
                          : LogNowButton(onTap: () => _openInteractiveOverlay(record)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
