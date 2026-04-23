import 'dart:developer' as developer;
import 'dart:io';

import 'package:anthropic_sdk_dart/anthropic_sdk_dart.dart' as anthropic;
import 'package:googleai_dart/googleai_dart.dart' as googleai;
import 'package:openai_dart/openai_dart.dart' as openai;

// These defaults track the latest generally available flagship models we want
// the translation tools to use when TRANSLATION_MODEL is not set.
const _kDefaultOpenAIModel = 'gpt-5.4';
const _kDefaultGoogleModel = 'gemini-2.5-pro';
const _kDefaultAnthropicModel = 'claude-opus-4-7';
const _kDefaultRetryIntervals = [
  Duration(seconds: 5),
  Duration(seconds: 20),
  Duration(seconds: 60),
  Duration(seconds: 60),
  Duration(seconds: 60),
];
const _kTranslatorLogName = 'translator_dart.translator';

/// The AI provider used for translation requests.
enum TranslationProvider { openai, google, anthropic }

/// Shared environment-backed settings for the translation tools.
class TranslationConfig {
  final TranslationProvider provider;
  final String model;
  final String apiKey;
  final String? baseUrl;
  final String? organization;
  final String? project;

  const TranslationConfig._({
    required this.provider,
    required this.model,
    required this.apiKey,
    this.baseUrl,
    this.organization,
    this.project,
  });

  /// Loads the provider choice and credentials once so every translation
  /// entrypoint follows the same validation rules.
  factory TranslationConfig.fromEnvironment({
    Map<String, String>? environment,
  }) {
    final env = environment ?? Platform.environment;
    final providerName =
        _readOptionalEnvironmentValue(env, 'TRANSLATION_PROVIDER') ?? 'openai';
    final provider = _parseProvider(providerName);
    final configuredModel = _readOptionalEnvironmentValue(
      env,
      'TRANSLATION_MODEL',
    );

    switch (provider) {
      case TranslationProvider.openai:
        return TranslationConfig._(
          provider: provider,
          model: configuredModel ?? _kDefaultOpenAIModel,
          apiKey: _readRequiredEnvironmentValue(env, 'OPENAI_API_KEY'),
          baseUrl: _readOptionalEnvironmentValue(env, 'OPENAI_BASE_URL'),
          organization: _readOptionalEnvironmentValue(env, 'OPENAI_ORG_ID'),
          project: _readOptionalEnvironmentValue(env, 'OPENAI_PROJECT_ID'),
        );
      case TranslationProvider.google:
        return TranslationConfig._(
          provider: provider,
          model: configuredModel ?? _kDefaultGoogleModel,
          apiKey: _readRequiredEnvironmentValue(env, 'GOOGLE_GENAI_API_KEY'),
        );
      case TranslationProvider.anthropic:
        return TranslationConfig._(
          provider: provider,
          model: configuredModel ?? _kDefaultAnthropicModel,
          apiKey: _readRequiredEnvironmentValue(env, 'ANTHROPIC_API_KEY'),
          baseUrl: _readOptionalEnvironmentValue(env, 'ANTHROPIC_BASE_URL'),
        );
    }
  }

  String get requestLabel => '${provider.name}/$model';
}

/// Provider-specific transport that turns a translation prompt into text.
abstract class TranslationClient {
  TranslationProvider get provider;

  String get model;

  Future<String> translatePrompt(String prompt);

  factory TranslationClient.fromEnvironment({
    Map<String, String>? environment,
  }) {
    return TranslationClient.fromConfig(
      TranslationConfig.fromEnvironment(environment: environment),
    );
  }

  factory TranslationClient.fromConfig(TranslationConfig config) {
    switch (config.provider) {
      case TranslationProvider.openai:
        return _OpenAITranslationClient(config);
      case TranslationProvider.google:
        return _GoogleTranslationClient(config);
      case TranslationProvider.anthropic:
        return _AnthropicTranslationClient(config);
    }
  }
}

/// Shared prompt-to-text adapter used by every translation entrypoint.
abstract class Translator {
  final TranslationClient client;
  final List<Duration> retryIntervals;
  final Future<void> Function(Duration duration) waitForRetry;

  Translator({
    TranslationClient? client,
    List<Duration>? retryIntervals,
    Future<void> Function(Duration duration)? waitForRetry,
  }) : client = client ?? TranslationClient.fromEnvironment(),
       retryIntervals = retryIntervals ?? _kDefaultRetryIntervals,
       waitForRetry = waitForRetry ?? Future.delayed;

  String prompt(String text, String targetLanguage);

  Future<String> translateText(String text, String targetLanguage) async {
    final builtPrompt = prompt(text, targetLanguage);

    // Retries stay in the shared base class so every translation workflow
    // keeps the same failure handling regardless of provider.
    for (int i = 0; i <= retryIntervals.length; i++) {
      try {
        final translatedText = (await client.translatePrompt(
          builtPrompt,
        )).trim();
        if (translatedText.isEmpty) {
          throw StateError(
            'Provider returned blank text for ${client.provider.name}/'
            '${client.model}.',
          );
        }
        return translatedText;
      } catch (e) {
        if (i < retryIntervals.length) {
          final retryDelay = retryIntervals[i];
          developer.log(
            'Error translating text with ${client.provider.name}/'
            '${client.model}: $e\nRetrying in ${retryDelay.inSeconds} '
            'seconds...',
            name: _kTranslatorLogName,
            error: e,
          );
          await waitForRetry(retryDelay);
        } else {
          throw Exception(
            'Failed to translate text with ${client.provider.name}/'
            '${client.model} after multiple attempts: $e',
          );
        }
      }
    }

    return '';
  }
}

class _OpenAITranslationClient implements TranslationClient {
  final TranslationConfig _config;
  final openai.OpenAIClient _client;

  _OpenAITranslationClient(this._config)
    : _client = openai.OpenAIClient(
        config: openai.OpenAIConfig(
          authProvider: openai.ApiKeyProvider(_config.apiKey),
          baseUrl: _config.baseUrl ?? 'https://api.openai.com/v1',
          organization: _config.organization,
          project: _config.project,
        ),
      );

  @override
  TranslationProvider get provider => _config.provider;

  @override
  String get model => _config.model;

  @override
  Future<String> translatePrompt(String prompt) async {
    final response = await _client.responses.create(
      openai.CreateResponseRequest(
        model: model,
        input: openai.ResponseInput.text(prompt),
        temperature: 0.7,
      ),
    );
    return response.outputText;
  }
}

class _GoogleTranslationClient implements TranslationClient {
  final TranslationConfig _config;
  final googleai.GoogleAIClient _client;

  _GoogleTranslationClient(this._config)
    : _client = googleai.GoogleAIClient(
        config: googleai.GoogleAIConfig.googleAI(
          apiVersion: googleai.ApiVersion.v1,
          authProvider: googleai.ApiKeyProvider(_config.apiKey),
        ),
      );

  @override
  TranslationProvider get provider => _config.provider;

  @override
  String get model => _config.model;

  @override
  Future<String> translatePrompt(String prompt) async {
    final response = await _client.models.generateContent(
      model: model,
      request: googleai.GenerateContentRequest(
        contents: [googleai.Content.text(prompt)],
        generationConfig: const googleai.GenerationConfig(temperature: 0.7),
      ),
    );
    return response.text ?? '';
  }
}

class _AnthropicTranslationClient implements TranslationClient {
  final TranslationConfig _config;
  final anthropic.AnthropicClient _client;

  _AnthropicTranslationClient(this._config)
    : _client = anthropic.AnthropicClient(
        config: anthropic.AnthropicConfig(
          authProvider: anthropic.ApiKeyProvider(_config.apiKey),
          baseUrl: _config.baseUrl ?? 'https://api.anthropic.com',
        ),
      );

  @override
  TranslationProvider get provider => _config.provider;

  @override
  String get model => _config.model;

  @override
  Future<String> translatePrompt(String prompt) async {
    final response = await _client.messages.create(
      anthropic.MessageCreateRequest(
        model: model,
        maxTokens: 1024,
        temperature: 0.7,
        messages: [anthropic.InputMessage.user(prompt)],
      ),
    );
    return response.text;
  }
}

String _readRequiredEnvironmentValue(Map<String, String> env, String key) {
  final value = _readOptionalEnvironmentValue(env, key);
  if (value == null) {
    throw StateError('Missing required environment variable: $key');
  }
  return value;
}

String? _readOptionalEnvironmentValue(Map<String, String> env, String key) {
  final value = env[key]?.trim();
  if (value == null || value.isEmpty) {
    return null;
  }
  return value;
}

TranslationProvider _parseProvider(String rawValue) {
  for (final provider in TranslationProvider.values) {
    if (provider.name == rawValue) {
      return provider;
    }
  }

  throw StateError(
    'Unsupported translation provider "$rawValue". Expected one of: '
    '${TranslationProvider.values.map((provider) => provider.name).join(', ')}.',
  );
}
