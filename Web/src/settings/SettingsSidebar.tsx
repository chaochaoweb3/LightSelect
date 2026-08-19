import { Info, ListChecks, ServerCog, Settings2, Shield } from 'lucide-react'
import type { FC } from 'react'

import { useTranslation } from '../adapters/i18n'
import type { InterfaceLanguage } from '../bridge/types'
import AppLogo from '../vendor/cherry/assets/logo.png'

export type SettingsPage = 'general' | 'actions' | 'api' | 'filter' | 'about'

const destinations = [
  ['general', Settings2, 'settings.general'],
  ['actions', ListChecks, 'settings.actions'],
  ['api', ServerCog, 'settings.api'],
  ['filter', Shield, 'settings.filter'],
  ['about', Info, 'settings.about']
] as const

const SettingsSidebar: FC<{
  activePage: SettingsPage
  onSelect: (page: SettingsPage) => void
  language: InterfaceLanguage
  onLanguageChange: (language: InterfaceLanguage) => void
}> = ({ activePage, onSelect, language, onLanguageChange }) => {
  const { t } = useTranslation()
  return (
    <aside className="lightselect-settings-sidebar" data-ui="settings.sidebar">
      <div className="lightselect-settings-brand">
        <img src={AppLogo} alt="" />
        <div><strong>{t('settings.product')}</strong><span>{t('settings.title')}</span></div>
      </div>
      <nav aria-label={t('settings.navigation')} className="lightselect-settings-nav">
        {destinations.map(([page, Icon, label]) => (
          <button
            key={page}
            type="button"
            data-settings-page={page}
            aria-current={activePage === page ? 'page' : undefined}
            onClick={() => onSelect(page)}>
            <Icon aria-hidden="true" />
            <span>{t(label)}</span>
          </button>
        ))}
      </nav>
      <div className="lightselect-language" aria-label={t('settings.language')}>
        <button type="button" aria-pressed={language === 'zh-CN'} onClick={() => onLanguageChange('zh-CN')}>中文</button>
        <button type="button" aria-pressed={language === 'en-US'} onClick={() => onLanguageChange('en-US')}>English</button>
      </div>
    </aside>
  )
}

export default SettingsSidebar
