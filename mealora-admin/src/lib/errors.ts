/**
 * Extrait un message lisible d'une erreur, quelle que soit sa
 * forme. Important : les erreurs de Supabase (PostgrestError) ne
 * sont **pas** des instances de `Error` — ce sont de simples objets
 * `{ message, details, hint, code }`. Faire `String(err)` dessus
 * donne juste "[object Object]", d'où cette fonction plutôt que le
 * classique `err instanceof Error ? err.message : String(err)`.
 */
export function getErrorMessage(err: unknown): string {
  if (err instanceof Error) return err.message;

  if (
    typeof err === 'object' &&
    err !== null &&
    'message' in err &&
    typeof (err as { message: unknown }).message === 'string'
  ) {
    return (err as { message: string }).message;
  }

  try {
    return JSON.stringify(err);
  } catch {
    return String(err);
  }
}
