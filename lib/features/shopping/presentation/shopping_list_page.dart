import 'package:flutter/material.dart';

import '../../../models/recipe_model.dart';
import '../../../repositories/recipe_repository.dart';
import '../../../repositories/shopping_list_repository.dart';

/// Contenu de l'onglet Courses (§20 du cahier des charges) : ajout
/// manuel d'articles, ou génération automatique depuis les
/// ingrédients des recettes planifiées cette semaine.
///
/// Pas de Scaffold ici : ce widget est intégré dans la coquille
/// d'app persistante (AppShellPage).
class ShoppingListTabView extends StatefulWidget {
  const ShoppingListTabView({super.key});

  @override
  State<ShoppingListTabView> createState() => ShoppingListTabViewState();
}

class ShoppingListTabViewState extends State<ShoppingListTabView> {
  final _shoppingListRepository = ShoppingListRepository();
  final _recipeRepository = RecipeRepository();
  final _addItemController = TextEditingController();

  late Future<List<Map<String, dynamic>>> _itemsFuture;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _addItemController.dispose();
    super.dispose();
  }

  void _load() {
    _itemsFuture = _shoppingListRepository.getItems();
  }

  Future<void> refresh() async {
    setState(_load);
    await _itemsFuture;
  }

  // ============================================================
  // GÉNÉRER DEPUIS LE PLANNING
  // ============================================================

  Future<void> _generateFromPlan() async {
    setState(() => _isGenerating = true);

    try {
      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - 1));
      final weekEnd = weekStart.add(const Duration(days: 6));

      final count = await _shoppingListRepository.generateFromMealPlan(
        start: weekStart,
        end: weekEnd,
      );

      if (!mounted) return;

      await refresh();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? 'Aucune recette planifiée cette semaine — rien à ajouter.'
                : '$count article${count > 1 ? 's' : ''} ajouté${count > 1 ? 's' : ''} '
                    'depuis le planning de la semaine.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  // ============================================================
  // GÉNÉRER DEPUIS UNE SEULE RECETTE (sélecteur de recette)
  // ============================================================
  //
  // Publique : appelée depuis l'icône de l'en-tête de la coquille
  // (AppShellPage) quand on est sur cet onglet.

  Future<void> pickRecipeAndGenerate() async {
    final searchController = TextEditingController();
    Future<List<RecipeModel>> resultsFuture =
        _recipeRepository.getPublishedRecipes();

    final selected = await showModalBottomSheet<RecipeModel>(
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
                return Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Générer depuis une recette',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choisis la recette que tu veux préparer.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        decoration: const InputDecoration(
                          hintText: 'Rechercher une recette...',
                          prefixIcon: Icon(Icons.search),
                        ),
                        onChanged: (value) {
                          setSheetState(() {
                            resultsFuture = value.trim().isEmpty
                                ? _recipeRepository.getPublishedRecipes()
                                : _recipeRepository.searchRecipes(
                                    query: value.trim(),
                                  );
                          });
                        },
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: FutureBuilder<List<RecipeModel>>(
                          future: resultsFuture,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState ==
                                ConnectionState.waiting) {
                              return const Center(
                                child: CircularProgressIndicator(),
                              );
                            }

                            final recipes = snapshot.data ?? [];

                            if (recipes.isEmpty) {
                              return const Center(
                                child: Text('Aucune recette trouvée.'),
                              );
                            }

                            return ListView.builder(
                              controller: scrollController,
                              itemCount: recipes.length,
                              itemBuilder: (context, index) {
                                final recipe = recipes[index];

                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: Icon(
                                      recipe.sourceType == 'video'
                                          ? Icons.play_circle_outline
                                          : Icons.restaurant,
                                    ),
                                  ),
                                  title: Text(recipe.title),
                                  onTap: () {
                                    Navigator.of(sheetContext).pop(recipe);
                                  },
                                );
                              },
                            );
                          },
                        ),
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

    if (selected == null) return;

    setState(() => _isGenerating = true);

    try {
      final count =
          await _shoppingListRepository.generateFromRecipe(selected.id);

      if (!mounted) return;

      await refresh();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count == 0
                ? '« ${selected.title} » n’a pas d’ingrédients renseignés.'
                : '$count article${count > 1 ? 's' : ''} ajouté'
                    '${count > 1 ? 's' : ''} depuis « ${selected.title} ».',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de générer la liste : $error')),
      );
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _addManualItem() async {
    final name = _addItemController.text.trim();

    if (name.isEmpty) return;

    _addItemController.clear();

    try {
      await _shoppingListRepository.addItem(name: name);

      if (!mounted) return;

      await refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’ajouter l’article : $error')),
      );
    }
  }

  Future<void> _toggleChecked(int itemId, bool value) async {
    try {
      await _shoppingListRepository.setChecked(itemId, value);

      if (!mounted) return;

      await refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de mettre à jour : $error')),
      );
    }
  }

  Future<void> _deleteItem(int itemId) async {
    try {
      await _shoppingListRepository.deleteItem(itemId);

      if (!mounted) return;

      await refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de retirer l’article : $error')),
      );
    }
  }

  Future<void> _clearChecked() async {
    try {
      await _shoppingListRepository.clearChecked();

      if (!mounted) return;

      await refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de nettoyer la liste : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: refresh,
      child: Column(
        children: [
          // ========================================================
          // GÉNÉRER DEPUIS LE PLANNING
          // ========================================================

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGenerating ? null : _generateFromPlan,
                icon: _isGenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.calendar_month_outlined),
                label: Text(
                  _isGenerating
                      ? 'Génération en cours...'
                      : 'Générer depuis le planning de la semaine',
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isGenerating ? null : pickRecipeAndGenerate,
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('Générer depuis une recette'),
              ),
            ),
          ),

          // ========================================================
          // AJOUT MANUEL
          // ========================================================

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _addItemController,
                    decoration: const InputDecoration(
                      hintText: 'Ajouter un article...',
                      prefixIcon: Icon(Icons.add),
                    ),
                    onSubmitted: (_) => _addManualItem(),
                  ),
                ),
                IconButton(
                  onPressed: _addManualItem,
                  icon: const Icon(Icons.send),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ========================================================
          // LISTE DES ARTICLES
          // ========================================================

          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _itemsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Impossible de charger la liste : ${snapshot.error}',
                    ),
                  );
                }

                final items = snapshot.data ?? [];

                if (items.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.shopping_bag_outlined,
                            size: 40,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Ta liste de courses est vide.\n'
                            'Ajoute un article ou génère-la depuis '
                            'ton planning.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final hasChecked = items.any((item) => item['is_checked'] == true);

                return ListView(
                  padding: const EdgeInsets.only(bottom: 90),
                  children: [
                    for (final item in items)
                      Dismissible(
                        key: ValueKey(item['id']),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => _deleteItem(item['id'] as int),
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: CheckboxListTile(
                          value: item['is_checked'] == true,
                          onChanged: (value) => _toggleChecked(
                            item['id'] as int,
                            value ?? false,
                          ),
                          title: Text(
                            item['name']?.toString() ?? '',
                            style: TextStyle(
                              decoration: item['is_checked'] == true
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: item['is_checked'] == true
                                  ? colorScheme.onSurfaceVariant
                                  : null,
                            ),
                          ),
                          subtitle: (item['quantity'] != null ||
                                  item['unit'] != null)
                              ? Text(
                                  [
                                    item['quantity']?.toString() ?? '',
                                    item['unit']?.toString() ?? '',
                                  ].where((s) => s.isNotEmpty).join(' '),
                                )
                              : null,
                          secondary: item['source'] == 'recipe'
                              ? const Icon(Icons.restaurant_menu_outlined)
                              : null,
                        ),
                      ),
                    if (hasChecked)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextButton.icon(
                          onPressed: _clearChecked,
                          icon: const Icon(Icons.cleaning_services_outlined),
                          label: const Text('Retirer les articles cochés'),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}