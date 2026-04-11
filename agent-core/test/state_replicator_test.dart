import 'dart:async';

import 'package:agent_core/agent_core.dart';
import 'package:test/test.dart';

void main() {
  group('StateReplicator', () {
    test('stream errors clear the subscription and allow reattach', () async {
      final replicator = _createReplicator();
      final firstStream = StreamController<StateReplicatedEnvelope>();

      await replicator.attach(firstStream.stream);
      expect(replicator.isAttached, isTrue);

      firstStream.addError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);

      expect(replicator.isAttached, isFalse);

      final secondStream = StreamController<StateReplicatedEnvelope>();
      await replicator.attach(secondStream.stream);
      secondStream.add(
        _envelope(
          revision: 0,
          payload: const _FakeState('reattached').toJson(),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(replicator.isAttached, isTrue);
      expect(replicator.current?.value, 'reattached');

      await firstStream.close();
      await secondStream.close();
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
      final sentEnvelopes = <StateReplicatedEnvelope>[];
      final replicator = _createReplicator(
        initialState: const _FakeState('before'),
        initialRevision: 4,
        sendEnvelope: sentEnvelopes.add,
      );
      final observedStates = <String?>[];

      replicator.onChanged((next, previous) {
        observedStates.add(next?.value);
      });

      await replicator.optimisticUpdate(const _FakeState('after'));

      expect(replicator.current?.value, 'after');
      expect(replicator.revision, 5);
      expect(sentEnvelopes, hasLength(1));
      expect(sentEnvelopes.single.revision, 5);

      final echoed = replicator.tryApplyMessage(sentEnvelopes.single.toJson());

      expect(echoed, isFalse);
      expect(observedStates, ['after']);

      await replicator.syncCurrent();

      expect(sentEnvelopes, hasLength(2));
      expect(sentEnvelopes.last.revision, 5);
      expect(sentEnvelopes.last.action, StateReplicatedAction.snapshot);
    });
  });
}

StateReplicator<_FakeState> _createReplicator({
  _FakeState? initialState,
  int initialRevision = 0,
  StateReplicatedEnvelopeSender? sendEnvelope,
}) {
  return StateReplicator<_FakeState>(
    sessionId: 'session-1',
    objectKind: 'pending_tool_calls',
    objectKey: 'active',
    decode: _FakeState.fromJson,
    sendEnvelope: sendEnvelope ?? (_) {},
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
