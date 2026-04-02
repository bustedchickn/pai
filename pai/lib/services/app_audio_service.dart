import 'dart:async';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AppAudioService {
  AppAudioService() {
    _player.audioCache = _audioCache;
  }

  static const String _assetPrefix = 'lib/sfx/';
  static const Duration _playCooldown = Duration(milliseconds: 140);
  static const double _defaultVolume = 0.38;
  static const double _successVolume = 0.42;
  static const double _failureVolume = 0.34;
  static const List<String> _selectAssets = [
    'select0.mp3',
    'select1.mp3',
    'select2.mp3',
  ];
  static const String _openProjectAsset = 'click3.mp3';
  static const String _createProjectAsset = 'new project.mp3';
  static const String _syncSuccessAsset = 'click6.mp3';
  static const String _syncFailureAsset = 'unavailable.mp3';

  final Random _random = Random();
  final AudioCache _audioCache = AudioCache(prefix: _assetPrefix);
  final AudioPlayer _player = AudioPlayer();

  bool _initialized = false;
  Future<void>? _initializeFuture;
  DateTime? _lastPlayedAt;

  Future<void> warmUp() async {
    try {
      await _ensureInitialized();
    } catch (error, stackTrace) {
      debugPrint('Audio warm-up failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> dispose() => _player.dispose();

  Future<void> playSelection() async {
    await _play(
      _selectAssets[_random.nextInt(_selectAssets.length)],
      volume: _defaultVolume,
    );
  }

  Future<void> playProjectOpened() async {
    await _play(_openProjectAsset, volume: _defaultVolume);
  }

  Future<void> playProjectCreated() async {
    await _play(_createProjectAsset, volume: _defaultVolume);
  }

  Future<void> playSyncSuccess() async {
    await _play(_syncSuccessAsset, volume: _successVolume);
  }

  Future<void> playSyncFailure() async {
    await _play(_syncFailureAsset, volume: _failureVolume);
  }

  Future<void> _ensureInitialized() async {
    if (_initialized) {
      return;
    }

    final initializeFuture = _initializeFuture ??= _initialize();
    try {
      await initializeFuture;
    } catch (_) {
      if (identical(_initializeFuture, initializeFuture)) {
        _initializeFuture = null;
      }
      rethrow;
    }
  }

  Future<void> _initialize() async {
    await _player.setPlayerMode(PlayerMode.lowLatency);
    await _player.setReleaseMode(ReleaseMode.stop);
    await _audioCache.loadAll([
      ..._selectAssets,
      _openProjectAsset,
      _createProjectAsset,
      _syncSuccessAsset,
      _syncFailureAsset,
    ]);
    _initialized = true;
  }

  Future<void> _play(String assetName, {required double volume}) async {
    final lastPlayedAt = _lastPlayedAt;
    if (lastPlayedAt != null &&
        DateTime.now().difference(lastPlayedAt) < _playCooldown) {
      return;
    }

    try {
      await _ensureInitialized();
      _lastPlayedAt = DateTime.now();
      await _player.stop();
      await _player.play(
        AssetSource(assetName),
        volume: volume,
        mode: PlayerMode.lowLatency,
      );
    } catch (error, stackTrace) {
      debugPrint('Failed to play $assetName: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }
}
