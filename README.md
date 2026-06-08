# LightSelect

A tiny macOS menu bar utility inspired by Cherry Studio's selection toolbar.

Select text in another app and LightSelect shows a small floating toolbar near the mouse:

- Translate: opens a local reading panel and asks your configured OpenAI-compatible API.
- Explain: opens the same local reading panel with an explanation prompt.
- Summary: opens the same local reading panel with a summary prompt.
- Search: opens Google search.
- Copy: copies the selected text.
- Quote: copies the selected text as Markdown quote text.

The reading panel is a floating window with Translate / Explain / Summary switching, copy, regenerate, and API settings shortcuts.

## Run

```bash
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

Use the menu bar item `LS` -> `API Settings...`.

LightSelect calls an OpenAI-compatible endpoint:

```text
POST {Base URL}/chat/completions
Authorization: Bearer {API Key}
```

API settings are stored locally in macOS UserDefaults. Do not commit real API
keys; this repository does not include any user key.

## Cherry Studio Attribution

LightSelect was built with reference to Cherry Studio's selection assistant,
including its selection-toolbar interaction and visual direction.

Cherry Studio: https://github.com/CherryHQ/cherry-studio

This project is not affiliated with, endorsed by, or maintained by Cherry
Studio or CherryHQ. See [NOTICE](NOTICE) for attribution details.

## License

AGPL-3.0. See [LICENSE](LICENSE).
