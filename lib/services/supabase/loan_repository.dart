import 'supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LoanOperationException implements Exception {
  const LoanOperationException(this.message);
  final String message;
}

class LoanRepository {
  final SupabaseService _service;

  const LoanRepository(this._service);

  String? get currentUserId => _service.auth.currentUser?.id;

  Future<List<Map<String, dynamic>>> findVisibleApplications() async {
    return _service.withSessionRecovery(() async {
      final result = await _service.loanApplications.select().order(
        'created_at',
      );
      return result.cast<Map<String, dynamic>>();
    });
  }

  Future<Map<String, dynamic>> create(Map<String, dynamic> application) async {
    return _service.withSessionRecovery(() async {
      final result = await _service.loanApplications
          .insert(application)
          .select()
          .single();
      return result;
    });
  }

  Future<Map<String, dynamic>> updateStatus(String id, String status) async {
    final latest = await findById(id);
    if (latest['status'] != 'pending') {
      throw const LoanOperationException(
        'Only pending applications can be changed.',
      );
    }
    return _loanOperation(() async {
      final result = await _service.loanApplications
          .update({'status': status})
          .eq('id', id)
          .eq('status', 'pending')
          .select()
          .single();
      return result;
    });
  }

  Future<void> delete(String id) async {
    await deletePending(id);
  }

  Future<Map<String, dynamic>> findById(String id) async {
    return _service.withSessionRecovery(() async {
      final row = await _service.loanApplications
          .select()
          .eq('id', id)
          .maybeSingle();
      if (row == null) {
        throw const LoanOperationException('Loan application was not found.');
      }
      return row;
    });
  }

  Future<Map<String, dynamic>> updateApplication(
    String id,
    Map<String, dynamic> values,
  ) async {
    final latest = await findById(id);
    if (latest['status'] != 'pending') {
      throw const LoanOperationException(
        'Only pending applications can be edited.',
      );
    }
    return _loanOperation(() async {
      final result = await _service.client.rpc(
        'update_pending_loan',
        params: {...values, 'p_id': id},
      );
      return Map<String, dynamic>.from(result as Map);
    });
  }

  Future<void> deletePending(String id) async {
    await _loanOperation(
      () => _service.client.rpc('delete_pending_loan', params: {'p_id': id}),
    );
  }

  Future<T> _loanOperation<T>(Future<T> Function() action) async {
    try {
      return await _service.withSessionRecovery(action);
    } on PostgrestException catch (error) {
      final message = switch (error.message) {
        'loan_not_pending' => 'Only pending applications can be changed.',
        'loan_not_found' => 'Loan application was not found.',
        'loan_invalid_details' =>
          'Please check the company name and loan amount.',
        'loan_forbidden' =>
          'You do not have permission to change this application.',
        _ =>
          'Unable to update loan applications. Please refresh and try again.',
      };
      throw LoanOperationException(message);
    }
  }
}
