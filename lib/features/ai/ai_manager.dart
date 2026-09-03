import 'package:flutter/foundation.dart';

import '../../services/ai/ai_repository.dart';
import '../../services/ai/gemini_service.dart';
import 'models/ai_recommendation.dart';

class AiManager extends ChangeNotifier {
  final AiRecommendationRepository _repository;

  AiManager(this._repository);

  AiRecommendation? _recommendation;
  bool _isLoading = false;
  String? _errorMessage;

  AiRecommendation? get recommendation => _recommendation;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> generateAdvice(AiAdvisorInput input) async {
    if (_isLoading) return;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _recommendation = await _repository.generateRecommendation(input);
    } on AiConfigurationException {
      _errorMessage = 'Gemini API key is not configured.';
    } on AiAuthenticationException {
      _errorMessage = 'Gemini authentication failed.';
    } on AiQuotaExceededException {
      _errorMessage = 'Gemini quota exceeded. Please try again later.';
    } on AiTimeoutException {
      _errorMessage = 'AI advice took too long. Please try again.';
    } on AiEmptyResponseException {
      _errorMessage = 'AI returned no advice. Please try again.';
    } on AiResponseFormatException {
      _errorMessage =
          'AI returned an unreadable recommendation. Please try again.';
    } on AiServiceUnavailableException {
      _errorMessage =
          'AI service is unavailable. Check your internet connection and try again.';
    } catch (_) {
      _errorMessage =
          'Unable to generate AI advice right now. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearRecommendation() {
    if (_recommendation == null && _errorMessage == null) return;
    _recommendation = null;
    _errorMessage = null;
    notifyListeners();
  }
}
