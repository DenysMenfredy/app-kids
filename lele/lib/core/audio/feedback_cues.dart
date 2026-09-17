import 'tone.dart';

/// The moments the app makes a noise about.
enum FeedbackCue {
  /// A wrong answer. Deliberately the most distinct of the three: a child
  /// who is not reading yet, and may not have heard the spoken "tente de
  /// novo" over a noisy room, still knows immediately that this was not it.
  wrong,

  /// A right answer, mid-lesson.
  correct,

  /// The end of a lesson.
  celebrate,
}

/// Note frequencies, named so the recipes below read as music rather than
/// as numbers.
const _g3 = 196.0;
const _bb3 = 233.08;
const _eb4 = 311.13;
const _c5 = 523.25;
const _e5 = 659.25;
const _g5 = 783.99;
const _c6 = 1046.50;

/// How each cue is built.
///
/// The shapes are deliberate: wrong falls, right rises. Pitch direction is
/// understood long before words are, so the sound carries the verdict on its
/// own for a three-year-old.
const cueRecipes = <FeedbackCue, List<ToneSegment>>{
  FeedbackCue.wrong: [
    // Two descending buzzes — the "uh-oh" shape. Square for the rasp that
    // separates it from every friendly sound in the app.
    ToneSegment(
      startHz: _eb4,
      seconds: 0.13,
      waveform: Waveform.square,
      gain: 0.45,
    ),
    ToneSegment.silence(0.04),
    ToneSegment(
      startHz: _bb3,
      endHz: _g3,
      seconds: 0.32,
      waveform: Waveform.square,
      gain: 0.5,
    ),
  ],
  FeedbackCue.correct: [
    // A rising major triad: the shortest phrase that sounds like "yes".
    ToneSegment(startHz: _c5, seconds: 0.08, gain: 0.42),
    ToneSegment(startHz: _e5, seconds: 0.08, gain: 0.42),
    ToneSegment(startHz: _g5, seconds: 0.2, gain: 0.45),
  ],
  FeedbackCue.celebrate: [
    // The same triad carried an octave up, so finishing a lesson is
    // recognisably "the right answer, but more".
    ToneSegment(startHz: _c5, seconds: 0.09, gain: 0.42),
    ToneSegment(startHz: _e5, seconds: 0.09, gain: 0.42),
    ToneSegment(startHz: _g5, seconds: 0.09, gain: 0.45),
    ToneSegment(startHz: _c6, seconds: 0.34, gain: 0.48),
  ],
};

/// Renders [cue] to a playable WAV.
///
/// Swapping any cue for a recorded file later means changing only the bytes
/// this returns — no call site names a tone.
List<ToneSegment> segmentsFor(FeedbackCue cue) => cueRecipes[cue]!;
