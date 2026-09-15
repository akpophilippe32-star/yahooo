import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../repositories/profile_repository.dart';
import '../data/auth_repository.dart';
import 'avatar_cropper_page.dart';

/// Écran affiché une seule fois, juste après la toute première
/// connexion via Google (ou tout futur fournisseur externe) : ces
/// comptes-là ne passent jamais par l'inscription classique, donc
/// il leur manque un nom d'utilisateur, une photo, une couleur
/// préférée et un type de compte. On les complète ici avant
/// d'accéder à l'app — même esprit visuel que RegisterPage.
class CompleteProfilePage extends StatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  State<CompleteProfilePage> createState() => _CompleteProfilePageState();
}

class _CompleteProfilePageState extends State<CompleteProfilePage> {
  final _authRepository = AuthRepository();
  final _profileRepository = ProfileRepository();
  final _imagePicker = ImagePicker();

  final _usernameController = TextEditingController();
  final _applicationNoteController = TextEditingController();

  final List<GlobalKey<FormState>> _stepFormKeys = List.generate(
    5,
    (_) => GlobalKey<FormState>(),
  );

  bool _isLoading = false;
  bool _isUploadingAvatar = false;
  int _currentStep = 0;
  int _direction = 1;

  Uint8List? _avatarBytes;
  String? _avatarPath;

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
  late Color _selectedColor = _colorSwatches.first;

  late ThemeMode _selectedThemeMode = ThemeController.instance.mode;

  String _accountType = 'user';

  static const int _stepUsername = 0;
  static const int _stepPhoto = 1;
  static const int _stepColor = 2;
  static const int _stepTheme = 3;
  static const int _stepAccountType = 4;
  static const int _stepQualifications = 5;

  int get _totalSteps => _accountType == 'user' ? 5 : 6;
  bool get _isLastStep => _currentStep == _totalSteps - 1;

  @override
  void dispose() {
    _usernameController.dispose();
    _applicationNoteController.dispose();
    super.dispose();
  }

  void _goNext() {
    final isValid =
        _stepFormKeys[_currentStep].currentState?.validate() ?? true;

    if (!isValid) return;

    if (_isLastStep) {
      _finish();
      return;
    }

    setState(() {
      _direction = 1;
      _currentStep++;
    });
  }

  void _skipStep() {
    setState(() {
      _direction = 1;
      _currentStep++;
    });
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

    setState(() {
      _avatarBytes = croppedBytes;
      _isUploadingAvatar = true;
    });

    try {
      final path = await _profileRepository.uploadAvatar(
        bytes: croppedBytes,
        fileExtension: 'png',
      );

      if (!mounted) return;

      setState(() => _avatarPath = path);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’envoyer la photo : $error')),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  Future<void> _finish() async {
    setState(() => _isLoading = true);

    try {
      await _authRepository.completeUsername(_usernameController.text.trim());

      if (_avatarPath != null) {
        await _profileRepository.updateIdentity(avatarUrl: _avatarPath);
      }

      try {
        await _authRepository.updateProfilePreferences(
          accentColor:
              '#${_selectedColor.toARGB32().toRadixString(16).substring(2)}',
          themePreference:
              ThemeController.themeModeToPreferenceString(_selectedThemeMode),
        );
      } catch (error) {
        debugPrint('Impossible d’enregistrer les préférences : $error');
      }

      if (_accountType != 'user') {
        try {
          await _authRepository.submitCreatorApplication(
            specialty: _accountType,
            applicationNote: _applicationNoteController.text.trim().isEmpty
                ? null
                : _applicationNoteController.text.trim(),
          );
        } catch (error) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Profil complété, mais impossible d’envoyer ta demande '
                'de statut créateur : $error',
              ),
            ),
          );
        }
      }

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de finaliser le profil : $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _applyThemeChoice(ThemeMode mode) {
    setState(() => _selectedThemeMode = mode);
    ThemeController.instance.setThemeMode(mode);
  }

  InputDecoration _underlineDecoration(
    BuildContext context, {
    required String label,
    String? hint,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: false,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      labelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: colorScheme.onSurfaceVariant,
      ),
      floatingLabelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: colorScheme.primary,
      ),
      border: UnderlineInputBorder(
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      enabledBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colorScheme.outline),
      ),
      focusedBorder: UnderlineInputBorder(
        borderSide: BorderSide(color: colorScheme.primary, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      '${(_currentStep + 1).toString().padLeft(2, '0')}  —  '
                      '${_totalSteps.toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: colorScheme.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: List.generate(_totalSteps, (index) {
                    final isActive = index <= _currentStep;

                    return Expanded(
                      child: Container(
                        height: 3,
                        margin: EdgeInsets.only(
                          right: index == _totalSteps - 1 ? 0 : 5,
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
                const SizedBox(height: 24),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 280),
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (child, animation) {
                      final entering = child.key == ValueKey(_currentStep);

                      final offsetTween = Tween<Offset>(
                        begin: Offset(entering ? _direction * 0.3 : 0, 0),
                        end: Offset(entering ? 0 : -_direction * 0.3, 0),
                      );

                      return SlideTransition(
                        position: offsetTween.animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child:
                            FadeTransition(opacity: animation, child: child),
                      );
                    },
                    child: SingleChildScrollView(
                      key: ValueKey(_currentStep),
                      child: _buildStepContent(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep == _stepPhoto && !_isLoading)
                      TextButton(
                        onPressed: _skipStep,
                        child: const Text('Passer cette étape'),
                      )
                    else
                      const SizedBox(),
                    InkWell(
                      onTap: _isLoading ? null : _goNext,
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 56,
                        height: 56,
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
                          boxShadow: [
                            BoxShadow(
                              color:
                                  colorScheme.primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: _isLoading
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isLastStep
                                    ? Icons.check
                                    : Icons.arrow_forward,
                                color: Colors.white,
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case _stepUsername:
        return _buildUsernameStep();
      case _stepPhoto:
        return _buildPhotoStep();
      case _stepColor:
        return _buildColorStep();
      case _stepTheme:
        return _buildThemeStep();
      case _stepAccountType:
        return _buildAccountTypeStep();
      default:
        return _buildQualificationsStep();
    }
  }

  Widget _buildUsernameStep() {
    return Form(
      key: _stepFormKeys[_stepUsername],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Bienvenue !\nChoisis ton pseudo',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w600,
              height: 1.25,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'On finalise ton profil Mealora en quelques étapes.',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 40),
          TextFormField(
            controller: _usernameController,
            autofocus: true,
            decoration:
                _underlineDecoration(context, label: 'NOM D’UTILISATEUR'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Entre un nom d’utilisateur';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Une photo\npour ton profil',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Facultatif.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        Center(
          child: InkWell(
            onTap: _isUploadingAvatar ? null : _pickAvatar,
            customBorder: const CircleBorder(),
            child: CircleAvatar(
              radius: 56,
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              backgroundImage:
                  _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
              child: _isUploadingAvatar
                  ? const CircularProgressIndicator()
                  : _avatarBytes == null
                      ? Icon(
                          Icons.add_a_photo_outlined,
                          size: 28,
                          color:
                              Theme.of(context).colorScheme.onSurfaceVariant,
                        )
                      : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildColorStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Choisis ta\ncouleur',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Pour personnaliser ton profil.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 40),
        Wrap(
          spacing: 18,
          runSpacing: 18,
          children: _colorSwatches.map((color) {
            final isSelected = color == _selectedColor;

            return InkWell(
              onTap: () => setState(() => _selectedColor = color),
              borderRadius: BorderRadius.circular(30),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.black87, width: 2.5)
                      : null,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildThemeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Clair ou\nsombre ?',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Change en direct.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        _MinimalOptionRow(
          isSelected: _selectedThemeMode == ThemeMode.light,
          title: 'Clair',
          onTap: () => _applyThemeChoice(ThemeMode.light),
        ),
        _MinimalOptionRow(
          isSelected: _selectedThemeMode == ThemeMode.dark,
          title: 'Sombre',
          onTap: () => _applyThemeChoice(ThemeMode.dark),
        ),
        _MinimalOptionRow(
          isSelected: _selectedThemeMode == ThemeMode.system,
          title: 'Système',
          subtitle: 'Suit le réglage de ton téléphone',
          onTap: () => _applyThemeChoice(ThemeMode.system),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildAccountTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Comment comptes-tu\nutiliser Mealora ?',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            height: 1.25,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Les demandes créateur sont examinées par un admin.',
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 28),
        _MinimalOptionRow(
          isSelected: _accountType == 'user',
          title: 'Découvrir et cuisiner',
          subtitle: 'Accès immédiat.',
          onTap: () => setState(() => _accountType = 'user'),
        ),
        _MinimalOptionRow(
          isSelected: _accountType == 'cuisine',
          title: 'Publier mes recettes',
          subtitle: 'Cuisinier·ère, chef ou créateur culinaire.',
          onTap: () => setState(() => _accountType = 'cuisine'),
        ),
        _MinimalOptionRow(
          isSelected: _accountType == 'nutrition',
          title: 'Partager des contenus nutrition',
          subtitle: 'Spécialiste en nutrition.',
          onTap: () => setState(() => _accountType = 'nutrition'),
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildQualificationsStep() {
    final isNutrition = _accountType == 'nutrition';

    return Form(
      key: _stepFormKeys[_stepQualifications],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Parle-nous\nde toi',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              height: 1.25,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isNutrition
                ? 'Décris ton expérience ou tes qualifications.'
                : 'Décris ton expérience culinaire (facultatif).',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 32),
          TextFormField(
            controller: _applicationNoteController,
            autofocus: true,
            maxLines: 5,
            decoration: _underlineDecoration(
              context,
              label: isNutrition
                  ? 'EXPÉRIENCE / QUALIFICATIONS'
                  : 'EXPÉRIENCE (FACULTATIF)',
              hint: isNutrition
                  ? 'Ex. diététicien diplômé, 5 ans d’expérience...'
                  : null,
            ),
            validator: (value) {
              if (isNutrition && (value == null || value.trim().isEmpty)) {
                return 'Ce champ aide l’admin à valider ta demande.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _MinimalOptionRow extends StatelessWidget {
  final bool isSelected;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool isLast;

  const _MinimalOptionRow({
    required this.isSelected,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? colorScheme.primary : colorScheme.outline,
              width: isSelected ? 2 : 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w400,
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurface,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 11,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              size: 18,
              color: isSelected ? colorScheme.primary : colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}