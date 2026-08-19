// Adapted from Cherry Studio src/renderer/pages/settings/SelectionAssistantSettings/hooks/useSettingsActionsList.ts @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import { useMemo, useState } from 'react'

import type { SelectionActionItem } from '../../../../../../bridge/types'

export const MAX_CUSTOM_ITEMS = 10
export const MAX_ENABLED_ITEMS = 8

export const useActionItems = (
  items: SelectionActionItem[],
  setItems: (items: SelectionActionItem[]) => void
) => {
  const [userEditingAction, setUserEditingAction] = useState<SelectionActionItem | null | undefined>(undefined)
  const [isSearchModalOpen, setIsSearchModalOpen] = useState(false)
  const enabledCount = useMemo(() => items.filter((item) => item.enabled).length, [items])
  const customItemsCount = useMemo(() => items.filter((item) => !item.isBuiltIn).length, [items])

  const toggle = (id: string): void => {
    const item = items.find((candidate) => candidate.id === id)
    if (!item) return
    if (item.enabled && enabledCount === 1) return
    if (!item.enabled && enabledCount >= MAX_ENABLED_ITEMS) return
    setItems(items.map((candidate) => (candidate.id === id ? { ...candidate, enabled: !candidate.enabled } : candidate)))
  }

  const move = (id: string, direction: -1 | 1): void => {
    const index = items.findIndex((item) => item.id === id)
    const destination = index + direction
    if (index < 0 || destination < 0 || destination >= items.length) return
    const next = [...items]
    const [item] = next.splice(index, 1)
    next.splice(destination, 0, item)
    setItems(next)
  }

  const saveUserAction = (action: SelectionActionItem): void => {
    if (userEditingAction) {
      setItems(items.map((item) => (item.id === userEditingAction.id ? action : item)))
    } else {
      setItems([...items, action])
    }
    setUserEditingAction(undefined)
  }

  const saveSearch = (searchEngine: string): void => {
    setItems(items.map((item) => (item.id === 'search' ? { ...item, searchEngine } : item)))
    setIsSearchModalOpen(false)
  }

  return {
    customItemsCount,
    isSearchModalOpen,
    userEditingAction,
    setUserEditingAction,
    setIsSearchModalOpen,
    toggle,
    move,
    saveUserAction,
    saveSearch,
    deleteAction: (id: string) => setItems(items.filter((item) => item.isBuiltIn || item.id !== id))
  }
}
