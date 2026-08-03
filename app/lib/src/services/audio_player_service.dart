import 'package:flutter/services.dart';

const _channel = MethodChannel('dildostu/audio');

/// Plyerin anlıq vəziyyəti (native tərəfdən oxunur).
class AudioPlaybackState {
  const AudioPlaybackState({
    this.prepared = false,
    this.playing = false,
    this.completed = false,
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.error,
  });

  final bool prepared;
  final bool playing;
  final bool completed;
  final Duration position;
  final Duration duration;

  /// Native tərəfdəki xəta — UI bunu GÖSTƏRMƏLİDİR (səssiz uğursuzluq yox).
  final String? error;

  factory AudioPlaybackState.fromMap(Map<dynamic, dynamic> map) =>
      AudioPlaybackState(
        prepared: map['prepared'] as bool? ?? false,
        playing: map['playing'] as bool? ?? false,
        completed: map['completed'] as bool? ?? false,
        position: Duration(milliseconds: map['positionMs'] as int? ?? 0),
        duration: Duration(milliseconds: map['durationMs'] as int? ?? 0),
        error: map['error'] as String?,
      );

  /// 0.0-1.0 arası gedişat; uzunluq bilinmirsə 0.
  double get progress {
    if (duration.inMilliseconds <= 0) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }
}

/// Native Android MediaPlayer üzərində nazik interfeys.
///
/// `just_audio` kimi federated plugin QƏSDƏN işlədilmir — bu maşında belə
/// plugin-lər Gradle buildini üç dəfə sındırıb (bax dildostu/CLAUDE.md).
/// Interfeys nazikdir ki, ekranlar testdə saxta plyerlə işləsin.
abstract class AudioPlayer {
  /// `source`: HTTP URL (axın) və ya yerli fayl yolu (offline).
  Future<void> play(String source);
  Future<void> pause();
  Future<void> resume();
  Future<void> seek(Duration position);
  Future<void> stop();
  Future<AudioPlaybackState> state();
}

class NativeAudioPlayer implements AudioPlayer {
  const NativeAudioPlayer();

  @override
  Future<void> play(String source) =>
      _channel.invokeMethod<void>('play', {'source': source});

  @override
  Future<void> pause() => _channel.invokeMethod<void>('pause');

  @override
  Future<void> resume() => _channel.invokeMethod<void>('resume');

  @override
  Future<void> seek(Duration position) =>
      _channel.invokeMethod<void>('seek', {'ms': position.inMilliseconds});

  @override
  Future<void> stop() => _channel.invokeMethod<void>('stop');

  @override
  Future<AudioPlaybackState> state() async {
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('state');
    if (map == null) return const AudioPlaybackState();
    return AudioPlaybackState.fromMap(map);
  }
}
