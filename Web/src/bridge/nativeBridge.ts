import type { NativeCommand, NativeEvent, NativeEventOfType, NativeEventType } from './types'
import { isNativeEvent } from './types'

declare global {
  interface Window {
    webkit?: {
      messageHandlers?: {
        lightselect?: {
          postMessage: (command: NativeCommand) => void
        }
      }
    }
  }
}

type EventListener = (event: NativeEvent) => void

class NativeBridge {
  private readonly listeners = new Map<NativeEventType, Set<EventListener>>()

  constructor() {
    window.addEventListener('lightselect:event', this.handleEvent)
  }

  send(command: NativeCommand): boolean {
    const handler = window.webkit?.messageHandlers?.lightselect
    if (!handler) return false
    handler.postMessage(command)
    return true
  }

  on<Type extends NativeEventType>(type: Type, listener: (event: NativeEventOfType<Type>) => void): () => void {
    const listeners = this.listeners.get(type) ?? new Set<EventListener>()
    const eventListener = listener as EventListener
    listeners.add(eventListener)
    this.listeners.set(type, listeners)

    return () => {
      listeners.delete(eventListener)
      if (listeners.size === 0) this.listeners.delete(type)
    }
  }

  private readonly handleEvent = (event: Event): void => {
    if (!(event instanceof CustomEvent) || !isNativeEvent(event.detail)) return
    this.listeners.get(event.detail.type)?.forEach((listener) => listener(event.detail))
  }
}

export const nativeBridge = new NativeBridge()
