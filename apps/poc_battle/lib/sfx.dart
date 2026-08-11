import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';

/// Port of `Assets/Scripts/Audio/Sfx.cs` (394 lines): a polyphonic one-shot
/// player with a per-cue cooldown and pitch jitter, plus the two music beds
/// cross-faded between menu and battle.
///
/// The cue table below is `Sfx.Awake`'s dictionary transliterated, including
/// the `RegisterExternal` overrides that trim volume for the recorded clips
/// (they peak near 0 dBFS where the synthesised stand-ins did not). Eleven
/// cues and both beds are the authored mp3s copied from
/// `Assets/Resources/Audio/`; the other five are baked from the C#'s own DSP
/// by `tools/bake_procedural_sfx.dart` — see that file for why.
///
/// Follows `Docs/AUDIO_IDENTIT.md` §9 (conservative runtime pitch
/// randomisation, never on music) and §11 (music sits under UI and combat:
/// the bed volumes here are the C#'s own 0.28 / 0.24).
///
/// Not ported: `EnsureAudioListener` (a Unity scene-graph repair with no
/// Flutter equivalent) and the generated `march` crowd loop, which the C#
/// starts as an always-on bed — this port leaves it out rather than add a
/// third continuously-mixed layer without being able to check it in the real
/// mix on a device, which §11.1 asks for.
class Sfx {
  Sfx._();

  static final Sfx instance = Sfx._();

  /// Per-cue tuning. `cd` is the cooldown in seconds that stops a cue
  /// pile-up, `vol` the playback gain, `jitter` the ± fraction of random
  /// pitch, `basePitch` a fixed multiplier.
  static const Map<String, _Cue> _cues = {
    // Synthesised in C#, baked to wav here.
    'shoot': _Cue('sfx/shoot.wav', cd: 0, vol: 0.16, jitter: 0.16),
    'pop': _Cue('sfx/pop.wav', cd: 0.04, vol: 0.45, jitter: 0.25),
    'gate': _Cue('sfx/gate.wav', cd: 0.05, vol: 0.55, jitter: 0.04),
    'win': _Cue('sfx/win.wav', cd: 0, vol: 0.9, jitter: 0),
    'lose': _Cue('sfx/lose.wav', cd: 0, vol: 0.9, jitter: 0),
    // Authored mp3s. Volumes are the RegisterExternal overrides.
    'hit': _Cue('sfx/hit.mp3', cd: 0.05, vol: 0.55, jitter: 0.12),
    'baseHit': _Cue('sfx/baseHit.mp3', cd: 0.1, vol: 0.8, jitter: 0.08),
    'destroy': _Cue('sfx/destroy.mp3', cd: 0, vol: 0.9, jitter: 0.05),
    'click': _Cue('sfx/click.mp3', cd: 0, vol: 0.72, jitter: 0),
    'battleClick': _Cue('sfx/battleClick.mp3', cd: 0, vol: 0.82, jitter: 0),
    'clash': _Cue('sfx/clash.mp3', cd: 0.06, vol: 0.35, jitter: 0.15),
    'land': _Cue('sfx/land.mp3', cd: 0.05, vol: 0.5, jitter: 0.12),
    'freeze': _Cue('sfx/freeze.mp3', cd: 0.10, vol: 0.8, jitter: 0.03),
    'fireball': _Cue('sfx/fireball.mp3', cd: 0.05, vol: 0.95, jitter: 0.04),
    'lightning': _Cue('sfx/lightning.mp3', cd: 0.05, vol: 0.95, jitter: 0.04),
  };

  static const _menuMusicVolume = 0.28; // Sfx.MenuMusicVolume
  static const _battleMusicVolume = 0.24; // Sfx.BattleMusicVolume

  /// `Sfx` runs ten `AudioSource` voices round-robin so a burst of cannon
  /// shots never cuts itself off. Same idea here.
  static const _voiceCount = 10;

  final List<AudioPlayer> _voices = [];
  final Map<String, DateTime> _last = {};
  final math.Random _rng = math.Random();
  int _next = 0;

  AudioPlayer? _menuMusic;
  AudioPlayer? _battleMusic;

  bool _ready = false;
  bool _muted = false;

  bool get muted => _muted;

  Future<void> init() async {
    if (_ready) return;
    _ready = true;
    for (var i = 0; i < _voiceCount; i++) {
      final p = AudioPlayer()..setReleaseMode(ReleaseMode.stop);
      await p.setPlayerMode(PlayerMode.lowLatency);
      _voices.add(p);
    }
    _menuMusic = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
    _battleMusic = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  }

  /// Port of `Sfx.Play`. [pitch] is the caller's multiplier — the gate uses
  /// it to pitch its chime up per combo, which is the one place the live
  /// game varies a cue deliberately rather than randomly.
  Future<void> play(String name, {double pitch = 1.0}) async {
    if (_muted || !_ready) return;
    final cue = _cues[name];
    if (cue == null) return;

    final now = DateTime.now();
    final last = _last[name];
    if (last != null && now.difference(last).inMicroseconds / 1e6 < cue.cd) {
      return;
    }
    _last[name] = now;

    final voice = _voices[_next];
    _next = (_next + 1) % _voices.length;

    // Sfx.PlayInternal: basePitch * pitchMul * (1 + Random(-jitter, jitter)).
    final jitter = cue.jitter == 0
        ? 1.0
        : 1.0 + (_rng.nextDouble() * 2 - 1) * cue.jitter;
    try {
      await voice.setPlaybackRate((pitch * jitter).clamp(0.5, 2.0));
      await voice.setVolume(cue.vol);
      await voice.play(AssetSource('audio/${cue.asset}'));
    } catch (_) {
      // A dropped one-shot must never take the frame down with it.
    }
  }

  Future<void> setMenuMusic() => _setMusic(battle: false);
  Future<void> setBattleMusic() => _setMusic(battle: true);

  /// The C# cross-fades the two beds every frame at 1.5 units/sec. Doing
  /// that from Dart would mean a timer ticking `setVolume` at 60Hz through
  /// a platform channel; `audioplayers` has no volume ramp of its own, so
  /// this fades in coarser steps over the same ~0.2s the C# takes to travel
  /// between 0 and 0.28.
  Future<void> _setMusic({required bool battle}) async {
    if (!_ready) return;
    final rising = battle ? _battleMusic : _menuMusic;
    final falling = battle ? _menuMusic : _battleMusic;
    final target = battle ? _battleMusicVolume : _menuMusicVolume;
    final source = battle ? 'audio/music/battle_theme.mp3' : 'audio/music/menu_theme.mp3';

    try {
      await falling?.stop();
      if (_muted) return;
      await rising?.setVolume(0);
      await rising?.play(AssetSource(source));
      const steps = 8;
      for (var i = 1; i <= steps; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
        if (_muted) return;
        await rising?.setVolume(target * i / steps);
      }
    } catch (_) {
      // Music is decoration; never let it break navigation.
    }
  }

  Future<void> stopMusic() async {
    await _menuMusic?.stop();
    await _battleMusic?.stop();
  }

  /// Backs `HomeMenu.cs`'s SOUND : ON/OFF toggle, which the settings modal
  /// exposes. Muting stops the beds outright rather than zeroing them, so a
  /// muted app is not still decoding audio in the background.
  Future<void> setMuted(bool value) async {
    _muted = value;
    if (value) await stopMusic();
  }
}

class _Cue {
  const _Cue(this.asset, {required this.cd, required this.vol, required this.jitter});

  final String asset;
  final double cd;
  final double vol;
  final double jitter;
}
