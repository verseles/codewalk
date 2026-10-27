import 'package:codewalk_core/codewalk_core.dart';
import 'package:test/test.dart';

import 'support/scripted_harness_scenarios.dart';

void main() {
  final message = MessageRef('msg_a');
  final created = DateTime.utc(2026, 10, 27, 12);
  final completed = DateTime.utc(2026, 10, 27, 12, 0, 3);

  test('merging keeps known values unless the update knows newer ones', () {
    final started = MessageContext(
      message: message,
      created: created,
      modelId: 'model',
      agentId: 'build',
    );
    final merged = started.merge(
      MessageContext(message: message, completed: completed, finish: 'stop'),
    );
    expect(
      [merged.created, merged.completed, merged.modelId, merged.agentId],
      [created, completed, 'model', 'build'],
    );
    expect(merged.finish, 'stop');
    expect(merged.cost, isNull);
    expect(message, MessageRef('msg_a'));
    expect(() => MessageRef(''), throwsArgumentError);
  });

  test('an item copied with new metadata keeps every other field', () {
    final context = MessageContext(message: message, completed: completed);
    final text = scriptedText('body', complete: true);
    final copy = text.withMeta(text.meta.withMessage(context)) as AssistantText;
    expect([copy.text, copy.complete, copy.id], [text.text, true, text.id]);
    expect(copy.meta.message, same(context));
    expect(copy.meta.turnId, text.meta.turnId);
    final tool = ToolCall(
      meta: scriptedItemMeta('tool'),
      kind: const OpenValue.known(ToolKind.read),
      rawName: 'read',
    );
    final toolCopy = tool.withMeta(tool.meta.withMessage(context)) as ToolCall;
    expect([toolCopy.rawName, toolCopy.kind.known], ['read', ToolKind.read]);
    expect(toolCopy.meta.message?.completed, completed);
  });

  test('the running step is set, kept against stale events and cleared', () {
    var state = SessionState(ownedRef);
    final step = StepInfo(message: message, startedAt: created, agentId: 'a');
    state = reduce(state, StepChanged(meta: scriptedMeta(2), step: step)).state;
    expect(state.currentStep, same(step));
    state = reduce(state, StepChanged(meta: scriptedMeta(1))).state;
    expect(state.currentStep, same(step));
    state = reduce(state, StepChanged(meta: scriptedMeta(3))).state;
    expect(state.currentStep, isNull);
  });
}
