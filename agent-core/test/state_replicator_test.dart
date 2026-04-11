import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('StateReplicator', () {
    test('detach clears attachment state', () async {
      final replicator = _createReplicator();

      expect(replicator.isAttached, isFalse);

      await replicator.detach();

      expect(replicator.isAttached, isFalse);
      await replicator.dispose();
    });

    test('closed envelopes preserve the previous value for listeners', () {
      final replicator = _createReplicator(
        initialState: const _FakeState('before-close'),
        initialRevision: 1,
      );
      _FakeState? nextState;
      _FakeState? previousState;

      replicator.onChanged((next, previous) {
        nextState = next;
        previousState = previous;
      });

      final applied = replicator.applyEnvelope(
        _envelope(
          revision: 2,
          action: StateReplicatedAction.closed,
          payload: const {},
        ),
      );

      expect(applied, isTrue);
      expect(nextState, isNull);
      expect(previousState?.value, 'before-close');
      expect(replicator.current, isNull);
      expect(replicator.hasCurrent, isFalse);
      expect(replicator.revision, 2);
    });

    test('same-revision envelopes are ignored', () {
      final replicator = _createReplicator(
        initialState: const _FakeState('current'),
        initialRevision: 3,
      );
      var notifications = 0;

      replicator.onChanged((next, previous) {
        notifications++;
      });

      final applied = replicator.applyEnvelope(
        _envelope(
          revision: 3,
          payload: const _FakeState('duplicate').toJson(),
        ),
      );

      expect(applied, isFalse);
      expect(replicator.current?.value, 'current');
      expect(notifications, 0);
    });

    test('optimistic updates increment revision and ignore echoed envelopes',
        () async {
      final replicator = _createReplicator(
        initialState: const _FakeState('before'),
        initialRevision: 4,
      );
      final observedStates = <String?>[];

      replicator.onChanged((next, previous) {
        observedStates.add(next?.value);
      });

      await replicator.optimisticUpdate(const _FakeState('after'));

      expect(replicator.current?.value, 'after');
      expect(replicator.revision, 5);
      final echoedEnvelope = replicator.currentEnvelope;
      expect(echoedEnvelope, isNotNull);
      expect(echoedEnvelope!.revision, 5);

      final echoed = replicator.tryApplyMessage(echoedEnvelope.toJson());

      expect(echoed, isFalse);
      expect(observedStates, ['after']);

      await replicator.syncCurrent();
    });
  });
}

StateReplicator<_FakeState> _createReplicator({
  _FakeState? initialState,
  int initialRevision = 0,
}) {
  return StateReplicator<_FakeState>(
    sessionId: 'session-1',
    objectKind: 'pending_tool_calls',
    objectKey: 'active',
    decode: _FakeState.fromJson,
    initialState: initialState,
    initialRevision: initialRevision,
  );
}

StateReplicatedEnvelope _envelope({
  required int revision,
  StateReplicatedAction action = StateReplicatedAction.snapshot,
  Map<String, dynamic> payload = const {'value': 'default'},
}) {
  return StateReplicatedEnvelope(
    sessionId: 'session-1',
    objectKind: 'pending_tool_calls',
    objectKey: 'active',
    revision: revision,
    action: action,
    payload: payload,
  );
}

class _FakeState implements ReplicatedState {
  final String value;

  const _FakeState(this.value);

  factory _FakeState.fromJson(Map<String, dynamic> json) {
    return _FakeState(json['value'] as String);
  }

  @override
  Map<String, dynamic> toJson() {
    return {'value': value};
  }
}
