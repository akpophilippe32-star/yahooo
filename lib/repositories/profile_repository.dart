import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gère la lecture et la mise à jour du profil de l'utilisateur
/// connecté : identité (nom, username, photo), préférences
/// alimentaires (§10 du cahier des charges), thème et couleur.
class ProfileRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // LECTURE DU PROFIL
  // ============================================================

  Future<Map<String, dynamic>> getMyProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return Map<String, dynamic>.from(response);
  }

  /// Récupère le profil d'un utilisateur quelconque par son id —
  /// utilisé pour afficher le profil du créateur d'une recette (pas
  /// forcément l'utilisateur connecté).
  Future<Map<String, dynamic>> getProfileById(String userId) async {
    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // PHOTO DE PROFIL
  // ============================================================

  Future<String> uploadAvatar({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final path =
        '${user.id}/avatar_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _supabase.storage.from('avatars').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return path;
  }

  Future<String?> getAvatarUrl(String? path) async {
    if (path == null || path.trim().isEmpty) {
      return null;
    }

    try {
      return await _supabase.storage
          .from('avatars')
          .createSignedUrl(path.trim(), 60 * 60);
    } catch (error) {
      debugPrint('Erreur avatar [$path] : $error');
      return null;
    }
  }

  // ============================================================
  // IDENTITÉ (nom, username, avatar)
  // ============================================================

  Future<void> updateIdentity({
    String? fullName,
    String? username,
    String? avatarUrl,
    String? bio,
    String? location,
    String? website,
  }) async {
    await _supabase.rpc(
      'update_profile_identity',
      params: {
        'p_full_name': fullName,
        'p_username': username,
        'p_avatar_url': avatarUrl,
        'p_bio': bio,
        'p_location': location,
        'p_website': website,
      },
    );
  }

  // ============================================================
  // PRÉFÉRENCES ALIMENTAIRES (§10)
  // ============================================================

  Future<void> updateFoodPreferences({
    List<String>? dietaryPreferences,
    List<String>? preferredFoods,
    List<String>? avoidedFoods,
    String? cookingLevel,
    List<String>? cuisinePreferences,
  }) async {
    await _supabase.rpc(
      'update_profile_food_preferences',
      params: {
        'p_dietary_preferences': dietaryPreferences,
        'p_preferred_foods': preferredFoods,
        'p_avoided_foods': avoidedFoods,
        'p_cooking_level': cookingLevel,
        'p_cuisine_preferences': cuisinePreferences,
      },
    );
  }

  // ============================================================
  // PRÉFÉRENCES D'APPARENCE (date de naissance, couleur, thème)
  // ============================================================
  // Déjà géré par AuthRepository.updateProfilePreferences —
  // conservé là-bas pour ne pas dupliquer, réutilisé depuis
  // ProfilePage directement via AuthRepository.

  // ============================================================
  // ABONNEMENT AUX CRÉATEURS (base du futur système de
  // notifications — ex. "X a publié une nouvelle recette")
  // ============================================================

  Future<bool> isFollowing(String creatorId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return false;

    final existing = await _supabase
        .from('creator_follows')
        .select('id')
        .eq('follower_id', user.id)
        .eq('creator_id', creatorId)
        .maybeSingle();

    return existing != null;
  }

  Future<int> getFollowerCount(String creatorId) async {
    final response = await _supabase
        .from('creator_follows')
        .select('id')
        .eq('creator_id', creatorId);

    return (response as List).length;
  }

  /// Bascule l'abonnement (suit si pas encore abonné, se désabonne
  /// sinon). Retourne le nouvel état (true = maintenant abonné).
  Future<bool> toggleFollow(String creatorId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final alreadyFollowing = await isFollowing(creatorId);

    if (alreadyFollowing) {
      await _supabase
          .from('creator_follows')
          .delete()
          .eq('follower_id', user.id)
          .eq('creator_id', creatorId);
      return false;
    } else {
      await _supabase.from('creator_follows').insert({
        'follower_id': user.id,
        'creator_id': creatorId,
      });
      return true;
    }
  }
}