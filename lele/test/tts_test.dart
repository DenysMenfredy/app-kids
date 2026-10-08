import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
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

/// Stands in for the platform engine.
///
/// [emptyReplies] reproduces the behaviour that caused the bug: Chrome's
/// `speechSynthesis.getVoices()` answers with an empty list until the voice
/// list has loaded, and only then returns the real one.
class FakeTts extends FlutterTts {
  FakeTts({this.voices = const [], this.emptyReplies = 0});

  final List<TtsVoice> voices;
  final int emptyReplies;

  int voiceQueries = 0;
  String? language;
  Map<String, String>? chosenVoice;
  double? rate;
  final List<String> spoken = [];

  @override
  Future<dynamic> get getVoices async {
    voiceQueries++;
    if (voiceQueries <= emptyReplies) return <dynamic>[];
    return voices.map((v) => {'name': v.name, 'locale': v.locale}).toList();
  }

  @override
  Future<dynamic> setLanguage(String value) async => language = value;

  @override
  Future<dynamic> setVoice(Map<String, String> value) async =>
      chosenVoice = value;

  @override
  Future<dynamic> setSpeechRate(double value) async => rate = value;

  @override
  Future<dynamic> setPitch(double value) async {}

  @override
  Future<dynamic> awaitSpeakCompletion(bool value) async {}

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async =>
      spoken.add(text);

  @override
  Future<dynamic> stop() async {}
}

class DelayedVoiceTts extends FakeTts {
  final ready = Completer<List<dynamic>>();
  @override
  Future<dynamic> get getVoices => ready.future;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('pickPortugueseVoice', () {
    test('picks Brazilian Portuguese out of a mixed list', () {
      final chosen = pickPortugueseVoice(_chromeOnLinux);
      expect(chosen?.name, 'Google português do Brasil');
      expect(chosen?.locale, 'pt-BR');
    });

    test(
      'never settles for the platform default when it is another language',
      () {
        // The bug this guards: Chrome's default here is German, and a voice
        // chosen by language alone read Portuguese with German phonetics.
        final chosen = pickPortugueseVoice(_chromeOnLinux);
        expect(chosen?.locale, isNot('de-DE'));
      },
    );

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

  group('awaitVoices', () {
    test('takes the list straight away when the platform has one', () async {
      var calls = 0;
      final voices = await awaitVoices(() async {
        calls++;
        return _chromeOnLinux;
      });
      expect(voices, _chromeOnLinux);
      // Mobile answers immediately; it must not pay for a poll it never needs.
      expect(calls, 1);
    });

    test('keeps asking until the browser has finished loading them', () async {
      var calls = 0;
      final voices = await awaitVoices(() async {
        calls++;
        return calls < 3 ? <TtsVoice>[] : _chromeOnLinux;
      }, gap: Duration.zero);
      expect(voices, _chromeOnLinux);
      expect(calls, 3);
    });

    test(
      'gives up rather than waiting forever on a device with none',
      () async {
        var calls = 0;
        final voices = await awaitVoices(
          () async {
            calls++;
            return <TtsVoice>[];
          },
          attempts: 4,
          gap: Duration.zero,
        );
        expect(voices, isEmpty);
        expect(calls, 4);
      },
    );
  });

  group('TtsService', () {
    test(
      'stopping while voices load cancels the pending page narration',
      () async {
        final tts = DelayedVoiceTts();
        final service = TtsService(tts);
        final pending = service.speak('Uma página antiga');
        await service.stop();
        tts.ready.complete([
          {'name': 'Português', 'locale': 'pt-BR'},
        ]);
        await pending;
        expect(tts.spoken, isEmpty);
      },
    );
    test('picks pt-BR even when the voice list loads late', () async {
      // The reported bug: Chrome returned no voices at the moment the engine
      // was configured, so nothing was selected and it read pt-BR text with
      // its default German voice.
      final tts = FakeTts(voices: _chromeOnLinux, emptyReplies: 2);
      await TtsService(tts).speak('Toque na letra A');

      expect(tts.chosenVoice, {
        'name': 'Google português do Brasil',
        'locale': 'pt-BR',
      });
      expect(tts.language, 'pt-BR');
      expect(tts.spoken, ['Toque na letra A']);
    });

    test('configures the voice before it speaks a word', () async {
      final tts = FakeTts(voices: _chromeOnLinux, emptyReplies: 1);
      final service = TtsService(tts);
      await service.speak('Oi');
      expect(tts.chosenVoice, isNotNull, reason: 'set before speaking');
      expect(service.voice?.locale, 'pt-BR');
    });

    test(
      'configures once across a warm-up and the utterances after it',
      () async {
        final tts = FakeTts(voices: _chromeOnLinux);
        final service = TtsService(tts);
        await Future.wait([
          service.warmUp(),
          service.speak('uma'),
          service.speak('duas'),
        ]);
        await service.speak('tres');
        expect(tts.voiceQueries, 1);
      },
    );

    test('retries on the next utterance when no voices came back', () async {
      // A device that answers empty may simply still be loading. Latching
      // here would leave the whole session on the default voice.
      final tts = FakeTts(voices: _chromeOnLinux, emptyReplies: 100);
      final service = TtsService(tts, Duration.zero);
      await service.speak('uma');
      expect(tts.chosenVoice, isNull);

      final queriesAfterFirst = tts.voiceQueries;
      await service.speak('duas');
      expect(tts.voiceQueries, greaterThan(queriesAfterFirst));
    });

    test('still speaks when the device has no Portuguese at all', () async {
      final tts = FakeTts(voices: [voice('Google Deutsch', 'de-DE')]);
      final service = TtsService(tts);
      await service.speak('Toque na letra A');
      expect(service.voice, isNull);
      expect(tts.chosenVoice, isNull, reason: 'German is not an improvement');
      expect(tts.spoken, ['Toque na letra A']);
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
