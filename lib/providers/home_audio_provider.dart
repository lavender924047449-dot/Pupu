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

/// 供 UI 订阅：当前是否正在播放（星星大亮 ⟺ true）。
final homeMusicPlayingProvider = StreamProvider<bool>((ref) {
  final player = ref.watch(homeAudioPlayerProvider);
  return player.onPlayerStateChanged
      .map((state) => state == PlayerState.playing);
});

class HomeMusicEnabledNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setEnabled(bool enabled) => state = enabled;
}

/// 用户是否曾开启 Home BGM（pause 后仍为 true，Q7A 无 stop）。
final homeMusicEnabledProvider =
    NotifierProvider<HomeMusicEnabledNotifier, bool>(
      HomeMusicEnabledNotifier.new,
    );

/// Home 页 BGM 状态机（HOME-003）。
///
/// - 播放中点星星 → pause，保留进度
/// - 子页导航 → pause，返回后再点 resume
/// - App 后台 → 不 pause（由 [HomeScreen] 生命周期保证）
/// - paused 跨日 → 瞬间清 memory，再点 playToday
class HomeAudioService {
  HomeAudioService(this._player) {
    _stateSub = _player.onPlayerStateChanged.listen(_onPlayerStateChanged);
  }

  final AudioPlayer _player;

  StreamSubscription<PlayerState>? _stateSub;

  /// 用户已开启音乐意图；pause 后保持 true（无显式 stop）。
  bool userWantsMusic = false;

  /// 播放中跨日后，当前曲播完等待用户切次日曲。
  bool pendingDayRollover = false;

  /// 当前曲目开始时的本地 day。
  int? _playingDay;

  /// pause 后是否有可 resume 的进度（跨日清 memory 时置 false）。
  bool _pauseMemoryValid = false;

  bool get isPlaying => _player.state == PlayerState.playing;

  int get _today => DateTime.now().day;

  /// 星星点击唯一入口。
  Future<void> onStarTap(WidgetRef ref) async {
    if (!userWantsMusic) {
      userWantsMusic = true;
      ref.read(homeMusicEnabledProvider.notifier).setEnabled(true);
      await playToday();
      return;
    }

    if (isPlaying) {
      await pauseByUser();
      return;
    }

    if (pendingDayRollover ||
        !_pauseMemoryValid ||
        _playingDay != _today) {
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
      _pauseMemoryValid = false;
      _playingDay = now.day;
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(AssetSource(assetPath));
    } catch (e, st) {
      debugPrint('HomeAudioService.playToday failed: $e\n$st');
    }
  }

  /// 用户播放中点星星：pause 并记忆进度。
  Future<void> pauseByUser() async {
    if (!isPlaying) return;
    try {
      await _player.pause();
      _pauseMemoryValid = true;
    } catch (e, st) {
      debugPrint('HomeAudioService.pauseByUser failed: $e\n$st');
    }
  }

  Future<void> resume() async {
    try {
      await _player.resume();
    } catch (e, st) {
      debugPrint('HomeAudioService.resume failed: $e\n$st');
    }
  }

  /// 子页音乐按钮入口：仅做播放/暂停切换，不处理 Home 星星的额外语义。
  Future<void> toggleFromSubPage(WidgetRef ref) async {
    if (isPlaying) {
      await pauseByUser();
      return;
    }

    if (!userWantsMusic) {
      userWantsMusic = true;
      ref.read(homeMusicEnabledProvider.notifier).setEnabled(true);
      await playToday();
      return;
    }

    if (!_pauseMemoryValid || _playingDay != _today) {
      pendingDayRollover = false;
      await playToday();
      return;
    }

    await resume();
  }

  /// 进子页前 pause；保留进度，返回后需用户点星星 resume。
  Future<void> pauseForLeave() async {
    if (!isPlaying) return;
    try {
      await _player.pause();
      _pauseMemoryValid = true;
    } catch (e, st) {
      debugPrint('HomeAudioService.pauseForLeave failed: $e\n$st');
    }
  }

  /// 检测跨本地日：playing 跨日曲终切换；paused 跨日瞬间清 memory。
  Future<void> evaluateDayRollover() async {
    if (_playingDay == null || !userWantsMusic) return;
    if (_today == _playingDay) return;

    if (isPlaying) {
      pendingDayRollover = true;
      _playingDay = _today;
      try {
        await _player.setReleaseMode(ReleaseMode.release);
      } catch (e, st) {
        debugPrint('HomeAudioService.evaluateDayRollover (playing) failed: $e\n$st');
      }
      return;
    }

    // paused 跨日（Q8）：清进度，不自动播；下次点星星走 playToday。
    await _clearPausedMemoryForNewDay();
  }

  /// paused 态跨日：stop 清 buffer，保留 userWantsMusic。
  Future<void> _clearPausedMemoryForNewDay() async {
    pendingDayRollover = false;
    _playingDay = _today;
    _pauseMemoryValid = false;
    try {
      await _player.stop();
    } catch (e, st) {
      debugPrint('HomeAudioService._clearPausedMemoryForNewDay failed: $e\n$st');
    }
  }

  void _onPlayerStateChanged(PlayerState state) {
    if (state == PlayerState.completed && pendingDayRollover) {
      _pauseMemoryValid = false;
      return;
    }
  }

  void dispose() {
    _stateSub?.cancel();
    _stateSub = null;
  }
}
