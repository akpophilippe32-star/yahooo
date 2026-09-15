import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../widgets/torn_edge_clipper.dart';
import '../data/auth_repository.dart';
import '../../../widgets/google_logo.dart';

/// Écran d'accueil — réplique fidèle de la maquette de référence
/// fournie (structure, doodles, dispersion des photos, couleurs).
///
/// ⚠️ Utilise volontairement le vert/orange de la maquette plutôt
/// que le corail/ambre du thème global de l'app (AppTheme) — c'est
/// un choix delibéré pour respecter fidèlement cette référence
/// visuelle précise. Dis-moi si tu veux que ces couleurs remplacent
/// aussi le thème global au lieu de rester propres à cet écran.
///
/// Photos temporaires libres de droits (licence Unsplash, pas
/// d'attribution requise) en attendant de vraies photos pour Mealora.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  final _authRepository = AuthRepository();
  StreamSubscription<AuthState>? _authSubscription;
  bool _isSigningInWithGoogle = false;

  static const Color _green = Color(0xFF3D8B40);
  static const Color _orange = Color(0xFFF2851E);
  static const Color _cream = Color(0xFFFBF8F2);
  static const Color _doodle = Color(0xFFE3D9C4);

  static const String _photoChicken =
      'https://images.unsplash.com/photo-1688923130928-8468d6af8d7e'
      '?fm=jpg&q=70&w=800&auto=format&fit=crop';

  static const String _photoBowl =
      'https://images.unsplash.com/photo-1512621776951-a57141f2eefd'
      '?fm=jpg&q=70&w=800&auto=format&fit=crop';

  @override
  void initState() {
    super.initState();

    // Le flux Google (redirection web / lien profond mobile) ne
    // revient pas directement avec un résultat : on écoute plutôt
    // le changement d'état d'authentification pour savoir quand la
    // connexion a réellement abouti, et rediriger vers l'accueil.
    _authSubscription =
    Supabase.instance.client.auth.onAuthStateChange.listen((data) async {
      if (data.event != AuthChangeEvent.signedIn || !mounted) return;

      // Un compte Google fraîchement créé n'a pas encore de pseudo
      // (pas passé par l'inscription classique) — on le fait d'abord
      // compléter son profil avant d'accéder à l'app.
      final needsCompletion = await _authRepository.needsProfileCompletion();

      if (!mounted) return;

      Navigator.of(context).pushNamedAndRemoveUntil(
        needsCompletion ? '/complete-profile' : '/home',
        (route) => false,
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _signInWithGoogle(BuildContext context) async {
    setState(() => _isSigningInWithGoogle = true);

    try {
      await _authRepository.signInWithGoogle();
      // La suite se passe via le listener d'état d'authentification
      // ci-dessus (redirection web ou retour du lien profond).
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Connexion Google impossible : $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSigningInWithGoogle = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      body: SafeArea(
        child: SingleChildScrollView(
          child: SizedBox(
            height: 900,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // ====================================================
                // DOODLES DE DÉCOR
                // ====================================================

                const Positioned(
                  top: 4,
                  left: 6,
                  child: Icon(Icons.spa, size: 28, color: Color(0xFF6FA65C)),
                ),
                Positioned(
                  top: 74,
                  left: -22,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFFD1483A),
                    ),
                  ),
                ),
                const Positioned(
                  top: 40,
                  right: 96,
                  child: Icon(
                    Icons.grain,
                    size: 18,
                    color: _orange,
                  ),
                ),
                const Positioned(
                  top: 200,
                  left: 20,
                  child: Icon(
                    Icons.local_florist,
                    size: 24,
                    color: Color(0xFF7BAE5E),
                  ),
                ),
                const Positioned(
                  top: 236,
                  right: 26,
                  child: Icon(
                    Icons.restaurant,
                    size: 22,
                    color: _doodle,
                  ),
                ),
                const Positioned(
                  top: 268,
                  right: 50,
                  child: Icon(Icons.spa, size: 20, color: Color(0xFF7BAE5E)),
                ),
                const Positioned(
                  top: 310,
                  right: 90,
                  child: Icon(
                    Icons.circle_outlined,
                    size: 14,
                    color: _doodle,
                  ),
                ),
                Positioned(
                  top: 332,
                  right: 60,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: _orange,
                    ),
                  ),
                ),
                Positioned(
                  top: 300,
                  left: 90,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green.withValues(alpha: 0.6),
                    ),
                  ),
                ),
                const Positioned(
                  top: 232,
                  left: 40,
                  child: Icon(
                    Icons.checkroom_outlined,
                    size: 22,
                    color: _doodle,
                  ),
                ),
                const Positioned(
                  top: 150,
                  right: 130,
                  child: Icon(
                    Icons.egg_outlined,
                    size: 18,
                    color: _doodle,
                  ),
                ),
                Positioned(
                  top: 96,
                  left: 150,
                  child: Icon(
                    Icons.blur_on,
                    size: 16,
                    color: _orange.withValues(alpha: 0.7),
                  ),
                ),
                Positioned(
                  top: 20,
                  right: 150,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _green.withValues(alpha: 0.5),
                    ),
                  ),
                ),

                // ====================================================
                // PHOTO — HAUT DROIT (poulet), déborde du bord
                // ====================================================

                Positioned(
                  top: -10,
                  right: -34,
                  child: _WelcomePhoto(
                    url: _photoChicken,
                    height: 170,
                    width: 190,
                    seed: 1,
                  ),
                ),

                // ====================================================
                // PHOTO — BAS GAUCHE (bowl), déborde du bord
                // ====================================================

                Positioned(
                  top: 330,
                  left: -34,
                  child: _WelcomePhoto(
                    url: _photoBowl,
                    height: 190,
                    width: 210,
                    seed: 7,
                  ),
                ),

                const Positioned(
                  top: 470,
                  right: 40,
                  child: Icon(
                    Icons.restaurant,
                    size: 26,
                    color: _doodle,
                  ),
                ),
                Positioned(
                  top: 400,
                  right: 26,
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF3A2B1D),
                      border: Border.all(color: _doodle, width: 2),
                    ),
                  ),
                ),
                const Positioned(
                  top: 560,
                  right: 30,
                  child: Icon(
                    Icons.crop_free,
                    size: 30,
                    color: _doodle,
                  ),
                ),

                // ====================================================
                // LOGO + WORDMARK + TAGLINE (centré, par-dessus)
                // ====================================================

                Positioned(
                  top: 60,
                  left: 0,
                  right: 0,
                  child: Column(
                    children: [
                      const Icon(
                        Icons.soup_kitchen_outlined,
                        size: 54,
                        color: _orange,
                      ),
                      const SizedBox(height: 8),
                      RichText(
                        text: const TextSpan(
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                          children: [
                            TextSpan(
                              text: 'Meal',
                              style: TextStyle(color: _green),
                            ),
                            TextSpan(
                              text: 'ora',
                              style: TextStyle(color: _orange),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 70,
                        height: 3,
                        color: _orange,
                      ),
                      const SizedBox(height: 14),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 56),
                        child: Text(
                          'Toute la cuisine\ndans une seule application',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15,
                            color: _green,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ====================================================
                // BOUTONS + LÉGAL
                // ====================================================

                Positioned(
                  top: 470,
                  left: 24,
                  right: 24,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                    decoration: BoxDecoration(
                      color: _cream,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 20,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          icon: const Icon(Icons.person_outline),
                          label: const Text(
                            'Créer un compte',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, '/login');
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                Theme.of(context).colorScheme.primary,
                            side: BorderSide(
                              color: Theme.of(context).colorScheme.primary,
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          icon: const Icon(Icons.login),
                          label: const Text(
                            'Se connecter',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        children: [
                          const Expanded(
                            child: Divider(color: _doodle),
                          ),
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 10),
                            child: Text(
                              'ou',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.brown.shade300,
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: _doodle),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 48,
                        child: OutlinedButton.icon(
                          onPressed: _isSigningInWithGoogle
                              ? null
                              : () => _signInWithGoogle(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF3A362B),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: Colors.brown.shade100),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          icon: _isSigningInWithGoogle
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const GoogleLogo(size: 20),
                          label: const Text('Continuer avec Google'),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text.rich(
                        TextSpan(
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.brown.shade300,
                            height: 1.6,
                          ),
                          children: const [
                            TextSpan(
                              text: 'En continuant, vous acceptez nos\n',
                            ),
                            TextSpan(
                              text: 'Conditions d’utilisation',
                              style: TextStyle(
                                color: _green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            TextSpan(text: ' et '),
                            TextSpan(
                              text: 'Politique de confidentialité',
                              style: TextStyle(
                                color: _green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomePhoto extends StatelessWidget {
  final String url;
  final double height;
  final double width;
  final int seed;

  const _WelcomePhoto({
    required this.url,
    required this.height,
    required this.width,
    this.seed = 1,
  });

  @override
  Widget build(BuildContext context) {
    return PhysicalShape(
      clipper: TornEdgeClipper(seed: seed),
      color: Colors.transparent,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      child: Image.network(
        url,
        height: height,
        width: width,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, progress) {
          if (progress == null) return child;

          return SizedBox(
            height: height,
            width: width,
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return SizedBox(
            height: height,
            width: width,
            child: const Center(
              child: Icon(Icons.restaurant, color: Color(0xFFA69C8A)),
            ),
          );
        },
      ),
    );
  }
}