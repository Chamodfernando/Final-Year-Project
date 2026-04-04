import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // TODO: Replace with your actual API Key from aistudio.google.com
  static const String _apiKey = "AIzaSyA5SM_rrf9yzKkMAmk4L984uwFyV6nvJok";
  static bool get isApiKeySet => _apiKey.isNotEmpty && _apiKey != "YOUR_GEMINI_API_KEY";
  
  late final GenerativeModel _model;
  ChatSession? _chatSession;

  GeminiService() {
    _model = GenerativeModel(
      model: 'gemini-2.5-flash',
      apiKey: _apiKey,
      generationConfig: GenerationConfig(
        temperature: 0.7,
        topK: 40,
        topP: 0.95,
        maxOutputTokens: 1024,
      ),
    );
  }

  /// Start a new chat session with context about the artifact
  void startArtifactChat({
    required String artifactTitle,
    required String history,
    required List<String> quickFacts,
  }) {
    final systemPrompt = '''
You are a knowledgeable and friendly Sri Lankan tour guide for the "Ceylon Trails" app.
Your goal is to answer questions about the specific artifact: "$artifactTitle".

Context about this artifact:
History: $history
Quick Facts: ${quickFacts.join(', ')}

Instructions:
- Be polite, engaging, and professional.
- Focus your answers primarily on this specific artifact.
- If asked about something unrelated, politely bring the conversation back to Sri Lankan heritage.
- Keep responses relatively concise but informative.
''';

    _chatSession = _model.startChat(history: [
      Content.text(systemPrompt),
      Content.model([TextPart("I understand. I am ready to help the user learn about $artifactTitle. How can I assist them today?")]),
    ]);
  }

  /// Send a message and get a stream of responses
  Stream<String> sendMessageStream(String message) async* {
    if (_chatSession == null) {
      throw Exception("Chat session not initialized. Call startArtifactChat first.");
    }

    final response = _chatSession!.sendMessageStream(Content.text(message));
    
    await for (final chunk in response) {
      if (chunk.text != null) {
        yield chunk.text!;
      }
    }
  }

  /// Legacy non-streaming method (if needed)
  Future<String> sendMessage(String message) async {
    if (_chatSession == null) {
      throw Exception("Chat session not initialized.");
    }
    
    final response = await _chatSession!.sendMessage(Content.text(message));
    return response.text ?? "I'm sorry, I couldn't generate a response.";
  }
}
