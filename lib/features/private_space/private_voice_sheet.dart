import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:pupu/models/private_entry.dart';
import 'package:pupu/services/private_media_storage.dart';
import 'package:pupu/services/private_permission_helper.dart';
import 'package:record/record.dart';

/// Recording panel: start / pause / resume / stop, max 5 minutes.
class PrivateVoiceRecordSheet extends StatefulWidget {
  const PrivateVoiceRecordSheet({super.key});

  @override
  State<PrivateVoiceRecordSheet> createState() => _PrivateVoiceRecordSheetState();
}

class _PrivateVoiceRecordSheetState extends State<PrivateVoiceRecordSheet> {
  static const _maxMs = 5 * 60 * 1000;

  final AudioRecorder _recorder = AudioRecorder();
  String? _path;
  _RecState _state = _RecState.idle;
  int _elapsedMs = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final ok = await PrivatePermissionHelper.ensure(
      context,
      PrivatePermissionKind.microphone,
    );
    if (!ok || !mounted) return;

    final id = DateTime.now().microsecondsSinceEpoch.toString();
    _path = await PrivateMediaStorage.voicePathFor(id);
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _path!,
    );
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedMs += 200;
        if (_elapsedMs >= _maxMs) _stop();
      });
    });
    setState(() => _state = _RecState.recording);
  }

  Future<void> _pause() async {
    await _recorder.pause();
    _timer?.cancel();
    setState(() => _state = _RecState.paused);
  }

  Future<void> _resume() async {
    await _recorder.resume();
    _timer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted) return;
      setState(() {
        _elapsedMs += 200;
        if (_elapsedMs >= _maxMs) _stop();
      });
    });
    setState(() => _state = _RecState.recording);
  }

  Future<void> _stop() async {
    _timer?.cancel();
    await _recorder.stop();
    if (!mounted) return;
    setState(() => _state = _RecState.stopped);
  }

  void _save() {
    if (_path == null || _elapsedMs < 500) {
      Navigator.pop(context);
      return;
    }
    final waveform = List<double>.generate(
      12,
      (i) => 0.2 + Random(i + _elapsedMs).nextDouble() * 0.7,
    );
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    Navigator.pop(
      context,
      PrivateVoiceData(
        id: id,
        path: _path!,
        durationMs: _elapsedMs,
        waveform: waveform,
      ),
    );
  }

  String get _timeLabel {
    final s = (_elapsedMs / 1000).floor();
    final m = s ~/ 60;
    final r = s % 60;
    return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF0E1520),
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: Color(0x55D9B34A))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _timeLabel,
            style: const TextStyle(
              color: Color(0xFFF6E6B3),
              fontSize: 32,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Max 5:00',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.45), fontSize: 12),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_state == _RecState.idle)
                _btn(Icons.mic, 'Start', _start, highlight: true)
              else if (_state == _RecState.recording) ...[
                _btn(Icons.pause, 'Pause', _pause),
                const SizedBox(width: 16),
                _btn(Icons.stop, 'Stop', _stop, highlight: true),
              ] else if (_state == _RecState.paused) ...[
                _btn(Icons.play_arrow, 'Resume', _resume, highlight: true),
                const SizedBox(width: 16),
                _btn(Icons.stop, 'Stop', _stop),
              ] else ...[
                _btn(Icons.check, 'Save', _save, highlight: true),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _btn(
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool highlight = false,
  }) {
    return Column(
      children: [
        Material(
          color: highlight ? const Color(0x33E2BE57) : Colors.white10,
          shape: const CircleBorder(
            side: BorderSide(color: Color(0x55D9B34A)),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Icon(icon, color: const Color(0xFFF6E6B3)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 11)),
      ],
    );
  }
}

enum _RecState { idle, recording, paused, stopped }

/// Global single voice player for Private Space blocks.
class PrivateVoicePlayer {
  PrivateVoicePlayer._() {
    _player.onPlayerComplete.listen((_) {
      _playingPath = null;
      _notify();
    });
  }

  static final PrivateVoicePlayer instance = PrivateVoicePlayer._();

  final AudioPlayer _player = AudioPlayer();
  String? _playingPath;
  final _listeners = <VoidCallback>{};

  String? get playingPath => _playingPath;

  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);

  void _notify() {
    for (final cb in List<VoidCallback>.from(_listeners)) {
      cb();
    }
  }

  Future<void> toggle(String path) async {
    if (_playingPath == path) {
      final state = _player.state;
      if (state == PlayerState.playing) {
        await _player.pause();
      } else {
        await _player.resume();
      }
      _notify();
      return;
    }
    await _player.stop();
    _playingPath = path;
    await _player.play(DeviceFileSource(path));
    _notify();
  }

  Future<void> stop() async {
    await _player.stop();
    _playingPath = null;
    _notify();
  }

  bool isPlaying(String path) =>
      _playingPath == path && _player.state == PlayerState.playing;
}
