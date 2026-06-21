import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pupu/core/widgets/app_glass_dialog.dart';
import 'package:pupu/providers/records_provider.dart';
import 'package:pupu/services/local_storage.dart';

// 与 Private Space Select Category 删除气泡一致的内边距与圆角。
const double _kDeleteBubbleHorizontalPadding = 14;
const double _kDeleteBubbleVerticalPadding = 10;
const double _kDeleteBubbleBorderRadius = 14;
const double _kDeleteBubbleGap = 8;

/// 图标 + "Delete" 文案，布局对齐 Private Space 删除气泡。
Widget deleteBubbleContent({Color foregroundColor = Colors.white}) {
  return Padding(
    padding: const EdgeInsets.symmetric(
      horizontal: _kDeleteBubbleHorizontalPadding,
      vertical: _kDeleteBubbleVerticalPadding,
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.delete_outline, color: foregroundColor, size: 18),
        const SizedBox(width: 8),
        Text(
          'Delete',
          style: TextStyle(
            color: foregroundColor,
            fontWeight: FontWeight.w600,
            fontFamily: 'SF Pro',
          ),
        ),
      ],
    ),
  );
}

Size _measureDeleteBubbleSize() {
  final painter = TextPainter(
    text: const TextSpan(
      text: 'Delete',
      style: TextStyle(
        fontWeight: FontWeight.w600,
        fontFamily: 'SF Pro',
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = _kDeleteBubbleHorizontalPadding * 2 + 18 + 8 + painter.width;
  const height = _kDeleteBubbleVerticalPadding * 2 + 18;
  return Size(width.ceilToDouble(), height);
}

/// 长按后显示的删除气泡。
///
/// 返回一个可调用的 dismiss 回调，调用方应在页面 dispose 时执行，避免残留 overlay。
VoidCallback showDeleteBubble({
  required BuildContext context,
  required GlobalKey targetKey,
  required Future<void> Function() onDeleteTap,
}) {
  final targetContext = targetKey.currentContext;
  final overlay = Overlay.of(context, rootOverlay: true);
  if (targetContext == null || overlay.mounted == false) {
    return () {};
  }
  final targetBox = targetContext.findRenderObject() as RenderBox?;
  final overlayBox = overlay.context.findRenderObject() as RenderBox?;
  if (targetBox == null || overlayBox == null) {
    return () {};
  }

  final bubbleSize = _measureDeleteBubbleSize();
  final targetTopLeft = targetBox.localToGlobal(
    Offset.zero,
    ancestor: overlayBox,
  );
  final targetSize = targetBox.size;
  final maxLeft = (overlayBox.size.width - bubbleSize.width)
      .clamp(0, double.infinity)
      .toDouble();
  final left =
      (targetTopLeft.dx + targetSize.width / 2 - bubbleSize.width / 2)
          .clamp(0.0, maxLeft)
          .toDouble();
  final top = (targetTopLeft.dy - bubbleSize.height - _kDeleteBubbleGap)
      .clamp(8.0, double.infinity)
      .toDouble();

  late final OverlayEntry entry;
  bool removed = false;

  void removeEntry() {
    if (removed) return;
    removed = true;
    entry.remove();
  }

  entry = OverlayEntry(
    builder: (ctx) => Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: removeEntry,
          ),
        ),
        Positioned(
          left: left,
          top: top,
          child: Material(
            type: MaterialType.transparency,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xFF0088FF),
                borderRadius:
                    BorderRadius.circular(_kDeleteBubbleBorderRadius),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: InkWell(
                borderRadius:
                    BorderRadius.circular(_kDeleteBubbleBorderRadius),
                onTap: () async {
                  removeEntry();
                  await onDeleteTap();
                },
                child: deleteBubbleContent(),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  HapticFeedback.mediumImpact();
  overlay.insert(entry);
  return removeEntry;
}

/// 删除确认弹窗：沿用 Private Space 的文案排布（标题 + 双按钮），视觉改为 Timer 液体玻璃。
Future<bool?> showRecordDeleteConfirmDialog({required BuildContext context}) {
  return showAppGlassDialog<bool>(
    context,
    barrierDismissible: false,
    useRootNavigator: true,
    child: Builder(
      builder: (dialogContext) => AppGlassDialog.confirm(
        title: 'Delete Log?',
        leftLabel: 'Cancel',
        rightLabel: 'Delete',
        onNo: () => Navigator.of(dialogContext).pop(false),
        onYes: () => Navigator.of(dialogContext).pop(true),
      ),
    ),
  );
}

Future<void> deleteRecordAndRefresh(WidgetRef ref, String recordId) async {
  await LocalStorage.deleteRecord(recordId);
  bumpRecordsRefresh(ref);
}
