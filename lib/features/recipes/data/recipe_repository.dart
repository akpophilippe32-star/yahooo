import 'package:supabase_flutter/supabase_flutter.dart';

class RecipeRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Crée une nouvelle recette en tant que brouillon.
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
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'Utilisateur non connecté. Impossible de créer la recette.',
      );
    }

    final data = {
      'author_id': user.id,
      'title': title,
      'description': description,
      'category_id': categoryId,
      'image_url': imageUrl,
      'prep_time': prepTime,
      'cook_time': cookTime,
      'servings': servings,
      'difficulty': difficulty,
      'diet_type': dietType,
      'status': 'draft',
      'published_at': null,
    };

    final response = await _supabase
        .from('recipes')
        .insert(data)
        .select()
        .single();

    return response;
  }
}