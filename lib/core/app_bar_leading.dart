import 'package:flutter/material.dart';

/// Combine un bouton retour fin (façon Facebook — chevron léger,
/// pas la grosse flèche Material par défaut) et le hamburger vers
/// le menu latéral, à utiliser en tant que `leading` d'AppBar avec
/// `leadingWidth: 96`.
///
/// Utilisé sur toutes les pages poussées par-dessus la coquille
/// d'app, pour que le menu latéral reste accessible partout.
class AppBackMenuLeading extends StatelessWidget {
  final VoidCallback? onBack;

  const AppBackMenuLeading({super.key, this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: onBack ?? () => Navigator.of(context).pop(),
        ),
        Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
      ],
    );
  }
}