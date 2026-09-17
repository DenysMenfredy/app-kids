import 'dart:math' as math;
import 'dart:typed_data';

/// Shape of a synthesised tone.
///
/// [square] carries the buzz a "that's not it" needs; [triangle] is the
/// softer, rounder voice used for anything congratulatory. Plain [sine] is
/// too polite to read as feedback on its own.
enum Waveform { sine, square, triangle }

/// One note of a synthesised sound effect.
///
/// A sound is a short list of these. Frequency sweeps from [startHz] to
/// [endHz] across the segment, which is what makes a fall read as
/// disappointment and a rise as praise.
class ToneSegment {
  const ToneSegment({
    required this.startHz,
    required this.seconds,
    double? endHz,
    this.waveform = Waveform.triangle,
    this.gain = 0.5,
  }) : endHz = endHz ?? startHz;

  /// A gap between notes. Silence is what separates two beeps from one
  /// long one.
  const ToneSegment.silence(this.seconds)
    : startHz = 0,
      endHz = 0,
      waveform = Waveform.sine,
      gain = 0;

  final double startHz;
  final double endHz;
  final double seconds;
  final Waveform waveform;

  /// Peak amplitude, 0..1. Kept well under 1 so the sum never clips and so
  /// the app never startles a child who is sitting close to the speaker.
  final double gain;
}

/// 22.05kHz is ample for tones under 2kHz and halves the bytes we hand to
/// the platform player versus CD rate.
const _sampleRate = 22050;

/// Long enough to stop a note starting or ending with an audible click,
/// short enough not to soften the attack.
const _attack = Duration(milliseconds: 6);
const _release = Duration(milliseconds: 28);

/// Renders [segments] to a 16-bit mono PCM WAV.
///
/// Returns a complete file — header included — so the result can go
/// straight to a platform audio player as bytes, with no asset to ship and
/// nothing to decode.
Uint8List renderWav(List<ToneSegment> segments) {
  final samples = <int>[];

  for (final segment in segments) {
    final count = (segment.seconds * _sampleRate).round();
    if (count <= 0) continue;

    final attackSamples = math.min(
      (_attack.inMicroseconds * _sampleRate) ~/ 1000000,
      count ~/ 2,
    );
    final releaseSamples = math.min(
      (_release.inMicroseconds * _sampleRate) ~/ 1000000,
      count ~/ 2,
    );

    // Phase is accumulated rather than recomputed from t, so a frequency
    // sweep stays continuous instead of clicking on every sample.
    var phase = 0.0;
    for (var i = 0; i < count; i++) {
      final progress = count == 1 ? 0.0 : i / (count - 1);
      final hz = segment.startHz + (segment.endHz - segment.startHz) * progress;
      phase += 2 * math.pi * hz / _sampleRate;

      var envelope = 1.0;
      if (i < attackSamples) {
        envelope = i / attackSamples;
      } else if (i >= count - releaseSamples) {
        envelope = (count - 1 - i) / releaseSamples;
      }

      final value = _sample(segment.waveform, phase) * segment.gain * envelope;
      samples.add((value.clamp(-1.0, 1.0) * 32767).round());
    }
  }

  return _wavFile(Int16List.fromList(samples));
}

double _sample(Waveform waveform, double phase) {
  switch (waveform) {
    case Waveform.sine:
      return math.sin(phase);
    case Waveform.square:
      return math.sin(phase) >= 0 ? 1.0 : -1.0;
    case Waveform.triangle:
      final cycle = (phase / (2 * math.pi)) % 1.0;
      return 4 * (cycle < 0.5 ? cycle : 1 - cycle) - 1;
  }
}

/// Wraps PCM samples in a canonical 44-byte RIFF/WAVE header.
Uint8List _wavFile(Int16List samples) {
  const headerBytes = 44;
  const bitsPerSample = 16;
  const channels = 1;
  final dataBytes = samples.length * 2;

  final out = ByteData(headerBytes + dataBytes);
  void ascii(int offset, String tag) {
    for (var i = 0; i < tag.length; i++) {
      out.setUint8(offset + i, tag.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  out.setUint32(4, headerBytes - 8 + dataBytes, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  out.setUint32(16, 16, Endian.little); // PCM chunk size
  out.setUint16(20, 1, Endian.little); // uncompressed
  out.setUint16(22, channels, Endian.little);
  out.setUint32(24, _sampleRate, Endian.little);
  out.setUint32(
    28,
    _sampleRate * channels * bitsPerSample ~/ 8,
    Endian.little,
  ); // byte rate
  out.setUint16(32, channels * bitsPerSample ~/ 8, Endian.little); // align
  out.setUint16(34, bitsPerSample, Endian.little);
  ascii(36, 'data');
  out.setUint32(40, dataBytes, Endian.little);

  for (var i = 0; i < samples.length; i++) {
    out.setInt16(headerBytes + i * 2, samples[i], Endian.little);
  }
  return out.buffer.asUint8List();
}
