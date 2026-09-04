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
  int _requestVersion = 0;

  AiRecommendation? get recommendation => _recommendation;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> generateAdvice(AiAdvisorInput input) async {
    if (!input.equipmentPrice.isFinite ||
        input.equipmentPrice < 5000 ||
        input.equipmentPrice > 600000 ||
        input.quantity < 1 ||
        input.quantity > 999) {
      return;
    }
    if (_isLoading) return;
    final version = ++_requestVersion;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.generateRecommendation(input);
      if (version == _requestVersion) _recommendation = result;
    } on AiConfigurationException {
      if (version != _requestVersion) return;
      _errorMessage = 'Gemini API key is not configured.';
    } on AiAuthenticationException {
      if (version != _requestVersion) return;
      _errorMessage = 'Gemini authentication failed.';
    } on AiQuotaExceededException {
      if (version != _requestVersion) return;
      _errorMessage = 'Gemini quota exceeded. Please try again later.';
    } on AiTimeoutException {
      if (version != _requestVersion) return;
      _errorMessage = 'AI advice took too long. Please try again.';
    } on AiEmptyResponseException {
      if (version != _requestVersion) return;
      _errorMessage = 'AI returned no advice. Please try again.';
    } on AiResponseFormatException {
      if (version != _requestVersion) return;
      _errorMessage =
          'AI returned an unreadable recommendation. Please try again.';
    } on AiServiceUnavailableException {
      if (version != _requestVersion) return;
      _errorMessage =
          'AI service is unavailable. Check your internet connection and try again.';
    } catch (_) {
      if (version != _requestVersion) return;
      _errorMessage =
          'Unable to generate AI advice right now. Please try again.';
    } finally {
      if (version == _requestVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  void clearRecommendation() {
    _requestVersion++;
    if (_recommendation == null && _errorMessage == null && !_isLoading) return;
    _isLoading = false;
    _recommendation = null;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _requestVersion++;
    super.dispose();
  }
}
