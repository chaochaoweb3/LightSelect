import { nativeBridge } from '../bridge/nativeBridge'
import type { APIErrorCode, NativeEvent } from '../bridge/types'

export type APIRequestState =
  | { phase: 'idle' }
  | { phase: 'loading'; requestId: string }
  | { phase: 'models'; requestId: string; models: string[]; latencyMilliseconds: number }
  | { phase: 'success'; requestId: string; latencyMilliseconds: number }
  | { phase: 'error'; requestId: string; code: APIErrorCode }

type Operation = 'models' | 'connection'
type Snapshot = Record<Operation, APIRequestState>
type APIEvent = Extract<NativeEvent, { type: 'api.modelsLoaded' | 'api.connectionSucceeded' | 'api.requestFailed' | 'api.requestCancelled' }>

let snapshot: Snapshot = { models: { phase: 'idle' }, connection: { phase: 'idle' } }
const listeners = new Set<() => void>()
const notify = (): void => listeners.forEach((listener) => listener())

export const apiRequestStore = {
  getSnapshot: (): Snapshot => snapshot,
  subscribe: (listener: () => void) => {
    listeners.add(listener)
    return () => { listeners.delete(listener) }
  },
  begin: (operation: Operation): string => {
    const current = snapshot[operation]
    if (current.phase === 'loading') nativeBridge.send({ type: 'api.cancelRequest', requestId: current.requestId })
    const requestId = crypto.randomUUID()
    snapshot = { ...snapshot, [operation]: { phase: 'loading', requestId } }
    notify()
    return requestId
  },
  applyEvent: (event: APIEvent): void => {
    const operation: Operation = event.type === 'api.modelsLoaded' ? 'models'
      : event.type === 'api.connectionSucceeded' ? 'connection'
        : event.type === 'api.requestFailed' ? event.operation
          : snapshot.models.phase === 'loading' && snapshot.models.requestId === event.requestId ? 'models' : 'connection'
    const current = snapshot[operation]
    if (current.phase !== 'loading' || current.requestId !== event.requestId) return
    const next: APIRequestState = event.type === 'api.modelsLoaded'
      ? { phase: 'models', requestId: event.requestId, models: event.models, latencyMilliseconds: event.latencyMilliseconds }
      : event.type === 'api.connectionSucceeded'
        ? { phase: 'success', requestId: event.requestId, latencyMilliseconds: event.latencyMilliseconds }
        : event.type === 'api.requestFailed'
          ? { phase: 'error', requestId: event.requestId, code: event.code }
          : { phase: 'idle' }
    snapshot = { ...snapshot, [operation]: next }
    notify()
  },
  reset: (): void => { snapshot = { models: { phase: 'idle' }, connection: { phase: 'idle' } }; notify() }
}

nativeBridge.on('api.modelsLoaded', apiRequestStore.applyEvent)
nativeBridge.on('api.connectionSucceeded', apiRequestStore.applyEvent)
nativeBridge.on('api.requestFailed', apiRequestStore.applyEvent)
nativeBridge.on('api.requestCancelled', apiRequestStore.applyEvent)
nativeBridge.on('bootstrap', () => apiRequestStore.reset())
