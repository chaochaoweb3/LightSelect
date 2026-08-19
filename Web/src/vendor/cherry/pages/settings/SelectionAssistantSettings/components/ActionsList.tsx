// Adapted from Cherry Studio src/renderer/pages/settings/SelectionAssistantSettings/components/ActionsList.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import type { FC } from 'react'

import type { SelectionActionItem } from '../../../../../../bridge/types'
import ActionsListItem from './ActionsListItem'

type Props = {
  items: SelectionActionItem[]
  onToggle: (id: string) => void
  onMove: (id: string, direction: -1 | 1) => void
  onEdit: (item: SelectionActionItem) => void
  onDelete: (id: string) => void
}

const ActionsList: FC<Props> = ({ items, onToggle, onMove, onEdit, onDelete }) => (
  <div className="divide-y-0">
    {items.map((item, index) => (
      <ActionsListItem
        key={item.id}
        item={item}
        index={index}
        count={items.length}
        onToggle={onToggle}
        onMove={onMove}
        onEdit={onEdit}
        onDelete={onDelete}
      />
    ))}
  </div>
)

export default ActionsList
