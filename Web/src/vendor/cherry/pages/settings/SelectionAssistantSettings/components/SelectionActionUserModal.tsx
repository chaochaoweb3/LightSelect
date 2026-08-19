// Adapted from Cherry Studio src/renderer/pages/settings/SelectionAssistantSettings/components/SelectionActionUserModal.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import type { FC } from 'react'
import { useEffect, useState } from 'react'

import type { SelectionActionItem } from '../../../../../../bridge/types'
import { useTranslation } from '../../../../../../adapters/i18n'

type Props = {
  editingAction: SelectionActionItem | null
  onSave: (action: SelectionActionItem) => void
  onClose: () => void
}

const SelectionActionUserModal: FC<Props> = ({ editingAction, onSave, onClose }) => {
  const { t } = useTranslation()
  const [name, setName] = useState('')
  const [icon, setIcon] = useState('message-square-heart')
  const [prompt, setPrompt] = useState('')

  useEffect(() => {
    setName(editingAction?.name ?? '')
    setIcon(editingAction?.icon ?? 'message-square-heart')
    setPrompt(editingAction?.prompt ?? '')
  }, [editingAction])

  const save = (): void => {
    if (!name.trim() || !prompt.trim()) return
    onSave({
      id: editingAction?.id ?? `custom-${Date.now()}`,
      name: name.trim(),
      icon: icon.trim() || 'message-square-heart',
      prompt: prompt.trim(),
      enabled: editingAction?.enabled ?? false,
      isBuiltIn: false
    })
  }

  return (
    <div role="dialog" aria-label={t('settings.dialog.customAction')} aria-modal="true" className="lightselect-modal">
      <div className="lightselect-dialog w-[min(440px,calc(100vw-32px))]">
        <h2 className="font-semibold text-base">{t('settings.dialog.customAction')}</h2>
        <label className="lightselect-field">
          <span>{t('settings.dialog.name')}</span>
          <input aria-label={t('settings.dialog.name')} value={name} onChange={(event) => setName(event.currentTarget.value)} />
        </label>
        <label className="lightselect-field">
          <span>{t('settings.dialog.icon')}</span>
          <input aria-label={t('settings.dialog.icon')} value={icon} onChange={(event) => setIcon(event.currentTarget.value)} />
        </label>
        <label className="lightselect-field">
          <span>{t('settings.dialog.prompt')}</span>
          <textarea
            aria-label={t('settings.dialog.prompt')}
            rows={5}
            value={prompt}
            onChange={(event) => setPrompt(event.currentTarget.value)}
          />
          <small className="text-muted-foreground">{t('settings.dialog.promptHint', { placeholder: '{{text}}' })}</small>
        </label>
        <div className="lightselect-dialog-footer">
          <button type="button" onClick={onClose}>{t('settings.dialog.cancel')}</button>
          <button type="button" onClick={save} className="bg-primary text-primary-foreground">{t('settings.dialog.save')}</button>
        </div>
      </div>
    </div>
  )
}

export default SelectionActionUserModal
