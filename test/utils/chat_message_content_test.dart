import 'package:flutter_test/flutter_test.dart';
import 'package:fluxdo/models/chat/chat_message.dart';
import 'package:fluxdo/utils/chat_message_content.dart';

void main() {
  ChatMessage message({String? raw, String? cooked}) =>
      ChatMessage(id: 1, channelId: 2, message: raw, cooked: cooked);

  test('keeps server cooked HTML unchanged', () {
    const cooked =
        '<p><img class="emoji" src="/images/emoji/twitter/tada.png"></p>';

    expect(chatMessageHtml(message(raw: ':tada:', cooked: cooked)), cooked);
  });

  test('renders emoji shortcodes while cooked HTML is pending', () {
    final html = chatMessageHtml(message(raw: 'hello :tada:'));

    expect(html, contains('hello '));
    expect(html, contains('class="emoji"'));
    expect(html, contains('/images/emoji/twitter/tada.png'));
  });

  test('escapes raw chat text before creating emoji HTML', () {
    final html = chatMessageHtml(message(raw: '<script>x</script>\n:heart:'));

    expect(html, isNot(contains('<script>')));
    expect(html, contains('&lt;script&gt;x&lt;/script&gt;<br>'));
    expect(html, contains('class="emoji"'));
  });
}
