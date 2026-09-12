import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../models/category_model.dart';
import '../../../models/recipe_model.dart';
import '../../../repositories/category_repository.dart';
import '../../../repositories/recipe_repository.dart';
import '../../../widgets/recipe_grid_card.dart';
import '../../../widgets/recipe_video_thumbnail.dart';
import 'recipe_public_view_page.dart';

/// Contenu de l'onglet Recherche (§17 du cahier des charges) — un
/// vrai écran de **découverte** : la grille de recettes est visible
/// dès l'ouverture (pas seulement après avoir tapé une recherche),
/// avec filtres rapides et recherche par titre/description/
/// créateur/ingrédient.
///
/// Différent de la recherche intégrée de l'Accueil, qui elle filtre
/// sur place sans jamais afficher de grille par défaut.
///
/// Pas de Scaffold ici — fourni par la coquille d'app persistante
/// (AppShellPage).
/// Niveau de détail d'affichage des recettes : grille classique,
/// liste détaillée, ou liste compacte — cycle via l'icône image de
/// l'en-tête (même logique que la réduction du calendrier sur Plan).
enum _RecipeViewDensity { grid, list, compact }

class SearchTabView extends StatefulWidget {
  const SearchTabView({super.key});

  @override
  State<SearchTabView> createState() => SearchTabViewState();
}

class SearchTabViewState extends State<SearchTabView> {
  final _recipeRepository = RecipeRepository();
  final _categoryRepository = CategoryRepository();
  final _searchController = TextEditingController();
  final _searchFocusNode = FocusNode();

  late Future<List<CategoryModel>> _categoriesFuture;
  late Future<List<RecipeModel>> _resultsFuture;

  int? _selectedCategoryId;
  Timer? _debounce;
  _RecipeViewDensity _density = _RecipeViewDensity.grid;

  static const String _historyPrefsKey = 'recent_recipe_searches';
  static const int _historyMaxItems = 10;
  List<String> _recentSearches = [];

  /// Réduit progressivement l'affichage : grille → liste détaillée
  /// → liste compacte → retour à la grille. Appelée depuis l'icône
  /// image de l'en-tête de la coquille (AppShellPage).
  void cycleViewDensity() {
    setState(() {
      _density = switch (_density) {
        _RecipeViewDensity.grid => _RecipeViewDensity.list,
        _RecipeViewDensity.list => _RecipeViewDensity.compact,
        _RecipeViewDensity.compact => _RecipeViewDensity.grid,
      };
    });
  }

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _categoryRepository.getCategories();
    // Mode découverte : la grille montre les recettes publiées dès
    // l'ouverture, pas besoin de taper quoi que ce soit d'abord.
    _resultsFuture = _recipeRepository.getPublishedRecipes();
    _loadHistory();
    _searchFocusNode.addListener(() => setState(() {}));
  }

  // ============================================================
  // HISTORIQUE DE RECHERCHE (local, shared_preferences)
  // ============================================================

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_historyPrefsKey) ?? [];

    if (!mounted) return;

    setState(() => _recentSearches = saved);
  }

  Future<void> _saveToHistory(String term) async {
    final trimmed = term.trim();

    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();

    final updated = [
      trimmed,
      ..._recentSearches.where(
        (item) => item.toLowerCase() != trimmed.toLowerCase(),
      ),
    ].take(_historyMaxItems).toList();

    await prefs.setStringList(_historyPrefsKey, updated);

    if (!mounted) return;

    setState(() => _recentSearches = updated);
  }

  Future<void> _removeFromHistory(String term) async {
    final prefs = await SharedPreferences.getInstance();

    final updated = _recentSearches.where((item) => item != term).toList();

    await prefs.setStringList(_historyPrefsKey, updated);

    if (!mounted) return;

    setState(() => _recentSearches = updated);
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_historyPrefsKey);

    if (!mounted) return;

    setState(() => _recentSearches = []);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _runSearch);
  }

  void _runSearch() {
    final query = _searchController.text.trim();

    setState(() {
      // Ni recherche ni catégorie : mode découverte, on montre tout.
      _resultsFuture = (query.isEmpty && _selectedCategoryId == null)
          ? _recipeRepository.getPublishedRecipes()
          : _recipeRepository.searchRecipes(
              query: query.isEmpty ? null : query,
              categoryId: _selectedCategoryId,
            );
    });

    if (query.isNotEmpty) {
      _saveToHistory(query);
    }
  }

  void _selectCategory(int? categoryId) {
    setState(() {
      _selectedCategoryId =
          _selectedCategoryId == categoryId ? null : categoryId;
    });
    _runSearch();
  }

  void _searchFor(String term) {
    _searchController.text = term;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: term.length),
    );
    _searchFocusNode.unfocus();
    _runSearch();
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — bientôt disponible.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final showRecentSearches =
        _searchFocusNode.hasFocus && _searchController.text.trim().isEmpty;

    return SafeArea(
      child: Column(
        children: [
          // ====================================================
          // BARRE DE RECHERCHE
          // ====================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: _onQueryChanged,
              onSubmitted: (_) => _runSearch(),
              decoration: InputDecoration(
                hintText: 'Recette, aliment, créateur...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _searchController.clear();
                          _runSearch();
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ====================================================
          // FILTRES RAPIDES
          // ====================================================

          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                ActionChip(
                  avatar: const Icon(Icons.favorite_border, size: 16),
                  label: const Text('Favoris'),
                  onPressed: () {
                    Navigator.of(context).pushNamed('/favorites');
                  },
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.push_pin_outlined, size: 16),
                  label: const Text('Épinglées'),
                  onPressed: () => _showComingSoon('Les recettes épinglées'),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ====================================================
          // FILTRES DE CATÉGORIE
          // ====================================================

          SizedBox(
            height: 40,
            child: FutureBuilder<List<CategoryModel>>(
              future: _categoriesFuture,
              builder: (context, snapshot) {
                final categories = snapshot.data ?? [];

                if (categories.isEmpty) {
                  return const SizedBox.shrink();
                }

                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: categories.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final category = categories[index];
                    final isSelected = _selectedCategoryId == category.id;

                    return ChoiceChip(
                      label: Text(category.name),
                      selected: isSelected,
                      onSelected: (_) => _selectCategory(category.id),
                    );
                  },
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // ====================================================
          // RECHERCHES RÉCENTES (affichées seulement quand le
          // champ est actif et vide, pour ne pas gêner la grille)
          // ====================================================

          if (showRecentSearches && _recentSearches.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recherches récentes',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      TextButton(
                        onPressed: _clearHistory,
                        child: const Text('Tout effacer'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _recentSearches.map((term) {
                      return InputChip(
                        label: Text(term),
                        onPressed: () => _searchFor(term),
                        onDeleted: () => _removeFromHistory(term),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),

          // ====================================================
          // GRILLE DE RECETTES (toujours visible — mode découverte)
          // ====================================================

          Expanded(
            child: FutureBuilder<List<RecipeModel>>(
              future: _resultsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Erreur de recherche : ${snapshot.error}',
                    ),
                  );
                }

                final results = snapshot.data ?? [];

                if (results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.search_off,
                          size: 40,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aucun résultat.',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return _buildResultsList(results);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultsList(List<RecipeModel> results) {
    switch (_density) {
      case _RecipeViewDensity.grid:
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 16,
            crossAxisSpacing: 12,
            childAspectRatio: 0.72,
          ),
          itemCount: results.length,
          itemBuilder: (context, index) {
            return RecipeGridCard(
              recipe: results[index],
              recipeRepository: _recipeRepository,
            );
          },
        );

      case _RecipeViewDensity.list:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          itemCount: results.length,
          separatorBuilder: (context, index) => const SizedBox(height: 14),
          itemBuilder: (context, index) {
            return _RecipeListTile(
              recipe: results[index],
              recipeRepository: _recipeRepository,
            );
          },
        );

      case _RecipeViewDensity.compact:
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
          itemCount: results.length,
          separatorBuilder: (context, index) => const Divider(height: 1),
          itemBuilder: (context, index) {
            return _RecipeCompactTile(
              recipe: results[index],
              recipeRepository: _recipeRepository,
            );
          },
        );
    }
  }
}

// ============================================================
// LIGNE DÉTAILLÉE (densité "liste")
// ============================================================

class _RecipeListTile extends StatelessWidget {
  final RecipeModel recipe;
  final RecipeRepository recipeRepository;

  const _RecipeListTile({
    required this.recipe,
    required this.recipeRepository,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RecipePublicViewPage(recipe: recipe),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 64,
              height: 64,
              child: recipe.sourceType == 'video' &&
                      recipe.videoUrl != null &&
                      recipe.videoUrl!.isNotEmpty
                  ? RecipeVideoThumbnail(
                      videoPath: recipe.videoUrl!,
                      recipeRepository: recipeRepository,
                    )
                  : FutureBuilder<String?>(
                      future:
                          recipeRepository.getRecipeImageUrl(recipe.imageUrl),
                      builder: (context, snapshot) {
                        final url = snapshot.data;

                        return Container(
                          color: colorScheme.surfaceContainerHighest,
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
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recipe.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (recipe.prepTime != null) ...[
                      Icon(
                        Icons.timer_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${recipe.prepTime}m',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    if (recipe.cookTime != null) ...[
                      Icon(
                        Icons.local_fire_department_outlined,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        '${recipe.cookTime}m',
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// LIGNE COMPACTE (densité "compacte")
// ============================================================

class _RecipeCompactTile extends StatelessWidget {
  final RecipeModel recipe;
  final RecipeRepository recipeRepository;

  const _RecipeCompactTile({
    required this.recipe,
    required this.recipeRepository,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: ClipOval(
        child: SizedBox(
          width: 40,
          height: 40,
          child: recipe.sourceType == 'video' &&
                  recipe.videoUrl != null &&
                  recipe.videoUrl!.isNotEmpty
              ? RecipeVideoThumbnail(
                  videoPath: recipe.videoUrl!,
                  recipeRepository: recipeRepository,
                )
              : FutureBuilder<String?>(
                  future: recipeRepository.getRecipeImageUrl(recipe.imageUrl),
                  builder: (context, snapshot) {
                    final url = snapshot.data;

                    return Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: url != null
                          ? Image.network(
                              url,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stack) {
                                return const Icon(Icons.restaurant, size: 16);
                              },
                            )
                          : Icon(
                              Icons.restaurant,
                              size: 16,
                              color: colorScheme.onSurfaceVariant,
                            ),
                    );
                  },
                ),
        ),
      ),
      title: Text(
        recipe.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      trailing: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RecipePublicViewPage(recipe: recipe),
          ),
        );
      },
    );
  }
}