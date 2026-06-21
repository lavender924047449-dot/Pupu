import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pupu/core/app_typography.dart';
import 'package:pupu/core/widgets/timer_blue_glass_panel.dart';

enum AppGlassDialogMode { confirm, single, alert }

/// 全局统一蓝色玻璃弹框（Log Calendar 删除确认同款视觉）。
///
/// 支持三种模式：[AppGlassDialog.confirm]、[AppGlassDialog.single]、[AppGlassDialog.alert]。
class AppGlassDialog extends StatelessWidget {
  const AppGlassDialog._({
    required this.title,
    required this.mode,
    this.message,
    this.leftLabel,
    this.rightLabel,
    this.onLeft,
    this.onRight,
    this.singleLabel,
    this.onSingle,
  });

  /// 双按钮：Cancel 左 / 主操作右；可选 [message] 作为 title 下方灰色正文。
  factory AppGlassDialog.confirm({
    required String title,
    String? message,
    String leftLabel = 'Cancel',
    String rightLabel = 'Delete',
    required VoidCallback onNo,
    required VoidCallback onYes,
  }) {
    return AppGlassDialog._(
      title: title,
      message: message,
      mode: AppGlassDialogMode.confirm,
      leftLabel: leftLabel,
      rightLabel: rightLabel,
      onLeft: onNo,
      onRight: onYes,
    );
  }

  /// 单按钮：整行一个主操作按钮；可选 [message] 作为 title 下方正文。
  factory AppGlassDialog.single({
    required String title,
    String? message,
    required String buttonLabel,
    required VoidCallback onTap,
  }) {
    return AppGlassDialog._(
      title: title,
      message: message,
      mode: AppGlassDialogMode.single,
      singleLabel: buttonLabel,
      onSingle: onTap,
    );
  }

  /// 无按钮：纯提示文案；可选 [message] 作为 title 下方正文。
  factory AppGlassDialog.alert({
    required String title,
    String? message,
  }) {
    return AppGlassDialog._(
      title: title,
      message: message,
      mode: AppGlassDialogMode.alert,
    );
  }

  final String title;
  final String? message;
  final AppGlassDialogMode mode;
  final String? leftLabel;
  final String? rightLabel;
  final VoidCallback? onLeft;
  final VoidCallback? onRight;
  final String? singleLabel;
  final VoidCallback? onSingle;

  /// 双按钮默认不可点遮罩关闭；单按钮/纯提示默认可关闭。
  bool get barrierDismissible => mode != AppGlassDialogMode.confirm;

  static const _titlePadding = EdgeInsets.fromLTRB(16, 20, 16, 12);
  static const _messagePadding = EdgeInsets.fromLTRB(16, 0, 16, 20);
  static const _actionRowHeight = 44.0;

  static final TextStyle _messageStyle = AppTypography.body(
    size: 15,
    color: const Color(0xFFC6C6C8),
  );

  @override
  Widget build(BuildContext context) {
    return TimerBlueGlassPanel(
      borderRadius: BorderRadius.circular(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: message == null
                ? const EdgeInsets.fromLTRB(16, 20, 16, 20)
                : _titlePadding,
            child: SizedBox(
              width: double.infinity,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.dialogTitle(
                  color: const Color(0xFFE6F0FF),
                ),
              ),
            ),
          ),
          if (message != null)
            Padding(
              padding: _messagePadding,
              child: SizedBox(
                width: double.infinity,
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: _messageStyle,
                ),
              ),
            ),
          if (mode == AppGlassDialogMode.confirm) _buildConfirmActions(),
          if (mode == AppGlassDialogMode.single) _buildSingleAction(),
        ],
      ),
    );
  }

  Widget _buildConfirmActions() {
    return SizedBox(
      height: _actionRowHeight,
      child: Row(
        children: [
          Expanded(
            child: _DialogActionButton(
              label: leftLabel!,
              style: AppTypography.body(
                size: 17,
                weight: FontWeight.w400,
                color: Colors.white70,
              ),
              onTap: onLeft!,
            ),
          ),
          Expanded(
            child: _DialogActionButton(
              label: rightLabel!,
              style: AppTypography.body(
                size: 17,
                weight: FontWeight.w600,
                color: const Color(0xFF0088FF),
              ),
              onTap: onRight!,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleAction() {
    return SizedBox(
      height: _actionRowHeight,
      child: Row(
        children: [
          Expanded(
            child: _DialogActionButton(
              label: singleLabel!,
              style: AppTypography.body(
                size: 17,
                weight: FontWeight.w600,
                color: const Color(0xFF0088FF),
              ),
              onTap: onSingle!,
            ),
          ),
        ],
      ),
    );
  }
}

/// 挂载 [AppGlassDialog] 的统一 showDialog 入口。
Future<T?> showAppGlassDialog<T>(
  BuildContext context, {
  required Widget child,
  bool? barrierDismissible,
  bool useRootNavigator = false,
  int? autoDismissSeconds,
  Color? barrierColor,
}) {
  final resolvedDismissible = barrierDismissible ??
      (child is AppGlassDialog ? child.barrierDismissible : true);

  return showDialog<T>(
    context: context,
    barrierDismissible: resolvedDismissible,
    useRootNavigator: useRootNavigator,
    barrierColor: barrierColor,
    builder: (dialogContext) {
      final shell = Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 52),
        child: child,
      );

      if (autoDismissSeconds == null) {
        return shell;
      }

      return _AutoDismissGlassDialogWrapper(
        seconds: autoDismissSeconds,
        child: shell,
      );
    },
  );
}

class _AutoDismissGlassDialogWrapper extends StatefulWidget {
  const _AutoDismissGlassDialogWrapper({
    required this.seconds,
    required this.child,
  });

  final int seconds;
  final Widget child;

  @override
  State<_AutoDismissGlassDialogWrapper> createState() =>
      _AutoDismissGlassDialogWrapperState();
}

class _AutoDismissGlassDialogWrapperState
    extends State<_AutoDismissGlassDialogWrapper> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(Duration(seconds: widget.seconds), () {
      if (mounted) Navigator.of(context).pop();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _DialogActionButton extends StatelessWidget {
  const _DialogActionButton({
    required this.label,
    required this.style,
    required this.onTap,
  });

  final String label;
  final TextStyle style;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Center(
          child: Text(label, style: style, textAlign: TextAlign.center),
        ),
      ),
    );
  }
}
