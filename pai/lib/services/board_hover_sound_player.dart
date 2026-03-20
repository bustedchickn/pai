import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class BoardHoverSoundPlayer {
  BoardHoverSoundPlayer({bool enabled = true}) : _enabled = enabled {
    _hoverPlayer.audioCache = _audioCache;
  }

  static const Duration _hoverCooldown = Duration(milliseconds: 260);
  static const double _hoverVolume = 0.5;
  static const Duration _fadeOutDuration = Duration(milliseconds: 150);
  static const int _fadeOutSteps = 4;
  static const List<String> _selectAssets = [
    'lib/sfx/select0.mp3',
    'lib/sfx/select1.mp3',
    'lib/sfx/select2.mp3',
  ];
  static const String _newProjectAsset = 'lib/sfx/new project.mp3';

  final Random _random = Random();
  final AudioCache _audioCache = AudioCache(prefix: '');
  final AudioPlayer _hoverPlayer = AudioPlayer();

  bool _enabled;
  bool _initialized = false;
  Future<void>? _initializeFuture;
  DateTime? _lastPlayedAt;
  final List<Timer> _fadeTimers = [];

  set enabled(bool value) => _enabled = value;

  Future<void> playProjectHover() async {
    await _playHoverAsset(
      _selectAssets[_random.nextInt(_selectAssets.length)],
    );
  }

  Future<void> playNewProjectHover() async {
    await _playHoverAsset(_newProjectAsset);
  }

  Future<void> warmUp() => _ensureInitialized();

  Future<void> dispose() async {
    _cancelFadeOut();
    await _hoverPlayer.dispose();
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    _initializeFuture ??= _initialize();
    await _initializeFuture;
  }

  Future<void> _initialize() async {
    await _hoverPlayer.setPlayerMode(PlayerMode.mediaPlayer);
    await _hoverPlayer.setReleaseMode(ReleaseMode.stop);
    await _hoverPlayer.setVolume(_hoverVolume);
    await _audioCache.loadAll([
      ..._selectAssets,
      _newProjectAsset,
    ]);
    _initialized = true;
  }

  Future<void> _playHoverAsset(String assetPath) async {
    if (!_enabled) {
      return;
    }

    final now = DateTime.now();
    final lastPlayedAt = _lastPlayedAt;
    if (lastPlayedAt != null && now.difference(lastPlayedAt) < _hoverCooldown) {
      return;
    }

    _lastPlayedAt = now;

    try {
      await _ensureInitialized();
      _cancelFadeOut();
      await _hoverPlayer.stop();
      await _hoverPlayer.setVolume(_hoverVolume);
      await _hoverPlayer.play(
        AssetSource(assetPath),
        volume: _hoverVolume,
        mode: PlayerMode.mediaPlayer,
      );
      await _hoverPlayer.setVolume(_hoverVolume);
      await _scheduleFadeOut();
    } catch (error, stackTrace) {
      debugPrint('Board hover audio failed for $assetPath: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _scheduleFadeOut() async {
    final duration = await _hoverPlayer.getDuration();
    if (duration == null || duration <= _fadeOutDuration) {
      return;
    }

    final fadeStartDelay = duration - _fadeOutDuration;
    final stepMilliseconds = (_fadeOutDuration.inMilliseconds / _fadeOutSteps)
        .round();

    for (var step = 0; step < _fadeOutSteps; step++) {
      final timer = Timer(
        fadeStartDelay + Duration(milliseconds: stepMilliseconds * step),
        () {
          final remainingRatio =
              (_fadeOutSteps - (step + 1)) / _fadeOutSteps;
          _hoverPlayer.setVolume(_hoverVolume * remainingRatio);
        },
      );
      _fadeTimers.add(timer);
    }
  }

  void _cancelFadeOut() {
    for (final timer in _fadeTimers) {
      timer.cancel();
    }
    _fadeTimers.clear();
  }
}
