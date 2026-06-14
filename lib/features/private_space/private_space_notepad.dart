import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pupu/core/app_typography.dart';
import 'package:pupu/features/private_space/private_note_editor.dart';
import 'package:pupu/features/private_space/private_note_document_controller.dart';
import 'package:pupu/models/private_entry.dart';

class PrivateSpaceNotepadStage extends StatelessWidget {
  const PrivateSpaceNotepadStage({
    super.key,
    required this.now,
    required this.docController,
    required this.noteScrollController,
    required this.onBack,
    required this.onUndo,
    required this.onRedo,
    required this.onSave,
    required this.onPickImage,
    required this.onAddVoiceBlock,
    required this.onVoiceRename,
    required this.onVoiceDelete,
    required this.onImageDoubleTap,
    required this.onImageLongPress,
    required this.onImageCopy,
    required this.onImageCut,
    required this.onImageDelete,
    required this.onContentChanged,
  });

  final DateTime now;
  final PrivateNoteDocumentController? docController;
  final ScrollController noteScrollController;
  final VoidCallback onBack;
  final VoidCallback onUndo;
  final VoidCallback onRedo;
  final VoidCallback onSave;
  final VoidCallback onPickImage;
  final VoidCallback onAddVoiceBlock;
  final void Function(int opIndex, PrivateVoiceData voice) onVoiceRename;
  final void Function(int opIndex, PrivateVoiceData voice) onVoiceDelete;
  final void Function(int opIndex, PrivateImageData image) onImageDoubleTap;
  final void Function(int opIndex, PrivateImageData image) onImageLongPress;
  final void Function(int opIndex, PrivateImageData image) onImageCopy;
  final void Function(int opIndex, PrivateImageData image) onImageCut;
  final void Function(int opIndex, PrivateImageData image) onImageDelete;
  final VoidCallback onContentChanged;

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;
    final keyboardVisible = keyboardInset > 0;
    final floatingButtonsBottom = keyboardVisible ? keyboardInset + 14.0 : 92.0;

    return SafeArea(
      key: const ValueKey<String>('notepad'),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Transform.translate(
                offset: const Offset(0, -14),
                child: Container(
                  width: 312,
                  height: 474,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: const Color(0x75E4BD45),
                      width: 1.0,
                    ),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 34,
                        offset: Offset(0, 14),
                      ),
                    ],
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0xD9101926),
                        Color(0xCC0B111B),
                      ],
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _NoteBackgroundGradientPainter(),
                          ),
                        ),
                        Positioned.fill(
                          child: Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x120F223D),
                                  Color(0x0C04070C),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const Positioned.fill(
                          child: IgnorePointer(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment(0.0, 0.08),
                                  radius: 1.0,
                                  colors: [
                                    Color(0x2238648A),
                                    Color(0x1815263D),
                                    Colors.transparent,
                                  ],
                                  stops: [0.0, 0.46, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            children: [
                              Container(
                                height: 56,
                                alignment: Alignment.bottomCenter,
                                padding: const EdgeInsets.only(bottom: 10),
                                decoration: const BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Color(0x6ED9B34A),
                                      width: 1.0,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      DateFormat('yyyy / MM / dd').format(now),
                                      style: AppTypography.body(
                                        color: const Color(0x9FD6D9DE),
                                        size: 13,
                                        letterSpacing: 0.6,
                                      ),
                                    ),
                                    Text(
                                      DateFormat('HH:mm').format(now),
                                      style: AppTypography.body(
                                        color: const Color(0x9FD6D9DE),
                                        size: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 14,
                                          bottom: 12,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(2),
                                          child: ImageFiltered(
                                            imageFilter: ImageFilter.blur(
                                              sigmaX: 14,
                                              sigmaY: 14,
                                            ),
                                            child: Opacity(
                                              opacity: 0.18,
                                              child: ColorFiltered(
                                                colorFilter: const ColorFilter.mode(
                                                  Color(0xCC0F1A28),
                                                  BlendMode.srcATop,
                                                ),
                                                child: Image.asset(
                                                  'assets/images/child.png',
                                                  fit: BoxFit.cover,
                                                  alignment: Alignment.center,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (docController != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: 14,
                                          bottom: 100,
                                        ),
                                        child: PrivateNoteEditor(
                                          controller: docController!,
                                          scrollController: noteScrollController,
                                          enabled: true,
                                          onVoiceRename: onVoiceRename,
                                          onVoiceDelete: onVoiceDelete,
                                          onImageDoubleTap: onImageDoubleTap,
                                          onImageLongPress: onImageLongPress,
                                          onImageCopy: onImageCopy,
                                          onImageCut: onImageCut,
                                          onImageDelete: onImageDelete,
                                          onContentChanged: onContentChanged,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 28,
            top: 28,
            child: SafeArea(
              child: _NotepadCircleIconButton(
                icon: Icons.chevron_left,
                onTap: onBack,
                compact: true,
              ),
            ),
          ),
          if (docController != null && !docController!.isEmpty)
            Positioned(
              right: 16,
              top: 8,
              child: SafeArea(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _NotepadCircleIconButton(
                      icon: Icons.undo,
                      onTap: onUndo,
                      compact: true,
                      enabled: docController!.canUndo,
                    ),
                    const SizedBox(width: 8),
                    _NotepadCircleIconButton(
                      icon: Icons.redo,
                      onTap: onRedo,
                      compact: true,
                      enabled: docController!.canRedo,
                    ),
                    const SizedBox(width: 8),
                    _NotepadCircleIconButton(
                      icon: Icons.check,
                      onTap: onSave,
                      highlighted: true,
                    ),
                  ],
                ),
              ),
            ),
          AnimatedPositioned(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            left: 0,
            right: 0,
            bottom: floatingButtonsBottom,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _NotepadCircleIconButton(
                  icon: Icons.image_outlined,
                  onTap: onPickImage,
                  compact: true,
                  mini: keyboardVisible,
                ),
                SizedBox(width: keyboardVisible ? 10 : 20),
                _NotepadCircleIconButton(
                  icon: Icons.mic_none,
                  onTap: onAddVoiceBlock,
                  compact: true,
                  mini: keyboardVisible,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotepadCircleIconButton extends StatelessWidget {
  const _NotepadCircleIconButton({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
    this.compact = false,
    this.mini = false,
    this.enabled = true,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;
  final bool compact;
  final bool mini;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final buttonSize = mini ? 34.0 : (compact ? 44.0 : 46.0);
    final iconSize = mini ? 16.0 : (compact ? 20.0 : 24.0);

    return Opacity(
      opacity: enabled ? 1 : 0.35,
      child: Material(
        color: highlighted
            ? const Color(0x301C2430)
            : const Color(0x2A111A24),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: buttonSize,
            height: buttonSize,
            decoration: BoxDecoration(
              border: Border.all(
                color: highlighted
                    ? const Color(0xA9E2BE57)
                    : const Color(0x82BC983A),
                width: 1,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0x669F7B24).withValues(
                    alpha: highlighted ? 0.18 : 0.10,
                  ),
                  blurRadius: mini ? 8 : (compact ? 10 : 12),
                ),
              ],
            ),
            child: Icon(
              icon,
              size: iconSize,
              color: highlighted
                  ? const Color(0xFFF5E8BF)
                  : const Color(0xFFE2BE57),
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteBackgroundGradientPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final gradient1 = RadialGradient(
      center: const Alignment(0, -0.6),
      radius: 1.5,
      colors: [
        const Color(0xFFFFDC64).withValues(alpha: 0.25),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4],
    );

    final gradient2 = RadialGradient(
      center: const Alignment(0, -0.6),
      radius: 1.5,
      colors: [
        Colors.white.withValues(alpha: 0.15),
        Colors.transparent,
      ],
      stops: const [0.0, 0.4],
    );

    final paint1 = Paint()..shader = gradient1.createShader(Offset.zero & size);
    final paint2 = Paint()..shader = gradient2.createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint1);
    canvas.drawRect(Offset.zero & size, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
