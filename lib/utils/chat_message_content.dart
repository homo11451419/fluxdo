import 'dart:convert';

import '../models/chat/chat_message.dart';
import '../services/emoji_handler.dart';

/// Returns renderable HTML for a chat message.
///
/// Chat broadcasts may arrive before Discourse finishes producing [ChatMessage.cooked].
/// Keep the raw-message fallback safe, while still rendering emoji shortcodes during
/// that short processing window.
String? chatMessageHtml(ChatMessage message) {
  final cooked = message.cooked;
  if (cooked != null && cooked.isNotEmpty) return cooked;

  final raw = message.message;
  if (raw == null || raw.isEmpty) return null;

  final escaped = const HtmlEscape(HtmlEscapeMode.element).convert(raw);
  return EmojiHandler().replaceEmojis(escaped).replaceAll('\n', '<br>');
}
