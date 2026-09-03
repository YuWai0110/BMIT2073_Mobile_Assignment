import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

import '../../features/ai/models/ai_recommendation.dart';

class GeminiService {
  static const String _modelName = 'gemini-3.5-flash-lite';
  static const Duration _requestTimeout = Duration(seconds: 30);

  final String? _apiKey;

  GeminiService._({this._apiKey});

  factory GeminiService.fromEnvironment() {
    return GeminiService._(apiKey: dotenv.env['GEMINI_API_KEY']);
  }

  Future<String> generateAdvice(AiAdvisorInput input) async {
    final configuredKey = _apiKey?.trim();
    if (configuredKey == null || configuredKey.isEmpty) {
      throw const AiConfigurationException();
    }

    final model = GenerativeModel(
      model: _modelName,
      apiKey: configuredKey,
      generationConfig: GenerationConfig(
        temperature: 0.2,
        maxOutputTokens: 500,
        responseMimeType: 'application/json',
      ),
    );

    try {
      final response = await _generateWithRetry(model, _buildPrompt(input));
      final text = response.text?.trim();
      if (text == null || text.isEmpty) {
        throw const AiEmptyResponseException();
      }
      return text;
    } on AiAdvisorException {
      rethrow;
    } catch (error) {
      if (error is TimeoutException) {
        throw const AiTimeoutException();
      }
      throw mapGeminiFailure(error);
    }
  }

  Future<GenerateContentResponse> _generateWithRetry(
    GenerativeModel model,
    String prompt,
  ) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        return await model
            .generateContent([Content.text(prompt)])
            .timeout(_requestTimeout);
      } catch (error) {
        if (kDebugMode) {
          debugPrint('Gemini request attempt ${attempt + 1} failed: $error');
        }
        if (attempt == 0 && _isRetriableRequestError(error)) {
          continue;
        }
        rethrow;
      }
    }

    throw const AiServiceUnavailableException();
  }

  bool _isRetriableRequestError(Object error) {
    return error is TimeoutException ||
        error.toString().contains('SocketException');
  }

  String _buildPrompt(AiAdvisorInput input) {
    return '''You are a Malaysian SME Financial Advisor for equipment financing.
Review the calculator data below. Give practical educational guidance only; do not guarantee loan approval or investment returns.

Calculator data:
${jsonEncode(input.toJson())}

Return JSON ONLY. Do not use Markdown, code fences, explanations, or additional keys.
Use exactly this schema:
{
  "risk_level": "Low | Medium | High",
  "summary": "short assessment",
  "recommendation": "clear financing recommendation",
  "cashflow_advice": "specific cash-flow advice",
  "confidence": 0
}

confidence must be a number from 0 to 100.''';
  }
}

sealed class AiAdvisorException implements Exception {
  const AiAdvisorException();
}

class AiConfigurationException extends AiAdvisorException {
  const AiConfigurationException();
}

class AiAuthenticationException extends AiAdvisorException {
  const AiAuthenticationException();
}

class AiQuotaExceededException extends AiAdvisorException {
  const AiQuotaExceededException();
}

class AiTimeoutException extends AiAdvisorException {
  const AiTimeoutException();
}

class AiEmptyResponseException extends AiAdvisorException {
  const AiEmptyResponseException();
}

class AiServiceUnavailableException extends AiAdvisorException {
  const AiServiceUnavailableException();
}

AiAdvisorException mapGeminiFailure(Object error) {
  if (error is InvalidApiKey) {
    return const AiAuthenticationException();
  }

  if (error is ServerException || error is GenerativeAIException) {
    final message = switch (error) {
      ServerException() => error.message.toLowerCase(),
      GenerativeAIException() => error.message.toLowerCase(),
      _ => '',
    };

    if (message.contains('api_key_invalid') ||
        message.contains('api key not valid') ||
        message.contains('invalid api key') ||
        message.contains('permission_denied')) {
      return const AiAuthenticationException();
    }

    if (message.contains('resource_exhausted') ||
        message.contains('quota') ||
        message.contains('rate limit') ||
        message.contains('too many requests') ||
        message.contains('429')) {
      return const AiQuotaExceededException();
    }
  }

  return const AiServiceUnavailableException();
}
