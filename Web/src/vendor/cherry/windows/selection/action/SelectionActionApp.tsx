// Adapted from Cherry Studio src/renderer/windows/selection/action/SelectionActionApp.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import type { FC } from 'react'

import { ErrorBoundary } from '../../../../../adapters/ErrorBoundary'
import { ThemeProvider } from '../../../../../adapters/theme'
import ActionWindow from './ActionWindow'

const SelectionActionApp: FC = () => (
  <ErrorBoundary>
    <ThemeProvider>
      <ErrorBoundary>
        <ActionWindow />
      </ErrorBoundary>
    </ThemeProvider>
  </ErrorBoundary>
)

export default SelectionActionApp
