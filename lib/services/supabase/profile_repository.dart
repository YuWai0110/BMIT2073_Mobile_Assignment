import 'supabase_service.dart';

class ProfileRepository {
  final SupabaseService _service;

  const ProfileRepository(this._service);

  Future<Map<String, dynamic>?> findById(String userId) async {
    return _service.withSessionRecovery(() async {
      final result = await _service.profiles
          .select()
          .eq('id', userId)
          .maybeSingle();
      return result;
    });
  }

  Future<Map<String, dynamic>> save({
    required String id,
    required String fullName,
    required String companyName,
    required String phone,
    required String email,
  }) async {
    return _service.withSessionRecovery(() async {
      final result = await _service.profiles
          .upsert({
            'id': id,
            'full_name': fullName,
            'company_name': companyName,
            'phone': phone,
            'email': email,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .select()
          .single();
      return result;
    });
  }

  Future<Map<String, dynamic>> update({
    required String userId,
    required String fullName,
    required String companyName,
    required String phone,
  }) async {
    return _service.withSessionRecovery(() async {
      final result = await _service.profiles
          .update({
            'full_name': fullName,
            'company_name': companyName,
            'phone': phone,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', userId)
          .select()
          .single();
      return result;
    });
  }
}
