import { act, fireEvent, render, screen } from '@testing-library/react'
import { beforeEach, describe, expect, it, type MockInstance, vi } from 'vitest'

import { nativeBridge } from '../../bridge/nativeBridge'
import type { NativeEvent, SelectionActionItem } from '../../bridge/types'
import { defaultSelectionPreferences } from '../../preferences/defaults'
import { preferenceStore } from '../../preferences/store'
import { createActionStore } from '../actionStore'
import ActionWindow from '../../vendor/cherry/windows/selection/action/ActionWindow'

const explainAction: SelectionActionItem = {
  id: 'explain',
  name: 'selection.action.builtin.explain',
  enabled: true,
  icon: 'file-question',
  isBuiltIn: true
}

const dispatch = (event: NativeEvent): void => {
  act(() => {
    window.dispatchEvent(new CustomEvent('lightselect:event', { detail: event }))
  })
}

const startAction = (requestId = 'request-1', selectedText = 'selected text'): void => {
  dispatch({
    type: 'action.start',
    requestId,
    action: explainAction,
    selectedText
  })
}

describe('actionStore', () => {
  it('starts a fresh session when the request changes even if the action id repeats', () => {
    const store = createActionStore()

    store.applyEvent({ type: 'action.start', requestId: 'request-1', action: explainAction, selectedText: 'first' })
    store.applyEvent({ type: 'action.delta', requestId: 'request-1', text: 'old result' })
    store.applyEvent({ type: 'action.start', requestId: 'request-2', action: explainAction, selectedText: 'second' })

    expect(store.getSnapshot()).toEqual({
      requestId: 'request-2',
      action: explainAction,
      selectedText: 'second',
      content: '',
      status: 'loading',
      error: null
    })
  })

  it('appends only current-request deltas and completes with the authoritative content', () => {
    const store = createActionStore()
    store.applyEvent({ type: 'action.start', requestId: 'request-2', action: explainAction, selectedText: 'text' })
    store.applyEvent({ type: 'action.delta', requestId: 'stale', text: 'ignore' })
    store.applyEvent({ type: 'action.delta', requestId: 'request-2', text: 'streamed ' })
    store.applyEvent({ type: 'action.delta', requestId: 'request-2', text: 'text' })
    store.applyEvent({ type: 'action.complete', requestId: 'request-2', content: 'final text' })

    expect(store.getSnapshot().content).toBe('final text')
    expect(store.getSnapshot().status).toBe('complete')
  })
})

describe('Cherry action window bridge behavior', () => {
  let send: MockInstance<typeof nativeBridge.send>

  beforeEach(() => {
    send = vi.spyOn(nativeBridge, 'send').mockReturnValue(true)
    preferenceStore.applyEvent({
      type: 'bootstrap',
      hasAPIKey: true,
      preferences: {
        ...defaultSelectionPreferences,
        actionWindowOpacity: 80,
        autoClose: false,
        autoPin: false
      }
    })
    startAction()
  })

  it('renders streaming deltas and an error for the active request', () => {
    render(<ActionWindow />)

    dispatch({ type: 'action.delta', requestId: 'request-1', text: 'first ' })
    dispatch({ type: 'action.delta', requestId: 'request-1', text: 'answer' })
    expect(screen.getByText('first answer')).toBeInTheDocument()

    dispatch({
      type: 'action.error',
      requestId: 'request-1',
      code: 'rate_limit',
      message: 'Too many requests'
    })
    expect(screen.getByRole('alert')).toHaveTextContent('Too many requests')
  })

  it('renders completed GitHub-flavored Markdown without executing raw HTML', () => {
    const { container } = render(<ActionWindow />)
    dispatch({
      type: 'action.complete',
      requestId: 'request-1',
      content: '**important**\n\n- first\n- second\n\n<script>unsafe()</script>'
    })

    expect(screen.getByText('important').tagName).toBe('STRONG')
    expect(screen.getByText('second').closest('li')).toBeInTheDocument()
    expect(container.querySelector('script')).not.toBeInTheDocument()
    expect(screen.getByText('<script>unsafe()</script>')).toBeInTheDocument()
  })

  it('keeps stop and close as separate footer actions while loading', () => {
    render(<ActionWindow />)
    send.mockClear()

    const stopButton = screen.getByRole('button', { name: '停止' })
    const closeButton = screen.getByRole('button', { name: '关闭' })
    expect(stopButton).toHaveClass('min-w-[64px]', 'h-7')
    expect(stopButton.querySelectorAll('svg')).toHaveLength(1)
    fireEvent.click(stopButton)
    expect(send).toHaveBeenCalledWith({ type: 'action.cancel', requestId: 'request-1' })
    fireEvent.click(closeButton)
    expect(send).toHaveBeenCalledWith({ type: 'action.close' })

    dispatch({ type: 'action.complete', requestId: 'request-1', content: 'finished' })
    fireEvent.click(screen.getByRole('button', { name: '重新生成' }))
    expect(send).toHaveBeenCalledWith({ type: 'action.regenerate', requestId: 'request-1' })
  })

  it('keeps a dedicated titlebar close button available while loading', () => {
    render(<ActionWindow />)
    send.mockClear()

    const closeButton = screen.getByRole('button', { name: '关闭窗口' })
    expect(closeButton).toHaveClass('size-6')
    fireEvent.click(closeButton)

    expect(send).toHaveBeenCalledTimes(1)
    expect(send).toHaveBeenCalledWith({ type: 'action.close' })
  })

  it('disables copy while loading and routes completed result copy', () => {
    render(<ActionWindow />)
    const copyButton = screen.getByRole('button', { name: '复制' })
    expect(copyButton).toBeDisabled()

    dispatch({ type: 'action.complete', requestId: 'request-1', content: 'copy result' })
    expect(copyButton).toBeEnabled()
    fireEvent.click(copyButton)

    expect(send).toHaveBeenCalledWith({ type: 'result.copy', content: 'copy result' })
  })

  it('closes on Escape after completion', () => {
    render(<ActionWindow />)
    dispatch({ type: 'action.complete', requestId: 'request-1', content: 'done' })
    send.mockClear()

    fireEvent.keyDown(window, { key: 'Escape' })
    expect(send).toHaveBeenCalledWith({ type: 'action.close' })
  })

  it('routes pin and opacity controls and applies configured opacity', () => {
    const { container } = render(<ActionWindow />)
    expect(container.firstElementChild).toHaveClass('bg-popover')
    expect(container.firstElementChild).toHaveStyle({ opacity: '0.8' })
    send.mockClear()

    fireEvent.click(screen.getByRole('button', { name: '固定' }))
    expect(send).toHaveBeenCalledWith({ type: 'action.pin', pinned: true })

    fireEvent.click(screen.getByRole('button', { name: '透明度' }))
    fireEvent.change(screen.getByRole('slider', { name: '透明度' }), { target: { value: '60' } })
    expect(container.firstElementChild).toHaveStyle({ opacity: '0.6' })
    expect(send).toHaveBeenCalledWith({ type: 'action.setOpacity', opacity: 60 })
  })

  it('auto-closes on blur only when unpinned', () => {
    preferenceStore.applyEvent({ type: 'preferences.changed', key: 'autoClose', value: true })
    render(<ActionWindow />)
    send.mockClear()

    fireEvent.blur(window)
    expect(send).toHaveBeenCalledWith({ type: 'action.close' })
  })

  it('resets transient controls for a repeated action in a new request', () => {
    render(<ActionWindow />)
    fireEvent.click(screen.getByRole('button', { name: '固定' }))
    fireEvent.click(screen.getByRole('button', { name: '透明度' }))
    expect(screen.getByRole('slider', { name: '透明度' })).toBeInTheDocument()

    startAction('request-2', 'next selection')

    expect(screen.queryByRole('slider', { name: '透明度' })).not.toBeInTheDocument()
    expect(screen.getByRole('button', { name: '固定' })).toHaveAttribute('aria-pressed', 'false')
  })

  it('does not clear a manual pin when only the default opacity preference changes', () => {
    render(<ActionWindow />)
    fireEvent.click(screen.getByRole('button', { name: '固定' }))
    expect(screen.getByRole('button', { name: '固定' })).toHaveAttribute('aria-pressed', 'true')

    act(() => {
      preferenceStore.applyEvent({ type: 'preferences.changed', key: 'actionWindowOpacity', value: 55 })
    })

    expect(screen.getByRole('button', { name: '固定' })).toHaveAttribute('aria-pressed', 'true')
  })

  it('preserves Cherry translation direction and original-text controls', () => {
    dispatch({
      type: 'action.start',
      requestId: 'translate-1',
      action: { ...explainAction, id: 'translate', name: 'selection.action.builtin.translate', icon: 'languages' },
      selectedText: 'Hello world'
    })
    render(<ActionWindow />)

    expect(screen.getByText('自动检测')).toBeInTheDocument()
    expect(screen.getByText('zh-cn')).toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: '显示原文' }))
    expect(screen.getByText('Hello world')).toBeInTheDocument()
    expect(screen.getByRole('button', { name: '复制原文' })).toBeInTheDocument()
  })
})
