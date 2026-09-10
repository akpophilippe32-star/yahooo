import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/app_bar_leading.dart';
import '../../../core/app_drawer.dart';
import '../../../models/category_model.dart';
import '../../../repositories/category_repository.dart';
import '../../../repositories/ingredient_repository.dart';
import '../../../repositories/recipe_repository.dart';

class CreateRecipePage extends StatefulWidget {
  const CreateRecipePage({super.key});

  @override
  State<CreateRecipePage> createState() => _CreateRecipePageState();
}

class _CreateRecipePageState extends State<CreateRecipePage> {
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _dietTypeController = TextEditingController();
  final _prepTimeController = TextEditingController();
  final _cookTimeController = TextEditingController();
  final _servingsController = TextEditingController();

  final _quantityController = TextEditingController();
  final _unitController = TextEditingController();
  final _stepController = TextEditingController();

  final RecipeRepository _recipeRepository = RecipeRepository();
  final CategoryRepository _categoryRepository = CategoryRepository();
  final IngredientRepository _ingredientRepository =
      IngredientRepository();

  final ImagePicker _imagePicker = ImagePicker();
  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  late Future<List<CategoryModel>> _categoriesFuture;
  late Future<List<Map<String, dynamic>>> _ingredientsFuture;

  bool _isLoading = false;
  bool _ingredientOptional = false;

  String? _selectedDifficulty;
  int? _selectedCategoryId;
  int? _selectedIngredientId;

  final List<String> _difficulties = [
    'easy',
    'medium',
    'hard',
  ];

  final List<RecipeIngredientDraft> _selectedIngredients = [];
  final List<RecipeStepDraft> _steps = [];

  @override
  void initState() {
    super.initState();

    _categoriesFuture = _categoryRepository.getCategories();
    _ingredientsFuture = _ingredientRepository.getIngredients();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dietTypeController.dispose();
    _prepTimeController.dispose();
    _cookTimeController.dispose();
    _servingsController.dispose();

    _quantityController.dispose();
    _unitController.dispose();
    _stepController.dispose();

    super.dispose();
  }

  // ============================================================
  // CHOISIR UNE IMAGE
  // ============================================================

  Future<void> _pickImage() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) {
      return;
    }

    final bytes = await image.readAsBytes();

    if (!mounted) return;

    setState(() {
      _selectedImage = image;
      _selectedImageBytes = bytes;
    });
  }

  // ============================================================
  // AJOUT D'UN INGRÉDIENT
  // ============================================================

  void _addIngredient() {
    if (_selectedIngredientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Sélectionne d’abord un ingrédient.',
          ),
        ),
      );
      return;
    }

    final quantityText = _quantityController.text.trim();

    final quantity = quantityText.isEmpty
        ? null
        : double.tryParse(
            quantityText.replaceAll(',', '.'),
          );

    if (quantityText.isNotEmpty && quantity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La quantité saisie est invalide.',
          ),
        ),
      );
      return;
    }

    final alreadyExists = _selectedIngredients.any(
      (ingredient) =>
          ingredient.ingredientId == _selectedIngredientId,
    );

    if (alreadyExists) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cet ingrédient est déjà ajouté.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _selectedIngredients.add(
        RecipeIngredientDraft(
          ingredientId: _selectedIngredientId,
          quantity: quantity,
          unit: _unitController.text.trim().isEmpty
              ? null
              : _unitController.text.trim(),
          optional: _ingredientOptional,
        ),
      );

      _selectedIngredientId = null;
      _quantityController.clear();
      _unitController.clear();
      _ingredientOptional = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Ingrédient ajouté à la recette.',
        ),
      ),
    );
  }

  // ============================================================
  // SUPPRESSION D'UN INGRÉDIENT
  // ============================================================

  void _removeIngredient(int index) {
    setState(() {
      _selectedIngredients.removeAt(index);
    });
  }

  void _addStep() {
    final instruction = _stepController.text.trim();

    if (instruction.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Décris d’abord l’étape de préparation.',
          ),
        ),
      );

      return;
    }

    setState(() {
      _steps.add(
        RecipeStepDraft(
          instruction: instruction,
        ),
      );

      _stepController.clear();
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Étape ajoutée à la recette.',
        ),
      ),
    );
  }
  void _removeStep(int index) {
    setState(() {
      _steps.removeAt(index);
    });
  }

  


  // ============================================================
  // CHAMPS OBLIGATOIRES POUR UNE PUBLICATION DIRECTE
  // ============================================================

  /// Vérifie côté client que les informations obligatoires pour une
  /// publication sont renseignées, avant même d'appeler le backend.
  /// (Le backend revérifie de toute façon via
  /// `RecipeRepository.publishRecipe`.)
  List<String> _missingFieldsForDirectPublish() {
    final missing = <String>[];

    if (_titleController.text.trim().isEmpty) {
      missing.add('Titre');
    }

    if (_selectedCategoryId == null) {
      missing.add('Catégorie');
    }

    if (_selectedDifficulty == null) {
      missing.add('Difficulté');
    }

    if (_selectedIngredients.isEmpty) {
      missing.add('Au moins un ingrédient');
    }

    if (_steps.isEmpty) {
      missing.add('Au moins une étape de préparation');
    }

    return missing;
  }

  // ============================================================
  // CRÉATION DE LA RECETTE (BROUILLON OU PUBLICATION DIRECTE)
  // ============================================================

  /// Crée la recette en brouillon, puis la publie immédiatement si
  /// [publish] est `true` et que les informations obligatoires sont
  /// renseignées.
  Future<void> _createRecipe({required bool publish}) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (publish) {
      final missing = _missingFieldsForDirectPublish();

      if (missing.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Informations manquantes pour publier : '
              '${missing.join(', ')}.',
            ),
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // ============================================================
      // ENVOI DE L'IMAGE (si une a été choisie)
      // ============================================================

      String? imageUrl;

      if (_selectedImage != null && _selectedImageBytes != null) {
        final extension =
            _selectedImage!.name.split('.').last.toLowerCase();

        imageUrl = await _recipeRepository.uploadRecipeImage(
          bytes: _selectedImageBytes!,
          fileExtension: extension,
        );
      }

      final recipe = await _recipeRepository.createDraft(
        title: _titleController.text.trim(),

        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),

        categoryId: _selectedCategoryId,

        imageUrl: imageUrl,

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

        dietType: _dietTypeController.text.trim().isEmpty
            ? null
            : _dietTypeController.text.trim(),

        // ============================================================
        // INGRÉDIENTS
        // ============================================================

        ingredients: _selectedIngredients.map((ingredient) {
          return {
            'ingredient_id': ingredient.ingredientId,
            'quantity': ingredient.quantity,
            'unit': ingredient.unit,
            'optional': ingredient.optional,
          };
        }).toList(),

        // ============================================================
        // ÉTAPES
        // ============================================================

        steps: _steps.asMap().entries.map((entry) {
          final index = entry.key;
          final step = entry.value;

          return {
            'step_number': index + 1,
            'instruction': step.instruction,
            'image_url': null,
          };
        }).toList(),
      );

      debugPrint('Recette créée : $recipe');
      debugPrint(
        'Ingrédients sélectionnés : $_selectedIngredients',
      );

      // ============================================================
      // PUBLICATION IMMÉDIATE (si demandée)
      // ============================================================

      if (publish) {
        final recipeId = recipe['id'] ?? recipe['recipe_id'];

        if (recipeId is! int) {
          throw Exception(
            'La recette a été enregistrée comme brouillon, mais '
            'son identifiant est introuvable pour la publier.',
          );
        }

        try {
          await _recipeRepository.publishRecipe(recipeId);

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'La recette a été créée et publiée avec succès.',
              ),
            ),
          );

          Navigator.of(context).pop();
          return;
        } catch (publishError) {
          // La recette est déjà enregistrée en brouillon à ce stade :
          // on informe l'utilisateur sans perdre son travail.
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'La recette a été enregistrée comme brouillon, mais '
                'n’a pas pu être publiée : $publishError',
              ),
            ),
          );

          Navigator.of(context).pop();
          return;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'La recette a été enregistrée comme brouillon.',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de créer la recette : $error',
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

  Future<void> _saveAndPublish() => _createRecipe(publish: true);

  // ============================================================
  // RECHARGEMENT DES DONNÉES
  // ============================================================

  Future<void> _reloadCategories() async {
    setState(() {
      _categoriesFuture = _categoryRepository.getCategories();
    });
  }

  Future<void> _reloadIngredients() async {
    setState(() {
      _ingredientsFuture =
          _ingredientRepository.getIngredients();
    });
  }

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExitAttempt();
      },
      child: Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Nouvelle recette'),
        leading: AppBackMenuLeading(onBack: _handleExitAttempt),
        leadingWidth: 96,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Renseigne les informations principales '
                  'de ta recette.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 28),

                // ========================================================
                // TITRE
                // ========================================================

                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Titre de la recette',
                    hintText: 'Ex. Riz au poulet',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
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
                    hintText:
                        'Décris brièvement ta recette...',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 20),

                // ========================================================
                // IMAGE DE LA RECETTE
                // ========================================================

                Row(
                  children: [
                    Icon(
                      Icons.image_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Image de la recette',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        height: 200,
                        width: double.infinity,
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child: _selectedImageBytes != null
                            ? Image.memory(
                                _selectedImageBytes!,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Column(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.add_photo_alternate_outlined,
                                    size: 36,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Aucune image sélectionnée',
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
                    ),
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Row(
                        children: [
                          if (_selectedImage != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _ImageActionButton(
                                icon: Icons.delete_outline,
                                onTap: _isLoading
                                    ? null
                                    : () {
                                        setState(() {
                                          _selectedImage = null;
                                          _selectedImageBytes = null;
                                        });
                                      },
                              ),
                            ),
                          _ImageActionButton(
                            icon: _selectedImage == null
                                ? Icons.add_a_photo_outlined
                                : Icons.edit_outlined,
                            onTap: _isLoading ? null : _pickImage,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // ========================================================
                // CATÉGORIE
                // ========================================================

                FutureBuilder<List<CategoryModel>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
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
                              child:
                                  CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          InputDecorator(
                            decoration:
                                const InputDecoration(
                              labelText: 'Catégorie',
                              border: OutlineInputBorder(),
                            ),
                            child: Text(
                              'Impossible de charger '
                              'les catégories.',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .error,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed:
                                _reloadCategories,
                            icon:
                                const Icon(Icons.refresh),
                            label:
                                const Text('Réessayer'),
                          ),
                        ],
                      );
                    }

                    final categories =
                        snapshot.data ?? [];

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
                          value: category.id,
                          child: Text(category.name),
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

                Text(
                  'Difficulté',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _difficulties.map((difficulty) {
                    final isSelected = _selectedDifficulty == difficulty;

                    return ChoiceChip(
                      label: Text(_difficultyLabel(difficulty)),
                      selected: isSelected,
                      onSelected: (_) {
                        setState(() => _selectedDifficulty = difficulty);
                      },
                    );
                  }).toList(),
                ),
                if (_selectedDifficulty == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6, left: 4),
                    child: Text(
                      'Sélectionne une difficulté.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
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
                        keyboardType:
                            TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Préparation',
                          suffixText: 'min',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return null;
                          }

                          final number =
                              int.tryParse(value.trim());

                          if (number == null ||
                              number < 0) {
                            return 'Valeur invalide';
                          }

                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _cookTimeController,
                        keyboardType:
                            TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Cuisson',
                          suffixText: 'min',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null ||
                              value.trim().isEmpty) {
                            return null;
                          }

                          final number =
                              int.tryParse(value.trim());

                          if (number == null ||
                              number < 0) {
                            return 'Valeur invalide';
                          }

                          return null;
                        },
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
                    hintText: 'Ex. 4',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null ||
                        value.trim().isEmpty) {
                      return null;
                    }

                    final number =
                        int.tryParse(value.trim());

                    if (number == null || number <= 0) {
                      return 'Nombre de portions invalide';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 32),

                // ========================================================
                // SECTION INGRÉDIENTS
                // ========================================================

                Row(
                  children: [
                    Icon(
                      Icons.shopping_basket_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Ingrédients',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // ========================================================
                // CHARGEMENT DES INGRÉDIENTS
                // ========================================================

                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _ingredientsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Center(
                          child:
                              CircularProgressIndicator(),
                        ),
                      );
                    }

                    if (snapshot.hasError) {
                      return Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Impossible de charger '
                            'les ingrédients.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .error,
                            ),
                          ),
                          TextButton.icon(
                            onPressed:
                                _reloadIngredients,
                            icon:
                                const Icon(Icons.refresh),
                            label:
                                const Text('Réessayer'),
                          ),
                        ],
                      );
                    }

                    final ingredients =
                        snapshot.data ?? [];

                    if (ingredients.isEmpty) {
                      return const Text(
                        'Aucun ingrédient disponible.',
                      );
                    }

                    return Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        // ==================================================
                        // SÉLECTION DE L'INGRÉDIENT
                        // ==================================================

                        DropdownButtonFormField<int>(
                          initialValue:
                              _selectedIngredientId,
                          decoration:
                              const InputDecoration(
                            labelText: 'Ingrédient',
                            border:
                                OutlineInputBorder(),
                          ),
                          items: ingredients.map(
                            (ingredient) {
                              return DropdownMenuItem<int>(
                                value:
                                    ingredient['id'] as int,
                                child: Text(
                                  ingredient['name']
                                      as String,
                                ),
                              );
                            },
                          ).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedIngredientId =
                                  value;
                            });
                          },
                        ),

                        const SizedBox(height: 16),

                        // ==================================================
                        // QUANTITÉ + UNITÉ
                        // ==================================================

                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller:
                                    _quantityController,
                                keyboardType:
                                    const TextInputType
                                        .numberWithOptions(
                                  decimal: true,
                                ),
                                decoration:
                                    const InputDecoration(
                                  labelText: 'Quantité',
                                  hintText: 'Ex. 200',
                                  border:
                                      OutlineInputBorder(),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller:
                                    _unitController,
                                decoration:
                                    const InputDecoration(
                                  labelText: 'Unité',
                                  hintText:
                                      'g, ml, unité...',
                                  border:
                                      OutlineInputBorder(),
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        // ==================================================
                        // OPTIONNEL
                        // ==================================================

                        CheckboxListTile(
                          contentPadding:
                              EdgeInsets.zero,
                          title: const Text(
                            'Ingrédient facultatif',
                          ),
                          value: _ingredientOptional,
                          onChanged: (value) {
                            setState(() {
                              _ingredientOptional =
                                  value ?? false;
                            });
                          },
                        ),

                        const SizedBox(height: 8),

                        // ==================================================
                        // BOUTON AJOUTER
                        // ==================================================

                        FilledButton.icon(
                          onPressed: _addIngredient,
                          icon: const Icon(Icons.add),
                          label: const Text(
                            'Ajouter l’ingrédient',
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ==================================================
                        // LISTE DES INGRÉDIENTS AJOUTÉS
                        // ==================================================

                        if (_selectedIngredients.isNotEmpty)
                          const Text(
                            'Ingrédients ajoutés',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                        if (_selectedIngredients.isNotEmpty)
                          const SizedBox(height: 12),

                        ..._selectedIngredients
                            .asMap()
                            .entries
                            .map((entry) {
                          final index = entry.key;
                          final ingredient = entry.value;

                          final ingredientName =
                              _getIngredientName(
                            ingredients,
                            ingredient.ingredientId,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor:
                                      Theme.of(context).colorScheme.surface,
                                  child: Icon(
                                    Icons.restaurant,
                                    size: 18,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        ingredientName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      Text(
                                        _formatIngredientDetails(ingredient),
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
                                IconButton(
                                  onPressed: () => _removeIngredient(index),
                                  tooltip: 'Supprimer',
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 32),

                                // ========================================================
                // ÉTAPES DE PRÉPARATION
                // ========================================================

                Row(
                  children: [
                    Icon(
                      Icons.format_list_numbered,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Étapes de préparation',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),                const SizedBox(height: 16),

                TextFormField(
                  controller: _stepController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Nouvelle étape',
                    hintText:
                        'Ex. Faire cuire le riz pendant 15 minutes...',
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                  ),
                ),

                const SizedBox(height: 12),

                FilledButton.icon(
                  onPressed: _addStep,
                  icon: const Icon(Icons.add),
                  label: const Text(
                    'Ajouter l’étape',
                  ),
                ),

                const SizedBox(height: 24),

                if (_steps.isNotEmpty)
                  const Text(
                    'Étapes ajoutées',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                if (_steps.isNotEmpty)
                  const SizedBox(height: 12),

                ..._steps.asMap().entries.map((entry) {
                  final index = entry.key;
                  final step = entry.value;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          child: Text(
                            '${index + 1}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              step.instruction,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () => _removeStep(index),
                          tooltip: 'Supprimer',
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 32),

                // ========================================================
                // PUBLIER DIRECTEMENT
                // ========================================================
                //
                // Le bouton "Enregistrer comme brouillon" a été retiré :
                // quitter l'écran sans publier déclenche désormais
                // automatiquement une sauvegarde en brouillon (voir
                // _handleExitAttempt / PopScope). Ce bouton reste donc
                // le seul appel à l'action explicite nécessaire.

                FilledButton.icon(
                  onPressed:
                      _isLoading ? null : _saveAndPublish,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons.publish_outlined,
                        ),
                  label: Text(
                    _isLoading
                        ? 'Enregistrement...'
                        : 'Publier la recette',
                  ),
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }

  // ============================================================
  // SORTIE DE L'ÉCRAN : BROUILLON AUTOMATIQUE
  // ============================================================

  /// Appelé quand l'utilisateur essaie de quitter l'écran (bouton
  /// retour, geste, flèche AppBar...) sans avoir explicitement
  /// publié ou enregistré. Si un titre a été saisi, on sauvegarde
  /// silencieusement un brouillon avant de laisser sortir — pour ne
  /// jamais perdre le travail en cours.
  Future<void> _handleExitAttempt() async {
    if (_titleController.text.trim().isEmpty) {
      // Rien de significatif n'a été saisi : rien à sauvegarder.
      if (mounted) {
        Navigator.of(context).pop();
      }
      return;
    }

    if (_isLoading) {
      // Une création/publication est déjà en cours : on la laisse
      // simplement terminer (elle gère elle-même la sortie).
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Enregistrement du brouillon...'),
        duration: Duration(seconds: 2),
      ),
    );

    // _createRecipe gère déjà ses propres erreurs (snackbar) et
    // ferme l'écran (pop) en cas de succès. Si ça échoue, on reste
    // volontairement sur l'écran pour ne pas perdre le travail :
    // l'utilisateur peut réessayer de quitter.
    await _createRecipe(publish: false);
  }

  // ============================================================
  // NOM D'UN INGRÉDIENT
  // ============================================================

  String _getIngredientName(
    List<Map<String, dynamic>> ingredients,
    int? ingredientId,
  ) {
    if (ingredientId == null) {
      return 'Ingrédient inconnu';
    }

    for (final ingredient in ingredients) {
      if (ingredient['id'] == ingredientId) {
        return ingredient['name'] as String;
      }
    }

    return 'Ingrédient inconnu';
  }

  // ============================================================
  // AFFICHAGE DES DÉTAILS
  // ============================================================

  String _formatIngredientDetails(
    RecipeIngredientDraft ingredient,
  ) {
    final parts = <String>[];

    if (ingredient.quantity != null) {
      final quantity =
          ingredient.quantity! % 1 == 0
              ? ingredient.quantity!
                  .toInt()
                  .toString()
              : ingredient.quantity!
                  .toString();

      parts.add(quantity);
    }

    if (ingredient.unit != null &&
        ingredient.unit!.isNotEmpty) {
      parts.add(ingredient.unit!);
    }

    if (ingredient.optional) {
      parts.add('facultatif');
    }

    if (parts.isEmpty) {
      return 'Quantité non précisée';
    }

    return parts.join(' ');
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
}

// ============================================================
// MODÈLE TEMPORAIRE D'UN INGRÉDIENT
// ============================================================
// ============================================================
// MODÈLE TEMPORAIRE D'UNE ÉTAPE
// ============================================================

class RecipeStepDraft {
  String instruction;

  RecipeStepDraft({
    required this.instruction,
  });

  @override
  String toString() {
    return 'RecipeStepDraft('
        'instruction: $instruction'
        ')';
  }
}

// ============================================================
// MODÈLE TEMPORAIRE D'UN INGRÉDIENT
// ============================================================

class RecipeIngredientDraft {
  int? ingredientId;
  double? quantity;
  String? unit;
  bool optional;

  RecipeIngredientDraft({
    this.ingredientId,
    this.quantity,
    this.unit,
    this.optional = false,
  });

  @override
  String toString() {
    return 'RecipeIngredientDraft('
        'ingredientId: $ingredientId, '
        'quantity: $quantity, '
        'unit: $unit, '
        'optional: $optional'
        ')';
  }
}
// ============================================================
// BOUTON D'ACTION SUR L'IMAGE (changer / retirer)
// ============================================================

class _ImageActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _ImageActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.black.withValues(alpha: 0.55),
        ),
        child: Icon(icon, size: 18, color: Colors.white),
      ),
    );
  }
}