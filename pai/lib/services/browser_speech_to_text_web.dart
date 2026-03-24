import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'browser_speech_to_text.dart';

BrowserSpeechToText createBrowserSpeechToTextImpl() => _WebBrowserSpeechToText();

class _WebBrowserSpeechToText implements BrowserSpeechToText {
  final StreamController<BrowserSpeechTranscription> _transcriptionController =
      StreamController<BrowserSpeechTranscription>.broadcast();
  final StreamController<bool> _listeningController =
      StreamController<bool>.broadcast();

  JSObject? _recognition;
  bool _isAvailable = false;
  bool _isListening = false;
  bool _isInitialized = false;

  @override
  Stream<BrowserSpeechTranscription> get transcriptions =>
      _transcriptionController.stream;

  @override
  Stream<bool> get listeningChanges => _listeningController.stream;

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> initialize() async {
    if (_isInitialized) {
      return _isAvailable;
    }

    _isInitialized = true;
    final constructor = _speechRecognitionConstructor();
    if (constructor == null) {
      return false;
    }

    final recognition = constructor.callAsConstructor<JSObject>();
    recognition['continuous'] = true.toJS;
    recognition['interimResults'] = true.toJS;
    final navigator = globalContext['navigator'] as JSObject?;
    final language = navigator?['language'];
    if (language != null) {
      recognition['lang'] = language;
    }
    recognition['onstart'] = ((JSAny? _) {
      _updateListeningState(true);
    }).toJS;
    recognition['onend'] = ((JSAny? _) {
      _updateListeningState(false);
    }).toJS;
    recognition['onerror'] = ((JSAny? _) {
      _updateListeningState(false);
    }).toJS;
    recognition['onresult'] = ((JSAny? event) {
      _handleResult(event as JSObject?);
    }).toJS;

    _recognition = recognition;
    _isAvailable = true;
    return true;
  }

  @override
  Future<void> start() async {
    if (!await initialize() || _recognition == null || _isListening) {
      return;
    }

    try {
      _recognition!.callMethodVarArgs('start'.toJS);
    } catch (_) {
      _updateListeningState(false);
    }
  }

  @override
  Future<void> stop() async {
    if (_recognition == null || !_isListening) {
      _updateListeningState(false);
      return;
    }

    try {
      _recognition!.callMethodVarArgs('stop'.toJS);
    } catch (_) {
      _updateListeningState(false);
    }
  }

  void _handleResult(JSObject? event) {
    final results = event?['results'] as JSObject?;
    if (results == null) {
      return;
    }

    final resultIndex =
        ((event?['resultIndex'] as JSNumber?)?.toDartDouble ?? 0).toInt();
    final resultLength =
        ((results['length'] as JSNumber?)?.toDartDouble ?? 0).toInt();
    final interimBuffer = StringBuffer();

    for (var index = resultIndex; index < resultLength; index++) {
      final result = results[index.toString()] as JSObject?;
      if (result == null) {
        continue;
      }

      final alternative = result['0'] as JSObject?;
      final transcript =
          ((alternative?['transcript'] as JSString?)?.toDart ?? '').trim();
      if (transcript.isEmpty) {
        continue;
      }

      final isFinal = (result['isFinal'] as JSBoolean?)?.toDart ?? false;
      if (isFinal) {
        _transcriptionController.add(
          BrowserSpeechTranscription(text: transcript, isFinal: true),
        );
      } else {
        if (interimBuffer.isNotEmpty) {
          interimBuffer.write(' ');
        }
        interimBuffer.write(transcript);
      }
    }

    if (interimBuffer.isNotEmpty) {
      _transcriptionController.add(
        BrowserSpeechTranscription(
          text: interimBuffer.toString(),
          isFinal: false,
        ),
      );
    }
  }

  JSFunction? _speechRecognitionConstructor() {
    if (globalContext.has('SpeechRecognition')) {
      return globalContext['SpeechRecognition'] as JSFunction?;
    }
    if (globalContext.has('webkitSpeechRecognition')) {
      return globalContext['webkitSpeechRecognition'] as JSFunction?;
    }
    return null;
  }

  void _updateListeningState(bool value) {
    if (_isListening == value) {
      return;
    }

    _isListening = value;
    _listeningController.add(value);
  }

  @override
  void dispose() {
    unawaited(stop());
    _transcriptionController.close();
    _listeningController.close();
    _recognition = null;
  }
}
