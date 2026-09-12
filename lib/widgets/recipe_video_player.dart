import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../repositories/recipe_repository.dart';

/// Lecteur vidéo pour une recette créée à partir d'une vidéo.
///
/// Résout lui-même une URL signée à partir du chemin de stockage
/// (le bucket `recipe-videos` est privé).
///
/// Deux modes :
/// - Par défaut (`fullscreenCover: false`) : lecteur classique,
///   contenu dans son ratio d'aspect, barre de progression visible,
///   lecture/pause au tap uniquement.
/// - `fullscreenCover: true` : remplit tout l'espace disponible
///   (recadré, façon Reels), démarre automatiquement, boucle en
///   continu — utilisé par la fiche recette vidéo plein écran.
class RecipeVideoPlayer extends StatefulWidget {
  final String videoPath;
  final bool fullscreenCover;

  const RecipeVideoPlayer({
    super.key,
    required this.videoPath,
    this.fullscreenCover = false,
  });

  @override
  State<RecipeVideoPlayer> createState() => _RecipeVideoPlayerState();
}

class _RecipeVideoPlayerState extends State<RecipeVideoPlayer> {
  final RecipeRepository _recipeRepository = RecipeRepository();

  VideoPlayerController? _controller;
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final signedUrl = await _recipeRepository.getRecipeVideoUrl(
      widget.videoPath,
    );

    if (signedUrl == null) {
      throw Exception('Impossible de charger la vidéo.');
    }

    final controller = VideoPlayerController.networkUrl(
      Uri.parse(signedUrl),
    );

    await controller.initialize();

    if (!mounted) {
      controller.dispose();
      return;
    }

    if (widget.fullscreenCover) {
      await controller.setLooping(true);
      await controller.play();
    }

    setState(() {
      _controller = controller;
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    final controller = _controller;

    if (controller == null) {
      return;
    }

    setState(() {
      if (controller.value.isPlaying) {
        controller.pause();
      } else {
        controller.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          if (widget.fullscreenCover) {
            return const ColoredBox(
              color: Colors.black,
              child: Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            );
          }

          return AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        if (snapshot.hasError || _controller == null) {
          debugPrint(
            'Erreur de lecture vidéo [${widget.videoPath}] : '
            '${snapshot.error}',
          );

          if (widget.fullscreenCover) {
            return const ColoredBox(
              color: Colors.black,
              child: Center(
                child: Text(
                  'Impossible de charger la vidéo.',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            );
          }

          return AspectRatio(
            aspectRatio: 16 / 9,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Center(
                child: Text('Impossible de charger la vidéo.'),
              ),
            ),
          );
        }

        final controller = _controller!;

        if (widget.fullscreenCover) {
          return GestureDetector(
            onTap: _togglePlayPause,
            child: ColoredBox(
              color: Colors.black,
              child: SizedBox.expand(
                child: FittedBox(
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
              ),
            ),
          );
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: controller.value.aspectRatio == 0
                    ? 16 / 9
                    : controller.value.aspectRatio,
                child: GestureDetector(
                  onTap: _togglePlayPause,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      VideoPlayer(controller),
                      AnimatedOpacity(
                        opacity: controller.value.isPlaying ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          color: Colors.black26,
                          child: const Icon(
                            Icons.play_arrow,
                            size: 56,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            VideoProgressIndicator(
              controller,
              allowScrubbing: true,
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ],
        );
      },
    );
  }
}