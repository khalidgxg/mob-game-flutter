// Bakes the five procedurally-synthesised cues from `Assets/Scripts/Audio/
// Sfx.cs` into WAV files for the Flutter build.
//
// Eleven of MobRush's sixteen cues, plus both music beds, already exist as
// authored mp3s under `Assets/Resources/Audio/` and are copied across
// unchanged. The other five (`shoot`, `pop`, `gate`, `win`, `lose`) are not
// files at all in Unity — `Sfx.Awake` synthesises them with DSP at startup
// and hands the samples to `AudioClip.Create`. Flutter's audio players take
// files, not sample buffers, so the same math runs here at build time
// instead and the result is committed.
//
// This keeps the audio identical to the live game without generating a
// single new asset: the generators below are transliterations of `Shoot()`,
// `Pop()`, `GateChime()`, `WinJingle()` and `Arp()`, including `Build()`'s
// short fade at both ends.
//
// Run: dart run tools/bake_procedural_sfx.dart
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

const int rate = 22050; // Sfx.Rate
const double tau = 6.2831853; // Sfx.Tau

/// Seeded so a re-bake is byte-identical; the C# uses `Random.value`, which
/// only needs to be *a* noise sequence, not a specific one.
final math.Random _rng = math.Random(20260811);

double _noise() => _rng.nextDouble() * 2.0 - 1.0;

double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

double _clamp01(double v) => v.clamp(0.0, 1.0);

/// Port of `Sfx.Shoot` — soft airy "thoop", machine-gunned by the cannon.
List<double> shoot() {
  final n = (rate * 0.07).toInt();
  return List<double>.generate(n, (i) {
    final t = i / rate;
    final env = math.exp(-t * 48);
    final freq = _lerp(680, 290, t / 0.07);
    return (math.sin(tau * freq * t) * 0.85 + _noise() * 0.15) * env * 0.5;
  });
}

/// Port of `Sfx.Pop` — cute up-chirp bubble pop for clashes.
List<double> pop() {
  final n = (rate * 0.055).toInt();
  return List<double>.generate(n, (i) {
    final t = i / rate;
    final env = math.exp(-t * 70);
    final freq = _lerp(320, 950, t / 0.055);
    return (math.sin(tau * freq * t) * 0.7 + _noise() * 0.3) * env * 0.55;
  });
}

/// Port of `Sfx.GateChime` — bright two-note chime, A5 → D6, with harmonics.
List<double> gateChime() {
  final n = (rate * 0.16).toInt();
  return List<double>.generate(n, (i) {
    final t = i / rate;
    final f = t < 0.06 ? 880.0 : 1174.66;
    final env = math.exp(-t * 14);
    final tone = math.sin(tau * f * t) * 0.6 +
        math.sin(tau * f * 2 * t) * 0.22 +
        math.sin(tau * f * 3 * t) * 0.08;
    return tone * env * 0.5;
  });
}

/// Port of `Sfx.WinJingle` — rising C-major arpeggio whose notes ring over
/// each other, so this one accumulates rather than generating per-sample.
List<double> winJingle() {
  const notes = [523.25, 659.25, 783.99, 1046.5, 1318.5];
  const dur = 0.11;
  final per = (rate * dur).toInt();
  final s = List<double>.filled(per * notes.length + (rate * 0.25).toInt(), 0);
  for (var k = 0; k < notes.length; k++) {
    final f = notes[k];
    for (var i = 0; i < per * 2 && k * per + i < s.length; i++) {
      final t = i / rate;
      final env = math.exp(-t * 7) * _clamp01(t * 60);
      final tone = math.sin(tau * f * t) * 0.5 + math.sin(tau * f * 2 * t) * 0.18;
      s[k * per + i] += tone * env * 0.4;
    }
  }
  return s;
}

/// Port of `Sfx.Arp`. `lose` is this over a descending G–E♭–B♭.
List<double> arp(List<double> freqs, double noteDur) {
  final per = (rate * noteDur).toInt();
  final s = List<double>.filled(per * freqs.length, 0);
  var idx = 0;
  for (final f in freqs) {
    for (var i = 0; i < per; i++) {
      final t = i / rate;
      final env = _clamp01(math.sin(math.pi * (t / noteDur)));
      final tone = math.sin(tau * f * t) * 0.6 + math.sin(tau * f * 2 * t) * 0.2;
      s[idx++] = tone * env * 0.4;
    }
  }
  return s;
}

/// Port of `Sfx.Build`'s fade — `min(200, n/8)` samples ramped in at both
/// ends, which is what keeps these clips from clicking on start and stop.
List<double> applyFade(List<double> s) {
  final n = s.length;
  final fade = math.min(200, n ~/ 8);
  for (var i = 0; i < fade; i++) {
    final g = i / fade;
    s[i] *= g;
    s[n - 1 - i] *= g;
  }
  return s;
}

/// Mono 16-bit PCM WAV at [rate]. Samples are hard-clipped to [-1, 1] first;
/// the generators above can sum past unity in `winJingle`'s overlap.
Uint8List toWav(List<double> samples) {
  final n = samples.length;
  final data = ByteData(44 + n * 2);
  void ascii(int offset, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(offset + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + n * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little); // PCM chunk size
  data.setUint16(20, 1, Endian.little); // PCM
  data.setUint16(22, 1, Endian.little); // mono
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little); // byte rate
  data.setUint16(32, 2, Endian.little); // block align
  data.setUint16(34, 16, Endian.little); // bits per sample
  ascii(36, 'data');
  data.setUint32(40, n * 2, Endian.little);

  for (var i = 0; i < n; i++) {
    final v = (samples[i].clamp(-1.0, 1.0) * 32767).round();
    data.setInt16(44 + i * 2, v, Endian.little);
  }
  return data.buffer.asUint8List();
}

void main() {
  const outDir = 'apps/poc_battle/assets/audio/sfx';
  Directory(outDir).createSync(recursive: true);

  final cues = <String, List<double>>{
    'shoot': shoot(),
    'pop': pop(),
    'gate': gateChime(),
    'win': winJingle(),
    'lose': arp([392.0, 311.13, 233.08], 0.18),
  };

  cues.forEach((name, samples) {
    final bytes = toWav(applyFade(samples));
    File('$outDir/$name.wav').writeAsBytesSync(bytes);
    final seconds = (samples.length / rate).toStringAsFixed(3);
    stdout.writeln('$name.wav  ${samples.length} samples  ${seconds}s  '
        '${bytes.length} bytes');
  });
}
