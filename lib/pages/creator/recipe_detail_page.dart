import 'package:flutter/material.dart';

import '../../core/app_bar_leading.dart';
import '../../core/app_drawer.dart';
import '../../models/recipe_model.dart';
import 'edit_recipe_page.dart';
import '../../repositories/recipe_repository.dart';

class RecipeDetailPage extends StatefulWidget {
  final RecipeModel recipe;

  const RecipeDetailPage({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  final RecipeRepository _recipeRepository = RecipeRepository();
  late Future<Map<String, dynamic>> _detailsFuture;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  void _loadDetails() {
    _detailsFuture = _recipeRepository.getRecipeDetails(widget.recipe.id);
  }

  Future<void> _reloadDetails() async {
    setState(() {
      _loadDetails();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Détail de la recette'),
        leading: const AppBackMenuLeading(),
        leadingWidth: 96,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _detailsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'Impossible de charger les détails de la recette.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text('${snapshot.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: _reloadDetails,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          final details = snapshot.data ?? {};
          final recipe = details['recipe'] as RecipeModel? ?? widget.recipe;
          final ingredients = (details['ingredients'] as List<dynamic>?) ?? [];
          final steps = (details['steps'] as List<dynamic>?) ?? [];

          return _buildRecipeContent(recipe, ingredients, steps);
        },
      ),
    );
  }

  Widget _buildRecipeContent(
    RecipeModel recipe,
    List<dynamic> ingredients,
    List<dynamic> steps,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (recipe.imageUrl != null && recipe.imageUrl!.trim().isNotEmpty) ...[
            FutureBuilder<String?>(
              future: _recipeRepository.getRecipeImageUrl(recipe.imageUrl),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                final imageUrl = snapshot.data;

                if (imageUrl == null || imageUrl.isEmpty) {
                  return Container(
                    height: 220,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.outline,
                      ),
                    ),
                    child: const Center(
                      child: Text('Impossible de charger l’image.'),
                    ),
                  );
                }

                return ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Image.network(
                    imageUrl,
                    height: 220,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 220,
                        child: const Center(
                          child: Text('Impossible de charger l’image.'),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
          ],

          Text(
            recipe.title,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildStatusBadge(recipe),
          const SizedBox(height: 24),

          if (recipe.description != null &&
              recipe.description!.trim().isNotEmpty) ...[
            const Text(
              'Description',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(recipe.description!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
          ],

          const Text(
            'Informations',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildInfoCard(recipe),
          const SizedBox(height: 24),

          if (recipe.categoryName != null) ...[
            const Text(
              'Catégorie',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(recipe.categoryName!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
          ],

          if (recipe.dietType != null &&
              recipe.dietType!.trim().isNotEmpty) ...[
            const Text(
              'Type alimentaire',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(recipe.dietType!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
          ],

          _buildIngredientsSection(ingredients),
          const SizedBox(height: 32),
          _buildStepsSection(steps),
          const SizedBox(height: 32),

          if (recipe.instructions != null &&
              recipe.instructions!.trim().isNotEmpty) ...[
            const Text(
              'Instructions',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(recipe.instructions!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 32),
          ],

          OutlinedButton.icon(
            onPressed: () async {
              final result = await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => EditRecipePage(recipe: recipe),
                ),
              );

              if (!context.mounted) return;

              if (result == true) {
                await _reloadDetails();
              }
            },
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Modifier la recette'),
          ),
        ],
      ),
    );
  }

  Widget _buildIngredientsSection(List<dynamic> ingredients) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Ingrédients',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (ingredients.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucun ingrédient enregistré pour cette recette.'),
            ),
          ),
        ...ingredients.asMap().entries.map((entry) {
          final ingredient = Map<String, dynamic>.from(entry.value as Map);
          final ingredientData = ingredient['ingredients'];
          final name = ingredientData is Map<String, dynamic>
              ? ingredientData['name']?.toString() ?? 'Ingrédient inconnu'
              : 'Ingrédient inconnu';

          final details = <String>[];
          if (ingredient['quantity'] != null) {
            details.add(ingredient['quantity'].toString());
          }
          if (ingredient['unit'] != null &&
              ingredient['unit'].toString().trim().isNotEmpty) {
            details.add(ingredient['unit'].toString());
          }
          if (ingredient['optional'] == true) details.add('facultatif');

          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: CircleAvatar(child: Text('${entry.key + 1}')),
              title: Text(
                name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                details.isEmpty ? 'Quantité non précisée' : details.join(' '),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStepsSection(List<dynamic> steps) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Étapes de préparation',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (steps.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aucune étape de préparation enregistrée.'),
            ),
          ),
        ...steps.map((step) {
          final stepData = Map<String, dynamic>.from(step as Map);
          final stepNumber = stepData['step_number'] as int? ?? 0;
          final instruction = stepData['instruction']?.toString() ?? '';

          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(child: Text('$stepNumber')),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      instruction,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildStatusBadge(RecipeModel recipe) {
    String label;
    switch (recipe.status) {
      case 'published':
        label = 'Publiée';
        break;
      case 'archived':
        label = 'Archivée';
        break;
      default:
        label = 'Brouillon';
        break;
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Chip(
        label: Text(label),
        avatar: Icon(_statusIcon(recipe), size: 18),
      ),
    );
  }

  IconData _statusIcon(RecipeModel recipe) {
    switch (recipe.status) {
      case 'published':
        return Icons.check_circle_outline;
      case 'archived':
        return Icons.archive_outlined;
      default:
        return Icons.edit_note;
    }
  }

  Widget _buildInfoCard(RecipeModel recipe) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (recipe.difficulty != null)
              _buildInfoRow(
                Icons.signal_cellular_alt,
                'Difficulté',
                _difficultyLabel(recipe.difficulty!),
              ),
            if (recipe.prepTime != null)
              _buildInfoRow(
                Icons.timer_outlined,
                'Préparation',
                '${recipe.prepTime} min',
              ),
            if (recipe.cookTime != null)
              _buildInfoRow(
                Icons.local_fire_department_outlined,
                'Cuisson',
                '${recipe.cookTime} min',
              ),
            if (recipe.servings != null)
              _buildInfoRow(
                Icons.people_outline,
                'Portions',
                '${recipe.servings}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _difficultyLabel(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'Facile';
      case 'medium':
        return 'Moyenne';
      case 'hard':
        return 'Difficile';
      default:
        return difficulty;
    }
  }
}