import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pupu/core/widgets/timer_blue_glass_panel.dart';

/// 统一 Timer 页玻璃弹窗挂载（maybe later 同款 barrier / Dialog）。
Future<void> showTimerGlassDialog(
  BuildContext context, {
  required Widget child,
  int? autoDismissSeconds,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.4),
    builder: (dialogContext) {
      if (autoDismissSeconds != null) {
        return _AutoDismissGlassDialogWrapper(
          seconds: autoDismissSeconds,
          child: child,
        );
      }
      return Dialog(
        backgroundColor: Colors.transparent,
        child: child,
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
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: widget.child,
    );
  }
}

/// 必做多选空选 Next 时的无按钮警示。
class TimerSelectOptionAlertDialog extends StatelessWidget {
  const TimerSelectOptionAlertDialog({super.key});

  static const _panelWidth = 293.0;
  static const _panelHeight = 120.0;

  @override
  Widget build(BuildContext context) {
    return const TimerBlueGlassPanel(
      width: _panelWidth,
      height: _panelHeight,
      child: Center(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Please select an option',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontFamily: 'SF Pro',
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

/// Finish Logging 确认：No 左 / Yes 右。
class TimerFinishSessionDialog extends StatefulWidget {
  const TimerFinishSessionDialog({
    super.key,
    required this.onYes,
    required this.onNo,
  });

  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  State<TimerFinishSessionDialog> createState() => _TimerFinishSessionDialogState();
}

class _TimerFinishSessionDialogState extends State<TimerFinishSessionDialog> {
  bool _yesPressed = false;
  bool _noPressed = false;

  @override
  Widget build(BuildContext context) {
    return TimerBlueGlassPanel(
      width: 293,
      height: 173,
      child: Stack(
        children: [
          const Positioned.fill(
            bottom: 56,
            child: Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Are you sure you are finished?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 48,
            bottom: 40,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _noPressed = true),
              onTapUp: (_) => setState(() => _noPressed = false),
              onTapCancel: () => setState(() => _noPressed = false),
              onTap: () {
                Navigator.of(context).pop();
                widget.onNo();
              },
              child: Opacity(
                opacity: _noPressed ? 0.6 : 1.0,
                child: const Text(
                  'No',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            right: 48,
            bottom: 40,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _yesPressed = true),
              onTapUp: (_) => setState(() => _yesPressed = false),
              onTapCancel: () => setState(() => _yesPressed = false),
              onTap: () {
                Navigator.of(context).pop();
                widget.onYes();
              },
              child: Opacity(
                opacity: _yesPressed ? 0.6 : 1.0,
                child: const Text(
                  'Yes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TimerMaybeLaterDialog extends StatefulWidget {
  const TimerMaybeLaterDialog({
    super.key,
    required this.onGotIt,
  });

  final Future<void> Function() onGotIt;

  @override
  State<TimerMaybeLaterDialog> createState() => _TimerMaybeLaterDialogState();
}

class _TimerMaybeLaterDialogState extends State<TimerMaybeLaterDialog> {
  bool _gotItPressed = false;

  @override
  Widget build(BuildContext context) {
    return TimerBlueGlassPanel(
      width: 293,
      height: 173,
      child: Stack(
        children: [
          const Positioned(
            left: (293 - 268) / 2,
            top: 34,
            child: SizedBox(
              width: 268,
              height: 43,
              child: Text(
                'You can always log it later in your Log Calendar or Logs.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontFamily: 'SF Pro',
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 40,
            child: Center(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (_) => setState(() => _gotItPressed = true),
                onTapUp: (_) => setState(() => _gotItPressed = false),
                onTapCancel: () => setState(() => _gotItPressed = false),
                onTap: () async {
                  await widget.onGotIt();
                },
                child: Opacity(
                  opacity: _gotItPressed ? 0.6 : 1.0,
                  child: const Text(
                    'Got it(Back to Home)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class TimerStopConfirmDialog extends StatefulWidget {
  const TimerStopConfirmDialog({
    super.key,
    required this.onYes,
    required this.onNo,
  });

  final VoidCallback onYes;
  final VoidCallback onNo;

  @override
  State<TimerStopConfirmDialog> createState() => _TimerStopConfirmDialogState();
}

class _TimerStopConfirmDialogState extends State<TimerStopConfirmDialog> {
  bool _yesPressed = false;
  bool _noPressed = false;

  @override
  Widget build(BuildContext context) {
    return TimerBlueGlassPanel(
      width: 269,
      height: 125,
      child: Stack(
        children: [
          const Positioned(
            left: 84,
            top: 28,
            child: Text(
              'Stop timing?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Positioned(
            left: 48,
            top: 77,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _yesPressed = true),
              onTapUp: (_) => setState(() => _yesPressed = false),
              onTapCancel: () => setState(() => _yesPressed = false),
              onTap: () {
                Navigator.of(context).pop();
                widget.onYes();
              },
              child: Opacity(
                opacity: _yesPressed ? 0.6 : 1.0,
                child: const Text(
                  'Yes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 199,
            top: 77,
            child: GestureDetector(
              onTapDown: (_) => setState(() => _noPressed = true),
              onTapUp: (_) => setState(() => _noPressed = false),
              onTapCancel: () => setState(() => _noPressed = false),
              onTap: () {
                Navigator.of(context).pop();
                widget.onNo();
              },
              child: Opacity(
                opacity: _noPressed ? 0.6 : 1.0,
                child: const Text(
                  'No',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
