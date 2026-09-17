import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/feedback_cues.dart';
import '../audio/tone.dart';

/// Prefix every log line so a silent app can be diagnosed with one grep.
const _tag = '[lele-sound]';

/// How a short interface sound should be played.
///
/// The defaults are wrong for this: audioplayers asks for
/// [AndroidAudioFocus.gain], which is what a music player wants and which
/// takes focus away from the speech engine. Here the cue and the spoken
/// prompt are deliberately simultaneous — the child hears the buzz while
/// "tente de novo" is still forming — so this asks for no focus at all and
/// declares itself as interface sonification rather than media.
///
/// On iOS [AVAudioSessionCategory.ambient] mixes with other audio by
/// default and honours the physical silent switch, which is the right
/// behaviour for feedback: a parent who silenced the phone meant it.
final _interfaceSound = AudioContext(
  android: const AudioContextAndroid(
    contentType: AndroidContentType.sonification,
    usageType: AndroidUsageType.assistanceSonification,
    audioFocus: AndroidAudioFocus.none,
  ),
  iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
);

/// Plays the short sound — and the matching buzz — that tells a child how
/// they did.
///
/// Sound and haptics are one call rather than two because they are one
/// event: every place that wants the noise wants the bump, and letting a
/// screen fire one without the other is how they drift apart.
abstract interface class FeedbackService {
  Future<void> play(FeedbackCue cue);

  /// Renders the cues and opens the players, so the first wrong answer is
  /// not the one that pays for it — and so a broken audio stack is reported
  /// at startup rather than silently at the worst moment.
  Future<void> warmUp();

  Future<void> dispose();
}

/// The real thing: tones synthesised at startup, held in memory, played
/// through the platform's audio stack.
class ToneFeedbackService implements FeedbackService {
  final _cache = <FeedbackCue, Uint8List>{};

  /// One player per cue. Sharing a single player cuts a sound off when the
  /// next one starts, which a child tapping quickly would hear as stutter.
  final _players = <FeedbackCue, AudioPlayer>{};

  bool _disposed = false;

  /// Why the last sound did not play, if it did not. Nothing reads this
  /// yet; it exists so that "I can't hear anything" has an answer that is
  /// not a guess.
  Object? lastError;

  Uint8List _bytesFor(FeedbackCue cue) =>
      _cache[cue] ??= renderWav(segmentsFor(cue));

  @override
  Future<void> warmUp() async {
    for (final cue in FeedbackCue.values) {
      _bytesFor(cue);
    }
    try {
      await AudioPlayer.global.setAudioContext(_interfaceSound);
      for (final cue in FeedbackCue.values) {
        await _open(cue);
      }
      debugPrint('$_tag ready — ${FeedbackCue.values.length} cues loaded');
    } catch (error) {
      _report(error, during: 'warm-up');
    }
  }

  Future<AudioPlayer> _open(FeedbackCue cue) async {
    final existing = _players[cue];
    if (existing != null) return existing;
    final player = AudioPlayer(playerId: 'lele-${cue.name}');
    await player.setAudioContext(_interfaceSound);
    await player.setReleaseMode(ReleaseMode.stop);
    _players[cue] = player;
    return player;
  }

  @override
  Future<void> play(FeedbackCue cue) async {
    if (_disposed) return;
    _haptic(cue);
    try {
      final player = await _open(cue);
      await player.play(
        BytesSource(_bytesFor(cue), mimeType: 'audio/wav'),
        volume: 1,
      );
    } catch (error) {
      _report(error, during: 'play($cue)');
    }
  }

  /// Never rethrows: a missing or busy audio device must not interrupt a
  /// lesson, because the spoken prompt and the animation still carry the
  /// feedback. It does insist on being findable in the log.
  void _report(Object error, {required String during}) {
    lastError = error;
    if (error is MissingPluginException) {
      // The exact failure this code shipped with: audioplayers has native
      // Android and iOS code, and neither hot reload nor hot restart can
      // add a platform plugin to a binary that was built without it.
      debugPrint(
        '$_tag NO AUDIO PLUGIN IN THIS BUILD. Stop the app and run it '
        'again — a hot reload or hot restart cannot add a native plugin.',
      );
      return;
    }
    debugPrint('$_tag failed during $during: $error');
  }

  void _haptic(FeedbackCue cue) {
    // Fire and forget: a buzz that arrives late is still useful, and one
    // that fails must not swallow the sound that follows it.
    final buzz = switch (cue) {
      FeedbackCue.wrong => HapticFeedback.heavyImpact(),
      FeedbackCue.correct => HapticFeedback.lightImpact(),
      FeedbackCue.celebrate => HapticFeedback.mediumImpact(),
    };
    // Desktop and web have no vibration motor.
    unawaited(buzz.catchError((_) {}));
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    for (final player in _players.values) {
      try {
        await player.dispose();
      } catch (_) {}
    }
    _players.clear();
  }
}

/// Makes no sound. Used where there is no audio stack to talk to.
class SilentFeedbackService implements FeedbackService {
  const SilentFeedbackService();

  @override
  Future<void> play(FeedbackCue cue) async {}

  @override
  Future<void> warmUp() async {}

  @override
  Future<void> dispose() async {}
}

final feedbackServiceProvider = Provider<FeedbackService>((ref) {
  final service = ToneFeedbackService();
  // Unawaited on purpose: rendering and opening happen while the child is
  // still reading the lesson intro.
  unawaited(service.warmUp());
  ref.onDispose(service.dispose);
  return service;
});
