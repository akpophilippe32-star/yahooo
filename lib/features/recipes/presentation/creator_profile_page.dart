import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_bar_leading.dart';
import '../../../core/app_drawer.dart';
import '../../../models/recipe_model.dart';
import '../../../repositories/profile_repository.dart';
import '../../../repositories/recipe_repository.dart';
import '../../../widgets/full_screen_image_viewer.dart';
import 'recipe_public_view_page.dart';

/// Profil public d'un créateur, consulté par n'importe quel visiteur
/// (contrairement à "Voir mon profil", en lecture seule — pas de
/// modification d'avatar, pas de bouton "Modifier").
class CreatorProfilePage extends StatefulWidget {
  final String authorId;

  const CreatorProfilePage({super.key, required this.authorId});

  @override
  State<CreatorProfilePage> createState() => _CreatorProfilePageState();
}

class _CreatorProfilePageState extends State<CreatorProfilePage> {
  final _profileRepository = ProfileRepository();
  final _recipeRepository = RecipeRepository();

  late Future<Map<String, dynamic>> _profileFuture;
  late Future<List<RecipeModel>> _recipesFuture;

  bool _isFollowing = false;
  int _followerCount = 0;
  bool _isFollowLoading = true;
  bool _isTogglingFollow = false;

  // ============================================================
  // NOTATION DU PROFIL CRÉATEUR
  // ============================================================
  // N'est activée que si le créateur a complété sa candidature avec
  // un document justificatif (creator_document_path non nul) — voir
  // rate_creator() côté base de données, qui applique la même règle.
  bool _canBeRated = false;
  bool _isRatingLoading = false;
  bool _isSubmittingRating = false;
  double _ratingAverage = 0;
  int _ratingCount = 0;
  int? _myRating;

  @override
  void initState() {
    super.initState();
    _profileFuture = _profileRepository.getProfileById(widget.authorId);
    _recipesFuture =
        _recipeRepository.getPublishedRecipesByAuthor(widget.authorId);
    _loadFollowState();

    _profileFuture.then((profile) {
      if (!mounted) return;

      final role = profile['role'] as String? ?? 'user';
      final documentPath = profile['creator_document_path'] as String?;
      final canBeRated =
          role == 'creator' && documentPath != null && documentPath.isNotEmpty;

      setState(() => _canBeRated = canBeRated);

      if (canBeRated) {
        _loadRatingState();
      }
    });
  }

  Future<void> _loadFollowState() async {
    try {
      final results = await Future.wait([
        _profileRepository.isFollowing(widget.authorId),
        _profileRepository.getFollowerCount(widget.authorId),
      ]);

      if (!mounted) return;

      setState(() {
        _isFollowing = results[0] as bool;
        _followerCount = results[1] as int;
        _isFollowLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isFollowLoading = false);
    }
  }

  Future<void> _loadRatingState() async {
    setState(() => _isRatingLoading = true);

    try {
      final summary =
          await _profileRepository.getCreatorRatingSummary(widget.authorId);
      final myRating =
          await _profileRepository.getMyRatingForCreator(widget.authorId);

      if (!mounted) return;

      setState(() {
        _ratingAverage = summary.average;
        _ratingCount = summary.count;
        _myRating = myRating;
        _isRatingLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isRatingLoading = false);
    }
  }

  Future<void> _submitRating(int rating) async {
    if (_isSubmittingRating) return;

    final previousRating = _myRating;

    setState(() {
      _isSubmittingRating = true;
      _myRating = rating;
    });

    try {
      await _profileRepository.rateCreator(
        creatorId: widget.authorId,
        rating: rating,
      );

      await _loadRatingState();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Merci pour ta note !')),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _myRating = previousRating);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’enregistrer la note : $error')),
      );
    } finally {
      if (mounted) setState(() => _isSubmittingRating = false);
    }
  }

  Future<void> _toggleFollow() async {
    if (_isTogglingFollow) return;

    setState(() {
      _isTogglingFollow = true;
      _isFollowing = !_isFollowing;
      _followerCount += _isFollowing ? 1 : -1;
    });

    try {
      final following =
          await _profileRepository.toggleFollow(widget.authorId);

      if (!mounted) return;

      if (following != _isFollowing) {
        setState(() {
          _isFollowing = following;
          _followerCount += following ? 1 : -1;
        });
      }
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isFollowing = !_isFollowing;
        _followerCount += _isFollowing ? 1 : -1;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de s’abonner : $error')),
      );
    } finally {
      if (mounted) setState(() => _isTogglingFollow = false);
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'creator':
        return 'Créateur';
      case 'admin':
        return 'Administrateur';
      default:
        return 'Utilisateur';
    }
  }

  String _specialtyLabel(String specialty) {
    switch (specialty) {
      case 'cuisine':
        return 'Cuisinier·ère';
      case 'nutrition':
        return 'Nutritionniste';
      default:
        return specialty;
    }
  }

  Color _accentColor(Map<String, dynamic> profile) {
    final hex = profile['accent_color'] as String?;

    if (hex != null && hex.isNotEmpty) {
      try {
        final value =
            int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000;
        return Color(value);
      } catch (_) {}
    }

    return const Color(0xFFE8703C);
  }

  // ============================================================
  // ÉTOILES (affichage moyenne + saisie de la note)
  // ============================================================

  Widget _buildStaticStars(double average, ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final threshold = index + 1;
        final IconData icon;

        if (average >= threshold) {
          icon = Icons.star;
        } else if (average >= threshold - 0.5) {
          icon = Icons.star_half;
        } else {
          icon = Icons.star_border;
        }

        return Icon(icon, size: 16, color: colorScheme.primary);
      }),
    );
  }

  Widget _buildInteractiveStars(ColorScheme colorScheme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;
        final isFilled = _myRating != null && starValue <= _myRating!;

        return IconButton(
          onPressed:
              _isSubmittingRating ? null : () => _submitRating(starValue),
          icon: Icon(
            isFilled ? Icons.star : Icons.star_border,
            color: colorScheme.primary,
          ),
          splashRadius: 18,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        );
      }),
    );
  }

  Widget _buildRatingSection(ColorScheme colorScheme) {
    final isSelf =
        widget.authorId == Supabase.instance.client.auth.currentUser?.id;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildStaticStars(_ratingAverage, colorScheme),
              const SizedBox(width: 8),
              Text(
                _isRatingLoading
                    ? 'Chargement...'
                    : _ratingCount == 0
                        ? 'Pas encore d’avis'
                        : '${_ratingAverage.toStringAsFixed(1)} '
                            '($_ratingCount avis)',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          if (!isSelf) ...[
            const SizedBox(height: 10),
            Text(
              'TA NOTE',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            _buildInteractiveStars(colorScheme),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ====================================================
            // BANNIÈRE (couleur du créateur) + AVATAR
            // ====================================================

            SliverToBoxAdapter(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _profileFuture,
                builder: (context, snapshot) {
                  final accent = snapshot.hasData
                      ? _accentColor(snapshot.data!)
                      : colorScheme.primary;

                  final avatarPath =
                      snapshot.data?['avatar_url'] as String?;

                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 110,
                        width: double.infinity,
                        color: accent,
                      ),
                      const Positioned(
                        top: 4,
                        left: 4,
                        child: AppBackMenuLeading(),
                      ),
                      Positioned(
                        left: 20,
                        bottom: -36,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Theme.of(context).scaffoldBackgroundColor,
                          ),
                          child: FutureBuilder<String?>(
                            future:
                                _profileRepository.getAvatarUrl(avatarPath),
                            builder: (context, avatarSnapshot) {
                              final url = avatarSnapshot.data;

                              return GestureDetector(
                                onTap: url == null
                                    ? null
                                    : () {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (context) =>
                                                FullScreenImageViewer(
                                              imageUrl: url,
                                            ),
                                          ),
                                        );
                                      },
                                child: CircleAvatar(
                                  radius: 36,
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                  backgroundImage:
                                      url != null ? NetworkImage(url) : null,
                                  child: url == null
                                      ? Icon(
                                          Icons.person,
                                          size: 32,
                                          color: colorScheme.onSurfaceVariant,
                                        )
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 44)),

            // ====================================================
            // NOM, USERNAME, BADGES
            // ====================================================

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              sliver: SliverToBoxAdapter(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _profileFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }

                    if (snapshot.hasError || snapshot.data == null) {
                      return Text(
                        'Impossible de charger ce profil : '
                        '${snapshot.error}',
                      );
                    }

                    final profile = snapshot.data!;
                    final fullName = profile['full_name']?.toString() ?? '';
                    final username = profile['username']?.toString() ?? '';
                    final role = profile['role'] as String? ?? 'user';
                    final specialty = profile['specialty'] as String?;
                    final bio = profile['bio']?.toString();
                    final documentPath =
                        profile['creator_document_path'] as String?;
                    final isVerified = role == 'creator' &&
                        documentPath != null &&
                        documentPath.isNotEmpty;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fullName.isEmpty ? 'Sans nom' : fullName,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '@$username',
                          style:
                              TextStyle(color: colorScheme.onSurfaceVariant),
                        ),
                        if (bio != null && bio.trim().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(bio),
                        ],
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          children: [
                            Chip(
                              label: Text(_roleLabel(role)),
                              visualDensity: VisualDensity.compact,
                            ),
                            if (specialty != null)
                              Chip(
                                label: Text(_specialtyLabel(specialty)),
                                visualDensity: VisualDensity.compact,
                              ),
                            if (isVerified)
                              Chip(
                                avatar: Icon(
                                  Icons.verified,
                                  size: 16,
                                  color: colorScheme.primary,
                                ),
                                label: const Text('Vérifié'),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: colorScheme.primary
                                    .withValues(alpha: 0.12),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            FutureBuilder<List<RecipeModel>>(
                              future: _recipesFuture,
                              builder: (context, recipeSnapshot) {
                                final count =
                                    recipeSnapshot.data?.length ?? 0;

                                return Text(
                                  count <= 1
                                      ? '$count recette publiée'
                                      : '$count recettes publiées',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                );
                              },
                            ),
                            const Text(
                              '  ·  ',
                              style: TextStyle(fontSize: 12),
                            ),
                            Text(
                              _followerCount <= 1
                                  ? '$_followerCount abonné'
                                  : '$_followerCount abonnés',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        if (widget.authorId !=
                            Supabase.instance.client.auth.currentUser?.id)
                          SizedBox(
                            width: double.infinity,
                            child: _isFollowing
                                ? OutlinedButton.icon(
                                    onPressed: _isFollowLoading
                                        ? null
                                        : _toggleFollow,
                                    icon: const Icon(Icons.check, size: 16),
                                    label: const Text('Abonné'),
                                  )
                                : FilledButton.icon(
                                    onPressed: _isFollowLoading
                                        ? null
                                        : _toggleFollow,
                                    icon: const Icon(
                                      Icons.person_add_alt_1,
                                      size: 16,
                                    ),
                                    label: const Text('Suivre'),
                                  ),
                          ),
                        if (_canBeRated) ...[
                          const SizedBox(height: 14),
                          _buildRatingSection(colorScheme),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(top: 20)),

            const SliverPadding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(child: Divider(height: 1)),
            ),

            // ====================================================
            // GRILLE DES RECETTES PUBLIÉES
            // ====================================================

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
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
                        child: Text(
                          'Impossible de charger les recettes : '
                          '${snapshot.error}',
                        ),
                      ),
                    );
                  }

                  final recipes = snapshot.data ?? [];

                  if (recipes.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Center(
                          child: Text(
                            'Aucune recette publiée pour l’instant.',
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  return SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                    ),
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return _CreatorRecipeCard(
                          recipe: recipes[index],
                          recipeRepository: _recipeRepository,
                        );
                      },
                      childCount: recipes.length,
                    ),
                  );
                },
              ),
            ),

            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      ),
    );
  }
}

class _CreatorRecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final RecipeRepository recipeRepository;

  const _CreatorRecipeCard({
    required this.recipe,
    required this.recipeRepository,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
              child: recipe.sourceType == 'video'
                  ? Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.play_circle_outline,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    )
                  : FutureBuilder<String?>(
                      future:
                          recipeRepository.getRecipeImageUrl(recipe.imageUrl),
                      builder: (context, snapshot) {
                        final url = snapshot.data;

                        return Container(
                          color: colorScheme.surfaceContainerHighest,
                          width: double.infinity,
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
          const SizedBox(height: 6),
          Text(
            recipe.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}