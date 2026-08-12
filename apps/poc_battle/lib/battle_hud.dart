import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mobrush_data/mobrush_data.dart';
import 'package:mobrush_save/mobrush_save.dart';
import 'package:mobrush_sim/mobrush_sim.dart';

import 'sfx.dart';
import 'stage1_game.dart';
import 'structure_artwork.dart';
import 'ui_theme.dart';

/// The battle chrome is Flutter while the live battlefield underneath is
/// Flame. This keeps text, safe areas and touch targets crisp without turning
/// the reference image into one non-interactive screenshot.
class BattleHud extends StatefulWidget {
  const BattleHud({
    super.key,
    required this.game,
    required this.profile,
    required this.onRestart,
    required this.onOpenMap,
    required this.onGoHome,
  });

  final Stage1Game game;
  final PlayerProfile? profile;
  final VoidCallback onRestart;
  final VoidCallback onOpenMap;
  final VoidCallback onGoHome;

  @override
  State<BattleHud> createState() => _BattleHudState();
}

class _BattleHudState extends State<BattleHud> {
  static const _navy = Color(0xF2111D39);
  static const _navyDeep = Color(0xFF071127);
  static const _blue = Color(0xFF168DFF);
  static const _cyan = Color(0xFF5DD4FF);
  static const _gold = Color(0xFFFFC43A);
  static const _red = Color(0xFFFF4E43);

  String? _hint;
  Color _hintColor = Colors.white;

  void _showHint(String text, Color color) {
    setState(() {
      _hint = text;
      _hintColor = color;
    });
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _hint == text) setState(() => _hint = null);
    });
  }

  void _tryBattleAction() {
    Sfx.instance.play('battleClick');
    if (!widget.game.battleStarted) {
      widget.game.startBattle();
      _showHint('BATTLE STARTED', _gold);
      return;
    }
    final result = widget.game.tryRush();
    _showHint(result, result == 'RUSH DEPLOYED' ? _gold : _red);
  }

  void _tryAbility(Ability ability) {
    Sfx.instance.play('click');
    final result = widget.game.tryAbility(ability);
    final ok =
        result != 'NO VALID TARGET' && result != 'START THE BATTLE FIRST';
    if (ok) {
      Sfx.instance.play(switch (ability) {
        Ability.freeze => 'freeze',
        Ability.fireball => 'fireball',
        Ability.lightning => 'lightning',
      });
    }
    _showHint(result, ok ? _gold : _red);
  }

  void _selectUnit(CharacterDefinition character) {
    Sfx.instance.play('click');
    if (widget.game.selectCharacter(character.id)) {
      _showHint('${character.displayName.toUpperCase()} SELECTED', _cyan);
    } else {
      _showHint('UNIT IS LOCKED', _red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final compact = width < 430 || height < 760;
        final deckHeight = compact
            ? (height * 0.25).clamp(172.0, 205.0).toDouble()
            : (height * 0.25).clamp(210.0, 268.0).toDouble();
        final sideScale = compact ? 0.86 : 1.0;

        return StreamBuilder<void>(
          stream: Stream<void>.periodic(const Duration(milliseconds: 120)),
          builder: (context, _) {
            if (!widget.game.simReady) return const SizedBox.shrink();
            final round = widget.game.round;
            return Stack(
              children: [
                _battlefieldLabels(round),
                Positioned(
                  left: width / 2 - (compact ? 38 : 47),
                  bottom: deckHeight - 2,
                  width: compact ? 76 : 94,
                  height: compact ? 88 : 108,
                  child: const IgnorePointer(
                    child: CustomPaint(painter: _BattleCannonPainter()),
                  ),
                ),
                Positioned(
                  left: width * 0.23,
                  right: width * 0.23,
                  bottom: deckHeight + (compact ? 63 : 76),
                  height: 4,
                  child: const IgnorePointer(
                    child: CustomPaint(painter: _DashedLinePainter()),
                  ),
                ),
                Positioned(top: 12, left: 12, child: _pauseButton(compact)),
                Positioned(top: 12, right: 12, child: _resourcesCard(compact)),
                Positioned(
                    top: compact ? 67 : 76,
                    left: 12,
                    child: _missionCard(compact)),
                Positioned(
                    top: compact ? 67 : 76,
                    right: 12,
                    child: _waveCard(compact)),
                Positioned(
                  left: 12,
                  top: math.max(compact ? 214 : 270, height * 0.39),
                  child: Transform.scale(
                    alignment: Alignment.topLeft,
                    scale: sideScale,
                    child: _energyMeter(round),
                  ),
                ),
                Positioned(
                  right: 10,
                  top: math.max(compact ? 190 : 235, height * 0.28),
                  child: Transform.scale(
                    alignment: Alignment.topRight,
                    scale: sideScale,
                    child: _abilityRail(round),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: deckHeight,
                  child: _commandDeck(round, compact),
                ),
                if (_hint != null)
                  Positioned(
                    left: 70,
                    right: 70,
                    bottom: deckHeight + 14,
                    child: IgnorePointer(
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: _navyDeep.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: _hintColor, width: 1.5),
                          ),
                          child: Text(
                            _hint!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: _hintColor,
                              fontSize: compact ? 11 : 13,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _pauseButton(bool compact) {
    final size = compact ? 44.0 : 52.0;
    return _panel(
      onTap: _openPauseModal,
      radius: 13,
      child: SizedBox(
        width: size,
        height: size,
        child: Icon(Icons.pause_rounded,
            color: Colors.white, size: compact ? 27 : 33),
      ),
    );
  }

  Widget _battlefieldLabels(BattleRound round) {
    Offset castleBadge(
      CastleArtworkSpec spec,
      double x,
      double z,
      double verticalFraction,
    ) {
      final projection = widget.game.projection;
      final origin = widget.game.origin;
      final anchorX = origin.dx + projection.screenX(x);
      final anchorY =
          origin.dy + projection.screenY(0.5, z + spec.forwardOffsetZ);
      final height = spec.worldWidth *
          projection.pixelsPerUnit *
          1.35 *
          spec.pixelHeight /
          spec.pixelWidth;
      final top = anchorY - height * spec.groundAnchorFraction;
      return Offset(anchorX, top + height * verticalFraction);
    }

    Offset gateCenter(double x) {
      final projection = widget.game.projection;
      final origin = widget.game.origin;
      final anchorY = origin.dy + projection.screenY(0.429, -2.4);
      final height = gateArtwork.worldHeight * projection.pixelsPerUnit;
      final top = anchorY - height * gateArtwork.groundAnchorFraction;
      return Offset(origin.dx + projection.screenX(x), top + height * 0.48);
    }

    final main = castleBadge(stage1Castles.main, 0, -20.5, 0.52);
    final side = stage1Castles.side!;
    final left = castleBadge(side, -5.25, -13.7, 0.37);
    final right = castleBadge(side, 5.25, -13.7, 0.37);
    final gateLeft = gateCenter(-3.2);
    final gateRight = gateCenter(3.2);

    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            _positionedTowerBadge(main, round.towers[2].currentHealth),
            _positionedTowerBadge(left, round.towers[0].currentHealth),
            _positionedTowerBadge(right, round.towers[1].currentHealth),
            _positionedGateLabel(gateLeft, '×2'),
            _positionedGateLabel(gateRight, '+5'),
          ],
        ),
      ),
    );
  }

  Widget _positionedTowerBadge(Offset center, int health) {
    const width = 66.0;
    const height = 29.0;
    return Positioned(
      left: center.dx - width / 2,
      top: center.dy - height / 2,
      width: width,
      height: height,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xEC111A2D),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _red, width: 2),
          boxShadow: const [
            BoxShadow(
                color: Color(0xAA000000), blurRadius: 5, offset: Offset(0, 3))
          ],
        ),
        child: Text(
          '$health',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 3, offset: Offset(0, 2))
            ],
          ),
        ),
      ),
    );
  }

  Widget _positionedGateLabel(Offset center, String label) {
    return Positioned(
      left: center.dx - 48,
      top: center.dy - 24,
      width: 96,
      height: 48,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 31,
            fontWeight: FontWeight.w900,
            shadows: [
              Shadow(color: Color(0xFF087FEA), blurRadius: 10),
              Shadow(
                  color: Color(0xFF043F96),
                  blurRadius: 2,
                  offset: Offset(0, 3)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _missionCard(bool compact) {
    return _panel(
      radius: 13,
      child: SizedBox(
        width: compact ? 132 : 160,
        height: compact ? 68 : 82,
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: compact ? 9 : 12, vertical: 8),
          child: Row(
            children: [
              Icon(Icons.castle_rounded, color: _gold, size: compact ? 25 : 32),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MISSION',
                      style: TextStyle(
                        color: const Color(0xFFB6C7F3),
                        fontSize: compact ? 9 : 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Defeat the\nEnemy Castle',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 10 : 12,
                        height: 1.12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resourcesCard(bool compact) {
    final profile = widget.profile;
    return _panel(
      radius: 13,
      child: SizedBox(
        height: compact ? 44 : 52,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: compact ? 9 : 13),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _resource('assets/home/icons/icon_coin.png',
                  '${profile?.currency ?? 0}', compact),
              Container(
                width: 1,
                height: compact ? 25 : 31,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: const Color(0x334DA6FF),
              ),
              _resource('assets/home/icons/icon_gem.png',
                  '${profile?.gems ?? 0}', compact),
            ],
          ),
        ),
      ),
    );
  }

  Widget _resource(String asset, String value, bool compact) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(asset, width: compact ? 17 : 22, height: compact ? 17 : 22),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 14 : 18,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _waveCard(bool compact) {
    final index = widget.game.waveIndex;
    return _panel(
      radius: 13,
      child: SizedBox(
        width: compact ? 132 : 160,
        height: compact ? 68 : 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'WAVE $index/${Stage1Game.waveCount}',
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 16 : 21,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.4,
              ),
            ),
            SizedBox(height: compact ? 6 : 9),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                Stage1Game.waveCount,
                (i) => Container(
                  width: compact ? 11 : 14,
                  height: compact ? 11 : 14,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < index ? _gold : const Color(0xFF415276),
                    border:
                        Border.all(color: const Color(0xFF0A1327), width: 1.2),
                    boxShadow: i < index
                        ? const [
                            BoxShadow(color: Color(0x99FFB400), blurRadius: 7)
                          ]
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _energyMeter(BattleRound round) {
    final ratio =
        (round.abilities.energy / round.abilities.maxEnergy).clamp(0.0, 1.0);
    return Container(
      width: 52,
      height: 222,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF244B84), width: 3),
        boxShadow: const [
          BoxShadow(
              color: Color(0x88000000), blurRadius: 10, offset: Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Container(
                color: const Color(0xFF08152D),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: FractionallySizedBox(
                    widthFactor: 1,
                    heightFactor: ratio,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFF65D5FF),
                            Color(0xFF168DFF),
                            Color(0xFF0757C4)
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          const Icon(Icons.bolt_rounded, color: Colors.white, size: 21),
          Text(
            round.abilities.energy.toStringAsFixed(0),
            style: const TextStyle(
                color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _abilityRail(BattleRound round) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _abilityCard(
            round, Ability.freeze, 'FREEZE', Icons.ac_unit_rounded, _cyan),
        const SizedBox(height: 9),
        _abilityCard(round, Ability.fireball, 'FIREBALL',
            Icons.local_fire_department_rounded, const Color(0xFFFF5A35)),
        const SizedBox(height: 9),
        _abilityCard(round, Ability.lightning, 'LIGHTNING', Icons.bolt_rounded,
            const Color(0xFF45B7FF)),
      ],
    );
  }

  Widget _abilityCard(
    BattleRound round,
    Ability ability,
    String label,
    IconData icon,
    Color color,
  ) {
    final charges = round.abilities.chargesFor(ability);
    return Opacity(
      opacity: charges > 0 ? 1 : 0.45,
      child: GestureDetector(
        onTap: charges > 0 ? () => _tryAbility(ability) : null,
        child: Container(
          width: 78,
          height: 82,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF203D70), Color(0xFF101D38), Color(0xFF071127)],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color, width: 2),
            boxShadow: [
              const BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 9,
                  offset: Offset(0, 4)),
              BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 11),
            ],
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        color: color,
                        size: 31,
                        shadows: [Shadow(color: color, blurRadius: 10)]),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ),
              Positioned(
                right: 5,
                bottom: 4,
                child: Text(
                  'x$charges',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _commandDeck(BattleRound round, bool compact) {
    final cards = widget.game.squadCharacters;
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C3158), Color(0xFF0C1933), Color(0xFF050D20)],
        ),
        border: Border(
          top: BorderSide(color: Color(0xFF263F6C), width: 4),
          left: BorderSide(color: Color(0xFF1B3158), width: 3),
          right: BorderSide(color: Color(0xFF1B3158), width: 3),
        ),
        boxShadow: [
          BoxShadow(
              color: Color(0xB0000000), blurRadius: 18, offset: Offset(0, -5))
        ],
      ),
      child: Column(
        children: [
          Container(
            height: compact ? 42 : 50,
            margin: const EdgeInsets.fromLTRB(8, 7, 8, 0),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xD90C1830),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF29466F), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(Icons.person_rounded, color: _blue, size: 24),
                const SizedBox(width: 6),
                Text(
                  '${round.livePlayerMobCount}',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 20 : 25,
                      fontWeight: FontWeight.w900),
                ),
                const Spacer(),
                Text(
                  'VS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: compact ? 20 : 27,
                    fontWeight: FontWeight.w900,
                    fontStyle: FontStyle.italic,
                    shadows: const [
                      Shadow(
                          color: Colors.black,
                          blurRadius: 5,
                          offset: Offset(0, 2))
                    ],
                  ),
                ),
                const Spacer(),
                Text(
                  '${round.liveEnemyMobCount}',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 20 : 25,
                      fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.person_rounded, color: _red, size: 24),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding:
                  EdgeInsets.fromLTRB(8, compact ? 6 : 9, 8, compact ? 8 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    Expanded(child: _unitCard(cards[i], i, compact)),
                    const SizedBox(width: 6),
                  ],
                  SizedBox(
                      width: compact ? 92 : 118, child: _battleButton(compact)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _unitCard(CharacterDefinition character, int index, bool compact) {
    final selected =
        widget.game.round.abilities.selectedCharacterId == character.id;
    final enabled = widget.game.isCharacterSelectable(character.id);
    final level = (widget.profile?.getCharacterLevel(character.id) ?? 0) + 1;
    return GestureDetector(
      onTap: () => _selectUnit(character),
      child: Opacity(
        opacity: enabled ? 1 : 0.58,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: selected
                  ? const [
                      Color(0xFF6FB8FF),
                      Color(0xFF296FD2),
                      Color(0xFF0B2C68)
                    ]
                  : const [
                      Color(0xFF486DA6),
                      Color(0xFF213B69),
                      Color(0xFF0B1934)
                    ],
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? Colors.white : const Color(0xFF83A2D4),
              width: selected ? 3 : 1.5,
            ),
            boxShadow: selected
                ? const [BoxShadow(color: Color(0xAA168DFF), blurRadius: 11)]
                : const [
                    BoxShadow(
                        color: Color(0x88000000),
                        blurRadius: 5,
                        offset: Offset(0, 3))
                  ],
          ),
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(top: compact ? 4 : 7),
                      child: CustomPaint(
                        painter: _UnitAvatarPainter(index: index),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
                    color: const Color(0x66030A19),
                    child: Text(
                      'LVL $level',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 9 : 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.water_drop_rounded,
                            color: _cyan, size: compact ? 11 : 15),
                        const SizedBox(width: 2),
                        Text(
                          '${character.launchEnergyCost}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 9 : 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!enabled)
                const Positioned(
                  top: 5,
                  right: 5,
                  child: Icon(Icons.lock_rounded,
                      color: Color(0xFFFFD263), size: 15),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _battleButton(bool compact) {
    final started = widget.game.battleStarted;
    return GestureDetector(
      onTap: _tryBattleAction,
      child: Container(
        decoration: BoxDecoration(
          gradient: MobRushTheme.goldFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFFFE47C), width: 2.5),
          boxShadow: const [
            BoxShadow(
                color: Color(0xAA000000), blurRadius: 9, offset: Offset(0, 5)),
            BoxShadow(color: Color(0x88FFAA00), blurRadius: 12),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
                started
                    ? Icons.groups_rounded
                    : Icons.sports_martial_arts_rounded,
                color: Colors.white,
                size: compact ? 29 : 40),
            SizedBox(height: compact ? 3 : 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                started ? 'RUSH x${widget.game.rushUnitCount}' : 'BATTLE',
                style: TextStyle(
                  color: const Color(0xFF5A2B00),
                  fontSize: compact ? 15 : 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _panel(
      {required Widget child, VoidCallback? onTap, double radius = 12}) {
    final panel = Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF203B68), _navy, _navyDeep],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _gold, width: 2),
        boxShadow: const [
          BoxShadow(
              color: Color(0x99000000), blurRadius: 9, offset: Offset(0, 4))
        ],
      ),
      child: child,
    );
    return onTap == null ? panel : GestureDetector(onTap: onTap, child: panel);
  }

  void _openPauseModal() {
    widget.game.pauseEngine();
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black87,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _navyDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: _gold, width: 2),
        ),
        title: const Text(
          'BATTLE PAUSED',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _pauseAction('RESUME', _blue, () {
              Navigator.of(dialogContext).pop();
              widget.game.resumeEngine();
            }),
            const SizedBox(height: 10),
            _pauseAction('RESTART', const Color(0xFF243F70), () {
              Navigator.of(dialogContext).pop();
              widget.onRestart();
            }),
            const SizedBox(height: 10),
            _pauseAction('MAP', const Color(0xFF243F70), () {
              Navigator.of(dialogContext).pop();
              widget.onOpenMap();
            }),
            const SizedBox(height: 10),
            _pauseAction('HOME', const Color(0xFF243F70), () {
              Navigator.of(dialogContext).pop();
              widget.onGoHome();
            }),
          ],
        ),
      ),
    ).then((_) {
      if (mounted && widget.game.paused) widget.game.resumeEngine();
    });
  }

  Widget _pauseAction(String label, Color color, VoidCallback onTap) {
    return SizedBox(
      width: 220,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(11)),
        ),
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _UnitAvatarPainter extends CustomPainter {
  const _UnitAvatarPainter({required this.index});

  final int index;

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width, size.height) / 70;
    final center = Offset(size.width / 2, size.height * 0.55);
    final shadow = Paint()..color = const Color(0x55000000);
    final dark = Paint()..color = const Color(0xFF063A91);
    final blue = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF57C3FF), Color(0xFF168DFF), Color(0xFF0750BD)],
      ).createShader(
          Rect.fromCenter(center: center, width: 55 * s, height: 70 * s));
    final steel = Paint()..color = const Color(0xFFE7F1FF);

    canvas.drawOval(
      Rect.fromCenter(
          center: center.translate(0, 22 * s), width: 50 * s, height: 13 * s),
      shadow,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center.translate(0, 6 * s), width: 34 * s, height: 39 * s),
        Radius.circular(9 * s),
      ),
      blue,
    );
    canvas.drawCircle(center.translate(0, -19 * s), 15 * s, blue);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center.translate(-10 * s, 27 * s),
            width: 11 * s,
            height: 25 * s),
        Radius.circular(5 * s),
      ),
      dark,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: center.translate(10 * s, 27 * s),
            width: 11 * s,
            height: 25 * s),
        Radius.circular(5 * s),
      ),
      dark,
    );

    final weapon = Paint()
      ..color = const Color(0xFFF2F7FF)
      ..strokeWidth = 4 * s
      ..strokeCap = StrokeCap.round;
    if (index == 0) {
      canvas.drawLine(center.translate(16 * s, 10 * s),
          center.translate(32 * s, -24 * s), weapon);
      canvas.drawLine(center.translate(13 * s, 5 * s),
          center.translate(25 * s, 10 * s), steel);
    } else if (index == 1) {
      canvas.drawArc(
        Rect.fromCenter(
            center: center.translate(17 * s, 0), width: 25 * s, height: 45 * s),
        -1.2,
        2.4,
        false,
        weapon..style = PaintingStyle.stroke,
      );
      canvas.drawLine(center.translate(10 * s, -18 * s),
          center.translate(29 * s, 19 * s), steel);
    } else if (index == 2) {
      final shield = Path()
        ..moveTo(center.dx + 12 * s, center.dy - 12 * s)
        ..lineTo(center.dx + 31 * s, center.dy - 5 * s)
        ..lineTo(center.dx + 27 * s, center.dy + 19 * s)
        ..lineTo(center.dx + 20 * s, center.dy + 27 * s)
        ..lineTo(center.dx + 13 * s, center.dy + 19 * s)
        ..close();
      canvas.drawPath(shield, Paint()..color = const Color(0xFF5ACBFF));
      canvas.drawPath(
        shield,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * s,
      );
    } else {
      canvas.drawLine(center.translate(14 * s, 10 * s),
          center.translate(32 * s, -12 * s), weapon);
      canvas.drawLine(center.translate(22 * s, -2 * s),
          center.translate(35 * s, 8 * s), weapon);
      canvas.drawLine(center.translate(22 * s, -2 * s),
          center.translate(13 * s, -15 * s), weapon);
    }
  }

  @override
  bool shouldRepaint(covariant _UnitAvatarPainter oldDelegate) =>
      oldDelegate.index != index;
}

class _DashedLinePainter extends CustomPainter {
  const _DashedLinePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xE6FFFFFF)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    const dash = 16.0;
    const gap = 10.0;
    for (double x = 0; x < size.width; x += dash + gap) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(math.min(x + dash, size.width), size.height / 2),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _BattleCannonPainter extends CustomPainter {
  const _BattleCannonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final s = math.min(size.width / 94, size.height / 108);
    final center = Offset(size.width / 2, size.height * 0.72);
    final shadow = Paint()..color = const Color(0x66000000);
    final dark = Paint()..color = const Color(0xFF101C35);
    final metal = Paint()..color = const Color(0xFF46597A);
    final blue = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF62CBFF), Color(0xFF168DFF), Color(0xFF0750BA)],
      ).createShader(
          Rect.fromCenter(center: center, width: 60 * s, height: 92 * s));

    canvas.drawOval(
      Rect.fromCenter(
          center: center.translate(0, 14 * s), width: 84 * s, height: 22 * s),
      shadow,
    );
    for (final dx in [-30.0, 30.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: center.translate(dx * s, 8 * s),
            width: 18 * s,
            height: 39 * s,
          ),
          Radius.circular(7 * s),
        ),
        dark,
      );
    }
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: 58 * s, height: 45 * s),
        Radius.circular(13 * s),
      ),
      metal,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(center.dx - 15 * s, center.dy - 71 * s, 30 * s, 72 * s),
        Radius.circular(10 * s),
      ),
      blue,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(0, -70 * s),
        width: 31 * s,
        height: 14 * s,
      ),
      dark,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center, width: 47 * s, height: 34 * s),
      blue,
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: center.translate(0, -3 * s), width: 20 * s, height: 13 * s),
      Paint()..color = const Color(0xFF9DE4FF),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
