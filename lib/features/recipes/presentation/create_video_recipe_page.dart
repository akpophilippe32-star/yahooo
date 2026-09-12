import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_bar_leading.dart';
import '../../../core/app_drawer.dart';
import '../../../models/recipe_model.dart';
import '../../../pages/creator/edit_recipe_page.dart';
import '../../../repositories/recipe_repository.dart';

/// Écran de création d'une recette à partir d'une vidéo déjà
/// présente sur l'appareil du créateur.
///
/// Ne fait volontairement pas de lecteur vidéo intégré ni de design
/// poussé : le but ici est juste de rendre le flux fonctionnel de
/// bout en bout (import → brouillon → IA ou non → édition/publication),
/// le front sera retravaillé plus tard.
class CreateVideoRecipePage extends StatefulWidget {
  const CreateVideoRecipePage({super.key});

  @override
  State<CreateVideoRecipePage> createState() =>
      _CreateVideoRecipePageState();
}

class _CreateVideoRecipePageState extends State<CreateVideoRecipePage> {
  final _formKey = GlobalKey<FormState>();
  final RecipeRepository _recipeRepository = RecipeRepository();
  final ImagePicker _imagePicker = ImagePicker();

  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController =
      TextEditingController();

  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  int? _selectedCategoryId;

  XFile? _selectedVideo;
  bool _isLoading = false;
  bool _isExiting = false;
  bool? _isRequestingAiAnalysis;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = _recipeRepository.getCategoriesForEdit();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHOISIR UNE VIDÉO DANS LA GALERIE
  // ============================================================

  Future<void> _pickVideo() async {
    final XFile? video = await _imagePicker.pickVideo(
      source: ImageSource.gallery,
    );

    if (video == null) {
      return;
    }

    setState(() {
      _selectedVideo = video;
    });
  }

  // ============================================================
  // CRÉER LE BROUILLON VIDÉO (avec ou sans demande d'analyse IA)
  // ============================================================

  Future<void> _createVideoRecipe({required bool requestAiAnalysis}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisis d’abord une vidéo.'),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _isRequestingAiAnalysis = requestAiAnalysis;
    });

    try {
      final Uint8List bytes = await _selectedVideo!.readAsBytes();

      final extension =
          _selectedVideo!.name.split('.').last.toLowerCase();

      // ============================================================
      // ENVOI DE LA VIDÉO
      // ============================================================
      //
      // .timeout(...) : sans ça, si la requête réseau ne répond
      // jamais (ni succès, ni erreur), le bouton reste bloqué à
      // vie sur "chargement" sans aucun message. Avec le timeout,
      // ça échoue proprement après un délai raisonnable et
      // l'utilisateur est prévenu. Délai généreux (4 min) car
      // l'envoi d'une vidéo peut être lent, surtout sur mobile.

      final videoPath = await _recipeRepository
          .uploadRecipeVideo(
            bytes: bytes,
            fileExtension: extension,
          )
          .timeout(
            const Duration(minutes: 4),
            onTimeout: () => throw Exception(
              'L’envoi de la vidéo a pris trop de temps '
              '(vérifie ta connexion, ou essaie avec une vidéo '
              'plus courte).',
            ),
          );

      // ============================================================
      // CRÉATION DE LA RECETTE EN BROUILLON
      // ============================================================

      final recipeMap = await _recipeRepository
          .createVideoDraft(
            title: _titleController.text.trim(),
            videoPath: videoPath,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            categoryId: _selectedCategoryId,
          )
          .timeout(
            const Duration(seconds: 60),
            onTimeout: () => throw Exception(
              'La création de la recette a pris trop de temps '
              '(vérifie ta connexion et réessaie).',
            ),
          );

      final recipe = RecipeModel.fromMap(recipeMap);

      // ============================================================
      // ANALYSE IA (optionnelle)
      // ============================================================

      if (requestAiAnalysis) {
        await _recipeRepository.requestVideoAnalysis(recipe.id);
      } else {
        await _recipeRepository.skipVideoAnalysis(recipe.id);
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            requestAiAnalysis
                ? 'Vidéo importée. L’analyse IA sera branchée '
                    'prochainement — tu peux déjà compléter la '
                    'recette manuellement en attendant.'
                : 'Vidéo importée. Complète la recette pour '
                    'pouvoir la publier.',
          ),
        ),
      );

      // On enchaîne sur l'écran d'édition existant pour compléter
      // catégorie / difficulté / ingrédients / étapes, puis publier
      // — même flux que pour une recette manuelle.
      //
      // Important : on utilise push() (pas pushReplacement) puis on
      // se repop nous-mêmes juste après, pour que le "await" fait
      // par Home au moment d'ouvrir cet écran ne se termine QUE
      // lorsque tout le flux (édition + publication) est vraiment
      // fini. Avec pushReplacement, Home croyait que c'était terminé
      // dès la création du brouillon vidéo, et rafraîchissait sa
      // liste trop tôt — la recette publiée plus tard n'apparaissait
      // alors jamais sans rafraîchissement manuel.
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditRecipePage(recipe: recipe),
        ),
      );

      if (!mounted) return;

      _isExiting = true;
      Navigator.of(context).pop(result);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de créer la recette vidéo : $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isRequestingAiAnalysis = null;
        });
      }
    }
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _isExiting,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExitAttempt();
      },
      child: Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Créer une recette à partir d’une vidéo'),
        leading: AppBackMenuLeading(onBack: _handleExitAttempt),
        leadingWidth: 96,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Choisis une vidéo déjà présente sur ton téléphone. '
                'Tu pourras compléter les ingrédients et les étapes '
                'ensuite, avec ou sans l’aide de l’IA.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // ========================================================
              // SÉLECTION DE LA VIDÉO
              // ========================================================

              InkWell(
                onTap: _isLoading ? null : _pickVideo,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: _selectedVideo == null
                            ? Theme.of(context).colorScheme.surface
                            : Theme.of(context).colorScheme.primary,
                        child: Icon(
                          _selectedVideo == null
                              ? Icons.video_call_outlined
                              : Icons.check,
                          color: _selectedVideo == null
                              ? Theme.of(context).colorScheme.onSurfaceVariant
                              : Colors.white,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _selectedVideo == null
                                  ? 'Choisir une vidéo'
                                  : 'Vidéo sélectionnée',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (_selectedVideo != null)
                              Text(
                                _selectedVideo!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ========================================================
              // TITRE
              // ========================================================

              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Titre de la recette',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Le titre est obligatoire.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ========================================================
              // DESCRIPTION
              // ========================================================

              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Description (facultatif)',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              // ========================================================
              // CATÉGORIE
              // ========================================================

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) {
                    return const InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Catégorie (facultatif)',
                        border: OutlineInputBorder(),
                      ),
                      child: SizedBox(
                        height: 24,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final categories = snapshot.data ?? [];

                  if (categories.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  return DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie (facultatif)',
                      border: OutlineInputBorder(),
                    ),
                    items: categories.map((category) {
                      return DropdownMenuItem<int>(
                        value: category['id'] as int,
                        child: Text(category['name'] as String),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                  );
                },
              ),

              const SizedBox(height: 32),

              // ========================================================
              // ACTIONS
              // ========================================================

              FilledButton.icon(
                onPressed: () {
                  if (_isLoading) return;
                  _createVideoRecipe(requestAiAnalysis: true);
                },
                icon: _isRequestingAiAnalysis == true
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.auto_awesome_outlined),
                label: const Text(
                  'Créer et analyser avec l’IA',
                ),
              ),

              const SizedBox(height: 12),

              OutlinedButton.icon(
                onPressed: () {
                  if (_isLoading) return;
                  _createVideoRecipe(requestAiAnalysis: false);
                },
                icon: _isRequestingAiAnalysis == false
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.edit_note_outlined),
                label: const Text(
                  'Créer sans analyse IA (je complète moi-même)',
                ),
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  // ============================================================
  // SORTIE DE L'ÉCRAN : BROUILLON VIDÉO AUTOMATIQUE
  // ============================================================

  /// Appelé quand l'utilisateur essaie de quitter l'écran sans avoir
  /// cliqué un des deux boutons de création. Si un titre ET une
  /// vidéo ont été choisis, on envoie/enregistre silencieusement un
  /// brouillon (sans analyse IA, c'est le choix par défaut pour une
  /// sortie non explicite) avant de laisser sortir.
  Future<void> _handleExitAttempt() async {
    if (_titleController.text.trim().isEmpty || _selectedVideo == null) {
      // Rien d'assez significatif à sauvegarder.
      _isExiting = true;
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (_isLoading) {
      // Une opération est déjà en cours, on la laisse terminer.
      return;
    }

    setState(() {
      _isLoading = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enregistrement du brouillon vidéo...'),
        duration: Duration(seconds: 2),
      ),
    );

    try {
      final Uint8List bytes = await _selectedVideo!.readAsBytes();

      final extension =
          _selectedVideo!.name.split('.').last.toLowerCase();

      final videoPath = await _recipeRepository
          .uploadRecipeVideo(
            bytes: bytes,
            fileExtension: extension,
          )
          .timeout(const Duration(minutes: 4));

      final recipeMap = await _recipeRepository
          .createVideoDraft(
            title: _titleController.text.trim(),
            videoPath: videoPath,
            description: _descriptionController.text.trim().isEmpty
                ? null
                : _descriptionController.text.trim(),
            categoryId: _selectedCategoryId,
          )
          .timeout(const Duration(seconds: 60));

      final recipe = RecipeModel.fromMap(recipeMap);

      await _recipeRepository.skipVideoAnalysis(recipe.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Brouillon vidéo enregistré.'),
        ),
      );

      _isExiting = true;
      Navigator.of(context).pop();
    } catch (error) {
      // On ne force pas la sortie en cas d'échec : on reste sur
      // l'écran pour ne pas perdre le travail (la vidéo choisie
      // reste en mémoire, l'utilisateur peut réessayer).
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d’enregistrer le brouillon vidéo : $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}