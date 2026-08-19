import '../adapters/i18n'
import '../styles/settings.css'

import { createRoot } from 'react-dom/client'

import { ErrorBoundary } from '../adapters/ErrorBoundary'
import { ThemeProvider } from '../adapters/theme'
import SelectionAssistantSettings from '../vendor/cherry/pages/settings/SelectionAssistantSettings/SelectionAssistantSettings'

const root = createRoot(document.getElementById('root') as HTMLElement)
root.render(
  <ErrorBoundary>
    <ThemeProvider>
      <SelectionAssistantSettings />
    </ThemeProvider>
  </ErrorBoundary>
)
