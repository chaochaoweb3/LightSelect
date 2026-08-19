import { act, fireEvent, render, screen } from '@testing-library/react'
import { afterEach, beforeEach, describe, expect, it, type MockInstance, vi } from 'vitest'

import { nativeBridge } from '../../bridge/nativeBridge'
import { applyInterfaceLanguage } from '../../adapters/i18n'
import type { SelectionActionItem } from '../../bridge/types'
import { defaultSelectionPreferences } from '../../preferences/defaults'
import { preferenceStore } from '../../preferences/store'
import SelectionToolbarView from '../../vendor/cherry/components/selection/SelectionToolbarView'
import SelectionToolbar from '../../vendor/cherry/windows/selection/toolbar/SelectionToolbar'

const expandedActions: SelectionActionItem[] = [
  defaultSelectionPreferences.actionItems[0],
  defaultSelectionPreferences.actionItems[1],
  defaultSelectionPreferences.actionItems[4]
]

describe('Cherry SelectionToolbarView', () => {
  it('preserves upstream geometry, logo, icon, and expanded labels', () => {
    const handleAction = vi.fn()
    const { container } = render(
      <SelectionToolbarView
        actionItems={expandedActions}
        isCompact={false}
        handleAction={handleAction}
        copyIconStatus="normal"
        copyIconAnimation="none"
        draggable
      />
    )

    const toolbar = container.querySelector('[data-ui="selection.toolbar"]')
    expect(toolbar).toHaveClass('h-9', 'rounded-[10px]', 'bg-card', 'm-[2px_3px_5px_3px]!')
    expect(container.querySelector('img')).toHaveClass('size-[22px]', 'rounded-full')
    expect(container.querySelector('.btn-icon')).toHaveClass('size-full')
    expect(screen.getByRole('button', { name: '翻译' })).toHaveTextContent('翻译')
    expect(screen.getByRole('button', { name: '解释' })).toHaveTextContent('解释')
    expect(screen.getByRole('button', { name: '复制' })).toHaveTextContent('复制')

    fireEvent.click(screen.getByRole('button', { name: '解释' }))
    expect(handleAction).toHaveBeenCalledWith(expandedActions[1])
  })

  it('uses titles and hides text labels in compact mode', () => {
    render(
      <SelectionToolbarView
        actionItems={expandedActions}
        isCompact
        handleAction={vi.fn()}
        copyIconStatus="normal"
        copyIconAnimation="none"
      />
    )

    expect(screen.getByRole('button', { name: '翻译' })).toHaveAttribute('title', '翻译')
    expect(screen.getByRole('button', { name: '翻译' })).not.toHaveTextContent('翻译')
  })

  it.each([
    ['success' as const, 'lucide-clipboard-check'],
    ['fail' as const, 'lucide-clipboard-x']
  ])('preserves the %s copy feedback icon transition', (status, iconClass) => {
    const { container } = render(
      <SelectionToolbarView
        actionItems={[defaultSelectionPreferences.actionItems[4]]}
        isCompact
        handleAction={vi.fn()}
        copyIconStatus={status}
        copyIconAnimation="enter"
      />
    )

    expect(container.querySelector(`.${iconClass}`)).toHaveClass('scale-100', 'opacity-100')
    expect(container.querySelector('.lucide-clipboard-copy')).toHaveClass('scale-0', 'opacity-0')
  })
})

describe('Cherry SelectionToolbar actions', () => {
  let send: MockInstance<typeof nativeBridge.send>

  beforeEach(async () => {
    await applyInterfaceLanguage('zh-CN')
    send = vi.spyOn(nativeBridge, 'send').mockReturnValue(true)
    preferenceStore.applyEvent({
      type: 'bootstrap',
      hasAPIKey: true,
      preferences: {
        ...defaultSelectionPreferences,
        enabled: true,
        actionItems: defaultSelectionPreferences.actionItems.map((action) => ({
          ...action,
          enabled: action.id !== 'refine'
        }))
      }
    })
  })

  afterEach(() => {
    vi.useRealTimers()
  })

  const pushSelection = (text: string, isFullscreen = false): void => {
    act(() => {
      window.dispatchEvent(
        new CustomEvent('lightselect:event', {
          detail: { type: 'selection.textSelected', text, isFullscreen }
        })
      )
    })
  }

  it('filters disabled actions and routes an AI action with fresh selected text', () => {
    render(<SelectionToolbar />)
    send.mockClear()
    pushSelection('selected text', true)

    expect(screen.queryByRole('button', { name: '润色' })).not.toBeInTheDocument()
    fireEvent.click(screen.getByRole('button', { name: '总结' }))

    expect(send).toHaveBeenCalledWith({
      type: 'selection.performAction',
      actionId: 'summary',
      selectedText: 'selected text'
    })
  })

  it('switches built-in labels to English at runtime', () => {
    render(<SelectionToolbar />)

    act(() => {
      window.dispatchEvent(new CustomEvent('lightselect:event', {
        detail: { type: 'preferences.changed', key: 'interfaceLanguage', value: 'en-US' }
      }))
    })

    expect(screen.getByRole('button', { name: 'Translate' })).toBeInTheDocument()
    expect(screen.getByRole('button', { name: 'Explain' })).toBeInTheDocument()
  })

  it.each([
    ['https://example.com/path', 'https://example.com/path'],
    ['/tmp/paper.pdf', '/tmp/paper.pdf'],
    ['hello world', 'https://www.google.com/search?q=hello%20world'],
    ['https://example.com/\nnext', 'https://www.google.com/search?q=https%3A%2F%2Fexample.com%2F%0Anext']
  ])('routes search text %j to the upstream-compatible target', (selectedText, expectedURL) => {
    render(<SelectionToolbar />)
    send.mockClear()
    pushSelection(selectedText)

    fireEvent.click(screen.getByRole('button', { name: '搜索' }))

    expect(send).toHaveBeenCalledWith({ type: 'system.openURL', url: expectedURL })
  })

  it('routes Markdown quote through the native action adapter', () => {
    render(<SelectionToolbar />)
    send.mockClear()
    pushSelection('quote me')

    fireEvent.click(screen.getByRole('button', { name: '引用' }))

    expect(send).toHaveBeenCalledWith({
      type: 'selection.performAction',
      actionId: 'quote',
      selectedText: 'quote me'
    })
  })

  it('shows Cherry copy success feedback and exits it after two seconds', () => {
    vi.useFakeTimers()
    const { container } = render(<SelectionToolbar />)
    send.mockClear()
    pushSelection('copy me')

    fireEvent.click(screen.getByRole('button', { name: '复制' }))

    expect(send).toHaveBeenCalledWith({ type: 'selection.copySelectedText', selectedText: 'copy me' })
    expect(container.querySelector('.lucide-clipboard-check')).toBeInTheDocument()

    act(() => vi.advanceTimersByTime(2000))
    expect(container.querySelector('.lucide-clipboard-check')).toHaveClass('scale-0', 'opacity-0')
  })

  it('reports ceil-rounded outer content dimensions', () => {
    vi.spyOn(HTMLElement.prototype, 'getBoundingClientRect').mockReturnValue({
      width: 342.2,
      height: 36.1,
      x: 0,
      y: 0,
      top: 0,
      right: 342.2,
      bottom: 36.1,
      left: 0,
      toJSON: () => ({})
    })
    vi.spyOn(window, 'getComputedStyle').mockReturnValue({
      marginLeft: '3px',
      marginRight: '3px',
      marginTop: '2px',
      marginBottom: '5px'
    } as CSSStyleDeclaration)

    render(<SelectionToolbar />)

    expect(send).toHaveBeenCalledWith({ type: 'selection.determineToolbarSize', width: 349, height: 44 })
  })
})
