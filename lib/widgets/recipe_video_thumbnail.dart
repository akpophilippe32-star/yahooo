import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../repositories/recipe_repository.dart';

/// Affiche la miniature d'une recette vidéo.
///
/// Deux cas :
/// - `imageUrl` fourni (recette créée après la mise en place des
///   vraies miniatures) : affiche directement cette image légère
///   (quelques Ko), sans jamais toucher au fichier vidéo — c'est le
///   cas normal désormais.
/// - `imageUrl` absent (anciennes recettes vidéo créées avant ce
///   changement) : repli sur l'ancien comportement, qui charge un
///   bout de la vidéo pour en extraire la première image. Plus
///   coûteux en bande passante, mais garde ces anciennes recettes
///   fonctionnelles sans qu'il soit nécessaire de les recréer.
class RecipeVideoThumbnail extends StatefulWidget {
  final String videoPath;
  final RecipeRepository recipeRepository;
  final String? imageUrl;

  const RecipeVideoThumbnail({
    super.key,
    required this.videoPath,
    required this.recipeRepository,
    this.imageUrl,
  });

  @override
  State<RecipeVideoThumbnail> createState() => _RecipeVideoThumbnailState();
}

class _RecipeVideoThumbnailState extends State<RecipeVideoThumbnail> {
  // Utilisés uniquement dans le cas de repli (pas de vraie
  // miniature disponible).
  VideoPlayerController? _controller;
  bool _failed = false;

  // Utilisé uniquement dans le cas normal (vraie miniature).
  String? _resolvedImageUrl;
  bool _isResolvingImage = false;

  bool get _hasRealThumbnail =>
      widget.imageUrl != null && widget.imageUrl!.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();

    if (_hasRealThumbnail) {
      _resolveImage();
    } else {
      _initVideoFallback();
    }
  }

  Future<void> _resolveImage() async {
    setState(() => _isResolvingImage = true);

    try {
      final url = await widget.recipeRepository.getRecipeImageUrl(
        widget.imageUrl,
      );

      if (!mounted) return;

      setState(() {
        _resolvedImageUrl = url;
        _isResolvingImage = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _failed = true;
        _isResolvingImage = false;
      });
    }
  }

  Future<void> _initVideoFallback() async {
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

    if (_hasRealThumbnail) {
      return _buildRealThumbnail(colorScheme);
    }

    return _buildVideoFallback(colorScheme);
  }

  // ============================================================
  // CAS NORMAL : vraie image légère
  // ============================================================

  Widget _buildRealThumbnail(ColorScheme colorScheme) {
    if (_failed || (!_isResolvingImage && _resolvedImageUrl == null)) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: Icon(
          Icons.play_circle_outline,
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (_isResolvingImage || _resolvedImageUrl == null) {
      return Container(
        color: colorScheme.surfaceContainerHighest,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          _resolvedImageUrl!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) {
            return Container(
              color: colorScheme.surfaceContainerHighest,
              child: Icon(
                Icons.play_circle_outline,
                color: colorScheme.onSurfaceVariant,
              ),
            );
          },
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

  // ============================================================
  // REPLI : anciennes recettes sans miniature pré-générée
  // ============================================================

  Widget _buildVideoFallback(ColorScheme colorScheme) {
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