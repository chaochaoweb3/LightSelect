// Adapted from Cherry Studio src/renderer/pages/settings/SelectionAssistantSettings/components/SelectionFilterListModal.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import type { FC } from 'react'
import { useState } from 'react'

import { useTranslation } from '../../../../../../adapters/i18n'

const SelectionFilterListModal: FC<{
  filterList: string[]
  onSave: (list: string[]) => void
  onClose: () => void
}> = ({ filterList, onSave, onClose }) => {
  const { t } = useTranslation()
  const [value, setValue] = useState(filterList.join('\n'))

  const save = (): void => {
    const normalized = value
      .split('\n')
      .map((entry) => entry.trim().toLowerCase())
      .filter(Boolean)
    onSave([...new Set(normalized)])
  }

  return (
    <div role="dialog" aria-label={t('settings.dialog.filter')} aria-modal="true" className="lightselect-modal">
      <div className="lightselect-dialog w-[min(520px,calc(100vw-32px))]">
        <h2 className="font-semibold text-base">{t('settings.dialog.filter')}</h2>
        <p className="text-muted-foreground text-sm">{t('settings.dialog.filterHint')}</p>
        <textarea rows={8} value={value} onChange={(event) => setValue(event.currentTarget.value)} autoFocus />
        <div className="lightselect-dialog-footer">
          <button type="button" onClick={onClose}>{t('settings.dialog.cancel')}</button>
          <button type="button" onClick={save} className="bg-primary text-primary-foreground">{t('settings.dialog.save')}</button>
        </div>
      </div>
    </div>
  )
}

export default SelectionFilterListModal
