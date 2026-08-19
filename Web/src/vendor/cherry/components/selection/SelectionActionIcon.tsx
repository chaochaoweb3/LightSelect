// Adapted from Cherry Studio src/renderer/components/selection/SelectionActionIcon.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import { ClipboardCopy, FileQuestion, Languages, Quote, ScanText, Search, WandSparkles } from '../../../../adapters/icons'
import type { ComponentProps, FC, ReactNode } from 'react'
import { lazy, Suspense } from 'react'

const DynamicSelectionActionIcon = lazy(() => import('./DynamicSelectionActionIcon'))

type StaticSelectionActionIcon = typeof Languages

const BUILT_IN_SELECTION_ACTION_ICONS: Record<string, StaticSelectionActionIcon> = {
  'clipboard-copy': ClipboardCopy,
  'file-question': FileQuestion,
  languages: Languages,
  quote: Quote,
  'scan-text': ScanText,
  search: Search,
  'wand-sparkles': WandSparkles
}

type SelectionActionIconProps = ComponentProps<StaticSelectionActionIcon> & {
  fallback?: () => ReactNode
  name?: string
}

const SelectionActionIcon: FC<SelectionActionIconProps> = ({ fallback, name, ...props }) => {
  const BuiltInIcon = name ? BUILT_IN_SELECTION_ACTION_ICONS[name] : undefined

  if (BuiltInIcon) {
    return <BuiltInIcon {...props} />
  }

  if (!name) {
    return fallback?.() ?? null
  }

  return (
    <Suspense fallback={fallback?.() ?? null}>
      <DynamicSelectionActionIcon fallback={fallback} name={name} {...props} />
    </Suspense>
  )
}

export default SelectionActionIcon
