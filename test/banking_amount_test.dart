import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile_assginment/core/formatters/rm_currency.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_manager.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_screen.dart';
import 'package:mobile_assginment/features/calculator_roi/calc_validators.dart';
import 'package:mobile_assginment/features/loan_approval/loan_manager.dart';
import 'package:mobile_assginment/features/loan_approval/loan_screen.dart';
import 'package:mobile_assginment/features/ai/ai_manager.dart';
import 'package:mobile_assginment/features/ai/models/ai_recommendation.dart';
import 'package:mobile_assginment/services/ai/ai_repository.dart';

void main() {
  test('RM currency includes grouping and exactly two decimals', () {
    expect(formatRm(15001), 'RM 15,001.00');
    expect(formatRm(5555), 'RM 5,555.00');
    expect(formatRm(10000.5), 'RM 10,000.50');
    expect(formatRm(0), 'RM 0.00');
  });

  test('equipment price requires exact decimals and inclusive min max', () {
    expect(validateEquipmentPrice(''), 'Equipment price is required.');
    for (final value in ['5000.00', '25000.50', '600000.00']) {
      expect(validateEquipmentPrice(value), isNull);
    }
    for (final value in [
      '-100',
      '10000',
      'abc',
      'NaN',
      '5000.0',
      '5000.000',
      '5e3',
    ]) {
      expect(
        validateEquipmentPrice(value),
        'Enter price in RM format (e.g. 5000.00).',
      );
    }
    expect(
      validateEquipmentPrice('4999.99'),
      'Minimum equipment price is RM 5,000.00.',
    );
    expect(
      validateEquipmentPrice('600001.00'),
      'Maximum equipment price is RM 600,000.00.',
    );
  });

  test('quantity requires integer from 1 through 999', () {
    expect(validateEquipmentQuantity(''), 'Quantity is required.');
    for (final value in ['1', '999']) {
      expect(validateEquipmentQuantity(value), isNull);
    }
    for (final value in ['0', '1000', '-1', '1.5', 'abc', '1e2']) {
      expect(validateEquipmentQuantity(value), isNotNull);
    }
  });

  test('invalid form zeroes all totals and saved scheme retains cents', () {
    final calc = CalcManager();
    calc.updateEquipmentPrice('25000.50');
    calc.updateQuantity('2');
    expect(calc.monthlyPayment, greaterThan(0));
    for (final price in ['', '10000', '4999.99', '600001.00', '-100', 'abc']) {
      calc.updateEquipmentPrice(price);
      expect(calc.monthlyPayment, 0);
      expect(calc.totalPayment, 0);
      expect(calc.totalInterest, 0);
      expect(calc.hasValidInputs, isFalse);
    }
    calc.updateEquipmentPrice('5000.00');
    for (final quantity in ['', '0', '1000', '-1', '1.1', 'abc']) {
      calc.updateQuantity(quantity);
      expect(calc.monthlyPayment, 0);
      expect(calc.totalPayment, 0);
      expect(calc.totalInterest, 0);
    }
    calc.loadSchemeForEditing(
      CalcScheme(
        id: 's',
        title: 'Saved',
        equipmentPrice: 25000.50,
        unitCount: 2,
        loanTermMonths: 36,
        interestRate: 4.5,
        monthlyPayment: 0,
        totalPayment: 0,
      ),
    );
    expect(calc.equipmentPriceText, '25000.50');
    expect(calc.monthlyPayment, greaterThan(0));
    calc.dispose();
  });

  testWidgets(
    'invalid inputs disable AI and discard outdated advice in both orientations',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final size in [const Size(390, 844), const Size(844, 390)]) {
        tester.view.physicalSize = size;
        final calc = CalcManager();
        final repository = _PendingAi();
        final ai = AiManager(repository);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: calc),
              ChangeNotifierProvider.value(value: ai),
            ],
            child: const MaterialApp(home: Scaffold(body: CalcScreen())),
          ),
        );
        final button = find.widgetWithText(
          ElevatedButton,
          'Generate AI Advice',
        );
        expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
        expect(find.text('RM 0.00'), findsNWidgets(3));
        await tester.enterText(find.byType(TextFormField).at(0), '5000.00');
        await tester.enterText(find.byType(TextFormField).at(1), '1');
        await tester.pumpAndSettle();
        expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pump();
        expect(repository.calls, 1);
        await tester.enterText(find.byType(TextFormField).at(0), '10000');
        await tester.pumpAndSettle();
        expect(tester.widget<ElevatedButton>(button).onPressed, isNull);
        expect(calc.monthlyPayment, 0);
        expect(
          find.text('Enter price in RM format (e.g. 5000.00).'),
          findsOneWidget,
        );
        repository.response.complete(
          const AiRecommendation(
            riskLevel: 'Low',
            summary: 'Old advice',
            recommendation: 'Old',
            cashflowAdvice: 'Old',
            confidence: 80,
          ),
        );
        await tester.pumpAndSettle();
        expect(ai.recommendation, isNull);
        expect(find.text('Old advice'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        calc.dispose();
        ai.dispose();
      }
    },
  );

  testWidgets('SME and banker loan cards use the same RM display', (
    tester,
  ) async {
    for (final banker in [false, true]) {
      final manager = LoanManager();
      await manager.addLoanRequest(
        LoanRequest(
          id: 'p',
          companyName: 'Test company',
          equipmentName: 'Robotic Arm',
          loanAmount: 10000.5,
          interestRate: 4.5,
        ),
      );
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: manager,
          child: MaterialApp(
            home: Scaffold(body: LoanScreen(isBanker: banker)),
          ),
        ),
      );
      expect(find.textContaining('RM 10,000.50'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      manager.dispose();
    }
  });
}

class _PendingAi implements AiRecommendationRepository {
  int calls = 0;
  final response = Completer<AiRecommendation>();
  @override
  Future<AiRecommendation> generateRecommendation(AiAdvisorInput input) {
    calls++;
    return response.future;
  }
}
