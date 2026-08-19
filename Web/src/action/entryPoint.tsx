import '../adapters/i18n'
import '../styles/action.css'

import { createRoot } from 'react-dom/client'

import SelectionActionApp from '../vendor/cherry/windows/selection/action/SelectionActionApp'

const root = createRoot(document.getElementById('root') as HTMLElement)
root.render(<SelectionActionApp />)
