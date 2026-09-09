import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/theme_controller.dart';
import '../features/auth/data/auth_repository.dart';
import '../repositories/profile_repository.dart';

/// Menu latéral (hamburger) réutilisable sur **toutes** les pages
/// de l'app — pas seulement les 4 onglets principaux.
///
/// Style repris de X : en-tête avec photo/nom réels, liste plate
/// (grandes icônes, pas de pastilles colorées, pas d'étiquettes de
/// section), fond bien sombre en mode sombre.
///
/// Naviguer vers Accueil/Recherche/Plan/Courses depuis une page
/// profonde (Profil, édition de recette...) réinitialise la pile de
/// navigation jusqu'à la coquille (AppShellPage), sur l'onglet
/// demandé — plus simple et cohérent que d'essayer de faire
/// remonter un état d'onglet à travers plusieurs écrans poussés.
class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  Future<bool> _checkIsCreator() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) return false;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      final role = profile['role'] as String?;
      return role == 'creator' || role == 'admin';
    } catch (_) {
      return false;
    }
  }

  void _goToTab(BuildContext context, int tabIndex) {
    Navigator.of(context).pop();
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/home',
      (route) => false,
      arguments: tabIndex,
    );
  }

  Future<void> _openProfile(BuildContext context) async {
    Navigator.of(context).pop();
    await Navigator.of(context).pushNamed('/my-profile');
  }

  Future<void> _openSettings(BuildContext context) async {
    Navigator.of(context).pop();
    await Navigator.of(context).pushNamed('/profile');
  }

  Future<void> _openCreateMenu(BuildContext context) async {
    final isCreator = await _checkIsCreator();

    if (!context.mounted) return;

    if (!isCreator) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seuls les créateurs peuvent publier des recettes.'),
        ),
      );
      return;
    }

    Navigator.of(context).pop();

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
                subtitle: const Text('Formulaire manuel, avec image'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pushNamed('/create-recipe');
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_call_outlined),
                title: const Text('Créer à partir d’une vidéo'),
                subtitle: const Text('Importer une vidéo déjà tournée'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pushNamed('/create-video-recipe');
                },
              ),
              ListTile(
                leading: const Icon(Icons.restaurant_menu_outlined),
                title: const Text('Mes recettes'),
                subtitle: const Text('Gérer mes brouillons et publications'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pushNamed('/my-recipes');
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showComingSoon(BuildContext context, String feature) {
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — bientôt disponible.')),
    );
  }

  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Clair';
      case ThemeMode.dark:
        return 'Sombre';
      case ThemeMode.system:
        return 'Système';
    }
  }

  Future<void> _showThemePicker(BuildContext context) async {
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
              for (final mode in ThemeMode.values)
                ListTile(
                  leading: Icon(
                    mode == ThemeMode.light
                        ? Icons.light_mode_outlined
                        : mode == ThemeMode.dark
                            ? Icons.dark_mode_outlined
                            : Icons.smartphone_outlined,
                  ),
                  title: Text(_themeModeLabel(mode)),
                  trailing: ThemeController.instance.mode == mode
                      ? Icon(
                          Icons.check,
                          color: Theme.of(sheetContext).colorScheme.primary,
                        )
                      : null,
                  onTap: () async {
                    await ThemeController.instance.setThemeMode(mode);
                    try {
                      await AuthRepository().updateProfilePreferences(
                        themePreference:
                            ThemeController.themeModeToPreferenceString(mode),
                      );
                    } catch (_) {}
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                  },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  Future<void> _logout(BuildContext context) async {
    Navigator.of(context).pop();
    await AuthRepository().signOut();

    if (!context.mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ====================================================
            // EN-TÊTE : PHOTO + NOM + USERNAME
            // ====================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
              child: FutureBuilder<Map<String, dynamic>>(
                future: ProfileRepository().getMyProfile(),
                builder: (context, snapshot) {
                  final profile = snapshot.data;
                  final fullName = profile?['full_name']?.toString() ?? '';
                  final username = profile?['username']?.toString() ?? '';

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openProfile(context),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              FutureBuilder<String?>(
                                future: profile == null
                                    ? null
                                    : ProfileRepository().getAvatarUrl(
                                        profile['avatar_url'] as String?,
                                      ),
                                builder: (context, avatarSnapshot) {
                                  final url = avatarSnapshot.data;

                                  return CircleAvatar(
                                    radius: 26,
                                    backgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    backgroundImage: url != null
                                        ? NetworkImage(url)
                                        : null,
                                    child: url == null
                                        ? Icon(
                                            Icons.person,
                                            color: colorScheme.onSurfaceVariant,
                                          )
                                        : null,
                                  );
                                },
                              ),
                              const SizedBox(height: 10),
                              Text(
                                fullName.isEmpty ? 'Mon compte' : fullName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              if (username.isNotEmpty)
                                Text(
                                  '@$username',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _openSettings(context),
                        icon: const Icon(Icons.more_vert),
                      ),
                    ],
                  );
                },
              ),
            ),

            const Divider(height: 1),

            // ====================================================
            // NAVIGATION PRINCIPALE (liste plate, grandes icônes)
            // ====================================================

            const SizedBox(height: 4),
            _FlatDrawerItem(
              icon: Icons.home_outlined,
              label: 'Accueil',
              onTap: () => _goToTab(context, 0),
            ),
            _FlatDrawerItem(
              icon: Icons.add_circle_outline,
              label: 'Ajouter une recette',
              onTap: () => _openCreateMenu(context),
            ),
            _FlatDrawerItem(
              icon: Icons.restaurant_menu_outlined,
              label: 'Mes recettes',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/my-recipes');
              },
            ),
            _FlatDrawerItem(
              icon: Icons.search,
              label: 'Rechercher',
              onTap: () => _goToTab(context, 1),
            ),
            _FlatDrawerItem(
              icon: Icons.favorite_border,
              label: 'Favoris',
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/favorites');
              },
            ),
            _FlatDrawerItem(
              icon: Icons.calendar_month_outlined,
              label: 'Planificateur de repas',
              onTap: () => _goToTab(context, 2),
            ),
            _FlatDrawerItem(
              icon: Icons.shopping_bag_outlined,
              label: 'Liste de courses',
              onTap: () => _goToTab(context, 3),
            ),

            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),

            // ====================================================
            // UTILITAIRES
            // ====================================================

            _FlatDrawerItem(
              icon: Icons.settings_outlined,
              label: 'Paramètres',
              onTap: () => _openSettings(context),
            ),
            _FlatDrawerItem(
              icon: Icons.help_outline,
              label: 'Aide et support',
              onTap: () => _showComingSoon(context, 'L’aide et le support'),
            ),
            _FlatDrawerItem(
              icon: Icons.ios_share_outlined,
              label: 'Partager l’application',
              onTap: () =>
                  _showComingSoon(context, 'Le partage de l’application'),
            ),
            _FlatDrawerItem(
              icon: Icons.brightness_6_outlined,
              label: 'Thème',
              trailing: _themeModeLabel(ThemeController.instance.mode),
              onTap: () => _showThemePicker(context),
            ),

            const SizedBox(height: 16),
            Center(
              child: Text(
                'Mealora — v0.1',
                style: TextStyle(fontSize: 11, color: colorScheme.outline),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),

            _FlatDrawerItem(
              icon: Icons.logout,
              label: 'Se déconnecter',
              color: Colors.red,
              onTap: () => _logout(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// LIGNE PLATE (icône + texte, grands, façon X)
// ============================================================

class _FlatDrawerItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  final Color? color;
  final VoidCallback onTap;

  const _FlatDrawerItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.trailing,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resolvedColor = color ?? Theme.of(context).colorScheme.onSurface;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 24, color: resolvedColor),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: resolvedColor,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}