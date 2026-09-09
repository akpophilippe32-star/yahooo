import 'package:flutter/material.dart';

import '../../../core/app_bar_leading.dart';
import '../../../core/app_drawer.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../repositories/profile_repository.dart';
import '../data/auth_repository.dart';

/// Écran de profil / paramètres — liste groupée façon CookBook,
/// mais réduite aux réglages pertinents pour Mealora (pas de plan
/// payant, synchronisation, tableau de bord personnalisable, unités
/// de conversion ou notifications détaillées — non applicables
/// aujourd'hui).
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _profileRepository = ProfileRepository();
  final _authRepository = AuthRepository();

  static const List<String> _dietaryOptions = [
    'Végétarien',
    'Végan',
    'Sans gluten',
    'Halal',
    'Casher',
    'Sans lactose',
  ];

  static const List<String> _cuisineOptions = [
    'Africaine',
    'Italienne',
    'Asiatique',
    'Française',
    'Orientale',
    'Américaine',
  ];

  static const List<Color> _colorSwatches = [
    Color(0xFFE8703C),
    Color(0xFFE8A63C),
    Color(0xFF3B6D11),
    Color(0xFF0F6E56),
    Color(0xFF2C5C8A),
    Color(0xFF5C3A8A),
    Color(0xFF8A2C4E),
    Color(0xFF6B6152),
  ];

  bool _isLoading = true;
  String? _loadError;
  Map<String, dynamic>? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ============================================================
  // CHARGEMENT
  // ============================================================

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final profile = await _profileRepository.getMyProfile();

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  Color get _accentColor {
    final hex = _profile?['accent_color'] as String?;

    if (hex != null && hex.isNotEmpty) {
      try {
        final value =
            int.parse(hex.replaceFirst('#', ''), radix: 16) | 0xFF000000;
        return Color(value);
      } catch (_) {}
    }

    return _colorSwatches.first;
  }

  // ============================================================
  // AVATAR (gérée sur l'écran "Voir mon profil" désormais)
  // ============================================================

  Future<void> _logout() async {
    await _authRepository.signOut();

    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — bientôt disponible.')),
    );
  }

  // ============================================================
  // FEUILLE — PRÉFÉRENCES ALIMENTAIRES
  // ============================================================

  Future<void> _showFoodPreferencesSheet() async {
    final dietary = Set<String>.from(
      ((_profile?['dietary_preferences'] as List?) ?? [])
          .map((e) => e.toString()),
    );
    final cuisines = Set<String>.from(
      ((_profile?['cuisine_preferences'] as List?) ?? [])
          .map((e) => e.toString()),
    );
    final preferredFoods = List<String>.from(
      ((_profile?['preferred_foods'] as List?) ?? [])
          .map((e) => e.toString()),
    );
    final avoidedFoods = List<String>.from(
      ((_profile?['avoided_foods'] as List?) ?? [])
          .map((e) => e.toString()),
    );
    String? cookingLevel = _profile?['cooking_level'] as String?;

    final preferredController = TextEditingController();
    final avoidedController = TextEditingController();

    bool isSaving = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            return DraggableScrollableSheet(
              initialChildSize: 0.85,
              maxChildSize: 0.95,
              expand: false,
              builder: (context, scrollController) {
                return SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 20,
                    bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Préférences alimentaires',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Régime',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _dietaryOptions.map((option) {
                          final isSelected = dietary.contains(option);
                          return FilterChip(
                            label: Text(option),
                            selected: isSelected,
                            onSelected: (value) {
                              setSheetState(() {
                                if (value) {
                                  dietary.add(option);
                                } else {
                                  dietary.remove(option);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Cuisines préférées',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _cuisineOptions.map((option) {
                          final isSelected = cuisines.contains(option);
                          return FilterChip(
                            label: Text(option),
                            selected: isSelected,
                            onSelected: (value) {
                              setSheetState(() {
                                if (value) {
                                  cuisines.add(option);
                                } else {
                                  cuisines.remove(option);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Niveau en cuisine',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          ChoiceChip(
                            label: const Text('Débutant'),
                            selected: cookingLevel == 'debutant',
                            onSelected: (_) => setSheetState(
                              () => cookingLevel = 'debutant',
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Intermédiaire'),
                            selected: cookingLevel == 'intermediaire',
                            onSelected: (_) => setSheetState(
                              () => cookingLevel = 'intermediaire',
                            ),
                          ),
                          ChoiceChip(
                            label: const Text('Avancé'),
                            selected: cookingLevel == 'avance',
                            onSelected: (_) => setSheetState(
                              () => cookingLevel = 'avance',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Aliments préférés',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: preferredController,
                              decoration: const InputDecoration(
                                hintText: 'Ex. riz, manioc...',
                              ),
                              onSubmitted: (value) {
                                final trimmed = value.trim();
                                if (trimmed.isEmpty ||
                                    preferredFoods.contains(trimmed)) {
                                  return;
                                }
                                setSheetState(() {
                                  preferredFoods.add(trimmed);
                                  preferredController.clear();
                                });
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final trimmed = preferredController.text.trim();
                              if (trimmed.isEmpty ||
                                  preferredFoods.contains(trimmed)) {
                                return;
                              }
                              setSheetState(() {
                                preferredFoods.add(trimmed);
                                preferredController.clear();
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: preferredFoods.map((food) {
                          return Chip(
                            label: Text(food),
                            onDeleted: () {
                              setSheetState(() => preferredFoods.remove(food));
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Aliments à éviter',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: avoidedController,
                              decoration: const InputDecoration(
                                hintText: 'Ex. arachide, fruits de mer...',
                              ),
                              onSubmitted: (value) {
                                final trimmed = value.trim();
                                if (trimmed.isEmpty ||
                                    avoidedFoods.contains(trimmed)) {
                                  return;
                                }
                                setSheetState(() {
                                  avoidedFoods.add(trimmed);
                                  avoidedController.clear();
                                });
                              },
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              final trimmed = avoidedController.text.trim();
                              if (trimmed.isEmpty ||
                                  avoidedFoods.contains(trimmed)) {
                                return;
                              }
                              setSheetState(() {
                                avoidedFoods.add(trimmed);
                                avoidedController.clear();
                              });
                            },
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: avoidedFoods.map((food) {
                          return Chip(
                            label: Text(food),
                            onDeleted: () {
                              setSheetState(() => avoidedFoods.remove(food));
                            },
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: isSaving
                            ? null
                            : () async {
                                setSheetState(() => isSaving = true);

                                try {
                                  await _profileRepository
                                      .updateFoodPreferences(
                                    dietaryPreferences: dietary.toList(),
                                    cuisinePreferences: cuisines.toList(),
                                    preferredFoods: preferredFoods,
                                    avoidedFoods: avoidedFoods,
                                    cookingLevel: cookingLevel,
                                  );

                                  if (!mounted) return;

                                  setState(() {
                                    _profile = {
                                      ...?_profile,
                                      'dietary_preferences':
                                          dietary.toList(),
                                      'cuisine_preferences':
                                          cuisines.toList(),
                                      'preferred_foods': preferredFoods,
                                      'avoided_foods': avoidedFoods,
                                      'cooking_level': cookingLevel,
                                    };
                                  });

                                  if (!sheetContext.mounted) return;
                                  Navigator.of(sheetContext).pop();
                                } catch (error) {
                                  setSheetState(() => isSaving = false);

                                  if (!sheetContext.mounted) return;
                                  ScaffoldMessenger.of(sheetContext)
                                      .showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Impossible d’enregistrer : $error',
                                      ),
                                    ),
                                  );
                                }
                              },
                        child: isSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Enregistrer'),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // ============================================================
  // FEUILLE — COULEUR DU THÈME
  // ============================================================

  Future<void> _showColorPicker() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Couleur du profil',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _colorSwatches.map((color) {
                  final isSelected = color == _accentColor;

                  return InkWell(
                    onTap: () async {
                      setState(() {
                        _profile = {
                          ...?_profile,
                          'accent_color':
                              '#${color.toARGB32().toRadixString(16).substring(2)}',
                        };
                      });

                      try {
                        await _authRepository.updateProfilePreferences(
                          accentColor:
                              '#${color.toARGB32().toRadixString(16).substring(2)}',
                        );
                      } catch (_) {}

                      if (!sheetContext.mounted) return;
                      Navigator.of(sheetContext).pop();
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black87, width: 2.5)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // FEUILLE — THÈME (clair/sombre/système)
  // ============================================================

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

  Future<void> _showThemePicker() async {
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
                      await _authRepository.updateProfilePreferences(
                        themePreference:
                            ThemeController.themeModeToPreferenceString(mode),
                      );
                    } catch (_) {}

                    if (!mounted) return;
                    setState(() {});

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

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_loadError != null) {
      return Scaffold(
        drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Profil'),
        leading: const AppBackMenuLeading(),
        leadingWidth: 96,
      ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                Text('Impossible de charger ton profil : $_loadError'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _loadProfile,
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    final fullName = _profile?['full_name']?.toString() ?? '';

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Profil'),
        leading: const AppBackMenuLeading(),
        leadingWidth: 96,
      ),
      body: SafeArea(
        child: ListView(
          children: [
            const SizedBox(height: 12),

            // ========================================================
            // SECTION : COMPTE
            // ========================================================

            const _SettingsSectionLabel('Compte'),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.account_circle_outlined,
                  title: 'Voir mon profil',
                  onTap: () {
                    Navigator.of(context).pushNamed('/my-profile');
                  },
                ),
                _SettingsRow(
                  icon: Icons.person_outline,
                  title: 'Mes informations',
                  subtitle: fullName.isEmpty ? null : fullName,
                  onTap: () async {
                    final updated = await Navigator.of(context)
                        .pushNamed('/edit-profile');
                    if (updated == true) {
                      _loadProfile();
                    }
                  },
                ),
                _SettingsRow(
                  icon: Icons.restaurant_menu_outlined,
                  title: 'Préférences alimentaires',
                  onTap: _showFoodPreferencesSheet,
                ),
                _SettingsRow(
                  icon: Icons.logout,
                  title: 'Se déconnecter',
                  titleColor: Colors.red,
                  iconColor: Colors.red,
                  showChevron: false,
                  onTap: _logout,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ========================================================
            // SECTION : APPARENCE
            // ========================================================

            const _SettingsSectionLabel('Apparence'),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.language,
                  title: 'Langue',
                  valueText: 'Français',
                  onTap: () => _showComingSoon('Le changement de langue'),
                ),
                _SettingsRow(
                  icon: Icons.translate,
                  title: 'Traduction auto',
                  valueText: 'Inactif',
                  onTap: () => _showComingSoon('La traduction automatique'),
                ),
                _SettingsRow(
                  icon: Icons.palette_outlined,
                  title: 'Couleur du thème',
                  trailing: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  onTap: _showColorPicker,
                ),
                _SettingsRow(
                  icon: Icons.brightness_6_outlined,
                  title: 'Thème',
                  valueText: _themeModeLabel(ThemeController.instance.mode),
                  onTap: _showThemePicker,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ========================================================
            // SECTION : À PROPOS
            // ========================================================

            const _SettingsSectionLabel('À propos'),
            _SettingsGroup(
              children: [
                _SettingsRow(
                  icon: Icons.help_outline,
                  title: 'Aide et support',
                  onTap: () => _showComingSoon('L’aide et le support'),
                ),
                _SettingsRow(
                  icon: Icons.description_outlined,
                  title: 'Conditions d’utilisation',
                  onTap: () => _showComingSoon('Les conditions d’utilisation'),
                ),
                _SettingsRow(
                  icon: Icons.shield_outlined,
                  title: 'Politique de confidentialité',
                  onTap: () =>
                      _showComingSoon('La politique de confidentialité'),
                ),
              ],
            ),

            const SizedBox(height: 24),
            Text(
              'Mealora — v0.1',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: colorScheme.outline),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// ÉTIQUETTE DE SECTION
// ============================================================

class _SettingsSectionLabel extends StatelessWidget {
  final String label;

  const _SettingsSectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

// ============================================================
// GROUPE DE RÉGLAGES (fond arrondi contenant les lignes)
// ============================================================

class _SettingsGroup extends StatelessWidget {
  final List<Widget> children;

  const _SettingsGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i != children.length - 1)
              Divider(
                height: 1,
                indent: 52,
                color: Theme.of(context).colorScheme.outline,
              ),
          ],
        ],
      ),
    );
  }
}

// ============================================================
// LIGNE DE RÉGLAGE (icône, titre, valeur/chevron)
// ============================================================

class _SettingsRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? valueText;
  final Widget? trailing;
  final Color? iconColor;
  final Color? titleColor;
  final bool showChevron;
  final VoidCallback onTap;

  const _SettingsRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.valueText,
    this.trailing,
    this.iconColor,
    this.titleColor,
    this.showChevron = true,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? colorScheme.onSurface),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 14, color: titleColor),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 11,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (valueText != null)
              Text(
                valueText!,
                style: TextStyle(
                  fontSize: 13,
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            if (trailing != null) trailing!,
            if (showChevron) ...[
              const SizedBox(width: 6),
              Icon(Icons.chevron_right, size: 18, color: colorScheme.outline),
            ],
          ],
        ),
      ),
    );
  }
}