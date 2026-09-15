/// Transforme une erreur technique (souvent longue et illisible —
/// exception Supabase, timeout réseau...) en message clair pour
/// l'utilisateur. À utiliser à la place de `'$error'` partout où
/// on affiche une erreur dans un SnackBar ou un écran d'état vide.
///
/// Exemple :
/// ```dart
/// catch (error) {
///   ScaffoldMessenger.of(context).showSnackBar(
///     SnackBar(content: Text(friendlyErrorMessage(error))),
///   );
/// }
/// ```
String friendlyErrorMessage(Object error) {
  final raw = error.toString().toLowerCase();

  final looksOffline = raw.contains('socketexception') ||
      raw.contains('failed host lookup') ||
      raw.contains('network is unreachable') ||
      raw.contains('connection failed') ||
      raw.contains('connection refused') ||
      raw.contains('clientexception') ||
      raw.contains('timeoutexception') ||
      raw.contains('xmlhttprequest');

  if (looksOffline) {
    return 'Vous êtes actuellement hors ligne. Impossible de charger '
        'cette page. Veuillez vérifier votre connexion Internet et '
        'réessayer.';
  }

  return 'Une erreur est survenue. Veuillez réessayer.';
}