import 'package:flutter/material.dart';

class HomeHeader extends StatelessWidget {
  final String userName;

  const HomeHeader({
    super.key,
    this.userName = '',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Logo / nom de l'application + profil
        Row(
          children: [
            const Expanded(
              child: Text(
                'Mealora nouveau ',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            IconButton(
              onPressed: () {
                // Nous brancherons le profil plus tard.
              },
              icon: const Icon(
                Icons.person_outline,
                size: 28,
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // Message d'accueil
        Text(
          userName.isEmpty
              ? 'Bonjour '
              : 'Bonjour, $userName 👋',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        const Text(
          'Qu’allons-nous cuisiner aujourd’hui ?',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey,
          ),
        ),

        const SizedBox(height: 20),

        // Barre de recherche
        TextField(
          readOnly: true,
          onTap: () {
            // La vraie recherche sera branchée plus tard.
          },
          decoration: InputDecoration(
            hintText: 'Rechercher une recette...',
            prefixIcon: const Icon(Icons.search),
            suffixIcon: const Icon(Icons.tune),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}