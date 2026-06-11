import 'dart:ui';

import 'package:flutter/material.dart';

/// 284×406 问卷浮层：点遮罩关闭；支持 easeInOut 淡出收起。
class QuestionnaireOverlay extends StatefulWidget {
  final Widget child;
  final VoidCallback onDismiss;

  const QuestionnaireOverlay({
    super.key,
    required this.child,
    required this.onDismiss,
  });

  @override
  State<QuestionnaireOverlay> createState() => QuestionnaireOverlayState();
}

class QuestionnaireOverlayState extends State<QuestionnaireOverlay>
    with SingleTickerProviderStateMixin {
  static const Duration dismissDuration = Duration(milliseconds: 500);

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;
  bool _isAnimatingOut = false;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: dismissDuration,
      value: 1,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  /// [animated] 为 true 时执行 0.5s easeInOut 淡出后再触发 [onDismiss]。
  Future<void> dismiss({bool animated = false}) async {
    if (_isAnimatingOut) return;
    if (!animated) {
      widget.onDismiss();
      return;
    }
    _isAnimatingOut = true;
    await _fadeController.animateTo(0, curve: Curves.easeInOut);
    if (!mounted) return;
    widget.onDismiss();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        dismiss();
      },
      child: Material(
        type: MaterialType.transparency,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () => dismiss(),
                  child: const SizedBox.expand(),
                ),
              ),
              Center(
                child: GestureDetector(
                  onTap: () {},
                  child: SizedBox(
                    width: 284,
                    height: 406,
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
                                child: Padding(
                                  // Leave breathing room so inner scrollables do not
                                  // start exactly at clipped border edges.
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: widget.child,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
