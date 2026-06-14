import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pupu/features/home/home_music.dart';

/// Home 音乐播放器（与 Timer 独立，避免互相抢播）。
final homeAudioPlayerProvider = Provider<AudioPlayer>((ref) {
  final player = AudioPlayer();
  ref.onDispose(() => player.dispose());
  return player;
});

/// Home 音乐服务（Provider 单例）。
final homeAudioServiceProvider = Provider<HomeAudioService>((ref) {
  final service = HomeAudioService(ref.watch(homeAudioPlayerProvider));
  ref.onDispose(service.dispose);
  return service;
});

/// 供 UI 订阅：当前是否正在播放。
final homeMusicPlayingProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(homeAudioPlayerProvider);
  return player.onPlayerStateChanged.map((state) => state == PlayerState.playing);
});

class HomeMusicEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) => state = enabled;
}

/// 供 UI 判断：是否已经被用户开启（包含 pause 待续播）。
final homeMusicEnabledProvider =
    NotifierProvider<HomeMusicEnabledNotifier, bool>(
      HomeMusicEnabledNotifier.new,
    );

class HomeAudioService {
  HomeAudioService(this._player) {
    _stateSub = _player.onPlayerStateChanged.listen(_onPlayerStateChanged);
  }

  final AudioPlayer _player;

  StreamSubscription<PlayerState>? _stateSub;

  bool userWantsMusic = false;
  bool pendingDayRollover = false;
  int? _playingDay;

  bool get isPlaying => _player.state == PlayerState.playing;

  Future<void> onStarTap(WidgetRef ref) async {
    if (!userWantsMusic) {
      userWantsMusic = true;
      ref.read(homeMusicEnabledProvider.notifier).setEnabled(true);
      await playToday();
      return;
    }

    if (isPlaying) {
      await stop();
      ref.read(homeMusicEnabledProvider.notifier).setEnabled(false);
      return;
    }

    if (pendingDayRollover) {
      pendingDayRollover = false;
      await playToday();
      return;
    }

    await resume();
  }

  Future<void> playToday() async {
    final now = DateTime.now();
    final index = homeMusicIndexForDate(now);
    final assetPath = homeMusicAssetPath(index);

    try {
      pendingDayRollover = false;
      _playingDay = now.day;
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(assetPath));
    } catch (e, st) {
      debugPrint('HomeAudioService.playToday failed: $e\n$st');
    }
  }

  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (e, st) {
      debugPrint('HomeAudioService.resume failed: $e\n$st');
    }
  }

  Future<void> stop() async {
    userWantsMusic = false;
    pendingDayRollover = false;
    _playingDay = null;
    try {
      await _player.stop();
    } catch (e, st) {
      debugPrint('HomeAudioService.stop failed: $e\n$st');
    }
  }

  Future<void> pauseForLeave() async {
    if (!isPlaying) return;
    try {
      await _player.pause();
    } catch (e, st) {
      debugPrint('HomeAudioService.pauseForLeave failed: $e\n$st');
    }
  }

  /// 检测是否跨本地日；若正在播放则改为“本轮播完即停”。
  Future<void> evaluateDayRollover() async {
    if (_playingDay == null || !userWantsMusic) return;
    final today = DateTime.now().day;
    if (today == _playingDay) return;

    pendingDayRollover = true;
    _playingDay = today;

    if (isPlaying) {
      try {
        await _player.setReleaseMode(ReleaseMode.release);
      } catch (e, st) {
        debugPrint('HomeAudioService.evaluateDayRollover failed: $e\n$st');
      }
    }
  }

  void _onPlayerStateChanged(PlayerState state) {
    // 跨日场景下，曲终后保持“已开启但暂停”态，等待用户点击切次日曲。
    if (state == PlayerState.completed && pendingDayRollover) {
      return;
    }
  }

  void dispose() {
    _stateSub?.cancel();
    _stateSub = null;
  }
}
