import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../../core/app_bar_leading.dart';
import '../../../core/app_drawer.dart';
import '../../../models/recipe_model.dart';
import '../../../repositories/recipe_repository.dart';

/// Mode cuisine guidé : affiche les étapes une par une, en gros,
/// avec un bouton de lecture audio (synthèse vocale) pour les
/// personnes qui ne savent pas lire ou préfèrent écouter en
/// cuisinant les mains occupées.
class CookingModePage extends StatefulWidget {
  final RecipeModel recipe;

  const CookingModePage({super.key, required this.recipe});

  @override
  State<CookingModePage> createState() => _CookingModePageState();
}

class _CookingModePageState extends State<CookingModePage> {
  final RecipeRepository _recipeRepository = RecipeRepository();
  final FlutterTts _tts = FlutterTts();

  late Future<List<Map<String, dynamic>>> _stepsFuture;

  int _currentIndex = 0;
  bool _isSpeaking = false;

  @override
  void initState() {
    super.initState();

    _stepsFuture = _recipeRepository.getRecipeSteps(widget.recipe.id);

    _tts.setLanguage('fr-FR');
    _tts.setSpeechRate(0.45);
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _isSpeaking = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    setState(() => _isSpeaking = true);
    await _tts.speak(text);
  }

  Future<void> _stopSpeaking() async {
    await _tts.stop();
    if (mounted) setState(() => _isSpeaking = false);
  }

  void _goToStep(int index) {
    _stopSpeaking();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text('Cuisiner : ${widget.recipe.title}'),
        leading: const AppBackMenuLeading(),
        leadingWidth: 96,
      ),
      body: SafeArea(
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _stepsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Text('Impossible de charger : ${snapshot.error}'),
              );
            }

            final steps = snapshot.data ?? [];

            if (steps.isEmpty) {
              return const Center(
                child: Text(
                  'Aucune étape renseignée pour cette recette.',
                ),
              );
            }

            final step = steps[_currentIndex];
            final instruction = step['instruction']?.toString() ?? '';
            final isFirst = _currentIndex == 0;
            final isLast = _currentIndex == steps.length - 1;

            return Column(
              children: [
                // ================================================
                // BARRE DE PROGRESSION DES ÉTAPES
                // ================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: List.generate(steps.length, (index) {
                      final isActive = index <= _currentIndex;

                      return Expanded(
                        child: Container(
                          height: 4,
                          margin: EdgeInsets.only(
                            right: index == steps.length - 1 ? 0 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: isActive
                                ? colorScheme.primary
                                : colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                // ================================================
                // ÉTAPE ACTUELLE (gros texte, lisible de loin)
                // ================================================

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'ÉTAPE ${_currentIndex + 1} / ${steps.length}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            instruction,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // ================================================
                // CONTRÔLES : PRÉCÉDENT / AUDIO / SUIVANT
                // ================================================

                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        iconSize: 32,
                        onPressed:
                            isFirst ? null : () => _goToStep(_currentIndex - 1),
                        icon: const Icon(Icons.skip_previous_outlined),
                      ),
                      InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () {
                          if (_isSpeaking) {
                            _stopSpeaking();
                          } else {
                            _speak(instruction);
                          }
                        },
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colorScheme.primary,
                                colorScheme.secondary,
                              ],
                            ),
                          ),
                          child: Icon(
                            _isSpeaking
                                ? Icons.stop_rounded
                                : Icons.volume_up_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                      IconButton(
                        iconSize: 32,
                        onPressed: isLast
                            ? null
                            : () => _goToStep(_currentIndex + 1),
                        icon: const Icon(Icons.skip_next_outlined),
                      ),
                    ],
                  ),
                ),

                if (isLast)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.check),
                      label: const Text('Terminé, bon appétit !'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}