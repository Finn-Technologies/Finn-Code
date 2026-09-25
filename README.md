# Finn Code

Finn Code is an Android-first, provider-agnostic AI coding harness built with Flutter. It gives mobile users a polished task interface for direct model APIs and for the full [Codex app-server](https://developers.openai.com/codex/app-server) protocol.

The repository is intentionally split into two parts:

- **Flutter mobile control plane** — native Android UI, streaming conversations, provider configuration, model discovery, approvals, themes, and responsive tablet layouts.
- **Codex fork integration** — the `codex/` Git submodule points to a real fork of [`openai/codex`](https://github.com/Abhi-Flex1/codex), allowing the Rust agent runtime to evolve independently while this repository owns the mobile experience.

> GitHub does not allow an existing non-fork repository to be converted into a network fork in place. Finn-Code therefore keeps its own repository identity and consumes the Codex fork as a submodule. Changes to the Rust runtime are made and pushed inside `codex/`, then the submodule pointer is updated here.

## What works now

- Native Flutter UI for Android with light, dark, and system themes
- Task inbox, responsive two-pane workspace, streaming messages, Markdown, reasoning, tool activity, diffs, usage, and cancellation
- Provider adapters for:
  - Finn offline demo runtime
  - Any OpenAI-compatible `/chat/completions` endpoint
  - Anthropic Messages API
  - Google Gemini `generateContent` API
  - Codex app-server JSON-RPC over WebSocket
- Provider presets for local llama.cpp/Ollama, Space Bunny Free, OpenRouter Free, Groq, Google AI Studio, Anthropic, and Codex Gateway
- Encrypted Android storage for API keys and gateway tokens
- Command/file-change approval UI backed by Codex server requests
- Versioned task-history persistence with selected-task restoration and corrupt-data fallback
- Independent run-scoped gateways so background tasks cannot cross-wire streams
- Android cleartext allowlist limited to emulator/local development hosts
- Generated OpenHarmony project shell for later adaptation
- Unit, widget, integration, analyzer, APK, and emulator verification targets

## Architecture

```text
lib/
├── core/       Theme and design tokens
├── data/       API adapters, Codex JSON-RPC client, storage, repository
├── domain/     Immutable models and gateway contracts
├── ui/         Feature views and reusable widgets
└── viewmodels/ AppState + AppViewModel orchestration
```

The mobile client does not pretend that a chat-completions endpoint can edit files. Direct model modes are explicitly chat-only. File access, commands, plans, diffs, and approval-gated tools come from a Codex app-server running on a trusted development host or remote gateway.

See:

- [`docs/architecture.md`](docs/architecture.md)
- [`docs/providers.md`](docs/providers.md)
- [`docs/android-and-harmonyos.md`](docs/android-and-harmonyos.md)

## Run on Android

Requirements used by this repository:

- Flutter 3.41.9 / Dart 3.11.5
- JDK 17
- Android SDK 35+
- An Android emulator or device

```bash
flutter pub get
flutter run
```

Build a debug APK:

```bash
flutter build apk --debug
```

The APK is written to `build/app/outputs/flutter-apk/app-debug.apk`.

## Free-model smoke test

The quickest end-to-end test needs no account or API key:

```bash
llama-server \
  -m /absolute/path/to/your-model.gguf \
  --alias FinnAI-Foundation \
  --host 0.0.0.0 \
  --port 11434 \
  -c 16384 \
  --parallel 1 \
  -n 512
```

In Finn Code:

1. Open **Models**.
2. Select **Local llama.cpp**.
3. The Android emulator reaches the host through `10.0.2.2`, so the default URL is `http://10.0.2.2:11434/v1`.
4. Refresh models or create a new task and send a short prompt.

For hosted free tiers, add your own key in the provider editor. Never commit API keys.

## Codex app-server

On a trusted development machine, install Codex and expose app-server to the emulator:

```bash
codex app-server --listen ws://0.0.0.0:4500
```

Then configure **Codex Gateway** in Finn Code with:

```text
ws://10.0.2.2:4500
```

`10.0.2.2` is the Android emulator alias for the host machine. A physical device must use the host's LAN address. Never expose an unauthenticated app-server listener to the public internet; the upstream WebSocket transport is experimental and should be fronted by an authenticated TLS gateway for non-local deployments.

## Codex fork workflow

The submodule currently tracks the `main` branch of `Abhi-Flex1/codex`.

```bash
git submodule update --init --recursive
git -C codex switch -c finn-mobile
# make runtime changes
git -C codex push -u origin finn-mobile
git add codex
```

The top-level repository keeps `codex-upstream` pointing at `openai/codex` for comparisons and rebases.

## Verification

```bash
flutter analyze
flutter test
flutter build apk --debug
flutter test integration_test/app_test.dart -d <android-device-id>
FINN_CODEX_RUN_TURN=1 dart run tool/codex_gateway_smoke.dart
```

Run `./tool/build_android_release.sh` after integration tests when producing a
release APK. The script removes a stale dev-only plugin registrant if Flutter
left one behind and verifies that the release artifact contains production
plugins only.

The Codex smoke command expects a local app-server at `ws://127.0.0.1:4599`; override it with `FINN_CODEX_APP_SERVER_URL`. It verifies the real WebSocket handshake, model discovery, and an optional read-only turn. The current implementation is an ambitious functional foundation, not a claim that every upstream Codex capability is exposed. The app-server subset is intentionally versioned behind `AgentGateway` so protocol changes do not leak into the UI.

## License

Finn-Code is licensed under Apache-2.0. The Codex submodule retains its upstream Apache-2.0 license. Inter and JetBrains Mono are bundled under the SIL Open Font License; their license texts are in `assets/fonts/`.
