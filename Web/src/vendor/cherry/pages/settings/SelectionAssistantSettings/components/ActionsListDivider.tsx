// Adapted from Cherry Studio src/renderer/pages/settings/SelectionAssistantSettings/components/ActionsListDivider.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import type { FC } from 'react'

const ActionsListDivider: FC<{ enabledCount: number; maxEnabled: number }> = ({ enabledCount, maxEnabled }) => (
  <div className="my-2 flex items-center gap-3 text-muted-foreground text-xs">
    <span className="h-px flex-1 bg-border" />
    <span>{`${enabledCount} / ${maxEnabled}`}</span>
    <span className="h-px flex-1 bg-border" />
  </div>
)

export default ActionsListDivider
