import 'package:flame/components/component.dart';
import 'package:meta/meta.dart';

import './effects.dart';
import '../position.dart';

class SequenceEffect extends PositionComponentEffect {
  final List<PositionComponentEffect> effects;
  int _currentIndex = 0;
  PositionComponentEffect currentEffect;
  bool _currentWasAlternating;
  double _driftModifier = 0.0;

  SequenceEffect({
    @required this.effects,
    isInfinite = false,
    isAlternating = false,
  }) : super(isInfinite, isAlternating) {
    /// All effects need to be finite, otherwise the sequence will get stuck
    assert(effects.every((effect) => !effect.isInfinite));
    /// No effects can be added to components from the start
    assert(effects.every((effect) => effect.component == null));
  }

  void _prepare(PositionComponent _comp) {
    super.component = _comp;
    _currentIndex = 0;
    final originalSize = _comp.toSize();
    final originalPosition = _comp.toPosition();
    Position currentSize = _comp.toSize();
    Position currentPosition = _comp.toPosition();
    effects.forEach((effect) {
      effect.reset();
      _comp.setBySize(currentSize);
      _comp.setByPosition(currentPosition);
      effect.component = _comp;
      if (effect is MoveEffect) {
        currentPosition = effect.destination;
      } else if (effect is ScaleEffect) {
        currentSize = Position.fromSize(effect.size);
      }
    });
    travelTime = effects.fold(
      0,
      (time, effect) => time + effect.totalTravelTime,
    );
    component.setBySize(originalSize);
    component.setByPosition(originalPosition);
    currentEffect = effects.first;
    _currentWasAlternating = currentEffect.isAlternating;
  }

  @override
  set component(PositionComponent _comp) {
    _prepare(_comp);
  }

  @override
  void update(double dt) {
    if (hasFinished()) {
      return;
    }
    super.update(dt);

    currentEffect.update(dt + _driftModifier);
    _driftModifier = 0.0;
    if (currentEffect.hasFinished()) {
      _driftModifier = currentEffect.driftTime;
      currentEffect.isAlternating = _currentWasAlternating;
      _currentIndex++;
      final iterationSize = isAlternating ? effects.length * 2 : effects.length;
      if (_currentIndex != 0 && _currentIndex % iterationSize == 0) {
        isInfinite ? reset() : dispose();
        return;
      }
      final orderedEffects =
          curveDirection.isNegative ? effects.reversed.toList() : effects;
      currentEffect = orderedEffects[_currentIndex % effects.length];
      _currentWasAlternating = currentEffect.isAlternating;
      if (isAlternating &&
          !currentEffect.isAlternating &&
          curveDirection.isNegative) {
        // Make the effect go in reverse
        currentEffect.isAlternating = true;
        currentEffect.percentage = 1.0;
      }
    }
  }

  @override
  void reset() {
    super.reset();
    _prepare(component);
  }
}
