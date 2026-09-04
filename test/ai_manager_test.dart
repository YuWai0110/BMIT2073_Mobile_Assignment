import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:mobile_assginment/features/ai/ai_manager.dart';
import 'package:mobile_assginment/features/ai/models/ai_recommendation.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_manager.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_screen.dart';
import 'package:mobile_assginment/services/ai/ai_repository.dart';
import 'package:mobile_assginment/services/ai/gemini_service.dart';
import 'package:provider/provider.dart';

void main() {
  const input = AiAdvisorInput(
    equipmentName: 'Robotic Arm',
    equipmentPrice: 50000,
    quantity: 2,
    loanAmount: 100000,
    interestRate: 4.5,
    repaymentYears: 3,
    monthlyEmi: 2974.79,
    currentOpr: 3,
  );

  test('parses a valid Gemini JSON recommendation', () {
    final recommendation = AiRecommendation.fromJsonString('''
      {
        "risk_level": "Medium",
        "summary": "The instalment is manageable with stable revenue.",
        "recommendation": "Proceed after confirming supplier quotations.",
        "cashflow_advice": "Keep three months of instalments in reserve.",
        "confidence": 84
      }
    ''');

    expect(recommendation.riskLevel, 'Medium');
    expect(recommendation.confidence, 84);
  });

  test('rejects invalid Gemini JSON recommendations', () {
    expect(
      () => AiRecommendation.fromJsonString('No JSON available'),
      throwsA(isA<AiResponseFormatException>()),
    );
  });

  test('AiManager stores a successful recommendation', () async {
    final manager = AiManager(
      _FakeAiRepository(
        recommendation: const AiRecommendation(
          riskLevel: 'Low',
          summary: 'Healthy repayment profile.',
          recommendation: 'Proceed with a conservative term.',
          cashflowAdvice: 'Maintain an emergency reserve.',
          confidence: 90,
        ),
      ),
    );

    await manager.generateAdvice(input);

    expect(manager.recommendation?.riskLevel, 'Low');
    expect(manager.errorMessage, isNull);
    expect(manager.isLoading, isFalse);
  });

  test('AiManager converts service failures into a friendly message', () async {
    final manager = AiManager(
      _FakeAiRepository(error: const AiServiceUnavailableException()),
    );

    await manager.generateAdvice(input);

    expect(manager.recommendation, isNull);
    expect(manager.errorMessage, contains('internet connection'));
    expect(manager.errorMessage, isNot(contains('Exception')));
  });

  test('AiManager identifies a missing Gemini API key', () async {
    final manager = AiManager(
      _FakeAiRepository(error: const AiConfigurationException()),
    );

    await manager.generateAdvice(input);

    expect(manager.errorMessage, 'Gemini API key is not configured.');
  });

  test('AiManager identifies Gemini authentication failures', () async {
    final manager = AiManager(
      _FakeAiRepository(error: const AiAuthenticationException()),
    );

    await manager.generateAdvice(input);

    expect(manager.errorMessage, 'Gemini authentication failed.');
  });

  test('AiManager identifies Gemini quota failures', () async {
    final manager = AiManager(
      _FakeAiRepository(error: const AiQuotaExceededException()),
    );

    await manager.generateAdvice(input);

    expect(
      manager.errorMessage,
      'Gemini quota exceeded. Please try again later.',
    );
  });

  test('Gemini failures classify invalid keys and quota separately', () {
    expect(
      mapGeminiFailure(InvalidApiKey('invalid')),
      isA<AiAuthenticationException>(),
    );
    expect(
      mapGeminiFailure(ServerException('RESOURCE_EXHAUSTED: quota exceeded')),
      isA<AiQuotaExceededException>(),
    );
  });

  testWidgets('Calculator displays a generated AI recommendation', (
    tester,
  ) async {
    final aiManager = AiManager(
      _FakeAiRepository(
        recommendation: const AiRecommendation(
          riskLevel: 'Medium',
          summary: 'The monthly instalment needs stable sales coverage.',
          recommendation: 'Proceed after confirming supplier pricing.',
          cashflowAdvice: 'Keep a repayment buffer before disbursement.',
          confidence: 86,
        ),
      ),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: aiManager),
          ChangeNotifierProvider(create: (_) => CalcManager()),
        ],
        child: const MaterialApp(home: Scaffold(body: CalcScreen())),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).at(0), '50000.00');
    await tester.enterText(find.byType(TextFormField).at(1), '1');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Generate AI Advice'));
    await tester.tap(find.text('Generate AI Advice'));
    await tester.pumpAndSettle();

    expect(find.text('Medium Risk'), findsOneWidget);
    expect(find.text('Confidence 86%'), findsOneWidget);
    expect(find.text('Cash-flow Advice'), findsOneWidget);
  });
}

class _FakeAiRepository implements AiRecommendationRepository {
  final AiRecommendation? recommendation;
  final Object? error;

  const _FakeAiRepository({this.recommendation, this.error});

  @override
  Future<AiRecommendation> generateRecommendation(AiAdvisorInput input) async {
    if (error != null) throw error!;
    return recommendation!;
  }
}
