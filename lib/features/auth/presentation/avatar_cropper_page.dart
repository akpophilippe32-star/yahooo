import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Écran de recadrage circulaire pour la photo de profil : glisser
/// pour repositionner, pincer (ou molette/glisser à deux doigts)
/// pour zoomer. "Valider" renvoie les octets PNG déjà recadrés.
///
/// Implémenté sans dépendance externe (juste `RepaintBoundary` +
/// gestes natifs Flutter), pour un comportement identique sur web
/// et mobile.
class AvatarCropperPage extends StatefulWidget {
  final Uint8List imageBytes;

  const AvatarCropperPage({super.key, required this.imageBytes});

  @override
  State<AvatarCropperPage> createState() => _AvatarCropperPageState();
}

class _AvatarCropperPageState extends State<AvatarCropperPage> {
  static const double _cropSize = 280;

  final GlobalKey _boundaryKey = GlobalKey();

  double _scale = 1.0;
  Offset _offset = Offset.zero;

  double _baseScale = 1.0;
  Offset _baseOffset = Offset.zero;
  Offset _startFocalPoint = Offset.zero;

  bool _isSaving = false;

  void _onScaleStart(ScaleStartDetails details) {
    _baseScale = _scale;
    _baseOffset = _offset;
    _startFocalPoint = details.focalPoint;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale = (_baseScale * details.scale).clamp(0.5, 4.0);
      _offset = _baseOffset + (details.focalPoint - _startFocalPoint);
    });
  }

  Future<void> _confirmCrop() async {
    setState(() => _isSaving = true);

    try {
      final boundary = _boundaryKey.currentContext!.findRenderObject()
          as RenderRepaintBoundary;

      // pixelRatio > 1 pour garder une image nette malgré le
      // recadrage (280 affichés -> export en plus haute résolution).
      final image = await boundary.toImage(pixelRatio: 3);
      final byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null) {
        throw Exception('Échec de l’export de l’image recadrée.');
      }

      if (!mounted) return;

      Navigator.of(context).pop(byteData.buffer.asUint8List());
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de recadrer la photo : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Recadrer la photo'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _confirmCrop,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Valider',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: GestureDetector(
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                child: RepaintBoundary(
                  key: _boundaryKey,
                  child: ClipOval(
                    child: Container(
                      width: _cropSize,
                      height: _cropSize,
                      color: Colors.grey.shade900,
                      child: ClipRect(
                        child: Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()
                            ..translate(_offset.dx, _offset.dy)
                            ..scale(_scale),
                          child: Image.memory(
                            widget.imageBytes,
                            fit: BoxFit.cover,
                            width: _cropSize,
                            height: _cropSize,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Glisse pour repositionner, pince (ou fais glisser à '
              'deux doigts) pour zoomer.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}