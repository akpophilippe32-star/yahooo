import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_repository.dart';

/// Écran de connexion — même style minimal que register_page.dart
/// (typographie, champs soulignés, bouton circulaire d'accent).
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _authRepository = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await _authRepository.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      Navigator.of(context).pushReplacementNamed('/home');
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

  InputDecoration _underlineDecoration(
    BuildContext context, {
    required String label,
    Widget? suffixIcon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;

    return InputDecoration(
      labelText: label,
      filled: false,
      floatingLabelBehavior: FloatingLabelBehavior.always,
      suffixIcon: suffixIcon,
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

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ========================================================
              // FLÈCHE RETOUR
              // ========================================================

              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),

              const SizedBox(height: 8),

              // ========================================================
              // CONTENU
              // ========================================================

              Expanded(
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Content de\nte revoir 👋',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w600,
                            height: 1.25,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Connecte-toi à ton compte Mealora.',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 40),
                        TextFormField(
                          controller: _emailController,
                          autofocus: true,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _underlineDecoration(
                            context,
                            label: 'ADRESSE E-MAIL',
                          ),
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
                          obscureText: _obscurePassword,
                          decoration: _underlineDecoration(
                            context,
                            label: 'MOT DE PASSE',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                size: 20,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Entre ton mot de passe';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context)
                                  .pushNamed('/forgot-password');
                            },
                            child: const Text('Mot de passe oublié ?'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // ========================================================
              // BOUTON SE CONNECTER (cercle) + LIEN INSCRIPTION
              // ========================================================

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pushReplacementNamed('/register');
                    },
                    child: const Text('Pas encore de compte ?'),
                  ),
                  InkWell(
                    onTap: _isLoading ? null : _login,
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
                          : const Icon(
                              Icons.arrow_forward,
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
}