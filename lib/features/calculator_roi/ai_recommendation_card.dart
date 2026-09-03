import 'package:flutter/material.dart';

import '../../core/constants.dart';
import '../ai/models/ai_recommendation.dart';

class AiRecommendationCard extends StatelessWidget {
  final AiRecommendation recommendation;

  const AiRecommendationCard({super.key, required this.recommendation});

  @override
  Widget build(BuildContext context) {
    final riskColor = _riskColor(recommendation.riskLevel);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Chip(
            avatar: Icon(Icons.shield_outlined, color: riskColor, size: 18),
            label: Text('${recommendation.riskLevel} Risk'),
            labelStyle: TextStyle(
              color: riskColor,
              fontWeight: FontWeight.w700,
            ),
            backgroundColor: riskColor.withValues(alpha: 0.1),
            side: BorderSide(color: riskColor.withValues(alpha: 0.35)),
          ),
        ),
        _AdviceSection(label: 'Summary', value: recommendation.summary),
        _AdviceSection(
          label: 'Recommendation',
          value: recommendation.recommendation,
        ),
        _AdviceSection(
          label: 'Cash-flow Advice',
          value: recommendation.cashflowAdvice,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(
              Icons.verified_outlined,
              size: 18,
              color: AppColors.accentBlue,
            ),
            const SizedBox(width: 6),
            Text(
              'Confidence ${recommendation.confidence.toStringAsFixed(0)}%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: recommendation.confidence / 100,
          color: AppColors.accentBlue,
          backgroundColor: AppColors.accentBlue.withValues(alpha: 0.12),
        ),
      ],
    );
  }

  Color _riskColor(String riskLevel) {
    return switch (riskLevel.toLowerCase()) {
      'low' => AppColors.success,
      'high' => AppColors.error,
      _ => AppColors.warning,
    };
  }
}

class _AdviceSection extends StatelessWidget {
  final String label;
  final String value;

  const _AdviceSection({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.mediumGrey,
            ),
          ),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(height: 1.35)),
        ],
      ),
    );
  }
}
