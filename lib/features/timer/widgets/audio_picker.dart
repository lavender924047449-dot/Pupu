import 'package:flutter/material.dart';

import 'package:pupu/core/widgets/liquid_glass_background.dart';

/// 音频曲目列表。索引即业务 ID：0 表示 No Audio。
const List<String> kTimerAudioTracks = [
  'No Audio',
  'Guided Belly Breathing - Female',
  'Guided Belly Breathing - Male',
  'Rain Sounds - Classical',
  'Binaural Beats - Rain',
  'Brainwaves - Hz Music',
  'Nature - Hz - Flute',
  'Hz Frequencies - Flowing Water',
  'Singing Bowl - Flowing Water',
  'Singing Bowl - Ocean Waves',
  'Inner Peace - Relaxation',
  'Healing - Tranquility',
];

/// 允许按固定文件名映射资源，避免 UI 文案调整导致资源路径失配。
const List<String> kTimerAudioAssetNames = [
  '',
  'Guided Belly Breathing - Female',
  'Guided Belly Breathing - Male',
  'Rain Sounds - Classical',
  'Binaural Beats - Rain',
  'Brainwaves - Hz Music',
  'Nature - Hz - Flute',
  'Hz Frequencies - Flowing Water',
  'Singing Bowl - Flowing Water',
  'Singing Bowl - Ocean Waves',
  'Inner Peace - Relaxation',
  'Healing - Tranquility',
];

/// 将曲目索引映射为 audioplayers [AssetSource] 路径。
/// index 0（No Audio）或越界时返回 null。
String? timerAudioAssetPath(int index) {
  if (index <= 0 || index >= kTimerAudioAssetNames.length) return null;
  return 'audio/${kTimerAudioAssetNames[index]}.mp3';
}

/// 返回候选资源路径（用于兼容历史文件命名差异）。
List<String> timerAudioAssetPathCandidates(int index) {
  final primary = timerAudioAssetPath(index);
  if (primary == null) return const [];
  final base = primary.replaceFirst('audio/', '').replaceFirst('.mp3', '');
  final candidates = <String>{
    primary,
    'audio/${base.replaceAll(' - ', '-').trim()}.mp3',
    'audio/${base.replaceAll(' ', '_')}.mp3',
    'audio/${base.replaceAll(' ', '')}.mp3',
  };
  return candidates.toList();
}

/// 计时页右侧的音乐按钮，旋转状态由父级控制。
class TimerMusicButton extends StatelessWidget {
  const TimerMusicButton({
    super.key,
    required this.rotationAnimation,
    required this.onTap,
  });

  final Animation<double> rotationAnimation;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: rotationAnimation,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 33,
          height: 33,
          decoration: ShapeDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(1000),
            ),
          ),
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: ShapeDecoration(
                    // 与 timer_screen.dart 中 _actionButton 的按钮底座样式保持一致。
                    color: Colors.white.withValues(alpha: 0.07),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(1000),
                    ),
                    shadows: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 40,
                        offset: Offset(0, 8),
                        spreadRadius: 0,
                      )
                    ],
                  ),
                ),
              ),
              const Center(
                child: Text(
                  '🎵',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontFamily: 'SF Pro',
                    fontWeight: FontWeight.w600,
                    height: 1.16,
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

/// 全屏音频选择层：包含 scrim 与玻璃面板。
class AudioPickerLayer extends StatelessWidget {
  const AudioPickerLayer({
    super.key,
    required this.isOpen,
    required this.panelAnimation,
    required this.selectedIndex,
    required this.onClose,
    required this.onSelect,
    required this.screenSize,
  });

  final bool isOpen;
  final Animation<double> panelAnimation;
  final int? selectedIndex;
  final VoidCallback onClose;
  final ValueChanged<int> onSelect;
  final Size screenSize;

  @override
  Widget build(BuildContext context) {
    if (!isOpen) return const SizedBox.shrink();

    final xScale = screenSize.width / 393;
    final yScale = screenSize.height / 852;
    double sx(double value) => value * xScale;
    double sy(double value) => value * yScale;

    final panelWidth = sx(289);
    final panelHeight = sy(414);
    final panelTop = sy(228);

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onClose,
            child: Container(color: Colors.black.withValues(alpha: 0.25)),
          ),
        ),
        Positioned(
          top: panelTop,
          left: (screenSize.width - panelWidth) / 2,
          width: panelWidth,
          height: panelHeight,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: panelAnimation,
              curve: Curves.easeInOut,
            ),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.96, end: 1.0).animate(
                CurvedAnimation(
                  parent: panelAnimation,
                  curve: Curves.easeInOut,
                ),
              ),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {},
                child: Stack(
                  children: [
                    const Positioned.fill(child: LiquidGlassBackground()),
                    Positioned.fill(
                      child: Padding(
                        padding: EdgeInsets.only(top: sy(20)),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: SizedBox(
                            width: sx(255),
                            child: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Choose an audio you like:',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontFamily: 'Josefin Sans',
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  SizedBox(height: sy(8)),
                                  ...List.generate(kTimerAudioTracks.length, (index) {
                                    final isSelected = selectedIndex == index;
                                    return _AudioTrackTile(
                                      label: kTimerAudioTracks[index],
                                      selected: isSelected,
                                      onTap: () => onSelect(index),
                                    );
                                  }),
                                  SizedBox(height: sy(14)),
                                ],
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
          ),
        ),
      ],
    );
  }
}

class _AudioTrackTile extends StatelessWidget {
  const _AudioTrackTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Container(
            width: double.infinity,
            decoration: selected
                ? BoxDecoration(
                    color: const Color(0xFF0088FF),
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '· ',
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.92),
                      fontSize: 14,
                      fontFamily: 'SF Pro',
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  TextSpan(
                    text: label,
                    style: TextStyle(
                      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.92),
                      fontSize: 14,
                      fontFamily: 'SF Pro',
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
