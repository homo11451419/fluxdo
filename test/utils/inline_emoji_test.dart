import 'package:flutter_test/flutter_test.dart';
import 'package:fluxdo/utils/inline_emoji.dart';

void main() {
  test('converts Unicode emoji to image-renderable shortcodes', () {
    expect(normalizeInlineEmoji('Hello 😀'), 'Hello :grinning:');
  });

  test('preserves existing Discourse shortcodes', () {
    expect(normalizeInlineEmoji('Hello :tada:'), 'Hello :tada:');
  });

  test('detects Unicode and shortcode emoji', () {
    expect(containsInlineEmoji('subject 😀'), isTrue);
    expect(containsInlineEmoji('subject :tada:'), isTrue);
    expect(containsInlineEmoji('plain subject'), isFalse);
  });
}
