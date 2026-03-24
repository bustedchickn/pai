import 'dart:async';

import 'browser_speech_to_text.dart';

BrowserSpeechToText createBrowserSpeechToTextImpl() => _StubBrowserSpeechToText();

class _StubBrowserSpeechToText implements BrowserSpeechToText {
  @override
  Stream<BrowserSpeechTranscription> get transcriptions =>
      const Stream<BrowserSpeechTranscription>.empty();

  @override
  Stream<bool> get listeningChanges => const Stream<bool>.empty();

  @override
  bool get isAvailable => false;

  @override
  bool get isListening => false;

  @override
  Future<bool> initialize() async => false;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}

  @override
  void dispose() {}
}
