// Adapted from Cherry Studio src/renderer/pages/settings/SelectionAssistantSettings/components/ActionsListItem.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import { ChevronDown, ChevronUp, GripVertical, Pencil, Trash2 } from 'lucide-react'
import type { FC } from 'react'

import { useTranslation } from '../../../../../../adapters/i18n'
import type { SelectionActionItem } from '../../../../../../bridge/types'
import SelectionActionIcon from '../../../../components/selection/SelectionActionIcon'

type Props = {
  item: SelectionActionItem
  index: number
  count: number
  onToggle: (id: string) => void
  onMove: (id: string, direction: -1 | 1) => void
  onEdit: (item: SelectionActionItem) => void
  onDelete: (id: string) => void
}

const ActionsListItem: FC<Props> = ({ item, index, count, onToggle, onMove, onEdit, onDelete }) => {
  const { t } = useTranslation()
  const name = item.isBuiltIn ? t(item.name) : item.name
  const enableLabel = t('settings.actions.enable', { name })

  return (
    <div className="flex min-h-11 items-center gap-2 border-border border-b py-2 last:border-b-0">
      <GripVertical className="size-4 shrink-0 text-muted-foreground" />
      <SelectionActionIcon name={item.icon} className="size-4 shrink-0" fallback={() => null} />
      <span className="min-w-0 flex-1 truncate text-sm">{name}</span>
      <label className="inline-flex items-center">
        <span className="sr-only">{enableLabel}</span>
        <input
          type="checkbox"
          role="switch"
          aria-label={enableLabel}
          checked={item.enabled}
          onChange={() => onToggle(item.id)}
          className="size-4 accent-primary"
        />
      </label>
      <button type="button" aria-label={t('settings.actions.moveUp', { name })} disabled={index === 0} onClick={() => onMove(item.id, -1)}>
        <ChevronUp className="size-4" />
      </button>
      <button
        type="button"
        aria-label={t('settings.actions.moveDown', { name })}
        disabled={index === count - 1}
        onClick={() => onMove(item.id, 1)}>
        <ChevronDown className="size-4" />
      </button>
      {(item.id === 'search' || !item.isBuiltIn) && (
        <button type="button" aria-label={t('settings.actions.edit', { name })} onClick={() => onEdit(item)}>
          <Pencil className="size-4" />
        </button>
      )}
      {!item.isBuiltIn && (
        <button type="button" aria-label={t('settings.actions.delete', { name })} onClick={() => onDelete(item.id)}>
          <Trash2 className="size-4 text-error" />
        </button>
      )}
    </div>
  )
}

export default ActionsListItem
