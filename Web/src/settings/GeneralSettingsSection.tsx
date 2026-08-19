import type { FC, ReactNode } from 'react'

import { useTranslation } from '../adapters/i18n'
import type { SelectionPreferences, SelectionTriggerMode } from '../bridge/types'
import { updatePreference } from '../preferences/update'

const GeneralSettingsSection: FC<{ preferences: SelectionPreferences }> = ({ preferences }) => {
  const { t } = useTranslation()
  return <>
    <section className="lightselect-settings-section">
      <SettingsSwitch label={t('settings.enable')} checked={preferences.enabled} onChange={(value) => updatePreference('enabled', value)} />
      <div className="lightselect-setting-row lightselect-choice-row">
        <div className="min-w-0 flex-1"><div className="text-sm">{t('settings.displayMode')}</div><div className="text-muted-foreground text-xs">{t('settings.displayMode.description')}</div></div>
        <RadioSet<SelectionTriggerMode>
          value={preferences.triggerMode}
          onChange={(value) => updatePreference('triggerMode', value)}
          options={[
            ['selected', t('settings.trigger.selected')],
            ['ctrlkey', t('settings.trigger.ctrlkey')],
            ['shortcut', t('settings.trigger.shortcut')]
          ]}
        />
      </div>
      <SettingsSwitch label={t('settings.compact')} description={t('settings.compact.description')} checked={preferences.compact} onChange={(value) => updatePreference('compact', value)} />
    </section>
    <section className="lightselect-settings-section">
      <h2>{t('settings.resultWindow')}</h2>
      <SettingsSwitch label={t('settings.followToolbar')} checked={preferences.followToolbar} onChange={(value) => updatePreference('followToolbar', value)} />
      <SettingsSwitch label={t('settings.rememberWindowSize')} checked={preferences.rememberWindowSize} onChange={(value) => updatePreference('rememberWindowSize', value)} />
      <SettingsSwitch label={t('settings.autoClose')} checked={preferences.autoClose} onChange={(value) => updatePreference('autoClose', value)} />
      <SettingsSwitch label={t('settings.autoPin')} checked={preferences.autoPin} onChange={(value) => updatePreference('autoPin', value)} />
      <div className="lightselect-setting-row">
        <div className="min-w-0 flex-1"><div className="text-sm">{t('settings.opacity')}</div><div className="text-muted-foreground text-xs">{preferences.actionWindowOpacity}%</div></div>
        <input type="range" min={20} max={100} aria-label={t('settings.opacity')} value={preferences.actionWindowOpacity} onChange={(event) => updatePreference('actionWindowOpacity', Number(event.currentTarget.value))} />
      </div>
    </section>
  </>
}

export const SettingsSwitch: FC<{ label: string; description?: string; checked: boolean; onChange: (checked: boolean) => void }> = ({ label, description, checked, onChange }) => (
  <div className="lightselect-setting-row"><div className="min-w-0 flex-1"><div className="text-sm">{label}</div>{description && <div className="text-muted-foreground text-xs">{description}</div>}</div><label className="lightselect-switch"><input type="checkbox" role="switch" aria-label={label} checked={checked} onChange={(event) => onChange(event.currentTarget.checked)} /><span /></label></div>
)

export const RadioSet = <Value extends string>({ value, options, onChange }: { value: Value; options: ReadonlyArray<readonly [Value, ReactNode]>; onChange: (value: Value) => void }) => (
  <div className="lightselect-radio-set">{options.map(([option, label]) => <label key={option}><input type="radio" name={options.map(([candidate]) => candidate).join('-')} value={option} checked={value === option} onChange={() => onChange(option)} />{label}</label>)}</div>
)

export default GeneralSettingsSection
