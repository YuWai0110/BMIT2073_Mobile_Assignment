import '../../features/ai/models/ai_recommendation.dart';
import 'gemini_service.dart';

abstract interface class AiRecommendationRepository {
  Future<AiRecommendation> generateRecommendation(AiAdvisorInput input);
}

class AiRepository implements AiRecommendationRepository {
  final GeminiService _service;

  const AiRepository(this._service);

  @override
  Future<AiRecommendation> generateRecommendation(AiAdvisorInput input) async {
    final response = await _service.generateAdvice(input);
    return AiRecommendation.fromJsonString(response);
  }
}
