import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pupu/features/private_space/private_space_ui.dart';
import 'package:pupu/features/private_space/private_voice_sheet.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/models/private_note_document.dart';

/// Seamless inline image stack — no section card, matches note paper background.
class InlineImageStack extends StatelessWidget {
  const InlineImageStack({
    super.key,
    required this.images,
    required this.onReorder,
    required this.onDelete,
    this.readOnly = false,
  });

  final List<PrivateImageData> images;
  final void Function(int oldIndex, int newIndex) onReorder;
  final void Function(int index) onDelete;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) return const SizedBox.shrink();

    if (readOnly) {
      return Column(
        children: images
            .map(
              (img) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: AspectRatio(
                    aspectRatio: 1.55,
                    child: _NoteImage(path: img.path),
                  ),
                ),
              ),
            )
            .toList(),
      );
    }

    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: images.length,
      onReorder: onReorder,
      itemBuilder: (context, index) {
        final img = images[index];
        return Padding(
          key: ValueKey(img.id),
          padding: const EdgeInsets.only(bottom: 10),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: AspectRatio(
                  aspectRatio: 1.55,
                  child: _NoteImage(path: img.path),
                ),
              ),
              Positioned(
                top: 6,
                right: 6,
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: _overlayIcon(Icons.drag_indicator),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => onDelete(index),
                      child: _overlayIcon(Icons.close),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _overlayIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black54,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 18, color: Colors.white),
    );
  }
}

class InlineVoiceBubble extends StatefulWidget {
  const InlineVoiceBubble({
    super.key,
    required this.voice,
    required this.onRename,
    this.readOnly = false,
  });

  final PrivateVoiceData voice;
  final VoidCallback onRename;
  final bool readOnly;

  @override
  State<InlineVoiceBubble> createState() => _InlineVoiceBubbleState();
}

class _InlineVoiceBubbleState extends State<InlineVoiceBubble> {
  @override
  void initState() {
    super.initState();
    PrivateVoicePlayer.instance.addListener(_onPlayer);
  }

  @override
  void dispose() {
    PrivateVoicePlayer.instance.removeListener(_onPlayer);
    super.dispose();
  }

  void _onPlayer() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final voice = widget.voice;
    final waveform = voice.waveform.isNotEmpty
        ? voice.waveform
        : const [0.24, 0.52, 0.35, 0.68, 0.4, 0.55];
    final seconds = (voice.durationMs / 1000).round();
    final playing = PrivateVoicePlayer.instance.isPlaying(voice.path);
    final title = (voice.title?.trim().isNotEmpty ?? false)
        ? voice.title!
        : '${seconds}s';

    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: widget.readOnly
            ? null
            : () {
                PrivateSpaceHaptics.menuOpen();
                widget.onRename();
              },
        child: Container(
          constraints: const BoxConstraints(maxWidth: 240),
          padding: const EdgeInsets.fromLTRB(12, 10, 14, 10),
          decoration: BoxDecoration(
            color: const Color(0x55141D2A),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x40D9B34A)),
          ),
          child: Row(
            children: [
              InkWell(
                onTap: widget.readOnly
                    ? null
                    : () => PrivateVoicePlayer.instance.toggle(voice.path),
                customBorder: const CircleBorder(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0x88E2BE57)),
                  ),
                  child: Icon(
                    playing ? Icons.pause : Icons.play_arrow_rounded,
                    color: const Color(0xFFF5E8BF),
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFFF0F3F7),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 16,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: waveform
                            .map(
                              (v) => Container(
                                width: 3,
                                height: 4 + 14 * v,
                                margin: const EdgeInsets.only(right: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xCCE2BE57),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// History list inline preview for mixed blocks.
class HistoryMixedContentPreview extends StatelessWidget {
  const HistoryMixedContentPreview({super.key, required this.entry});

  static const int _maxTextLines = 3;
  static const int _maxImages = 1;
  static const int _maxVoices = 1;
  /// Compact list thumbnail — full images are shown in the editor only.
  static const double _historyImageHeight = 56;

  final PrivateEntry entry;

  @override
  Widget build(BuildContext context) {
    final doc = entry.document;
    if (doc.ops.isEmpty) {
      return const SizedBox.shrink();
    }

    final textParts = <String>[];
    final imageOps = <PrivateDocImageOp>[];
    final voiceOps = <PrivateDocVoiceOp>[];

    for (final op in doc.ops) {
      switch (op) {
        case PrivateDocTextOp(:final text):
          final t = text.trim();
          if (t.isNotEmpty) textParts.add(t);
        case PrivateDocImageOp():
          imageOps.add(op);
        case PrivateDocVoiceOp():
          voiceOps.add(op);
      }
    }

    final mergedText = textParts.join(' ').trim();
    final shownImages = imageOps.take(_maxImages).toList(growable: false);
    final shownVoices = voiceOps.take(_maxVoices).toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mergedText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            mergedText,
            maxLines: _maxTextLines,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFFFFBEB),
              height: 1.5,
            ),
          ),
        ],
        for (final imageOp in shownImages) ...[
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: _historyImageHeight,
              width: double.infinity,
              child: _NoteImage(path: imageOp.image.path),
            ),
          ),
        ],
        for (final voiceOp in shownVoices) ...[
          const SizedBox(height: 8),
          InlineVoiceBubble(
            voice: voiceOp.voice,
            onRename: () {},
            readOnly: true,
          ),
        ],
        if (imageOps.length > shownImages.length || voiceOps.length > shownVoices.length) ...[
          const SizedBox(height: 8),
          Text(
            '+${(imageOps.length - shownImages.length).clamp(0, 99)} image / +${(voiceOps.length - shownVoices.length).clamp(0, 99)} voice',
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
      ],
    );
  }
}

class _NoteImage extends StatelessWidget {
  const _NoteImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover);
    }
    final file = File(path);
    if (!file.existsSync()) {
      return Container(
        color: const Color(0x33141D2A),
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.white38),
        ),
      );
    }
    return Image.file(file, fit: BoxFit.cover);
  }
}
