/// 音频 Provider
/// 计时页：本地播放、单曲循环

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pupu/features/timer/widgets/audio_picker.dart';

/// 音频播放器实例
final audioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => player.dispose());
  return player;
});

/// 计时页音频引擎：仅负责 play/stop，不持有 UI 选中态。
class TimerAudioService {
  TimerAudioService(this._player);

  final AudioPlayer _player;

  /// 播放指定曲目（单曲 loop）；index 无效时等同 [stop]。
  Future<void> playTrack(int index) async {
    final pathCandidates = timerAudioAssetPathCandidates(index);
    if (pathCandidates.isEmpty) {
      await stop();
      return;
    }

    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      Object? lastError;
      StackTrace? lastStack;
      for (final candidate in pathCandidates) {
        try {
          await _player.play(AssetSource(candidate));
          return;
        } catch (e, st) {
          lastError = e;
          lastStack = st;
        }
      }
      debugPrint(
        'TimerAudioService.playTrack($index) failed, candidates: $pathCandidates, error: $lastError\n$lastStack',
      );
    } catch (e, st) {
      debugPrint('TimerAudioService.playTrack($index) failed: $e\n$st');
    }
  }

  /// 停止当前播放。
  Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e, st) {
      debugPrint('TimerAudioService.stop failed: $e\n$st');
    }
  }
}

final timerAudioServiceProvider = Provider<TimerAudioService>((ref) {
  return TimerAudioService(ref.watch(audioPlayerProvider));
});
