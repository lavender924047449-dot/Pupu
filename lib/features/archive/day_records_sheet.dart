import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pupu/core/widgets/timer_blue_glass_panel.dart';
import 'package:pupu/features/archive/logs_day_utils.dart';
import 'package:pupu/features/archive/widgets/log_now_button.dart';
import 'package:pupu/features/archive/widgets/record_delete_ui.dart';
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
  )
  onSubmitAnswers;

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
  String? _openSwipeRecordId;
  VoidCallback? _dismissDeleteBubble;
  final Map<String, GlobalKey> _rowKeys = {};

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
    _dismissDeleteBubble?.call();
    _dismissDeleteBubble = null;
    _overlayEntry?.remove();
    _overlayEntry = null;
    _readonlyScrollController.dispose();
    _finishLoggingController.dispose();
    _flow.dispose();
    super.dispose();
  }

  GlobalKey _rowKeyFor(String recordId) {
    return _rowKeys.putIfAbsent(
      recordId,
      () => GlobalKey(debugLabel: 'day-record-$recordId'),
    );
  }

  void _openOverlay(Widget child) {
    _dismissDeleteBubbleIfNeeded();
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

  void _dismissDeleteBubbleIfNeeded() {
    _dismissDeleteBubble?.call();
    _dismissDeleteBubble = null;
  }

  Future<void> _confirmDeleteRecord(BowelRecord record) async {
    final confirmed = await showRecordDeleteConfirmDialog(context: context);
    if (confirmed != true) {
      setState(() => _openSwipeRecordId = null);
      return;
    }
    await deleteRecordAndRefresh(ref, record.id);
    if (!mounted) return;
    setState(() => _openSwipeRecordId = null);
    final all = await ref.read(recordsWithRefreshProvider.future);
    final remains = recordsForDay(all, widget.date);
    if (mounted && remains.isEmpty) {
      Navigator.of(context).maybePop();
    }
  }

  void _showDeleteBubble(GlobalKey key, BowelRecord record) {
    _dismissDeleteBubbleIfNeeded();
    _dismissDeleteBubble = showDeleteBubble(
      context: context,
      targetKey: key,
      onDeleteTap: () async {
        _dismissDeleteBubbleIfNeeded();
        await _confirmDeleteRecord(record);
      },
    );
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
    final answers = encodeAnswers(
      _flow.selectedAnswers,
      _flow.visibleQuestions,
    );
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
                  final rowKey = _rowKeyFor(record.id);
                  return _SwipeToDeleteRow(
                    key: ValueKey(record.id),
                    isOpen: _openSwipeRecordId == record.id,
                    gesturesEnabled: _overlayEntry == null,
                    onOpenChanged: (isOpen) {
                      if (!mounted) return;
                      setState(
                        () => _openSwipeRecordId = isOpen ? record.id : null,
                      );
                    },
                    onDeleteTap: () async {
                      _dismissDeleteBubbleIfNeeded();
                      await _confirmDeleteRecord(record);
                    },
                    onLongPress: () {
                      if (_overlayEntry != null) return;
                      if (_openSwipeRecordId != null) {
                        setState(() => _openSwipeRecordId = null);
                      }
                      _showDeleteBubble(rowKey, record);
                    },
                    child: InkWell(
                      key: rowKey,
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
                            ? const Icon(
                                Icons.chevron_right,
                                color: Colors.white54,
                              )
                            : LogNowButton(
                                onTap: () => _openInteractiveOverlay(record),
                              ),
                      ),
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

class _SwipeToDeleteRow extends StatefulWidget {
  const _SwipeToDeleteRow({
    super.key,
    required this.child,
    required this.isOpen,
    required this.gesturesEnabled,
    required this.onOpenChanged,
    required this.onDeleteTap,
    required this.onLongPress,
  });

  final Widget child;
  final bool isOpen;
  final bool gesturesEnabled;
  final ValueChanged<bool> onOpenChanged;
  final Future<void> Function() onDeleteTap;
  final VoidCallback onLongPress;

  @override
  State<_SwipeToDeleteRow> createState() => _SwipeToDeleteRowState();
}

class _SwipeToDeleteRowState extends State<_SwipeToDeleteRow>
    with SingleTickerProviderStateMixin {
  static const double _actionWidth = 64;
  static const Duration _kSnapDuration = Duration(milliseconds: 180);
  static const double _openThreshold = 0.45;

  late final AnimationController _snapController;
  Animation<double>? _snapAnimation;
  double _dragOffset = 0;

  @override
  void initState() {
    super.initState();
    _snapController = AnimationController(
      vsync: this,
      duration: _kSnapDuration,
    );
  }

  @override
  void didUpdateWidget(covariant _SwipeToDeleteRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isOpen != widget.isOpen) {
      _animateTo(widget.isOpen ? _actionWidth : 0);
    }
  }

  @override
  void dispose() {
    _snapController.dispose();
    super.dispose();
  }

  void _animateTo(double target) {
    _snapController.stop();
    _snapAnimation?.removeListener(_handleSnapTick);
    _snapAnimation = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _snapController, curve: Curves.easeOut),
    )..addListener(_handleSnapTick);
    _snapController
      ..value = 0
      ..forward();
  }

  void _handleSnapTick() {
    final animation = _snapAnimation;
    if (animation == null || !mounted) return;
    setState(() => _dragOffset = animation.value);
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (!widget.gesturesEnabled) return;
    final next = (_dragOffset - details.delta.dx).clamp(0.0, _actionWidth);
    if (next != _dragOffset) {
      setState(() => _dragOffset = next);
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (!widget.gesturesEnabled) return;
    final shouldOpen = _dragOffset > _actionWidth * _openThreshold;
    widget.onOpenChanged(shouldOpen);
    _animateTo(shouldOpen ? _actionWidth : 0);
  }

  Future<void> _handleDeleteTap() async {
    if (!widget.gesturesEnabled) return;
    await widget.onDeleteTap();
    widget.onOpenChanged(false);
    _animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    final revealWidth = _dragOffset.clamp(0.0, _actionWidth);
    final isFullyOpen = revealWidth >= _actionWidth - 0.5;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // 底层删除区：仅负责视觉揭示，不承担点击（避免被前景层拦截）
          if (revealWidth > 0)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: revealWidth,
              child: const ColoredBox(color: Color(0xFF0088FF)),
            ),
          // 前景行：deferToChild 让滑开后的右侧区域点击能穿透到底层按钮
          GestureDetector(
            behavior: HitTestBehavior.deferToChild,
            onHorizontalDragUpdate: _onHorizontalDragUpdate,
            onHorizontalDragEnd: _onHorizontalDragEnd,
            onLongPress: widget.gesturesEnabled ? widget.onLongPress : null,
            onTap: isFullyOpen
                ? () {
                    widget.onOpenChanged(false);
                    _animateTo(0);
                  }
                : null,
            child: Transform.translate(
              offset: Offset(-_dragOffset, 0),
              child: widget.child,
            ),
          ),
          // 完全滑开后，在顶层放置可点击垃圾桶（确保点击命中）
          if (isFullyOpen && widget.gesturesEnabled)
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: _actionWidth,
              child: Material(
                color: const Color(0xFF0088FF),
                child: InkWell(
                  onTap: _handleDeleteTap,
                  child: const Center(
                    child: Icon(Icons.delete_outline, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
