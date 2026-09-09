import 'package:flutter/material.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/register_page.dart';
import '../../features/auth/presentation/profile_page.dart';
import '../../features/auth/presentation/my_profile_view_page.dart';
import '../../features/recipes/presentation/favorites_page.dart';
import '../../features/auth/presentation/edit_profile_page.dart';
import '../app_shell.dart';
import '../../features/auth/presentation/welcome_page.dart';
import '../../features/recipes/presentation/create_recipe_page.dart';
import '../../features/recipes/presentation/create_video_recipe_page.dart';
import '../../pages/creator/my_recipes_page.dart';
class AppRouter {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => const WelcomePage(),
        );

      case '/login':
        return MaterialPageRoute(
          builder: (_) => const LoginPage(),
        );

      case '/register':
        return MaterialPageRoute(
          builder: (_) => const RegisterPage(),
        );

      case '/home':
        final tabIndex = settings.arguments as int? ?? 0;
        return MaterialPageRoute(
          builder: (_) => AppShellPage(initialTabIndex: tabIndex),
        );
        case '/create-recipe':
        return MaterialPageRoute(
          builder: (_) => const CreateRecipePage(),
        );
        case '/create-video-recipe':
        return MaterialPageRoute(
          builder: (_) => const CreateVideoRecipePage(),
        );
        case '/my-recipes':
        return MaterialPageRoute(
          builder: (_) => const MyRecipesPage(),
        );
        case '/profile':
        return MaterialPageRoute(
          builder: (_) => const ProfilePage(),
        );
        case '/my-profile':
        return MaterialPageRoute(
          builder: (_) => const MyProfileViewPage(),
        );
        case '/favorites':
        return MaterialPageRoute(
          builder: (_) => const FavoritesPage(),
        );
        case '/edit-profile':
        return MaterialPageRoute(
          builder: (_) => const EditProfilePage(),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const WelcomePage(),
        );
    }
  }
}