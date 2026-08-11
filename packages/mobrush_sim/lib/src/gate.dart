/// One pass-through gate result: how many copies/units the gate produced and
/// what label it would show. Port of the return contract implicit in
/// `Gate.Apply` — the C# builds a floating "+N"/"xN" popup only after a real
/// crowd change, which this mirrors by reporting 0 when nothing was created.
class GateResult {
  const GateResult({
    required this.spawned,
    required this.requested,
    required this.mobDied,
    required this.label,
  });

  final int spawned;
  final int requested;

  /// True for a negative (÷N) gate's culling branch.
  final bool mobDied;

  final String label;

  bool get changedCrowd => spawned > 0 || mobDied;

  /// True when the mob cap silently capped this gate below its authored
  /// promise. Mirrors `ReportCapacityIfPartial`.
  bool get hitCapacity => spawned < requested;
}

/// Reusable crowd portal. Port of the simulation core of
/// `Assets/Scripts/Gameplay/Gate.cs` — multiplier/negative/additive
/// semantics and the once-per-round additive spend. The trigger footprint,
/// spawn placement, and every visual (flash, label, popup, sound combo) are
/// left out; a battle orchestrator calls [apply] once it has already decided
/// a mob crossed this gate.
class Gate {
  Gate({
    int multiplier = 2,
    this.isNegative = false,
    this.isAdditive = false,
    int addAmount = 5,
  })  : multiplier = multiplier < 1 ? 1 : multiplier,
        addAmount = addAmount < 1 ? 1 : addAmount {
    if (isAdditive) isNegative = false;
  }

  final int multiplier;
  bool isNegative;
  final bool isAdditive;
  final int addAmount;

  int _negCounter = 0;
  bool _additiveSpent = false;

  String get displayText => isAdditive
      ? '+${addAmount < 1 ? 1 : addAmount}'
      : (isNegative ? '÷$multiplier' : '×$multiplier');

  /// Applies the gate once to a crossing mob.
  ///
  /// [canGenerate] mirrors `CanGenerateCharacter` — a definition whose
  /// `canBeGeneratedByGate` is false (a capped roster character like Max)
  /// refuses the gate entirely, matching the C# early return exactly.
  /// [capacityRemaining] mirrors the global mob cap: [apply] never asks for
  /// more copies than the cap has room for.
  GateResult apply({required bool canGenerate, required int capacityRemaining}) {
    if (isAdditive) {
      // +N grants a fixed squad ONCE per round — firing per crossing mob
      // turned a "+5" into a hundred-plus unit cascade capped only by the
      // global mob limit, and made the gate impossible to balance a stage
      // against. See the C# comment on the same guard.
      if (_additiveSpent || !canGenerate) {
        return GateResult(spawned: 0, requested: 0, mobDied: false, label: '');
      }
      _additiveSpent = true;
      final requested = addAmount < 1 ? 1 : addAmount;
      final spawned = _clamp(requested, capacityRemaining);
      return GateResult(
        spawned: spawned,
        requested: requested,
        mobDied: false,
        label: spawned > 0 ? '+$spawned' : '',
      );
    }

    if (isNegative) {
      _negCounter++;
      final dies = _negCounter % multiplier != 0;
      return GateResult(
        spawned: 0,
        requested: 0,
        mobDied: dies,
        label: dies ? '÷$multiplier' : '',
      );
    }

    if (!canGenerate) {
      return GateResult(spawned: 0, requested: 0, mobDied: false, label: '');
    }
    final requestedCopies = (multiplier - 1) < 0 ? 0 : multiplier - 1;
    final createdCopies = _clamp(requestedCopies, capacityRemaining);
    // A x3 gate that can only create one clone honestly displays x2. If no
    // clone can be created, it displays nothing at all.
    return GateResult(
      spawned: createdCopies,
      requested: requestedCopies,
      mobDied: false,
      label: createdCopies > 0 ? '×${createdCopies + 1}' : '',
    );
  }

  static int _clamp(int requested, int capacityRemaining) {
    final cap = capacityRemaining < 0 ? 0 : capacityRemaining;
    return requested < cap ? requested : cap;
  }

  void resetForRound() {
    _negCounter = 0;
    _additiveSpent = false;
  }
}
