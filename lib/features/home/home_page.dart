import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/category_model.dart';
import '../../models/recipe_model.dart';
import '../../repositories/category_repository.dart';
import '../../repositories/recipe_repository.dart';
import '../../widgets/recipe_grid_card.dart';
import '../../widgets/recipe_video_thumbnail.dart';
import '../recipes/presentation/recipe_public_view_page.dart';

/// Contenu de l'onglet Accueil : catégories + grille des recettes
/// populaires, avec une recherche **intégrée sur place** (filtre
/// directement le contenu affiché ici, sans changer d'écran).
///
/// Différent de l'onglet Recherche (nav du bas) qui, lui, est un
/// vrai écran de découverte avec filtres avancés.
///
/// Pas de Scaffold/Drawer/nav ici — c'est la coquille d'app
/// persistante (AppShellPage) qui les fournit.
class HomeTabView extends StatefulWidget {
  final VoidCallback onOpenSearch;

  const HomeTabView({super.key, required this.onOpenSearch});

  @override
  State<HomeTabView> createState() => HomeTabViewState();
}

class HomeTabViewState extends State<HomeTabView> {
  final RecipeRepository _recipeRepository = RecipeRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final TextEditingController _searchController = TextEditingController();

  late Future<List<CategoryModel>> _categoriesFuture;
  late Future<List<RecipeModel>> _recipesFuture;

  Future<List<RecipeModel>>? _searchResultsFuture;
  Timer? _debounce;

  bool get _isSearching => _searchResultsFuture != null;

  final PageController _carouselController = PageController();
  Timer? _carouselTimer;
  int _carouselPage = 0;

  @override
  void initState() {
    super.initState();

    _categoriesFuture = _categoryRepository.getCategories();
    _recipesFuture = _recipeRepository.getPublishedRecipes();

    // Défilement automatique du carrousel façon Play Store.
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!_carouselController.hasClients) return;

      final nextPage = _carouselPage + 1;
      _carouselController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    _carouselTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  // ============================================================
  // RECHERCHE INTÉGRÉE (filtre sur place, reste sur l'accueil)
  // ============================================================

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    if (value.trim().isEmpty) {
      setState(() => _searchResultsFuture = null);
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 400), () {
      setState(() {
        _searchResultsFuture =
            _recipeRepository.searchRecipes(query: value.trim());
      });
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _debounce?.cancel();
    setState(() => _searchResultsFuture = null);
  }

  // ============================================================
  // RAFRAÎCHIR (appelée aussi depuis la coquille après création
  // d'une recette, retour de "Mes recettes", etc.)
  // ============================================================

  Future<void> refresh() async {
    setState(() {
      _categoriesFuture = _categoryRepository.getCategories();
      _recipesFuture = _recipeRepository.getPublishedRecipes();
    });

    try {
      await Future.wait([_categoriesFuture, _recipesFuture]);
    } catch (_) {
      // Erreur déjà visible via les FutureBuilder concernés.
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: refresh,
      child: CustomScrollView(
        slivers: [
          // ====================================================
          // BARRE DE RECHERCHE INTÉGRÉE
          // ====================================================

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            sliver: SliverToBoxAdapter(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Rechercher une recette, un aliment...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _isSearching
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor:
                      Theme.of(context).colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(vertical: 13),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          // ====================================================
          // MODE RECHERCHE : juste les résultats
          // ====================================================

          if (_isSearching) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Résultats pour « ${_searchController.text.trim()} »',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            _buildSearchResultsGrid(context),
            const SliverPadding(padding: EdgeInsets.only(bottom: 90)),
          ]

          // ====================================================
          // MODE NORMAL : catégories + recettes populaires
          // ====================================================
          else ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              sliver: SliverToBoxAdapter(
                child: _buildCategories(context),
              ),
            ),

            // ================================================
            // CARROUSEL PUBLICITAIRE (façon Play Store)
            // ================================================

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 0),
              sliver: SliverToBoxAdapter(
                child: _buildPromoCarousel(context),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Recettes populaires',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onOpenSearch,
                      child: const Text('Voir tout'),
                    ),
                  ],
                ),
              ),
            ),
            _buildRecipeGrid(context),

            // ================================================
            // RECETTES TENDANCE
            // ================================================

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Icon(
                      Icons.trending_up,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Recettes tendance',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton(
                      onPressed: widget.onOpenSearch,
                      child: const Text('Voir tout'),
                    ),
                  ],
                ),
              ),
            ),
            _buildTrendingGrid(context),

            const SliverPadding(padding: EdgeInsets.only(bottom: 90)),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // CARROUSEL PUBLICITAIRE DE RECETTES (façon Play Store)
  // ============================================================

  Widget _buildPromoCarousel(BuildContext context) {
    return FutureBuilder<List<RecipeModel>>(
      future: _recipesFuture,
      builder: (context, recipesSnapshot) {
        final recipes = (recipesSnapshot.data ?? []).take(5).toList();

        if (recipes.isEmpty) {
          return const SizedBox.shrink();
        }

        // On précharge d'un coup l'image de CHAQUE carte du
        // carrousel (pas seulement celle affichée en premier), pour
        // que swiper vers une carte suivante ne déclenche jamais sa
        // propre recherche d'image à ce moment-là — tout est déjà
        // prêt à l'arrivée.
        return FutureBuilder<Map<int, String?>>(
          future: _resolveCarouselImageUrls(recipes),
          builder: (context, urlsSnapshot) {
            final resolvedUrls = urlsSnapshot.data ?? const {};

            return SizedBox(
              height: 260,
              child: PageView.builder(
                controller: _carouselController,
                onPageChanged: (index) {
                  _carouselPage = index % recipes.length;
                },
                itemBuilder: (context, index) {
                  final recipe = recipes[index % recipes.length];

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    // Même format que l'image en tête de la fiche
                    // recette : rectangle plat, cœur en surimpression.
                    child: _PromoRecipeCard(
                      recipe: recipe,
                      recipeRepository: _recipeRepository,
                      preloadedImageUrl: resolvedUrls[recipe.id],
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Récupère en une seule fois les URLs (image, signées) de toutes
  /// les recettes-photo du carrousel. Les recettes vidéo gèrent
  /// elles-mêmes leur miniature via [RecipeVideoThumbnail].
  Future<Map<int, String?>> _resolveCarouselImageUrls(
    List<RecipeModel> recipes,
  ) async {
    final photoRecipes =
        recipes.where((r) => r.sourceType != 'video').toList();

    final urls = await Future.wait(
      photoRecipes.map((r) => _recipeRepository.getRecipeImageUrl(r.imageUrl)),
    );

    return {
      for (var i = 0; i < photoRecipes.length; i++) photoRecipes[i].id: urls[i],
    };
  }

  // ============================================================
  // GRILLE DE RÉSULTATS DE RECHERCHE
  // ============================================================

  Widget _buildSearchResultsGrid(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: FutureBuilder<List<RecipeModel>>(
        future: _searchResultsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasError) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Erreur de recherche : ${snapshot.error}'),
              ),
            );
          }

          final results = snapshot.data ?? [];

          if (results.isEmpty) {
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Aucun résultat.')),
              ),
            );
          }

          return SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return RecipeGridCard(
                  recipe: results[index],
                  recipeRepository: _recipeRepository,
                );
              },
              childCount: results.length,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // CATÉGORIES (cercles)
  // ============================================================

  Widget _buildCategories(BuildContext context) {
    return FutureBuilder<List<CategoryModel>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 76,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Text('Erreur catégories : ${snapshot.error}');
        }

        final categories = snapshot.data ?? [];

        if (categories.isEmpty) {
          return const SizedBox.shrink();
        }

        return SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final category = categories[index];

              return SizedBox(
                width: 60,
                child: Column(
                  children: [
                    ClipOval(
                      child: Container(
                        width: 52,
                        height: 52,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: category.imageUrl != null
                            ? Image.network(
                                category.imageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    Icons.restaurant_outlined,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  );
                                },
                              )
                            : Icon(
                                Icons.restaurant_outlined,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      category.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // GRILLE DE RECETTES (populaires)
  // ============================================================

  Widget _buildRecipeGrid(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: FutureBuilder<List<RecipeModel>>(
        future: _recipesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasError) {
            return SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Icon(Icons.error_outline, size: 40),
                    const SizedBox(height: 10),
                    const Text('Impossible de charger les recettes.'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: refresh,
                      child: const Text('Réessayer'),
                    ),
                  ],
                ),
              ),
            );
          }

          final recipes = snapshot.data ?? [];

          if (recipes.isEmpty) {
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: Text('Aucune recette disponible.')),
              ),
            );
          }

          return SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return RecipeGridCard(
                  recipe: recipes[index],
                  recipeRepository: _recipeRepository,
                );
              },
              childCount: recipes.length,
            ),
          );
        },
      ),
    );
  }

  // ============================================================
  // GRILLE DE RECETTES TENDANCE
  // ============================================================
  //
  // ⚠️ Pas encore un vrai calcul de tendance (nécessiterait un
  // suivi des vues/likes dans le temps) — pour l'instant, réutilise
  // les mêmes recettes publiées dans un ordre différent, comme
  // heuristique temporaire.

  Widget _buildTrendingGrid(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: FutureBuilder<List<RecipeModel>>(
        future: _recipesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          if (snapshot.hasError) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }

          final recipes = (snapshot.data ?? []).reversed.toList();

          if (recipes.isEmpty) {
            return const SliverToBoxAdapter(child: SizedBox.shrink());
          }

          return SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                return RecipeGridCard(
                  recipe: recipes[index],
                  recipeRepository: _recipeRepository,
                );
              },
              childCount: recipes.length,
            ),
          );
        },
      ),
    );
  }
}

// ============================================================
// CARTE DU CARROUSEL — même format que l'image en tête de la
// fiche recette (rectangle plat, cœur en surimpression, titre
// affiché en dessous plutôt que superposé).
// ============================================================

class _PromoRecipeCard extends StatefulWidget {
  final RecipeModel recipe;
  final RecipeRepository recipeRepository;
  final String? preloadedImageUrl;

  const _PromoRecipeCard({
    required this.recipe,
    required this.recipeRepository,
    this.preloadedImageUrl,
  });

  @override
  State<_PromoRecipeCard> createState() => _PromoRecipeCardState();
}

class _PromoRecipeCardState extends State<_PromoRecipeCard> {
  bool _isLiked = false;
  bool _isLikeLoaded = false;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _loadLikeState();
  }

  Future<void> _loadLikeState() async {
    try {
      final liked = await widget.recipeRepository.hasLiked(widget.recipe.id);

      if (!mounted) return;

      setState(() {
        _isLiked = liked;
        _isLikeLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLikeLoaded = true);
    }
  }

  Future<void> _toggleLike() async {
    if (_isToggling) return;

    setState(() {
      _isToggling = true;
      _isLiked = !_isLiked;
    });

    try {
      final liked = await widget.recipeRepository.toggleLike(widget.recipe.id);

      if (!mounted) return;
      setState(() => _isLiked = liked);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLiked = !_isLiked);
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recipe = widget.recipe;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RecipePublicViewPage(recipe: recipe),
          ),
        );
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  recipe.sourceType == 'video' &&
                          recipe.videoUrl != null &&
                          recipe.videoUrl!.isNotEmpty
                      ? RecipeVideoThumbnail(
                          videoPath: recipe.videoUrl!,
                          recipeRepository: widget.recipeRepository,
                        )
                      : Container(
                          color: colorScheme.surfaceContainerHighest,
                          child: widget.preloadedImageUrl != null
                              ? Image.network(
                                  widget.preloadedImageUrl!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stack) {
                                    return const Icon(Icons.restaurant);
                                  },
                                )
                              : Icon(
                                  Icons.restaurant,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                        ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: InkWell(
                      onTap: _isLikeLoaded ? _toggleLike : null,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.4),
                        ),
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 16,
                          color: _isLiked ? Colors.red : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recipe.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}