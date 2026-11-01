# tests/b: B's tests, mocks and preview (never in production)

| Folder | What |
|---|---|
| `unit/` | Pure-logic specs (layouts, validator, secrets access, protocol, GameClient + mock, selectors, formatting, strings) |
| `mock/` | Test-only fixtures, MockBalance, pure MockServer, LoopbackTransport (unit tests), MockTransport (Studio preview) |
| `preview/` | PreviewServer script that builds B's world in Studio (preview project only) |
| `tools/` | `check.sh`, `bundle.py` (runs pure modules in the Luau CLI), `sourcemap.py`, `lint.py` |

## Run everything
```bash
# needs: luau-lsp + luau on PATH, ROBLOX_DEFS -> luau-lsp's scripts/globalTypes.d.luau
export ROBLOX_DEFS=/path/to/globalTypes.d.luau
tests/b/tools/check.sh
```
Without the tools, the matching section prints `SKIPPED`. Getting the tools: install `luau-lsp` and `luau` from their GitHub releases (or build from source with CMake). The definitions file is in the luau-lsp repo under `scripts/`.

## Run only the unit tests
```bash
python3 tests/b/tools/bundle.py > /tmp/b.luau && luau /tmp/b.luau
```

## Studio preview
```bash
rojo serve preview-b.project.json
```
Connect from Studio and press Play. The client detects the test-only `ReplicatedStorage.PopParadeTestB` folder (Studio only) and uses the mock with a yellow **TEST PREVIEW** banner. To see other states, set `FIXTURE` in `mock/MockTransport.luau` to one of `Fixtures.LIST`.
