import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'theme/app_theme.dart';
import 'app_drawer.dart';
import '../features/home/home_page.dart';
import '../features/recipes/presentation/search_page.dart';
import '../features/planner/presentation/meal_plan_page.dart';
import '../features/shopping/presentation/shopping_list_page.dart';

/// Coquille persistante de l'application : Drawer, en-tête, bouton
/// "+" et navigation du bas restent toujours visibles, seul le
/// contenu au centre change selon l'onglet sélectionné.
///
/// Corrige le bug où appuyer sur Recettes/Plan/Courses poussait un
/// nouvel écran par-dessus et faisait disparaître la navigation
/// principale — maintenant tout reste dans un seul Scaffold.
class AppShellPage extends StatefulWidget {
  final int initialTabIndex;

  const AppShellPage({super.key, this.initialTabIndex = 0});

  @override
  State<AppShellPage> createState() => _AppShellPageState();
}

class _AppShellPageState extends State<AppShellPage> {
  late int _currentIndex = widget.initialTabIndex;

  final GlobalKey<HomeTabViewState> _homeKey = GlobalKey<HomeTabViewState>();
  final GlobalKey<SearchTabViewState> _searchKey =
      GlobalKey<SearchTabViewState>();
  final GlobalKey<MealPlanTabViewState> _mealPlanKey =
      GlobalKey<MealPlanTabViewState>();
  final GlobalKey<ShoppingListTabViewState> _shoppingListKey =
      GlobalKey<ShoppingListTabViewState>();

  late final List<Widget> _tabs;

  String? _userRole;
  bool _isLoadingRole = true;

  bool get _isCreator =>
      !_isLoadingRole && (_userRole == 'creator' || _userRole == 'admin');

  @override
  void initState() {
    super.initState();

    _tabs = [
      HomeTabView(
        key: _homeKey,
        onOpenSearch: () => setState(() => _currentIndex = 1),
      ),
      SearchTabView(key: _searchKey),
      MealPlanTabView(key: _mealPlanKey),
      ShoppingListTabView(key: _shoppingListKey),
    ];

    _loadUserRole();
  }

  // ============================================================
  // CHARGEMENT DU RÔLE
  // ============================================================

  Future<void> _loadUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _userRole = null;
        _isLoadingRole = false;
      });
      return;
    }

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .single();

      if (!mounted) return;

      setState(() {
        _userRole = profile['role'] as String?;
        _isLoadingRole = false;
      });
    } catch (error) {
      debugPrint('Erreur récupération rôle : $error');

      if (!mounted) return;

      setState(() {
        _userRole = null;
        _isLoadingRole = false;
      });
    }
  }

  void _selectTab(int index) {
    setState(() => _currentIndex = index);
  }

  Widget _buildHeaderTrailingIcon() {
    switch (_currentIndex) {
      case 1: // Recherche/Recettes
        return IconButton(
          onPressed: () => _searchKey.currentState?.cycleViewDensity(),
          icon: const Icon(Icons.image_outlined),
          tooltip: 'Changer l’affichage des recettes',
        );
      case 2: // Plan
        return IconButton(
          onPressed: _cyclePlanDensity,
          icon: const Icon(Icons.calendar_today_outlined),
        );
      case 3: // Courses
        return IconButton(
          onPressed: () =>
              _shoppingListKey.currentState?.pickRecipeAndGenerate(),
          icon: const Icon(Icons.menu_book_outlined),
          tooltip: 'Générer depuis une recette',
        );
      default: // Accueil
        return IconButton(
          onPressed: () => _showComingSoon('Les notifications'),
          icon: const Icon(Icons.notifications_outlined),
        );
    }
  }

  void _cyclePlanDensity() {
    _mealPlanKey.currentState?.cycleDensity();
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature — bientôt disponible.')),
    );
  }

  // ============================================================
  // MENU DE CRÉATION (bouton "+" central)
  // ============================================================

  Future<void> _openCreateMenu() async {
    if (!_isCreator) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Seuls les créateurs peuvent publier des recettes.'),
        ),
      );
      return;
    }

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
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Navigator.of(context).pushNamed('/create-recipe');
                  if (!mounted) return;
                  await _homeKey.currentState?.refresh();
                },
              ),
              ListTile(
                leading: const Icon(Icons.video_call_outlined),
                title: const Text('Créer à partir d’une vidéo'),
                subtitle: const Text('Importer une vidéo déjà tournée'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Navigator.of(context)
                      .pushNamed('/create-video-recipe');
                  if (!mounted) return;
                  await _homeKey.currentState?.refresh();
                },
              ),
              ListTile(
                leading: const Icon(Icons.restaurant_menu_outlined),
                title: const Text('Mes recettes'),
                subtitle: const Text('Gérer mes brouillons et publications'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await Navigator.of(context).pushNamed('/my-recipes');
                  if (!mounted) return;
                  await _homeKey.currentState?.refresh();
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
    return Scaffold(
      drawer: const AppDrawer(),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ====================================================
            // EN-TÊTE PERSISTANT
            // ====================================================

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Builder(
                    builder: (context) => IconButton(
                      onPressed: () => Scaffold.of(context).openDrawer(),
                      icon: const Icon(Icons.menu),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Mealora',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                  ),
                  _buildHeaderTrailingIcon(),
                ],
              ),
            ),

            // ====================================================
            // CONTENU DE L'ONGLET SÉLECTIONNÉ
            // ====================================================

            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: _tabs,
              ),
            ),
          ],
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateMenu,
        backgroundColor: AppTheme.accentSecondary,
        foregroundColor: Colors.black,
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavItem(
              icon: Icons.home_rounded,
              label: 'Accueil',
              isActive: _currentIndex == 0,
              onTap: () => _selectTab(0),
            ),
            _NavItem(
              icon: Icons.search_rounded,
              label: 'Recettes',
              isActive: _currentIndex == 1,
              onTap: () => _selectTab(1),
            ),
            const SizedBox(width: 40),
            _NavItem(
              icon: Icons.calendar_month_rounded,
              label: 'Plan',
              isActive: _currentIndex == 2,
              onTap: () => _selectTab(2),
            ),
            _NavItem(
              icon: Icons.shopping_bag_outlined,
              label: 'Courses',
              isActive: _currentIndex == 3,
              onTap: () => _selectTab(3),
            ),
          ],
        ),
      ),
    );
  }
}


// ============================================================
// ÉLÉMENT DE NAVIGATION DU BAS
// ============================================================

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }
}