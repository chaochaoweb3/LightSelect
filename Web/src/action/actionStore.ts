import { nativeBridge } from '../bridge/nativeBridge'
import type { NativeEvent, SelectionActionItem } from '../bridge/types'

export type ActionState = {
  requestId: string | null
  action: SelectionActionItem | null
  selectedText: string
  content: string
  status: 'idle' | 'loading' | 'complete' | 'error' | 'cancelled'
  error: { code: string; message: string } | null
}

type ActionEvent = Extract<NativeEvent, { type: `action.${string}` }>
type StoreListener = () => void

export type ActionStore = {
  getSnapshot: () => ActionState
  subscribe: (listener: StoreListener) => () => void
  applyEvent: (event: ActionEvent) => void
}

const initialState: ActionState = {
  requestId: null,
  action: null,
  selectedText: '',
  content: '',
  status: 'idle',
  error: null
}

export const createActionStore = (): ActionStore => {
  let snapshot = initialState
  const listeners = new Set<StoreListener>()
  const publish = (next: ActionState): void => {
    snapshot = next
    listeners.forEach((listener) => listener())
  }

  return {
    getSnapshot: () => snapshot,
    subscribe: (listener) => {
      listeners.add(listener)
      return () => listeners.delete(listener)
    },
    applyEvent: (event) => {
      if (event.type === 'action.start') {
        publish({
          requestId: event.requestId,
          action: event.action,
          selectedText: event.selectedText,
          content: '',
          status: 'loading',
          error: null
        })
        return
      }

      if (event.requestId !== snapshot.requestId) return

      switch (event.type) {
        case 'action.delta':
          publish({ ...snapshot, content: snapshot.content + event.text })
          break
        case 'action.complete':
          publish({ ...snapshot, content: event.content, status: 'complete', error: null })
          break
        case 'action.error':
          publish({
            ...snapshot,
            status: 'error',
            error: { code: event.code, message: event.message }
          })
          break
        case 'action.cancelled':
          publish({ ...snapshot, status: 'cancelled' })
          break
      }
    }
  }
}

export const actionStore = createActionStore()

for (const eventType of ['action.start', 'action.delta', 'action.complete', 'action.error', 'action.cancelled'] as const) {
  nativeBridge.on(eventType, (event) => actionStore.applyEvent(event))
}
