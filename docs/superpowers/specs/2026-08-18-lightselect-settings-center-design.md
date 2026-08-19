# LightSelect Settings Center Upgrade Design

## Summary

LightSelect's current settings window is a single scrolling page with limited visual hierarchy. API testing is available only from the status-item menu, model names must be entered manually, the interface is mostly hard-coded Chinese, and keyboard paste is unreliable in the `WKWebView` settings fields.

This upgrade turns the existing window into a polished Cherry-style settings center while preserving LightSelect's lightweight Swift/AppKit plus system `WKWebView` architecture. It adds application-wide Chinese and English localization, inline API connection testing, one-click model discovery, explicit save and request states, and standard macOS editing commands including keyboard paste.

## Goals

1. Replace the long undifferentiated settings page with a clear, work-focused settings center.
2. Let users switch the complete application between Simplified Chinese and English without restarting.
3. Put API testing directly beside the API configuration fields and report results in place.
4. Fetch OpenAI-compatible model identifiers from the configured provider and offer them in an editable selector.
5. Make `Command-V`, `Command-C`, `Command-X`, and `Command-A` work in settings fields, with `Control-V` accepted as a paste fallback while a settings text field is focused.
6. Keep API keys local, avoid logging secrets, and preserve existing settings and credentials during migration.
7. Retain Cherry Studio's visual language and avoid bundling Electron or Chromium.

## Non-Goals

- Adding provider-specific account management, billing, pricing, or usage dashboards.
- Downloading model metadata beyond identifiers returned by an OpenAI-compatible `/models` endpoint.
- Replacing the existing OpenAI-compatible streaming implementation.
- Redesigning the selection toolbar or action window beyond localization support.
- Syncing settings or credentials to a remote service.

## User Experience

### Window Structure

The settings window keeps a restrained desktop layout at a default size of approximately 900 by 700 points:

- A 184-point sidebar contains `General`, `Actions`, `API`, `App Filter`, and `About` destinations with Lucide icons.
- The content region uses a compact title, optional supporting text, and full-width setting groups separated by subtle borders.
- The top of the sidebar contains the LightSelect mark and product name.
- A `Chinese | English` segmented control appears at the bottom of the sidebar and remains visible while content scrolls.
- On narrow windows, the sidebar becomes a horizontal destination strip and the content uses a single column.

The page must remain an operational settings surface rather than a card-heavy landing page. Individual API status or model-selection tools may use one shallow bordered group, but page sections are not nested cards.

### General

General contains the master enable switch, trigger mode segmented control, compact mode, result-window behavior, and opacity. Settings save immediately, with a small global `Saving`, `Saved`, or `Save failed` indicator in the content header.

### Actions

The existing Cherry-derived action list and editing dialogs remain functionally intact. Labels, dialogs, action controls, and built-in action names use the selected application language. User-created action names and prompts are never translated.

### API

The API page is organized in this order:

1. Base URL.
2. API key with reveal/conceal control and stored-key state.
3. Editable model combobox with a refresh icon button.
4. Source language and target language selectors.
5. Timeout control under an `Advanced` disclosure.
6. A primary `Test Connection` button followed by an inline result area.

The refresh icon is disabled while a model request is active. The connection button is disabled while a connection test is active. Both operations expose loading, success, and failure states without modal alerts. Tooltips name icon-only controls.

The model selector remains editable because some OpenAI-compatible providers omit models, reject `/models`, or allow aliases not returned by the endpoint. A successful refresh replaces the suggestion list but does not silently replace a non-empty selected model. If the current model appears in the response, it remains selected.

### API Result Language

Messages are localized and intentionally specific:

- Missing or malformed configuration.
- Authentication failed.
- Provider rejected model-list access.
- Rate limited.
- Server error.
- Timeout or connection failure.
- Invalid provider response.
- Connection succeeded, including a short latency value.
- Models loaded, including the count.

Raw server bodies and API keys are never displayed. A model-fetch failure does not imply that chat completions are unavailable, and the interface states that distinction when appropriate.

### App Filter and About

App Filter retains the existing default, allow-list, and block-list behavior with clearer explanatory copy. About contains version, source-code link, license summary, and Accessibility permission status/actions. It does not contain marketing content.

## Localization

Add an `interfaceLanguage` preference with values `zh-CN` and `en-US`. Existing users default to `zh-CN` to preserve current behavior. The preference is included in the existing settings JSON and bridge bootstrap payload. This changes the settings schema version from 2 to 3; decoding all existing fields remains backward compatible and the first successful save writes schema version 3.

All first-party strings move into the existing `i18next` resources:

- Settings center navigation, headings, labels, descriptions, buttons, dialogs, validation, and statuses.
- Selection toolbar built-in action names and tooltips.
- Action window controls, loading states, and error messages.
- Status-item menu titles and native alerts.
- Settings window title.

The web layer calls `i18n.changeLanguage` when the preference changes and updates `document.documentElement.lang`. Swift owns native-menu localization through a small typed localization table keyed by the same persisted preference. Switching language rebuilds menu titles and updates open window titles immediately without restarting.

Provider-returned model identifiers, user-created content, URLs, code, and exact API values are never localized.

## Native and Web Architecture

### Settings Data

`LightSelectSettings` gains:

```swift
public enum InterfaceLanguage: String, Codable, Sendable {
    case zhCN = "zh-CN"
    case enUS = "en-US"
}

public var interfaceLanguage: InterfaceLanguage
```

Decoding uses `decodeIfPresent` for `interfaceLanguage` so existing schema-version-2 settings migrate safely. The web `SelectionPreferences` type and validators add the same field. Existing settings keys remain unchanged.

Preference updates gain a request identifier:

```text
preferences.update(requestId, key, value)
preferences.saved(requestId, key, value)
preferences.saveFailed(requestId, key)
```

The web shows `Saving` after sending an update, `Saved` only after the matching native acknowledgement, and `Save failed` after a matching failure. A stale acknowledgement cannot overwrite a newer pending state. Native code broadcasts the confirmed value only after persistence succeeds. Existing toolbar and action-window consumers continue to receive confirmed preference changes.

### API Service

Introduce a focused `OpenAIConfigurationService` rather than adding unrelated responsibilities to the streaming client. It receives an ephemeral configuration value and exposes:

```swift
func fetchModels(configuration: APIConfiguration, completion: @escaping (Result<[String], APIConfigurationError>) -> Void)
func testConnection(configuration: APIConfiguration, completion: @escaping (Result<ConnectionTestResult, APIConfigurationError>) -> Void)
```

Both operations use an ephemeral `URLSession`, bounded timeouts, and cancellable tasks. The service normalizes these common base URL forms:

- `https://host/v1`
- `https://host/v1/`
- `https://host/v1/chat/completions`

Model discovery sends `GET` to the corresponding `/models` endpoint with bearer authentication. It parses `data[].id`, removes empty identifiers and duplicates, and sorts identifiers using localized standard ordering.

Connection testing sends the smallest practical non-streaming chat-completions request using the selected model and asks for a one-token-equivalent `OK` response where provider semantics allow. Any 2xx response with a structurally valid completion is success; response text is not shown or required to equal `OK`. The result includes measured round-trip latency.

### Bridge Protocol

The web sends explicit request identifiers so stale responses cannot overwrite a newer operation:

```text
api.fetchModels(requestId, configuration, apiKeyInput)
api.testConnection(requestId, configuration, apiKeyInput)
api.cancelRequest(requestId)
```

`apiKeyInput` is either a newly entered value or absent, meaning the native layer must use the Keychain-backed stored key. The masked placeholder is never sent as a credential.

Native responses are:

```text
api.modelsLoaded(requestId, models, latencyMilliseconds)
api.connectionSucceeded(requestId, latencyMilliseconds)
api.requestFailed(requestId, operation, code)
api.requestCancelled(requestId)
```

The native layer validates URLs and credentials, maps errors to stable codes, and sends no raw provider response text to the web UI. Closing the settings window cancels outstanding configuration requests.

### Credential Save Semantics

API fields maintain a local draft. Clicking `Fetch Models` or `Test Connection` uses that draft immediately, even if a field still has focus. A newly typed API key is sent ephemerally for the request and saved only through the existing credential update command when the user explicitly leaves the field or confirms the request action. The interface marks whether the key is stored.

No API key is included in logs, error descriptions, persisted JSON, or web events sent back from native code.

## Keyboard Editing

The current accessory application has a status-item menu but no standard application `Edit` menu. AppKit therefore does not consistently route standard key equivalents to the `WKWebView` responder chain, even though WebKit's context menu can invoke paste.

Add a normal application main menu containing an `Edit` submenu with `Undo`, `Redo`, `Cut`, `Copy`, `Paste`, and `Select All` actions targeting the first responder. This restores standard `Command-Z`, `Shift-Command-Z`, `Command-X`, `Command-C`, `Command-V`, and `Command-A` behavior.

`SettingsWindowController` also installs a window-local key monitor. When the settings web view is first responder and the user presses `Control-V`, it forwards `paste:` through the responder chain. The fallback is scoped to the settings window and does not alter system-wide shortcuts or selection monitoring.

## Error Handling and State Consistency

- A new API request cancels the previous request of the same operation.
- The web ignores responses whose request identifier is no longer active.
- Closing the settings window cancels pending requests and clears loading states on the next bootstrap.
- A failed settings save restores the last confirmed preference snapshot and displays `Save failed`.
- Model and connection errors use stable codes rather than provider text.
- A model list response may be empty; this is a valid response rendered as `No models returned`, while manual model entry remains available.
- Network operations never block the main thread.

## Visual Style

- Continue using Cherry Studio semantic tokens, Lucide icons, and existing light/dark themes.
- Use 6-pixel or smaller control radii and an 8-pixel maximum for framed tool groups.
- Keep typography compact: 20-pixel page titles, 14-pixel row labels, and 12-pixel descriptions/statuses.
- Use neutral surfaces with the existing primary color reserved for selection, focus, toggles, and primary actions.
- Use stable row heights and grid tracks so loading labels, validation messages, and translated English strings do not shift the layout unexpectedly.
- Do not use gradients, decorative shapes, marketing copy, oversized headings, or nested cards.

## Testing

### Web Tests

- Language switch updates all visible settings navigation and controls and persists `interfaceLanguage`.
- Built-in action labels change language while custom action content remains unchanged.
- API draft values are sent to model discovery and connection testing before blur.
- A masked API key is never sent as a literal credential.
- Model loading, empty, success, failure, cancellation, stale-response, and editable-manual-model states render correctly.
- API connection loading, success, timeout, authentication, and retry states render in place.
- Sidebar navigation and narrow responsive navigation select and reveal the correct page.

### Swift Tests

- Existing settings decode without `interfaceLanguage` and default to `zh-CN`.
- Preference updates persist and broadcast the selected language.
- Bridge commands and events round-trip for model discovery, connection testing, cancellation, and localized status data.
- Base URL normalization produces the correct `/models` and `/chat/completions` endpoints.
- Mock URL protocol tests cover successful model parsing, duplicate removal, empty lists, malformed payloads, HTTP status mapping, timeouts, and secret non-disclosure.
- Stale/cancelled API requests cannot emit a success event.
- The application menu exposes standard Edit commands and localized status-item titles.
- The `Control-V` fallback only forwards paste while the settings web view is focused.

### Visual and Runtime Verification

- Capture the settings center in Chinese and English, light and dark appearance, at default and narrow window sizes.
- Check screenshots for clipping, overlap, inconsistent spacing, and dynamic-status layout shifts.
- Verify `Command-V`, `Control-V`, copy, cut, select-all, and undo in Base URL, API key, model, and custom prompt fields.
- Verify model discovery against a local mock OpenAI-compatible server without exposing or consuming the user's API key.
- Install the release app and verify signing, bundle metadata, launch status, saved-language restart behavior, and settings migration.
- A real user-configured provider test remains an explicit final acceptance action because it may consume quota and depends on external service behavior.

## Acceptance Criteria

The upgrade is complete only when all of the following are demonstrated:

1. The settings center uses the approved sidebar/content layout and remains usable in light, dark, default, and narrow states.
2. Chinese and English can be switched without restart across the settings window, toolbar, action window, status menu, and native window titles.
3. API connection testing runs from the API page using current draft values and displays an inline localized result.
4. Model discovery runs from the API page, populates an editable model selector, and handles unavailable or empty model endpoints without blocking manual entry.
5. Standard macOS editing shortcuts work in settings fields, and `Control-V` also pastes while a settings text field is focused.
6. Existing user preferences and Keychain credentials survive migration.
7. No credential or raw provider response leaks into logs, persisted settings, UI error text, or tests.
8. Automated web tests, Swift tests or the repository's documented Swift fallback, provenance verification, self-test, release build, and release verification pass.
9. The installed app launches the new build and the remaining real-provider acceptance boundary is reported accurately.
