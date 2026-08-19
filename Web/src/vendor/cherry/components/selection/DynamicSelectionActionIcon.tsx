// Adapted from Cherry Studio src/renderer/components/selection/DynamicSelectionActionIcon.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import { icons, type LucideIcon, type LucideProps } from 'lucide-react'
import type { FC, ReactNode } from 'react'

type DynamicSelectionActionIconProps = LucideProps & {
  fallback?: () => ReactNode
  name: string
}

const toLucideExportName = (name: string): string =>
  name
    .split('-')
    .filter(Boolean)
    .map((part) => part.charAt(0).toUpperCase() + part.slice(1))
    .join('')

const DynamicSelectionActionIcon: FC<DynamicSelectionActionIconProps> = ({ fallback, name, ...props }) => {
  const Icon = icons[toLucideExportName(name) as keyof typeof icons] as LucideIcon | undefined
  return Icon ? <Icon {...props} /> : (fallback?.() ?? null)
}

export default DynamicSelectionActionIcon
