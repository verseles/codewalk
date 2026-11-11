> 📣 A session without a model of its own now shows the model the server will actually use, and the model picker names providers instead of showing their ids.

### Model picker

- A session that has no model of its own shows the model the server runs it on: its agent's own model, or else the server's default. Before, it showed "Default".
- Providers appear by name in the model picker, in its search, and in the new-chat picker.
- The model and agent lists refresh on their own when the server reports a change to its models, agents or providers.
