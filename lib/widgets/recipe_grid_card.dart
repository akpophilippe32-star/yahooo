import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import '../models/recipe_model.dart';
import '../repositories/recipe_repository.dart';
import '../features/recipes/presentation/recipe_public_view_page.dart';

/// Carte de recette réutilisable (grille 2 colonnes) : image ou
/// icône vidéo, titre en surimpression, cœur de like cliquable en
/// direct, compteur de likes + durée en dessous.
///
/// Utilisée sur l'accueil, la vue de profil et la recherche.
class RecipeGridCard extends StatefulWidget {
  final RecipeModel recipe;
  final RecipeRepository recipeRepository;

  const RecipeGridCard({
    super.key,
    required this.recipe,
    required this.recipeRepository,
  });

  @override
  State<RecipeGridCard> createState() => _RecipeGridCardState();
}

class _RecipeGridCardState extends State<RecipeGridCard> {
  bool _isLiked = false;
  int _likeCount = 0;
  bool _isLikeLoaded = false;
  bool _isToggling = false;

  @override
  void initState() {
    super.initState();
    _loadLikeState();
  }

  Future<void> _loadLikeState() async {
    try {
      final results = await Future.wait([
        widget.recipeRepository.hasLiked(widget.recipe.id),
        widget.recipeRepository.getLikeCount(widget.recipe.id),
      ]);

      if (!mounted) return;

      setState(() {
        _isLiked = results[0] as bool;
        _likeCount = results[1] as int;
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
      _likeCount += _isLiked ? 1 : -1;
    });

    try {
      await widget.recipeRepository.toggleLike(widget.recipe.id);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isLiked = !_isLiked;
        _likeCount += _isLiked ? 1 : -1;
      });
    } finally {
      if (mounted) setState(() => _isToggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.recipe;
    final totalTime = (recipe.prepTime ?? 0) + (recipe.cookTime ?? 0);

    return InkWell(
      borderRadius: BorderRadius.circular(14),
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
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FutureBuilder<String?>(
                    future: recipe.sourceType == 'video'
                        ? widget.recipeRepository
                            .getRecipeVideoUrl(recipe.videoUrl)
                        : widget.recipeRepository
                            .getRecipeImageUrl(recipe.imageUrl),
                    builder: (context, snapshot) {
                      final hasImage = recipe.sourceType != 'video' &&
                          snapshot.data != null;

                      return Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: hasImage
                            ? Image.network(
                                snapshot.data!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.restaurant);
                                },
                              )
                            : Icon(
                                recipe.sourceType == 'video'
                                    ? Icons.play_circle_outline
                                    : Icons.restaurant,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                      );
                    },
                  ),
                  Positioned(
                    left: 8,
                    right: 8,
                    bottom: 8,
                    child: Text(
                      recipe.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(blurRadius: 6, color: Colors.black87),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: InkWell(
                      onTap: _isLikeLoaded ? _toggleLike : null,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isLiked
                              ? AppTheme.accentDanger
                              : Colors.black.withValues(alpha: 0.35),
                        ),
                        child: Icon(
                          _isLiked ? Icons.favorite : Icons.favorite_border,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(
                Icons.favorite,
                size: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 3),
              Text(
                '$_likeCount',
                style: TextStyle(
                  fontSize: 10,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              if (totalTime > 0) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.access_time,
                  size: 11,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 3),
                Text(
                  '${totalTime}m',
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}