> 📣 A calmer conversation: the agent's text sits on the page, text is larger, work folds into one quiet line, and a long press on a message offers copy, select and revert. The permission switch now lives on the server.

### Conversation

- The agent's messages have no card and reach closer to the screen's edge on phones.
- Your messages keep their bubble, without the "You" label or the outline.
- Conversation text is one step larger; your text size setting still applies on top.
- Folded work is a single quiet line instead of a card.
- Progress bars inside messages use the full width.
- System reminders, such as the Plan mode notes, show as light notices in the timeline instead of pending messages.

### Gestures

- Double tap a message to copy all of it.
- Long press a message for Revert to here, Copy all and Select text.
- Tap `inline code` to copy it.

### Permissions

- The ✓✓ button at the top is gone. The switch in the model and agent picker is the only control.
- The switch is the session's allow-all rule on the server, so every client and device sees the same state. On, the agent asks nothing, even in Plan mode; Off removes the rule, whoever added it.
- Sessions you start in CodeWalk begin On. Sessions started elsewhere show what the server says, and CodeWalk answers nothing for them while the switch is Off.
- A sub-agent follows its own rule: one started after you turned the switch On asks nothing, while one started before may still ask, and its cards wait for you.
