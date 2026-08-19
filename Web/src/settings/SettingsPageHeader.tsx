import { AlertCircle, CheckCircle2, LoaderCircle, X } from 'lucide-react'
import type { FC } from 'react'
import { useSyncExternalStore } from 'react'

import { useTranslation } from '../adapters/i18n'
import { nativeBridge } from '../bridge/nativeBridge'
import { preferenceStore } from '../preferences/store'
import type { SettingsPage } from './SettingsSidebar'

const SettingsPageHeader: FC<{ page: SettingsPage }> = ({ page }) => {
  const { t } = useTranslation()
  const save = useSyncExternalStore(preferenceStore.subscribeSave, preferenceStore.getSaveSnapshot)
  const Icon = save.phase === 'saving' ? LoaderCircle : save.phase === 'failed' ? AlertCircle : CheckCircle2
  const status = save.phase === 'idle' ? '' : t(`settings.save.${save.phase}`)
  return (
    <header className="lightselect-page-header">
      <div>
        <h1>{t(`settings.${page}`)}</h1>
        <p>{t(`settings.${page}.description`)}</p>
      </div>
      <div className="lightselect-page-header-actions">
        <span
          className={`lightselect-save-status is-${save.phase}`}
          data-testid="settings.save-status"
          data-ui="settings.save-status"
          aria-live="polite">
          {status && <><Icon aria-hidden="true" />{status}</>}
        </span>
        <button
          type="button"
          className="lightselect-settings-close"
          aria-label={t('settings.close')}
          title={t('settings.close')}
          onClick={() => nativeBridge.send({ type: 'application.closeSettings' })}>
          <X aria-hidden="true" />
        </button>
      </div>
    </header>
  )
}

export default SettingsPageHeader
