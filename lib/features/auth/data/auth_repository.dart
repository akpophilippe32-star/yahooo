import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
    required String fullName,
  }) async {
    return await _supabase.auth.signUp(
      email: email,
      password: password,
      data: {
        'username': username,
        'full_name': fullName,
      },
    );
  }

  /// Met à jour les préférences du profil (date de naissance,
  /// couleur préférée, thème). Chaque paramètre est optionnel :
  /// seuls ceux fournis sont modifiés côté base de données.
  Future<void> updateProfilePreferences({
    DateTime? birthDate,
    String? accentColor,
    String? themePreference,
  }) async {
    await _supabase.rpc(
      'update_profile_preferences',
      params: {
        'p_birth_date': birthDate != null
            ? '${birthDate.year.toString().padLeft(4, '0')}-'
                '${birthDate.month.toString().padLeft(2, '0')}-'
                '${birthDate.day.toString().padLeft(2, '0')}'
            : null,
        'p_accent_color': accentColor,
        'p_theme_preference': themePreference,
      },
    );
  }

  /// Soumet une demande de statut Creator (cuisine, nutrition ou
  /// autre spécialité). Le compte reste "user" tant qu'un admin n'a
  /// pas validé la demande — voir submit_creator_application côté
  /// base de données.
  Future<void> submitCreatorApplication({
    required String specialty,
    String? applicationNote,
  }) async {
    await _supabase.rpc(
      'submit_creator_application',
      params: {
        'p_specialty': specialty,
        'p_application_note': applicationNote,
      },
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  User? get currentUser => _supabase.auth.currentUser;
}