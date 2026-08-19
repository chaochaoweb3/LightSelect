# LightSelect 2.0 Design

## Purpose

LightSelect 2.0 is a lightweight macOS extraction of Cherry Studio's selection assistant. It must reuse the upstream selection UI and interaction code instead of approximating Cherry Studio in AppKit, while excluding Cherry Studio features unrelated to text selection.

The upstream baseline is CherryHQ/cherry-studio commit `83d9d6325f7a00ab03a59eea31d0c943b3acf530` from 2026-08-14. LightSelect remains licensed under AGPL-3.0 and records copied and adapted upstream files in `NOTICE` and a vendor manifest.

## Success Criteria

1. Selecting meaningful text in another macOS application shows the Cherry Studio selection toolbar near the selection endpoint.
2. The toolbar and action window render from adapted copies of Cherry Studio's React components and exact theme tokens, not a separately designed AppKit imitation.
3. Translate, explain, summarize, search, copy, Markdown quote, and custom prompt actions work without launching Cherry Studio.
4. The selection settings support enabled actions and ordering, compact mode, trigger mode, follow-toolbar positioning, action-window size memory, auto-close, auto-pin, opacity, and application filtering.
5. The application contains no bundled Chromium, Cherry chat UI, knowledge base, paintings, OCR, SQLite, or full provider registry.
6. API secrets remain in local macOS preferences and are never committed or sent anywhere except the configured OpenAI-compatible endpoint.
7. The built app is signed, installs at `~/Applications/LightSelect.app`, preserves the stable bundle identifier `local.ccw3.LightSelect`, and is materially smaller than the installed 665 MB Cherry Studio application.
8. Automated tests cover native selection policies, configuration persistence, window positioning, bridge messages, web component behavior, and API error handling. Light and dark UI states are verified from screenshots against the pinned upstream baseline.

## Architecture Decision

LightSelect keeps a native Swift/AppKit process for macOS integration and uses `WKWebView` for the selection toolbar, action window, and selection settings. The web views load a small static bundle built from copied Cherry Studio React sources. macOS supplies WebKit at runtime, so LightSelect does not ship Electron or Chromium.

This hybrid is preferred over the alternatives:

- A stripped Electron fork offers the most direct runtime reuse but retains Electron's application-size and process overhead.
- A pure AppKit port is smallest but would reproduce the visual drift that LightSelect 2.0 is intended to eliminate.
- The hybrid directly reuses the upstream presentation code while leaving platform integration in the existing native process.

No Node.js runtime is required after packaging. Node, Vite, TypeScript, and Vitest are build-time tools only.

## Source Provenance

The following upstream files are copied into `Vendor/CherryStudioSelection/upstream` without conceptual redesign and are adapted through a small compatibility layer:

- `src/renderer/components/selection/SelectionToolbarView.tsx`
- `src/renderer/components/selection/SelectionActionIcon.tsx`
- `src/renderer/components/selection/DynamicSelectionActionIcon.tsx`
- `src/renderer/windows/selection/toolbar/SelectionToolbar.tsx`
- `src/renderer/windows/selection/toolbar/SelectionToolbarApp.tsx`
- `src/renderer/windows/selection/action/ActionWindow.tsx`
- `src/renderer/windows/selection/action/SelectionActionApp.tsx`
- `src/renderer/windows/selection/action/components/WindowFooter.tsx`
- the action result components needed by translate and general prompt actions
- the selection toolbar and action window HTML entry points
- the Cherry logo and selection-related theme variables
- the selection action types and default action definitions

Each copied file records its original repository path. `Vendor/CherryStudioSelection/UPSTREAM.md` records the repository URL, pinned commit, retrieval date, upstream license, copied-file list, and adaptation notes. `NOTICE` identifies Cherry Studio and the MIT-licensed `selection-hook` project where behavior is consulted.

Cherry's Electron-only code is not copied into the runtime unchanged. `SelectionService.ts`, BrowserWindow management, Electron IPC handlers, SQLite preference hooks, provider registry calls, and quote-to-main-chat behavior are replaced at explicit adapter boundaries.

## Components

### Native Application Shell

The Swift application owns lifecycle, menu-bar state, Accessibility permission prompts, log output, and the three windows. Existing uncommitted improvements to selection gesture filtering, clipboard restoration, toolbar animation, pinning, and self-tests are preserved until equivalent 2.0 components replace them.

The current single `main.swift` is split by responsibility:

- `App/AppDelegate.swift`: lifecycle and menu-bar commands.
- `Selection/SelectionMonitor.swift`: text-selection detection and trigger modes.
- `Selection/SelectionPolicy.swift`: meaningful-text and filter decisions.
- `Selection/SelectionPositioner.swift`: screen-aware toolbar and action-window placement.
- `Bridge/SelectionWebBridge.swift`: typed JSON messages between Swift and JavaScript.
- `Windows/ToolbarPanelController.swift`: nonactivating transparent toolbar panel and web view.
- `Windows/ActionPanelController.swift`: resizable action panel, focus, pin, opacity, and size persistence.
- `Windows/SettingsWindowController.swift`: selection and API settings web view.
- `API/OpenAIClient.swift`: streaming OpenAI-compatible chat completions.
- `Settings/LightSelectSettings.swift`: versioned UserDefaults schema and migration from 0.1.0.

### Web Selection UI

The web workspace uses React, TypeScript, Vite, Vitest, Testing Library, Lucide React, and the minimum styling dependencies required by the copied Cherry components. Import aliases are replaced by local adapters only where upstream application services are absent.

The compatibility layer supplies:

- preferences through a synchronous initial snapshot plus change events;
- localization for Chinese and English selection strings;
- toolbar visibility, selected text, fullscreen state, and window-size reporting;
- action dispatch, clipboard writes, URL opening, pinning, opacity, closing, and regeneration;
- incremental AI result events and cancellation;
- system light/dark appearance updates.

Copied components keep their upstream DOM structure, dimensions, CSS classes, icons, hover states, copy-status animation, and footer behavior. Adaptation must not replace them with newly designed controls.

### Settings

The default actions are Translate, Explain, Summary, Search, Copy, and Quote. Users can enable, disable, and reorder actions and add custom prompt actions. Search supports a configurable URL template containing `{{queryString}}`.

Selection preferences match Cherry's selection keys:

- `enabled`
- `actionItems`
- `actionWindowOpacity`
- `autoClose`
- `autoPin`
- `compact`
- `filterList`
- `filterMode`: default, whitelist, or blacklist
- `followToolbar`
- `rememberWindowSize`
- `triggerMode`: selected, control-key, or shortcut

LightSelect-specific API preferences are base URL, API key, model, source language, target language, and request timeout. The existing OpenAI-compatible configuration migrates without losing values.

## Selection Flow

1. The native monitor receives mouse and keyboard events.
2. It reads the focused application's Accessibility selected-text attribute.
3. If Accessibility does not expose text after a valid selection gesture, it performs a temporary Command-C read and restores every prior pasteboard item.
4. The policy rejects empty, punctuation-only, overlong, filtered, and duplicate selections.
5. The positioner calculates a visible-screen-safe toolbar origin from the selection endpoint and toolbar content size.
6. Swift sends selected text and state to the toolbar web view, which renders the copied Cherry toolbar.
7. Local actions execute immediately. AI actions open the action window and stream response deltas through the bridge.
8. Closing, regeneration, cancellation, auto-close, pinning, opacity, and size changes update native state and persisted settings.

In control-key mode, selection updates are collected passively and the toolbar appears only after the configured control-key gesture. Shortcut mode uses a registered global shortcut. Selected mode shows the toolbar after a valid selection gesture.

## Action Semantics

- Translate uses source/target language settings and Cherry's translation presentation.
- Explain, Summary, and custom actions send their configured prompts with the selected text.
- Search opens a selected URI/path directly or expands the configured search URL template.
- Copy writes the selected text and shows Cherry's success/failure icon animation.
- Quote copies the selection as Markdown quote lines because standalone LightSelect has no Cherry main chat input.
- AI responses support streaming, stop, regenerate, result copy, error display, and request cancellation when the window closes.

## Error Handling

Accessibility denial keeps the menu available and opens the correct System Settings pane. A failed clipboard fallback restores the previous pasteboard and does not show stale text. Bridge messages are decoded into typed enums; unknown or malformed messages are logged and ignored without executing an action.

HTTP failures distinguish configuration errors, authentication errors, rate limits, timeouts, malformed responses, and user cancellation. The action window displays a localized error and keeps regeneration available. API keys are redacted from logs.

A missing or invalid web bundle prevents only the affected panel from opening, records a diagnostic, and offers a menu command that opens the log file. It must not crash the menu-bar process.

## Testing And Verification

Native Swift tests cover selection gesture thresholds, meaningful text, filter modes, pasteboard snapshot restoration, screen-edge positioning, settings migration, action routing, bridge decoding, API streaming parsing, cancellation, and redaction.

Web tests start from copied upstream selection tests and adapt only their IPC fixtures. They cover toolbar actions, compact and expanded modes, copy animation, action-window reuse, pin/opacity controls, auto-close, footer shortcuts, loading/stop/regenerate states, and malformed-result errors.

A deterministic `--ui-test` launch mode renders toolbar, action, and settings fixtures without Accessibility input or network calls. Screenshot verification captures light and dark appearances at native scale. Toolbar geometry and core pixels are compared with screenshots rendered from the pinned upstream component bundle; changes beyond the documented bridge adaptations fail verification.

Release verification runs the following gates:

1. Web typecheck, unit tests, and production bundle.
2. `swift test` and release compilation.
3. App-bundle assembly with all web resources.
4. Code-signature and bundle-identifier inspection.
5. App-size comparison against Cherry Studio.
6. Clean install/update at `~/Applications/LightSelect.app`.
7. Manual selection smoke tests in a native app and a browser, including clipboard restoration.
8. Process and memory inspection while idle and while streaming one action.

## Distribution And Maintenance

`scripts/build-app.sh` builds the web bundle first, then Swift release artifacts, copies resources, and signs the result. `scripts/install-update.sh` updates the stable installed bundle without changing its identity. Version becomes `2.0.0` with a new build number.

Upstream refreshes are deliberate rather than automatic. A sync script fetches only the manifest-listed files from a requested Cherry commit, shows their diff, and requires the web and screenshot suites before the pinned commit is updated. Local adapters live outside the upstream mirror so upstream code remains recognizable and auditable.

LightSelect 2.0 remains an AGPL-3.0 project. Any distributed build includes `LICENSE`, `NOTICE`, the vendor provenance manifest, and a source-code link in the application menu.
