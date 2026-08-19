import type { FC, PropsWithChildren } from 'react'
import { useEffect } from 'react'

import { nativeBridge } from '../bridge/nativeBridge'
import type { AppearanceMode } from '../bridge/types'

const applyAppearance = (mode: AppearanceMode): void => {
  document.documentElement.classList.toggle('dark', mode === 'dark')
  document.documentElement.style.colorScheme = mode
}

export const ThemeProvider: FC<PropsWithChildren> = ({ children }) => {
  useEffect(() => {
    const prefersDark = window.matchMedia?.('(prefers-color-scheme: dark)').matches ?? false
    applyAppearance(prefersDark ? 'dark' : 'light')
    const unsubscribe = nativeBridge.on('appearance.changed', (event) => applyAppearance(event.mode))
    document.documentElement.dataset.lightselectReady = 'true'
    return () => {
      unsubscribe()
      delete document.documentElement.dataset.lightselectReady
    }
  }, [])

  return children
}
