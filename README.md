# LightSelect 2.0

A lightweight native macOS extraction of Cherry Studio's selection assistant.
LightSelect directly reuses the pinned Cherry Studio selection toolbar, action
window, settings components, icons, dimensions, and theme tokens while keeping
the application process native Swift/AppKit. The reused React UI runs in the
system `WKWebView`; Electron and the rest of Cherry Studio are not bundled.

Select text in another app and LightSelect shows a small floating toolbar near the mouse:

- Translate: opens a local reading panel and asks your configured OpenAI-compatible API.
- Explain: opens the same local reading panel with an explanation prompt.
- Summary: opens the same local reading panel with a summary prompt.
- Search: opens Google search.
- Copy: copies the selected text.
- Quote: copies the selected text as Markdown quote text.

The action panel is a floating Cherry-style window with streaming output, copy,
cancel, regenerate, pin, opacity, and appearance support. The settings center
has General, Actions, API, App Filter, and About destinations plus a runtime
Chinese/English switch. It controls compact mode, trigger mode, application
filters, toolbar actions, custom prompts, follow behavior, auto-close, and
auto-pin.

## Architecture

- Swift/AppKit owns the menu bar lifecycle, Accessibility permission, windows,
  settings persistence, and OpenAI-compatible streaming.
- A native C ABI adapter wraps the pinned `selection-hook` macOS implementation,
  including Accessibility selection reads and clipboard fallback restoration.
- Three Vite entries under `Web/` adapt the pinned Cherry Studio toolbar,
  action window, and selection settings to a typed native/WebKit bridge.
- `Vendor/` and `NOTICE` record the exact upstream commits, licenses, copied
  paths, and local adaptations. Run `scripts/verify-provenance.sh` to verify them.

## Run

```bash
cd Web
npm ci
npm run build
cd ..
swift run
```

On first launch, grant Accessibility permission in System Settings, then restart LightSelect.

## Build a Release Binary

```bash
swift build -c release
```

The binary will be at:

```text
.build/release/LightSelect
```

## Build an App Bundle

```bash
chmod +x scripts/build-app.sh
scripts/build-app.sh
open build/LightSelect.app
```

If macOS asks for permission, grant Accessibility access to `LightSelect.app`, then quit and reopen it.

To keep it around as a normal local app:

```bash
mkdir -p ~/Applications
cp -R build/LightSelect.app ~/Applications/
open ~/Applications/LightSelect.app
```

For later updates, prefer:

```bash
chmod +x scripts/install-update.sh
scripts/install-update.sh
```

Grant Accessibility permission to this fixed app path:

```text
~/Applications/LightSelect.app
```

LightSelect is signed with the local identity `LightSelect Stable Code Signing` when available. That keeps the bundle identity stable across updates, so Accessibility permission should not need to be granted again after every code change. If the app was previously authorized while ad-hoc signed, remove the old LightSelect entry and authorize this stable-signed app once.

If selecting text in a browser does not show the toolbar, click the page once, select the text again, and check that `LightSelect.app` is enabled in Accessibility. LightSelect first tries the app's Accessibility selected-text API, then falls back to a temporary `Cmd+C` read and restores the previous clipboard.

## API Settings

Use the LightSelect menu bar icon -> `Selection Settings...` for selection
behavior and actions, or choose `API Settings...` to open the API section
directly.

LightSelect calls an OpenAI-compatible endpoint:

```text
POST {Base URL}/chat/completions
Authorization: Bearer {API Key}
```

The API page can fetch available models and test the connection inline. Model
discovery requires the provider to implement an OpenAI-compatible `GET /models`
endpoint; manual model entry remains available when it does not. Timeout is in
Advanced Settings, and provider errors are shown locally without exposing
response bodies.

Settings remain local in macOS UserDefaults and the API key is stored in macOS
Keychain. The native bridge sends only whether a stored key exists, never the
stored key itself. Do not commit real API keys; this repository does not include
any user key.

Standard macOS editing shortcuts work in the settings window: Command-Z,
Command-Shift-Z, Command-X, Command-C, Command-V, and Command-A. Control-V is
also accepted as a window-local paste alias.

For deterministic local API testing without using an external provider, run:

```bash
node scripts/mock-openai-server.mjs
```

Use `http://127.0.0.1:18431/success/v1` for the success path. The same server
also provides `auth`, `forbidden`, `rate`, `server`, `malformed`, `empty`, and
`slow` base-path variants under `http://127.0.0.1:18431/<variant>/v1`.

## Upstream Attribution

LightSelect 2.0 contains adapted selection-assistant source code from Cherry
Studio at the commit recorded in `Vendor/CherryStudioSelection/UPSTREAM.md` and
native selection code from `selection-hook` at the commit recorded in
`Vendor/SelectionHookNative/UPSTREAM.md`.

Cherry Studio: https://github.com/CherryHQ/cherry-studio

selection-hook: https://github.com/0xfullex/selection-hook

This project is not affiliated with, endorsed by, or maintained by Cherry
Studio, CherryHQ, or selection-hook's maintainers. See [NOTICE](NOTICE) for
attribution and adaptation details.

## License

AGPL-3.0. See [LICENSE](LICENSE).
