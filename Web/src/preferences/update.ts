import { nativeBridge } from '../bridge/nativeBridge'
import type { NativeCommand, SelectionPreferences } from '../bridge/types'
import { preferenceStore } from './store'

export const updatePreference = <Key extends keyof SelectionPreferences>(
  key: Key,
  value: SelectionPreferences[Key]
): void => {
  const requestId = crypto.randomUUID()
  preferenceStore.beginUpdate(requestId, key, value)
  const command = { type: 'preferences.update', requestId, key, value } as Extract<
    NativeCommand,
    { type: 'preferences.update' }
  >
  if (!nativeBridge.send(command)) {
    preferenceStore.applyEvent({ type: 'preferences.saveFailed', requestId, key })
  }
}
