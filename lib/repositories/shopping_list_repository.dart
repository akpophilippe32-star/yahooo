import 'package:supabase_flutter/supabase_flutter.dart';

/// Gère la liste de courses de l'utilisateur connecté (§20 du
/// cahier des charges) : ajout manuel, ou génération automatique à
/// partir des ingrédients des recettes planifiées.
class ShoppingListRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // LECTURE
  // ============================================================

  Future<List<Map<String, dynamic>>> getItems() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _supabase
        .from('shopping_list_items')
        .select()
        .eq('user_id', user.id)
        .order('is_checked', ascending: true)
        .order('created_at', ascending: true);

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  // ============================================================
  // AJOUT MANUEL
  // ============================================================

  Future<void> addItem({
    required String name,
    String? quantity,
    String? unit,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    await _supabase.from('shopping_list_items').insert({
      'user_id': user.id,
      'name': name,
      'quantity': quantity,
      'unit': unit,
      'source': 'manual',
    });
  }

  // ============================================================
  // COCHER / DÉCOCHER
  // ============================================================

  Future<void> setChecked(int itemId, bool isChecked) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    await _supabase
        .from('shopping_list_items')
        .update({'is_checked': isChecked})
        .eq('id', itemId)
        .eq('user_id', user.id);
  }

  // ============================================================
  // SUPPRESSION
  // ============================================================

  Future<void> deleteItem(int itemId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    await _supabase
        .from('shopping_list_items')
        .delete()
        .eq('id', itemId)
        .eq('user_id', user.id);
  }

  /// Retire tous les articles déjà cochés (nettoyage rapide).
  Future<void> clearChecked() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    await _supabase
        .from('shopping_list_items')
        .delete()
        .eq('user_id', user.id)
        .eq('is_checked', true);
  }

  // ============================================================
  // GÉNÉRATION À PARTIR DU PLANNING DES REPAS
  // ============================================================

  /// Récupère les ingrédients de toutes les recettes planifiées
  /// entre `start` et `end` (bornes incluses), les regroupe par nom
  /// + unité (en additionnant les quantités numériques quand c'est
  /// possible), et les ajoute à la liste de courses.
  ///
  /// Retourne le nombre d'articles ajoutés.
  Future<int> generateFromMealPlan({
    required DateTime start,
    required DateTime end,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    String formatDate(DateTime date) {
      return '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';
    }

    // 1. Recettes planifiées sur la période.
    final planResponse = await _supabase
        .from('meal_plan_entries')
        .select('recipe_id')
        .eq('user_id', user.id)
        .gte('plan_date', formatDate(start))
        .lte('plan_date', formatDate(end));

    final recipeIds = (planResponse as List)
        .map((row) => row['recipe_id'] as int)
        .toSet()
        .toList();

    if (recipeIds.isEmpty) {
      return 0;
    }

    // 2. Ingrédients de ces recettes.
    final ingredientsResponse = await _supabase
        .from('recipe_ingredients')
        .select('''
          quantity,
          unit,
          recipe_id,
          ingredients (
            name
          )
        ''')
        .inFilter('recipe_id', recipeIds);

    // 3. Regroupement par nom + unité.
    final Map<String, ({String name, double? total, String? unit})>
        grouped = {};

    for (final row in ingredientsResponse as List) {
      final ingredientData = row['ingredients'];
      final name = ingredientData is Map<String, dynamic>
          ? ingredientData['name']?.toString()
          : null;

      if (name == null || name.trim().isEmpty) continue;

      final unit = row['unit']?.toString();
      final rawQuantity = row['quantity'];
      final quantity = rawQuantity is num
          ? rawQuantity.toDouble()
          : double.tryParse(rawQuantity?.toString() ?? '');

      final key = '${name.toLowerCase()}|${unit ?? ''}';

      final existing = grouped[key];

      if (existing == null) {
        grouped[key] = (name: name, total: quantity, unit: unit);
      } else {
        final combinedTotal = (existing.total != null && quantity != null)
            ? existing.total! + quantity
            : existing.total ?? quantity;

        grouped[key] = (name: name, total: combinedTotal, unit: unit);
      }
    }

    if (grouped.isEmpty) {
      return 0;
    }

    // 4. Insertion dans la liste de courses.
    final rows = grouped.values.map((item) {
      return {
        'user_id': user.id,
        'name': item.name,
        'quantity': item.total != null
            ? (item.total! % 1 == 0
                ? item.total!.toInt().toString()
                : item.total!.toStringAsFixed(1))
            : null,
        'unit': item.unit,
        'source': 'recipe',
      };
    }).toList();

    await _supabase.from('shopping_list_items').insert(rows);

    return rows.length;
  }

  // ============================================================
  // GÉNÉRATION À PARTIR D'UNE SEULE RECETTE
  // ============================================================

  /// Ajoute à la liste de courses tous les ingrédients d'une seule
  /// recette choisie. Retourne le nombre d'articles ajoutés.
  Future<int> generateFromRecipe(int recipeId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final ingredientsResponse = await _supabase
        .from('recipe_ingredients')
        .select('''
          quantity,
          unit,
          ingredients (
            name
          )
        ''')
        .eq('recipe_id', recipeId);

    final rows = <Map<String, dynamic>>[];

    for (final row in ingredientsResponse as List) {
      final ingredientData = row['ingredients'];
      final name = ingredientData is Map<String, dynamic>
          ? ingredientData['name']?.toString()
          : null;

      if (name == null || name.trim().isEmpty) continue;

      rows.add({
        'user_id': user.id,
        'name': name,
        'quantity': row['quantity']?.toString(),
        'unit': row['unit']?.toString(),
        'source': 'recipe',
        'recipe_id': recipeId,
      });
    }

    if (rows.isEmpty) {
      return 0;
    }

    await _supabase.from('shopping_list_items').insert(rows);

    return rows.length;
  }
}