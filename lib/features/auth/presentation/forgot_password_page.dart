import 'package:flutter/material.dart';

import '../data/auth_repository.dart';

/// Écran "Mot de passe oublié" : demande l'email et envoie le lien
/// de réinitialisation via Supabase. Ne crée aucune session — la
/// suite se passe par email, puis via ResetPasswordPage une fois
/// le lien ouvert.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _authRepository = AuthRepository();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _sendResetEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authRepository.sendPasswordResetEmail(
        _emailController.text.trim(),
      );

      if (!mounted) return;

      setState(() => _emailSent = true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’envoyer l’email : $error')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mot de passe oublié')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _emailSent ? _buildSuccessState(context) : _buildForm(context),
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 12),
          Icon(
            Icons.lock_reset_outlined,
            size: 48,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 16),
          const Text(
            'Entre l’adresse email de ton compte. Tu recevras un '
            'lien pour choisir un nouveau mot de passe.',
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Adresse email'),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Renseigne ton adresse email.';
              }
              if (!value.contains('@')) {
                return 'Adresse email invalide.';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _isLoading ? null : _sendResetEmail,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Envoyer le lien'),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.mark_email_read_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 20),
        const Text(
          'Email envoyé !',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Vérifie ta boîte mail (${_emailController.text.trim()}) et '
          'clique sur le lien pour choisir un nouveau mot de passe.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Retour à la connexion'),
        ),
      ],
    );
  }
}