# Providers and free models

Provider availability and quotas change frequently. Finn Code ships presets, not guarantees. Check each provider's current terms before depending on a free tier.

## Keyless options

### Finn Demo

- Protocol: built-in offline demo
- Key: none
- Best for: UI, streaming, task, event, diff, and cancellation tests
- Limitation: simulated agent activity; no model inference

### Local llama.cpp

- Protocol: OpenAI-compatible
- Default URL: `http://10.0.2.2:11434/v1`
- Key: none
- Best for: genuine end-to-end testing with a free GGUF model
- Emulator host alias: `10.0.2.2`
- For Codex app-server turns, start llama.cpp with at least a 16K context because the Codex system prompt is larger than a small chat prompt.

### Ollama

- Protocol: OpenAI-compatible
- Default URL: `http://10.0.2.2:11434/v1`
- Key: none
- Best for: local model exploration

### Space Bunny Free

- Preset: `Space Bunny Free`
- Base URL: `https://opencode.ai/zen/v1`
- Model: `space-bunny-free`
- Key: not required for the documented free model route
- Best for: a real, zero-cost hosted turn from the Android harness

The Models tab exposes this route as `Try Space Bunny`. It is a direct API
chat path, so it does not grant file or command tools; use the Codex Gateway
runtime when the task needs approvals or workspace access.

## Hosted free-tier presets

### OpenRouter Free

- Base URL: `https://openrouter.ai/api/v1`
- Model: `openrouter/free`
- Key: required
- The router selects an available zero-cost model and can route around individual capacity limits.
- Individual free models use `:free`; availability and rate limits vary.

### Groq Free Tier

- Base URL: `https://api.groq.com/openai/v1`
- Model: `openai/gpt-oss-20b`
- Key: required
- Current official free-plan examples include GPT-OSS 20B/120B and selected Qwen models. Account limits are authoritative.
- Keep `max_tokens` modest because Groq accounts for the requested ceiling as well as generated output.

### Google AI Studio / Gemini

- Protocol: native Gemini
- Base URL: `https://generativelanguage.googleapis.com/v1beta`
- Preset model: `gemini-2.5-flash`
- Key: required
- Free-tier quotas and model names are shown in Google AI Studio.

## Paid/native adapters

The provider editor also supports:

- OpenAI and other OpenAI-compatible APIs
- Anthropic Messages
- Any Gemini-compatible project endpoint
- Codex app-server

## Model discovery

For OpenAI-compatible, Anthropic, and Gemini providers, Finn Code calls the provider's model-list endpoint. For Codex, it calls `model/list`. If discovery is unavailable, the configured model ID is used directly.

## Adding a protocol

1. Add a `ProviderProtocol` value.
2. Create an `AgentGateway` implementation in `lib/data/services`.
3. Normalize text, reasoning, events, approval requests, and usage into `AgentStreamUpdate` types.
4. Register the implementation in `AgentRepository`.
5. Add a provider preset or custom-provider metadata.
6. Add request/stream parsing tests and one emulator smoke test.

Do not put provider-specific JSON in widgets or the view model.
