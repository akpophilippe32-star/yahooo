import 'package:supabase_flutter/supabase_flutter.dart';

class AdminService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<bool> setUserRole({
    required String userId,
    required String role,
  }) async {
    try {
      final result = await _supabase.rpc(
        'set_user_role',
        params: {
          'target_user_id': userId,
          'new_role': role,
        },
      );

      return result == true;
    } on PostgrestException catch (e) {
      print('Erreur Supabase : ${e.message}');
      rethrow;
    } catch (e) {
      print('Erreur : $e');
      rethrow;
    }
  }
}