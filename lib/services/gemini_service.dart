import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Reads [OPENROUTER_API_KEY] from compile-time defines (never commit a real key in Dart).
///
/// Local dev (recommended): copy [secrets.example.json] to `secrets.json`, add your key
/// (`secrets.json` is gitignored), then run:
/// `flutter run --dart-define-from-file=secrets.json`
///
/// Or once: `flutter run --dart-define=OPENROUTER_API_KEY=your_key`
class GeminiService {
  static const String _openRouterApiKey = String.fromEnvironment(
    'OPENROUTER_API_KEY',
    defaultValue: '',
  );
  static const String _deepSeekApiKey = String.fromEnvironment(
    'DEEPSEEK_API_KEY',
    defaultValue: '',
  );
  static const String _legacyGeminiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: '',
  );
  static const String _model = String.fromEnvironment(
    'OPENROUTER_MODEL',
    defaultValue: 'openrouter/auto',
  );
  static String get _apiKey =>
      _openRouterApiKey.isNotEmpty
          ? _openRouterApiKey
          : (_deepSeekApiKey.isNotEmpty ? _deepSeekApiKey : _legacyGeminiKey);

  static bool get isApiKeySet => _apiKey.isNotEmpty;

  /// Shown when [isApiKeySet] is false (key was not passed at compile time).
  static String get missingCompileTimeKeyUserMessage =>
      'This build does not include an OpenRouter API key yet.\n\n'
      '1. Put your key in secrets.json (copy secrets.example.json if needed).\n'
      '2. Fully stop the app (not hot reload).\n'
      '3. Run from the project folder:\n'
      'flutter run --dart-define-from-file=secrets.json\n\n'
      'In VS Code / Cursor, pick the launch configuration that adds that flag, '
      'or add the same flag under "Additional run args".\n\n'
      'Alternative:\n'
      'flutter run --dart-define=OPENROUTER_API_KEY=your_key_here\n'
      '(Legacy fallback also works: DEEPSEEK_API_KEY / GEMINI_API_KEY)';

  static const int _maxHistoryChars = 4500;
  static const int _maxQuickFactsChars = 1500;

  static String _truncateForPrompt(String text, int maxChars) {
    final t = text.trim();
    if (t.length <= maxChars) return t;
    return '${t.substring(0, maxChars)}…\n[Context truncated for the AI guide.]';
  }

  static bool _isLikelyQuotaMessage(String m) =>
      m.contains('too many requests') ||
      m.contains('quota exceeded') ||
      m.contains('rate limit') ||
      m.contains('rate_limit') ||
      m.contains('429') ||
      (m.contains('quota') && (m.contains('exceed') || m.contains('limit')));

  static const String _quotaUserMessage =
      'OpenRouter rate-limited or capped this API key.\n\n'
      '• Wait about 60 seconds and try again.\n'
      '• Avoid sending many messages in a row.\n'
      '• Check your OpenRouter account usage and limits.\n'
      '• For higher limits, upgrade your OpenRouter plan.';

  static const String _endpoint = 'https://openrouter.ai/api/v1/chat/completions';
  final List<Map<String, String>> _messages = [];

  void _assertConfigured() {
    if (!isApiKeySet) throw StateError('OPENROUTER_API_KEY is not set.');
  }

  /// Start a new chat session with context about the artifact.
  void startArtifactChat({
    required String artifactTitle,
    required String history,
    required List<String> quickFacts,
  }) {
    if (!isApiKeySet) {
      _messages.clear();
      return;
    }

    final historyForModel = _truncateForPrompt(history, _maxHistoryChars);
    final factsJoined = quickFacts.map((s) => s.trim()).where((s) => s.isNotEmpty).join('; ');
    final factsForModel = _truncateForPrompt(factsJoined, _maxQuickFactsChars);

    final systemPrompt = '''
You are a knowledgeable and friendly Sri Lankan tour guide for the "Ceylon Trails" app.
Your goal is to answer questions about the specific artifact: "$artifactTitle".

Context about this artifact:
History: $historyForModel
Quick Facts: $factsForModel

Instructions:
- Be polite, engaging, and professional.
- Focus your answers primarily on this specific artifact.
- If asked about something unrelated, politely bring the conversation back to Sri Lankan heritage.
- Keep responses relatively concise but informative.
''';

    _messages
      ..clear()
      ..add({'role': 'system', 'content': systemPrompt});
  }

  Future<String> _requestCompletion() async {
    final response = await http.post(
      Uri.parse(_endpoint),
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer $_apiKey',
        HttpHeaders.contentTypeHeader: 'application/json',
        'HTTP-Referer': 'https://ceylon-trails.app',
        'X-Title': 'Ceylon Trails',
      },
      body: jsonEncode({
        'model': _model,
        'messages': _messages,
        'temperature': 0.7,
        'max_tokens': 1024,
        'stream': false,
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('OpenRouter API ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = data['choices'] as List<dynamic>? ?? const [];
    if (choices.isEmpty) {
      return "I'm sorry, I couldn't generate a response.";
    }
    final msg = choices.first as Map<String, dynamic>;
    final content = ((msg['message'] as Map<String, dynamic>?)?['content'] as String?)
            ?.trim() ??
        '';
    if (content.isEmpty) {
      return "I'm sorry, I couldn't generate a response.";
    }
    return content;
  }

  /// Send a message and expose chunks for the existing chat UI.
  Stream<String> sendMessageStream(String message) async* {
    _assertConfigured();
    if (_messages.isEmpty) {
      throw Exception('Chat session not initialized. Call startArtifactChat first.');
    }
    _messages.add({'role': 'user', 'content': message});
    final full = await _requestCompletion();
    _messages.add({'role': 'assistant', 'content': full});
    yield full;
  }

  Future<String> sendMessage(String message) async {
    _assertConfigured();
    if (_messages.isEmpty) {
      throw Exception('Chat session not initialized. Call startArtifactChat first.');
    }
    _messages.add({'role': 'user', 'content': message});
    final full = await _requestCompletion();
    _messages.add({'role': 'assistant', 'content': full});
    return full;
  }

  /// Short text for in-app chat when the AI API fails.
  static String userFacingErrorMessage(Object error) {
    if (error is StateError) {
      final msg = error.message;
      if (msg.contains('OPENROUTER_API_KEY') ||
          msg.contains('DEEPSEEK_API_KEY') ||
          msg.contains('GEMINI_API_KEY')) {
        return missingCompileTimeKeyUserMessage;
      }
    }

    final raw = error.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('401') || lower.contains('unauthorized')) {
      return 'Your OpenRouter API key was rejected. Update secrets.json, then fully stop and run again with '
          '--dart-define-from-file=secrets.json';
    }
    if (lower.contains('402') ||
        lower.contains('payment required') ||
        lower.contains('insufficient balance') ||
        lower.contains('insufficient_quota')) {
      return 'Your OpenRouter key is valid, but the account has no API balance/quota right now.\n\n'
          'Add credit (or enable billing) in your OpenRouter account, then try again.';
    }
    if (lower.contains('403') || lower.contains('forbidden')) {
      return 'Access denied for this OpenRouter API key. Check key permissions and account status.';
    }
    if (lower.contains('404') || lower.contains('not found')) {
      return 'OpenRouter endpoint/model not available right now. Try again later.';
    }
    if (lower.contains('socketexception') || error is http.ClientException) {
      return 'No internet connection (or DNS failed). Check Wi-Fi/mobile data and try again.';
    }
    if (lower.contains('failed host lookup') ||
        lower.contains('network is unreachable') ||
        lower.contains('connection refused') ||
        lower.contains('connection reset')) {
      return 'Could not reach OpenRouter (network issue). Check your connection and try again.';
    }
    if (lower.contains('api key not valid') || lower.contains('invalid api key')) {
      return 'This app needs a valid OpenRouter API key. '
          'then run or build with:\n'
          'flutter run --dart-define=OPENROUTER_API_KEY=your_key_here';
    }
    if ((lower.contains('openrouter_api_key') ||
            lower.contains('openrouter api key') ||
            lower.contains('deepseek_api_key') ||
            lower.contains('deepseek api key')) &&
        !lower.contains('is not set')) {
      return 'Add your OpenRouter API key when running the app:\n'
          'flutter run --dart-define-from-file=secrets.json\n'
          'or: flutter run --dart-define=OPENROUTER_API_KEY=your_key_here';
    }
    if (_isLikelyQuotaMessage(lower)) {
      return _quotaUserMessage;
    }
    return 'Sorry, the guide could not answer right now. Please try again.';
  }
}
