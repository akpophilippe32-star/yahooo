import 'package:flutter/foundation.dart';
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

  // ============================================================
  // CONNEXION GOOGLE
  // ============================================================

  /// Lance le flux de connexion Google. Sur le web, redirige la
  /// page elle-même ; sur mobile, ouvre le navigateur système puis
  /// revient dans l'app via le lien profond `io.supabase.mealora://`
  /// (le même que pour la récupération de mot de passe).
  ///
  /// Ne renvoie rien directement : le résultat (connecté ou non)
  /// arrive ensuite via `onAuthStateChange`, à écouter côté appelant.
  Future<void> signInWithGoogle() async {
    await _supabase.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: kIsWeb ? null : 'io.supabase.mealora://login-callback',
      // Sans ça, Google reconnecte automatiquement avec le dernier
      // compte utilisé dans ce navigateur, sans jamais proposer de
      // choisir — gênant si on a plusieurs comptes Google.
      queryParams: const {'prompt': 'select_account'},
    );
  }

  /// Un compte créé via Google n'est jamais passé par l'écran
  /// d'inscription classique — il n'a donc pas de `username` choisi
  /// (le trigger de création automatique du profil ne peut pas en
  /// inventer un). On s'en sert comme signal fiable pour savoir
  /// s'il faut afficher l'écran de complément de profil.
  Future<bool> needsProfileCompletion() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    final profile = await _supabase
        .from('profiles')
        .select('username')
        .eq('id', user.id)
        .maybeSingle();

    final username = profile?['username'] as String?;
    return username == null || username.trim().isEmpty;
  }

  /// Définit le nom d'utilisateur pour un compte qui n'en a pas
  /// encore (typiquement après une première connexion Google).
  Future<void> completeUsername(String username) async {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('Utilisateur non connecté.');

    await _supabase
        .from('profiles')
        .update({'username': username})
        .eq('id', user.id);
  }

  // ============================================================
  // MOT DE PASSE OUBLIÉ
  // ============================================================

  /// Envoie un email de réinitialisation contenant un lien qui
  /// rouvre l'application (deep link sur mobile, même page sur le
  /// web) avec une session de récupération active.
  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(
      email,
      redirectTo:
          kIsWeb ? Uri.base.origin : 'io.supabase.mealora://login-callback',
    );
  }

  /// Définit un nouveau mot de passe — à appeler uniquement une
  /// fois qu'une session de récupération est active (après avoir
  /// cliqué sur le lien reçu par email).
  Future<void> updatePassword(String newPassword) async {
    await _supabase.auth.updateUser(
      UserAttributes(password: newPassword),
    );
  }
}