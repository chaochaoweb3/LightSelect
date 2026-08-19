// Adapted from Cherry Studio src/renderer/pages/settings/SelectionAssistantSettings/components/SelectionActionSearchModal.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import type { FC } from 'react'
import { useState } from 'react'

import { useTranslation } from '../../../../../../adapters/i18n'

const SelectionActionSearchModal: FC<{
  searchEngine: string
  onSave: (searchEngine: string) => void
  onClose: () => void
}> = ({ searchEngine, onSave, onClose }) => {
  const { t } = useTranslation()
  const [value, setValue] = useState(searchEngine)

  return (
    <div role="dialog" aria-label={t('settings.dialog.search')} aria-modal="true" className="lightselect-modal">
      <div className="lightselect-dialog w-[min(480px,calc(100vw-32px))]">
        <h2 className="font-semibold text-base">{t('settings.dialog.search')}</h2>
        <label className="lightselect-field">
          <span>{t('settings.dialog.searchURL')}</span>
          <input aria-label={t('settings.dialog.searchURL')} value={value} onChange={(event) => setValue(event.currentTarget.value)} />
          <small className="text-muted-foreground">{t('settings.dialog.searchHint', { placeholder: '{{queryString}}' })}</small>
        </label>
        <div className="lightselect-dialog-footer">
          <button type="button" onClick={onClose}>{t('settings.dialog.cancel')}</button>
          <button type="button" onClick={() => onSave(value.trim())} className="bg-primary text-primary-foreground">
            {t('settings.dialog.save')}
          </button>
        </div>
      </div>
    </div>
  )
}

export default SelectionActionSearchModal
