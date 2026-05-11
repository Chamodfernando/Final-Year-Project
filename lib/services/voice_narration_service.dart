import 'package:flutter_tts/flutter_tts.dart';

enum VoiceNarrationState { stopped, speaking, paused }

class VoiceNarrationService {
  final FlutterTts _tts = FlutterTts();
  bool _isConfigured = false;
  VoiceNarrationState _state = VoiceNarrationState.stopped;
  void Function(VoiceNarrationState state)? _onStateChanged;
  String _lastText = '';
  String _lastLocale = 'en-US';
  double _lastRate = 0.45;

  VoiceNarrationState get state => _state;

  VoiceNarrationService() {
    _tts.setStartHandler(() => _updateState(VoiceNarrationState.speaking));
    _tts.setCompletionHandler(() => _updateState(VoiceNarrationState.stopped));
    _tts.setCancelHandler(() => _updateState(VoiceNarrationState.stopped));
    _tts.setPauseHandler(() => _updateState(VoiceNarrationState.paused));
    _tts.setContinueHandler(() => _updateState(VoiceNarrationState.speaking));
  }

  void setStateListener(void Function(VoiceNarrationState state)? listener) {
    _onStateChanged = listener;
  }

  void _updateState(VoiceNarrationState state) {
    _state = state;
    _onStateChanged?.call(state);
  }

  Future<void> _configureIfNeeded({
    required String locale,
    required double rate,
  }) async {
    await _tts.setLanguage(locale);
    await _tts.setSpeechRate(rate);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    if (!_isConfigured) {
      await _tts.awaitSpeakCompletion(true);
      _isConfigured = true;
    }
  }

  Future<void> speak(
    String text, {
    required String locale,
    required double rate,
  }) async {
    _lastText = text;
    _lastLocale = locale;
    _lastRate = rate;
    await _configureIfNeeded(locale: locale, rate: rate);
    await _tts.stop();
    await _tts.speak(text);
  }

  Future<void> pause() async {
    await _tts.pause();
  }

  Future<void> resume() async {
    if (_lastText.isEmpty) return;
    await _configureIfNeeded(locale: _lastLocale, rate: _lastRate);
    await _tts.speak(_lastText);
  }

  Future<void> stop() async {
    await _tts.stop();
    _updateState(VoiceNarrationState.stopped);
  }
}
