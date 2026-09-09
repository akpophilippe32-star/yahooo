import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/theme_controller.dart';
import '../data/auth_repository.dart';

/// Écran d'inscription — style minimal (typographie + espacement),
/// avec juste une touche de couleur d'accent (soulignements,
/// compteur d'étape, bouton circulaire) plutôt que des bandeaux ou
/// icônes décoratives.
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _applicationNoteController = TextEditingController();

  final List<GlobalKey<FormState>> _stepFormKeys = List.generate(
    7,
    (_) => GlobalKey<FormState>(),
  );

  final _authRepository = AuthRepository();

  bool _isLoading = false;
  int _currentStep = 0;
  int _direction = 1;

  DateTime? _birthDate;

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

  static const int _stepIdentity = 0;
  static const int _stepBirthDate = 1;
  static const int _stepCredentials = 2;
  static const int _stepColor = 3;
  static const int _stepTheme = 4;
  static const int _stepAccountType = 5;
  static const int _stepQualifications = 6;

  int get _totalSteps => _accountType == 'user' ? 6 : 7;
  bool get _isLastStep => _currentStep == _totalSteps - 1;

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _applicationNoteController.dispose();
    super.dispose();
  }

  // ============================================================
  // NAVIGATION ENTRE ÉTAPES
  // ============================================================

  void _goNext() {
    final isValid =
        _stepFormKeys[_currentStep].currentState?.validate() ?? true;

    if (!isValid) return;

    if (_isLastStep) {
      _register();
      return;
    }

    setState(() {
      _direction = 1;
      _currentStep++;
    });
  }

  void _goBack() {
    if (_currentStep == 0) {
      Navigator.of(context).pop();
      return;
    }

    setState(() {
      _direction = -1;
      _currentStep--;
    });
  }

  // ============================================================
  // INSCRIPTION
  // ============================================================

  Future<void> _register() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await _authRepository.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim(),
        fullName: _fullNameController.text.trim(),
      );

      try {
        await _authRepository.updateProfilePreferences(
          birthDate: _birthDate,
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
            applicationNote:
                _applicationNoteController.text.trim().isEmpty
                    ? null
                    : _applicationNoteController.text.trim(),
          );
        } catch (error) {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Compte créé, mais impossible d’envoyer ta demande '
                'de statut créateur : $error',
              ),
            ),
          );

          return;
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _accountType == 'user'
                ? 'Compte créé avec succès.'
                : 'Compte créé. Ta demande de statut créateur est '
                    'en attente de validation par un administrateur.',
          ),
        ),
      );

      Navigator.of(context).pushReplacementNamed('/login');
    } on AuthException catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Une erreur est survenue.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _applyThemeChoice(ThemeMode mode) {
    setState(() => _selectedThemeMode = mode);
    ThemeController.instance.setThemeMode(mode);
  }

  // ============================================================
  // CHAMP DE TEXTE MINIMAL (soulignement, pas de fond)
  // ============================================================

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

  // ============================================================
  // INTERFACE
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final isBirthDateStep = _currentStep == _stepBirthDate;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              // ========================================================
              // FLÈCHE RETOUR + COMPTEUR D'ÉTAPE
              // ========================================================

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _goBack,
                    icon: const Icon(Icons.arrow_back),
                    color: colorScheme.onSurface,
                  ),
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

              // ========================================================
              // BARRE DE PROGRESSION SEGMENTÉE
              // ========================================================

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

              // ========================================================
              // CONTENU DE L'ÉTAPE
              // ========================================================

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
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: SingleChildScrollView(
                    key: ValueKey(_currentStep),
                    child: _buildStepContent(),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ========================================================
              // BOUTON SUIVANT (cercle) + PASSER (facultatif)
              // ========================================================

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (isBirthDateStep && !_isLoading)
                    TextButton(
                      onPressed: () => setState(() {
                        _direction = 1;
                        _currentStep++;
                      }),
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
                          colors: [colorScheme.primary, colorScheme.secondary],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.35),
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
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case _stepIdentity:
        return _buildIdentityStep();
      case _stepBirthDate:
        return _buildBirthDateStep();
      case _stepCredentials:
        return _buildCredentialsStep();
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

  // ============================================================
  // ÉTAPE — IDENTITÉ
  // ============================================================

  Widget _buildIdentityStep() {
    return Form(
      key: _stepFormKeys[_stepIdentity],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Comment tu\nt’appelles ?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              height: 1.25,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 40),
          TextFormField(
            controller: _fullNameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: _underlineDecoration(context, label: 'NOM COMPLET'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Entre ton nom complet';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _usernameController,
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

  // ============================================================
  // ÉTAPE — DATE DE NAISSANCE (facultative)
  // ============================================================

  Widget _buildBirthDateStep() {
    return Form(
      key: _stepFormKeys[_stepBirthDate],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ta date de\nnaissance',
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
          const SizedBox(height: 40),
          InkWell(
            onTap: () async {
              final now = DateTime.now();

              final picked = await showDatePicker(
                context: context,
                initialDate: _birthDate ??
                    DateTime(now.year - 18, now.month, now.day),
                firstDate: DateTime(now.year - 100),
                lastDate: now,
              );

              if (picked != null) {
                setState(() => _birthDate = picked);
              }
            },
            child: InputDecorator(
              decoration:
                  _underlineDecoration(context, label: 'DATE DE NAISSANCE'),
              child: Text(
                _birthDate == null
                    ? 'Choisir une date'
                    : '${_birthDate!.day.toString().padLeft(2, '0')}/'
                        '${_birthDate!.month.toString().padLeft(2, '0')}/'
                        '${_birthDate!.year}',
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ÉTAPE — IDENTIFIANTS
  // ============================================================

  Widget _buildCredentialsStep() {
    return Form(
      key: _stepFormKeys[_stepCredentials],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Tes\nidentifiants',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w600,
              height: 1.25,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 40),
          TextFormField(
            controller: _emailController,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            decoration: _underlineDecoration(context, label: 'ADRESSE E-MAIL'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Entre ton adresse e-mail';
              }
              if (!value.contains('@')) {
                return 'Adresse e-mail invalide';
              }
              return null;
            },
          ),
          const SizedBox(height: 28),
          TextFormField(
            controller: _passwordController,
            obscureText: true,
            decoration:
                _underlineDecoration(context, label: 'MOT DE PASSE'),
            validator: (value) {
              if (value == null || value.length < 6) {
                return '6 caractères minimum';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ÉTAPE — COULEUR PRÉFÉRÉE
  // ============================================================

  Widget _buildColorStep() {
    return Form(
      key: _stepFormKeys[_stepColor],
      child: Column(
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
      ),
    );
  }

  // ============================================================
  // ÉTAPE — THÈME
  // ============================================================

  Widget _buildThemeStep() {
    return Form(
      key: _stepFormKeys[_stepTheme],
      child: Column(
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
      ),
    );
  }

  // ============================================================
  // ÉTAPE — TYPE DE COMPTE
  // ============================================================

  Widget _buildAccountTypeStep() {
    return Form(
      key: _stepFormKeys[_stepAccountType],
      child: Column(
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
      ),
    );
  }

  // ============================================================
  // ÉTAPE — QUALIFICATIONS (Creator uniquement)
  // ============================================================

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

// ============================================================
// LIGNE D'OPTION MINIMALE (soulignement, coche à droite)
// ============================================================

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
        margin: EdgeInsets.only(bottom: isLast ? 0 : 0),
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