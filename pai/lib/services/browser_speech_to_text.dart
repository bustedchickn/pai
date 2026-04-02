import 'browser_speech_to_text_stub.dart'
    if (dart.library.html) 'browser_speech_to_text_web.dart';

class BrowserSpeechTranscription {
  const BrowserSpeechTranscription({
    required this.text,
    required this.isFinal,
  });

  final String text;
  final bool isFinal;
}

abstract class BrowserSpeechToText {
  Stream<BrowserSpeechTranscription> get transcriptions;
  Stream<bool> get listeningChanges;
  bool get isAvailable;
  bool get isListening;

  Future<bool> initialize();
  Future<void> start();
  Future<void> stop();
  void dispose();
}

// Keyboard dictation already works in Flutter text fields on supported devices.
// This optional browser helper only inserts recognized text into the current
// field and does not keep or upload audio recordings.
BrowserSpeechToText createBrowserSpeechToText() =>
    createBrowserSpeechToTextImpl();
