import { nativeBridge } from '../bridge/nativeBridge'
import type { NativeEvent, SelectionPreferences } from '../bridge/types'
import { defaultSelectionPreferences } from './defaults'

type PreferenceEvent = Extract<
  NativeEvent,
  { type: 'bootstrap' | 'preferences.changed' | 'preferences.saved' | 'preferences.saveFailed' }
>
type StoreListener = () => void
type PendingUpdate<Key extends keyof SelectionPreferences = keyof SelectionPreferences> = {
  requestId: string
  key: Key
  value: SelectionPreferences[Key]
}

export type PreferenceSaveSnapshot = {
  phase: 'idle' | 'saving' | 'saved' | 'failed'
  requestId?: string
}

export type PreferenceStore = {
  getSnapshot: () => SelectionPreferences
  getSaveSnapshot: () => PreferenceSaveSnapshot
  hasAPIKey: () => boolean
  subscribe: (listener: StoreListener) => () => void
  subscribeSave: (listener: StoreListener) => () => void
  beginUpdate: <Key extends keyof SelectionPreferences>(
    requestId: string,
    key: Key,
    value: SelectionPreferences[Key]
  ) => void
  applyEvent: (event: PreferenceEvent) => void
}

export const createPreferenceStore = (
  initialPreferences: SelectionPreferences = defaultSelectionPreferences
): PreferenceStore => {
  let confirmed = { ...initialPreferences }
  let snapshot = { ...initialPreferences }
  let saveSnapshot: PreferenceSaveSnapshot = { phase: 'idle' }
  let apiKeyConfigured = false
  const pending = new Map<keyof SelectionPreferences, PendingUpdate>()
  const listeners = new Set<StoreListener>()
  const saveListeners = new Set<StoreListener>()

  const notify = (): void => listeners.forEach((listener) => listener())
  const notifySave = (): void => saveListeners.forEach((listener) => listener())
  const rebuildSnapshot = (): void => {
    snapshot = { ...confirmed }
    pending.forEach(({ key, value }) => {
      snapshot = { ...snapshot, [key]: value } as SelectionPreferences
    })
  }

  return {
    getSnapshot: () => snapshot,
    getSaveSnapshot: () => saveSnapshot,
    hasAPIKey: () => apiKeyConfigured,
    subscribe: (listener) => {
      listeners.add(listener)
      return () => listeners.delete(listener)
    },
    subscribeSave: (listener) => {
      saveListeners.add(listener)
      return () => saveListeners.delete(listener)
    },
    beginUpdate: (requestId, key, value) => {
      pending.set(key, { requestId, key, value } as PendingUpdate)
      rebuildSnapshot()
      saveSnapshot = { phase: 'saving', requestId }
      notify()
      notifySave()
    },
    applyEvent: (event) => {
      if (event.type === 'bootstrap') {
        confirmed = { ...event.preferences }
        snapshot = { ...event.preferences }
        apiKeyConfigured = event.hasAPIKey
        pending.clear()
        saveSnapshot = { phase: 'idle' }
        notify()
        notifySave()
        return
      }

      if (event.type === 'preferences.changed') {
        confirmed = { ...confirmed, [event.key]: event.value } as SelectionPreferences
        rebuildSnapshot()
        notify()
        return
      }

      const active = pending.get(event.key)
      if (!active || active.requestId !== event.requestId) return
      pending.delete(event.key)

      if (event.type === 'preferences.saved') {
        confirmed = { ...confirmed, [event.key]: event.value } as SelectionPreferences
        saveSnapshot = { phase: 'saved', requestId: event.requestId }
      } else {
        saveSnapshot = { phase: 'failed', requestId: event.requestId }
      }
      rebuildSnapshot()
      notify()
      notifySave()
    }
  }
}

export const preferenceStore = createPreferenceStore()

nativeBridge.on('bootstrap', (event) => preferenceStore.applyEvent(event))
nativeBridge.on('preferences.changed', (event) => preferenceStore.applyEvent(event))
nativeBridge.on('preferences.saved', (event) => preferenceStore.applyEvent(event))
nativeBridge.on('preferences.saveFailed', (event) => preferenceStore.applyEvent(event))
