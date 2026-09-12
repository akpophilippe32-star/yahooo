import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../repositories/recipe_repository.dart';

/// Affiche la première image d'une vidéo comme miniature (en
/// pause, sans son), avec un petit repère "lecture" par-dessus —
/// pour qu'une recette vidéo montre un vrai aperçu au lieu d'une
/// simple icône ▶ générique, partout où elle apparaît en grille ou
/// en carrousel.
class RecipeVideoThumbnail extends StatefulWidget {
  final String videoPath;
  final RecipeRepository recipeRepository;

  const RecipeVideoThumbnail({
    super.key,
    required this.videoPath,
    required this.recipeRepository,
  });

  @override
  State<RecipeVideoThumbnail> createState() => _RecipeVideoThumbnailState();
}

class _RecipeVideoThumbnailState extends State<RecipeVideoThumbnail> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final url =
          await widget.recipeRepository.getRecipeVideoUrl(widget.videoPath);

      if (url == null || !mounted) return;

      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();

      if (!mounted) {
        controller.dispose();
        return;
      }

      // On reste sur la toute première image, sans jouer le son ni
      // la vidéo : c'est juste une miniature statique.
      await controller.seekTo(Duration.zero);
      await controller.pause();

      setState(() => _controller = controller);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final controller = _controller;

    if (_failed || controller == null) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.play_circle_outline,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: controller.value.size.width == 0
                ? 1
                : controller.value.size.width,
            height: controller.value.size.height == 0
                ? 1
                : controller.value.size.height,
            child: VideoPlayer(controller),
          ),
        ),
        Center(
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.4),
            ),
            child: const Icon(
              Icons.play_arrow,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
      ],
    );
  }
}