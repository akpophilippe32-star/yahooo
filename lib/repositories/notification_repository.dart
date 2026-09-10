import 'package:supabase_flutter/supabase_flutter.dart';

/// Gère les notifications de l'utilisateur connecté. Les
/// notifications elles-mêmes sont créées côté base de données par
/// des déclencheurs (nouvel abonné, nouvelle recette publiée par un
/// créateur suivi) — ce repository ne fait que les lire.
class NotificationRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  // ============================================================
  // LECTURE
  // ============================================================

  Future<List<Map<String, dynamic>>> getNotifications() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('Utilisateur non connecté.');
    }

    final response = await _supabase
        .from('notifications')
        .select()
        .eq('recipient_id', user.id)
        .order('created_at', ascending: false)
        .limit(100);

    return (response as List)
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  Future<int> getUnreadCount() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return 0;

    final response = await _supabase
        .from('notifications')
        .select('id')
        .eq('recipient_id', user.id)
        .eq('is_read', false);

    return (response as List).length;
  }

  // ============================================================
  // MARQUER COMME LU
  // ============================================================

  Future<void> markAsRead(int notificationId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('id', notificationId)
        .eq('recipient_id', user.id);
  }

  Future<void> markAllAsRead() async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    await _supabase
        .from('notifications')
        .update({'is_read': true})
        .eq('recipient_id', user.id)
        .eq('is_read', false);
  }

  // ============================================================
  // SUPPRIMER
  // ============================================================

  Future<void> deleteNotification(int notificationId) async {
    final user = _supabase.auth.currentUser;

    if (user == null) return;

    await _supabase
        .from('notifications')
        .delete()
        .eq('id', notificationId)
        .eq('recipient_id', user.id);
  }
}