import type { FC } from 'react'

import { useTranslation } from '../adapters/i18n'
import type { SelectionFilterMode, SelectionPreferences } from '../bridge/types'
import { updatePreference } from '../preferences/update'
import SelectionFilterListModal from '../vendor/cherry/pages/settings/SelectionAssistantSettings/components/SelectionFilterListModal'
import { RadioSet } from './GeneralSettingsSection'

const AppFilterSettingsSection: FC<{ preferences: SelectionPreferences; modalOpen: boolean; onModalOpen: (open: boolean) => void }> = ({ preferences, modalOpen, onModalOpen }) => {
  const { t } = useTranslation()
  return <>
    <section className="lightselect-settings-section">
      <div className="lightselect-setting-row lightselect-choice-row">
        <div className="min-w-0 flex-1"><div className="text-sm">{t('settings.filterMode')}</div><div className="text-muted-foreground text-xs">{t('settings.filterMode.description')}</div></div>
        <RadioSet<SelectionFilterMode> value={preferences.filterMode} onChange={(value) => updatePreference('filterMode', value)} options={[
          ['default', t('settings.filter.default')], ['whitelist', t('settings.filter.whitelist')], ['blacklist', t('settings.filter.blacklist')]
        ]} />
      </div>
      {preferences.filterMode !== 'default' && <div className="lightselect-setting-row"><div className="min-w-0 flex-1 text-sm">{t('settings.filter.count', { count: preferences.filterList.length })}</div><button type="button" aria-label={t('settings.filter.edit')} onClick={() => onModalOpen(true)}>{t('settings.edit')}</button></div>}
    </section>
    {modalOpen && <SelectionFilterListModal filterList={preferences.filterList} onClose={() => onModalOpen(false)} onSave={(list) => { updatePreference('filterList', list); onModalOpen(false) }} />}
  </>
}

export default AppFilterSettingsSection
