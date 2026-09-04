import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_assginment/core/widgets/loading_skeletons.dart';
import 'package:mobile_assginment/features/ai/ai_manager.dart';
import 'package:mobile_assginment/features/ai/models/ai_recommendation.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_manager.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_screen.dart';
import 'package:mobile_assginment/features/loan_approval/loan_manager.dart';
import 'package:mobile_assginment/features/loan_approval/loan_screen.dart';
import 'package:mobile_assginment/services/ai/ai_repository.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'calculator preserves inputs results edit state and AI across orientation',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      final calc = CalcManager();
      calc.updateEquipmentPrice('50000');
      calc.updateQuantity('2');
      calc.updateInterestRate(6.25);
      calc.updateLoanTerm(84);
      calc.loadSchemeForEditing(
        CalcScheme(
          id: 'editing',
          title: 'Factory Upgrade',
          equipmentPrice: 50000,
          unitCount: 2,
          loanTermMonths: 84,
          interestRate: 6.25,
          monthlyPayment: calc.monthlyPayment,
          totalPayment: calc.totalPayment,
        ),
      );
      final repository = _CompletingAiRepository();
      final ai = AiManager(repository);

      Future<void> pump(Size size) async {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: calc),
              ChangeNotifierProvider.value(value: ai),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: KeyedSubtree(
                  key: ValueKey(size),
                  child: const CalcScreen(),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pump(const Size(390, 844));
      expect(find.text('Update Saved Scheme'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).at(0))
            .controller
            ?.text,
        '50000',
      );
      await tester.ensureVisible(find.text('Generate AI Advice'));
      await tester.tap(find.text('Generate AI Advice'));
      await tester.pump();
      expect(ai.isLoading, isTrue);

      await pump(const Size(844, 390));
      expect(ai.isLoading, isTrue);
      expect(find.byType(AiAdvisorSkeleton), findsOneWidget);
      expect(calc.formInterestRate, 6.25);
      expect(calc.formLoanTermMonths, 84);
      expect(calc.editingSchemeId, 'editing');
      expect(calc.monthlyPayment, greaterThan(0));
      expect(calc.totalPayment, greaterThan(calc.monthlyPayment));
      expect(calc.totalInterest, greaterThan(0));

      repository.complete();
      await tester.pumpAndSettle();
      expect(find.text('Low Risk'), findsOneWidget);
      expect(find.text('Confidence 91%'), findsOneWidget);

      await pump(const Size(390, 844));
      await tester.ensureVisible(find.text('Low Risk'));
      expect(find.text('Low Risk'), findsOneWidget);
      expect(ai.recommendation?.confidence, 91);
      expect(calc.equipmentPriceText, '50000');
      expect(calc.quantityText, '2');
      expect(find.text('Update Saved Scheme'), findsOneWidget);
    },
  );

  testWidgets('loan form and validation survive orientation recreation', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    final manager = LoanManager();

    Future<void> pump(Size size) async {
      tester.view.physicalSize = size;
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: manager,
          child: MaterialApp(
            home: Scaffold(
              body: KeyedSubtree(
                key: ValueKey(size),
                child: const LoanScreen(isBanker: false),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pump(const Size(390, 844));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'OptiMach MY');
    await tester.enterText(fields.at(1), 'not-a-number');
    manager.updateFormEquipmentType('Robotic Arm');
    manager.updateFormInterestRate(7.5);
    manager.updateFormRepaymentYears(7);
    await tester.ensureVisible(find.text('Submit Application'));
    await tester.tap(find.text('Submit Application'));
    await tester.pump();
    expect(find.text('Enter a valid number'), findsOneWidget);
    expect(manager.formValidationVisible, isTrue);

    await pump(const Size(844, 390));
    expect(manager.formCompanyName, 'OptiMach MY');
    expect(manager.formLoanAmount, 'not-a-number');
    expect(manager.formEquipmentType, 'Robotic Arm');
    expect(manager.formInterestRate, 7.5);
    expect(manager.formRepaymentYears, 7);
    expect(manager.formValidationVisible, isTrue);
    expect(find.text('Enter a valid number'), findsOneWidget);
    expect(
      tester
          .widget<TextFormField>(find.byType(TextFormField).at(0))
          .controller
          ?.text,
      'OptiMach MY',
    );

    await pump(const Size(390, 844));
    expect(find.text('Enter a valid number'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _CompletingAiRepository implements AiRecommendationRepository {
  final _completer = Completer<AiRecommendation>();

  @override
  Future<AiRecommendation> generateRecommendation(AiAdvisorInput input) {
    return _completer.future;
  }

  void complete() {
    _completer.complete(
      const AiRecommendation(
        riskLevel: 'Low',
        summary: 'Cash flow supports the projected repayment.',
        recommendation: 'Proceed with supplier verification.',
        cashflowAdvice: 'Maintain a three-month repayment reserve.',
        confidence: 91,
      ),
    );
  }
}
