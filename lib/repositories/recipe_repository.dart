import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/recipe_model.dart';

class RecipeRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // CACHE DES URLS SIGNÉES (image/vidéo)
  // ============================================================
  //
  // `static` : partagé par TOUTES les instances de RecipeRepository
  // (on en crée une nouvelle à chaque écran), pour que le cache
  // survive à la navigation. Sans ça, chaque fois qu'une miniature
  // redevient visible après un défilement (le widget qui l'affiche
  // est reconstruit), on refaisait un aller-retour réseau complet
  // avant de pouvoir l'afficher — d'où le temps d'attente et le
  // "clignotement" observés. Les URLs signées restent valables 1h
  // côté Supabase ; on les garde 50 minutes ici par sécurité, pour
  // ne jamais servir une URL qui vient d'expirer.
  static final Map<String, _CachedUrl> _imageUrlCache = {};
  static final Map<String, _CachedUrl> _videoUrlCache = {};
  static const Duration _cacheValidity = Duration(minutes: 50);

  // ============================================================
  // RECETTES PUBLIÉES
  // ============================================================

  /// Récupère toutes les recettes publiées.
  Future<List<RecipeModel>> getPublishedRecipes() async {
    final response = await _supabase
        .from('recipes')
        .select('''
          id,
          title,
          author_id,
          description,
          image_url,
          video_url,
          source_type,
          prep_time,
          cook_time,
          servings,
          difficulty,
          diet_type,
          instructions,
          calories_kcal,
          carbs_g,
          fat_g,
          protein_g,
          category_id,
          status,
          created_at,
          updated_at,
          published_at,
          categories (
            name
          )
        ''')
        .eq('status', 'published')
        .order('created_at', ascending: false);

    return (response as List).map((recipe) {
      final data = Map<String, dynamic>.from(recipe);

      final category = data['categories'];

      if (category is Map<String, dynamic>) {
        data['category_name'] = category['name'];
      } else {
        data['category_name'] = null;
      }

      data.remove('categories');

      return RecipeModel.fromMap(data);
    }).toList();
  }

  // ============================================================
  // MES RECETTES
  // ============================================================

  /// Récupère toutes les recettes créées par l'utilisateur connecté.
  Future<List<RecipeModel>> getMyRecipes() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    final response = await _supabase
        .from('recipes')
        .select('''
          id,
          title,
          author_id,
          description,
          image_url,
          video_url,
          source_type,
          prep_time,
          cook_time,
          servings,
          difficulty,
          diet_type,
          instructions,
          calories_kcal,
          carbs_g,
          fat_g,
          protein_g,
          category_id,
          status,
          created_at,
          updated_at,
          published_at,
          categories (
            name
          )
        ''')
        .eq('author_id', user.id)
        .order('created_at', ascending: false);

    return (response as List).map((recipe) {
      final data = Map<String, dynamic>.from(recipe);

      final category = data['categories'];

      if (category is Map<String, dynamic>) {
        data['category_name'] = category['name'];
      } else {
        data['category_name'] = null;
      }

      data.remove('categories');

      return RecipeModel.fromMap(data);
    }).toList();
  }

  // ============================================================
  // MES RECETTES PUBLIÉES (pour la vue "Voir mon profil")
  // ============================================================

  /// Récupère uniquement les recettes publiées de l'utilisateur
  /// connecté (contrairement à [getMyRecipes] qui renvoie aussi les
  /// brouillons/archivées, utile pour la gestion Creator).
  Future<List<RecipeModel>> getMyPublishedRecipes() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _supabase
        .from('recipes')
        .select('''
          id,
          title,
          author_id,
          description,
          image_url,
          video_url,
          source_type,
          prep_time,
          cook_time,
          servings,
          difficulty,
          diet_type,
          instructions,
          calories_kcal,
          carbs_g,
          fat_g,
          protein_g,
          category_id,
          status,
          created_at,
          updated_at,
          published_at,
          categories (
            name
          )
        ''')
        .eq('author_id', user.id)
        .eq('status', 'published')
        .order('published_at', ascending: false);

    return (response as List).map((recipe) {
      final data = Map<String, dynamic>.from(recipe);

      final category = data['categories'];

      if (category is Map<String, dynamic>) {
        data['category_name'] = category['name'];
      } else {
        data['category_name'] = null;
      }

      data.remove('categories');

      return RecipeModel.fromMap(data);
    }).toList();
  }

  /// Recettes publiées d'un créateur quelconque (pas forcément
  /// l'utilisateur connecté) — utilisé pour la page de profil
  /// public d'un créateur, consultée par n'importe quel visiteur.
  Future<List<RecipeModel>> getPublishedRecipesByAuthor(
    String authorId,
  ) async {
    final response = await _supabase
        .from('recipes')
        .select('''
          id,
          title,
          author_id,
          description,
          image_url,
          video_url,
          source_type,
          prep_time,
          cook_time,
          servings,
          difficulty,
          diet_type,
          instructions,
          calories_kcal,
          carbs_g,
          fat_g,
          protein_g,
          category_id,
          status,
          created_at,
          updated_at,
          published_at,
          categories (
            name
          )
        ''')
        .eq('author_id', authorId)
        .eq('status', 'published')
        .order('published_at', ascending: false);

    return (response as List).map((recipe) {
      final data = Map<String, dynamic>.from(recipe);

      final category = data['categories'];

      if (category is Map<String, dynamic>) {
        data['category_name'] = category['name'];
      } else {
        data['category_name'] = null;
      }

      data.remove('categories');

      return RecipeModel.fromMap(data);
    }).toList();
  }

  // ============================================================
  // RECHERCHE (§17 du cahier des charges)
  // ============================================================

  /// Recherche parmi les recettes publiées : titre, description,
  /// **et nom du créateur** (username/nom complet). Tolère les
  /// fautes de frappe et les accents (ex. "Ignzme" trouve "Igname"),
  /// grâce à la RPC `search_recipe_ids` (similarité de trigrammes).
  Future<List<RecipeModel>> searchRecipes({
    String? query,
    int? categoryId,
  }) async {
    final trimmedQuery = query?.trim();
    final hasQuery = trimmedQuery != null && trimmedQuery.isNotEmpty;

    if (!hasQuery && categoryId == null) {
      return [];
    }

    List<int> orderedIds = [];

    if (hasQuery) {
      final rpcResponse = await _supabase.rpc(
        'search_recipe_ids',
        params: {
          'p_query': trimmedQuery,
          'p_category_id': categoryId,
        },
      );

      orderedIds = (rpcResponse as List)
          .map((row) => row['id'] as int)
          .toList();

      // Aucune recette pertinente : inutile d'interroger plus loin.
      if (orderedIds.isEmpty) {
        return [];
      }
    }

    var builder = _supabase
        .from('recipes')
        .select('''
          id,
          title,
          author_id,
          description,
          image_url,
          video_url,
          source_type,
          prep_time,
          cook_time,
          servings,
          difficulty,
          diet_type,
          instructions,
          calories_kcal,
          carbs_g,
          fat_g,
          protein_g,
          category_id,
          status,
          created_at,
          updated_at,
          published_at,
          categories (
            name
          )
        ''')
        .eq('status', 'published');

    if (hasQuery) {
      builder = builder.inFilter('id', orderedIds);
    } else if (categoryId != null) {
      builder = builder.eq('category_id', categoryId);
    }

    final response = await builder.order('published_at', ascending: false);

    final recipes = (response as List).map((recipe) {
      final data = Map<String, dynamic>.from(recipe);

      final category = data['categories'];

      if (category is Map<String, dynamic>) {
        data['category_name'] = category['name'];
      } else {
        data['category_name'] = null;
      }

      data.remove('categories');

      return RecipeModel.fromMap(data);
    }).toList();

    // .inFilter() ne garantit pas l'ordre : on retrie selon le score
    // de pertinence renvoyé par la RPC (déjà classé par ordre
    // décroissant de similarité).
    if (hasQuery) {
      final rankById = {
        for (var i = 0; i < orderedIds.length; i++) orderedIds[i]: i,
      };

      recipes.sort((a, b) {
        final rankA = rankById[a.id] ?? orderedIds.length;
        final rankB = rankById[b.id] ?? orderedIds.length;
        return rankA.compareTo(rankB);
      });
    }

    return recipes;
  }

  // ============================================================
  // CATÉGORIES
  // ============================================================

  /// Récupère les catégories disponibles pour la modification
  /// d'une recette.
  Future<List<Map<String, dynamic>>> getCategoriesForEdit() async {
    final response = await _supabase
        .from('categories')
        .select('id, name')
        .order('name', ascending: true);

    return (response as List)
        .map(
          (category) => Map<String, dynamic>.from(category),
        )
        .toList();
  }

  // ============================================================
  // MODIFICATION D'UNE RECETTE
  // ============================================================

  /// Modifie les informations principales d'une recette.
  Future<void> updateRecipe({
    required int recipeId,
    required String title,
    String? description,
    int? categoryId,
    int? prepTime,
    int? cookTime,
    int? servings,
    String? difficulty,
    String? dietType,
    String? imageUrl,
    int? caloriesKcal,
    double? carbsG,
    double? fatG,
    double? proteinG,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    await _supabase
        .from('recipes')
        .update({
          'title': title,
          'description': description,
          'image_url': imageUrl,
          'category_id': categoryId,
          'prep_time': prepTime,
          'cook_time': cookTime,
          'servings': servings,
          'difficulty': difficulty,
          'diet_type': dietType,
          'calories_kcal': caloriesKcal,
          'carbs_g': carbsG,
          'fat_g': fatG,
          'protein_g': proteinG,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', recipeId)
        .eq('author_id', user.id);
  }

  // ============================================================
  // DÉTAIL D'UNE RECETTE
  // ============================================================

  /// Récupère une recette avec ses informations principales,
  /// ses ingrédients et ses étapes.
  Future<Map<String, dynamic>> getRecipeDetails(
    int recipeId,
  ) async {
    final recipeResponse = await _supabase
        .from('recipes')
        .select('''
          id,
          title,
          author_id,
          description,
          image_url,
          video_url,
          source_type,
          prep_time,
          cook_time,
          servings,
          difficulty,
          diet_type,
          instructions,
          calories_kcal,
          carbs_g,
          fat_g,
          protein_g,
          category_id,
          status,
          created_at,
          updated_at,
          published_at,
          categories (
            name
          )
        ''')
        .eq('id', recipeId)
        .single();

    final recipeData =
        Map<String, dynamic>.from(recipeResponse);

    final category = recipeData['categories'];

    if (category is Map<String, dynamic>) {
      recipeData['category_name'] = category['name'];
    } else {
      recipeData['category_name'] = null;
    }

    recipeData.remove('categories');

    final recipe = RecipeModel.fromMap(recipeData);

    final ingredientsResponse = await _supabase
        .from('recipe_ingredients')
        .select('''
          id,
          recipe_id,
          ingredient_id,
          quantity,
          unit,
          optional,
          created_at,
          ingredients (
            id,
            name,
            description,
            image_url
          )
        ''')
        .eq('recipe_id', recipeId)
        .order('id', ascending: true);

    final ingredients =
        (ingredientsResponse as List).map((ingredient) {
      return Map<String, dynamic>.from(ingredient);
    }).toList();

    final stepsResponse = await _supabase
        .from('recipe_steps')
        .select('''
          id,
          recipe_id,
          step_number,
          instruction,
          image_url,
          created_at
        ''')
        .eq('recipe_id', recipeId)
        .order('step_number', ascending: true);

    final steps =
        (stepsResponse as List).map((step) {
      return Map<String, dynamic>.from(step);
    }).toList();

    return {
      'recipe': recipe,
      'ingredients': ingredients,
      'steps': steps,
    };
  }

  // ============================================================
  // CRÉATION D'UNE RECETTE
  // ============================================================

  /// Crée une nouvelle recette en brouillon.
  ///
  /// La recette, les ingrédients et les étapes sont créés
  /// par la fonction PostgreSQL `create_recipe_draft`.
  Future<Map<String, dynamic>> createDraft({
    required String title,
    String? description,
    int? categoryId,
    String? imageUrl,
    int? prepTime,
    int? cookTime,
    int? servings,
    String? difficulty,
    String? dietType,
    List<Map<String, dynamic>> ingredients = const [],
    List<Map<String, dynamic>> steps = const [],
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté. Impossible de créer la recette.',
      );
    }

    final response = await _supabase.rpc(
      'create_recipe_draft',
      params: {
        'p_title': title,
        'p_description': description,
        'p_category_id': categoryId,
        'p_image_url': imageUrl,
        'p_prep_time': prepTime,
        'p_cook_time': cookTime,
        'p_servings': servings,
        'p_difficulty': difficulty,
        'p_diet_type': dietType,
        'p_ingredients': ingredients,
        'p_steps': steps,
      },
    );

    if (response == null) {
      throw Exception(
        'La création de la recette n’a retourné aucun résultat.',
      );
    }

    if (response is Map<String, dynamic>) {
      return response;
    }

    return Map<String, dynamic>.from(response as Map);
  }

  // ============================================================
  // INGRÉDIENTS D'UNE RECETTE
  // ============================================================

  /// Récupère les ingrédients associés à une recette.
  Future<List<Map<String, dynamic>>> getRecipeIngredients(
    int recipeId,
  ) async {
    final response = await _supabase
        .from('recipe_ingredients')
        .select('''
          id,
          recipe_id,
          ingredient_id,
          quantity,
          unit,
          optional,
          created_at,
          ingredients (
            id,
            name,
            description,
            image_url
          )
        ''')
        .eq('recipe_id', recipeId)
        .order('id', ascending: true);

    return (response as List)
        .map(
          (ingredient) => Map<String, dynamic>.from(ingredient),
        )
        .toList();
  }

  // ============================================================
  // TOUS LES INGRÉDIENTS DU CATALOGUE
  // ============================================================

  /// Récupère la liste de tous les ingrédients disponibles.
  Future<List<Map<String, dynamic>>> getIngredients() async {
    final response = await _supabase
        .from('ingredients')
        .select('''
          id,
          name,
          description,
          image_url
        ''')
        .order('name', ascending: true);

    return (response as List)
        .map(
          (ingredient) => Map<String, dynamic>.from(ingredient),
        )
        .toList();
  }

  // ============================================================
  // ÉTAPES DE LA RECETTE
  // ============================================================

  /// Récupère les étapes d'une recette.
  Future<List<Map<String, dynamic>>> getRecipeSteps(
    int recipeId,
  ) async {
    final response = await _supabase
        .from('recipe_steps')
        .select('''
          id,
          recipe_id,
          step_number,
          instruction,
          image_url,
          created_at
        ''')
        .eq('recipe_id', recipeId)
        .order('step_number', ascending: true);

    return (response as List)
        .map(
          (step) => Map<String, dynamic>.from(step),
        )
        .toList();
  }

  // ============================================================
  // AJOUTER UNE ÉTAPE
  // ============================================================

  Future<Map<String, dynamic>> addRecipeStep({
    required int recipeId,
    required String instruction,
    String? imageUrl,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final recipe = await _supabase
        .from('recipes')
        .select('id')
        .eq('id', recipeId)
        .eq('author_id', user.id)
        .maybeSingle();

    if (recipe == null) {
      throw Exception(
        'Tu n’as pas les droits pour modifier cette recette.',
      );
    }

    final lastStepResponse = await _supabase
        .from('recipe_steps')
        .select('step_number')
        .eq('recipe_id', recipeId)
        .order('step_number', ascending: false)
        .limit(1)
        .maybeSingle();

    final int nextStepNumber =
        ((lastStepResponse?['step_number'] as int?) ?? 0) + 1;

    final response = await _supabase
        .from('recipe_steps')
        .insert({
          'recipe_id': recipeId,
          'step_number': nextStepNumber,
          'instruction': instruction,
          'image_url': imageUrl,
        })
        .select('''
          id,
          recipe_id,
          step_number,
          instruction,
          image_url,
          created_at
        ''')
        .single();

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // RÉORGANISER LES ÉTAPES
  // ============================================================

  Future<void> reorderRecipeSteps({
    required int recipeId,
    required List<int> orderedStepIds,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final recipe = await _supabase
        .from('recipes')
        .select('id')
        .eq('id', recipeId)
        .eq('author_id', user.id)
        .maybeSingle();

    if (recipe == null) {
      throw Exception(
        'Tu n’as pas les droits pour réorganiser cette recette.',
      );
    }

    final existingResponse = await _supabase
        .from('recipe_steps')
        .select('id')
        .eq('recipe_id', recipeId);

    final existingIds = (existingResponse as List)
        .map((row) => row['id'])
        .whereType<int>()
        .toSet();

    final requestedIds = orderedStepIds.toSet();

    if (existingIds.length != orderedStepIds.length ||
        requestedIds.length != orderedStepIds.length ||
        !existingIds.containsAll(requestedIds)) {
      throw Exception(
        'La liste des étapes à réorganiser est invalide.',
      );
    }

    for (var index = 0; index < orderedStepIds.length; index++) {
      await _supabase
          .from('recipe_steps')
          .update({
            'step_number': 1000000 + index,
          })
          .eq('id', orderedStepIds[index])
          .eq('recipe_id', recipeId);
    }

    for (var index = 0; index < orderedStepIds.length; index++) {
      await _supabase
          .from('recipe_steps')
          .update({
            'step_number': index + 1,
          })
          .eq('id', orderedStepIds[index])
          .eq('recipe_id', recipeId);
    }
  }

  // ============================================================
  // AJOUTER UN INGRÉDIENT À UNE RECETTE
  // ============================================================

  /// Ajoute un ingrédient existant du catalogue à une recette.
  Future<Map<String, dynamic>> addRecipeIngredient({
    required int recipeId,
    required int ingredientId,
    num? quantity,
    String? unit,
    bool optional = false,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    final recipe = await _supabase
        .from('recipes')
        .select('id')
        .eq('id', recipeId)
        .eq('author_id', user.id)
        .maybeSingle();

    if (recipe == null) {
      throw Exception(
        'Tu n’as pas les droits pour modifier cette recette.',
      );
    }

    final response = await _supabase
        .from('recipe_ingredients')
        .insert({
          'recipe_id': recipeId,
          'ingredient_id': ingredientId,
          'quantity': quantity,
          'unit': unit,
          'optional': optional,
        })
        .select('''
          id,
          recipe_id,
          ingredient_id,
          quantity,
          unit,
          optional,
          created_at,
          ingredients (
            id,
            name,
            description,
            image_url
          )
        ''')
        .single();

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // MODIFIER UN INGRÉDIENT
  // ============================================================

  /// Modifie la quantité, l'unité ou le caractère facultatif
  /// d'un ingrédient déjà associé à une recette.
  Future<Map<String, dynamic>> updateRecipeIngredient({
    required int recipeIngredientId,
    num? quantity,
    String? unit,
    bool? optional,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    final existing = await _supabase
        .from('recipe_ingredients')
        .select('''
          id,
          recipe_id
        ''')
        .eq('id', recipeIngredientId)
        .maybeSingle();

    if (existing == null) {
      throw Exception(
        'Ingrédient de recette introuvable.',
      );
    }

    final recipeId = existing['recipe_id'];

    final recipe = await _supabase
        .from('recipes')
        .select('id')
        .eq('id', recipeId)
        .eq('author_id', user.id)
        .maybeSingle();

    if (recipe == null) {
      throw Exception(
        'Tu n’as pas les droits pour modifier cet ingrédient.',
      );
    }

    final updateData = <String, dynamic>{};

    if (quantity != null) {
      updateData['quantity'] = quantity;
    }

    if (unit != null) {
      updateData['unit'] = unit;
    }

    if (optional != null) {
      updateData['optional'] = optional;
    }

    if (updateData.isEmpty) {
      throw Exception(
        'Aucune modification à enregistrer.',
      );
    }

    final response = await _supabase
        .from('recipe_ingredients')
        .update(updateData)
        .eq('id', recipeIngredientId)
        .select('''
          id,
          recipe_id,
          ingredient_id,
          quantity,
          unit,
          optional,
          created_at,
          ingredients (
            id,
            name,
            description,
            image_url
          )
        ''')
        .single();

    return Map<String, dynamic>.from(response);
  }

  // ============================================================
  // SUPPRIMER UN INGRÉDIENT
  // ============================================================

  /// Supprime un ingrédient d'une recette.
  Future<void> deleteRecipeIngredient(
    int recipeIngredientId,
  ) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    final existing = await _supabase
        .from('recipe_ingredients')
        .select('recipe_id')
        .eq('id', recipeIngredientId)
        .maybeSingle();

    if (existing == null) {
      throw Exception(
        'Ingrédient de recette introuvable.',
      );
    }

    final recipeId = existing['recipe_id'];

    final recipe = await _supabase
        .from('recipes')
        .select('id')
        .eq('id', recipeId)
        .eq('author_id', user.id)
        .maybeSingle();

    if (recipe == null) {
      throw Exception(
        'Tu n’as pas les droits pour supprimer cet ingrédient.',
      );
    }

    await _supabase
        .from('recipe_ingredients')
        .delete()
        .eq('id', recipeIngredientId);
  }

  // ============================================================
  // IMAGE D'UNE RECETTE
  // ============================================================

  /// Envoie une image dans le bucket privé `recipe-images` et
  /// retourne le CHEMIN de stockage (comme pour la vidéo, il faudra
  /// passer par [getRecipeImageUrl] pour l'afficher).
  Future<String> uploadRecipeImage({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final imagePath =
        '${user.id}/recipe_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _supabase.storage.from('recipe-images').uploadBinary(
          imagePath,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return imagePath;
  }

  /// Génère une URL temporaire pour une image stockée
  /// dans le bucket privé `recipe-images`. Mise en cache en
  /// mémoire (voir [_imageUrlCache]) pour éviter de refaire
  /// l'aller-retour réseau à chaque fois qu'une miniature redevient
  /// visible après un défilement.
  Future<String?> getRecipeImageUrl(
    String? imagePath,
  ) async {
    if (imagePath == null ||
        imagePath.trim().isEmpty) {
      return null;
    }

    final path = imagePath.trim();

    final cached = _imageUrlCache[path];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    try {
      final signedUrl = await _supabase.storage
          .from('recipe-images')
          .createSignedUrl(
            path,
            60 * 60,
          );

      _imageUrlCache[path] = _CachedUrl(signedUrl);

      return signedUrl;
    } catch (error) {
      debugPrint(
        'Erreur image [$imagePath] : $error',
      );

      return null;
    }
  }

  // ============================================================
  // ÉTAPES DE PRÉPARATION
  // ============================================================

  /// Modifie une étape de préparation.
  Future<void> updateRecipeStep({
    required int stepId,
    required String instruction,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    final existing = await _supabase
        .from('recipe_steps')
        .select('recipe_id')
        .eq('id', stepId)
        .maybeSingle();

    if (existing == null) {
      throw Exception(
        'Étape introuvable.',
      );
    }

    final recipeId = existing['recipe_id'];

    final recipe = await _supabase
        .from('recipes')
        .select('id')
        .eq('id', recipeId)
        .eq('author_id', user.id)
        .maybeSingle();

    if (recipe == null) {
      throw Exception(
        'Tu n’as pas les droits pour modifier cette étape.',
      );
    }

    await _supabase
        .from('recipe_steps')
        .update({
          'instruction': instruction,
        })
        .eq('id', stepId);
  }

  /// Supprime une étape de préparation.
  Future<void> deleteRecipeStep(
    int stepId,
  ) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    final existing = await _supabase
        .from('recipe_steps')
        .select('recipe_id')
        .eq('id', stepId)
        .maybeSingle();

    if (existing == null) {
      throw Exception(
        'Étape introuvable.',
      );
    }

    final recipeId = existing['recipe_id'];

    final recipe = await _supabase
        .from('recipes')
        .select('id')
        .eq('id', recipeId)
        .eq('author_id', user.id)
        .maybeSingle();

    if (recipe == null) {
      throw Exception(
        'Tu n’as pas les droits pour supprimer cette étape.',
      );
    }

    await _supabase
        .from('recipe_steps')
        .delete()
        .eq('id', stepId);

    final remainingResponse = await _supabase
        .from('recipe_steps')
        .select('id')
        .eq('recipe_id', recipeId)
        .order('step_number', ascending: true);

    final remainingIds = (remainingResponse as List)
        .map((row) => row['id'])
        .whereType<int>()
        .toList();

    if (remainingIds.isNotEmpty) {
      await reorderRecipeSteps(
        recipeId: recipeId,
        orderedStepIds: remainingIds,
      );
    }
  }

  // ============================================================
  // CHAMPS OBLIGATOIRES AVANT PUBLICATION
  // ============================================================

  /// Vérifie que les informations obligatoires d'une recette sont
  /// bien renseignées.
  Future<List<String>> getMissingFieldsForPublish(
    int recipeId,
  ) async {
    final missing = <String>[];

    final recipeResponse = await _supabase
        .from('recipes')
        .select('title, category_id, difficulty, source_type')
        .eq('id', recipeId)
        .single();

    final recipe = Map<String, dynamic>.from(recipeResponse);

    final title = recipe['title'] as String?;

    if (title == null || title.trim().isEmpty) {
      missing.add('Titre');
    }

    if (recipe['category_id'] == null) {
      missing.add('Catégorie');
    }

    if (recipe['difficulty'] == null) {
      missing.add('Difficulté');
    }

    final sourceType = recipe['source_type'] as String? ?? 'manual';

    if (sourceType != 'video') {
      final ingredientsResponse = await _supabase
          .from('recipe_ingredients')
          .select('id')
          .eq('recipe_id', recipeId);

      if ((ingredientsResponse as List).isEmpty) {
        missing.add('Au moins un ingrédient');
      }

      final stepsResponse = await _supabase
          .from('recipe_steps')
          .select('id')
          .eq('recipe_id', recipeId);

      if ((stepsResponse as List).isEmpty) {
        missing.add('Au moins une étape de préparation');
      }
    }

    return missing;
  }

  // ============================================================
  // PUBLICATION D'UNE RECETTE
  // ============================================================

  /// Fait passer une recette du statut `draft` à `published`.
  Future<void> publishRecipe(int recipeId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté.',
      );
    }

    final recipe = await _supabase
        .from('recipes')
        .select('id, status')
        .eq('id', recipeId)
        .eq('author_id', user.id)
        .maybeSingle();

    if (recipe == null) {
      throw Exception(
        'Tu n’as pas les droits pour publier cette recette.',
      );
    }

    if (recipe['status'] == 'published') {
      return;
    }

    final missingFields = await getMissingFieldsForPublish(
      recipeId,
    );

    if (missingFields.isNotEmpty) {
      throw Exception(
        'Informations manquantes avant publication : '
        '${missingFields.join(', ')}.',
      );
    }

    final updateResponse = await _supabase
        .from('recipes')
        .update({
          'status': 'published',
          'published_at': DateTime.now().toUtc().toIso8601String(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', recipeId)
        .eq('author_id', user.id)
        .select('id, status');

    if ((updateResponse as List).isEmpty) {
      throw Exception(
        'La publication a été refusée par le serveur '
        '(vérifie que ton rôle est bien "creator" ou "admin").',
      );
    }
  }

  // ============================================================
  // SUPPRESSION D'UNE RECETTE
  // ============================================================

  /// Supprime définitivement une recette.
  Future<void> deleteRecipe(int recipeId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _supabase
        .from('recipes')
        .delete()
        .eq('id', recipeId)
        .eq('author_id', user.id)
        .select('id');

    if ((response as List).isEmpty) {
      throw Exception(
        'Suppression refusée (recette introuvable ou droits '
        'insuffisants).',
      );
    }
  }

  // ============================================================
  // VIDÉO — IMPORT ET CRÉATION DE RECETTE VIDÉO
  // ============================================================

  String _videoMimeType(String fileExtension) {
    switch (fileExtension.toLowerCase()) {
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'm4v':
        return 'video/x-m4v';
      case 'webm':
        return 'video/webm';
      case 'avi':
        return 'video/x-msvideo';
      case '3gp':
        return 'video/3gpp';
      default:
        return 'video/mp4';
    }
  }

  Future<String> uploadRecipeVideo({
    required Uint8List bytes,
    required String fileExtension,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final videoPath =
        '${user.id}/recipe_video_${DateTime.now().millisecondsSinceEpoch}.$fileExtension';

    await _supabase.storage.from('recipe-videos').uploadBinary(
          videoPath,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: _videoMimeType(fileExtension),
          ),
        );

    return videoPath;
  }

  /// Génère une URL signée temporaire pour lire une vidéo stockée
  /// dans le bucket privé `recipe-videos`. Retourne `null` si aucun
  /// chemin n'est fourni. Mise en cache en mémoire (voir
  /// [_videoUrlCache]) — sans ça, chaque miniature vidéo qui
  /// redevient visible après un défilement refaisait tout le
  /// travail (aller-retour réseau + réinitialisation du lecteur)
  /// depuis zéro.
  Future<String?> getRecipeVideoUrl(String? videoPath) async {
    if (videoPath == null || videoPath.isEmpty) {
      return null;
    }

    final cached = _videoUrlCache[videoPath];
    if (cached != null && !cached.isExpired) {
      return cached.url;
    }

    final signedUrl = await _supabase.storage
        .from('recipe-videos')
        .createSignedUrl(videoPath, 3600);

    _videoUrlCache[videoPath] = _CachedUrl(signedUrl);

    return signedUrl;
  }

  /// Crée une recette en brouillon à partir d'une vidéo importée.
  Future<Map<String, dynamic>> createVideoDraft({
    required String title,
    required String videoPath,
    String? description,
    int? categoryId,
  }) async {
    final recipe = await createDraft(
      title: title,
      description: description,
      categoryId: categoryId,
    );

    final recipeId = recipe['id'] ?? recipe['recipe_id'];

    if (recipeId is! int) {
      throw Exception(
        'Impossible de récupérer l’identifiant de la recette créée.',
      );
    }

    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final updateResponse = await _supabase
        .from('recipes')
        .update({
          'source_type': 'video',
          'video_url': videoPath,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', recipeId)
        .eq('author_id', user.id)
        .select('id, source_type, video_url');

    if ((updateResponse as List).isEmpty) {
      throw Exception(
        'Impossible d’associer la vidéo à la recette créée.',
      );
    }

    recipe['source_type'] = 'video';
    recipe['video_url'] = videoPath;

    return recipe;
  }

  // ============================================================
  // VIDÉO — ANALYSE IA (optionnelle)
  // ============================================================

  Future<int> requestVideoAnalysis(int recipeId) async {
    final response = await _supabase
        .from('recipe_video_analyses')
        .insert({
          'recipe_id': recipeId,
          'status': 'pending',
        })
        .select('id')
        .single();

    return response['id'] as int;
  }

  Future<void> skipVideoAnalysis(int recipeId) async {
    await _supabase.from('recipe_video_analyses').insert({
      'recipe_id': recipeId,
      'status': 'skipped',
    });
  }

  Future<Map<String, dynamic>?> getLatestVideoAnalysis(
    int recipeId,
  ) async {
    final response = await _supabase
        .from('recipe_video_analyses')
        .select()
        .eq('recipe_id', recipeId)
        .order('requested_at', ascending: false)
        .limit(1)
        .maybeSingle();

    return response == null
        ? null
        : Map<String, dynamic>.from(response);
  }

  Future<void> markVideoAnalysisApplied(int analysisId) async {
    await _supabase.from('recipe_video_analyses').update({
      'applied': true,
      'completed_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', analysisId);
  }

  // ============================================================
  // LIKES
  // ============================================================

  Future<bool> toggleLike(int recipeId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final existing = await _supabase
        .from('recipe_likes')
        .select('id')
        .eq('recipe_id', recipeId)
        .eq('user_id', user.id)
        .maybeSingle();

    if (existing != null) {
      await _supabase
          .from('recipe_likes')
          .delete()
          .eq('id', existing['id'] as int);

      return false;
    }

    await _supabase.from('recipe_likes').insert({
      'recipe_id': recipeId,
      'user_id': user.id,
    });

    return true;
  }

  Future<int> getLikeCount(int recipeId) async {
    final response = await _supabase
        .from('recipe_likes')
        .select('id')
        .eq('recipe_id', recipeId);

    return (response as List).length;
  }

  Future<bool> hasLiked(int recipeId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return false;
    }

    final existing = await _supabase
        .from('recipe_likes')
        .select('id')
        .eq('recipe_id', recipeId)
        .eq('user_id', user.id)
        .maybeSingle();

    return existing != null;
  }

  /// Récupère une recette publiée par son id.
  Future<RecipeModel?> getRecipeById(int id) async {
    final response = await _supabase
        .from('recipes')
        .select('''
          id,
          title,
          author_id,
          description,
          image_url,
          video_url,
          source_type,
          prep_time,
          cook_time,
          servings,
          difficulty,
          diet_type,
          instructions,
          calories_kcal,
          carbs_g,
          fat_g,
          protein_g,
          category_id,
          status,
          created_at,
          updated_at,
          published_at,
          categories (
            name
          )
        ''')
        .eq('id', id)
        .eq('status', 'published')
        .maybeSingle();

    if (response == null) return null;

    final data = Map<String, dynamic>.from(response);
    final category = data['categories'];

    data['category_name'] =
        category is Map<String, dynamic> ? category['name'] : null;
    data.remove('categories');

    return RecipeModel.fromMap(data);
  }

  Future<List<RecipeModel>> getMyLikedRecipes() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _supabase
        .from('recipe_likes')
        .select('''
          created_at,
          recipes (
            id,
            title,
            author_id,
            description,
            image_url,
            video_url,
            source_type,
            prep_time,
            cook_time,
            servings,
            difficulty,
            diet_type,
            instructions,
            category_id,
            status,
            created_at,
            updated_at,
            published_at,
            calories_kcal,
            carbs_g,
            fat_g,
            protein_g,
            categories (
              name
            )
          )
        ''')
        .eq('user_id', user.id)
        .order('created_at', ascending: false);

    final recipes = <RecipeModel>[];

    for (final row in response as List) {
      final recipeData = row['recipes'];

      if (recipeData is! Map<String, dynamic>) continue;
      if (recipeData['status'] != 'published') continue;

      final data = Map<String, dynamic>.from(recipeData);
      final category = data['categories'];

      data['category_name'] =
          category is Map<String, dynamic> ? category['name'] : null;
      data.remove('categories');

      recipes.add(RecipeModel.fromMap(data));
    }

    return recipes;
  }

  // ============================================================
  // NOTATION EN ÉTOILES
  // ============================================================

  Future<void> rateRecipe(int recipeId, int rating) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    if (rating < 1 || rating > 5) {
      throw Exception('La note doit être comprise entre 1 et 5.');
    }

    await _supabase.from('recipe_ratings').upsert(
      {
        'recipe_id': recipeId,
        'user_id': user.id,
        'rating': rating,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      },
      onConflict: 'recipe_id,user_id',
    );
  }

  Future<int?> getMyRating(int recipeId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      return null;
    }

    final response = await _supabase
        .from('recipe_ratings')
        .select('rating')
        .eq('recipe_id', recipeId)
        .eq('user_id', user.id)
        .maybeSingle();

    return response?['rating'] as int?;
  }

  Future<({double average, int count})> getRatingSummary(
    int recipeId,
  ) async {
    final response = await _supabase
        .from('recipe_ratings')
        .select('rating')
        .eq('recipe_id', recipeId);

    final ratings = (response as List)
        .map((row) => row['rating'] as int)
        .toList();

    if (ratings.isEmpty) {
      return (average: 0.0, count: 0);
    }

    final average = ratings.reduce((a, b) => a + b) / ratings.length;

    return (average: average, count: ratings.length);
  }

  // ============================================================
  // COMMENTAIRES
  // ============================================================

  Future<List<Map<String, dynamic>>> getComments(
    int recipeId,
  ) async {
    final response = await _supabase
        .from('recipe_comments')
        .select('''
          id,
          content,
          created_at,
          updated_at,
          parent_comment_id,
          is_hidden,
          user_id,
          profiles (
            username,
            full_name,
            avatar_url
          )
        ''')
        .eq('recipe_id', recipeId)
        .order('created_at', ascending: true);

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<void> addComment({
    required int recipeId,
    required String content,
    int? parentCommentId,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    if (content.trim().isEmpty) {
      throw Exception('Le commentaire ne peut pas être vide.');
    }

    await _supabase.from('recipe_comments').insert({
      'recipe_id': recipeId,
      'user_id': user.id,
      'content': content.trim(),
      'parent_comment_id': parentCommentId,
    });
  }

  Future<void> updateComment({
    required int commentId,
    required String content,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _supabase
        .from('recipe_comments')
        .update({
          'content': content.trim(),
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', commentId)
        .eq('user_id', user.id)
        .select('id');

    if ((response as List).isEmpty) {
      throw Exception(
        'Impossible de modifier ce commentaire.',
      );
    }
  }

  Future<void> deleteComment(int commentId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    await _supabase
        .from('recipe_comments')
        .delete()
        .eq('id', commentId)
        .eq('user_id', user.id);
  }

  Future<void> moderateDeleteComment(int commentId) async {
    await _supabase
        .from('recipe_comments')
        .delete()
        .eq('id', commentId);
  }

  Future<void> moderateHideComment(
    int commentId, {
    required bool hide,
  }) async {
    await _supabase
        .from('recipe_comments')
        .update({'is_hidden': hide})
        .eq('id', commentId);
  }
}

/// URL signée mise en cache avec son horodatage, pour savoir quand
/// la considérer comme périmée (voir [RecipeRepository._cacheValidity]).
class _CachedUrl {
  final String url;
  final DateTime cachedAt;

  _CachedUrl(this.url) : cachedAt = DateTime.now();

  bool get isExpired =>
      DateTime.now().difference(cachedAt) > RecipeRepository._cacheValidity;
}