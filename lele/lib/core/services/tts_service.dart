import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// The locale every child-facing phrase is written in.
const ttsLocale = 'pt-BR';

/// A voice offered by the platform's speech engine.
class TtsVoice {
  const TtsVoice({required this.name, required this.locale});

  final String name;
  final String locale;

  /// `pt_BR`, `pt-br` and `pt-BR` all mean the same thing across platforms.
  String get normalizedLocale => locale.replaceAll('_', '-').toLowerCase();

  Map<String, String> toMap() => {'name': name, 'locale': locale};

  @override
  String toString() => '$name [$locale]';
}

/// Chooses the voice to read Portuguese with.
///
/// Setting the *language* alone is not enough: the engine is free to keep
/// its default voice, and a machine whose default is, say, German will
/// happily read Portuguese text with German phonetics. Naming the voice
/// removes the choice.
///
/// Prefers an exact pt-BR match, then European Portuguese as a distant
/// second — wrong accent, but recognisably the right language. Returns null
/// when the platform has no Portuguese at all, which is the caller's cue to
/// say so rather than mispronounce everything.
TtsVoice? pickPortugueseVoice(List<TtsVoice> voices) {
  TtsVoice? firstWhereOrNull(bool Function(TtsVoice) test) {
    for (final voice in voices) {
      if (test(voice)) return voice;
    }
    return null;
  }

  return firstWhereOrNull((v) => v.normalizedLocale == 'pt-br') ??
      firstWhereOrNull((v) => v.normalizedLocale.startsWith('pt-br')) ??
      firstWhereOrNull((v) => v.normalizedLocale.startsWith('pt'));
}

/// How fast to speak, per platform.
///
/// The scales are not the same. flutter_tts doubles the value on Android
/// and passes it straight to AVSpeechUtterance on iOS, both of which call
/// 0.5 normal; on web it becomes `SpeechSynthesisUtterance.rate`, where 1.0
/// is normal. The single value that used to be shared here therefore ran at
/// 0.45x speed in a browser, which slurs the vowels and is a good part of
/// why the speech sounded wrong.
double get ttsSpeechRate => kIsWeb ? 0.85 : 0.45;

/// Waits for the platform to actually have a voice list.
///
/// This is the whole problem on web: `speechSynthesis.getVoices()` returns
/// an empty list on the first call and fills in asynchronously, and
/// flutter_tts reads it synchronously. Configure too early and both
/// setLanguage and setVoice match nothing, leaving the utterance on
/// whatever the browser defaults to — German, on a machine set up in
/// German. Mobile returns its list straight away and falls out on the first
/// attempt.
///
/// Gives up after [attempts], so a device with no voices at all costs a
/// bounded wait rather than hanging the first lesson.
Future<List<TtsVoice>> awaitVoices(
  Future<List<TtsVoice>> Function() loadVoices, {
  int attempts = 20,
  Duration gap = const Duration(milliseconds: 150),
}) async {
  for (var attempt = 0; attempt < attempts; attempt++) {
    final voices = await loadVoices();
    if (voices.isNotEmpty) return voices;
    if (attempt < attempts - 1) await Future<void>.delayed(gap);
  }
  return const [];
}

/// Text-to-speech for the child-facing activities, pinned to pt-BR.
class TtsService {
  TtsService([
    FlutterTts? tts,
    this.voiceWait = const Duration(milliseconds: 150),
  ]) : _tts = tts ?? FlutterTts();

  final FlutterTts _tts;

  /// How long to leave between asks while the platform loads its voices.
  final Duration voiceWait;
  bool _configured = false;

  /// Shared by every caller while a configure pass is in flight. Without it,
  /// a `speak` arriving during the warm-up would start a second pass and
  /// poll for voices all over again.
  Future<void>? _configuring;

  /// The voice actually in use, once known. Null means the platform had no
  /// Portuguese voice and whatever speaks will sound wrong.
  TtsVoice? get voice => _voice;
  TtsVoice? _voice;

  Future<List<TtsVoice>> availableVoices() async {
    try {
      final raw = await _tts.getVoices as List<dynamic>?;
      return (raw ?? [])
          .whereType<Map>()
          .map(
            (v) => TtsVoice(
              name: v['name']?.toString() ?? '',
              locale: v['locale']?.toString() ?? '',
            ),
          )
          .where((v) => v.name.isNotEmpty)
          .toList();
    } catch (_) {
      // Not every platform can enumerate voices; setLanguage still applies.
      return const [];
    }
  }

  /// On iOS, speech is silenced by the ring/silent switch unless the audio
  /// session says otherwise — and a child playing with the switch flipped
  /// would get a lesson that simply never speaks.
  Future<void> _configureIosAudio() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
        IosTextToSpeechAudioCategoryOptions.duckOthers,
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
      ], IosTextToSpeechAudioMode.voicePrompt);
    } catch (error) {
      // Not fatal: speech still works, it just obeys the silent switch.
      debugPrint('TTS iOS audio session: $error');
    }
  }

  Future<void> _configure() {
    if (_configured) return Future<void>.value();
    return _configuring ??= _runConfigure().whenComplete(() {
      _configuring = null;
    });
  }

  Future<void> _runConfigure() async {
    await _configureIosAudio();
    try {
      // Before anything else: flutter_tts resolves both the language and the
      // voice against whatever getVoices() returns at that instant.
      final voices = await awaitVoices(availableVoices, gap: voiceWait);

      await _tts.setLanguage(ttsLocale);

      final chosen = pickPortugueseVoice(voices);
      if (chosen != null) {
        await _tts.setVoice(chosen.toMap());
        _voice = chosen;
        if (chosen.normalizedLocale != 'pt-br') {
          debugPrint(
            'TTS: no pt-BR voice installed; falling back to $chosen. '
            'Pronunciation will not be Brazilian.',
          );
        }
      } else if (voices.isNotEmpty) {
        // Worth shouting about: everything the child hears will be read with
        // the wrong phonetics, and nothing else in the app reveals why.
        debugPrint(
          'TTS: no Portuguese voice on this device. Install the pt-BR voice '
          '(Android: Settings › Language & input › Text-to-speech; Chrome on '
          'Linux: a pt-BR speech-dispatcher voice). '
          'Available: ${voices.join(', ')}',
        );
      }

      await _tts.setSpeechRate(ttsSpeechRate);
      await _tts.setPitch(1.05);
      await _tts.awaitSpeakCompletion(true);

      // Latch only once the platform actually offered a voice list. An empty
      // one means it may still be loading, so the next utterance retries
      // instead of leaving the engine on its default voice for the session.
      _configured = voices.isNotEmpty;
    } catch (error) {
      debugPrint('TTS unavailable: $error');
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await _configure();
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (error) {
      debugPrint('TTS speak failed: $error');
    }
  }

  /// Settles the engine ahead of the first utterance, so waiting for the
  /// voice list doesn't delay the child's first "Toque na letra...".
  Future<void> warmUp() => _configure();

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }
}

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  // Unawaited on purpose: the voice list loads while the parent is still
  // reading the lesson intro.
  unawaited(service.warmUp());
  ref.onDispose(service.stop);
  return service;
});
