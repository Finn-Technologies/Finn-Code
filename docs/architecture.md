# Architecture

## Runtime model

Finn Code uses two execution paths behind one UI contract.

### Direct provider path

The Flutter client speaks a provider protocol directly:

- OpenAI-compatible Chat Completions
- Anthropic Messages
- Gemini `streamGenerateContent`

This path is optimized for fast setup, model comparison, and free-tier testing. It is chat-only: the app never executes a shell command or claims a file changed.

### Codex app-server path

A trusted host runs `codex app-server`. Finn Code connects over WebSocket and uses its bidirectional JSON-RPC protocol:

1. `initialize`
2. `initialized`
3. `model/list` or `thread/list`
4. `thread/start` or `thread/resume`
5. `turn/start`
6. Stream `item/*`, `turn/*`, and error notifications
7. Respond to server-initiated approval requests
8. `turn/interrupt` when the user stops a run

This path provides Codex plans, reasoning summaries, command execution, file changes, diffs, MCP/tool events, persistent remote threads, and approval semantics.

## Layering

### Domain

`lib/domain` contains immutable provider, session, message, event, model, and gateway types. It does not import Flutter or HTTP/WebSocket packages.

### Data

`lib/data` implements each `AgentGateway`:

- `OpenAiCompatibleGateway`
- `AnthropicGateway`
- `GeminiGateway`
- `CodexAppServerGateway`
- `DemoAgentGateway`

`AgentRepository` selects an implementation from `ProviderConfig.protocol`.

### View model

`AppViewModel` owns one immutable `AppState` snapshot. Views listen with `provider` and send user intent back as commands. The view model updates messages and event timelines from `AgentStreamUpdate` values. Active runs, approvals, cancellation, and gateway ownership are tracked per session so a user can switch tasks without redirecting a background stream.

### UI

The UI is grouped by feature (`home`, `session`, `models`, `settings`) with reusable widgets under `ui/widgets`. Widgets do not perform network calls.

## Security boundaries

- API keys and gateway tokens are stored with Android Keystore-backed secure storage.
- Provider metadata is persisted without secrets.
- Android cleartext traffic is denied globally and enabled only for `10.0.2.2`, `localhost`, and `127.0.0.1` development endpoints.
- Codex approvals are surfaced as modal task actions. No approval is auto-accepted.
- New Codex tasks default to read-only when no project path is supplied.
- A task with a project path uses workspace-write and still requests approval when the runtime policy requires it.

## Protocol versioning

The upstream app-server evolves quickly. The client identifies itself as `finn_code_mobile` and opts into experimental capabilities because approval and remote-thread fields are still evolving. The current protocol uses hyphenated sandbox modes on `thread/start` (`read-only` / `workspace-write`) and camel-case policy types on `turn/start` (`readOnly` / `workspaceWrite`); the adapter keeps that distinction explicit. Protocol-specific code is isolated in `codex_app_server_gateway.dart`; all other features consume normalized `AgentStreamUpdate` values.

## Persistence

Provider metadata, selected provider, theme, provider overrides, task history, and the selected task use `SharedPreferencesAsync`. Task history is serialized by the versioned `SessionCodec`; malformed records are ignored and interrupted streaming turns are normalized on restore. Secrets use `SecretStore`, currently implemented by `flutter_secure_storage`. The abstraction is intentional: HarmonyOS can supply a native KeyStore/preferences implementation without changing the view model.

The current task store is local and single-device. A production follow-up should move it to a repository-backed database with retention, encrypted-at-rest policy, and migration tests before enabling multi-device sync.

## Upgrade path

1. Pin the Codex submodule to a reviewed commit.
2. Run upstream app-server protocol tests.
3. Exercise initialize, model list, thread start/resume, a read-only turn, an approval, cancellation, and reconnect.
4. Update normalized event mapping if the wire schema changed.
5. Run Flutter unit, integration, and emulator checks.
