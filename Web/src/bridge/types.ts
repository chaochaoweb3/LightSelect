export type SelectionTriggerMode = 'selected' | 'ctrlkey' | 'shortcut'
export type SelectionFilterMode = 'default' | 'whitelist' | 'blacklist'
export type AppearanceMode = 'light' | 'dark'
export type InterfaceLanguage = 'zh-CN' | 'en-US'
export type APIConfigurationOperation = 'models' | 'connection'
export type APIErrorCode =
  | 'configuration'
  | 'authentication'
  | 'forbidden'
  | 'rate_limit'
  | 'server'
  | 'timeout'
  | 'connection'
  | 'invalid_response'
  | 'cancelled'

export type SelectionActionItem = {
  id: string
  name: string
  enabled: boolean
  isBuiltIn: boolean
  icon?: string
  prompt?: string
  assistantId?: string
  selectedText?: string
  searchEngine?: string
}

export type APISettings = {
  baseURL: string
  model: string
  sourceLanguage: string
  targetLanguage: string
  timeoutSeconds: number
}

export type SelectionPreferences = {
  interfaceLanguage: InterfaceLanguage
  enabled: boolean
  actionItems: SelectionActionItem[]
  actionWindowOpacity: number
  autoClose: boolean
  autoPin: boolean
  compact: boolean
  filterList: string[]
  filterMode: SelectionFilterMode
  followToolbar: boolean
  rememberWindowSize: boolean
  triggerMode: SelectionTriggerMode
  api: APISettings
}

export type NativeCommand =
  | { type: 'selection.performAction'; actionId: string; selectedText: string }
  | { type: 'selection.determineToolbarSize'; width: number; height: number }
  | { type: 'selection.copySelectedText'; selectedText: string }
  | { type: 'result.copy'; content: string }
  | { type: 'system.openURL'; url: string }
  | { type: 'action.close' }
  | { type: 'action.pin'; pinned: boolean }
  | { type: 'action.setOpacity'; opacity: number }
  | { type: 'action.cancel'; requestId: string }
  | { type: 'action.regenerate'; requestId: string }
  | {
      [Key in keyof SelectionPreferences]: {
        type: 'preferences.update'
        requestId: string
        key: Key
        value: SelectionPreferences[Key]
      }
    }[keyof SelectionPreferences]
  | { type: 'credentials.updateAPIKey'; value: string | null }
  | { type: 'api.fetchModels'; requestId: string; configuration: APISettings; apiKeyInput?: string }
  | { type: 'api.testConnection'; requestId: string; configuration: APISettings; apiKeyInput?: string }
  | { type: 'api.cancelRequest'; requestId: string }
  | { type: 'application.openSettings'; section?: 'selection' | 'api' }
  | { type: 'application.closeSettings' }
  | { type: 'application.openAccessibilitySettings' }
  | { type: 'application.openSource' }

export type NativeEvent =
  | { type: 'bootstrap'; preferences: SelectionPreferences; hasAPIKey: boolean }
  | {
      [Key in keyof SelectionPreferences]: {
        type: 'preferences.changed'
        key: Key
        value: SelectionPreferences[Key]
      }
    }[keyof SelectionPreferences]
  | {
      [Key in keyof SelectionPreferences]: {
        type: 'preferences.saved'
        requestId: string
        key: Key
        value: SelectionPreferences[Key]
      }
    }[keyof SelectionPreferences]
  | { type: 'preferences.saveFailed'; requestId: string; key: keyof SelectionPreferences }
  | { type: 'selection.textSelected'; text: string; isFullscreen?: boolean }
  | { type: 'appearance.changed'; mode: AppearanceMode }
  | { type: 'toolbar.visibilityChanged'; visible: boolean }
  | { type: 'action.start'; requestId: string; action: SelectionActionItem; selectedText: string }
  | { type: 'action.delta'; requestId: string; text: string }
  | { type: 'action.complete'; requestId: string; content: string }
  | { type: 'action.error'; requestId: string; code: string; message: string }
  | { type: 'action.cancelled'; requestId: string }
  | { type: 'api.modelsLoaded'; requestId: string; models: string[]; latencyMilliseconds: number }
  | { type: 'api.connectionSucceeded'; requestId: string; latencyMilliseconds: number }
  | { type: 'api.requestFailed'; requestId: string; operation: APIConfigurationOperation; code: APIErrorCode }
  | { type: 'api.requestCancelled'; requestId: string }

export type NativeEventType = NativeEvent['type']
export type NativeEventOfType<Type extends NativeEventType> = Extract<NativeEvent, { type: Type }>

const selectionPreferenceKeys: ReadonlyArray<keyof SelectionPreferences> = [
  'interfaceLanguage',
  'enabled',
  'actionItems',
  'actionWindowOpacity',
  'autoClose',
  'autoPin',
  'compact',
  'filterList',
  'filterMode',
  'followToolbar',
  'rememberWindowSize',
  'triggerMode',
  'api'
]

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value)

const hasString = (value: Record<string, unknown>, key: string): boolean => typeof value[key] === 'string'
const hasBoolean = (value: Record<string, unknown>, key: string): boolean => typeof value[key] === 'boolean'
const hasNumber = (value: Record<string, unknown>, key: string): boolean =>
  typeof value[key] === 'number' && Number.isFinite(value[key])
const hasRequestID = (value: Record<string, unknown>): boolean =>
  typeof value.requestId === 'string' &&
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(value.requestId)

const apiErrorCodes: ReadonlyArray<APIErrorCode> = [
  'configuration', 'authentication', 'forbidden', 'rate_limit', 'server',
  'timeout', 'connection', 'invalid_response', 'cancelled'
]

export const isSelectionActionItem = (value: unknown): value is SelectionActionItem => {
  if (!isRecord(value)) return false
  if (!hasString(value, 'id') || !hasString(value, 'name')) return false
  if (!hasBoolean(value, 'enabled') || !hasBoolean(value, 'isBuiltIn')) return false

  for (const optionalKey of ['icon', 'prompt', 'assistantId', 'selectedText', 'searchEngine']) {
    if (value[optionalKey] !== undefined && typeof value[optionalKey] !== 'string') return false
  }

  return true
}

export const isSelectionPreferences = (value: unknown): value is SelectionPreferences => {
  if (!isRecord(value)) return false
  if (!['zh-CN', 'en-US'].includes(String(value.interfaceLanguage))) return false
  if (!hasBoolean(value, 'enabled')) return false
  if (!Array.isArray(value.actionItems) || !value.actionItems.every(isSelectionActionItem)) return false
  if (!hasNumber(value, 'actionWindowOpacity')) return false
  if (!hasBoolean(value, 'autoClose') || !hasBoolean(value, 'autoPin') || !hasBoolean(value, 'compact')) return false
  if (!Array.isArray(value.filterList) || !value.filterList.every((item) => typeof item === 'string')) return false
  if (!['default', 'whitelist', 'blacklist'].includes(String(value.filterMode))) return false
  if (!hasBoolean(value, 'followToolbar') || !hasBoolean(value, 'rememberWindowSize')) return false
  if (!['selected', 'ctrlkey', 'shortcut'].includes(String(value.triggerMode))) return false
  if (!isRecord(value.api)) return false
  if (!hasString(value.api, 'baseURL') || !hasString(value.api, 'model')) return false
  if (!hasString(value.api, 'sourceLanguage') || !hasString(value.api, 'targetLanguage')) return false
  if (!hasNumber(value.api, 'timeoutSeconds')) return false
  return true
}

const isPreferenceKey = (value: unknown): value is keyof SelectionPreferences =>
  typeof value === 'string' && selectionPreferenceKeys.includes(value as keyof SelectionPreferences)

const isPreferenceValue = (key: keyof SelectionPreferences, value: unknown): boolean => {
  switch (key) {
    case 'interfaceLanguage':
      return value === 'zh-CN' || value === 'en-US'
    case 'enabled':
    case 'autoClose':
    case 'autoPin':
    case 'compact':
    case 'followToolbar':
    case 'rememberWindowSize':
      return typeof value === 'boolean'
    case 'actionItems':
      return Array.isArray(value) && value.every(isSelectionActionItem)
    case 'actionWindowOpacity':
      return typeof value === 'number' && Number.isFinite(value)
    case 'filterList':
      return Array.isArray(value) && value.every((item) => typeof item === 'string')
    case 'filterMode':
      return typeof value === 'string' && ['default', 'whitelist', 'blacklist'].includes(value)
    case 'triggerMode':
      return typeof value === 'string' && ['selected', 'ctrlkey', 'shortcut'].includes(value)
    case 'api':
      return isSelectionPreferences({
        interfaceLanguage: 'zh-CN',
        enabled: false,
        actionItems: [],
        actionWindowOpacity: 100,
        autoClose: false,
        autoPin: false,
        compact: false,
        filterList: [],
        filterMode: 'default',
        followToolbar: true,
        rememberWindowSize: false,
        triggerMode: 'selected',
        api: value
      })
  }
}

export const isNativeEvent = (value: unknown): value is NativeEvent => {
  if (!isRecord(value) || typeof value.type !== 'string') return false

  switch (value.type) {
    case 'bootstrap':
      return isSelectionPreferences(value.preferences) && hasBoolean(value, 'hasAPIKey')
    case 'preferences.changed':
      return isPreferenceKey(value.key) && isPreferenceValue(value.key, value.value)
    case 'preferences.saved':
      return hasString(value, 'requestId') && isPreferenceKey(value.key) && isPreferenceValue(value.key, value.value)
    case 'preferences.saveFailed':
      return hasString(value, 'requestId') && isPreferenceKey(value.key)
    case 'selection.textSelected':
      return hasString(value, 'text') && (value.isFullscreen === undefined || typeof value.isFullscreen === 'boolean')
    case 'appearance.changed':
      return value.mode === 'light' || value.mode === 'dark'
    case 'toolbar.visibilityChanged':
      return hasBoolean(value, 'visible')
    case 'action.start':
      return hasString(value, 'requestId') && isSelectionActionItem(value.action) && hasString(value, 'selectedText')
    case 'action.delta':
      return hasString(value, 'requestId') && hasString(value, 'text')
    case 'action.complete':
      return hasString(value, 'requestId') && hasString(value, 'content')
    case 'action.error':
      return hasString(value, 'requestId') && hasString(value, 'code') && hasString(value, 'message')
    case 'action.cancelled':
      return hasString(value, 'requestId')
    case 'api.modelsLoaded':
      return hasRequestID(value) && Array.isArray(value.models) && value.models.every((model) => typeof model === 'string') &&
        hasNumber(value, 'latencyMilliseconds') && Number(value.latencyMilliseconds) >= 0
    case 'api.connectionSucceeded':
      return hasRequestID(value) && hasNumber(value, 'latencyMilliseconds') && Number(value.latencyMilliseconds) >= 0
    case 'api.requestFailed':
      return hasRequestID(value) && (value.operation === 'models' || value.operation === 'connection') &&
        typeof value.code === 'string' && apiErrorCodes.includes(value.code as APIErrorCode)
    case 'api.requestCancelled':
      return hasRequestID(value)
    default:
      return false
  }
}
