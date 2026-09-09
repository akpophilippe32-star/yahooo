import 'package:flutter/material.dart';

import '../../../core/app_bar_leading.dart';
import '../../../core/app_drawer.dart';
import '../../../models/recipe_model.dart';
import '../../../repositories/recipe_repository.dart';
import '../../../widgets/recipe_grid_card.dart';

/// Écran "Mes favoris" — les recettes que l'utilisateur a likées
/// (le like sert de base aux favoris, pas de système séparé).
class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final _recipeRepository = RecipeRepository();
  late Future<List<RecipeModel>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _favoritesFuture = _recipeRepository.getMyLikedRecipes();
  }

  Future<void> _refresh() async {
    setState(() {
      _favoritesFuture = _recipeRepository.getMyLikedRecipes();
    });
    await _favoritesFuture;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Mes favoris'),
        leading: const AppBackMenuLeading(),
        leadingWidth: 96,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<RecipeModel>>(
            future: _favoritesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Impossible de charger tes favoris : '
                        '${snapshot.error}',
                      ),
                    ),
                  ],
                );
              }

              final recipes = snapshot.data ?? [];

              if (recipes.isEmpty) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.favorite_border,
                            size: 44,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Aucun favori pour l’instant.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Appuie sur le ❤️ d’une recette pour '
                            'l’ajouter ici.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.72,
                ),
                itemCount: recipes.length,
                itemBuilder: (context, index) {
                  return RecipeGridCard(
                    recipe: recipes[index],
                    recipeRepository: _recipeRepository,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}