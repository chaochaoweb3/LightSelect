// Adapted from Cherry Studio src/renderer/pages/settings/SelectionAssistantSettings/components/SelectionActionsList.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import type { FC } from 'react'

import type { SelectionActionItem } from '../../../../../../bridge/types'
import SelectionToolbarView from '../../../../components/selection/SelectionToolbarView'
import { MAX_CUSTOM_ITEMS, MAX_ENABLED_ITEMS, useActionItems } from '../hooks/useSettingsActionsList'
import ActionsList from './ActionsList'
import ActionsListDivider from './ActionsListDivider'
import SelectionActionSearchModal from './SelectionActionSearchModal'
import SelectionActionUserModal from './SelectionActionUserModal'
import SettingsActionsListHeader from './SettingsActionsListHeader'

const SelectionActionsList: FC<{
  items: SelectionActionItem[]
  compact: boolean
  onChange: (items: SelectionActionItem[]) => void
}> = ({ items, compact, onChange }) => {
  const actions = useActionItems(items, onChange)

  const edit = (item: SelectionActionItem): void => {
    if (item.id === 'search') actions.setIsSearchModalOpen(true)
    else if (!item.isBuiltIn) actions.setUserEditingAction(item)
  }

  return (
    <section className="lightselect-settings-section">
      <SettingsActionsListHeader
        disabled={actions.customItemsCount >= MAX_CUSTOM_ITEMS}
        onAdd={() => actions.setUserEditingAction(null)}
      />
      <div className="my-5 flex min-h-12 items-center justify-center overflow-x-auto py-1">
        <SelectionToolbarView
          actionItems={items.filter((item) => item.enabled)}
          isCompact={compact}
          handleAction={() => {}}
          copyIconStatus="normal"
          copyIconAnimation="none"
        />
      </div>
      <ActionsList
        items={items}
        onToggle={actions.toggle}
        onMove={actions.move}
        onEdit={edit}
        onDelete={actions.deleteAction}
      />
      <ActionsListDivider enabledCount={items.filter((item) => item.enabled).length} maxEnabled={MAX_ENABLED_ITEMS} />

      {actions.userEditingAction !== undefined && (
        <SelectionActionUserModal
          editingAction={actions.userEditingAction}
          onSave={actions.saveUserAction}
          onClose={() => actions.setUserEditingAction(undefined)}
        />
      )}
      {actions.isSearchModalOpen && (
        <SelectionActionSearchModal
          searchEngine={items.find((item) => item.id === 'search')?.searchEngine ?? ''}
          onSave={actions.saveSearch}
          onClose={() => actions.setIsSearchModalOpen(false)}
        />
      )}
    </section>
  )
}

export default SelectionActionsList
