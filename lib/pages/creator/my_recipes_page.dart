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
    return Card(
      margin: const EdgeInsets.only(bottom: 16),

      child: InkWell(
        borderRadius: BorderRadius.circular(12),

        // ========================================================
        // CLIC SUR LA RECETTE
        // ========================================================

        onTap: () {
          _openRecipeDetail(recipe);
        },

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              // ==================================================
              // TITRE
              // ==================================================

              Text(
                recipe.title,

                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              // ==================================================
              // CATÉGORIE
              // ==================================================

              if (recipe.categoryName != null)
                Text(
                  recipe.categoryName!,

                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),

              const SizedBox(height: 12),

              // ==================================================
              // STATUT
              // ==================================================

              Row(
                children: [
                  _buildStatusBadge(recipe.status),

                  const Spacer(),

                  if (recipe.createdAt != null)
                    Text(
                      _formatDate(recipe.createdAt!),

                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant,
                      ),
                    ),
                ],
              ),

              // ==================================================
              // DESCRIPTION
              // ==================================================

              if (recipe.description != null &&
                  recipe.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 12),

                Text(
                  recipe.description!,

                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,

                  style: TextStyle(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurfaceVariant,
                  ),
                ),
              ],

              const SizedBox(height: 8),

              // ==================================================
              // INDICATION CLIQUABLE
              // ==================================================

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'Voir les détails',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),

                  const SizedBox(width: 4),

                  Icon(
                    Icons.arrow_forward_ios,
                    size: 14,
                    color: Theme.of(context)
                        .colorScheme
                        .primary,
                  ),
                ],
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

    switch (status) {
      case 'published':
        label = 'Publiée';
        icon = Icons.check_circle_outline;
        break;

      case 'draft':
        label = 'Brouillon';
        icon = Icons.edit_outlined;
        break;

      case 'archived':
        label = 'Archivée';
        icon = Icons.archive_outlined;
        break;

      default:
        label = 'Inconnue';
        icon = Icons.help_outline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 6,
      ),

      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Row(
        mainAxisSize: MainAxisSize.min,

        children: [
          Icon(
            icon,
            size: 16,
          ),

          const SizedBox(width: 6),

          Text(
            label,

            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
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

  // ============================================================
  // FORMATAGE DE LA DATE
  // ============================================================

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }
}