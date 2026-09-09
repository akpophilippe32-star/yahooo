class CategoryModel {
  final int id;
  final String name;
  final String? description;
  final String? imageUrl;

  CategoryModel({
    required this.id,
    required this.name,
    this.description,
    this.imageUrl,
  });

  factory CategoryModel.fromMap(Map<String, dynamic> map) {
    return CategoryModel(
      id: map['id'] as int,
      name: map['name'] as String,
      description: map['description'] as String?,
      imageUrl: map['image_url'] as String?,
    );
  }
}