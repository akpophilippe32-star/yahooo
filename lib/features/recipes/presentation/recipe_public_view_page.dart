import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_drawer.dart';
import 'package:flutter/services.dart';
import '../../../models/recipe_model.dart';
import '../../../repositories/recipe_repository.dart';
import '../../../repositories/meal_plan_repository.dart';
import '../../../repositories/profile_repository.dart';
import '../../../widgets/recipe_video_player.dart';
import '../../auth/presentation/my_profile_view_page.dart';
import 'cooking_mode_page.dart';
import 'creator_profile_page.dart';

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
  final ProfileRepository _profileRepository = ProfileRepository();
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

  // Panneau de commentaires façon Instagram (vidéo réduite en haut
  // + liste de commentaires en dessous). La clé globale garantit
  // que c'est la MÊME lecture vidéo qui continue, pas une nouvelle
  // qui redémarre, quand on bascule entre plein écran et réduit.
  final GlobalKey _videoPlayerKey = GlobalKey();
  bool _showComments = false;
  bool _isVideoMuted = false;

  String? _authorName;
  String? _authorAvatarUrl;

  @override
  void initState() {
    super.initState();

    _detailsFuture = _recipeRepository.getRecipeDetails(widget.recipe.id);
    _commentsFuture = _recipeRepository.getComments(widget.recipe.id);

    _loadLikeState();
    _loadRatingState();
    _loadAuthorName();

    // S'assure que la barre de statut ET la barre de navigation
    // Android restent visibles (mode "edge to edge", comme
    // Instagram) plutôt qu'en immersion totale qui les cache. Ça
    // s'applique à l'écran entier (pas seulement au mode Reel), ce
    // qui ne change rien pour les recettes photo.
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }

  Future<void> _loadAuthorName() async {
    final authorId = widget.recipe.authorId;
    if (authorId == null) return;

    try {
      final profile = await _profileRepository.getProfileById(authorId);

      if (!mounted) return;

      final username = profile['username']?.toString();
      final fullName = profile['full_name']?.toString();
      final avatarPath = profile['avatar_url']?.toString();

      final avatarUrl = (avatarPath != null && avatarPath.trim().isNotEmpty)
          ? await _profileRepository.getAvatarUrl(avatarPath)
          : null;

      if (!mounted) return;

      setState(() {
        _authorName = (fullName != null && fullName.trim().isNotEmpty)
            ? fullName
            : (username != null && username.trim().isNotEmpty)
                ? '@$username'
                : null;
        _authorAvatarUrl = avatarUrl;
      });
    } catch (_) {
      // Reste sur le libellé par défaut ("Profil") en cas d'échec.
    }
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

  /// Formate la date d'un commentaire en "il y a X min/h/j/sem",
  /// façon Instagram.
  String _commentTimeAgo(Map<String, dynamic> comment) {
    final createdAtRaw = comment['created_at'];
    if (createdAtRaw == null) return '';

    final createdAt = DateTime.tryParse(createdAtRaw.toString());
    if (createdAt == null) return '';

    final diff = DateTime.now().difference(createdAt);

    if (diff.inMinutes < 1) return 'à l’instant';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min';
    if (diff.inHours < 24) return '${diff.inHours} h';
    if (diff.inDays < 7) return '${diff.inDays} j';
    return '${(diff.inDays / 7).floor()} sem';
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

  /// Chemin de stockage (pas encore une URL) de la photo de profil
  /// de l'auteur d'un commentaire — à résoudre via
  /// `_profileRepository.getAvatarUrl(...)` avant affichage.
  String? _commentAvatarPath(Map<String, dynamic> comment) {
    final profile = comment['profiles'];

    if (profile is Map<String, dynamic>) {
      final avatarUrl = profile['avatar_url'] as String?;
      if (avatarUrl != null && avatarUrl.trim().isNotEmpty) {
        return avatarUrl;
      }
    }

    return null;
  }

  /// Avatar d'un commentaire : résout et affiche la vraie photo de
  /// profil de son auteur (mise en cache côté ProfileRepository —
  /// donc quasi instantané après le tout premier affichage), avec
  /// une icône générique de repli si l'auteur n'a pas de photo.
  Widget _buildCommentAvatar(
    BuildContext context,
    Map<String, dynamic> comment, {
    double radius = 16,
  }) {
    final avatarPath = _commentAvatarPath(comment);

    if (avatarPath == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Icon(Icons.person, size: radius),
      );
    }

    return FutureBuilder<String?>(
      future: _profileRepository.getAvatarUrl(avatarPath),
      builder: (context, snapshot) {
        final url = snapshot.data;

        return CircleAvatar(
          radius: radius,
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          backgroundImage: url != null ? NetworkImage(url) : null,
          child: url == null ? Icon(Icons.person, size: radius) : null,
        );
      },
    );
  }

  /// Ouvre "Voir mon profil" si c'est ta propre recette, sinon le
  /// profil public du créateur — logique partagée entre l'avatar
  /// en bas à gauche et n'importe quel autre point d'entrée vers le
  /// profil sur cet écran.
  void _openAuthorProfile(RecipeModel recipe) {
    _openUserProfile(recipe.authorId);
  }

  /// Version générale : ouvre le profil de n'importe quel
  /// utilisateur par son id — un simple utilisateur qui a laissé un
  /// commentaire, tout autant qu'un créateur. Même logique que
  /// [_openAuthorProfile] : "Voir mon profil" si c'est toi-même,
  /// sinon le profil public de la personne concernée.
  void _openUserProfile(String? userId) {
    if (userId == null) return;

    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    final isSelf = currentUserId == userId;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => isSelf
            ? const MyProfileViewPage()
            : CreatorProfilePage(authorId: userId),
      ),
    );
  }

  void _toggleMute() {
    setState(() => _isVideoMuted = !_isVideoMuted);
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

    final isVideo = recipe.sourceType == 'video' &&
        recipe.videoUrl != null &&
        recipe.videoUrl!.isNotEmpty;

    if (isVideo) {
      return _buildReelLayout(context, recipe);
    }

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
  // MISE EN PAGE "REEL" (plein écran) — recettes vidéo uniquement
  // ============================================================

  Widget _buildReelLayout(BuildContext context, RecipeModel recipe) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: PopScope(
        // Retour en deux temps : si le panneau de commentaires est
        // ouvert, le bouton retour le referme d'abord (retour à la
        // vidéo plein écran) ; ce n'est qu'au deuxième appui, une
        // fois les commentaires déjà fermés, qu'on quitte vraiment
        // cet écran.
        canPop: !_showComments,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          setState(() => _showComments = false);
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          drawer: const AppDrawer(),
          // Sans ça, l'ouverture du clavier (champ de commentaire)
          // réduisait la hauteur disponible, ce qui faisait déborder
          // la colonne d'icônes (calée depuis le bas) vers le haut —
          // jusque dans la zone transparente de la barre de statut,
          // où le cœur "like" se retrouvait mélangé aux icônes
          // système (batterie, réseau...). La mise en page reste
          // maintenant fixe ; seul le champ de saisie du panneau de
          // commentaires gère lui-même sa remontée au-dessus du
          // clavier (voir _buildCommentsPanel).
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              _showComments
                  ? SizedBox(
                      height: 300,
                    child: _buildReelVideoStack(context, recipe),
                  )
                : Expanded(
                    child: _buildReelVideoStack(context, recipe),
                  ),
            if (_showComments) Expanded(child: _buildCommentsPanel(context)),
          ],
        ),
      ),
      ),
    );
  }

  /// La vidéo elle-même + ses superpositions (dégradés, icônes,
  /// texte). Les superpositions ne s'affichent qu'en plein écran —
  /// une fois réduite pour laisser place au panneau de
  /// commentaires, seule la vidéo (avec un bouton pour revenir)
  /// reste visible, comme dans la référence.
  Widget _buildReelVideoStack(BuildContext context, RecipeModel recipe) {
    final videoPlayer = RecipeVideoPlayer(
      key: _videoPlayerKey,
      videoPath: recipe.videoUrl!,
      fullscreenCover: true,
      muted: _isVideoMuted,
    );

    // ==========================================================
    // VIDÉO RÉDUITE (panneau de commentaires ouvert) : cadre
    // arrondi et centré sur fond noir, comme la référence
    // Instagram — pas plein cadre comme en mode normal.
    // ==========================================================
    if (_showComments) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 44),
            child: GestureDetector(
              onTap: () => setState(() => _showComments = false),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: AspectRatio(
                  aspectRatio: 9 / 14,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      videoPlayer,
                      Positioned(
                        right: 8,
                        bottom: 8,
                        child: _CircleIconButton(
                          icon: _isVideoMuted
                              ? Icons.volume_off
                              : Icons.volume_up,
                          onTap: _toggleMute,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ==========================================================
    // VIDÉO PLEIN ÉCRAN : un vrai en-tête (fond uni, pas de vidéo
    // derrière) au-dessus, la vidéo occupe le reste — comme la
    // référence, où le lecteur s'arrête avant le haut de l'écran
    // au lieu de remonter jusqu'à la barre de statut.
    // ==========================================================
    return Column(
      children: [
        Container(
          color: Colors.black,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 8,
            left: 8,
            right: 8,
            bottom: 8,
          ),
          child: Row(
            children: [
              _CircleIconButton(
                icon: Icons.arrow_back,
                onTap: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: 8),
              Builder(
                builder: (context) => _CircleIconButton(
                  icon: Icons.menu,
                  onTap: () => Scaffold.of(context).openDrawer(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              videoPlayer,

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 260,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.75),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // Colonne d'actions à droite (façon Reels).
              Positioned(
          right: 10,
          bottom: 110,
          child: Column(
            children: [
              _ReelAction(
                icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                iconColor: _isLiked ? Colors.red : Colors.white,
                label: '$_likeCount',
                onTap: _isLikeLoading ? null : _toggleLike,
              ),
              const SizedBox(height: 22),
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _commentsFuture,
                builder: (context, snapshot) {
                  final count = snapshot.data?.length ?? 0;

                  return _ReelAction(
                    icon: Icons.chat_bubble_outline,
                    label: '$count',
                    onTap: () => setState(() => _showComments = true),
                  );
                },
              ),
              const SizedBox(height: 22),
              _ReelAction(
                icon: Icons.shopping_basket_outlined,
                label: 'Ingrédients',
                onTap: _showIngredientsSheet,
              ),
              const SizedBox(height: 22),
              _ReelAction(
                icon: Icons.calendar_month_outlined,
                label: 'Planifier',
                onTap: _showAddToPlanSheet,
              ),
              const SizedBox(height: 22),
              _ReelAction(
                icon: Icons.soup_kitchen_outlined,
                label: 'Cuisiner',
                onTap: _openCookingMode,
              ),
              const SizedBox(height: 22),
              _ReelAction(
                icon: Icons.share_outlined,
                label: 'Partager',
                onTap: () => _showComingSoon('Le partage'),
              ),
            ],
          ),
        ),

        // Titre / auteur / description en bas à gauche.
        Positioned(
          left: 16,
          right: 90,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_authorName != null)
                InkWell(
                  onTap: () => _openAuthorProfile(recipe),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 13,
                        backgroundColor: Colors.white,
                        backgroundImage: _authorAvatarUrl != null
                            ? NetworkImage(_authorAvatarUrl!)
                            : null,
                        child: _authorAvatarUrl == null
                            ? Icon(
                                Icons.person,
                                size: 15,
                                color: Colors.black.withValues(alpha: 0.6),
                              )
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _authorName!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_isRatingLoading) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: _showRatingSheet,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _myRating != null ? Icons.star : Icons.star_border,
                        size: 14,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _ratingCount == 0
                            ? 'Pas encore noté — donne ton avis'
                            : '${_averageRating.toStringAsFixed(1)} '
                                '($_ratingCount avis)',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                recipe.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              if (recipe.description != null &&
                  recipe.description!.trim().isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  recipe.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                  ),
                ),
              ],
              ],
            ),
          ),
        ],
      ),
    ),
  ],
    );
  }

  // Emojis de réaction rapide, façon Instagram : un tap insère
  // l'emoji dans le champ de commentaire (pas besoin d'ouvrir le
  // clavier pour une réaction simple).
  static const List<String> _quickReactionEmojis = [
    '❤️',
    '🙌',
    '🔥',
    '👏',
    '😢',
    '😍',
    '😮',
    '😂',
  ];

  Widget _buildQuickReactionsRow() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickReactionEmojis.length,
        separatorBuilder: (context, index) => const SizedBox(width: 16),
        itemBuilder: (context, index) {
          final emoji = _quickReactionEmojis[index];

          return InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              _commentController.text += emoji;
              _commentController.selection = TextSelection.fromPosition(
                TextPosition(offset: _commentController.text.length),
              );
            },
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          );
        },
      ),
    );
  }

  /// Panneau de commentaires façon Instagram : liste des
  /// commentaires (avatar, nom, texte) + barre de réponse en bas.
  /// S'affiche pendant que la vidéo est réduite en haut de l'écran.
  Widget _buildCommentsPanel(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      // Comme le Scaffold ne redimensionne plus la page pour le
      // clavier (voir resizeToAvoidBottomInset ci-dessus), c'est ce
      // panneau lui-même qui remonte au-dessus du clavier quand il
      // apparaît — la vidéo réduite au-dessus, elle, ne bouge pas.
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outline,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () => _openUserProfile(
                              comment['user_id'] as String?,
                            ),
                            child: _buildCommentAvatar(context, comment),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    InkWell(
                                      onTap: () => _openUserProfile(
                                        comment['user_id'] as String?,
                                      ),
                                      child: Text(
                                        _commentAuthorName(comment),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      _commentTimeAgo(comment),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  comment['content']?.toString() ?? '',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          _buildQuickReactionsRow(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: 'Ajoutez un commentaire...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(
                            Radius.circular(24),
                          ),
                        ),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
          ),
        ],
      ),
    );
  }

  Future<void> _showIngredientsSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'Ingrédients',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(child: _buildIngredientsTab(context)),
              ],
            );
          },
        );
      },
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
        if (widget.recipe.authorId != null)
          _QuickAction(
            icon: Icons.person_outline,
            label: _authorName ?? 'Profil',
            avatarUrl: _authorAvatarUrl,
            onTap: () {
              final currentUserId =
                  Supabase.instance.client.auth.currentUser?.id;
              final isOwnRecipe = currentUserId == widget.recipe.authorId;

              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => isOwnRecipe
                      ? const MyProfileViewPage()
                      : CreatorProfilePage(
                          authorId: widget.recipe.authorId!,
                        ),
                ),
              );
            },
          ),
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
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () => _openUserProfile(
                            comment['user_id'] as String?,
                          ),
                          child: _buildCommentAvatar(context, comment),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: () => _openUserProfile(
                                  comment['user_id'] as String?,
                                ),
                                child: Text(
                                  _commentAuthorName(comment),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(comment['content']?.toString() ?? ''),
                            ],
                          ),
                        ),
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
// ACTION DE LA COLONNE REEL (icône ou avatar + libellé optionnel)
// ============================================================

class _ReelAction extends StatelessWidget {
  final IconData? icon;
  final Widget? child;
  final Color iconColor;
  final String? label;
  final VoidCallback? onTap;

  const _ReelAction({
    this.icon,
    this.child,
    this.label,
    this.onTap,
    this.iconColor = Colors.white,
  }) : assert(icon != null || child != null);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child ??
              Icon(icon, color: iconColor, size: 30, shadows: const [
                Shadow(color: Colors.black54, blurRadius: 6),
              ]),
          if (label != null) ...[
            const SizedBox(height: 4),
            Text(
              label!,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ],
        ],
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
  final String? avatarUrl;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.avatarUrl,
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
              backgroundImage:
                  avatarUrl != null ? NetworkImage(avatarUrl!) : null,
              child: avatarUrl == null
                  ? Icon(
                      icon,
                      size: 18,
                      color: colorScheme.onSurface,
                    )
                  : null,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 64,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11),
              ),
            ),
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