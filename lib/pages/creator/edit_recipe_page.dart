import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_bar_leading.dart';
import '../../core/app_drawer.dart';
import '../../models/recipe_model.dart';
import '../../repositories/recipe_repository.dart';
import '../../widgets/recipe_video_player.dart';

class EditRecipePage extends StatefulWidget {
  final RecipeModel recipe;

  const EditRecipePage({
    super.key,
    required this.recipe,
  });

  @override
  State<EditRecipePage> createState() => _EditRecipePageState();
}

class _EditRecipePageState extends State<EditRecipePage> {
  final _formKey = GlobalKey<FormState>();
  

  final RecipeRepository _recipeRepository = RecipeRepository();

  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedRecipeImage;
  Uint8List? _selectedRecipeImageBytes;

  bool _removeRecipeImage = false;

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _dietTypeController;
  late final TextEditingController _prepTimeController;
  late final TextEditingController _cookTimeController;
  late final TextEditingController _servingsController;
  late final TextEditingController _caloriesController;
  late final TextEditingController _carbsController;
  late final TextEditingController _fatController;
  late final TextEditingController _proteinController;

  late String? _selectedDifficulty;
  late int? _selectedCategoryId;

  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  late Future<List<Map<String, dynamic>>> _ingredientsFuture;

  late Future<List<Map<String, dynamic>>> _stepsFuture;

  // Étapes actuellement affichées dans la recette
  List<Map<String, dynamic>> _editableSteps = [];

  // Contrôleur pour ajouter/modifier une étape
  final TextEditingController _stepInstructionController =
      TextEditingController();

  bool _isLoading = false;
    // Ingrédients disponibles dans le catalogue
  late Future<List<Map<String, dynamic>>> _availableIngredientsFuture;

  // Ingrédients actuellement affichés dans la recette
  List<Map<String, dynamic>> _editableIngredients = [];
  final TextEditingController _quantityController =
      TextEditingController();
  final TextEditingController _unitController =
      TextEditingController();

  final List<String> _difficulties = [
    'easy',
    'medium',
    'hard',
  ];

  @override
  void initState() {
    super.initState();

    // ============================================================
    // PRÉREMPLISSAGE DES CHAMPS
    // ============================================================

    _titleController = TextEditingController(
      text: widget.recipe.title,
    );

    _descriptionController = TextEditingController(
      text: widget.recipe.description ?? '',
    );

    _dietTypeController = TextEditingController(
      text: widget.recipe.dietType ?? '',
    );

    _prepTimeController = TextEditingController(
      text: widget.recipe.prepTime?.toString() ?? '',
    );

    _cookTimeController = TextEditingController(
      text: widget.recipe.cookTime?.toString() ?? '',
    );

    _servingsController = TextEditingController(
      text: widget.recipe.servings?.toString() ?? '',
    );

    _caloriesController = TextEditingController(
      text: widget.recipe.caloriesKcal?.toString() ?? '',
    );

    _carbsController = TextEditingController(
      text: widget.recipe.carbsG?.toString() ?? '',
    );

    _fatController = TextEditingController(
      text: widget.recipe.fatG?.toString() ?? '',
    );

    _proteinController = TextEditingController(
      text: widget.recipe.proteinG?.toString() ?? '',
    );

    _selectedDifficulty = widget.recipe.difficulty;

    _selectedCategoryId = widget.recipe.categoryId;

    // ============================================================
    // CHARGEMENT DES CATÉGORIES
    // ============================================================

    _categoriesFuture = _loadCategories();
    _ingredientsFuture = _loadIngredients();
    _availableIngredientsFuture =
        _recipeRepository.getIngredients();
    _stepsFuture = _loadSteps();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dietTypeController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();
    _caloriesController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _proteinController.dispose();
    _quantityController.dispose();
    _unitController.dispose();
    _stepInstructionController.dispose();

    super.dispose();
  }

  // ============================================================
  // CHARGER LES CATÉGORIES
  // ============================================================

  Future<List<Map<String, dynamic>>> _loadCategories() async {
    final response = await _recipeRepository.getCategoriesForEdit();

    return response;
  }

  // ============================================================
// CHARGER LES INGRÉDIENTS
// ============================================================

Future<List<Map<String, dynamic>>> _loadIngredients() async {
  final ingredients = await _recipeRepository.getRecipeIngredients(
    widget.recipe.id,
  );

  _editableIngredients = ingredients
      .map(
        (item) => Map<String, dynamic>.from(item),
      )
      .toList();

  return _editableIngredients;
}
// ============================================================
// CHARGER LES ÉTAPES
// ============================================================

Future<List<Map<String, dynamic>>> _loadSteps() async {
  final steps = await _recipeRepository.getRecipeSteps(
    widget.recipe.id,
  );

  _editableSteps = steps
      .map(
        (step) => Map<String, dynamic>.from(step),
      )
      .toList();

  return _editableSteps;
}

  // ============================================================
  // ENREGISTRER LES MODIFICATIONS
  // ============================================================

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _persistFormChanges();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La recette a été modifiée avec succès.',
          ),
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de modifier la recette : $error',
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

  /// Enregistre l'état actuel du formulaire en base (image, titre,
  /// catégorie, difficulté, nutrition...) — sans notification ni
  /// navigation, pour être réutilisable à la fois par "Enregistrer"
  /// et par "Publier" (qui doit d'abord sauvegarder les derniers
  /// changements avant de vérifier que rien n'est manquant).
  Future<void> _persistFormChanges() async {
    String? imageUrl = widget.recipe.imageUrl;

    // ============================================================
    // NOUVELLE IMAGE
    // ============================================================

    if (_selectedRecipeImage != null &&
        _selectedRecipeImageBytes != null) {
      final user = Supabase.instance.client.auth.currentUser;

      if (user == null) {
        throw Exception('Utilisateur non connecté.');
      }

      final extension = _selectedRecipeImage!.name
          .split('.')
          .last
          .toLowerCase();

      final imagePath =
          '${user.id}/recipe_${widget.recipe.id}_${DateTime.now().millisecondsSinceEpoch}.$extension';

      await Supabase.instance.client.storage
          .from('recipe-images')
          .uploadBinary(
            imagePath,
            _selectedRecipeImageBytes!,
            fileOptions: const FileOptions(
              upsert: true,
            ),
          );

      imageUrl = imagePath;
    }

    // ============================================================
    // SUPPRESSION DE L'IMAGE
    // ============================================================

    if (_removeRecipeImage) {
      imageUrl = null;
    }

    // ============================================================
    // MISE À JOUR DE LA RECETTE
    // ============================================================

    await _recipeRepository.updateRecipe(
      recipeId: widget.recipe.id,
      title: _titleController.text.trim(),
      description:
          _descriptionController.text.trim().isEmpty
              ? null
              : _descriptionController.text.trim(),
      categoryId: _selectedCategoryId,
      prepTime: int.tryParse(
        _prepTimeController.text.trim(),
      ),
      cookTime: int.tryParse(
        _cookTimeController.text.trim(),
      ),
      servings: int.tryParse(
        _servingsController.text.trim(),
      ),
      difficulty: _selectedDifficulty,
      dietType:
          _dietTypeController.text.trim().isEmpty
              ? null
              : _dietTypeController.text.trim(),
      imageUrl: imageUrl,
      caloriesKcal: int.tryParse(_caloriesController.text.trim()),
      carbsG: double.tryParse(
        _carbsController.text.trim().replaceAll(',', '.'),
      ),
      fatG: double.tryParse(
        _fatController.text.trim().replaceAll(',', '.'),
      ),
      proteinG: double.tryParse(
        _proteinController.text.trim().replaceAll(',', '.'),
      ),
    );
  }
    // ============================================================
  // PUBLIER LA RECETTE
  // ============================================================

  /// Fait passer la recette du statut "draft" à "published".
  ///
  /// Sauvegarde d'abord les derniers changements du formulaire
  /// (catégorie, difficulté, etc.) — sans ça, la vérification des
  /// informations obligatoires se basait sur les anciennes valeurs
  /// encore en base, et refusait à tort de publier en réclamant des
  /// informations pourtant déjà remplies à l'écran.
  Future<void> _publishRecipe() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _persistFormChanges();
      await _recipeRepository.publishRecipe(widget.recipe.id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La recette a été publiée avec succès.',
          ),
        ),
      );

      // On repasse `true` pour que les écrans précédents
      // (liste, détail) rafraîchissent leurs données.
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de publier la recette : $error',
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

  // ============================================================
  // MODIFIER UN INGRÉDIENT
  // ============================================================

  Future<void> _showEditIngredientDialog(
    Map<String, dynamic> item,
  ) async {
    final ingredientId = item['ingredient_id'] as int?;
    final recipeIngredientId = item['id'] as int?;

    if (ingredientId == null || recipeIngredientId == null) {
      return;
    }

    final quantityController = TextEditingController(
      text: item['quantity']?.toString() ?? '',
    );

    final unitController = TextEditingController(
      text: item['unit']?.toString() ?? '',
    );

    bool isOptional = item['optional'] == true;

    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Modifier l’ingrédient'),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ==================================================
                      // NOM DE L'INGRÉDIENT
                      // ==================================================

                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _ingredientName(item),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // ==================================================
                      // QUANTITÉ
                      // ==================================================

                      TextField(
                        controller: quantityController,
                        keyboardType:
                            const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Quantité',
                          hintText: 'Ex. 200',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==================================================
                      // UNITÉ
                      // ==================================================

                      TextField(
                        controller: unitController,
                        decoration: const InputDecoration(
                          labelText: 'Unité',
                          hintText: 'Ex. g, kg, ml, pièce...',
                          border: OutlineInputBorder(),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ==================================================
                      // FACULTATIF
                      // ==================================================

                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Facultatif'),
                        value: isOptional,
                        onChanged: (value) {
                          setDialogState(() {
                            isOptional = value ?? false;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(false);
                    },
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop(true);
                    },
                    child: const Text('Enregistrer'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result != true) {
        return;
      }

      final quantityText =
          quantityController.text.trim();

      final unit =
          unitController.text.trim();

      final quantity = quantityText.isEmpty
          ? null
          : double.tryParse(
              quantityText.replaceAll(',', '.'),
            );

      if (quantityText.isNotEmpty && quantity == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'La quantité saisie est invalide.',
            ),
          ),
        );

        return;
      }

      await _recipeRepository.updateRecipeIngredient(
        recipeIngredientId: recipeIngredientId,
        quantity: quantity,
        unit: unit.isEmpty ? null : unit,
        optional: isOptional,
      );

      final ingredients =
          await _recipeRepository.getRecipeIngredients(
        widget.recipe.id,
      );

      if (!mounted) return;

      setState(() {
        _editableIngredients = ingredients
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ingrédient modifié avec succès.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de modifier l’ingrédient : $error',
          ),
        ),
      );
    } finally {
      quantityController.dispose();
      unitController.dispose();
    }
  }

  // ============================================================
  // NOM D'UN INGRÉDIENT
  // ============================================================

  String _ingredientName(
    Map<String, dynamic> item,
  ) {
    final ingredient = item['ingredients'];

    if (ingredient is Map<String, dynamic>) {
      return ingredient['name']?.toString() ??
          'Ingrédient';
    }

    return 'Ingrédient';
  }
    // ============================================================
  // SUPPRIMER UN INGRÉDIENT
  // ============================================================

  Future<void> _deleteIngredient(
    Map<String, dynamic> item,
  ) async {
    final recipeIngredientId = item['id'] as int?;

    if (recipeIngredientId == null) {
      return;
    }

    final ingredientName = _ingredientName(item);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer l’ingrédient ?'),
          content: Text(
            'Voulez-vous vraiment supprimer « $ingredientName » '
            'de cette recette ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _recipeRepository.deleteRecipeIngredient(
        recipeIngredientId,
      );

      final ingredients =
          await _recipeRepository.getRecipeIngredients(
        widget.recipe.id,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _editableIngredients = ingredients
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '« $ingredientName » a été supprimé.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de supprimer l’ingrédient : $error',
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
  Future<void> _pickRecipeImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();

    if (!mounted) {
      return;
    }

    setState(() {
      _selectedRecipeImage = image;
      _selectedRecipeImageBytes = bytes;
      _removeRecipeImage = false;
    });
  }
  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Modifier la recette'),
        leading: const AppBackMenuLeading(),
        leadingWidth: 96,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Modifier la recette',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Modifie les informations de ta recette.',
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
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              // ========================================================
              // VIDÉO DE LA RECETTE (uniquement pour une recette
              // créée à partir d'une vidéo importée)
              // ========================================================

              if (widget.recipe.sourceType == 'video' &&
                  widget.recipe.videoUrl != null &&
                  widget.recipe.videoUrl!.isNotEmpty) ...[
                const Text(
                  'Vidéo de la recette',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                RecipeVideoPlayer(
                  videoPath: widget.recipe.videoUrl!,
                ),
                const SizedBox(height: 20),
              ],

              // ========================================================
              // IMAGE DE LA RECETTE
              // ========================================================
              //
              // Inutile pour une recette vidéo : le contenu principal
              // est déjà la vidéo (affichée ci-dessus).
              if (widget.recipe.sourceType != 'video') ...[
                const Text(
                  'Image de la recette',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 12),

                Container(
                  height: 220,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _selectedRecipeImageBytes != null
                      // Nouvelle image choisie localement : pas besoin
                      // d'URL signée, on affiche directement les bytes.
                      ? Image.memory(
                          _selectedRecipeImageBytes!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        )
                      : (!_removeRecipeImage &&
                              widget.recipe.imageUrl != null &&
                              widget.recipe.imageUrl!.isNotEmpty)
                          // Image existante : le champ imageUrl contient
                          // un CHEMIN de stockage (bucket privé), pas une
                          // URL publique. Il faut donc demander une URL
                          // signée avant de pouvoir l'afficher.
                          ? FutureBuilder<String?>(
                              future: _recipeRepository.getRecipeImageUrl(
                                widget.recipe.imageUrl,
                              ),
                              builder: (context, snapshot) {
                                if (snapshot.connectionState ==
                                    ConnectionState.waiting) {
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }

                                final signedUrl = snapshot.data;

                                if (signedUrl == null ||
                                    signedUrl.isEmpty) {
                                  return const Center(
                                    child: Text(
                                      'Impossible de charger l’image actuelle.',
                                    ),
                                  );
                                }

                                return Image.network(
                                  signedUrl,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                  errorBuilder: (
                                    context,
                                    error,
                                    stackTrace,
                                  ) {
                                    return const Center(
                                      child: Text(
                                        'Impossible de charger l’image actuelle.',
                                      ),
                                    );
                                  },
                                );
                              },
                            )
                          : const Center(
                              child: Text(
                                'Aucune image pour cette recette.',
                              ),
                            ),
                ),

                const SizedBox(height: 12),

                OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : _pickRecipeImage,
                  icon: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  label: Text(
                    _selectedRecipeImage == null
                        ? 'Choisir une image'
                        : 'Changer l’image',
                  ),
                ),

                if (_selectedRecipeImage != null ||
                    (widget.recipe.imageUrl != null &&
                        widget.recipe.imageUrl!.isNotEmpty))
                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _selectedRecipeImage = null;
                              _removeRecipeImage = true;
                            });
                          },
                    icon: const Icon(
                      Icons.delete_outline,
                    ),
                    label: const Text(
                      'Supprimer l’image',
                    ),
                  ),

                const SizedBox(height: 20),
              ],

              // ========================================================
              // CATÉGORIE
              // ========================================================

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _categoriesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Catégorie',
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

                  if (snapshot.hasError) {
                    return Text(
                      'Impossible de charger les catégories : '
                      '${snapshot.error}',
                    );
                  }

                  final categories = snapshot.data ?? [];

                  if (categories.isEmpty) {
                    return const InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Catégorie',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(
                        'Aucune catégorie disponible.',
                      ),
                    );
                  }

                  return DropdownButtonFormField<int>(
                    initialValue: _selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Catégorie',
                      border: OutlineInputBorder(),
                    ),
                    items: categories.map((category) {
                      return DropdownMenuItem<int>(
                        value: category['id'] as int,
                        child: Text(
                          category['name'] as String,
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategoryId = value;
                      });
                    },
                    validator: (value) {
                      if (value == null) {
                        return 'Sélectionne une catégorie.';
                      }
                      return null;
                    },
                  );
                },
              ),

              const SizedBox(height: 20),

              // ========================================================
              // DIFFICULTÉ
              // ========================================================

              DropdownButtonFormField<String>(
                initialValue: _selectedDifficulty,
                decoration: const InputDecoration(
                  labelText: 'Difficulté',
                  border: OutlineInputBorder(),
                ),
                items: _difficulties.map((difficulty) {
                  return DropdownMenuItem<String>(
                    value: difficulty,
                    child: Text(
                      _difficultyLabel(difficulty),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedDifficulty = value;
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Sélectionne une difficulté.';
                  }
                  return null;
                },
              ),

              const SizedBox(height: 20),

              // ========================================================
              // TYPE ALIMENTAIRE
              // ========================================================

              TextFormField(
                controller: _dietTypeController,
                decoration: const InputDecoration(
                  labelText: 'Type alimentaire',
                  hintText: 'Ex. Végétarien',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 20),

              // ========================================================
              // TEMPS
              // ========================================================

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _prepTimeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Préparation',
                        suffixText: 'min',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateOptionalPositiveNumber,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cookTimeController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Cuisson',
                        suffixText: 'min',
                        border: OutlineInputBorder(),
                      ),
                      validator: _validateOptionalPositiveNumber,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // ========================================================
              // PORTIONS
              // ========================================================

              TextFormField(
                controller: _servingsController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Nombre de portions',
                  border: OutlineInputBorder(),
                ),
                validator: _validateOptionalServings,
              ),

              const SizedBox(height: 32),

              // ========================================================
              // NUTRITION (facultatif, par portion)
              // ========================================================

              const Text(
                'Nutrition (facultatif, par portion)',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: _caloriesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Calories',
                  suffixText: 'kcal',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _carbsController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Glucides',
                        suffixText: 'g',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _fatController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Lipides',
                        suffixText: 'g',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _proteinController,
                      keyboardType:
                          const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Protéines',
                        suffixText: 'g',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // ========================================================
              // INGRÉDIENTS
              // ========================================================

              const Text(
                'Ingrédients',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _ingredientsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Text(
                      'Impossible de charger les ingrédients : '
                      '${snapshot.error}',
                    );
                  }

                  final ingredients = snapshot.data ?? [];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (ingredients.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'Aucun ingrédient enregistré pour cette recette.',
                          ),
                        )
                      else
                        ...ingredients.map((item) {
                          final ingredient = item['ingredients'];

                          final String name =
                              ingredient is Map<String, dynamic>
                                  ? ingredient['name']?.toString() ??
                                      'Ingrédient'
                                  : 'Ingrédient';

                          final String quantity =
                              item['quantity']?.toString() ?? '';

                          final String unit =
                              item['unit']?.toString() ?? '';

                          final bool optional =
                              item['optional'] == true;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: const Icon(
                                Icons.restaurant_menu,
                              ),
                              title: Text(name),
                              subtitle: Text(
                                [
                                  if (quantity.isNotEmpty) quantity,
                                  if (unit.isNotEmpty) unit,
                                  if (optional) 'Facultatif',
                                ].join(' '),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                    ),
                                    tooltip: 'Modifier',
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            _showEditIngredientDialog(item);
                                          },
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                    ),
                                    tooltip: 'Supprimer',
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            _deleteIngredient(item);
                                          },
                                  ),
                                ],
                              ),
                            ),
                          );
                        }),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : _showAddIngredientDialog,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Ajouter un ingrédient',
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // ========================================================
              // ÉTAPES DE PRÉPARATION
              // ========================================================

              const Text(
                'Étapes de préparation',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 12),

              FutureBuilder<List<Map<String, dynamic>>>(
                future: _stepsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }

                  if (snapshot.hasError) {
                    return Text(
                      'Impossible de charger les étapes : '
                      '${snapshot.error}',
                    );
                  }

                  final steps = snapshot.data ?? [];

                  if (steps.isEmpty) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Aucune étape enregistrée pour cette recette.',
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: _isLoading
                              ? null
                              : _showAddStepDialog,
                          icon: const Icon(Icons.add),
                          label: const Text(
                            'Ajouter une étape',
                          ),
                        ),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ReorderableListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: steps.length,
                        onReorder: _isLoading
                            ? (_, __) {}
                            : _reorderSteps,
                        itemBuilder: (context, index) {
                          final step = steps[index];

                          final int stepId =
                              step['id'] as int;

                          final int stepNumber =
                              index + 1;

                          final String instruction =
                              step['instruction']?.toString() ?? '';

                          return Card(
                            key: ValueKey(stepId),
                            margin: const EdgeInsets.only(bottom: 10),
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(
                                  '$stepNumber',
                                ),
                              ),
                              title: Text(
                                'Étape $stepNumber',
                              ),
                              subtitle: Text(
                                instruction,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.drag_handle,
                                  ),
                                  IconButton(
                                    tooltip: 'Modifier',
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                    ),
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            _showEditStepDialog(
                                              stepId: stepId,
                                              stepNumber: stepNumber,
                                              instruction: instruction,
                                            );
                                          },
                                  ),
                                  IconButton(
                                    tooltip: 'Supprimer',
                                    icon: const Icon(
                                      Icons.delete_outline,
                                    ),
                                    onPressed: _isLoading
                                        ? null
                                        : () {
                                            _confirmDeleteStep(
                                              stepId,
                                              stepNumber,
                                            );
                                          },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _isLoading
                            ? null
                            : _showAddStepDialog,
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'Ajouter une étape',
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 32),

              // ========================================================
              // ENREGISTRER
              // ========================================================

              FilledButton.icon(
                onPressed: _isLoading
                    ? null
                    : _saveChanges,
                icon: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.save_outlined,
                      ),
                label: Text(
                  _isLoading
                      ? 'Enregistrement...'
                      : 'Enregistrer les modifications',
                ),
              ),

              // ========================================================
              // PUBLIER LA RECETTE (brouillon → publiée)
              // ========================================================

              if (widget.recipe.status != 'published') ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : _publishRecipe,
                  icon: const Icon(
                    Icons.publish_outlined,
                  ),
                  label: const Text(
                    'Publier la recette',
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

    // ============================================================
  // AJOUTER UN INGRÉDIENT
  // ============================================================

  Future<void> _showAddIngredientDialog() async {
    int? selectedIngredientId;
    final quantityController = TextEditingController();
    final unitController = TextEditingController();
    bool isOptional = false;

    try {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              return AlertDialog(
                title: const Text('Ajouter un ingrédient'),
                content: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _availableIngredientsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const SizedBox(
                        width: 300,
                        height: 100,
                        child: Center(
                          child: CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Text(
                        'Impossible de charger les ingrédients : '
                        '${snapshot.error}',
                      );
                    }

                    final ingredients = snapshot.data ?? [];

                    if (ingredients.isEmpty) {
                      return const Text(
                        'Aucun ingrédient disponible dans le catalogue.',
                      );
                    }

                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          DropdownButtonFormField<int>(
                            initialValue: selectedIngredientId,
                            decoration: const InputDecoration(
                              labelText: 'Ingrédient',
                              border: OutlineInputBorder(),
                            ),
                            items: ingredients.map((ingredient) {
                              return DropdownMenuItem<int>(
                                value: ingredient['id'] as int,
                                child: Text(
                                  ingredient['name']?.toString() ??
                                      'Ingrédient',
                                ),
                              );
                            }).toList(),
                            onChanged: (value) {
                              setDialogState(() {
                                selectedIngredientId = value;
                              });
                            },
                          ),

                          const SizedBox(height: 16),

                          TextField(
                            controller: quantityController,
                            keyboardType:
                                const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Quantité',
                              hintText: 'Ex. 200',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 16),

                          TextField(
                            controller: unitController,
                            decoration: const InputDecoration(
                              labelText: 'Unité',
                              hintText: 'Ex. g, kg, ml, pièce...',
                              border: OutlineInputBorder(),
                            ),
                          ),

                          const SizedBox(height: 8),

                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Facultatif'),
                            value: isOptional,
                            onChanged: (value) {
                              setDialogState(() {
                                isOptional = value ?? false;
                              });
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                    },
                    child: const Text('Annuler'),
                  ),
                  FilledButton(
                    onPressed: () {
                      if (selectedIngredientId == null) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Sélectionne un ingrédient.',
                            ),
                          ),
                        );
                        return;
                      }

                      Navigator.of(dialogContext).pop({
                        'ingredient_id': selectedIngredientId,
                        'quantity':
                            quantityController.text.trim(),
                        'unit': unitController.text.trim(),
                        'optional': isOptional,
                      });
                    },
                    child: const Text('Ajouter'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (result == null) {
        return;
      }

      final ingredientId = result['ingredient_id'] as int;

      final quantityText =
          result['quantity']?.toString().trim() ?? '';

      final unit =
          result['unit']?.toString().trim() ?? '';

      final optional =
          result['optional'] == true;

      final quantity = quantityText.isEmpty
          ? null
          : double.tryParse(
              quantityText.replaceAll(',', '.'),
            );

      if (quantityText.isNotEmpty && quantity == null) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('La quantité saisie est invalide.'),
          ),
        );

        return;
      }

      // Empêcher d'ajouter deux fois le même ingrédient.
      final alreadyExists = _editableIngredients.any(
        (item) => item['ingredient_id'] == ingredientId,
      );

      if (alreadyExists) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Cet ingrédient est déjà présent dans la recette.',
            ),
          ),
        );

        return;
      }

      await _recipeRepository.addRecipeIngredient(
        recipeId: widget.recipe.id,
        ingredientId: ingredientId,
        quantity: quantity,
        unit: unit.isEmpty ? null : unit,
        optional: optional,
      );

      final ingredients =
          await _recipeRepository.getRecipeIngredients(
        widget.recipe.id,
      );

      if (!mounted) return;

      setState(() {
        _editableIngredients = ingredients
            .map(
              (item) => Map<String, dynamic>.from(item),
            )
            .toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ingrédient ajouté avec succès.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d’ajouter l’ingrédient : $error',
          ),
        ),
      );
    } finally {
      quantityController.dispose();
      unitController.dispose();
    }
  }
  
  // ============================================================
  // VALIDATION TEMPS
  // ============================================================

  String? _validateOptionalPositiveNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final number = int.tryParse(value.trim());

    if (number == null || number < 0) {
      return 'Valeur invalide';
    }

    return null;
  }

  // ============================================================
  // VALIDATION PORTIONS
  // ============================================================

  String? _validateOptionalServings(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final number = int.tryParse(value.trim());

    if (number == null || number <= 0) {
      return 'Nombre de portions invalide';
    }

    return null;
  }

  // ============================================================
  // DIFFICULTÉ
  // ============================================================

  String _difficultyLabel(String difficulty) {
    switch (difficulty) {
      case 'easy':
        return 'Facile';

      case 'medium':
        return 'Moyenne';

      case 'hard':
        return 'Difficile';

      default:
        return difficulty;
    }
  }
  // ============================================================
  // SUPPRIMER UNE ÉTAPE
  // ============================================================

  Future<void> _confirmDeleteStep(
    int stepId,
    int stepNumber,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Supprimer l’étape ?'),
          content: Text(
            'Veux-tu vraiment supprimer l’étape $stepNumber ?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('Supprimer'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _recipeRepository.deleteRecipeStep(stepId);

      final steps = await _recipeRepository.getRecipeSteps(
        widget.recipe.id,
      );

      if (!mounted) return;

      setState(() {
        _editableSteps = steps
            .map((step) => Map<String, dynamic>.from(step))
            .toList();
        _stepsFuture = Future.value(_editableSteps);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L’étape a été supprimée avec succès.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de supprimer l’étape : $error',
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

  // ============================================================
  // MODIFIER UNE ÉTAPE
  // ============================================================

  Future<void> _showEditStepDialog({
    required int stepId,
    required int stepNumber,
    required String instruction,
  }) async {
    final controller = TextEditingController(
      text: instruction,
    );

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              'Modifier l’étape $stepNumber',
            ),
            content: TextField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Instruction',
                hintText: 'Décris cette étape...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();

                  if (value.isEmpty) {
                    return;
                  }

                  Navigator.of(dialogContext).pop(value);
                },
                child: const Text('Enregistrer'),
              ),
            ],
          );
        },
      );

      if (result == null || result.trim().isEmpty) {
        return;
      }

      setState(() {
        _isLoading = true;
      });

      await _recipeRepository.updateRecipeStep(
        stepId: stepId,
        instruction: result.trim(),
      );

      final steps = await _recipeRepository.getRecipeSteps(
        widget.recipe.id,
      );

      if (!mounted) return;

      setState(() {
        _editableSteps = steps
            .map((step) => Map<String, dynamic>.from(step))
            .toList();
        _stepsFuture = Future.value(_editableSteps);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L’étape a été modifiée avec succès.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de modifier l’étape : $error',
          ),
        ),
      );
    } finally {
      controller.dispose();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // AJOUTER UNE ÉTAPE
  // ============================================================

  Future<void> _showAddStepDialog() async {
    final controller = TextEditingController();

    try {
      final result = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text(
              'Ajouter une étape',
            ),
            content: TextField(
              controller: controller,
              maxLines: 5,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Instruction',
                hintText: 'Décris cette étape...',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () {
                  final value = controller.text.trim();

                  if (value.isEmpty) {
                    return;
                  }

                  Navigator.of(dialogContext).pop(value);
                },
                child: const Text('Ajouter'),
              ),
            ],
          );
        },
      );

      if (result == null || result.trim().isEmpty) {
        return;
      }

      setState(() {
        _isLoading = true;
      });

      await _recipeRepository.addRecipeStep(
        recipeId: widget.recipe.id,
        instruction: result.trim(),
      );

      final steps = await _recipeRepository.getRecipeSteps(
        widget.recipe.id,
      );

      if (!mounted) return;

      setState(() {
        _editableSteps = steps
            .map((step) => Map<String, dynamic>.from(step))
            .toList();
        _stepsFuture = Future.value(_editableSteps);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'L’étape a été ajoutée avec succès.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible d’ajouter l’étape : $error',
          ),
        ),
      );
    } finally {
      controller.dispose();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // RÉORGANISER LES ÉTAPES
  // ============================================================

  Future<void> _reorderSteps(
    int oldIndex,
    int newIndex,
  ) async {
    if (oldIndex == newIndex) {
      return;
    }

    if (newIndex > oldIndex) {
      newIndex -= 1;
    }

    final reordered = List<Map<String, dynamic>>.from(
      _editableSteps,
    );

    if (oldIndex < 0 ||
        oldIndex >= reordered.length ||
        newIndex < 0 ||
        newIndex >= reordered.length) {
      return;
    }

    final movedStep = reordered.removeAt(oldIndex);
    reordered.insert(newIndex, movedStep);

    final previousSteps = List<Map<String, dynamic>>.from(
      _editableSteps,
    );

    setState(() {
      _editableSteps = reordered;
      _stepsFuture = Future.value(_editableSteps);
      _isLoading = true;
    });

    try {
      final orderedStepIds = reordered
          .map((step) => step['id'])
          .whereType<int>()
          .toList();

      await _recipeRepository.reorderRecipeSteps(
        recipeId: widget.recipe.id,
        orderedStepIds: orderedStepIds,
      );

      final steps = await _recipeRepository.getRecipeSteps(
        widget.recipe.id,
      );

      if (!mounted) return;

      setState(() {
        _editableSteps = steps
            .map((step) => Map<String, dynamic>.from(step))
            .toList();
        _stepsFuture = Future.value(_editableSteps);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Les étapes ont été réorganisées.',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _editableSteps = previousSteps;
        _stepsFuture = Future.value(_editableSteps);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de réorganiser les étapes : $error',
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