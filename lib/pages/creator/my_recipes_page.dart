import 'package:flutter/material.dart';

import '../../core/app_bar_leading.dart';
import '../../core/app_drawer.dart';
import '../../models/recipe_model.dart';
import '../../repositories/recipe_repository.dart';
import '../../features/recipes/presentation/create_video_recipe_page.dart';
import 'recipe_detail_page.dart';

class MyRecipesPage extends StatefulWidget {
  const MyRecipesPage({super.key});

  @override
  State<MyRecipesPage> createState() => _MyRecipesPageState();
}

class _MyRecipesPageState extends State<MyRecipesPage> {
  final RecipeRepository _recipeRepository = RecipeRepository();

  late Future<List<RecipeModel>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  // ============================================================
  // CHARGEMENT DES RECETTES
  // ============================================================

  void _loadRecipes() {
    _recipesFuture = _recipeRepository.getMyRecipes();
  }

  // ============================================================
  // ACTUALISER
  // ============================================================

  Future<void> _refreshRecipes() async {
    setState(() {
      _loadRecipes();
    });

    await _recipesFuture;
  }

  // ============================================================
  // OUVRIR LE DÉTAIL D'UNE RECETTE
  // ============================================================

  Future<void> _openRecipeDetail(RecipeModel recipe) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) {
          return RecipeDetailPage(
            recipe: recipe,
          );
        },
      ),
    );

    // On rafraîchit systématiquement la liste au retour de l'écran de
    // détail, car la recette a pu être modifiée (titre, statut, image...)
    // pendant que l'utilisateur y était.
    if (!mounted) return;

    await _refreshRecipes();
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Mes recettes'),
        leading: const AppBackMenuLeading(),
        leadingWidth: 96,
      ),

      body: FutureBuilder<List<RecipeModel>>(
        future: _recipesFuture,

        builder: (context, snapshot) {
          // ========================================================
          // CHARGEMENT
          // ========================================================

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ========================================================
          // ERREUR
          // ========================================================

          if (snapshot.hasError) {
            return _buildErrorState(
              snapshot.error.toString(),
            );
          }

          // ========================================================
          // DONNÉES
          // ========================================================

          final recipes = snapshot.data ?? [];

          // ========================================================
          // AUCUNE RECETTE
          // ========================================================

          if (recipes.isEmpty) {
            return _buildEmptyState();
          }

          // ========================================================
          // LISTE DES RECETTES
          // ========================================================

          return RefreshIndicator(
            onRefresh: _refreshRecipes,

            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: recipes.length,

              itemBuilder: (context, index) {
                final recipe = recipes[index];

                return _buildRecipeCard(recipe);
              },
            ),
          );
        },
      ),

      // ==========================================================
      // BOUTON AJOUTER
      // ==========================================================

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showCreateRecipeChoice();
        },

        child: const Icon(Icons.add),
      ),
    );
  }

  // ============================================================
  // CHOIX DU MODE DE CRÉATION (classique ou vidéo)
  // ============================================================

  Future<void> _showCreateRecipeChoice() async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  'Comment veux-tu créer ta recette ?',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.edit_note_outlined),
                title: const Text('Recette classique'),
                subtitle: const Text(
                  'Titre, ingrédients et étapes saisis manuellement.',
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();

                  await Navigator.of(context).pushNamed('/create-recipe');

                  if (!mounted) return;
                  await _refreshRecipes();
                },
              ),
              ListTile(
                leading: const Icon(Icons.videocam_outlined),
                title: const Text('Recette vidéo'),
                subtitle: const Text(
                  'Importe une vidéo, avec ou sans aide de l’IA.',
                ),
                onTap: () async {
                  Navigator.of(sheetContext).pop();

                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const CreateVideoRecipePage(),
                    ),
                  );

                  if (!mounted) return;
                  await _refreshRecipes();
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // CARTE D'UNE RECETTE
  // ============================================================

  Widget _buildRecipeCard(RecipeModel recipe) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openRecipeDetail(recipe),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // MINIATURE
              // ==================================================

              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: recipe.sourceType == 'video'
                      ? Container(
                          color: colorScheme.surface,
                          child: Icon(
                            Icons.play_circle_outline,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        )
                      : FutureBuilder<String?>(
                          future: _recipeRepository
                              .getRecipeImageUrl(recipe.imageUrl),
                          builder: (context, snapshot) {
                            final url = snapshot.data;

                            return Container(
                              color: colorScheme.surface,
                              child: url != null
                                  ? Image.network(
                                      url,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stack) {
                                        return const Icon(Icons.restaurant);
                                      },
                                    )
                                  : Icon(
                                      Icons.restaurant,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(width: 14),

              // ==================================================
              // CONTENU
              // ==================================================

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (recipe.categoryName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          recipe.categoryName!,
                          style: TextStyle(
                            fontSize: 12,
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),
                    _buildStatusBadge(recipe.status),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right,
                color: colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // BADGE DU STATUT
  // ============================================================

  Widget _buildStatusBadge(String? status) {
    String label;
    IconData icon;
    Color color;

    switch (status) {
      case 'published':
        label = 'Publiée';
        icon = Icons.check_circle_outline;
        color = const Color(0xFF3B6D11);
        break;
      case 'draft':
        label = 'Brouillon';
        icon = Icons.edit_outlined;
        color = const Color(0xFFE8A63C);
        break;
      case 'archived':
        label = 'Archivée';
        icon = Icons.archive_outlined;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      default:
        label = 'Inconnue';
        icon = Icons.help_outline;
        color = Theme.of(context).colorScheme.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }


  // ============================================================
  // ÉTAT VIDE
  // ============================================================

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: _refreshRecipes,

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),

        padding: const EdgeInsets.all(24),

        children: [
          const SizedBox(height: 100),

          Icon(
            Icons.restaurant_menu,
            size: 80,

            color: Theme.of(context)
                .colorScheme
                .primary,
          ),

          const SizedBox(height: 24),

          const Text(
            'Aucune recette',

            textAlign: TextAlign.center,

            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Tu n’as pas encore créé de recette.',

            textAlign: TextAlign.center,

            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurfaceVariant,
            ),
          ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _showCreateRecipeChoice,

            icon: const Icon(Icons.add),

            label: const Text(
              'Créer une recette',
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ÉTAT ERREUR
  // ============================================================

  Widget _buildErrorState(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(
              Icons.error_outline,

              size: 64,

              color: Theme.of(context)
                  .colorScheme
                  .error,
            ),

            const SizedBox(height: 16),

            const Text(
              'Impossible de charger tes recettes',

              textAlign: TextAlign.center,

              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              error,

              textAlign: TextAlign.center,

              style: TextStyle(
                color: Theme.of(context)
                    .colorScheme
                    .onSurfaceVariant,
              ),
            ),

            const SizedBox(height: 24),

            FilledButton.icon(
              onPressed: () {
                setState(() {
                  _loadRecipes();
                });
              },

              icon: const Icon(Icons.refresh),

              label: const Text(
                'Réessayer',
              ),
            ),
          ],
        ),
      ),
    );
  }
}