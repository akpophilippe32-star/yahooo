import 'dart:async';

import 'package:device_preview/device_preview.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    publishableKey: dotenv.env['SUPABASE_PUBLISHABLE_KEY']!,
  );

  // Charge la préférence de thème sauvegardée localement (si elle
  // existe) avant d'afficher l'app, pour éviter un flash du mauvais
  // thème au démarrage.
  await ThemeController.instance.loadFromPrefs();

  // Supabase persiste déjà la session localement d'une ouverture à
  // l'autre, mais l'app démarrait toujours sur l'écran de bienvenue
  // sans jamais vérifier si une session valide existait déjà — on
  // redemandait donc de se reconnecter à chaque lancement, même
  // juste après s'être connecté. On saute directement à l'accueil
  // si une session est déjà active.
  final hasSession = Supabase.instance.client.auth.currentSession != null;

  runApp(
    // DevicePreview permet de simuler différents téléphones (taille,
    // encoches, orientation...) directement dans le navigateur.
    // Actif uniquement hors mode release (jamais en production).
    DevicePreview(
      enabled: !kReleaseMode,
      builder: (context) => MealoraApp(initialRoute: hasSession ? '/home' : '/'),
    ),
  );
}

/// Autorise le défilement par glisser-déposer à la souris (pas
/// seulement au tactile), sinon le scroll ne répond pas quand on
/// simule un téléphone dans le navigateur (DevicePreview) avec la
/// souris — le comportement par défaut de Flutter ne reconnaît que
/// le tactile pour ce genre de glissement.
class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}

class MealoraApp extends StatefulWidget {
  final String initialRoute;

  const MealoraApp({super.key, this.initialRoute = '/'});

  @override
  State<MealoraApp> createState() => _MealoraAppState();
}

class _MealoraAppState extends State<MealoraApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  StreamSubscription<AuthState>? _authSubscription;

  @override
  void initState() {
    super.initState();

    // Quand l'utilisateur ouvre le lien reçu par email ("mot de
    // passe oublié"), Supabase détecte automatiquement le jeton de
    // récupération et déclenche cet événement — peu importe où on
    // se trouve dans l'app à ce moment-là.
    _authSubscription =
        Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.passwordRecovery) {
        _navigatorKey.currentState?.pushNamed('/reset-password');
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Recalcule et applique le style de la barre de statut/navigation
  /// Android à chaque changement de thème : icônes sombres sur fond
  /// clair, icônes claires sur fond sombre. Sans ça, en thème clair,
  /// les icônes système (heure, batterie...) restaient blanches —
  /// donc invisibles sur un fond clair.
  void _applySystemUiOverlayStyle(BuildContext context) {
    final mode = ThemeController.instance.mode;

    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);

    SystemChrome.setSystemUIOverlayStyle(
      isDark
          ? const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
              systemNavigationBarColor: Colors.black,
              systemNavigationBarIconBrightness: Brightness.light,
            )
          : const SystemUiOverlayStyle(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
              systemNavigationBarColor: Colors.white,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // ListenableBuilder reconstruit le MaterialApp dès que le thème
    // change (via ThemeController.instance.setThemeMode(...)),
    // y compris en direct pendant l'inscription.
    return ListenableBuilder(
      listenable: ThemeController.instance,
      builder: (context, _) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _applySystemUiOverlayStyle(context);
        });

        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Mealora',
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeController.instance.mode,

          // Requis par DevicePreview pour simuler correctement
          // taille d'écran, densité et locale de l'appareil choisi.
          locale: DevicePreview.locale(context),
          builder: DevicePreview.appBuilder,

          // Corrige le scroll à la souris dans la simulation Chrome.
          scrollBehavior: AppScrollBehavior(),

          initialRoute: widget.initialRoute,

          onGenerateRoute: AppRouter.generateRoute,
        );
      },
    );
  }
}