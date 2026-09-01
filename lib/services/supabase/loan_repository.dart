import 'supabase_service.dart';

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
    return _service.withSessionRecovery(() async {
      final result = await _service.loanApplications
          .update({'status': status})
          .eq('id', id)
          .select()
          .single();
      return result;
    });
  }

  Future<void> delete(String id) async {
    await _service.withSessionRecovery(
      () => _service.loanApplications.delete().eq('id', id),
    );
  }
}
