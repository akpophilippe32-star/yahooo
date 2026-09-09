class RecipeModel {
  final int id;
  final String title;
  final String? description;
  final String? imageUrl;
  final int? prepTime;
  final int? cookTime;
  final int? servings;
  final String? difficulty;
  final String? dietType;
  final String? instructions;
  final int? categoryId;
  final String? categoryName;

  // Informations supplémentaires pour le Creator
  final String? status;
  final DateTime? createdAt;

  // Vidéo (recette créée à partir d'une vidéo importée)
  final String sourceType;
  final String? videoUrl;

  // Nutrition de base (facultative — §11 du cahier des charges)
  final int? caloriesKcal;
  final double? carbsG;
  final double? fatG;
  final double? proteinG;

  RecipeModel({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    this.prepTime,
    this.cookTime,
    this.servings,
    this.difficulty,
    this.dietType,
    this.instructions,
    this.categoryId,
    this.categoryName,
    this.status,
    this.createdAt,
    this.sourceType = 'manual',
    this.videoUrl,
    this.caloriesKcal,
    this.carbsG,
    this.fatG,
    this.proteinG,
  });

  factory RecipeModel.fromMap(Map<String, dynamic> map) {
    return RecipeModel(
      id: map['id'] as int,
      title: map['title'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
      prepTime: map['prep_time'] as int?,
      cookTime: map['cook_time'] as int?,
      servings: map['servings'] as int?,
      difficulty: map['difficulty'] as String?,
      dietType: map['diet_type'] as String?,
      instructions: map['instructions'] as String?,
      categoryId: map['category_id'] as int?,
      categoryName: map['category_name'] as String?,
      status: map['status'] as String?,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(
              map['created_at'].toString(),
            )
          : null,
      sourceType: map['source_type'] as String? ?? 'manual',
      videoUrl: map['video_url'] as String?,
      caloriesKcal: map['calories_kcal'] as int?,
      carbsG: (map['carbs_g'] as num?)?.toDouble(),
      fatG: (map['fat_g'] as num?)?.toDouble(),
      proteinG: (map['protein_g'] as num?)?.toDouble(),
    );
  }
}