import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/services/tts_service.dart';

TtsVoice voice(String name, String locale) =>
    TtsVoice(name: name, locale: locale);

/// What this machine's Chrome actually reports — note the default is German.
final _chromeOnLinux = [
  voice('Google Deutsch', 'de-DE'),
  voice('Google US English', 'en-US'),
  voice('Google español', 'es-ES'),
  voice('Google français', 'fr-FR'),
  voice('Google português do Brasil', 'pt-BR'),
];

void main() {
  group('pickPortugueseVoice', () {
    test('picks Brazilian Portuguese out of a mixed list', () {
      final chosen = pickPortugueseVoice(_chromeOnLinux);
      expect(chosen?.name, 'Google português do Brasil');
      expect(chosen?.locale, 'pt-BR');
    });

    test('never settles for the platform default when it is another language',
        () {
      // The bug this guards: Chrome's default here is German, and a voice
      // chosen by language alone read Portuguese with German phonetics.
      final chosen = pickPortugueseVoice(_chromeOnLinux);
      expect(chosen?.locale, isNot('de-DE'));
    });

    test('accepts the underscore form Android reports', () {
      final chosen = pickPortugueseVoice([
        voice('en-us-x-sfg#male_1-local', 'en_US'),
        voice('pt-br-x-ptd#female_2-local', 'pt_BR'),
      ]);
      expect(chosen?.locale, 'pt_BR');
    });

    test('prefers Brazilian over European Portuguese', () {
      final chosen = pickPortugueseVoice([
        voice('Portuguese (Portugal)', 'pt-PT'),
        voice('Português do Brasil', 'pt-BR'),
      ]);
      expect(chosen?.locale, 'pt-BR');
    });

    test('takes European Portuguese only when Brazilian is missing', () {
      final chosen = pickPortugueseVoice([
        voice('Google US English', 'en-US'),
        voice('Portuguese (Portugal)', 'pt-PT'),
      ]);
      expect(chosen?.locale, 'pt-PT');
    });

    test('returns null when the platform has no Portuguese at all', () {
      final chosen = pickPortugueseVoice([
        voice('Google Deutsch', 'de-DE'),
        voice('Google US English', 'en-US'),
      ]);
      expect(chosen, isNull);
    });

    test('returns null for an empty list rather than throwing', () {
      expect(pickPortugueseVoice([]), isNull);
    });

    test('is not fooled by a language whose code merely starts with p', () {
      final chosen = pickPortugueseVoice([
        voice('Polski', 'pl-PL'),
        voice('فارسی', 'fa-IR'),
      ]);
      expect(chosen, isNull);
    });
  });

  group('speech rate', () {
    test('is slower than normal speech, but not half speed', () {
      // Android and iOS call 0.5 normal; the browser calls 1.0 normal. The
      // rate has to be read against the right scale or the vowels slur.
      expect(ttsSpeechRate, greaterThan(0.3));
      expect(ttsSpeechRate, lessThan(1.0));
    });
  });

  group('TtsVoice', () {
    test('normalises the locale separators platforms disagree on', () {
      expect(voice('a', 'pt_BR').normalizedLocale, 'pt-br');
      expect(voice('a', 'pt-BR').normalizedLocale, 'pt-br');
      expect(voice('a', 'PT-br').normalizedLocale, 'pt-br');
    });

    test('hands flutter_tts the shape setVoice expects', () {
      expect(voice('Google português do Brasil', 'pt-BR').toMap(), {
        'name': 'Google português do Brasil',
        'locale': 'pt-BR',
      });
    });
  });
}
