# LightSelect 2.0 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build LightSelect 2.0 as a lightweight macOS application that directly reuses Cherry Studio's selection-assistant UI and interaction sources while retaining a native Swift process and system WebKit.

**Architecture:** A Swift executable and testable `LightSelectCore` library own Accessibility integration, the adapted selection-hook native bridge, settings, OpenAI-compatible streaming, and AppKit panels. Three `WKWebView` panels load a Vite bundle built from pinned Cherry Studio React components. A typed JSON bridge replaces Cherry's Electron IPC and preference services.

**Tech Stack:** Swift 5.10, AppKit, WebKit, Objective-C++, Swift Package Manager, React 19, TypeScript 5.8, Vite 7, Vitest 3, Testing Library, Lucide React, CSS copied from Cherry Studio, macOS 13+.

## Global Constraints

- Pin Cherry Studio sources to commit `83d9d6325f7a00ab03a59eea31d0c943b3acf530`.
- Pin selection-hook 2.0.3 sources to npm git commit `ff85000e98ab65ab111e2274c385eb3b86c7e19f`.
- Preserve the user's existing uncommitted selection-detection and action-window work until equivalent tested modules replace it.
- Reuse the upstream component DOM, dimensions, icons, state transitions, and theme tokens; do not redesign them in AppKit.
- Keep bundle identifier `local.ccw3.LightSelect`, install path `~/Applications/LightSelect.app`, and local code-signing identity behavior.
- Do not bundle Electron, Chromium, Node.js, SQLite, OCR, Cherry chat, knowledge, paintings, or the full provider registry.
- Store API credentials only in local UserDefaults and redact them from logs.
- Keep the project AGPL-3.0 and preserve Cherry Studio AGPL-3.0 plus selection-hook MIT provenance.
- Use repository-local Git identity `chaochaoweb3 <49186707+chaochaoweb3@users.noreply.github.com>` for every commit.
- Every new behavior follows red-green-refactor; copied third-party files retain and adapt their upstream tests before local behavior is added.

## File Map

- `Package.swift`: executable, core library, Objective-C++ bridge, resources, and test targets.
- `Sources/LightSelect/main.swift`: minimal entry point after the existing implementation is split.
- `Sources/LightSelectCore/App/`: lifecycle coordination and action routing.
- `Sources/LightSelectCore/API/`: OpenAI-compatible request and streaming parser.
- `Sources/LightSelectCore/Bridge/`: codable native/web message protocol.
- `Sources/LightSelectCore/Selection/`: policy, monitor orchestration, trigger modes, and positioning.
- `Sources/LightSelectCore/Settings/`: schema, defaults, migration, and UserDefaults store.
- `Sources/LightSelectCore/Windows/`: WebKit configuration and AppKit panel controllers.
- `Sources/SelectionHookNative/`: C ABI adapter plus copied selection-hook macOS Objective-C++ sources.
- `Tests/LightSelectCoreTests/`: Swift unit and integration tests.
- `Web/`: minimal React/Vite workspace, bridge adapters, selection entry points, and web tests.
- `Vendor/CherryStudioSelection/`: pinned upstream sources, manifest, license, and adaptation record.
- `Vendor/SelectionHookNative/`: pinned MIT source metadata and license.
- `Resources/Web/`: generated production web bundle copied into the app.
- `scripts/sync-cherry-selection.sh`: deterministic upstream fetcher.
- `scripts/verify-provenance.sh`: hash and license verifier.
- `scripts/capture-ui.sh`: deterministic LightSelect fixture screenshots.

---

### Task 1: Pin And Verify Upstream Sources

**Files:**
- Create: `Vendor/CherryStudioSelection/manifest.txt`
- Create: `Vendor/CherryStudioSelection/UPSTREAM.md`
- Create: `Vendor/CherryStudioSelection/LICENSE`
- Create: `Vendor/SelectionHookNative/UPSTREAM.md`
- Create: `Vendor/SelectionHookNative/LICENSE`
- Create: `scripts/sync-cherry-selection.sh`
- Create: `scripts/verify-provenance.sh`
- Modify: `NOTICE`

**Interfaces:**
- Consumes: GitHub raw-content URLs and pinned commit IDs.
- Produces: `scripts/sync-cherry-selection.sh <commit>` and a zero-argument provenance verifier used by builds and release checks.

- [ ] **Step 1: Write the failing provenance verifier**

Create `scripts/verify-provenance.sh` so it requires exact commit metadata, both license files, every manifest path, and SHA-256 values:

```bash
#!/usr/bin/env bash
set -euo pipefail
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
manifest="$repo_root/Vendor/CherryStudioSelection/manifest.txt"
test -f "$repo_root/Vendor/CherryStudioSelection/LICENSE"
test -f "$repo_root/Vendor/SelectionHookNative/LICENSE"
rg -q '83d9d6325f7a00ab03a59eea31d0c943b3acf530' "$repo_root/Vendor/CherryStudioSelection/UPSTREAM.md"
while IFS=$'\t' read -r digest relative_path; do
  test -n "$digest"
  test -f "$repo_root/Vendor/CherryStudioSelection/upstream/$relative_path"
  actual="$(shasum -a 256 "$repo_root/Vendor/CherryStudioSelection/upstream/$relative_path" | awk '{print $1}')"
  test "$actual" = "$digest"
done < "$manifest"
```

- [ ] **Step 2: Run the verifier and confirm the expected failure**

Run: `bash scripts/verify-provenance.sh`

Expected: non-zero exit because `Vendor/CherryStudioSelection/LICENSE` and the manifest do not exist.

- [ ] **Step 3: Implement deterministic source synchronization**

`scripts/sync-cherry-selection.sh` must accept one 40-character commit, fetch only this explicit list with `gh api -H 'Accept: application/vnd.github.raw+json'`, preserve repository-relative paths under `Vendor/CherryStudioSelection/upstream`, and regenerate sorted `manifest.txt` entries as `<sha256><tab><path>`:

```text
src/renderer/components/selection/DynamicSelectionActionIcon.tsx
src/renderer/components/selection/SelectionActionIcon.tsx
src/renderer/components/selection/SelectionToolbarView.tsx
src/renderer/components/selection/__tests__/SelectionActionIcon.test.tsx
src/renderer/components/selection/__tests__/SelectionToolbarView.test.tsx
src/renderer/windows/selection/toolbar/SelectionToolbar.tsx
src/renderer/windows/selection/toolbar/SelectionToolbarApp.tsx
src/renderer/windows/selection/toolbar/entryPoint.tsx
src/renderer/windows/selection/toolbar/index.html
src/renderer/windows/selection/toolbar/__tests__/SelectionToolbar.test.tsx
src/renderer/windows/selection/toolbar/__tests__/SelectionToolbarApp.test.tsx
src/renderer/windows/selection/action/ActionWindow.tsx
src/renderer/windows/selection/action/SelectionActionApp.tsx
src/renderer/windows/selection/action/entryPoint.tsx
src/renderer/windows/selection/action/index.html
src/renderer/windows/selection/action/errorMessage.ts
src/renderer/windows/selection/action/components/ActionGeneral.tsx
src/renderer/windows/selection/action/components/ActionResultContent.tsx
src/renderer/windows/selection/action/components/ActionTranslate.tsx
src/renderer/windows/selection/action/components/WindowFooter.tsx
src/renderer/windows/selection/action/__tests__/ActionWindow.test.tsx
src/renderer/windows/selection/action/__tests__/SelectionActionApp.test.tsx
src/renderer/windows/selection/action/__tests__/errorMessage.test.ts
src/renderer/windows/selection/action/components/__tests__/ActionGeneral.test.tsx
src/renderer/windows/selection/action/components/__tests__/ActionTranslate.test.tsx
src/renderer/windows/selection/action/components/__tests__/WindowFooter.test.tsx
src/renderer/pages/settings/SelectionAssistantSettings/SelectionAssistantSettings.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/ActionsList.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/ActionsListDivider.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/ActionsListItem.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/SelectionActionSearchModal.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/SelectionActionUserModal.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/SelectionActionsList.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/SelectionFilterListModal.tsx
src/renderer/pages/settings/SelectionAssistantSettings/components/SettingsActionsListHeader.tsx
src/renderer/pages/settings/SelectionAssistantSettings/hooks/useSettingsActionsList.ts
src/shared/data/preference/preferenceTypes.ts
src/shared/data/preference/preferenceSchemas.ts
src/main/services/selection/SelectionService.ts
src/main/services/selection/selectionConfig.ts
src/renderer/assets/images/logo.png
LICENSE
```

Fetch selection-hook's `LICENSE`, `src/mac/selection_hook.mm`, and `src/mac/lib/*.{h,mm}` at the version-2.0.3 commit recorded by `npm view selection-hook@2.0.3 gitHead` and record that commit in `Vendor/SelectionHookNative/UPSTREAM.md`.

- [ ] **Step 4: Run synchronization and make provenance pass**

Run:

```bash
bash scripts/sync-cherry-selection.sh 83d9d6325f7a00ab03a59eea31d0c943b3acf530
bash scripts/verify-provenance.sh
```

Expected: both commands exit 0 and the manifest contains no source outside the explicit list.

- [ ] **Step 5: Update notices and commit**

Add Cherry Studio repository, commit, AGPL-3.0 paths, selection-hook repository/version/commit, MIT license path, and a statement that Electron-specific services are adapted. Run `git diff --check` and commit only Task 1 files:

```bash
git commit -m "build: pin Cherry selection sources"
```

---

### Task 2: Define The Web Bridge And Preference Contract

**Files:**
- Create: `Web/package.json`
- Create: `Web/package-lock.json`
- Create: `Web/tsconfig.json`
- Create: `Web/vite.config.ts`
- Create: `Web/vitest.config.ts`
- Create: `Web/src/bridge/types.ts`
- Create: `Web/src/bridge/nativeBridge.ts`
- Create: `Web/src/bridge/__tests__/nativeBridge.test.ts`
- Create: `Web/src/preferences/defaults.ts`
- Create: `Web/src/preferences/store.ts`
- Create: `Web/src/preferences/__tests__/store.test.ts`

**Interfaces:**
- Produces: `NativeCommand`, `NativeEvent`, `SelectionPreferences`, `nativeBridge.send(command)`, `nativeBridge.on(type, listener)`, and `preferenceStore`.
- Consumes later: toolbar, action window, settings UI, and Swift `SelectionWebBridge`.

- [ ] **Step 1: Add the minimal build/test configuration**

Use runtime dependencies `react@19.2.0`, `react-dom@19.2.0`, `lucide-react@0.525.0`, `i18next@23.11.5`, `react-i18next@14.1.2`, `clsx@2.1.1`, and `tailwind-merge@3.3.1`. Use dev dependencies `typescript@5.8.3`, `vite@7.3.6`, `vitest@3.2.7`, `jsdom@26.1.0`, `@vitejs/plugin-react@5.1.1`, `@testing-library/react@16.3.0`, `@testing-library/jest-dom@6.6.3`, `@types/react@19.2.7`, and `@types/react-dom@19.2.3`; override transitive `esbuild` to `0.28.2`. Scripts are `typecheck`, `test`, and `build`. Generate and commit `package-lock.json` with `npm install`.

- [ ] **Step 2: Write failing bridge tests**

The tests must install a fake `window.webkit.messageHandlers.lightselect.postMessage`, call:

```ts
nativeBridge.send({ type: 'selection.performAction', actionId: 'translate', selectedText: 'hello' })
```

and assert the exact object was posted. A second test dispatches:

```ts
window.dispatchEvent(new CustomEvent('lightselect:event', {
  detail: { type: 'action.delta', requestId: 'r1', text: '你' }
}))
```

and asserts only the `action.delta` listener receives it. A malformed event must be ignored.

- [ ] **Step 3: Run tests and confirm RED**

Run: `npm test -- --run src/bridge/__tests__/nativeBridge.test.ts`

Expected: failure because `nativeBridge` and event schemas do not exist.

- [ ] **Step 4: Implement discriminated message unions**

Define outbound commands for perform action, resize toolbar, copy selection/result, open URL, close action, pin action, set opacity, cancel, regenerate, update preference, open settings, and open source. Define inbound events for bootstrap, selected text, appearance, toolbar visibility, action start/delta/complete/error/cancelled, and preference changes. Validate inbound objects by type plus required scalar fields before notifying listeners.

- [ ] **Step 5: Write failing preference-store tests**

Assert Cherry defaults in order: translate, explain, summary, search, copy enabled; refine and quote disabled. Assert `bootstrap` replaces all preferences and `preferences.changed` replaces only named keys without mutating the prior snapshot.

- [ ] **Step 6: Implement immutable preference state and verify GREEN**

Run:

```bash
npm run typecheck
npm test -- --run
```

Expected: all Task 2 tests pass without warnings.

- [ ] **Step 7: Commit**

```bash
git commit -m "feat: define selection web bridge"
```

---

### Task 3: Build The Copied Cherry Toolbar

**Files:**
- Create: `Web/src/adapters/cn.ts`
- Create: `Web/src/adapters/i18n.ts`
- Create: `Web/src/adapters/icons.ts`
- Create: `Web/src/styles/cherry-theme.css`
- Create: `Web/src/toolbar/entryPoint.tsx`
- Create: `Web/src/toolbar/index.html`
- Create: `Web/src/toolbar/__tests__/toolbar.test.tsx`
- Adapt: copied toolbar and selection component sources under `Web/src/vendor/cherry/`

**Interfaces:**
- Consumes: `nativeBridge`, `preferenceStore`, selected-text events.
- Produces: a content-sized toolbar root and `selection.determineToolbarSize` messages.

- [ ] **Step 1: Copy upstream toolbar sources into the build tree without redesigning markup**

Copy from the pinned vendor mirror into `Web/src/vendor/cherry/`. Preserve upstream comments and add only a top-of-file line containing the original path and pinned commit. Replace Cherry import aliases with the local adapters; do not replace the component JSX.

- [ ] **Step 2: Adapt the upstream tests first and confirm RED**

Start from Cherry's `SelectionToolbarView.test.tsx` and `SelectionToolbar.test.tsx`. Assert expanded button labels, compact title attributes, action ordering, filtered disabled actions, exact copy success/failure icon transitions, URL/path search behavior, and posted action commands. Add geometry assertions for `h-9`, `rounded-[10px]`, logo `size-[22px]`, icons `size-4`, and the upstream margin string.

Run: `npm test -- --run src/toolbar/__tests__/toolbar.test.tsx`

Expected: failure because theme, i18n, icon, and native bridge adapters are incomplete.

- [ ] **Step 3: Implement only the missing adapters**

Map the exact selection strings for `zh-CN` and `en-US`, map Cherry icon names to Lucide exports, and copy the upstream light/dark variables including `--selection-toolbar-border` and `--selection-toolbar-shadow`. Dispatch selected text and visibility through bridge events and report `Math.ceil` content dimensions.

- [ ] **Step 4: Verify toolbar GREEN**

Run:

```bash
npm run typecheck
npm test -- --run src/toolbar/__tests__/toolbar.test.tsx
npm run build
```

Expected: tests pass and Vite emits a separate toolbar HTML entry.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: reuse Cherry selection toolbar"
```

---

### Task 4: Build The Copied Cherry Action Window

**Files:**
- Create: `Web/src/action/actionStore.ts`
- Create: `Web/src/action/entryPoint.tsx`
- Create: `Web/src/action/index.html`
- Create: `Web/src/action/__tests__/actionWindow.test.tsx`
- Adapt: copied action-window sources under `Web/src/vendor/cherry/`

**Interfaces:**
- Consumes: action lifecycle bridge events and action-window preferences.
- Produces: close, pin, opacity, cancel, regenerate, and copy-result commands.

- [ ] **Step 1: Adapt upstream action tests and confirm RED**

Start from Cherry's action window, translation, general action, error-message, and footer tests. Test a new selection session even when the action ID repeats, streaming deltas, stop while loading, regenerate after completion, copy disabled while loading, Escape close, pin state, opacity slider, auto-close on blur, error rendering, and result copy.

Run: `npm test -- --run src/action/__tests__/actionWindow.test.tsx`

Expected: failure because local action state and bridge adapters are absent.

- [ ] **Step 2: Implement the bridge-backed action store**

Use this state shape:

```ts
type ActionState = {
  requestId: string | null
  action: SelectionActionItem | null
  selectedText: string
  content: string
  status: 'idle' | 'loading' | 'complete' | 'error' | 'cancelled'
  error: { code: string; message: string } | null
}
```

Reset state on every `action.start`, append only matching request deltas, ignore stale request IDs, and keep the copied Cherry rendering hierarchy.

- [ ] **Step 3: Adapt upstream imports without altering visual structure**

Replace provider hooks and Electron IPC with `actionStore`, `nativeBridge`, local i18n, local button/tooltip/slider primitives, and local Markdown rendering limited to headings, paragraphs, lists, code, links, and tables. Preserve ActionWindow header, traffic-light inset, pin/drop opacity controls, result padding, and fading WindowFooter.

- [ ] **Step 4: Verify action window GREEN**

Run:

```bash
npm run typecheck
npm test -- --run src/action/__tests__/actionWindow.test.tsx
npm run build
```

Expected: tests pass and action HTML is emitted independently of toolbar HTML.

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: reuse Cherry selection action window"
```

---

### Task 5: Build The Selection Settings UI

**Files:**
- Create: `Web/src/settings/entryPoint.tsx`
- Create: `Web/src/settings/index.html`
- Create: `Web/src/settings/APISettingsSection.tsx`
- Create: `Web/src/settings/__tests__/selectionSettings.test.tsx`
- Adapt: copied `SelectionAssistantSettings` sources under `Web/src/vendor/cherry/`

**Interfaces:**
- Consumes: full preference bootstrap and incremental changes.
- Produces: validated `preferences.update` messages and `application.openAccessibilitySettings`.

- [ ] **Step 1: Write failing settings tests**

Assert toggles for enabled/compact/follow/remember/auto-close/auto-pin, opacity from 20 through 100, trigger modes selected/control/shortcut, filter modes default/whitelist/blacklist, add/remove filter values, enable/reorder built-in actions, custom prompt creation, search URL editing, API base URL/model/timeout editing, and masked API key behavior.

Run: `npm test -- --run src/settings/__tests__/selectionSettings.test.tsx`

Expected: failure because the Cherry settings imports still depend on its preference and UI packages.

- [ ] **Step 2: Add minimal Cherry-compatible UI primitives**

Implement only Switch, Select, Slider, Button, Input, Modal, Tooltip, and sortable action-list behavior used by the copied settings components. Keep Cherry labels, spacing, list rows, drag handles, modal field order, and action icons.

- [ ] **Step 3: Add API settings as an unframed section**

Fields are Base URL, API Key, Model, source language, target language, and timeout seconds. Never echo a stored key back through the bridge; bootstrap returns `hasAPIKey: true` and the field shows a fixed masked value until replaced or cleared.

- [ ] **Step 4: Verify settings GREEN**

Run:

```bash
npm run typecheck
npm test -- --run src/settings/__tests__/selectionSettings.test.tsx
npm run build
```

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: add Cherry selection settings"
```

---

### Task 6: Establish The Swift Core And Settings Model

**Files:**
- Modify: `Package.swift`
- Create: `Sources/LightSelectCore/Settings/LightSelectSettings.swift`
- Create: `Sources/LightSelectCore/Settings/SettingsStore.swift`
- Create: `Sources/LightSelectCore/Selection/SelectionPolicy.swift`
- Create: `Sources/LightSelectCore/Selection/SelectionPositioner.swift`
- Create: `Sources/LightSelectCore/Bridge/SelectionWebMessage.swift`
- Create: `Tests/LightSelectCoreTests/SettingsStoreTests.swift`
- Create: `Tests/LightSelectCoreTests/SelectionPolicyTests.swift`
- Create: `Tests/LightSelectCoreTests/SelectionPositionerTests.swift`
- Create: `Tests/LightSelectCoreTests/SelectionWebMessageTests.swift`

**Interfaces:**
- Produces: `LightSelectSettings`, `SettingsStore`, `SelectionPolicy`, `SelectionPositioner`, `WebCommand`, and `WebEvent`.
- Consumes later: native selection monitor, panels, bridge, and action router.

- [ ] **Step 1: Add the library and test targets, then write failing model tests**

`LightSelectCore` targets macOS 13 and links AppKit, ApplicationServices, and WebKit. Tests assert Cherry action defaults and order, 0.1.0 key migration, non-persistence of masked API keys, valid opacity clamping, filter decisions using lowercase bundle identifiers, punctuation rejection, repeated-selection suppression inputs, and screen-edge positioning.

The positioner tests use:

```swift
let visible = CGRect(x: 0, y: 0, width: 1440, height: 900)
XCTAssertEqual(
    SelectionPositioner.toolbarOrigin(anchor: CGPoint(x: 1435, y: 5),
                                      toolbarSize: CGSize(width: 350, height: 43),
                                      visibleFrame: visible),
    CGPoint(x: 1082, y: 13)
)
```

Adjust the expected point only if the design's fixed 8-point screen inset yields a mathematically different value, and document the formula in the test name.

- [ ] **Step 2: Run Swift tests and confirm RED**

Run: `swift test`

Expected: compile failure because the core types are missing.

- [ ] **Step 3: Implement the immutable settings schema and migrations**

Use `Codable`, explicit schema version `2`, the exact Cherry selection fields, `APISettings`, and a `UserDefaults`-backed store injected by suite name for tests. Migrate existing `apiBaseURL`, `apiKey`, and `apiModel` keys without deleting them until the new encoded settings save succeeds.

- [ ] **Step 4: Implement policy, positioning, and codable bridge messages**

Port the meaningful-selection checks already present in the uncommitted `main.swift`. Implement default/whitelist/blacklist filters. Position toolbar above or below the anchor with 8-point visible-frame insets and position the action window at the toolbar when `followToolbar` is enabled.

- [ ] **Step 5: Verify GREEN and commit**

Run:

```bash
swift test
swift build -c release
```

Expected: all core tests pass and the existing executable still compiles.

```bash
git commit -m "feat: add LightSelect core models"
```

---

### Task 7: Reuse selection-hook's macOS Native Detection

**Files:**
- Modify: `Package.swift`
- Create: `Sources/SelectionHookNative/include/SelectionHookNative.h`
- Create: `Sources/SelectionHookNative/SelectionHookNative.mm`
- Copy/adapt: `Sources/SelectionHookNative/clipboard.{h,mm}`
- Copy/adapt: `Sources/SelectionHookNative/keyboard.{h,mm}`
- Copy/adapt: `Sources/SelectionHookNative/utils.{h,mm}`
- Create: `Sources/LightSelectCore/Selection/NativeSelectionHook.swift`
- Create: `Sources/LightSelectCore/Selection/SelectionMonitor.swift`
- Create: `Tests/LightSelectCoreTests/SelectionMonitorTests.swift`

**Interfaces:**
- C ABI: `LSSelectionHookCreate`, `LSSelectionHookStart`, `LSSelectionHookStop`, `LSSelectionHookSetPassive`, `LSSelectionHookSetFilter`, `LSSelectionHookCurrent`, `LSSelectionHookDestroy`.
- Swift protocol: `SelectionHooking` with `start(handler:)`, `stop()`, `setPassive(_:)`, `setFilter(mode:bundleIdentifiers:)`, and `currentSelection()`.
- Callback value: text, bundle identifier, four selection corners, mouse start/end, method, position level, and fullscreen flag.

- [ ] **Step 1: Write failing monitor orchestration tests with a fake hook**

Test selected mode immediate delivery, control mode passive collection followed by control-key release, shortcut mode delivery only after shortcut invocation, policy rejection, duplicate suppression, disabled state, filter propagation, and stop cleanup. Assert that callbacks are delivered on the main queue.

Run: `swift test --filter SelectionMonitorTests`

Expected: compile failure because `SelectionHooking` and `SelectionMonitor` do not exist.

- [ ] **Step 2: Add the Objective-C++ target and C ABI**

Copy upstream 2.0.3 macOS gesture constants, event taps, AX selected-text lookup, range bounds, fullscreen detection, I-beam checks, clipboard backup/restore, and filter logic. Remove N-API object wrapping and replace thread-safe JavaScript callbacks with a C function pointer plus opaque context. Preserve upstream copyright comments and mark each adaptation around Node-specific code.

- [ ] **Step 3: Implement Swift ownership and conversion**

`NativeSelectionHook` owns exactly one opaque handle, converts callback UTF-8 strings and points synchronously before the native payload is released, dispatches values to the main queue, and calls stop before destroy in `deinit`.

- [ ] **Step 4: Implement trigger orchestration and verify GREEN**

Run:

```bash
swift test --filter SelectionMonitorTests
swift test
swift build -c release
```

Expected: all tests pass; build contains no Node or Electron linkage (`otool -L .build/release/LightSelect | rg -i 'node|electron'` returns no matches).

- [ ] **Step 5: Commit**

```bash
git commit -m "feat: reuse native selection-hook detection"
```

---

### Task 8: Implement The Typed WebKit Bridge And Panels

**Files:**
- Create: `Sources/LightSelectCore/Bridge/SelectionWebBridge.swift`
- Create: `Sources/LightSelectCore/Windows/WebViewFactory.swift`
- Create: `Sources/LightSelectCore/Windows/ToolbarPanelController.swift`
- Create: `Sources/LightSelectCore/Windows/ActionPanelController.swift`
- Create: `Sources/LightSelectCore/Windows/SettingsWindowController.swift`
- Create: `Tests/LightSelectCoreTests/SelectionWebBridgeTests.swift`
- Create: `Tests/LightSelectCoreTests/PanelStateTests.swift`

**Interfaces:**
- Consumes: `WebCommand`, `WebEvent`, settings, and production `Resources/Web` URLs.
- Produces: `SelectionWebBridgeDelegate` callbacks and panel `show/hide/update` methods.

- [ ] **Step 1: Write failing bridge tests**

Decode every outbound Web command from JSON dictionaries, reject missing fields and unknown types, verify JavaScript event serialization escapes Unicode/newlines safely through `JSONEncoder`, and verify that API-key bootstrap exposes only `hasAPIKey`.

Run: `swift test --filter SelectionWebBridgeTests`

Expected: compile failure because bridge and delegate types are absent.

- [ ] **Step 2: Implement the bridge**

Register only `lightselect` as a `WKScriptMessageHandler`, decode the body by round-tripping through `JSONSerialization` and `JSONDecoder`, forward valid commands to a weak delegate, and emit events with:

```swift
window.dispatchEvent(new CustomEvent('lightselect:event', { detail: <encoded JSON> }))
```

Remove the script handler when the bridge is invalidated to prevent retain cycles.

- [ ] **Step 3: Write failing panel-state tests**

Extract testable panel state reducers for toolbar visible/hidden transitions, action pin/auto-close/opacity, remembered-size clamping, and settings singleton behavior. Verify repeated hide calls are idempotent and stale animation completions cannot hide a newly shown toolbar.

- [ ] **Step 4: Implement panels with copied web content**

Toolbar uses a borderless nonactivating `NSPanel`, transparent `WKWebView`, no scrollbars, content-size messages, and `orderFrontRegardless`. Action panel is borderless/resizable, can become key, starts at 500x400, and applies pin/opacity/remember-size settings. Settings is a normal titled window. All three use nonpersistent `WKWebsiteDataStore`, local-file read access limited to the bundled Web directory, and navigation policy that blocks nonlocal navigation.

- [ ] **Step 5: Verify GREEN and commit**

Run:

```bash
swift test --filter SelectionWebBridgeTests
swift test --filter PanelStateTests
swift test
```

```bash
git commit -m "feat: host Cherry UI in native panels"
```

---

### Task 9: Implement Streaming AI And Action Routing

**Files:**
- Create: `Sources/LightSelectCore/API/OpenAIClient.swift`
- Create: `Sources/LightSelectCore/API/ServerSentEventParser.swift`
- Create: `Sources/LightSelectCore/App/SelectionActionRouter.swift`
- Create: `Tests/LightSelectCoreTests/ServerSentEventParserTests.swift`
- Create: `Tests/LightSelectCoreTests/OpenAIClientTests.swift`
- Create: `Tests/LightSelectCoreTests/SelectionActionRouterTests.swift`

**Interfaces:**
- `OpenAIClient.stream(request:onEvent:) -> UUID` and `cancel(requestID:)`.
- `SelectionActionRouter.perform(action:selectedText:anchor:)` routes local and AI actions.
- Stream events: started, delta, completed, failed, and cancelled with stable request IDs.

- [ ] **Step 1: Write failing SSE parser tests**

Cover chunk boundaries inside UTF-8 text, multiple `data:` lines, blank heartbeat lines, `[DONE]`, OpenAI `choices[0].delta.content`, an error JSON body, and a final line without trailing newline.

Run: `swift test --filter ServerSentEventParserTests`

Expected: compile failure because the parser does not exist.

- [ ] **Step 2: Implement the incremental parser and verify it GREEN**

Use a byte buffer, split complete SSE events on double newline, concatenate `data:` lines with newline, and decode only complete UTF-8 payloads. Do not log payload bodies.

- [ ] **Step 3: Write failing client and router tests**

Use a custom `URLProtocol` to inspect `POST {baseURL}/chat/completions`, Bearer auth, model, `stream: true`, timeout, prompts, status mappings for 401/429/500, cancellation, and API-key redaction. Router tests assert Search URI detection and URL expansion, Copy, Markdown Quote, Translate prompt language values, Explain/Summary/Refine/custom prompts, and stale-stream event rejection.

- [ ] **Step 4: Implement client and router**

The router owns active request ID and selected text, opens the action panel before streaming, maps errors to stable codes `configuration`, `authentication`, `rate_limit`, `server`, `timeout`, `invalid_response`, and `cancelled`, and posts action events through the bridge.

- [ ] **Step 5: Verify GREEN and commit**

Run:

```bash
swift test --filter ServerSentEventParserTests
swift test --filter OpenAIClientTests
swift test --filter SelectionActionRouterTests
swift test
```

```bash
git commit -m "feat: stream selection AI actions"
```

---

### Task 10: Integrate The 2.0 Application And Preserve Existing Work

**Files:**
- Create: `Sources/LightSelectCore/App/AppCoordinator.swift`
- Create: `Sources/LightSelectCore/App/AppDelegate.swift`
- Replace: `Sources/LightSelect/main.swift`
- Remove after parity: native `ToolbarButton`, `SelectionToolbar`, and `ActionWindow` definitions from the old single file.
- Create: `Tests/LightSelectCoreTests/AppCoordinatorTests.swift`
- Modify: `README.md`

**Interfaces:**
- `AppCoordinator` owns monitor, router, settings store, and three panel controllers.
- AppDelegate owns status item, accessibility prompts, enabled state, logs, source link, settings, fixture mode, and quit.

- [ ] **Step 1: Write failing coordinator tests**

With protocol fakes, verify launch starts monitoring only when enabled, selecting text shows the toolbar, clearing selection hides it, changing trigger/filter preferences reconfigures the monitor, action commands reach the router, settings changes broadcast to all web views, disabled state stops the hook and hides panels, and termination cancels requests and invalidates bridges.

Run: `swift test --filter AppCoordinatorTests`

Expected: compile failure because coordinator protocols and implementation are absent.

- [ ] **Step 2: Split the existing single file without losing behavior**

Move API settings values into the schema migration, logging into AppDelegate support, Accessibility prompts/settings URLs into AppDelegate, and the uncommitted gesture/pasteboard/self-test behavior into their corresponding tested modules. Replace native toolbar and action UI only after WebKit controllers pass their tests. Keep `--api-test` until its coverage is replaced; change `--self-test` to run the same core fixtures through public test helpers or remove it only after `swift test` covers every assertion.

- [ ] **Step 3: Implement coordinator and entry point**

`main.swift` creates `NSApplication.shared`, an AppDelegate, sets `.accessory`, and runs. Menu items are Enabled, Selection Settings, API Settings (opens the settings API section), Test API, Show Test Toolbar, Show Test Action, Open Accessibility Settings, Open Log, View Source Code, and Quit.

- [ ] **Step 4: Verify GREEN and commit**

Run:

```bash
swift test --filter AppCoordinatorTests
swift test
swift build -c release
git diff --check
```

Confirm `git diff 117fb0e -- Sources/LightSelect/main.swift Sources/LightSelectCore` shows every pre-existing uncommitted behavior either preserved or superseded by a named test.

```bash
git commit -m "feat: integrate LightSelect 2.0"
```

---

### Task 11: Package, Render, Compare, Install, And Audit

**Files:**
- Modify: `Resources/Info.plist`
- Modify: `scripts/build-app.sh`
- Modify: `scripts/install-update.sh`
- Create: `scripts/capture-ui.sh`
- Create: `scripts/verify-release.sh`
- Create: `Tests/Fixtures/action-response.md`
- Create: `artifacts/ui/light-toolbar.png`
- Create: `artifacts/ui/dark-toolbar.png`
- Create: `artifacts/ui/light-action.png`
- Create: `artifacts/ui/dark-action.png`

**Interfaces:**
- `LightSelect --ui-test toolbar|action|settings --appearance light|dark --output <path>` renders deterministic fixtures.
- `scripts/verify-release.sh <app-path>` verifies packaging, identity, provenance, size, and forbidden dependencies.

- [ ] **Step 1: Write the failing release verifier**

Require version `2.0.0`, build number `200`, bundle ID `local.ccw3.LightSelect`, `Contents/Resources/Web/toolbar.html`, action and settings HTML, both licenses, `NOTICE`, provenance manifests, valid `codesign --verify --deep --strict`, app size below 25 MB, and no files or linked libraries matching Electron, Chromium, Node, SQLite, OCR, or Cherry chat modules.

Run: `bash scripts/verify-release.sh build/LightSelect.app`

Expected: failure because the current 0.1.0 bundle lacks Web resources and provenance.

- [ ] **Step 2: Update build and installer scripts**

`build-app.sh` runs provenance verification, `npm ci`, web typecheck/tests/build, `swift test`, Swift release build, app assembly, resource copying, plist copy, and signing. It copies the generated web bundle, logo, `LICENSE`, `NOTICE`, both upstream license files, and both provenance documents into `Contents/Resources`. `install-update.sh` updates the complete bundle atomically through a sibling staging directory while retaining the fixed destination and signing identity.

- [ ] **Step 3: Implement deterministic UI fixture mode**

Fixture toolbar text is `LightSelect 2.0 selection fixture`. Fixture action is Translate with a fixed bilingual Markdown response and completed state. Settings use default actions plus one custom prompt. Set fixed panel sizes and disable nondeterministic animations after their final frame before capture.

- [ ] **Step 4: Build and confirm release verifier GREEN**

Run:

```bash
bash scripts/build-app.sh
bash scripts/verify-release.sh build/LightSelect.app
```

Expected: all checks pass and the app is below 25 MB.

- [ ] **Step 5: Capture and visually inspect every required state**

Run `scripts/capture-ui.sh` for light/dark toolbar and action states plus settings at 1440x900. Inspect images for nonblank content, exact 36-pixel toolbar content height, 10-pixel radius, 22-pixel logo, 16-pixel icons, no clipped labels, correct Cherry green hover fixture, no overlap, and action footer visibility. Compare against the pinned Cherry renderer capture and record pixel-difference output in `artifacts/ui/comparison.txt`.

- [ ] **Step 6: Install and perform real smoke tests**

Run:

```bash
bash scripts/install-update.sh
codesign --verify --deep --strict "$HOME/Applications/LightSelect.app"
defaults read "$HOME/Applications/LightSelect.app/Contents/Info" CFBundleShortVersionString
du -sh "$HOME/Applications/LightSelect.app"
```

Launch the installed app, verify Accessibility trust, select text in TextEdit and Chrome, invoke Copy without changing pre-existing rich pasteboard items, invoke Search, run one configured AI action, verify cancel/regenerate, verify compact/light/dark modes, and record idle plus streaming RSS.

- [ ] **Step 7: Run the completion audit and commit**

Run all gates from a clean build:

```bash
bash scripts/verify-provenance.sh
cd Web && npm ci && npm run typecheck && npm test -- --run && npm run build
cd .. && swift test && swift build -c release
bash scripts/build-app.sh
bash scripts/verify-release.sh build/LightSelect.app
git diff --check
git status --short
```

Audit every success criterion in `docs/superpowers/specs/2026-08-14-lightselect-2-design.md` against source, tests, built app, screenshots, installed behavior, size, process list, and signature. Commit only after all evidence is present:

```bash
git commit -m "release: build LightSelect 2.0"
```
