import { act, fireEvent, render, screen } from '@testing-library/react'
import { beforeEach, describe, expect, it, type MockInstance, vi } from 'vitest'

import { applyInterfaceLanguage } from '../../adapters/i18n'
import { nativeBridge } from '../../bridge/nativeBridge'
import { defaultSelectionPreferences } from '../../preferences/defaults'
import APISettingsSection from '../APISettingsSection'
import { apiRequestStore } from '../apiRequestStore'

describe('API settings tools', () => {
  let send: MockInstance<typeof nativeBridge.send>

  beforeEach(async () => {
    await applyInterfaceLanguage('zh-CN')
    apiRequestStore.reset()
    send = vi.spyOn(nativeBridge, 'send').mockReturnValue(true)
  })

  it('fetches models with the current draft and keeps manual model entry editable', () => {
    const onChange = vi.fn()
    render(<APISettingsSection api={defaultSelectionPreferences.api} hasAPIKey onChange={onChange} />)
    fireEvent.change(screen.getByLabelText('Base URL'), { target: { value: 'https://draft.example/v1' } })
    fireEvent.focus(screen.getByLabelText('API Key'))
    fireEvent.change(screen.getByLabelText('API Key'), { target: { value: 'draft-secret' } })
    fireEvent.change(screen.getByRole('combobox', { name: 'Model' }), { target: { value: 'manual-model' } })
    fireEvent.click(screen.getByRole('button', { name: '获取模型列表' }))

    const command = send.mock.calls.map(([value]) => value).find((value) => value.type === 'api.fetchModels')
    expect(command).toMatchObject({
      configuration: { baseURL: 'https://draft.example/v1', model: 'manual-model' },
      apiKeyInput: 'draft-secret'
    })
    expect(send).toHaveBeenCalledWith({ type: 'credentials.updateAPIKey', value: 'draft-secret' })
    expect(onChange).toHaveBeenCalledWith(expect.objectContaining({
      baseURL: 'https://draft.example/v1', model: 'manual-model'
    }))
    if (!command || command.type !== 'api.fetchModels') throw new Error('Expected model request')

    act(() => window.dispatchEvent(new CustomEvent('lightselect:event', { detail: {
      type: 'api.modelsLoaded', requestId: command.requestId, models: ['gpt-a', 'gpt-z'], latencyMilliseconds: 18
    } })))
    expect(screen.getByRole('combobox', { name: 'Model' })).toHaveValue('manual-model')
    expect(screen.getByRole('option', { name: 'gpt-a' })).toBeInTheDocument()
    expect(screen.getByText('已加载 2 个模型')).toBeInTheDocument()

    const model = screen.getByRole('combobox', { name: 'Model' })
    fireEvent.keyDown(model, { key: 'ArrowDown' })
    fireEvent.keyDown(model, { key: 'Enter' })
    expect(model).toHaveValue('gpt-a')
  })

  it('tests the connection inline and never sends the masked key', () => {
    render(<APISettingsSection api={defaultSelectionPreferences.api} hasAPIKey onChange={vi.fn()} />)
    fireEvent.click(screen.getByRole('button', { name: '测试连接' }))
    const command = send.mock.calls.map(([value]) => value).find((value) => value.type === 'api.testConnection')
    expect(command).not.toHaveProperty('apiKeyInput')
    if (!command || command.type !== 'api.testConnection') throw new Error('Expected connection request')

    act(() => window.dispatchEvent(new CustomEvent('lightselect:event', { detail: {
      type: 'api.connectionSucceeded', requestId: command.requestId, latencyMilliseconds: 22
    } })))
    expect(screen.getByText('连接成功 · 22 ms')).toBeInTheDocument()
  })

  it('reveals the API key on demand and keeps timeout in advanced settings', () => {
    render(<APISettingsSection api={defaultSelectionPreferences.api} hasAPIKey onChange={vi.fn()} />)

    const apiKey = screen.getByLabelText('API Key')
    expect(apiKey).toHaveAttribute('type', 'password')
    fireEvent.click(screen.getByRole('button', { name: '显示 API Key' }))
    expect(apiKey).toHaveAttribute('type', 'text')

    expect(screen.getByText('高级设置').closest('details')).not.toHaveAttribute('open')
    expect(screen.getByLabelText('超时（秒）')).toBeInTheDocument()
  })

  it('shows a stable localized error and ignores stale model responses', () => {
    render(<APISettingsSection api={defaultSelectionPreferences.api} hasAPIKey onChange={vi.fn()} />)
    const refresh = screen.getByRole('button', { name: '获取模型列表' })
    fireEvent.click(refresh)
    const first = send.mock.calls.map(([value]) => value).find((value) => value.type === 'api.fetchModels')
    if (!first || first.type !== 'api.fetchModels') throw new Error('Expected first model request')

    expect(refresh).toBeDisabled()
    let secondRequestId = ''
    act(() => { secondRequestId = apiRequestStore.begin('models') })

    act(() => window.dispatchEvent(new CustomEvent('lightselect:event', { detail: {
      type: 'api.modelsLoaded', requestId: first.requestId, models: ['stale-model'], latencyMilliseconds: 10
    } })))
    expect(screen.queryByRole('option', { name: 'stale-model' })).not.toBeInTheDocument()

    act(() => window.dispatchEvent(new CustomEvent('lightselect:event', { detail: {
      type: 'api.requestFailed', requestId: secondRequestId, operation: 'models', code: 'authentication'
    } })))
    expect(screen.getByText('认证失败，请检查 API Key')).toBeInTheDocument()
  })
})
