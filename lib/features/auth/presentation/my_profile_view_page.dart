import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/app_bar_leading.dart';
import 'avatar_cropper_page.dart';
import '../../../core/app_drawer.dart';
import '../../../models/recipe_model.dart';
import '../../../repositories/profile_repository.dart';
import '../../../repositories/recipe_repository.dart';
import '../data/auth_repository.dart';
import '../../recipes/presentation/recipe_public_view_page.dart';

const List<String> _kMonthNamesFr = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Vue de profil "publique" de l'utilisateur connecté — façon page
/// de profil d'un réseau social (bannière, avatar, infos, grille de
/// publications), adaptée à Mealora : bannière = couleur choisie à
/// l'inscription (pas une photo), onglets Images/Vidéos/Tous à la
/// place des icônes de contenu génériques.
class MyProfileViewPage extends StatefulWidget {
  const MyProfileViewPage({super.key});

  @override
  State<MyProfileViewPage> createState() => _MyProfileViewPageState();
}

enum _RecipeFilter { images, videos, all }

class _MyProfileViewPageState extends State<MyProfileViewPage> {
  final _profileRepository = ProfileRepository();
  final _recipeRepository = RecipeRepository();
  final _authRepository = AuthRepository();
  final _imagePicker = ImagePicker();

  late Future<Map<String, dynamic>> _profileFuture;
  late Future<List<RecipeModel>> _recipesFuture;

  bool _isUploadingAvatar = false;
  bool _isSubmittingApplication = false;
  String? _avatarPath;
  String _role = 'user';
  String? _creatorStatus;
  _RecipeFilter _filter = _RecipeFilter.all;

  @override
  void initState() {
    super.initState();
    _load();
  }

  bool get _isCreator => _role == 'creator' || _role == 'admin';

  void _load() {
    _profileFuture = _profileRepository.getMyProfile();
    _recipesFuture = _recipeRepository.getMyPublishedRecipes();

    // _role/_creatorStatus pilotent l'affichage (grille créateur vs
    // invitation à devenir créateur) en dehors du FutureBuilder de
    // l'en-tête : il faut donc bien un setState() ici, sinon la
    // page reste bloquée sur les valeurs par défaut une fois
    // chargée (bug précédent).
    _profileFuture.then((profile) {
      if (!mounted) return;

      setState(() {
        _avatarPath = profile['avatar_url'] as String?;
        _role = profile['role'] as String? ?? 'user';
        _creatorStatus = profile['creator_status'] as String?;
      });
    });
  }

  Future<void> _refresh() async {
    setState(_load);
    await Future.wait([_profileFuture, _recipesFuture]);
  }

  Future<void> _pickAvatar() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    final Uint8List originalBytes = await image.readAsBytes();

    if (!mounted) return;

    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (context) => AvatarCropperPage(imageBytes: originalBytes),
      ),
    );

    if (croppedBytes == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final path = await _profileRepository.uploadAvatar(
        bytes: croppedBytes,
        fileExtension: 'png',
      );

      await _profileRepository.updateIdentity(avatarUrl: path);

      if (!mounted) return;

      setState(() => _avatarPath = path);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de mettre à jour la photo : $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
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

  String? _formatBirthDate(Map<String, dynamic> profile) {
    final raw = profile['birth_date'] as String?;

    if (raw == null || raw.isEmpty) return null;

    final date = DateTime.tryParse(raw);
    if (date == null) return null;

    return 'Né(e) le ${date.day} ${_kMonthNamesFr[date.month - 1]} '
        '${date.year}';
  }

  String? _formatJoinedDate() {
    final createdAt = Supabase.instance.client.auth.currentUser?.createdAt;

    if (createdAt == null) return null;

    final date = DateTime.tryParse(createdAt);
    if (date == null) return null;

    return 'A rejoint Mealora en '
        '${_kMonthNamesFr[date.month - 1]} ${date.year}';
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — bientôt disponible.')),
    );
  }

  // ============================================================
  // DEMANDE DE STATUT CRÉATEUR (pour les comptes "user" simples)
  // ============================================================

  Future<void> _showBecomeCreatorSheet() async {
    String specialty = 'cuisine';
    final noteController = TextEditingController();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final isNutrition = specialty == 'nutrition';

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Devenir créateur',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Un administrateur examine chaque demande avant '
                    'de l’activer.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    children: [
                      ChoiceChip(
                        label: const Text('Cuisinier·ère'),
                        selected: specialty == 'cuisine',
                        onSelected: (_) {
                          setSheetState(() => specialty = 'cuisine');
                        },
                      ),
                      ChoiceChip(
                        label: const Text('Nutritionniste'),
                        selected: specialty == 'nutrition',
                        onSelected: (_) {
                          setSheetState(() => specialty = 'nutrition');
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: isNutrition
                          ? 'Expérience / qualifications'
                          : 'Expérience (facultatif)',
                      hintText: isNutrition
                          ? 'Ex. diététicien diplômé, 5 ans d’expérience...'
                          : null,
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isSubmittingApplication
                        ? null
                        : () async {
                            if (isNutrition &&
                                noteController.text.trim().isEmpty) {
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Ce champ aide l’admin à valider ta '
                                    'demande.',
                                  ),
                                ),
                              );
                              return;
                            }

                            setState(() => _isSubmittingApplication = true);

                            try {
                              await _authRepository.submitCreatorApplication(
                                specialty: specialty,
                                applicationNote:
                                    noteController.text.trim().isEmpty
                                        ? null
                                        : noteController.text.trim(),
                              );

                              if (!mounted) return;

                              await _refresh();

                              if (!sheetContext.mounted) return;
                              Navigator.of(sheetContext).pop();

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Demande envoyée ! En attente de '
                                    'validation par un administrateur.',
                                  ),
                                ),
                              );
                            } catch (error) {
                              if (!mounted) return;

                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Impossible d’envoyer la demande : '
                                    '$error',
                                  ),
                                ),
                              );
                            } finally {
                              if (mounted) {
                                setState(
                                  () => _isSubmittingApplication = false,
                                );
                              }
                            }
                          },
                    child: _isSubmittingApplication
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Envoyer ma demande'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _openCreateMenu() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(sheetContext).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.edit_note_outlined),
                title: const Text('Créer une recette'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pushNamed('/create-recipe');
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_call_outlined),
                title: const Text('Créer à partir d’une vidéo'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pushNamed('/create-video-recipe');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  List<RecipeModel> _applyFilter(List<RecipeModel> recipes) {
    switch (_filter) {
      case _RecipeFilter.images:
        return recipes.where((r) => r.sourceType != 'video').toList();
      case _RecipeFilter.videos:
        return recipes.where((r) => r.sourceType == 'video').toList();
      case _RecipeFilter.all:
        return recipes;
    }
  }

  // ============================================================
  // INVITATION À DEVENIR CRÉATEUR (comptes "user")
  // ============================================================

  Widget _buildBecomeCreatorPrompt(ColorScheme colorScheme) {
    final isPending = _creatorStatus == 'pending';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(
            isPending ? Icons.hourglass_top_outlined : Icons.storefront_outlined,
            size: 36,
            color: isPending ? colorScheme.secondary : colorScheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            isPending
                ? 'Ta demande est en cours d’examen'
                : 'Tu n’es pas encore créateur',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            isPending
                ? 'Un administrateur va bientôt valider ta demande. '
                    'Tu pourras alors publier tes recettes ici.'
                : 'Deviens créateur pour pouvoir créer et publier '
                    'tes propres recettes.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          if (!isPending) ...[
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _showBecomeCreatorSheet,
              icon: const Icon(Icons.add_business_outlined, size: 18),
              label: const Text('Devenir créateur'),
            ),
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
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            slivers: [
              // ====================================================
              // BANNIÈRE + BARRE D'ACTIONS EN SURIMPRESSION
              // ====================================================

              SliverToBoxAdapter(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _profileFuture,
                  builder: (context, snapshot) {
                    final accent = snapshot.hasData
                        ? _accentColor(snapshot.data!)
                        : colorScheme.primary;

                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          height: 120,
                          width: double.infinity,
                          color: accent,
                        ),
                        Positioned(
                          top: 4,
                          left: 4,
                          child: const AppBackMenuLeading(),
                        ),
                        Positioned(
                          top: 8,
                          right: 12,
                          child: Row(
                            children: [
                              _BannerIconButton(
                                icon: Icons.refresh,
                                onTap: _refresh,
                              ),
                              const SizedBox(width: 8),
                              _BannerIconButton(
                                icon: Icons.more_horiz,
                                onTap: () =>
                                    _showComingSoon('Plus d’options'),
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 20,
                          bottom: -40,
                          child: Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color:
                                      Theme.of(context).scaffoldBackgroundColor,
                                ),
                                child: FutureBuilder<String?>(
                                  future: _profileRepository
                                      .getAvatarUrl(_avatarPath),
                                  builder: (context, avatarSnapshot) {
                                    final url = avatarSnapshot.data;

                                    return CircleAvatar(
                                      radius: 40,
                                      backgroundColor:
                                          colorScheme.surfaceContainerHighest,
                                      backgroundImage: url != null
                                          ? NetworkImage(url)
                                          : null,
                                      child: url == null
                                          ? Icon(
                                              Icons.person,
                                              size: 36,
                                              color:
                                                  colorScheme.onSurfaceVariant,
                                            )
                                          : null,
                                    );
                                  },
                                ),
                              ),
                              Positioned(
                                right: 0,
                                bottom: 0,
                                child: InkWell(
                                  onTap: _isUploadingAvatar
                                      ? null
                                      : _pickAvatar,
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 26,
                                    height: 26,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: colorScheme.primary,
                                      border: Border.all(
                                        color: Theme.of(context)
                                            .scaffoldBackgroundColor,
                                        width: 2,
                                      ),
                                    ),
                                    child: _isUploadingAvatar
                                        ? const Padding(
                                            padding: EdgeInsets.all(5),
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Icon(
                                            Icons.camera_alt,
                                            size: 13,
                                            color: Colors.white,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              const SliverPadding(padding: EdgeInsets.only(top: 48)),

              // ====================================================
              // NOM, USERNAME, INFOS, BOUTONS
              // ====================================================

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _profileFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (snapshot.hasError || snapshot.data == null) {
                        return Text(
                          'Impossible de charger le profil : '
                          '${snapshot.error}',
                        );
                      }

                      final profile = snapshot.data!;
                      final fullName =
                          profile['full_name']?.toString() ?? '';
                      final username = profile['username']?.toString() ?? '';
                      final role = profile['role'] as String? ?? 'user';
                      final specialty = profile['specialty'] as String?;
                      final creatorStatus =
                          profile['creator_status'] as String?;
                      final birthLabel = _formatBirthDate(profile);
                      final joinedLabel = _formatJoinedDate();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
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
                                      style: TextStyle(
                                        color: colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (birthLabel != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.cake_outlined,
                                    size: 15,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    birthLabel,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (joinedLabel != null)
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_outlined,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  joinedLabel,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
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
                              if (creatorStatus == 'pending')
                                Chip(
                                  label: const Text('Demande en attente'),
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: colorScheme.secondary
                                      .withValues(alpha: 0.15),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          FutureBuilder<List<RecipeModel>>(
                            future: _recipesFuture,
                            builder: (context, recipeSnapshot) {
                              final count = recipeSnapshot.data?.length ?? 0;

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
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _showComingSoon(
                                    'Le partage du profil',
                                  ),
                                  child: const Text('Partager'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () async {
                                    final updated = await Navigator.of(
                                      context,
                                    ).pushNamed('/edit-profile');
                                    if (updated == true) {
                                      _refresh();
                                    }
                                  },
                                  child: const Text('Éditer le profil'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),

              // ====================================================
              // ONGLETS : IMAGES / VIDÉOS / TOUS (créateurs)
              // OU INVITATION À DEVENIR CRÉATEUR (comptes "user")
              // ====================================================

              if (_isCreator) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Row(
                      children: [
                        _FilterTab(
                          label: 'Images',
                          icon: Icons.image_outlined,
                          isActive: _filter == _RecipeFilter.images,
                          onTap: () =>
                              setState(() => _filter = _RecipeFilter.images),
                        ),
                        _FilterTab(
                          label: 'Vidéos',
                          icon: Icons.videocam_outlined,
                          isActive: _filter == _RecipeFilter.videos,
                          onTap: () =>
                              setState(() => _filter = _RecipeFilter.videos),
                        ),
                        _FilterTab(
                          label: 'Tous',
                          icon: Icons.grid_view_outlined,
                          isActive: _filter == _RecipeFilter.all,
                          onTap: () =>
                              setState(() => _filter = _RecipeFilter.all),
                        ),
                      ],
                    ),
                  ),
                ),

                const SliverPadding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(child: Divider(height: 1)),
                ),

                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: FutureBuilder<List<RecipeModel>>(
                    future: _recipesFuture,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
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

                      final recipes = _applyFilter(snapshot.data ?? []);

                      if (recipes.isEmpty) {
                        return SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 30),
                            child: Center(
                              child: Text(
                                'Aucune recette ici pour l’instant.',
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
                            return _ProfileRecipeCard(
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
              ] else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  sliver: SliverToBoxAdapter(
                    child: _buildBecomeCreatorPrompt(colorScheme),
                  ),
                ),

              const SliverPadding(padding: EdgeInsets.only(bottom: 90)),
            ],
          ),
        ),
      ),
      floatingActionButton: _isCreator
          ? FloatingActionButton(
              onPressed: _openCreateMenu,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ============================================================
// BOUTON CIRCULAIRE SUR LA BANNIÈRE
// ============================================================

class _BannerIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _BannerIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.3),
        ),
        child: Icon(icon, size: 17, color: Colors.white),
      ),
    );
  }
}

// ============================================================
// ONGLET DE FILTRE (Images / Vidéos / Tous)
// ============================================================

class _FilterTab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color:
                    isActive ? colorScheme.primary : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// CARTE RECETTE DE LA GRILLE DE PROFIL
// ============================================================

class _ProfileRecipeCard extends StatelessWidget {
  final RecipeModel recipe;
  final RecipeRepository recipeRepository;

  const _ProfileRecipeCard({
    required this.recipe,
    required this.recipeRepository,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
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
          if (totalTime > 0)
            Text(
              '$totalTime min',
              style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}