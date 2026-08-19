// Adapted from Cherry Studio src/renderer/pages/settings/SelectionAssistantSettings/SelectionAssistantSettings.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import type { FC } from 'react'
import { useState, useSyncExternalStore } from 'react'

import { preferenceStore } from '../../../../../preferences/store'
import { updatePreference } from '../../../../../preferences/update'
import AboutSettingsSection from '../../../../../settings/AboutSettingsSection'
import APISettingsSection from '../../../../../settings/APISettingsSection'
import AppFilterSettingsSection from '../../../../../settings/AppFilterSettingsSection'
import GeneralSettingsSection from '../../../../../settings/GeneralSettingsSection'
import SettingsPageHeader from '../../../../../settings/SettingsPageHeader'
import SettingsSidebar, { type SettingsPage } from '../../../../../settings/SettingsSidebar'
import SelectionActionsList from './components/SelectionActionsList'

const SelectionAssistantSettings: FC = () => {
  const preferences = useSyncExternalStore(preferenceStore.subscribe, preferenceStore.getSnapshot)
  const [activePage, setActivePage] = useState<SettingsPage>('general')
  const [filterModalOpen, setFilterModalOpen] = useState(false)

  const page = (() => {
    switch (activePage) {
      case 'general': return <GeneralSettingsSection preferences={preferences} />
      case 'actions': return <SelectionActionsList items={preferences.actionItems} compact={preferences.compact} onChange={(items) => updatePreference('actionItems', items)} />
      case 'api': return <APISettingsSection api={preferences.api} hasAPIKey={preferenceStore.hasAPIKey()} onChange={(api) => updatePreference('api', api)} />
      case 'filter': return <AppFilterSettingsSection preferences={preferences} modalOpen={filterModalOpen} onModalOpen={setFilterModalOpen} />
      case 'about': return <AboutSettingsSection />
    }
  })()

  return (
    <main className="lightselect-settings-shell">
      <SettingsSidebar activePage={activePage} onSelect={setActivePage} language={preferences.interfaceLanguage} onLanguageChange={(language) => updatePreference('interfaceLanguage', language)} />
      <div className="lightselect-settings-content">
        <SettingsPageHeader page={activePage} />
        <section className="lightselect-settings-page" data-ui={`settings.page.${activePage}`}>{page}</section>
      </div>
    </main>
  )
}

export default SelectionAssistantSettings
