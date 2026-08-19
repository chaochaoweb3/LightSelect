import { act, fireEvent, render, screen, within } from '@testing-library/react'
import { beforeEach, describe, expect, it, type MockInstance, vi } from 'vitest'

import { nativeBridge } from '../../bridge/nativeBridge'
import { applyInterfaceLanguage } from '../../adapters/i18n'
import { defaultSelectionPreferences } from '../../preferences/defaults'
import { preferenceStore } from '../../preferences/store'
import SelectionAssistantSettings from '../../vendor/cherry/pages/settings/SelectionAssistantSettings/SelectionAssistantSettings'

describe('Cherry selection assistant settings', () => {
  let send: MockInstance<typeof nativeBridge.send>

  beforeEach(async () => {
    await applyInterfaceLanguage('zh-CN')
    send = vi.spyOn(nativeBridge, 'send').mockReturnValue(true)
    act(() => {
      preferenceStore.applyEvent({
        type: 'bootstrap',
        hasAPIKey: true,
        preferences: { ...defaultSelectionPreferences, enabled: true }
      })
    })
  })

  const navigate = (name: string): void => {
    fireEvent.click(within(screen.getByRole('navigation', { name: '设置导航' })).getByRole('button', { name }))
  }

  it('uses a five-destination settings center with a stable save indicator', () => {
    render(<SelectionAssistantSettings />)

    const navigation = screen.getByRole('navigation', { name: '设置导航' })
    expect(within(navigation).getAllByRole('button')).toHaveLength(5)
    expect(screen.getByText('启用划词助手')).toBeInTheDocument()
    expect(screen.queryByLabelText('API 设置')).not.toBeInTheDocument()

    fireEvent.click(within(navigation).getByRole('button', { name: 'API' }))
    expect(screen.getByLabelText('API 设置')).toBeInTheDocument()
    expect(screen.queryByText('启用划词助手')).not.toBeInTheDocument()

    act(() => preferenceStore.beginUpdate('save-layout', 'compact', true))
    expect(screen.getByTestId('settings.save-status')).toHaveTextContent('正在保存')
  })

  it('closes only the settings window from the page header', () => {
    render(<SelectionAssistantSettings />)

    fireEvent.click(screen.getByRole('button', { name: '关闭设置' }))

    expect(send).toHaveBeenCalledWith({ type: 'application.closeSettings' })
  })

  it('updates the six core switches through the preference bridge', () => {
    render(<SelectionAssistantSettings />)

    for (const [label, key, value] of [
      ['启用划词助手', 'enabled', false],
      ['紧凑模式', 'compact', true],
      ['跟随工具栏', 'followToolbar', false],
      ['记住窗口大小', 'rememberWindowSize', true],
      ['失焦自动关闭', 'autoClose', true],
      ['自动固定窗口', 'autoPin', true]
    ] as const) {
      const control = screen.getByRole('switch', { name: label })
      fireEvent.click(control)
      expect(send).toHaveBeenCalledWith(expect.objectContaining({
        type: 'preferences.update',
        requestId: expect.any(String),
        key,
        value
      }))
    }
  })

  it('updates trigger, filter, opacity, and normalized filter entries', () => {
    render(<SelectionAssistantSettings />)

    fireEvent.click(screen.getByRole('radio', { name: '按住 Control' }))
    expect(send).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'preferences.update', requestId: expect.any(String), key: 'triggerMode', value: 'ctrlkey' })
    )
    fireEvent.click(screen.getByRole('radio', { name: '快捷键' }))
    expect(send).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'preferences.update', requestId: expect.any(String), key: 'triggerMode', value: 'shortcut' })
    )

    fireEvent.change(screen.getByRole('slider', { name: '结果窗口透明度' }), { target: { value: '60' } })
    expect(send).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'preferences.update', requestId: expect.any(String), key: 'actionWindowOpacity', value: 60 })
    )

    navigate('应用过滤')
    fireEvent.click(screen.getByRole('radio', { name: '白名单' }))
    fireEvent.click(screen.getByRole('button', { name: '编辑过滤列表' }))
    const dialog = screen.getByRole('dialog', { name: '应用过滤列表' })
    fireEvent.change(within(dialog).getByRole('textbox'), {
      target: { value: 'COM.APP.ONE\ncom.app.two\ncom.app.one\n' }
    })
    fireEvent.click(within(dialog).getByRole('button', { name: '保存' }))

    expect(send).toHaveBeenCalledWith(expect.objectContaining({
      type: 'preferences.update',
      requestId: expect.any(String),
      key: 'filterList',
      value: ['com.app.one', 'com.app.two']
    }))
  })

  it('enables, reorders, and edits built-in actions', () => {
    render(<SelectionAssistantSettings />)
    navigate('动作')

    fireEvent.click(screen.getByRole('switch', { name: '启用 润色' }))
    expect(send).toHaveBeenCalledWith(
      expect.objectContaining({ type: 'preferences.update', key: 'actionItems' })
    )
    const enabled = send.mock.calls.at(-1)?.[0]
    expect(enabled).toMatchObject({
      value: expect.arrayContaining([expect.objectContaining({ id: 'refine', enabled: true })])
    })

    fireEvent.click(screen.getByRole('button', { name: '上移 总结' }))
    const reordered = send.mock.calls.at(-1)?.[0]
    if (!reordered || reordered.type !== 'preferences.update' || reordered.key !== 'actionItems') {
      throw new Error('Expected actionItems update')
    }
    expect(reordered.value.map((item) => item.id).slice(0, 3)).toEqual(['translate', 'summary', 'explain'])

    fireEvent.click(screen.getByRole('button', { name: '编辑 搜索' }))
    const dialog = screen.getByRole('dialog', { name: '编辑搜索动作' })
    fireEvent.change(within(dialog).getByLabelText('搜索网址'), {
      target: { value: 'DuckDuckGo|https://duckduckgo.com/?q={{queryString}}' }
    })
    fireEvent.click(within(dialog).getByRole('button', { name: '保存' }))
    expect(send.mock.calls.at(-1)?.[0]).toMatchObject({
      type: 'preferences.update',
      key: 'actionItems',
      value: expect.arrayContaining([
        expect.objectContaining({ id: 'search', searchEngine: 'DuckDuckGo|https://duckduckgo.com/?q={{queryString}}' })
      ])
    })
  })

  it('creates a custom prompt action in Cherry field order', () => {
    render(<SelectionAssistantSettings />)
    navigate('动作')
    fireEvent.click(screen.getByRole('button', { name: '添加自定义动作' }))
    const dialog = screen.getByRole('dialog', { name: '自定义动作' })

    fireEvent.change(within(dialog).getByLabelText('名称'), { target: { value: '提取术语' } })
    fireEvent.change(within(dialog).getByLabelText('图标'), { target: { value: 'list-checks' } })
    fireEvent.change(within(dialog).getByLabelText('提示词'), { target: { value: '提取 {{text}} 中的术语' } })
    fireEvent.click(within(dialog).getByRole('button', { name: '保存' }))

    expect(send.mock.calls.at(-1)?.[0]).toMatchObject({
      type: 'preferences.update',
      key: 'actionItems',
      value: expect.arrayContaining([
        expect.objectContaining({
          name: '提取术语',
          icon: 'list-checks',
          prompt: '提取 {{text}} 中的术语',
          enabled: false,
          isBuiltIn: false
        })
      ])
    })
  })

  it('edits API settings while keeping a stored key masked', () => {
    render(<SelectionAssistantSettings />)
    navigate('API')

    const apiKey = screen.getByLabelText('API Key')
    expect(apiKey.closest('form')).toHaveAttribute('aria-label', 'API 设置')
    expect(apiKey).toHaveValue('••••••••')
    expect(apiKey).toHaveAttribute('type', 'password')

    fireEvent.change(screen.getByLabelText('Base URL'), { target: { value: 'https://api.example.com/v1' } })
    fireEvent.blur(screen.getByLabelText('Base URL'))
    expect(send).toHaveBeenCalledWith(
      expect.objectContaining({
        type: 'preferences.update',
        key: 'api',
        value: expect.objectContaining({ baseURL: 'https://api.example.com/v1' })
      })
    )

    fireEvent.focus(apiKey)
    fireEvent.change(apiKey, { target: { value: 'new-secret' } })
    fireEvent.blur(apiKey)
    expect(send).toHaveBeenCalledWith({ type: 'credentials.updateAPIKey', value: 'new-secret' })

    navigate('关于')
    fireEvent.click(screen.getByRole('button', { name: '打开辅助功能设置' }))
    expect(send).toHaveBeenCalledWith({ type: 'application.openAccessibilitySettings' })
  })

  it('marks choice rows for narrow settings windows', () => {
    render(<SelectionAssistantSettings />)

    expect(screen.getByText('显示模式').closest('.lightselect-setting-row')).toHaveClass('lightselect-choice-row')
    navigate('应用过滤')
    expect(screen.getByText('过滤模式').closest('.lightselect-setting-row')).toHaveClass('lightselect-choice-row')
  })

  it('switches first-party settings labels while preserving custom action names', () => {
    act(() => {
      preferenceStore.applyEvent({
        type: 'bootstrap',
        hasAPIKey: true,
        preferences: {
          ...defaultSelectionPreferences,
          actionItems: [
            ...defaultSelectionPreferences.actionItems,
            { id: 'custom-terms', name: '提取术语', enabled: true, isBuiltIn: false, prompt: '提取术语' }
          ]
        }
      })
    })
    render(<SelectionAssistantSettings />)

    act(() => {
      window.dispatchEvent(new CustomEvent('lightselect:event', {
        detail: { type: 'preferences.changed', key: 'interfaceLanguage', value: 'en-US' }
      }))
    })

    expect(screen.getByText('Selection Assistant')).toBeInTheDocument()
    expect(screen.getAllByText('General')).not.toHaveLength(0)
    fireEvent.click(within(screen.getByRole('navigation', { name: 'Settings navigation' })).getByRole('button', { name: 'Actions' }))
    expect(screen.getAllByText('提取术语')).not.toHaveLength(0)
  })
})
