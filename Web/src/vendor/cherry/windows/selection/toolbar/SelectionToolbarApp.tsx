// Adapted from Cherry Studio src/renderer/windows/selection/toolbar/SelectionToolbarApp.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import type { FC } from 'react'

import { ErrorBoundary } from '../../../../../adapters/ErrorBoundary'
import { ThemeProvider } from '../../../../../adapters/theme'
import SelectionToolbar from './SelectionToolbar'

const SelectionToolbarApp: FC = () => {
  return (
    // The boundary must stay the ANCESTOR of the provider so a provider throwing
    // during render falls back instead of white-screening.
    <ErrorBoundary>
      <ThemeProvider>
        <SelectionToolbar />
      </ThemeProvider>
    </ErrorBoundary>
  )
}

export default SelectionToolbarApp
