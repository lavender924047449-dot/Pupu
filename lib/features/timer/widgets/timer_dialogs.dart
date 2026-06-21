import 'package:flutter/material.dart';
import 'package:pupu/core/widgets/app_glass_dialog.dart';

/// 统一 Timer 页玻璃弹窗挂载（maybe later 同款 barrier / Dialog）。
Future<void> showTimerGlassDialog(
  BuildContext context, {
  required Widget child,
  int? autoDismissSeconds,
}) {
  return showAppGlassDialog<void>(
    context,
    child: child,
    autoDismissSeconds: autoDismissSeconds,
    barrierColor: Colors.black.withValues(alpha: 0.4),
  );
}

/// 系统返回 / Stop 中途退出：Cancel 左 / Leave 右。
class TimerLeaveTimerConfirmDialog extends StatelessWidget {
  const TimerLeaveTimerConfirmDialog({
    super.key,
    required this.onLeave,
    required this.onCancel,
  });

  final VoidCallback onLeave;
  final VoidCallback onCancel;

  void _dismissCancel(BuildContext context) {
    Navigator.of(context).pop();
    onCancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _dismissCancel(context);
      },
      child: AppGlassDialog.confirm(
        title: 'Leave Timer?',
        message: 'This session won\'t be saved.',
        leftLabel: 'Cancel',
        rightLabel: 'Leave',
        onNo: () => _dismissCancel(context),
        onYes: () {
          Navigator.of(context).pop();
          onLeave();
        },
      ),
    );
  }
}

/// 问卷未完成时系统返回：Cancel 左 / Leave 右（回 Session Summary）。
class TimerQuestionnaireLeaveConfirmDialog extends StatelessWidget {
  const TimerQuestionnaireLeaveConfirmDialog({
    super.key,
    required this.onLeave,
    required this.onCancel,
  });

  final VoidCallback onLeave;
  final VoidCallback onCancel;

  void _dismissCancel(BuildContext context) {
    Navigator.of(context).pop();
    onCancel();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _dismissCancel(context);
      },
      child: AppGlassDialog.confirm(
        title: 'You haven\'t finished logging.\n\nLeave anyway?',
        leftLabel: 'Cancel',
        rightLabel: 'Leave',
        onNo: () => _dismissCancel(context),
        onYes: () {
          Navigator.of(context).pop();
          onLeave();
        },
      ),
    );
  }
}

/// 必做多选空选 Next 时的无按钮警示。
class TimerSelectOptionAlertDialog extends StatelessWidget {
  const TimerSelectOptionAlertDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AppGlassDialog.alert(
      title: 'Selection Required',
      message: 'Please select an option.',
    );
  }
}

/// Finish Logging 确认：Cancel 左 / Finish 右。
class TimerFinishSessionDialog extends StatelessWidget {
  const TimerFinishSessionDialog({
    super.key,
    required this.onYes,
    required this.onNo,
  });

  final VoidCallback onYes;
  final VoidCallback onNo;

  void _dismissNo(BuildContext context) {
    Navigator.of(context).pop();
    onNo();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _dismissNo(context);
      },
      child: AppGlassDialog.confirm(
        title: 'Finish Logging?',
        leftLabel: 'Cancel',
        rightLabel: 'Finish',
        onNo: () => _dismissNo(context),
        onYes: () {
          Navigator.of(context).pop();
          onYes();
        },
      ),
    );
  }
}

class TimerMaybeLaterDialog extends StatelessWidget {
  const TimerMaybeLaterDialog({
    super.key,
    required this.onGotIt,
  });

  final Future<void> Function() onGotIt;

  @override
  Widget build(BuildContext context) {
    return AppGlassDialog.single(
      title: 'You can always log it later',
      message: 'Find it in your Log Calendar or Logs.',
      buttonLabel: 'Back to Home',
      onTap: () async {
        await onGotIt();
      },
    );
  }
}

class TimerStopConfirmDialog extends StatelessWidget {
  const TimerStopConfirmDialog({
    super.key,
    required this.onYes,
    required this.onNo,
  });

  final VoidCallback onYes;
  final VoidCallback onNo;

  void _dismissNo(BuildContext context) {
    Navigator.of(context).pop();
    onNo();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _dismissNo(context);
      },
      child: AppGlassDialog.confirm(
        title: 'Stop Timer?',
        leftLabel: 'Cancel',
        rightLabel: 'Stop',
        onNo: () => _dismissNo(context),
        onYes: () {
          Navigator.of(context).pop();
          onYes();
        },
      ),
    );
  }
}
