import 'dart:convert';

/// `imageUrl` may hold a JSON array of URLs; return the first one.
String? primaryImageUrl(String? rawUrl) {
  if (rawUrl == null) return null;
  final trimmed = rawUrl.trim();
  if (trimmed.isEmpty) return null;
  if (!trimmed.startsWith('[')) return trimmed;
  try {
    final parsed = jsonDecode(trimmed);
    if (parsed is List) {
      for (final item in parsed) {
        if (item is String && item.trim().isNotEmpty) return item.trim();
      }
    }
  } catch (_) {
    return trimmed;
  }
  return null;
}
