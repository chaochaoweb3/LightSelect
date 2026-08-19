# LightSelect Settings Center Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a polished Cherry-style LightSelect settings center with application-wide Chinese/English localization, inline API testing, model discovery, explicit save status, and working macOS keyboard editing shortcuts.

**Architecture:** Keep the existing Swift/AppKit host and three system `WKWebView` entries. Add a focused native OpenAI configuration service, extend the typed Swift/TypeScript bridge with request-correlated preference and API events, persist the interface language in schema version 3, and reorganize the existing Cherry-derived React settings page into a sidebar/content workspace.

**Tech Stack:** Swift 5.10, AppKit, WebKit, Foundation `URLSession`, Swift Package Manager, React 19, TypeScript 5.8, Vite 7, Vitest 3, Testing Library, i18next, Lucide React, Cherry Studio semantic CSS tokens.

**Spec:** `docs/superpowers/specs/2026-08-18-lightselect-settings-center-design.md`

## Global Constraints

- Preserve the native Swift/AppKit plus system `WKWebView` architecture; do not bundle Electron or Chromium.
- Support macOS 13 and newer.
- Keep API keys outside settings JSON and never emit them in native-to-web events, logs, test failures, or UI errors.
- Preserve all existing schema-version-2 settings and credentials; migrated settings save as schema version 3.
- Support `zh-CN` and `en-US` across settings, toolbar, action window, native status menu, native alerts, and settings window title without restart.
- Keep provider model identifiers, URLs, API values, code, and user-created action text unchanged across language switches.
- Keep manual model entry available even when `/models` is unavailable or returns an empty list.
- Use Cherry semantic tokens and Lucide icons; no gradients, decorative shapes, nested cards, marketing copy, or oversized headings.
- Use request identifiers for preference saves, model requests, and connection tests; stale events must not overwrite newer UI state.
- Real provider testing is an explicit final user acceptance action because it can consume quota and depends on external service behavior.
- Do not push commits unless the user explicitly requests it.

## File Structure

### New Native Files

- `Sources/LightSelectCore/API/OpenAIConfigurationService.swift`: base-URL normalization, model discovery, connection testing, cancellation, response parsing, error mapping, and latency measurement.
- `Sources/LightSelectCore/App/AppLocalization.swift`: typed Simplified Chinese and English strings for AppKit menus, alerts, and window titles.
- `Sources/LightSelectCore/App/ApplicationMenuFactory.swift`: application/Edit menu construction with standard responder-chain commands.
- `Sources/LightSelectCore/Settings/KeychainAPICredentialStore.swift`: Security-framework storage and migration target for the API key.
- `Tests/LightSelectCoreContractTests/main.swift`: runnable no-XCTest contract suite for the current Command Line Tools environment.

### New Web Files

- `Web/src/settings/SettingsSidebar.tsx`: desktop sidebar and narrow horizontal navigation.
- `Web/src/settings/SettingsPageHeader.tsx`: page title, description, and correlated save-state indicator.
- `Web/src/settings/GeneralSettingsSection.tsx`: general and result-window controls.
- `Web/src/settings/AppFilterSettingsSection.tsx`: filter mode, list count, and filter modal orchestration.
- `Web/src/settings/AboutSettingsSection.tsx`: permissions, source, version, and license actions.
- `Web/src/settings/ModelCombobox.tsx`: editable model input, accessible suggestion list, and refresh control.
- `Web/src/settings/apiRequestStore.ts`: request-correlated model/test operation state and stale-event rejection.
- `scripts/mock-openai-server.mjs`: deterministic local `/models` and `/chat/completions` provider for installed-app acceptance.

### Existing Files With Expanded Responsibilities

- `Sources/LightSelectCore/Settings/LightSelectSettings.swift`: schema-3 interface-language model and backward decoding.
- `Sources/LightSelectCore/Bridge/SelectionWebMessage.swift`: correlated preference/API commands and events.
- `Sources/LightSelectCore/App/AppCoordinator.swift`: persistence acknowledgements and API service orchestration.
- `Sources/LightSelectCore/App/AppDelegate.swift`: localization refresh, service wiring, and main-menu installation.
- `Sources/LightSelectCore/Windows/SettingsWindowController.swift`: localized title and window-scoped Control-V forwarding.
- `Web/src/bridge/types.ts`: exact TypeScript mirror of native settings, commands, events, and validators.
- `Web/src/preferences/store.ts`: confirmed/optimistic preference state and rollback on failed saves.
- `Web/src/preferences/update.ts`: request-ID generation and correlated preference commands.
- `Web/src/adapters/i18n.ts`: complete application string catalogs and runtime language synchronization.
- `Web/src/vendor/cherry/pages/settings/SelectionAssistantSettings/SelectionAssistantSettings.tsx`: settings-center page composition only.
- `Web/src/settings/APISettingsSection.tsx`: API draft editing, key visibility, model/test requests, and inline state.
- `Web/src/styles/settings.css`: settings-center layout, responsive behavior, fields, status, and accessible interaction states.

---

### Task 1: Add a Runnable Native Contract Suite and Schema-3 Language Preference

**Files:**
- Modify: `Package.swift`
- Create: `Tests/LightSelectCoreContractTests/main.swift`
- Modify: `Sources/LightSelectCore/Settings/LightSelectSettings.swift`
- Create: `Sources/LightSelectCore/Settings/KeychainAPICredentialStore.swift`
- Modify: `Sources/LightSelectCore/Settings/SettingsStore.swift`
- Modify: `Tests/LightSelectCoreTests/SettingsStoreTests.swift`
- Modify: `Web/src/bridge/types.ts`
- Modify: `Web/src/preferences/defaults.ts`
- Modify: `Web/src/preferences/__tests__/store.test.ts`

**Interfaces:**
- Produces: `InterfaceLanguage`, `LightSelectSettings.interfaceLanguage`, schema version 3, and `SelectionPreferences.interfaceLanguage`.
- Produces: `APICredentialStoring` plus a Keychain implementation and one-time migration from the existing UserDefaults credential key.
- Produces: `swift run LightSelectCoreContractTests <contract-name>` as the native red/green command available without XCTest.
- Consumes: existing `LightSelectSettings` Codable model and `SelectionPreferences` runtime validator.

- [ ] **Step 1: Add the contract executable target and write the failing migration contract**

Add this target after `LightSelect` in `Package.swift`:

```swift
.executableTarget(
    name: "LightSelectCoreContractTests",
    dependencies: ["LightSelectCore"],
    path: "Tests/LightSelectCoreContractTests"
),
```

Create `Tests/LightSelectCoreContractTests/main.swift` with a tiny named-contract runner and the first contract:

```swift
import Foundation
import LightSelectCore

enum ContractFailure: Error { case failed(String) }

func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    guard condition() else { throw ContractFailure.failed(message) }
}

func settingsLanguageContract() throws {
    let current = LightSelectSettings.default
    try require(current.schemaVersion == 3, "schema version must be 3")
    try require(current.interfaceLanguage == .zhCN, "default language must preserve Chinese behavior")

    let legacy = """
    {"schemaVersion":2,"enabled":false,"actionItems":[],"actionWindowOpacity":100,
    "autoClose":false,"autoPin":false,"compact":false,"filterList":[],"filterMode":"default",
    "followToolbar":true,"rememberWindowSize":false,"triggerMode":"selected",
    "api":{"baseURL":"https://api.example.com/v1","model":"m","sourceLanguage":"auto",
    "targetLanguage":"zh-cn","timeoutSeconds":60}}
    """
    let migrated = try JSONDecoder().decode(LightSelectSettings.self, from: Data(legacy.utf8))
    try require(migrated.interfaceLanguage == .zhCN, "schema 2 must migrate to zh-CN")
}

let selected = CommandLine.arguments.dropFirst().first ?? "all"
do {
    if selected == "all" || selected == "settings-language" { try settingsLanguageContract() }
    print("CONTRACT_OK \(selected)")
} catch {
    fputs("CONTRACT_FAILED \(selected): \(error)\n", stderr)
    exit(1)
}
```

Add an in-memory `APICredentialStoring` fake to the contract runner. Seed `UserDefaults` with the existing `lightselect.credentials.apiKey`, load `SettingsStore`, and assert the value moves to the fake credential store and is removed from UserDefaults only after the Keychain-style save succeeds.

Add XCTest assertions for schema 3, default `.zhCN`, explicit `.enUS`, schema-2 settings migration, settings-key migration from `lightselect.settings.v2` to `lightselect.settings.v3`, successful credential migration, and failed credential writes leaving the legacy value recoverable. Add a Vitest assertion that the default web preference is `zh-CN` and that a bootstrap event containing `en-US` passes validation.

- [ ] **Step 2: Run the contracts and verify RED**

Run:

```bash
swift run LightSelectCoreContractTests settings-language
cd Web && npm test -- --run src/preferences/__tests__/store.test.ts
```

Expected: Swift compilation fails because `InterfaceLanguage`, `interfaceLanguage`, and `APICredentialStoring` do not exist; Vitest fails because the preference field and validator do not exist.

- [ ] **Step 3: Implement schema-3 language persistence in Swift and TypeScript**

Add to `LightSelectSettings.swift`:

```swift
public enum InterfaceLanguage: String, Codable, CaseIterable, Sendable {
    case zhCN = "zh-CN"
    case enUS = "en-US"
}
```

Add `interfaceLanguage` to the stored model and initializer, set `schemaVersion = 3`, and decode with:

```swift
interfaceLanguage: try container.decodeIfPresent(InterfaceLanguage.self, forKey: .interfaceLanguage) ?? .zhCN
```

Add to `SelectionPreferences`:

```ts
export type InterfaceLanguage = 'zh-CN' | 'en-US'
interfaceLanguage: InterfaceLanguage
```

Add `interfaceLanguage: 'zh-CN'` to `defaultSelectionPreferences`, include the key in `selectionPreferenceKeys`, validate it in `isSelectionPreferences`, and accept only `zh-CN` or `en-US` in `isPreferenceValue`.

Link the `Security` framework from `LightSelectCore`. Implement:

```swift
public protocol APICredentialStoring: AnyObject {
    var apiKey: String? { get }
    @discardableResult func updateAPIKey(_ value: String?) -> Bool
}

public final class KeychainAPICredentialStore: APICredentialStoring {
    public static let service = "local.ccw3.LightSelect"
    public static let account = "openai-compatible-api-key"
}
```

Use `SecItemCopyMatching`, `SecItemAdd`, `SecItemUpdate`, and `SecItemDelete`; return only success/failure and never include key bytes in errors. Inject `APICredentialStoring` into `SettingsStore` with `KeychainAPICredentialStore()` as the production default.

Change `SettingsStore.settingsKey` to `lightselect.settings.v3` and retain `legacySettingsKey = lightselect.settings.v2`. Load v3 first, otherwise decode v2, save v3, then remove v2 only after byte-for-byte verification of the new value. Migrate `lightselect.credentials.apiKey`, `api.key`, or `apiKey` into the credential store and remove a legacy credential only after `updateAPIKey` returns true.

- [ ] **Step 4: Run native and web contracts and verify GREEN**

Run:

```bash
swift run LightSelectCoreContractTests settings-language
cd Web && npm test -- --run src/preferences/__tests__/store.test.ts src/bridge/__tests__/nativeBridge.test.ts
find Sources Tests -name '*.swift' -print0 | xargs -0 -n1 swiftc -parse
```

Expected: `CONTRACT_OK settings-language`; Vitest passes; all Swift files parse.

- [ ] **Step 5: Commit the schema foundation**

```bash
git add Package.swift Tests/LightSelectCoreContractTests/main.swift Sources/LightSelectCore/Settings/LightSelectSettings.swift Sources/LightSelectCore/Settings/KeychainAPICredentialStore.swift Sources/LightSelectCore/Settings/SettingsStore.swift Tests/LightSelectCoreTests/SettingsStoreTests.swift Web/src/bridge/types.ts Web/src/preferences/defaults.ts Web/src/preferences/__tests__/store.test.ts
git commit -m "feat: persist interface language"
```

---

### Task 2: Correlate Preference Saves and Expose Save Status

**Files:**
- Modify: `Sources/LightSelectCore/Bridge/SelectionWebMessage.swift`
- Modify: `Sources/LightSelectCore/App/AppCoordinator.swift`
- Modify: `Tests/LightSelectCoreTests/SelectionWebMessageTests.swift`
- Modify: `Tests/LightSelectCoreTests/AppCoordinatorTests.swift`
- Modify: `Tests/LightSelectCoreContractTests/main.swift`
- Modify: `Web/src/bridge/types.ts`
- Modify: `Web/src/preferences/store.ts`
- Modify: `Web/src/preferences/update.ts`
- Modify: `Web/src/preferences/__tests__/store.test.ts`

**Interfaces:**
- Consumes: `InterfaceLanguage` and schema-3 preferences from Task 1.
- Produces: `preferences.update(requestId,key,value)`, `preferences.saved(requestId,key,value)`, and `preferences.saveFailed(requestId,key)`.
- Produces: `preferenceStore.getSaveSnapshot()` returning `{ phase: 'idle' | 'saving' | 'saved' | 'failed'; requestId?: string }`.

- [ ] **Step 1: Write failing bridge, coordinator, and optimistic-rollback tests**

Add a bridge test that decodes:

```swift
let data = Data(#"{"type":"preferences.update","requestId":"save-1","key":"interfaceLanguage","value":"en-US"}"#.utf8)
XCTAssertEqual(
    try JSONDecoder().decode(WebCommand.self, from: data),
    .updatePreference(requestID: "save-1", update: .interfaceLanguage(.enUS))
)
```

Extend `FakeSettingsStore` with `var shouldSave = true`, and test that a successful coordinator save emits both `.preferenceChanged` and `.preferenceSaved`, while a failed save emits `.preferenceSaveFailed` and leaves `coordinator.settings` at the previous confirmed value.

In `store.test.ts`, begin an optimistic update, apply a matching failure, and assert that the original value returns and save phase becomes `failed`. Apply an obsolete failure after a newer request and assert it is ignored.

- [ ] **Step 2: Run focused tests and verify RED**

Run:

```bash
cd Web && npm test -- --run src/preferences/__tests__/store.test.ts src/bridge/__tests__/nativeBridge.test.ts
swift run LightSelectCoreContractTests preference-save
```

Expected: TypeScript fails on missing correlated event types/store methods; the native contract fails on missing command/event cases.

- [ ] **Step 3: Implement correlated preference commands and native acknowledgements**

Change the Swift command and events to:

```swift
case updatePreference(requestID: String, update: SelectionPreferenceUpdate)
case preferenceSaved(requestID: String, update: SelectionPreferenceUpdate)
case preferenceSaveFailed(requestID: String, key: String)
```

Add `.interfaceLanguage(InterfaceLanguage)` to `SelectionPreferenceUpdate`. Decode and encode `requestId` for all save messages.

Refactor coordinator application to mutate a candidate copy first:

```swift
private func apply(requestID: String, update: SelectionPreferenceUpdate) {
    var candidate = settings
    candidate.apply(update)
    guard settingsStore.save(candidate) else {
        settingsWindow.send(.preferenceSaveFailed(requestID: requestID, key: update.key))
        return
    }
    settings = candidate
    reconfigureAfterConfirmedSave(update)
    broadcast(.preferenceChanged(update))
    settingsWindow.send(.preferenceSaved(requestID: requestID, update: update))
}
```

Add `SelectionPreferenceUpdate.apply(to:)` with an exhaustive switch for every key, including `interfaceLanguage`, and call it on the candidate before saving. Keep `SelectionPreferenceUpdate.key` internally visible to the module. Do not mutate monitor or action-window state until the store confirms the save.

- [ ] **Step 4: Implement web optimistic state with request-correlated rollback**

Define the command/event shapes with `requestId`. Extend the preference store with a confirmed snapshot, pending entries keyed by preference key, and a separate save snapshot. `updatePreference` generates `crypto.randomUUID()`, records the previous confirmed value, applies the optimistic value, and sends the command.

On `preferences.saved`, confirm only when `requestId` matches the pending request for that key. On `preferences.saveFailed`, restore the confirmed value only when it matches. On bootstrap, clear all pending state.

- [ ] **Step 5: Run focused and regression tests and verify GREEN**

Run:

```bash
cd Web && npm test -- --run src/preferences/__tests__/store.test.ts src/bridge/__tests__/nativeBridge.test.ts src/settings/__tests__/selectionSettings.test.tsx
swift run LightSelectCoreContractTests preference-save
find Sources Tests -name '*.swift' -print0 | xargs -0 -n1 swiftc -parse
```

Expected: correlated save and rollback tests pass; existing settings behavior remains green.

- [ ] **Step 6: Commit correlated persistence**

```bash
git add Sources/LightSelectCore/Bridge/SelectionWebMessage.swift Sources/LightSelectCore/App/AppCoordinator.swift Tests/LightSelectCoreTests/SelectionWebMessageTests.swift Tests/LightSelectCoreTests/AppCoordinatorTests.swift Tests/LightSelectCoreContractTests/main.swift Web/src/bridge/types.ts Web/src/preferences/store.ts Web/src/preferences/update.ts Web/src/preferences/__tests__/store.test.ts
git commit -m "feat: report settings save status"
```

---

### Task 3: Implement OpenAI-Compatible Model Discovery and Connection Testing

**Files:**
- Create: `Sources/LightSelectCore/API/OpenAIConfigurationService.swift`
- Create: `Tests/LightSelectCoreTests/OpenAIConfigurationServiceTests.swift`
- Modify: `Tests/LightSelectCoreContractTests/main.swift`

**Interfaces:**
- Consumes: existing `APISettings` and credentials provided by the coordinator.
- Produces: `APIConfiguration`, `ModelDiscoveryResult`, `ConnectionTestResult`, `APIConfigurationError`, and `OpenAIConfigurationServing`.
- Produces: cancellable `fetchModels(requestID:configuration:completion:)`, `testConnection(requestID:configuration:completion:)`, `cancel(requestID:)`, and `cancelAll()`.

- [ ] **Step 1: Write failing URL normalization and model parsing contracts**

Add contracts for these exact endpoint mappings:

```swift
try require(
    OpenAIConfigurationService.endpoint(baseURL: "https://api.example.com/v1", resource: .models)?.absoluteString
        == "https://api.example.com/v1/models",
    "v1 must append models"
)
try require(
    OpenAIConfigurationService.endpoint(baseURL: "https://api.example.com/v1/chat/completions", resource: .models)?.absoluteString
        == "https://api.example.com/v1/models",
    "chat completions must normalize before models"
)
```

Use a `MockURLProtocol` in the contract runner to return:

```json
{"data":[{"id":"gpt-z"},{"id":"gpt-a"},{"id":"gpt-z"},{"id":""}]}
```

Assert request method `GET`, bearer header, endpoint `/v1/models`, and result `['gpt-a','gpt-z']`. Add XCTest equivalents plus malformed response, empty response, 401, 403, 429, 500, timeout, and cancellation cases.

- [ ] **Step 2: Run the service contract and verify RED**

Run:

```bash
swift run LightSelectCoreContractTests api-configuration
```

Expected: compilation fails because `OpenAIConfigurationService` and its result/error types do not exist.

- [ ] **Step 3: Implement the service types and request lifecycle**

Create these public types:

```swift
public struct APIConfiguration: Equatable, Sendable {
    public let baseURL: String
    public let apiKey: String
    public let model: String
    public let timeoutSeconds: Int
}

public struct ModelDiscoveryResult: Equatable, Sendable {
    public let models: [String]
    public let latencyMilliseconds: Int
}

public struct ConnectionTestResult: Equatable, Sendable {
    public let latencyMilliseconds: Int
}

public enum APIConfigurationError: String, Error, Equatable, Sendable {
    case configuration
    case authentication
    case forbidden
    case rateLimit = "rate_limit"
    case server
    case timeout
    case connection
    case invalidResponse = "invalid_response"
    case cancelled
}
```

Define the protocol:

```swift
public protocol OpenAIConfigurationServing: AnyObject {
    func fetchModels(requestID: UUID, configuration: APIConfiguration,
                     completion: @escaping (Result<ModelDiscoveryResult, APIConfigurationError>) -> Void)
    func testConnection(requestID: UUID, configuration: APIConfiguration,
                        completion: @escaping (Result<ConnectionTestResult, APIConfigurationError>) -> Void)
    func cancel(requestID: UUID)
    func cancelAll()
}
```

The concrete service stores `[UUID: URLSessionDataTask]` behind `NSLock`. Model parsing accepts only a top-level `data` array containing string `id` fields, trims whitespace, removes empties/duplicates, and sorts with `localizedStandardCompare`.

Connection testing sends `POST /chat/completions` with `stream: false`, `max_tokens: 1`, and messages `[{"role":"user","content":"Reply with OK."}]`. Treat a 2xx JSON object containing a non-empty `choices` array as success. Map HTTP and `URLError` values to stable enum cases without retaining provider bodies.

- [ ] **Step 4: Run service tests and verify GREEN**

Run:

```bash
swift run LightSelectCoreContractTests api-configuration
find Sources Tests -name '*.swift' -print0 | xargs -0 -n1 swiftc -parse
```

Expected: endpoint, request, parsing, error, latency, and cancellation contracts pass; Swift parse is clean.

- [ ] **Step 5: Commit the configuration service**

```bash
git add Sources/LightSelectCore/API/OpenAIConfigurationService.swift Tests/LightSelectCoreTests/OpenAIConfigurationServiceTests.swift Tests/LightSelectCoreContractTests/main.swift
git commit -m "feat: add API configuration service"
```

---

### Task 4: Bridge API Operations Through the Coordinator

**Files:**
- Modify: `Sources/LightSelectCore/Bridge/SelectionWebMessage.swift`
- Modify: `Sources/LightSelectCore/App/AppCoordinator.swift`
- Modify: `Sources/LightSelectCore/App/AppDelegate.swift`
- Modify: `Sources/LightSelectCore/Windows/SettingsWindowController.swift`
- Modify: `Tests/LightSelectCoreTests/SelectionWebMessageTests.swift`
- Modify: `Tests/LightSelectCoreTests/AppCoordinatorTests.swift`
- Modify: `Tests/LightSelectCoreContractTests/main.swift`
- Modify: `Web/src/bridge/types.ts`
- Modify: `Web/src/bridge/__tests__/nativeBridge.test.ts`

**Interfaces:**
- Consumes: `OpenAIConfigurationServing` from Task 3 and correlated settings from Task 2.
- Produces commands: `api.fetchModels`, `api.testConnection`, and `api.cancelRequest`.
- Produces events: `api.modelsLoaded`, `api.connectionSucceeded`, `api.requestFailed`, and `api.requestCancelled`.

- [ ] **Step 1: Write failing codec and coordinator routing tests**

Test this command without a new key:

```json
{"type":"api.fetchModels","requestId":"B04E...","configuration":{"baseURL":"https://api.example.com/v1","model":"gpt-a","sourceLanguage":"auto","targetLanguage":"zh-cn","timeoutSeconds":30}}
```

Test a connection command with `apiKeyInput: "new-secret"`, and assert encoded native events never contain that secret. In coordinator tests, use a `FakeConfigurationService` to capture configuration, verify absence means stored key, verify a new key is used and persisted, and verify stale service callbacks do not emit after cancellation.

- [ ] **Step 2: Run bridge tests and verify RED**

Run:

```bash
cd Web && npm test -- --run src/bridge/__tests__/nativeBridge.test.ts
swift run LightSelectCoreContractTests api-bridge
```

Expected: commands/events are rejected because the cases and validators do not exist.

- [ ] **Step 3: Add exact Swift and TypeScript command/event cases**

Use these Swift cases:

```swift
case fetchModels(requestID: String, configuration: APISettings, apiKeyInput: String?)
case testConnection(requestID: String, configuration: APISettings, apiKeyInput: String?)
case cancelAPIRequest(requestID: String)

case modelsLoaded(requestID: String, models: [String], latencyMilliseconds: Int)
case connectionSucceeded(requestID: String, latencyMilliseconds: Int)
case apiRequestFailed(requestID: String, operation: APIConfigurationOperation, code: String)
case apiRequestCancelled(requestID: String)
```

Mirror each field in TypeScript. Validators require a UUID-shaped non-empty request string, a valid `APISettings` object, string arrays for models, finite non-negative latency, operation `models | connection`, and stable error-code strings.

- [ ] **Step 4: Route operations and cancellation in AppCoordinator**

Inject `OpenAIConfigurationServing` into `AppCoordinator`. Resolve credentials as:

```swift
let key = apiKeyInput?.trimmingCharacters(in: .whitespacesAndNewlines)
let resolvedKey = (key?.isEmpty == false ? key : nil) ?? settingsStore.apiKey ?? ""
```

Reject `SettingsStore.maskedAPIKey`, persist a genuine `apiKeyInput` before starting the request, and build `APIConfiguration` from the draft `APISettings`. Convert the web request ID to `UUID`; invalid IDs emit `configuration` failure.

Send service completions only when the request remains active. `cancelAPIRequest` cancels and emits cancelled once. `terminate()` and a new `settingsWindowDidClose()` method cancel every active configuration request.

Add `SettingsWindowController.onClose` and invoke it from `windowWillClose`; wire it in `AppDelegate` to `coordinator.settingsWindowDidClose()`.

- [ ] **Step 5: Run focused bridge and coordinator tests and verify GREEN**

Run:

```bash
cd Web && npm test -- --run src/bridge/__tests__/nativeBridge.test.ts
swift run LightSelectCoreContractTests api-bridge
find Sources Tests -name '*.swift' -print0 | xargs -0 -n1 swiftc -parse
```

Expected: all command/event round trips, credential selection, cancellation, stale-event, and secret non-disclosure contracts pass.

- [ ] **Step 6: Commit native/web API bridging**

```bash
git add Sources/LightSelectCore/Bridge/SelectionWebMessage.swift Sources/LightSelectCore/App/AppCoordinator.swift Sources/LightSelectCore/App/AppDelegate.swift Sources/LightSelectCore/Windows/SettingsWindowController.swift Tests/LightSelectCoreTests/SelectionWebMessageTests.swift Tests/LightSelectCoreTests/AppCoordinatorTests.swift Tests/LightSelectCoreContractTests/main.swift Web/src/bridge/types.ts Web/src/bridge/__tests__/nativeBridge.test.ts
git commit -m "feat: bridge API settings operations"
```

---

### Task 5: Localize the Complete Application

**Files:**
- Create: `Sources/LightSelectCore/App/AppLocalization.swift`
- Modify: `Sources/LightSelectCore/App/AppDelegate.swift`
- Modify: `Sources/LightSelectCore/Windows/SettingsWindowController.swift`
- Modify: `Tests/LightSelectCoreContractTests/main.swift`
- Modify: `Web/src/adapters/i18n.ts`
- Modify: `Web/src/action/entryPoint.tsx`
- Modify: `Web/src/toolbar/entryPoint.tsx`
- Modify: `Web/src/settings/entryPoint.tsx`
- Modify: `Web/src/action/__tests__/actionWindow.test.tsx`
- Modify: `Web/src/toolbar/__tests__/toolbar.test.tsx`
- Modify: `Web/src/settings/__tests__/selectionSettings.test.tsx`

**Interfaces:**
- Consumes: `InterfaceLanguage` preference and confirmed preference broadcasts.
- Produces: `AppLocalization.strings(for:)`, complete i18next catalogs, and runtime language synchronization in every web entry.

- [ ] **Step 1: Write failing native and web language-switch tests**

Native contract assertions:

```swift
try require(AppLocalization.strings(for: .zhCN).settingsTitle == "LightSelect 设置", "Chinese title")
try require(AppLocalization.strings(for: .enUS).settingsTitle == "LightSelect Settings", "English title")
try require(AppLocalization.strings(for: .enUS).quit == "Quit LightSelect", "English quit menu")
```

In Vitest, bootstrap with `zh-CN`, render toolbar/action/settings, then apply `.preferences.changed(interfaceLanguage: 'en-US')`. Assert built-in UI labels become English while a custom action named `提取术语` remains exactly `提取术语`.

- [ ] **Step 2: Run localization tests and verify RED**

Run:

```bash
cd Web && npm test -- --run src/toolbar/__tests__/toolbar.test.tsx src/action/__tests__/actionWindow.test.tsx src/settings/__tests__/selectionSettings.test.tsx
swift run LightSelectCoreContractTests localization
```

Expected: missing resource keys and native localization types cause failures.

- [ ] **Step 3: Build complete i18next catalogs and runtime synchronization**

Move every first-party visible string into `resources['zh-CN'].translation` and `resources['en-US'].translation`. Include settings navigation/controls/dialogs, action-window statuses/errors, toolbar tooltips, save phases, API statuses, permissions, source, and About copy.

Export:

```ts
export const applyInterfaceLanguage = async (language: InterfaceLanguage): Promise<void> => {
  document.documentElement.lang = language
  await i18n.changeLanguage(language)
}
```

Subscribe once to `bootstrap` and confirmed `preferences.changed` events and call `applyInterfaceLanguage` only for `interfaceLanguage`. Keep all entry points importing `i18n.ts` before rendering.

- [ ] **Step 4: Implement native string tables and immediate refresh**

Define a `NativeStrings` value containing every status-menu title, settings title, API alert title retained in native code, Accessibility label, source label, and quit label. `AppLocalization.strings(for:)` returns an exhaustive literal for `.zhCN` and `.enUS`.

Refactor status-menu construction into `rebuildStatusMenu(language:)`. In `coordinator.onSettingsChanged`, update the enabled checkmark, rebuild titles when language changes, and call `settingsWindow.setLanguage(language)` to update an open window immediately.

- [ ] **Step 5: Run localization suites and verify GREEN**

Run:

```bash
cd Web && npm test -- --run src/toolbar/__tests__/toolbar.test.tsx src/action/__tests__/actionWindow.test.tsx src/settings/__tests__/selectionSettings.test.tsx
swift run LightSelectCoreContractTests localization
find Sources Tests -name '*.swift' -print0 | xargs -0 -n1 swiftc -parse
```

Expected: live language switches update built-in labels in all four surfaces and preserve user strings.

- [ ] **Step 6: Commit application localization**

```bash
git add Sources/LightSelectCore/App/AppLocalization.swift Sources/LightSelectCore/App/AppDelegate.swift Sources/LightSelectCore/Windows/SettingsWindowController.swift Tests/LightSelectCoreContractTests/main.swift Web/src/adapters/i18n.ts Web/src/action/entryPoint.tsx Web/src/toolbar/entryPoint.tsx Web/src/settings/entryPoint.tsx Web/src/action/__tests__/actionWindow.test.tsx Web/src/toolbar/__tests__/toolbar.test.tsx Web/src/settings/__tests__/selectionSettings.test.tsx
git commit -m "feat: localize LightSelect interface"
```

---

### Task 6: Rebuild the Settings Window as a Cherry-Style Settings Center

**Files:**
- Create: `Web/src/settings/SettingsSidebar.tsx`
- Create: `Web/src/settings/SettingsPageHeader.tsx`
- Create: `Web/src/settings/GeneralSettingsSection.tsx`
- Create: `Web/src/settings/AppFilterSettingsSection.tsx`
- Create: `Web/src/settings/AboutSettingsSection.tsx`
- Modify: `Web/src/vendor/cherry/pages/settings/SelectionAssistantSettings/SelectionAssistantSettings.tsx`
- Modify: `Web/src/styles/settings.css`
- Modify: `Web/src/settings/__tests__/selectionSettings.test.tsx`
- Modify: `Sources/LightSelectCore/Windows/SettingsWindowController.swift`

**Interfaces:**
- Consumes: localized strings, `preferenceStore`, correlated save status, and existing action/filter dialogs.
- Produces: settings destinations `general | actions | api | filter | about` and responsive navigation.

- [ ] **Step 1: Write failing structure, navigation, save-state, and responsive-contract tests**

Assert the default render contains a navigation landmark with five localized destinations and only the General page visible. Click API and assert the API page title and API form become visible. Click Actions and confirm the existing action list still works. Apply a saving/saved/failed store event and assert the page header displays the matching localized state.

Add stable selectors:

```tsx
<aside data-ui="settings.sidebar" />
<nav aria-label={t('settings.navigation')} />
<section data-ui={`settings.page.${activePage}`} />
<span data-ui="settings.save-status" />
```

Assert the stylesheet contains a `184px minmax(0, 1fr)` desktop grid and a media query that switches to one column at 700px.

- [ ] **Step 2: Run settings tests and verify RED**

Run:

```bash
cd Web && npm test -- --run src/settings/__tests__/selectionSettings.test.tsx
```

Expected: sidebar destinations, page selection, and save-status UI are absent.

- [ ] **Step 3: Implement focused settings components**

`SettingsSidebar` receives `activePage`, `onSelect`, `language`, and `onLanguageChange`. Use Lucide `Settings2`, `ListChecks`, `ServerCog`, `Shield`, and `Info` icons. Language is a two-option segmented control labeled `中文` and `English`.

`SettingsPageHeader` consumes `preferenceStore.getSaveSnapshot()` through `useSyncExternalStore` and renders an icon plus localized phase without changing header height.

Move existing general/result controls into `GeneralSettingsSection`, filter controls/modal into `AppFilterSettingsSection`, and permissions/source/version content into `AboutSettingsSection`. Keep `SelectionActionsList` and its Cherry-derived dialogs unchanged except for localized props/keys.

`SelectionAssistantSettings` owns only active-page state and composition:

```tsx
const [activePage, setActivePage] = useState<SettingsPage>('general')
return (
  <main className="lightselect-settings-shell">
    <SettingsSidebar activePage={activePage} onSelect={setActivePage} ... />
    <div className="lightselect-settings-content">
      <SettingsPageHeader page={activePage} />
      {renderPage(activePage)}
    </div>
  </main>
)
```

- [ ] **Step 4: Implement the restrained responsive visual system**

Set the native default window to 900 by 700 points with a 720 by 560 minimum. In CSS, use a fixed 184px sidebar, full-height content scroll region, 20px page titles, 14px labels, 12px supporting text, 48px stable rows, 6px controls, and at most 8px framed tool radius. Use existing `--background`, `--card`, `--border`, `--accent`, `--primary`, and foreground tokens.

At `max-width: 700px`, change the shell to one column, render sidebar destinations as a horizontally scrollable stable-height strip, keep the language control visible, and prevent labels or buttons from overlapping.

- [ ] **Step 5: Run settings and full web tests and verify GREEN**

Run:

```bash
cd Web && npm run typecheck
cd Web && npm test -- --run src/settings/__tests__/selectionSettings.test.tsx
cd Web && npm test -- --run
```

Expected: settings navigation and existing action/filter behavior pass; the entire web suite remains green.

- [ ] **Step 6: Commit the settings-center shell**

```bash
git add Web/src/settings/SettingsSidebar.tsx Web/src/settings/SettingsPageHeader.tsx Web/src/settings/GeneralSettingsSection.tsx Web/src/settings/AppFilterSettingsSection.tsx Web/src/settings/AboutSettingsSection.tsx Web/src/vendor/cherry/pages/settings/SelectionAssistantSettings/SelectionAssistantSettings.tsx Web/src/styles/settings.css Web/src/settings/__tests__/selectionSettings.test.tsx Sources/LightSelectCore/Windows/SettingsWindowController.swift
git commit -m "feat: redesign settings center"
```

---

### Task 7: Build Inline API Testing and Editable Model Discovery UI

**Files:**
- Create: `Web/src/settings/ModelCombobox.tsx`
- Create: `Web/src/settings/apiRequestStore.ts`
- Create: `Web/src/settings/__tests__/apiSettings.test.tsx`
- Modify: `Web/src/settings/APISettingsSection.tsx`
- Modify: `Web/src/styles/settings.css`
- Modify: `Web/src/bridge/types.ts`

**Interfaces:**
- Consumes: Task 4 API commands/events and Task 5 localization resources.
- Produces: editable `ModelCombobox`, inline request phases, key reveal/conceal, model refresh, and connection-test actions using current drafts.

- [ ] **Step 1: Write failing model, credential, request-state, and stale-event tests**

Cover these behaviors with Testing Library:

```ts
fireEvent.change(screen.getByLabelText('Base URL'), { target: { value: 'https://draft.example/v1' } })
fireEvent.change(screen.getByLabelText('API Key'), { target: { value: 'draft-secret' } })
fireEvent.click(screen.getByRole('button', { name: '获取模型列表' }))
expect(send).toHaveBeenCalledWith(expect.objectContaining({
  type: 'api.fetchModels',
  configuration: expect.objectContaining({ baseURL: 'https://draft.example/v1' }),
  apiKeyInput: 'draft-secret'
}))
```

Assert masked `••••••••` produces no `apiKeyInput`. Emit `api.modelsLoaded` with the active request ID and assert sorted options appear while a manually typed model remains selected. Emit an older failure and assert it is ignored. Test empty list, authentication, forbidden model list, timeout, connection success with latency, retry, loading disablement, and localized status text.

- [ ] **Step 2: Run API UI tests and verify RED**

Run:

```bash
cd Web && npm test -- --run src/settings/__tests__/apiSettings.test.tsx
```

Expected: request store, model combobox, buttons, and inline statuses do not exist.

- [ ] **Step 3: Implement request-correlated API operation state**

Create `apiRequestStore.ts` with separate `models` and `connection` states:

```ts
export type APIRequestState =
  | { phase: 'idle' }
  | { phase: 'loading'; requestId: string }
  | { phase: 'models'; requestId: string; models: string[]; latencyMilliseconds: number }
  | { phase: 'success'; requestId: string; latencyMilliseconds: number }
  | { phase: 'error'; requestId: string; code: APIErrorCode }
```

`begin(operation)` cancels the existing request for that operation, sends `api.cancelRequest`, creates a new UUID, and marks loading. Native events update state only when request IDs match. Bootstrap resets both operations.

- [ ] **Step 4: Implement the editable model combobox and refined API page**

`ModelCombobox` renders an input with `role="combobox"`, `aria-controls`, and `aria-expanded`; a refresh icon button using `RefreshCw`; and a positioned `role="listbox"` containing model options. Clicking an option updates the draft. Escape closes the list; ArrowUp/ArrowDown moves the active option; Enter selects it. Manual input is always accepted.

Rewrite `APISettingsSection` to:

- Keep one local draft synchronized only after confirmed external changes.
- Show/conceal API key with `Eye`/`EyeOff` icon buttons and tooltips.
- Commit current API settings before a model/test request.
- Send a non-masked new key ephemerally and persist it through `credentials.updateAPIKey` on blur or request action.
- Put timeout in a native `<details>` disclosure.
- Render model and connection feedback inline with `CheckCircle2`, `AlertCircle`, or a spinning `LoaderCircle`.
- Disable only the operation currently loading; do not disable manual fields.

- [ ] **Step 5: Run focused, full web, and type tests and verify GREEN**

Run:

```bash
cd Web && npm run typecheck
cd Web && npm test -- --run src/settings/__tests__/apiSettings.test.tsx src/settings/__tests__/selectionSettings.test.tsx src/bridge/__tests__/nativeBridge.test.ts
cd Web && npm test -- --run
```

Expected: current-draft commands, model selection/manual entry, all status/error states, localization, and stale-event rejection pass.

- [ ] **Step 6: Commit the API settings experience**

```bash
git add Web/src/settings/ModelCombobox.tsx Web/src/settings/apiRequestStore.ts Web/src/settings/__tests__/apiSettings.test.tsx Web/src/settings/APISettingsSection.tsx Web/src/styles/settings.css Web/src/bridge/types.ts
git commit -m "feat: add inline API setup tools"
```

---

### Task 8: Restore Standard Editing Commands and Add Control-V Fallback

**Files:**
- Create: `Sources/LightSelectCore/App/ApplicationMenuFactory.swift`
- Modify: `Sources/LightSelectCore/App/AppDelegate.swift`
- Modify: `Sources/LightSelectCore/Windows/SettingsWindowController.swift`
- Create: `Tests/LightSelectCoreTests/ApplicationMenuFactoryTests.swift`
- Modify: `Tests/LightSelectCoreTests/UIFixtureTests.swift`
- Modify: `Tests/LightSelectCoreContractTests/main.swift`

**Interfaces:**
- Consumes: native strings from Task 5.
- Produces: `ApplicationMenuFactory.make(language:)` and `SettingsWindowController.shouldForwardControlPaste(...)`.

- [ ] **Step 1: Write failing menu and key-routing contracts**

Assert the generated Edit menu contains these actions and equivalents:

```swift
[(#selector(UndoManager.undo), "z", NSEvent.ModifierFlags.command),
 (#selector(UndoManager.redo), "Z", [.command, .shift]),
 (#selector(NSText.cut(_:)), "x", .command),
 (#selector(NSText.copy(_:)), "c", .command),
 (#selector(NSText.paste(_:)), "v", .command),
 (#selector(NSText.selectAll(_:)), "a", .command)]
```

Add a pure routing test that returns true only for lowercase/uppercase `v` with exactly Control while the settings window is key and the first responder descends from the settings web view. Command-V must return false because AppKit's main menu handles it.

- [ ] **Step 2: Run editing contracts and verify RED**

Run:

```bash
swift run LightSelectCoreContractTests editing-menu
```

Expected: menu factory and Control-V routing helper do not exist.

- [ ] **Step 3: Implement the application and Edit menus**

`ApplicationMenuFactory.make(language:)` returns a root `NSMenu` with an application submenu and an Edit submenu. Standard editing items target `nil`, allowing AppKit to route selectors to the current first responder. Use localized menu titles but standard key equivalents. Install it with `NSApp.mainMenu = ...` at launch and rebuild it when interface language changes.

- [ ] **Step 4: Implement window-scoped Control-V forwarding**

Install an `NSEvent.addLocalMonitorForEvents(matching: .keyDown)` monitor while the settings controller exists. On a qualifying event:

```swift
if Self.shouldForwardControlPaste(event, window: window, webView: host.webView),
   NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: window) {
    return nil
}
return event
```

Remove the monitor in `invalidate` and `deinit`. Confirm the check rejects other windows, other keys, Command-V, mixed modifiers, and a responder outside the settings web view.

- [ ] **Step 5: Run contracts and parse checks and verify GREEN**

Run:

```bash
swift run LightSelectCoreContractTests editing-menu
find Sources Tests -name '*.swift' -print0 | xargs -0 -n1 swiftc -parse
```

Expected: Edit menu structure and scoped Control-V routing contracts pass; all Swift sources parse.

- [ ] **Step 6: Commit keyboard editing support**

```bash
git add Sources/LightSelectCore/App/ApplicationMenuFactory.swift Sources/LightSelectCore/App/AppDelegate.swift Sources/LightSelectCore/Windows/SettingsWindowController.swift Tests/LightSelectCoreTests/ApplicationMenuFactoryTests.swift Tests/LightSelectCoreTests/UIFixtureTests.swift Tests/LightSelectCoreContractTests/main.swift
git commit -m "fix: restore settings keyboard editing"
```

---

### Task 9: Add Deterministic Visual Fixtures, Build, Install, and Audit Every Requirement

**Files:**
- Modify: `Sources/LightSelectCore/App/UIFixtureRequest.swift`
- Modify: `Sources/LightSelectCore/App/UIFixtureRenderer.swift`
- Modify: `Tests/LightSelectCoreTests/UIFixtureTests.swift`
- Modify: `scripts/capture-ui.sh`
- Create: `scripts/mock-openai-server.mjs`
- Modify: `README.md`
- Generate: `artifacts/ui/settings-zh-light.png`
- Generate: `artifacts/ui/settings-zh-dark.png`
- Generate: `artifacts/ui/settings-en-light.png`
- Generate: `artifacts/ui/settings-en-dark.png`
- Generate: `artifacts/ui/settings-zh-narrow.png`
- Generate: `artifacts/ui/settings-en-narrow.png`

**Interfaces:**
- Consumes: all previous tasks.
- Produces: deterministic `--ui-test settings --language zh-CN|en-US --width <points> --height <points>` capture support and final release evidence.

- [ ] **Step 1: Write failing fixture argument and deterministic-state tests**

Add parser cases for:

```text
--ui-test settings --appearance dark --language en-US --width 900 --height 700 --output /tmp/settings.png
--ui-test settings --appearance light --language zh-CN --width 520 --height 760 --output /tmp/settings.png
```

Assert unsupported languages and dimensions below the fixture minimum fail parsing. Fixture bootstrap must include the selected interface language, a masked saved key state, fixed models, and deterministic saved/API-success statuses so screenshots do not depend on a network.

- [ ] **Step 2: Run fixture contract and verify RED**

Run:

```bash
swift run LightSelectCoreContractTests ui-fixture-settings
```

Expected: parser rejects `--language`, `--width`, and `--height` because they are not implemented.

- [ ] **Step 3: Implement fixture options and six screenshot captures**

Extend `UIFixtureRequest` with `language`, `width`, and `height`. Use default 900 by 700 for settings and retain existing defaults for toolbar/action. In `UIFixtureRenderer`, apply schema-3 preferences before loading the page and send deterministic API events after bootstrap.

Update `capture-ui.sh` to build once and capture the six named settings images plus existing toolbar/action fixtures. Do not overwrite unrelated artifact files.

Create `scripts/mock-openai-server.mjs` using Node's built-in `http` module. Listen only on `127.0.0.1:18431`. Support base paths `/success/v1`, `/auth/v1`, `/forbidden/v1`, `/rate/v1`, `/server/v1`, `/malformed/v1`, `/empty/v1`, and `/slow/v1`. Return these deterministic behaviors for both `/models` and `/chat/completions`: success 200 JSON, 401, 403, 429, 500, malformed JSON, an empty models list, and a response delayed beyond the configured timeout. The success models payload contains duplicate unsorted IDs; the success completion payload contains a non-empty `choices` array. Log only method/path/status, never Authorization headers.

- [ ] **Step 4: Run the full automated verification matrix**

Run:

```bash
cd Web && npm run typecheck
cd Web && npm test -- --run
cd Web && npm audit
swift run LightSelectCoreContractTests all
find Sources Tests -name '*.swift' -print0 | xargs -0 -n1 swiftc -parse
bash scripts/verify-provenance.sh
.build/release/LightSelect --self-test
bash scripts/capture-ui.sh
git diff --check
```

Expected: TypeScript passes; all Vitest files pass; audit reports zero vulnerabilities; every native contract prints `CONTRACT_OK`; Swift parse, provenance, self-test, capture, and diff checks exit 0.

- [ ] **Step 5: Inspect every screenshot and verify layout invariants**

Open each PNG with the local image viewer. Verify:

- Nonblank content and correct selected destination.
- No clipped Chinese or English labels at 900px or 520px width.
- Sidebar is 184px at desktop width and navigation becomes a stable horizontal strip when narrow.
- API key, model input, refresh button, test button, and status line do not overlap.
- Loading/success/error placeholders reserve stable height.
- Light/dark contrast is readable and theme tokens are applied.
- No nested cards, gradients, decorative blobs, oversized headings, or viewport-dependent font scaling.

Record any defect as a failing CSS/component test before fixing it, then rerun Step 4 and re-inspect the affected images.

- [ ] **Step 6: Build and atomically install the release**

Run:

```bash
bash scripts/install-update.sh
bash scripts/verify-release.sh "$HOME/Applications/LightSelect.app"
```

Gracefully terminate the old installed process, launch `$HOME/Applications/LightSelect.app`, and verify a new PID plus a fresh `launched trusted=true` line in `$HOME/Library/Logs/LightSelect.log`.

- [ ] **Step 7: Verify installed behavior without using the user's API quota**

Using the installed settings window and a local mock OpenAI-compatible endpoint, verify:

- Switch Chinese/English and confirm settings, native title, status menu, toolbar fixture, and action fixture update without restart.
- Paste distinct sentinel text using Command-V and Control-V in Base URL, API key, model, and a custom prompt; verify copy, cut, select-all, undo, and redo.
- Fetch models and confirm duplicate-free sorted suggestions plus manual model entry.
- Test connection and confirm inline success latency; force 401, 403, 429, 500, timeout, malformed JSON, and empty models and confirm localized inline states.
- Close settings during a request and confirm cancellation with no stale success.
- Restart and confirm language, API settings, actions, and credential presence persist while no key appears in settings JSON or logs.

Do not send a request to the user's configured external provider during this step.

Start the mock with:

```bash
node scripts/mock-openai-server.mjs
```

Use `http://127.0.0.1:18431/success/v1` for success and substitute each documented base path for error states. Stop the server after installed-app verification.

- [ ] **Step 8: Update documentation and perform the completion audit**

Update `README.md` with the settings-center navigation, language switch, model discovery, connection test, keyboard shortcuts, and the statement that model discovery depends on provider `/models` compatibility.

Audit all nine acceptance criteria in the spec against source, automated output, screenshots, installed process/log state, persisted schema, and local mock-provider behavior. State the remaining real-provider boundary explicitly if the user has not pressed Test Connection with their provider.

- [ ] **Step 9: Commit verified release changes**

```bash
git add Sources/LightSelectCore/App/UIFixtureRequest.swift Sources/LightSelectCore/App/UIFixtureRenderer.swift Tests/LightSelectCoreTests/UIFixtureTests.swift scripts/capture-ui.sh scripts/mock-openai-server.mjs README.md artifacts/ui/settings-zh-light.png artifacts/ui/settings-zh-dark.png artifacts/ui/settings-en-light.png artifacts/ui/settings-en-dark.png artifacts/ui/settings-zh-narrow.png artifacts/ui/settings-en-narrow.png
git commit -m "release: ship upgraded settings center"
```

- [ ] **Step 10: Verify final repository and identity state**

Run:

```bash
git status --short --branch
git log -1 --format='%H%n%an <%ae>%n%cn <%ce>%n%s'
bash scripts/verify-release.sh "$HOME/Applications/LightSelect.app"
```

Expected: feature worktree is clean; Author and Committer are `chaochaoweb3 <49186707+chaochaoweb3@users.noreply.github.com>`; installed release verification succeeds. Do not push.
