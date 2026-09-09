import 'package:flutter/material.dart';

import '../../../models/recipe_model.dart';
import '../../../repositories/meal_plan_repository.dart';
import '../../../repositories/recipe_repository.dart';
import '../../recipes/presentation/recipe_public_view_page.dart';

const List<String> _kMonthNames = [
  'Janvier',
  'Février',
  'Mars',
  'Avril',
  'Mai',
  'Juin',
  'Juillet',
  'Août',
  'Septembre',
  'Octobre',
  'Novembre',
  'Décembre',
];

const List<String> _kMonthNamesShort = [
  'Jan.',
  'Fév.',
  'Mars',
  'Avr.',
  'Mai',
  'Juin',
  'Juil.',
  'Août',
  'Sept.',
  'Oct.',
  'Nov.',
  'Déc.',
];

const List<String> _kWeekdayNamesShort = [
  'Lun.',
  'Mar.',
  'Mer.',
  'Jeu.',
  'Ven.',
  'Sam.',
  'Dim.',
];

/// Niveau de détail affiché : mois complet, une seule semaine, ou
/// juste le jour sélectionné (façon "réduire" progressivement le
/// calendrier, comme dans la référence CookBook).
enum _CalendarDensity { month, week, day }

/// Contenu de l'onglet Planning : calendrier mensuel complet (comme
/// la référence CookBook) + détail du jour sélectionné en dessous,
/// avec les 4 créneaux de repas.
///
/// Pas de Scaffold ici : ce widget est intégré dans la coquille
/// d'app persistante (AppShellPage), qui fournit l'en-tête, le
/// tiroir et la navigation du bas.
class MealPlanTabView extends StatefulWidget {
  const MealPlanTabView({super.key});

  @override
  State<MealPlanTabView> createState() => MealPlanTabViewState();
}

class MealPlanTabViewState extends State<MealPlanTabView> {
  final _mealPlanRepository = MealPlanRepository();
  final _recipeRepository = RecipeRepository();

  late DateTime _visibleMonth;
  late DateTime _selectedDay;
  _CalendarDensity _density = _CalendarDensity.month;
  late Future<List<Map<String, dynamic>>> _monthEntriesFuture;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month, 1);
    _selectedDay = DateTime(now.year, now.month, now.day);

    _loadMonth();
  }

  // ============================================================
  // GRILLE DU MOIS (avec jours des mois adjacents pour compléter)
  // ============================================================

  List<({DateTime date, bool isCurrentMonth})> _buildMonthGrid() {
    final firstOfMonth = _visibleMonth;
    final daysInMonth =
        DateTime(_visibleMonth.year, _visibleMonth.month + 1, 0).day;
    final leadingEmptyDays = firstOfMonth.weekday - 1; // Lundi = 1

    final prevMonthLastDay =
        DateTime(_visibleMonth.year, _visibleMonth.month, 0).day;

    final cells = <({DateTime date, bool isCurrentMonth})>[];

    for (var i = leadingEmptyDays - 1; i >= 0; i--) {
      cells.add((
        date: DateTime(
          _visibleMonth.year,
          _visibleMonth.month - 1,
          prevMonthLastDay - i,
        ),
        isCurrentMonth: false,
      ));
    }

    for (var d = 1; d <= daysInMonth; d++) {
      cells.add((
        date: DateTime(_visibleMonth.year, _visibleMonth.month, d),
        isCurrentMonth: true,
      ));
    }

    var nextDay = 1;
    while (cells.length % 7 != 0) {
      cells.add((
        date: DateTime(
          _visibleMonth.year,
          _visibleMonth.month + 1,
          nextDay,
        ),
        isCurrentMonth: false,
      ));
      nextDay++;
    }

    return cells;
  }

  DateTime get _gridStart => _buildMonthGrid().first.date;
  DateTime get _gridEnd => _buildMonthGrid().last.date;

  void _loadMonth() {
    _monthEntriesFuture = _mealPlanRepository.getMealPlan(
      start: _gridStart,
      end: _gridEnd,
    );
  }

  Future<void> _refresh() async {
    setState(_loadMonth);
    await _monthEntriesFuture;
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _visibleMonth = DateTime(now.year, now.month, 1);
      _selectedDay = DateTime(now.year, now.month, now.day);
      _loadMonth();
    });
  }

  /// Saute directement à une date précise (appelé depuis l'icône
  /// calendrier de la coquille d'app, dans l'en-tête).
  void goToDate(DateTime date) {
    setState(() {
      _visibleMonth = DateTime(date.year, date.month, 1);
      _selectedDay = DateTime(date.year, date.month, date.day);
      _loadMonth();
    });
  }

  /// Réduit progressivement la vue du calendrier : mois complet →
  /// une seule semaine → juste le jour → retour au mois. Appelée
  /// depuis l'icône calendrier de l'en-tête de la coquille.
  void cycleDensity() {
    setState(() {
      _density = switch (_density) {
        _CalendarDensity.month => _CalendarDensity.week,
        _CalendarDensity.week => _CalendarDensity.day,
        _CalendarDensity.day => _CalendarDensity.month,
      };
    });
  }

  DateTime get _mondayOfSelectedWeek {
    return _selectedDay.subtract(Duration(days: _selectedDay.weekday - 1));
  }

  void _goPrevious() {
    setState(() {
      switch (_density) {
        case _CalendarDensity.month:
          _visibleMonth =
              DateTime(_visibleMonth.year, _visibleMonth.month - 1, 1);
          break;
        case _CalendarDensity.week:
          _selectedDay = _selectedDay.subtract(const Duration(days: 7));
          _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
          break;
        case _CalendarDensity.day:
          _selectedDay = _selectedDay.subtract(const Duration(days: 1));
          _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
          break;
      }
      _loadMonth();
    });
  }

  void _goNext() {
    setState(() {
      switch (_density) {
        case _CalendarDensity.month:
          _visibleMonth =
              DateTime(_visibleMonth.year, _visibleMonth.month + 1, 1);
          break;
        case _CalendarDensity.week:
          _selectedDay = _selectedDay.add(const Duration(days: 7));
          _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
          break;
        case _CalendarDensity.day:
          _selectedDay = _selectedDay.add(const Duration(days: 1));
          _visibleMonth = DateTime(_selectedDay.year, _selectedDay.month, 1);
          break;
      }
      _loadMonth();
    });
  }

  String get _headerTitle {
    if (_density == _CalendarDensity.day) {
      return '${_selectedDay.day} '
          '${_kMonthNamesShort[_selectedDay.month - 1]}, '
          '${_selectedDay.year}';
    }
    return '${_kMonthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  // ============================================================
  // AJOUTER / CHANGER UN REPAS
  // ============================================================

  Future<void> _pickRecipeForSlot(String mealType) async {
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
                      Text(
                        'Choisir une recette — '
                        '${MealPlanRepository.mealTypeLabel(mealType)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
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

    try {
      await _mealPlanRepository.setMealPlanEntry(
        date: _selectedDay,
        mealType: mealType,
        recipeId: selected.id,
      );

      if (!mounted) return;
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’ajouter au planning : $error')),
      );
    }
  }

  Future<void> _removeEntry(int entryId) async {
    try {
      await _mealPlanRepository.removeMealPlanEntry(entryId);

      if (!mounted) return;
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de retirer ce repas : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final grid = _buildMonthGrid();

    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _monthEntriesFuture,
        builder: (context, snapshot) {
          final allEntries = snapshot.data ?? [];

          final datesWithEntries = allEntries
              .map((e) => DateTime.parse(e['plan_date'].toString()))
              .toSet();

          final dayEntries = allEntries.where((entry) {
            final planDate = DateTime.parse(entry['plan_date'].toString());
            return _isSameDay(planDate, _selectedDay);
          }).toList();

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              // ================================================
              // EN-TÊTE (MOIS / SEMAINE / JOUR) + NAVIGATION
              // ================================================

              Row(
                children: [
                  Expanded(
                    child: Text(
                      _headerTitle,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: colorScheme.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _goPrevious,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  TextButton(
                    onPressed: _goToToday,
                    child: const Text('Aujourd’hui'),
                  ),
                  IconButton(
                    onPressed: _goNext,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ================================================
              // GRILLE (mois complet ou une seule semaine — rien
              // en vue "jour", pour rester compact)
              // ================================================

              if (_density != _CalendarDensity.day) ...[
                Row(
                  children: ['L', 'M', 'M', 'J', 'V', 'S', 'D'].map((label) {
                    return Expanded(
                      child: Center(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 6),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _density == _CalendarDensity.month
                      ? grid.length
                      : 7,
                  gridDelegate:
                      const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 7,
                  ),
                  itemBuilder: (context, index) {
                    final cell = _density == _CalendarDensity.month
                        ? grid[index]
                        : (
                            date: _mondayOfSelectedWeek
                                .add(Duration(days: index)),
                            isCurrentMonth: true,
                          );

                    final isSelected = _isSameDay(cell.date, _selectedDay);
                    final hasEntry = datesWithEntries.any(
                      (d) => _isSameDay(d, cell.date),
                    );

                    return InkWell(
                      onTap: () => setState(() => _selectedDay = cell.date),
                      customBorder: const CircleBorder(),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isSelected
                                    ? colorScheme.primary
                                    : Colors.transparent,
                              ),
                              child: Text(
                                '${cell.date.day}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w700
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? Colors.white
                                      : cell.isCurrentMonth
                                          ? colorScheme.onSurface
                                          : colorScheme.onSurfaceVariant
                                              .withValues(alpha: 0.4),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            SizedBox(
                              width: 5,
                              height: 5,
                              child: hasEntry
                                  ? DecoratedBox(
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: isSelected
                                            ? colorScheme.primary
                                            : colorScheme.secondary,
                                      ),
                                    )
                                  : null,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],

              const Divider(height: 32),

              // ================================================
              // JOUR SÉLECTIONNÉ
              // ================================================

              Text(
                '${_kWeekdayNamesShort[_selectedDay.weekday - 1]} '
                '${_selectedDay.day} '
                '${_kMonthNamesShort[_selectedDay.month - 1]} '
                '${_selectedDay.year}',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 12),

              ...MealPlanRepository.mealTypes.map((mealType) {
                final entry = dayEntries.firstWhere(
                  (e) => e['meal_type'] == mealType,
                  orElse: () => <String, dynamic>{},
                );

                return _MealSlot(
                  label: MealPlanRepository.mealTypeLabel(mealType),
                  entry: entry.isEmpty ? null : entry,
                  onAdd: () => _pickRecipeForSlot(mealType),
                  onRemove: entry.isEmpty
                      ? null
                      : () => _removeEntry(entry['id'] as int),
                  onOpenRecipe: entry.isEmpty
                      ? null
                      : () {
                          final recipeData =
                              entry['recipes'] as Map<String, dynamic>?;
                          if (recipeData == null) return;

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => RecipePublicViewPage(
                                recipe: RecipeModel.fromMap(recipeData),
                              ),
                            ),
                          );
                        },
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

// ============================================================
// CRÉNEAU DE REPAS (Petit-déjeuner / Déjeuner / Dîner / Collation)
// ============================================================

class _MealSlot extends StatelessWidget {
  final String label;
  final Map<String, dynamic>? entry;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;
  final VoidCallback? onOpenRecipe;

  const _MealSlot({
    required this.label,
    required this.entry,
    required this.onAdd,
    this.onRemove,
    this.onOpenRecipe,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final recipeData = entry?['recipes'] as Map<String, dynamic>?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border(
          left: BorderSide(color: colorScheme.secondary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: colorScheme.secondary,
            ),
          ),
          const SizedBox(height: 8),
          if (recipeData == null)
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter une recette'),
            )
          else
            InkWell(
              onTap: onOpenRecipe,
              borderRadius: BorderRadius.circular(10),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colorScheme.surface,
                    child: Icon(
                      recipeData['source_type'] == 'video'
                          ? Icons.play_circle_outline
                          : Icons.restaurant,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      recipeData['title']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: onRemove,
                    icon: const Icon(Icons.close, size: 18),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}