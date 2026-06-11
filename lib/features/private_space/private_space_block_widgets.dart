import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pupu/models/private_entry.dart';

class DraftImageGroupCard extends StatelessWidget {
  const DraftImageGroupCard({super.key, required this.block});

  final PrivateContentBlock block;

  @override
  Widget build(BuildContext context) {
    final images = block.images;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0x24141D2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x55D9B34A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.photo_library_outlined, color: Color(0xFFE2BE57), size: 18),
              SizedBox(width: 8),
              Text(
                'Image stack',
                style: TextStyle(
                  color: Color(0xFFF6E6B3),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...images.map(
            (image) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 1.55,
                  child: _BlockImage(path: image.path),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class DraftVoiceCard extends StatelessWidget {
  const DraftVoiceCard({super.key, required this.block});

  final PrivateContentBlock block;

  @override
  Widget build(BuildContext context) {
    final voice = block.voice;
    final waveform = voice?.waveform ?? const [0.24, 0.52, 0.35, 0.68];
    final seconds = ((voice?.durationMs ?? 0) / 1000).round();

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 230),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: const Color(0xCC17212E),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0x55D9B34A)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x22E2BE57),
                border: Border.all(color: const Color(0x88E2BE57)),
              ),
              child: const Icon(
                Icons.play_arrow_rounded,
                color: Color(0xFFF5E8BF),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (voice?.title?.trim().isNotEmpty ?? false)
                        ? voice!.title!
                        : 'Voice ${seconds}s',
                    style: const TextStyle(
                      color: Color(0xFFF6E6B3),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 18,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: waveform
                          .map(
                            (value) => Container(
                              width: 4,
                              height: max(4, 18 * value),
                              margin: const EdgeInsets.only(right: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE2BE57),
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
    );
  }
}

class HistoryBlockBadge extends StatelessWidget {
  const HistoryBlockBadge({super.key, required this.type});

  final PrivateBlockType type;

  @override
  Widget build(BuildContext context) {
    final (icon, label) = switch (type) {
      PrivateBlockType.image => (Icons.photo_outlined, 'Image'),
      PrivateBlockType.voice => (Icons.mic_none, 'Voice'),
      PrivateBlockType.text => (Icons.notes_outlined, 'Text'),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0x30E2BE57)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFE2BE57)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockImage extends StatelessWidget {
  const _BlockImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    if (path.startsWith('assets/')) {
      return Image.asset(path, fit: BoxFit.cover);
    }
    if (path.startsWith('http')) {
      return Image.network(path, fit: BoxFit.cover);
    }
    return Image.file(File(path), fit: BoxFit.cover);
  }
}
