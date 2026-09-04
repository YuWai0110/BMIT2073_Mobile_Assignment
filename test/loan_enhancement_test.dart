import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mobile_assginment/features/loan_approval/loan_manager.dart';
import 'package:mobile_assginment/features/loan_approval/loan_screen.dart';
import 'package:mobile_assginment/features/loan_approval/loan_validators.dart';
import 'package:mobile_assginment/services/supabase/loan_repository.dart';
import 'package:mobile_assginment/services/supabase/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

LoanRequest loan(String id, {LoanStatus status = LoanStatus.pending}) =>
    LoanRequest(
      id: id,
      companyName: 'OptiMach',
      equipmentName: 'Robotic Arm',
      loanAmount: 10000.50,
      interestRate: 4.5,
      status: status,
      submittedAt: DateTime(2026, 9, 4),
    );

void main() {
  test(
    'repository fetches latest server status before allowing updates',
    () async {
      final client = SupabaseClient(
        'https://example.invalid',
        'test-public-key',
      );
      final repository = _CloudRepository(SupabaseService(client));
      repository.rows.single['status'] = 'approved';
      await expectLater(
        repository.updateApplication('p', {}),
        throwsA(isA<LoanOperationException>()),
      );
      expect(repository.fetches, 1);
      await client.dispose();
    },
  );

  testWidgets(
    'banker pending delete waits for cloud and retains row on failure',
    (tester) async {
      final repository = _DelayedDeleteRepository();
      final manager = LoanManager(repository);
      await manager.loadApplications();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: manager,
          child: const MaterialApp(
            home: Scaffold(body: LoanScreen(isBanker: true)),
          ),
        ),
      );
      await tester.drag(find.byType(Dismissible), const Offset(-700, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(manager.allRequests.length, 1);
      expect(tester.takeException(), isNull);
      repository.deletion.completeError(
        const LoanOperationException('Unable to delete. Please try again.'),
      );
      await tester.pumpAndSettle();
      expect(manager.allRequests.length, 1);
      expect(find.text('Unable to delete. Please try again.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      manager.dispose();
    },
  );
  test(
    'company and exact decimal amount validation and integer cents parsing',
    () {
      expect(validateLoanCompany(' '), 'Company name is required.');
      expect(validateLoanCompany('A' * 50), isNull);
      expect(
        validateLoanCompany('A' * 51),
        'Company name cannot exceed 50 characters.',
      );
      expect(validateLoanAmount(''), 'Loan amount is required.');
      for (final amount in [
        '4500',
        '-100',
        '10000',
        'abc',
        '1e4',
        '5000.000',
      ]) {
        expect(
          validateLoanAmount(amount),
          'Enter amount in RM format (e.g. 5000.00).',
        );
      }
      expect(
        validateLoanAmount('4999.99'),
        'Minimum loan amount is RM 5,000.00.',
      );
      expect(
        validateLoanAmount('600000.01'),
        'Maximum loan amount is RM 600,000.00.',
      );
      for (final amount in ['5000.00', '10000.50', '550000.00', '600000.00']) {
        expect(validateLoanAmount(amount), isNull);
      }
      expect(parseLoanAmountCents('10000.50'), 1000050);
      expect(parseLoanAmountCents('10000'), isNull);
    },
  );

  test(
    'Provider filters and unlimited pending edits preserve submission date',
    () async {
      final manager = LoanManager();
      await manager.addLoanRequest(loan('p'));
      await manager.addLoanRequest(loan('a', status: LoanStatus.approved));
      await manager.addLoanRequest(loan('r', status: LoanStatus.notApproved));
      expect(manager.filteredRequests.length, 3);
      for (final entry in {
        LoanFilter.pending: 'p',
        LoanFilter.approved: 'a',
        LoanFilter.rejected: 'r',
      }.entries) {
        manager.setFilter(entry.key);
        expect(manager.filteredRequests.single.id, entry.value);
      }
      manager.setFilter(LoanFilter.all);
      expect(manager.startEditing('a'), isNotNull);
      expect(await manager.deletePending('a'), isNotNull);
      for (var count = 1; count <= 5; count++) {
        expect(manager.startEditing('p'), isNull);
        manager.updateFormCompanyName('Edit $count');
        expect(await manager.saveForm(), isNull);
        expect(manager.allRequests.first.companyName, 'Edit $count');
        expect(manager.allRequests.first.submittedAt, DateTime(2026, 9, 4));
      }
      expect(manager.startEditing('p'), isNull);
      expect(await manager.updateApplication(loan('p')), isNull);
      manager.dispose();
    },
  );

  test(
    'legacy dates fallback and account changes clear drafts and filters',
    () async {
      final request = LoanRequest.fromMap({
        'id': 'old',
        'company_name': 'Legacy',
        'equipment_name': 'Robotic Arm',
        'amount': 5000,
        'interest_rate': 4.5,
        'repayment_years': 5,
        'status': 'pending',
        'created_at': '2026-09-04T00:00:00Z',
      });
      expect(request.submittedAt, request.createdAt);
      final manager = LoanManager();
      manager.setUser('one');
      await manager.addLoanRequest(request);
      manager.startEditing('old');
      manager.setFilter(LoanFilter.pending);
      manager.setUser('two');
      expect(manager.isEditing, isFalse);
      expect(manager.formCompanyName, isEmpty);
      expect(manager.allRequests, isEmpty);
      expect(manager.filter, LoanFilter.all);
      manager.dispose();
    },
  );

  testWidgets(
    'loan edit draft validation and filter survive orientation recreation',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      final manager = LoanManager();
      await manager.addLoanRequest(loan('p'));
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
        await tester.pumpAndSettle();
      }

      await pump(const Size(390, 844));
      await tester.ensureVisible(find.byKey(const ValueKey('edit-p')));
      await tester.tap(find.byKey(const ValueKey('edit-p')));
      await tester.pumpAndSettle();
      expect(find.text('Edit Loan Application'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField).at(0), 'Draft Company');
      await tester.enterText(find.byType(TextFormField).at(1), '4500.00');
      manager.updateFormEquipmentType('AI Vision Inspector');
      manager.updateFormInterestRate(6.0);
      manager.updateFormRepaymentYears(7);
      manager.setFilter(LoanFilter.pending);
      for (final size in [const Size(844, 390), const Size(390, 844)]) {
        await pump(size);
        expect(manager.editingId, 'p');
        expect(manager.filter, LoanFilter.pending);
        expect(manager.formCompanyName, 'Draft Company');
        expect(manager.formLoanAmount, '4500.00');
        expect(manager.formEquipmentType, 'AI Vision Inspector');
        expect(manager.formInterestRate, 6);
        expect(manager.formRepaymentYears, 7);
        expect(
          find.text('Minimum loan amount is RM 5,000.00.'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Update Application'),
              )
              .onPressed,
          isNull,
        );
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      manager.dispose();
    },
  );

  testWidgets('update and delete confirmations cancel safely and commit once', (
    tester,
  ) async {
    final manager = LoanManager();
    await manager.addLoanRequest(loan('p'));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: manager,
        child: const MaterialApp(
          home: Scaffold(body: LoanScreen(isBanker: false)),
        ),
      ),
    );
    await tester.ensureVisible(find.byKey(const ValueKey('edit-p')));
    await tester.tap(find.byKey(const ValueKey('edit-p')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Updated company');
    await tester.ensureVisible(find.text('Update Application'));
    await tester.tap(find.text('Update Application'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm Update'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();
    expect(manager.allRequests.single.companyName, 'OptiMach');
    expect(manager.formCompanyName, 'Updated company');
    await tester.tap(find.text('Update Application'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Update'));
    await tester.pumpAndSettle();
    expect(manager.allRequests.single.companyName, 'Updated company');
    expect(manager.isEditing, isFalse);
    await tester.ensureVisible(find.byKey(const ValueKey('delete-p')));
    await tester.tap(find.byKey(const ValueKey('delete-p')));
    await tester.pumpAndSettle();
    expect(find.text('Delete Application?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(manager.allRequests.length, 1);
    await tester.tap(find.byKey(const ValueKey('delete-p')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(manager.allRequests, isEmpty);
    expect(find.text('Application deleted successfully.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    manager.dispose();
  });
}

class _CloudRepository extends LoanRepository {
  _CloudRepository(super.service);
  final deletion = Completer<void>();
  int fetches = 0;
  final rows = <Map<String, dynamic>>[
    {
      'id': 'p',
      'user_id': 'owner',
      'company_name': 'OptiMach',
      'equipment_name': 'Robotic Arm',
      'amount': 10000.50,
      'interest_rate': 4.5,
      'repayment_years': 5,
      'status': 'pending',
      'created_at': '2026-09-04T00:00:00Z',
      'submitted_at': '2026-09-04T00:00:00Z',
    },
  ];
  @override
  String? get currentUserId => 'owner';
  @override
  Future<List<Map<String, dynamic>>> findVisibleApplications() async => rows;
  @override
  Future<Map<String, dynamic>> findById(String id) async {
    fetches++;
    return rows.single;
  }

  @override
  Future<void> deletePending(String id) => deletion.future;
}

class _DelayedDeleteRepository implements LoanRepository {
  final deletion = Completer<void>();
  @override
  String? get currentUserId => 'owner';
  @override
  Future<List<Map<String, dynamic>>> findVisibleApplications() async => [
    {
      'id': 'p',
      'user_id': 'owner',
      'company_name': 'OptiMach',
      'equipment_name': 'Robotic Arm',
      'amount': 10000.50,
      'interest_rate': 4.5,
      'repayment_years': 5,
      'status': 'pending',
      'created_at': '2026-09-04T00:00:00Z',
    },
  ];
  @override
  Future<void> deletePending(String id) => deletion.future;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
