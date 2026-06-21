import 'package:flutter/material.dart';

class WarmSentenceOverlay extends StatelessWidget {
  const WarmSentenceOverlay({
    super.key,
    required this.animation,
    required this.text,
  });

  final Animation<double> animation;
  final String text;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: FadeTransition(
        opacity: animation,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: IntrinsicWidth(
            child: Text(
              text,
              textAlign: TextAlign.left,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.90),
                fontSize: 18,
                fontFamily: 'Josefin Sans',
                fontWeight: FontWeight.w300,
                height: 1.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
