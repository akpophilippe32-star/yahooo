import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../repositories/profile_repository.dart';
import '../data/auth_repository.dart';

const List<String> _kMonthNamesFrEdit = [
  'janvier',
  'février',
  'mars',
  'avril',
  'mai',
  'juin',
  'juillet',
  'août',
  'septembre',
  'octobre',
  'novembre',
  'décembre',
];

/// Écran d'édition de profil façon X : bannière + avatar + champs
/// (nom, bio, localisation, site web, date de naissance).
///
/// La bannière n'accepte pas de photo — on ne stocke qu'une couleur
/// (celle choisie à l'inscription) : le bouton caméra dessus ouvre
/// donc un sélecteur de couleur plutôt qu'une galerie de photos.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _profileRepository = ProfileRepository();
  final _imagePicker = ImagePicker();

  static const List<Color> _colorSwatches = [
    Color(0xFFE8703C),
    Color(0xFFE8A63C),
    Color(0xFF3B6D11),
    Color(0xFF0F6E56),
    Color(0xFF2C5C8A),
    Color(0xFF5C3A8A),
    Color(0xFF8A2C4E),
    Color(0xFF6B6152),
  ];

  final _fullNameController = TextEditingController();
  final _bioController = TextEditingController();
  final _locationController = TextEditingController();
  final _websiteController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingAvatar = false;
  String? _loadError;

  String? _avatarPath;
  Color _accentColor = _colorSwatches.first;
  DateTime? _birthDate;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _bioController.dispose();
    _locationController.dispose();
    _websiteController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final profile = await _profileRepository.getMyProfile();

      if (!mounted) return;

      setState(() {
        _fullNameController.text = profile['full_name']?.toString() ?? '';
        _bioController.text = profile['bio']?.toString() ?? '';
        _locationController.text = profile['location']?.toString() ?? '';
        _websiteController.text = profile['website']?.toString() ?? '';
        _avatarPath = profile['avatar_url'] as String?;

        final rawBirthDate = profile['birth_date'] as String?;
        _birthDate =
            rawBirthDate != null ? DateTime.tryParse(rawBirthDate) : null;

        final hex = profile['accent_color'] as String?;
        if (hex != null && hex.isNotEmpty) {
          try {
            final value =
                int.parse(hex.replaceFirst('#', ''), radix: 16) |
                    0xFF000000;
            _accentColor = Color(value);
          } catch (_) {}
        }

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadError = error.toString();
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // AVATAR
  // ============================================================

  Future<void> _pickAvatar() async {
    final XFile? image = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );

    if (image == null) return;

    setState(() => _isUploadingAvatar = true);

    try {
      final Uint8List bytes = await image.readAsBytes();
      final extension = image.name.split('.').last.toLowerCase();

      final path = await _profileRepository.uploadAvatar(
        bytes: bytes,
        fileExtension: extension,
      );

      await _profileRepository.updateIdentity(avatarUrl: path);

      if (!mounted) return;

      setState(() => _avatarPath = path);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Impossible de mettre à jour la photo : $error'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingAvatar = false);
    }
  }

  // ============================================================
  // COULEUR DE LA BANNIÈRE (pas de photo — juste une couleur)
  // ============================================================

  Future<void> _pickBannerColor() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Couleur de la bannière',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text(
                'La bannière n’accepte pas de photo — choisis une '
                'couleur.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: _colorSwatches.map((color) {
                  final isSelected = color == _accentColor;

                  return InkWell(
                    onTap: () {
                      setState(() => _accentColor = color);
                      Navigator.of(sheetContext).pop();
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.black87, width: 2.5)
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // DATE DE NAISSANCE
  // ============================================================

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate:
          _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
    );

    if (picked != null) {
      setState(() => _birthDate = picked);
    }
  }

  // ============================================================
  // ENREGISTRER
  // ============================================================

  Future<void> _save() async {
    setState(() => _isSaving = true);

    try {
      await _profileRepository.updateIdentity(
        fullName: _fullNameController.text.trim(),
        bio: _bioController.text.trim(),
        location: _locationController.text.trim(),
        website: _websiteController.text.trim(),
      );

      await AuthRepository().updateProfilePreferences(
        birthDate: _birthDate,
        accentColor:
            '#${_accentColor.toARGB32().toRadixString(16).substring(2)}',
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil mis à jour.')),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() => _isSaving = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible d’enregistrer : $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Éditer le profil'),
        actions: [
          TextButton(
            onPressed: _isLoading || _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Enregistrer'),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Erreur : $_loadError'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Réessayer'),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      // ============================================
                      // BANNIÈRE (couleur) + AVATAR
                      // ============================================

                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          InkWell(
                            onTap: _pickBannerColor,
                            child: Container(
                              height: 130,
                              width: double.infinity,
                              color: _accentColor,
                              child: Center(
                                child: Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withValues(alpha: 0.35),
                                  ),
                                  child: const Icon(
                                    Icons.palette_outlined,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            left: 20,
                            bottom: -36,
                            child: InkWell(
                              onTap:
                                  _isUploadingAvatar ? null : _pickAvatar,
                              customBorder: const CircleBorder(),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context)
                                      .scaffoldBackgroundColor,
                                ),
                                child: Stack(
                                  children: [
                                    FutureBuilder<String?>(
                                      future: _profileRepository
                                          .getAvatarUrl(_avatarPath),
                                      builder: (context, snapshot) {
                                        final url = snapshot.data;

                                        return CircleAvatar(
                                          radius: 36,
                                          backgroundColor: colorScheme
                                              .surfaceContainerHighest,
                                          backgroundImage: url != null
                                              ? NetworkImage(url)
                                              : null,
                                          child: url == null
                                              ? Icon(
                                                  Icons.person,
                                                  size: 32,
                                                  color: colorScheme
                                                      .onSurfaceVariant,
                                                )
                                              : null,
                                        );
                                      },
                                    ),
                                    Positioned.fill(
                                      child: Center(
                                        child: Container(
                                          width: 30,
                                          height: 30,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: Colors.black
                                                .withValues(alpha: 0.35),
                                          ),
                                          child: _isUploadingAvatar
                                              ? const Padding(
                                                  padding:
                                                      EdgeInsets.all(6),
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Icon(
                                                  Icons.camera_alt,
                                                  size: 15,
                                                  color: Colors.white,
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 48),

                      // ============================================
                      // CHAMPS
                      // ============================================

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextField(
                              controller: _fullNameController,
                              decoration: const InputDecoration(
                                labelText: 'Nom',
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _bioController,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Biographie',
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _locationController,
                              decoration: const InputDecoration(
                                labelText: 'Localisation',
                              ),
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: _websiteController,
                              keyboardType: TextInputType.url,
                              decoration: const InputDecoration(
                                labelText: 'Site Web',
                              ),
                            ),
                            const SizedBox(height: 20),
                            InkWell(
                              onTap: _pickBirthDate,
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Date de naissance',
                                ),
                                child: Text(
                                  _birthDate == null
                                      ? 'Choisir une date'
                                      : '${_kMonthNamesFrEdit[_birthDate!.month - 1]} '
                                          '${_birthDate!.day}, ${_birthDate!.year}',
                                ),
                              ),
                            ),
                            const SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }
}