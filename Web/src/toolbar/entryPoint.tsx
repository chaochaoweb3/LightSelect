import '../adapters/i18n'
import '../styles/cherry-theme.css'

import { createRoot } from 'react-dom/client'

import SelectionToolbarApp from '../vendor/cherry/windows/selection/toolbar/SelectionToolbarApp'

const root = createRoot(document.getElementById('root') as HTMLElement)
root.render(<SelectionToolbarApp />)
