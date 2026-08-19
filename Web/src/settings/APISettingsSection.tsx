import { CheckCircle2, CircleAlert, Eye, EyeOff, LoaderCircle, PlugZap } from 'lucide-react'
import type { FC, FocusEvent, ReactNode } from 'react'
import { useEffect, useState, useSyncExternalStore } from 'react'

import { nativeBridge } from '../bridge/nativeBridge'
import { useTranslation } from '../adapters/i18n'
import type { APIErrorCode, APISettings } from '../bridge/types'
import ModelCombobox from './ModelCombobox'
import { apiRequestStore, type APIRequestState } from './apiRequestStore'

const MASKED_API_KEY = '••••••••'

const Status: FC<{ state: APIRequestState; loadingLabel: string; success?: ReactNode }> = ({ state, loadingLabel, success }) => {
  const { t } = useTranslation()
  if (state.phase === 'idle') return <span className="lightselect-api-status" />
  if (state.phase === 'loading') return <span className="lightselect-api-status" role="status"><LoaderCircle className="is-spinning" />{loadingLabel}</span>
  if (state.phase === 'error') return <span className="lightselect-api-status is-error" role="status"><CircleAlert />{t(`settings.api.error.${state.code as APIErrorCode}`)}</span>
  return <span className="lightselect-api-status is-success" role="status"><CheckCircle2 />{success}</span>
}

const APISettingsSection: FC<{
  api: APISettings
  hasAPIKey: boolean
  onChange: (api: APISettings) => void
}> = ({ api, hasAPIKey, onChange }) => {
  const { t } = useTranslation()
  const [draft, setDraft] = useState(api)
  const [apiKey, setAPIKey] = useState(hasAPIKey ? MASKED_API_KEY : '')
  const [showAPIKey, setShowAPIKey] = useState(false)
  const requests = useSyncExternalStore(apiRequestStore.subscribe, apiRequestStore.getSnapshot)

  useEffect(() => setDraft(api), [api])
  useEffect(() => setAPIKey(hasAPIKey ? MASKED_API_KEY : ''), [hasAPIKey])

  const update = <Key extends keyof APISettings>(key: Key, value: APISettings[Key]): void => {
    setDraft((current) => ({ ...current, [key]: value }))
  }

  const commit = <Key extends keyof APISettings>(key: Key, value: APISettings[Key]): void => {
    onChange({ ...draft, [key]: value })
  }
  const commitKey = (event: FocusEvent<HTMLInputElement>): void => {
    const value = event.currentTarget.value
    if (value !== MASKED_API_KEY) nativeBridge.send({ type: 'credentials.updateAPIKey', value: value || null })
  }

  const requestAPI = (type: 'api.fetchModels' | 'api.testConnection'): void => {
    const operation = type === 'api.fetchModels' ? 'models' : 'connection'
    const requestId = apiRequestStore.begin(operation)
    const apiKeyInput = apiKey !== '' && apiKey !== MASKED_API_KEY ? apiKey : undefined
    onChange(draft)
    if (apiKeyInput) nativeBridge.send({ type: 'credentials.updateAPIKey', value: apiKeyInput })
    nativeBridge.send({ type, requestId, configuration: draft, ...(apiKeyInput ? { apiKeyInput } : {}) })
  }

  const models = requests.models.phase === 'models' ? requests.models.models : []
  const modelsSuccess = requests.models.phase === 'models'
    ? t('settings.api.modelsLoaded', { count: requests.models.models.length })
    : undefined
  const connectionSuccess = requests.connection.phase === 'success'
    ? t('settings.api.connectionSucceeded', { latency: requests.connection.latencyMilliseconds })
    : undefined

  return (
    <section className="lightselect-settings-section" id="api-settings">
      <h2 className="font-medium text-[15px]">API</h2>
      <form
        aria-label={t('settings.api.form')}
        className="mt-3 grid grid-cols-1 gap-3 sm:grid-cols-2"
        onSubmit={(event) => event.preventDefault()}>
        <label className="lightselect-field sm:col-span-2">
          <span>Base URL</span>
          <input
            aria-label="Base URL"
            value={draft.baseURL}
            onChange={(event) => update('baseURL', event.currentTarget.value)}
            onBlur={(event) => commit('baseURL', event.currentTarget.value)}
          />
        </label>
        <label className="lightselect-field sm:col-span-2">
          <span>API Key</span>
          <div className="lightselect-field-control">
            <input
              type={showAPIKey ? 'text' : 'password'}
              aria-label="API Key"
              autoComplete="off"
              value={apiKey}
              onFocus={() => apiKey === MASKED_API_KEY && setAPIKey('')}
              onChange={(event) => setAPIKey(event.currentTarget.value)}
              onBlur={commitKey}
            />
            <button
              type="button"
              aria-label={t(showAPIKey ? 'settings.api.hideKey' : 'settings.api.showKey')}
              title={t(showAPIKey ? 'settings.api.hideKey' : 'settings.api.showKey')}
              onMouseDown={(event) => event.preventDefault()}
              onClick={() => setShowAPIKey((current) => !current)}>
              {showAPIKey ? <EyeOff /> : <Eye />}
            </button>
          </div>
        </label>
        <label className="lightselect-field sm:col-span-2">
          <span>Model</span>
          <ModelCombobox
            value={draft.model}
            models={models}
            loading={requests.models.phase === 'loading'}
            onChange={(value) => update('model', value)}
            onCommit={(value) => commit('model', value)}
            onRefresh={() => requestAPI('api.fetchModels')}
            refreshLabel={t('settings.api.fetchModels')}
          />
          <Status state={requests.models} loadingLabel={t('settings.api.fetchingModels')} success={modelsSuccess} />
        </label>
        <label className="lightselect-field">
          <span>{t('settings.api.sourceLanguage')}</span>
          <input
            aria-label={t('settings.api.sourceLanguage')}
            value={draft.sourceLanguage}
            onChange={(event) => update('sourceLanguage', event.currentTarget.value)}
            onBlur={(event) => commit('sourceLanguage', event.currentTarget.value)}
          />
        </label>
        <label className="lightselect-field">
          <span>{t('settings.api.targetLanguage')}</span>
          <input
            aria-label={t('settings.api.targetLanguage')}
            value={draft.targetLanguage}
            onChange={(event) => update('targetLanguage', event.currentTarget.value)}
            onBlur={(event) => commit('targetLanguage', event.currentTarget.value)}
          />
        </label>
        <div className="lightselect-api-connection sm:col-span-2">
          <button type="button" onClick={() => requestAPI('api.testConnection')} disabled={requests.connection.phase === 'loading'}>
            {requests.connection.phase === 'loading' ? <LoaderCircle className="is-spinning" /> : <PlugZap />}
            {t('settings.api.testConnection')}
          </button>
          <Status state={requests.connection} loadingLabel={t('settings.api.testingConnection')} success={connectionSuccess} />
        </div>
        <details className="lightselect-api-advanced sm:col-span-2">
          <summary>{t('settings.api.advanced')}</summary>
          <label className="lightselect-field">
            <span>{t('settings.api.timeout')}</span>
            <input
              type="number"
              min={5}
              max={300}
              aria-label={t('settings.api.timeout')}
              value={draft.timeoutSeconds}
              onChange={(event) => update('timeoutSeconds', Number(event.currentTarget.value))}
              onBlur={(event) => commit('timeoutSeconds', Number(event.currentTarget.value))}
            />
          </label>
        </details>
      </form>
    </section>
  )
}

export default APISettingsSection
