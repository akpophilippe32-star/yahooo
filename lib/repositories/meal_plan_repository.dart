import 'package:supabase_flutter/supabase_flutter.dart';

/// Gère le planning des repas de l'utilisateur connecté (§19 du
/// cahier des charges) : un repas par créneau (jour + type de
/// repas), en ajouter un autre remplace l'existant.
class MealPlanRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  static const List<String> mealTypes = [
    'petit_dejeuner',
    'dejeuner',
    'diner',
    'collation',
  ];

  static String mealTypeLabel(String mealType) {
    switch (mealType) {
      case 'petit_dejeuner':
        return 'Petit-déjeuner';
      case 'dejeuner':
        return 'Déjeuner';
      case 'diner':
        return 'Dîner';
      case 'collation':
        return 'Collation';
      default:
        return mealType;
    }
  }

  // ============================================================
  // LECTURE
  // ============================================================

  /// Récupère le planning sur une période (bornes incluses), avec
  /// les informations principales de chaque recette planifiée.
  Future<List<Map<String, dynamic>>> getMealPlan({
    required DateTime start,
    required DateTime end,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _supabase
        .from('meal_plan_entries')
        .select('''
          id,
          plan_date,
          meal_type,
          recipe_id,
          recipes (
            id,
            title,
            image_url,
            video_url,
            source_type,
            prep_time,
            cook_time
          )
        ''')
        .eq('user_id', user.id)
        .gte('plan_date', _formatDate(start))
        .lte('plan_date', _formatDate(end))
        .order('plan_date', ascending: true);

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  // ============================================================
  // ÉCRITURE
  // ============================================================

  /// Ajoute (ou remplace) le repas prévu pour un créneau donné.
  Future<void> setMealPlanEntry({
    required DateTime date,
    required String mealType,
    required int recipeId,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    await _supabase.from('meal_plan_entries').upsert(
      {
        'user_id': user.id,
        'plan_date': _formatDate(date),
        'meal_type': mealType,
        'recipe_id': recipeId,
      },
      onConflict: 'user_id,plan_date,meal_type',
    );
  }

  /// Retire le repas prévu pour un créneau.
  Future<void> removeMealPlanEntry(int entryId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    await _supabase
        .from('meal_plan_entries')
        .delete()
        .eq('id', entryId)
        .eq('user_id', user.id);
  }

  String _formatDate(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}