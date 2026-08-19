import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest'

import { nativeBridge } from '../nativeBridge'
import { isNativeEvent } from '../types'

describe('nativeBridge', () => {
  const postMessage = vi.fn()

  beforeEach(() => {
    postMessage.mockReset()
    Object.defineProperty(window, 'webkit', {
      configurable: true,
      value: {
        messageHandlers: {
          lightselect: { postMessage }
        }
      }
    })
  })

  afterEach(() => {
    Reflect.deleteProperty(window, 'webkit')
  })

  it('posts a typed action command to the native handler', () => {
    const command = {
      type: 'selection.performAction' as const,
      actionId: 'translate',
      selectedText: 'hello'
    }

    nativeBridge.send(command)

    expect(postMessage).toHaveBeenCalledOnce()
    expect(postMessage).toHaveBeenCalledWith(command)
  })

  it('delivers a valid event only to listeners for its type', () => {
    const deltaListener = vi.fn()
    const completeListener = vi.fn()
    const removeDelta = nativeBridge.on('action.delta', deltaListener)
    const removeComplete = nativeBridge.on('action.complete', completeListener)

    window.dispatchEvent(
      new CustomEvent('lightselect:event', {
        detail: { type: 'action.delta', requestId: 'r1', text: '你' }
      })
    )

    expect(deltaListener).toHaveBeenCalledWith({ type: 'action.delta', requestId: 'r1', text: '你' })
    expect(completeListener).not.toHaveBeenCalled()

    removeDelta()
    removeComplete()
  })

  it('ignores malformed and unknown native events', () => {
    const listener = vi.fn()
    const remove = nativeBridge.on('action.delta', listener)

    window.dispatchEvent(new CustomEvent('lightselect:event', { detail: { type: 'action.delta', text: 'missing id' } }))
    window.dispatchEvent(new CustomEvent('lightselect:event', { detail: { type: 'unknown.event' } }))
    window.dispatchEvent(new CustomEvent('lightselect:event', { detail: null }))

    expect(listener).not.toHaveBeenCalled()
    remove()
  })

  it('accepts correlated API results and rejects unstable error shapes', () => {
    expect(isNativeEvent({
      type: 'api.modelsLoaded',
      requestId: 'B04E446B-834E-4A26-98F7-6642A8451E63',
      models: ['gpt-a', 'gpt-b'],
      latencyMilliseconds: 18
    })).toBe(true)
    expect(isNativeEvent({
      type: 'api.connectionSucceeded',
      requestId: 'B04E446B-834E-4A26-98F7-6642A8451E63',
      latencyMilliseconds: 22
    })).toBe(true)
    expect(isNativeEvent({
      type: 'api.requestFailed',
      requestId: 'B04E446B-834E-4A26-98F7-6642A8451E63',
      operation: 'models',
      code: 'authentication'
    })).toBe(true)
    expect(isNativeEvent({
      type: 'api.requestFailed',
      requestId: 'B04E446B-834E-4A26-98F7-6642A8451E63',
      operation: 'models',
      code: 'provider-secret-body'
    })).toBe(false)
    expect(isNativeEvent({
      type: 'api.modelsLoaded',
      requestId: 'not-a-uuid',
      models: ['gpt-a'],
      latencyMilliseconds: 18
    })).toBe(false)
  })
})
