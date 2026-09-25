# Upstream relationship

Finn-Code is a mobile/product repository derived from the Apache-2.0 licensed `openai/codex` project.

- Upstream: `https://github.com/openai/codex`
- Fork used by the submodule: `https://github.com/Abhi-Flex1/codex`
- Submodule path: `codex/`
- Current pinned commit: see `git submodule status`

The Flutter client communicates through the public Codex app-server protocol. It does not copy or modify Rust source in the top-level commit; runtime changes belong in the Codex fork and are referenced by the submodule pointer.

When changing the submodule:

```bash
git -C codex switch -c finn-mobile
# edit and test
git -C codex push -u origin finn-mobile
git add codex
```
