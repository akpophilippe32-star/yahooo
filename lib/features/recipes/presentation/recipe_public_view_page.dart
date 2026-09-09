import 'package:flutter/material.dart';

import '../../../core/app_drawer.dart';
import '../../../models/recipe_model.dart';
import '../../../repositories/recipe_repository.dart';
import '../../../repositories/meal_plan_repository.dart';
import '../../../widgets/recipe_video_player.dart';
import 'cooking_mode_page.dart';

/// Écran de vue publique d'une recette publiée : photo/vidéo en
/// tête avec like, actions rapides (planifier / cuisiner / courses),
/// nutrition de base, et navigation par onglets **en bas** de
/// l'écran (Aperçu / Ingrédients / Commentaires) — les étapes de
/// préparation vivent désormais dans le mode cuisine dédié
/// (avec lecture audio), accessible via "Cuisiner".
class RecipePublicViewPage extends StatefulWidget {
  final RecipeModel recipe;

  const RecipePublicViewPage({
    super.key,
    required this.recipe,
  });

  @override
  State<RecipePublicViewPage> createState() => _RecipePublicViewPageState();
}

class _RecipePublicViewPageState extends State<RecipePublicViewPage> {
  final RecipeRepository _recipeRepository = RecipeRepository();
  final MealPlanRepository _mealPlanRepository = MealPlanRepository();

  late Future<Map<String, dynamic>> _detailsFuture;
  late Future<List<Map<String, dynamic>>> _commentsFuture;

  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLikeLoading = true;
  bool _isTogglingLike = false;

  double _averageRating = 0;
  int _ratingCount = 0;
  int? _myRating;
  bool _isRatingLoading = true;

  final TextEditingController _commentController = TextEditingController();
  bool _isSubmittingComment = false;

  @override
  void initState() {
    super.initState();

    _detailsFuture = _recipeRepository.getRecipeDetails(widget.recipe.id);
    _commentsFuture = _recipeRepository.getComments(widget.recipe.id);

    _loadLikeState();
    _loadRatingState();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  // ============================================================
  // LIKES
  // ============================================================

  Future<void> _loadLikeState() async {
    try {
      final results = await Future.wait([
        _recipeRepository.hasLiked(widget.recipe.id),
        _recipeRepository.getLikeCount(widget.recipe.id),
      ]);

      if (!mounted) return;

      setState(() {
        _isLiked = results[0] as bool;
        _likeCount = results[1] as int;
        _isLikeLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLikeLoading = false);
    }
  }

  Future<void> _toggleLike() async {
    if (_isTogglingLike) return;

    setState(() {
      _isTogglingLike = true;
      _isLiked = !_isLiked;
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      final liked = await _recipeRepository.toggleLike(widget.recipe.id);

      if (!mounted) return;

      setState(() {
        if (liked != _isLiked) {
          _isLiked = liked;
          _likeCount += liked ? 1 : -1;
        }
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de mettre à jour le like : $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isTogglingLike = false);
    }
  }

  // ============================================================
  // NOTATION EN ÉTOILES (accessible via la moyenne sous le titre)
  // ============================================================

  Future<void> _loadRatingState() async {
    try {
      final results = await Future.wait([
        _recipeRepository.getRatingSummary(widget.recipe.id),
        _recipeRepository.getMyRating(widget.recipe.id),
      ]);

      if (!mounted) return;

      final summary = results[0] as ({double average, int count});

      setState(() {
        _averageRating = summary.average;
        _ratingCount = summary.count;
        _myRating = results[1] as int?;
        _isRatingLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRatingLoading = false);
    }
  }

  Future<void> _showRatingSheet() async {
    int selected = _myRating ?? 0;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Ta note pour cette recette',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (index) {
                      final starValue = index + 1;

                      return IconButton(
                        iconSize: 34,
                        onPressed: () async {
                          setSheetState(() => selected = starValue);

                          try {
                            await _recipeRepository.rateRecipe(
                              widget.recipe.id,
                              starValue,
                            );

                            if (!mounted) return;

                            setState(() => _myRating = starValue);
                            await _loadRatingState();

                            if (!sheetContext.mounted) return;
                            Navigator.of(sheetContext).pop();
                          } catch (error) {
                            if (!sheetContext.mounted) return;
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Impossible d’enregistrer la note : $error',
                                ),
                              ),
                            );
                          }
                        },
                        icon: Icon(
                          starValue <= selected
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.amber,
                        ),
                      );
                    }),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // MODE CUISINE
  // ============================================================

  void _openCookingMode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CookingModePage(recipe: widget.recipe),
      ),
    );
  }

  // ============================================================
  // AJOUTER AU PLANNING DES REPAS
  // ============================================================

  Future<void> _showAddToPlanSheet() async {
    final today = DateTime.now();
    final days = List.generate(
      7,
      (index) => DateTime(today.year, today.month, today.day)
          .add(Duration(days: index)),
    );

    DateTime selectedDay = days.first;
    String selectedMealType = MealPlanRepository.mealTypes.first;
    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final colorScheme = Theme.of(sheetContext).colorScheme;

            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Ajouter au planning',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 64,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        final day = days[index];
                        final isSelected = day.day == selectedDay.day &&
                            day.month == selectedDay.month;

                        const weekdayLabels = [
                          'L',
                          'M',
                          'M',
                          'J',
                          'V',
                          'S',
                          'D',
                        ];

                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              setSheetState(() => selectedDay = day);
                            },
                            child: Container(
                              width: 44,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colorScheme.primary
                                    : colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    weekdayLabels[day.weekday - 1],
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isSelected
                                          ? Colors.white
                                          : colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${day.day}',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: isSelected
                                          ? Colors.white
                                          : colorScheme.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 8,
                    children: MealPlanRepository.mealTypes.map((mealType) {
                      final isSelected = mealType == selectedMealType;

                      return ChoiceChip(
                        label: Text(MealPlanRepository.mealTypeLabel(mealType)),
                        selected: isSelected,
                        onSelected: (_) {
                          setSheetState(() => selectedMealType = mealType);
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: isSaving
                        ? null
                        : () async {
                            setSheetState(() => isSaving = true);

                            try {
                              await _mealPlanRepository.setMealPlanEntry(
                                date: selectedDay,
                                mealType: selectedMealType,
                                recipeId: widget.recipe.id,
                              );

                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();

                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Ajouté au planning.'),
                                ),
                              );
                            } catch (error) {
                              setSheetState(() => isSaving = false);

                              if (!sheetContext.mounted) return;
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Impossible d’ajouter au planning : $error',
                                  ),
                                ),
                              );
                            }
                          },
                    child: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Ajouter'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // COMMENTAIRES
  // ============================================================

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();

    if (content.isEmpty) return;

    setState(() => _isSubmittingComment = true);

    try {
      await _recipeRepository.addComment(
        recipeId: widget.recipe.id,
        content: content,
      );

      _commentController.clear();

      if (!mounted) return;

      setState(() {
        _commentsFuture = _recipeRepository.getComments(widget.recipe.id);
      });
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible d’ajouter le commentaire : $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  String _commentAuthorName(Map<String, dynamic> comment) {
    final profile = comment['profiles'];

    if (profile is Map<String, dynamic>) {
      final username = profile['username'] as String?;
      final fullName = profile['full_name'] as String?;

      if (fullName != null && fullName.trim().isNotEmpty) {
        return fullName;
      }

      if (username != null && username.trim().isNotEmpty) {
        return username;
      }
    }

    return 'Utilisateur';
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — bientôt disponible.')),
    );
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        drawer: const AppDrawer(),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // ====================================================
              // PHOTO / VIDÉO + BOUTONS EN SURIMPRESSION
              // ====================================================

              _buildMedia(context, recipe),

              // ====================================================
              // TITRE + NOTE (tapable) + ACTIONS RAPIDES
              // ====================================================

              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      recipe.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _isRatingLoading
                        ? const SizedBox.shrink()
                        : InkWell(
                            onTap: _showRatingSheet,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _myRating != null
                                      ? Icons.star
                                      : Icons.star_border,
                                  size: 16,
                                  color: Colors.amber,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _ratingCount == 0
                                      ? 'Pas encore noté — donne ton avis'
                                      : '${_averageRating.toStringAsFixed(1)} '
                                          '($_ratingCount avis)',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  Icons.favorite,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '$_likeCount',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                    const SizedBox(height: 16),
                    _buildQuickActions(context),
                  ],
                ),
              ),

              // ====================================================
              // CONTENU DES ONGLETS
              // ====================================================

              Expanded(
                child: TabBarView(
                  children: [
                    _buildAboutTab(context, recipe),
                    _buildIngredientsTab(context),
                    _buildCommentsTab(context),
                  ],
                ),
              ),
            ],
          ),
        ),

        // ======================================================
        // NAVIGATION PAR ONGLETS EN BAS DE L'ÉCRAN
        // ======================================================

        bottomNavigationBar: SafeArea(
          top: false,
          child: Builder(
            builder: (context) {
              final tabController = DefaultTabController.of(context);

              return AnimatedBuilder(
                animation: tabController,
                builder: (context, _) {
                  return Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).scaffoldBackgroundColor,
                      border: Border(
                        top: BorderSide(color: colorScheme.outline),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 10,
                      horizontal: 12,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _RecipeNavPill(
                          icon: Icons.info_outline,
                          label: 'À propos',
                          isActive: tabController.index == 0,
                          onTap: () => tabController.animateTo(0),
                        ),
                        _RecipeNavPill(
                          icon: Icons.shopping_basket_outlined,
                          label: 'Ingrédients',
                          isActive: tabController.index == 1,
                          onTap: () => tabController.animateTo(1),
                        ),
                        _RecipeNavPill(
                          icon: Icons.forum_outlined,
                          label: 'Commentaires',
                          isActive: tabController.index == 2,
                          onTap: () => tabController.animateTo(2),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // MÉDIA (photo ou vidéo) + BOUTONS EN SURIMPRESSION
  // ============================================================

  Widget _buildMedia(BuildContext context, RecipeModel recipe) {
    final hasVideo = recipe.sourceType == 'video' &&
        recipe.videoUrl != null &&
        recipe.videoUrl!.isNotEmpty;

    return SizedBox(
      height: 220,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasVideo)
            RecipeVideoPlayer(videoPath: recipe.videoUrl!)
          else if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
            FutureBuilder<String?>(
              future: _recipeRepository.getRecipeImageUrl(recipe.imageUrl),
              builder: (context, snapshot) {
                final imageUrl = snapshot.data;

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (imageUrl == null) {
                  return const SizedBox.shrink();
                }

                return Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                );
              },
            ),
          Positioned(
            top: 8,
            left: 8,
            child: _CircleIconButton(
              icon: Icons.arrow_back,
              onTap: () => Navigator.of(context).pop(),
            ),
          ),
          Positioned(
            top: 8,
            left: 52,
            child: Builder(
              builder: (context) => _CircleIconButton(
                icon: Icons.menu,
                onTap: () => Scaffold.of(context).openDrawer(),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: _CircleIconButton(
              icon: Icons.share_outlined,
              onTap: () => _showComingSoon('Le partage'),
            ),
          ),
          Positioned(
            bottom: 8,
            right: 8,
            child: _CircleIconButton(
              icon: _isLiked ? Icons.favorite : Icons.favorite_border,
              iconColor: _isLiked ? Colors.red : Colors.white,
              onTap: _isLikeLoading ? null : _toggleLike,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ACTIONS RAPIDES (Planifier / Cuisiner / Courses)
  // ============================================================

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _QuickAction(
          icon: Icons.calendar_month_outlined,
          label: 'Planifier',
          onTap: _showAddToPlanSheet,
        ),
        _QuickAction(
          icon: Icons.soup_kitchen_outlined,
          label: 'Cuisiner',
          onTap: _openCookingMode,
        ),
        _QuickAction(
          icon: Icons.shopping_bag_outlined,
          label: 'Courses',
          onTap: () => _showComingSoon('La liste de courses'),
        ),
      ],
    );
  }

  // ============================================================
  // ONGLET — APERÇU
  // ============================================================

  Widget _buildAboutTab(BuildContext context, RecipeModel recipe) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            if (recipe.prepTime != null)
              _InfoPill(
                icon: Icons.timer_outlined,
                label: 'Préparation : ${recipe.prepTime} min',
              ),
            if (recipe.cookTime != null)
              _InfoPill(
                icon: Icons.local_fire_department_outlined,
                label: 'Cuisson : ${recipe.cookTime} min',
              ),
            if (recipe.servings != null)
              _InfoPill(
                icon: Icons.restaurant_outlined,
                label: '${recipe.servings} portions',
              ),
          ],
        ),

        if (recipe.description != null &&
            recipe.description!.trim().isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(recipe.description!),
        ],

        if (recipe.caloriesKcal != null ||
            recipe.carbsG != null ||
            recipe.fatG != null ||
            recipe.proteinG != null) ...[
          const SizedBox(height: 24),
          _buildNutritionCard(context, recipe),
        ],
      ],
    );
  }

  Widget _buildNutritionCard(BuildContext context, RecipeModel recipe) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          if (recipe.caloriesKcal != null) ...[
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: 1,
                    strokeWidth: 5,
                    color: colorScheme.primary,
                    backgroundColor: colorScheme.outline,
                  ),
                  Text(
                    '${recipe.caloriesKcal}',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recipe.caloriesKcal != null)
                  Text(
                    '${recipe.caloriesKcal} kcal',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                if (recipe.carbsG != null)
                  Text('Glucides : ${recipe.carbsG!.toStringAsFixed(0)} g'),
                if (recipe.fatG != null)
                  Text('Lipides : ${recipe.fatG!.toStringAsFixed(0)} g'),
                if (recipe.proteinG != null)
                  Text('Protéines : ${recipe.proteinG!.toStringAsFixed(0)} g'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ONGLET — INGRÉDIENTS
  // ============================================================

  Widget _buildIngredientsTab(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: _detailsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Center(
            child: Text('Impossible de charger : ${snapshot.error}'),
          );
        }

        final ingredients = (snapshot.data!['ingredients'] as List)
            .cast<Map<String, dynamic>>();

        if (ingredients.isEmpty) {
          return const Center(
            child: Text('Aucun ingrédient renseigné pour cette recette.'),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: ingredients.length,
          itemBuilder: (context, index) {
            final item = ingredients[index];
            final ingredient = item['ingredients'];

            final name = ingredient is Map<String, dynamic>
                ? ingredient['name']?.toString() ?? 'Ingrédient'
                : 'Ingrédient';

            final quantity = item['quantity']?.toString() ?? '';
            final unit = item['unit']?.toString() ?? '';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '• $name'
                '${quantity.isNotEmpty ? ' — $quantity' : ''}'
                '${unit.isNotEmpty ? ' $unit' : ''}',
              ),
            );
          },
        );
      },
    );
  }

  // ============================================================
  // ONGLET — COMMENTAIRES
  // ============================================================

  Widget _buildCommentsTab(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _commentsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Impossible de charger les commentaires : '
                    '${snapshot.error}',
                  ),
                );
              }

              final comments = (snapshot.data ?? [])
                  .where((comment) => comment['is_hidden'] != true)
                  .toList();

              if (comments.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Aucun commentaire pour l’instant. '
                      'Sois le premier à en laisser un !',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _commentAuthorName(comment),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(comment['content']?.toString() ?? ''),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'Écrire un commentaire...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: _isSubmittingComment ? null : _submitComment,
                icon: _isSubmittingComment
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// BOUTON CIRCULAIRE SUR LA PHOTO
// ============================================================

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final VoidCallback? onTap;

  const _CircleIconButton({
    required this.icon,
    required this.onTap,
    this.iconColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.4),
        ),
        child: Icon(icon, size: 18, color: iconColor),
      ),
    );
  }
}

// ============================================================
// ACTION RAPIDE (Planifier / Cuisiner / Courses)
// ============================================================

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Icon(
                icon,
                size: 18,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PASTILLE DE NAVIGATION (À propos / Ingrédients / Commentaires)
// ============================================================

class _RecipeNavPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _RecipeNavPill({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: isActive
              ? colorScheme.primary.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                color:
                    isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PASTILLE D'INFORMATION (temps, portions...)
// ============================================================

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoPill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}