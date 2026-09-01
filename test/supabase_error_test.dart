import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_assginment/services/supabase/supabase_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('PGRST303 is identified and converted to a friendly message', () {
    const error = PostgrestException(
      message: 'JWT issued at future',
      code: 'PGRST303',
    );

    expect(isJwtSessionError(error), isTrue);
    expect(friendlySupabaseError(error), contains('sign in again'));
    expect(friendlySupabaseError(error), isNot(contains('PGRST303')));
    expect(friendlySupabaseError(error), isNot(contains('JWT')));
  });

  test('other PostgREST errors do not expose backend details', () {
    const error = PostgrestException(
      message: 'relation public.secret_table does not exist',
      code: '42P01',
    );

    expect(
      friendlySupabaseError(error),
      'Unable to load cloud data right now. Please try again.',
    );
  });
}
