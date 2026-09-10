import 'package:flutter/material.dart';

import '../../../core/app_bar_leading.dart';
import '../../../core/app_drawer.dart';
import '../../../repositories/notification_repository.dart';
import '../../../repositories/recipe_repository.dart';
import '../../recipes/presentation/creator_profile_page.dart';
import '../../recipes/presentation/recipe_public_view_page.dart';

/// Écran de notifications : nouvel abonné, nouvelle recette publiée
/// par un créateur suivi. Les notifications sont créées côté base
/// de données (déclencheurs) — cet écran ne fait que les afficher.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  final _notificationRepository = NotificationRepository();
  final _recipeRepository = RecipeRepository();

  late Future<List<Map<String, dynamic>>> _notificationsFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _notificationsFuture = _notificationRepository.getNotifications();
  }

  Future<void> _refresh() async {
    setState(_load);
    await _notificationsFuture;
  }

  Future<void> _markAllAsRead() async {
    try {
      await _notificationRepository.markAllAsRead();

      if (!mounted) return;

      await _refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de marquer comme lu : $error')),
      );
    }
  }

  Future<void> _deleteNotification(int id) async {
    try {
      await _notificationRepository.deleteNotification(id);

      if (!mounted) return;

      await _refresh();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Impossible de supprimer : $error')),
      );
    }
  }

  Future<void> _openNotification(Map<String, dynamic> notification) async {
    if (notification['is_read'] != true) {
      await _notificationRepository.markAsRead(notification['id'] as int);
      if (mounted) await _refresh();
    }

    if (!mounted) return;

    final type = notification['type'] as String?;
    final recipeId = notification['related_recipe_id'] as int?;
    final userId = notification['related_user_id'] as String?;

    if (type == 'new_recipe' && recipeId != null) {
      final recipe = await _recipeRepository.getRecipeById(recipeId);

      if (!mounted) return;

      if (recipe == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cette recette n’est plus disponible.'),
          ),
        );
        return;
      }

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => RecipePublicViewPage(recipe: recipe),
        ),
      );
    } else if (type == 'new_follower' && userId != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CreatorProfilePage(authorId: userId),
        ),
      );
    }
  }

  IconData _iconForType(String? type) {
    switch (type) {
      case 'new_recipe':
        return Icons.restaurant_menu_outlined;
      case 'new_follower':
        return Icons.person_add_alt_1_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  /// Formate une date en "il y a X min/h/j", sans dépendance externe.
  String _formatRelativeTime(DateTime date) {
    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'à l’instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'il y a ${diff.inHours} h';
    if (diff.inDays < 7) return 'il y a ${diff.inDays} j';

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: const Text('Notifications'),
        leading: const AppBackMenuLeading(),
        leadingWidth: 96,
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Tout marquer lu'),
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _notificationsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'Impossible de charger tes notifications : '
                        '${snapshot.error}',
                      ),
                    ),
                  ],
                );
              }

              final notifications = snapshot.data ?? [];

              if (notifications.isEmpty) {
                return ListView(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.notifications_none,
                            size: 44,
                            color: colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Aucune notification pour l’instant.',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Abonne-toi à des créateurs pour être '
                            'prévenu de leurs nouvelles recettes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: notifications.length,
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 68),
                itemBuilder: (context, index) {
                  final notification = notifications[index];
                  final isRead = notification['is_read'] == true;
                  final createdAt = DateTime.tryParse(
                    notification['created_at'].toString(),
                  );

                  return Dismissible(
                    key: ValueKey(notification['id']),
                    direction: DismissDirection.endToStart,
                    onDismissed: (_) =>
                        _deleteNotification(notification['id'] as int),
                    background: Container(
                      color: Colors.red,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    child: ListTile(
                      tileColor: isRead
                          ? null
                          : colorScheme.primary.withValues(alpha: 0.06),
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.surfaceContainerHighest,
                        child: Icon(
                          _iconForType(notification['type'] as String?),
                          size: 18,
                          color: colorScheme.primary,
                        ),
                      ),
                      title: Text(
                        notification['title']?.toString() ?? '',
                        style: TextStyle(
                          fontWeight:
                              isRead ? FontWeight.w500 : FontWeight.w700,
                        ),
                      ),
                      subtitle: Text(
                        [
                          notification['body']?.toString() ?? '',
                          if (createdAt != null)
                            _formatRelativeTime(createdAt),
                        ].where((s) => s.isNotEmpty).join(' · '),
                      ),
                      trailing: isRead
                          ? null
                          : Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: colorScheme.primary,
                              ),
                            ),
                      onTap: () => _openNotification(notification),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}