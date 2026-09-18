import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Gère la lecture et la mise à jour du profil de l'utilisateur
/// connecté : identité (nom, username, photo), préférences
/// alimentaires (§10 du cahier des charges), thème et couleur.
class ProfileRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // CACHE DES URLS D'AVATAR
  // ============================================================
  //
  // Même principe que pour les images/vidéos de recette : sans
  // cache, chaque fois qu'un avatar redevient visible après un
  // défilement, on refaisait un aller-retour réseau complet avant
  // de pouvoir l'afficher. `static` : partagé par toutes les
  // instances de ProfileRepository, pour survivre à la navigation.
  static final Map<String, _CachedUrl> _avatarUrlCache = {};
  static const Duration _cacheValidity = Duration(minutes: 50);

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

  /// Génère une URL temporaire pour un avatar stocké dans le bucket
  /// privé `avatars`. Mise en cache en mémoire (voir
  /// [_avatarUrlCache]) pour éviter de refaire l'aller-retour
  /// réseau à chaque fois qu'une photo redevient visible après un
  /// défilement (listes d'utilisateurs, commentaires...).
  Future<String?> getAvatarUrl(String? path) async {
    if (path == null || path.trim().isEmpty) {
      return null;
    }

    final trimmedPath = path.trim();

    final cached = _avatarUrlCache[trimmedPath];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    try {
      final signedUrl = await _supabase.storage
          .from('avatars')
          .createSignedUrl(trimmedPath, 60 * 60);

      _avatarUrlCache[trimmedPath] = _CachedUrl(signedUrl);

      return signedUrl;
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

    // La photo vient peut-être de changer : on invalide l'entrée en
    // cache pour ce chemin, pour ne jamais montrer une ancienne
    // photo mise en cache après une mise à jour.
    if (avatarUrl != null) {
      _avatarUrlCache.remove(avatarUrl.trim());
    }
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

  // ============================================================
  // NOTATION DU PROFIL CRÉATEUR
  // ============================================================
  // Réservée aux créateurs ayant complété leur candidature avec un
  // document justificatif (creator_document_path non nul) — voir
  // rate_creator() côté base de données, qui applique cette règle
  // même si le client est contourné.

  /// Note (ou met à jour sa note pour) un créateur, de 1 à 5.
  /// Lève une exception si le créateur n'a pas encore de document
  /// justificatif, ou si on essaie de se noter soi-même.
  Future<void> rateCreator({
    required String creatorId,
    required int rating,
  }) async {
    await _supabase.rpc(
      'rate_creator',
      params: {
        'p_creator_id': creatorId,
        'p_rating': rating,
      },
    );
  }

  /// Moyenne + nombre d'avis pour un créateur donné.
  Future<({double average, int count})> getCreatorRatingSummary(
    String creatorId,
  ) async {
    final response = await _supabase
        .rpc(
          'get_creator_rating_summary',
          params: {'p_creator_id': creatorId},
        )
        .single();

    final row = Map<String, dynamic>.from(response as Map);

    return (
      average: (row['average'] as num?)?.toDouble() ?? 0.0,
      count: (row['rating_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// La note déjà donnée par l'utilisateur connecté à ce créateur,
  /// ou null s'il ne l'a pas encore noté.
  Future<int?> getMyRatingForCreator(String creatorId) async {
    final response = await _supabase.rpc(
      'get_my_rating_for_creator',
      params: {'p_creator_id': creatorId},
    );

    if (response == null) return null;
    return (response as num).toInt();
  }
}

/// URL signée mise en cache avec son horodatage (voir
/// [ProfileRepository._cacheValidity]).
class _CachedUrl {
  final String url;
  final DateTime cachedAt;

  _CachedUrl(this.url) : cachedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > ProfileRepository._cacheValidity;
}