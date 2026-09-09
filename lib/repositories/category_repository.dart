import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category_model.dart';

class CategoryRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<CategoryModel>> getCategories() async {
    final response = await _supabase
        .from('categories')
        .select('''
          id,
          name,
          description,
          image_url
        ''')
        .order('name');

    return (response as List)
        .map(
          (category) => CategoryModel.fromMap(
            Map<String, dynamic>.from(category),
          ),
        )
        .toList();
  }
}