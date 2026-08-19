// Adapted from Cherry Studio src/renderer/pages/settings/SelectionAssistantSettings/components/SettingsActionsListHeader.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import { Plus } from 'lucide-react'
import type { FC } from 'react'

import { useTranslation } from '../../../../../../adapters/i18n'

const SettingsActionsListHeader: FC<{ disabled: boolean; onAdd: () => void }> = ({ disabled, onAdd }) => {
  const { t } = useTranslation()
  return (
    <div className="flex items-center gap-3">
      <h2 className="flex-1 font-medium text-[15px]">{t('settings.actions')}</h2>
      <button
        type="button"
        disabled={disabled}
        onClick={onAdd}
        aria-label={t('settings.actions.add')}
        className="inline-flex h-8 items-center gap-1 rounded border border-border px-2 text-sm hover:bg-accent disabled:opacity-40">
        <Plus className="size-4" />
        {t('settings.actions.custom')}
      </button>
    </div>
  )
}

export default SettingsActionsListHeader
