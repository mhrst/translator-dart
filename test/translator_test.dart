import 'package:flutter_test/flutter_test.dart';

import 'package:translator_dart/translator.dart';

void main() {
  group('TranslationConfig.fromEnvironment', () {
    test('defaults to OpenAI with the latest default model', () {
      final config = TranslationConfig.fromEnvironment(
        environment: {'OPENAI_API_KEY': 'openai-key'},
      );

      expect(config.provider, TranslationProvider.openai);
      expect(config.model, 'gpt-5.4');
      expect(config.apiKey, 'openai-key');
    });

    test('loads Google configuration from environment', () {
      final config = TranslationConfig.fromEnvironment(
        environment: {
          'TRANSLATION_PROVIDER': 'google',
          'TRANSLATION_MODEL': 'gemini-2.5-flash',
          'GOOGLE_GENAI_API_KEY': 'google-key',
        },
      );

      expect(config.provider, TranslationProvider.google);
      expect(config.model, 'gemini-2.5-flash');
      expect(config.apiKey, 'google-key');
    });

    test('defaults Google to the latest model when not configured', () {
      final config = TranslationConfig.fromEnvironment(
        environment: {
          'TRANSLATION_PROVIDER': 'google',
          'GOOGLE_GENAI_API_KEY': 'google-key',
        },
      );

      expect(config.provider, TranslationProvider.google);
      expect(config.model, 'gemini-2.5-pro');
      expect(config.apiKey, 'google-key');
    });

    test('loads Anthropic configuration from environment', () {
      final config = TranslationConfig.fromEnvironment(
        environment: {
          'TRANSLATION_PROVIDER': 'anthropic',
          'TRANSLATION_MODEL': 'claude-sonnet-4-5',
          'ANTHROPIC_API_KEY': 'anthropic-key',
          'ANTHROPIC_BASE_URL': 'https://proxy.example.com',
        },
      );

      expect(config.provider, TranslationProvider.anthropic);
      expect(config.model, 'claude-sonnet-4-5');
      expect(config.apiKey, 'anthropic-key');
      expect(config.baseUrl, 'https://proxy.example.com');
    });

    test('defaults Anthropic to the latest model when not configured', () {
      final config = TranslationConfig.fromEnvironment(
        environment: {
          'TRANSLATION_PROVIDER': 'anthropic',
          'ANTHROPIC_API_KEY': 'anthropic-key',
        },
      );

      expect(config.provider, TranslationProvider.anthropic);
      expect(config.model, 'claude-opus-4-7');
      expect(config.apiKey, 'anthropic-key');
    });

    test('throws for an unsupported provider', () {
      expect(
        () => TranslationConfig.fromEnvironment(
          environment: {
            'TRANSLATION_PROVIDER': 'unsupported',
            'OPENAI_API_KEY': 'openai-key',
          },
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('throws when the selected provider key is missing', () {
      expect(
        () => TranslationConfig.fromEnvironment(
          environment: {
            'TRANSLATION_PROVIDER': 'google',
            'TRANSLATION_MODEL': 'gemini-2.5-flash',
          },
        ),
        throwsA(isA<StateError>()),
      );
    });
  });

  group('Translator.translateText', () {
    test('passes the built prompt to the client', () async {
      String? capturedPrompt;
      final translator = _TestTranslator(
        client: _FakeTranslationClient(
          translatePrompt: (prompt) async {
            capturedPrompt = prompt;
            return 'bonjour';
          },
        ),
      );

      await translator.translateText('hello', 'fr');

      expect(capturedPrompt, 'prompt for "hello" in fr');
    });

    test('trims the translated text', () async {
      final translator = _TestTranslator(
        client: _FakeTranslationClient(
          translatePrompt: (prompt) async => '  bonjour  ',
        ),
      );

      final translatedText = await translator.translateText('hello', 'fr');

      expect(translatedText, 'bonjour');
    });

    test('fails when the provider returns blank text', () async {
      final translator = _TestTranslator(
        client: _FakeTranslationClient(
          provider: TranslationProvider.google,
          model: 'gemini-2.5-flash',
          translatePrompt: (prompt) async => '   ',
        ),
      );

      await expectLater(
        () => translator.translateText('hello', 'fr'),
        throwsA(
          predicate(
            (error) =>
                error.toString().contains('google/gemini-2.5-flash') &&
                error.toString().contains('blank text'),
          ),
        ),
      );
    });
  });
}

class _TestTranslator extends Translator {
  _TestTranslator({required super.client})
    : super(retryIntervals: const [], waitForRetry: _skipRetryDelay);

  @override
  String prompt(String text, String targetLanguage) {
    return 'prompt for "$text" in $targetLanguage';
  }
}

class _FakeTranslationClient implements TranslationClient {
  final TranslationProvider _provider;
  final String _model;
  final Future<String> Function(String prompt) _translatePrompt;

  _FakeTranslationClient({
    TranslationProvider provider = TranslationProvider.openai,
    String model = 'gpt-5.4',
    required Future<String> Function(String prompt) translatePrompt,
  }) : _provider = provider,
       _model = model,
       _translatePrompt = translatePrompt;

  @override
  TranslationProvider get provider => _provider;

  @override
  String get model => _model;

  @override
  Future<String> translatePrompt(String prompt) {
    return _translatePrompt(prompt);
  }
}

Future<void> _skipRetryDelay(Duration duration) async {}
