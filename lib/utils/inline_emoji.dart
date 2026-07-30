import 'package:emoji_extension/emoji_extension.dart';

/// Converts Unicode emoji to the shortcode form consumed by [EmojiHandler].
///
/// Discord shortcode names are compatible with the names used by Discourse's
/// Twitter emoji set for the standard emoji displayed in compact text.
String normalizeInlineEmoji(String text) {
  if (!text.emojis.contains) return text;
  return text.emojis.toDiscordShortcodes();
}

bool containsInlineEmoji(String text) {
  return text.contains(':') || text.emojis.contains;
}
