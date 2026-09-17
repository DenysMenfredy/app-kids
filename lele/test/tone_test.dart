import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:lele/core/audio/feedback_cues.dart';
import 'package:lele/core/audio/tone.dart';

const _sampleRate = 22050;
const _headerBytes = 44;

String _tag(ByteData data, int offset) => String.fromCharCodes([
  for (var i = 0; i < 4; i++) data.getUint8(offset + i),
]);

void main() {
  group('renderWav produces a real WAV file', () {
    final wav = renderWav(const [ToneSegment(startHz: 440, seconds: 0.1)]);
    final data = ByteData.sublistView(wav);

    test('carries a canonical RIFF/WAVE header', () {
      expect(_tag(data, 0), 'RIFF');
      expect(_tag(data, 8), 'WAVE');
      expect(_tag(data, 12), 'fmt ');
      expect(_tag(data, 36), 'data');
    });

    test('declares 16-bit mono PCM at the rate it renders', () {
      expect(data.getUint16(20, Endian.little), 1, reason: 'uncompressed PCM');
      expect(data.getUint16(22, Endian.little), 1, reason: 'mono');
      expect(data.getUint32(24, Endian.little), _sampleRate);
      expect(data.getUint16(34, Endian.little), 16, reason: 'bits per sample');
      expect(
        data.getUint32(28, Endian.little),
        _sampleRate * 2,
        reason: 'byte rate = rate * channels * bytes per sample',
      );
      expect(data.getUint16(32, Endian.little), 2, reason: 'block align');
    });

    test('the declared sizes match the bytes actually present', () {
      final dataBytes = data.getUint32(40, Endian.little);
      expect(dataBytes, wav.length - _headerBytes);
      expect(data.getUint32(4, Endian.little), wav.length - 8);
    });

    test('renders the requested duration', () {
      final samples = (wav.length - _headerBytes) ~/ 2;
      expect(samples, (0.1 * _sampleRate).round());
    });
  });

  group('the sound itself', () {
    Int16List samplesOf(Uint8List wav) =>
        Int16List.sublistView(wav, _headerBytes);

    test('opens and closes near silence, so it cannot click', () {
      final samples = samplesOf(
        renderWav(const [ToneSegment(startHz: 440, seconds: 0.2)]),
      );
      expect(samples.first.abs(), lessThan(1200));
      expect(samples.last.abs(), lessThan(1200));
    });

    test('a silent segment really is silent', () {
      final samples = samplesOf(renderWav(const [ToneSegment.silence(0.05)]));
      expect(samples, isNotEmpty);
      expect(samples.every((s) => s == 0), isTrue);
    });

    test('never clips, however the segments stack up', () {
      for (final cue in FeedbackCue.values) {
        final samples = samplesOf(renderWav(segmentsFor(cue)));
        final peak = samples
            .map((s) => s.abs())
            .reduce((a, b) => a > b ? a : b);
        expect(
          peak,
          lessThan(32767),
          reason: '$cue peaks at the rail and would distort',
        );
        expect(peak, greaterThan(3000), reason: '$cue is too quiet to hear');
      }
    });

    test('a falling sweep ends lower than it starts', () {
      // Zero crossings per half are a cheap proxy for pitch.
      final samples = samplesOf(
        renderWav(const [ToneSegment(startHz: 800, endHz: 200, seconds: 0.4)]),
      );
      int crossings(Iterable<int> xs) {
        var count = 0;
        var previous = 0;
        for (final s in xs) {
          if (previous < 0 && s >= 0) count++;
          previous = s;
        }
        return count;
      }

      final half = samples.length ~/ 2;
      expect(
        crossings(samples.take(half)),
        greaterThan(crossings(samples.skip(half))),
      );
    });
  });

  group('every cue is playable', () {
    for (final cue in FeedbackCue.values) {
      test('$cue renders within a sensible length', () {
        final wav = renderWav(segmentsFor(cue));
        final seconds = (wav.length - _headerBytes) / 2 / _sampleRate;
        expect(seconds, greaterThan(0.1));
        expect(
          seconds,
          lessThan(1.0),
          reason: 'feedback must not outlast the moment it describes',
        );
      });
    }
  });

  test('wrong is the most distinct cue: it falls where the others rise', () {
    double centreHz(List<ToneSegment> segments) {
      final voiced = segments.where((s) => s.gain > 0).toList();
      return voiced
              .map((s) => (s.startHz + s.endHz) / 2)
              .reduce((a, b) => a + b) /
          voiced.length;
    }

    final wrong = segmentsFor(FeedbackCue.wrong).where((s) => s.gain > 0);
    expect(
      wrong.last.endHz,
      lessThan(wrong.first.startHz),
      reason: 'the wrong cue must fall',
    );

    final correct = segmentsFor(FeedbackCue.correct).where((s) => s.gain > 0);
    expect(
      correct.last.endHz,
      greaterThan(correct.first.startHz),
      reason: 'the correct cue must rise',
    );

    expect(
      centreHz(segmentsFor(FeedbackCue.wrong)),
      lessThan(centreHz(segmentsFor(FeedbackCue.correct))),
      reason: 'wrong sits below correct so the two can never be confused',
    );
  });
}
