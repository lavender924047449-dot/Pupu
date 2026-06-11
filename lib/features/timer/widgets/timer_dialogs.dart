import 'package:flutter/material.dart';
import 'package:pupu/core/widgets/timer_blue_glass_panel.dart';

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
          Positioned(
            left: (293 - 268) / 2,
            top: 34,
            child: SizedBox(
              width: 268,
              height: 43,
              child: Text(
                'You can always log it later in your Log Calendar or Logs.',
                textAlign: TextAlign.center,
                style: const TextStyle(
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
            left: 63,
            top: 19,
            child: Text(
              'Stop timing?',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontFamily: 'SF Pro',
                fontWeight: FontWeight.w300,
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
                    fontSize: 17,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w500,
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
                    fontSize: 17,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w500,
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
