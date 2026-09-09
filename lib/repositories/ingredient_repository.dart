import 'package:supabase_flutter/supabase_flutter.dart';

class IngredientRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Récupère tous les ingrédients disponibles.
  Future<List<Map<String, dynamic>>> getIngredients() async {
    final response = await _supabase
        .from('ingredients')
        .select('''
          id,
          name,
          description,
          image_url
        ''')
        .order('name');

    return (response as List)
        .map(
          (ingredient) =>
              Map<String, dynamic>.from(ingredient),
        )
        .toList();
  }

  /// Ajoute un ingrédient à une recette.
  Future<Map<String, dynamic>> addIngredientToRecipe({
    required int recipeId,
    required int ingredientId,
    double? quantity,
    String? unit,
    bool optional = false,
  }) async {
    final response = await _supabase
        .from('recipe_ingredients')
        .insert({
          'recipe_id': recipeId,
          'ingredient_id': ingredientId,
          'quantity': quantity,
          'unit': unit,
          'optional': optional,
        })
        .select()
        .single();

    return Map<String, dynamic>.from(response);
  }
}