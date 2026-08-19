import { render } from '@testing-library/react'
import { afterEach, describe, expect, it } from 'vitest'

import { ThemeProvider } from '../theme'

describe('ThemeProvider fixture readiness', () => {
  afterEach(() => {
    delete document.documentElement.dataset.lightselectReady
  })

  it('marks the native bridge ready only while the provider is mounted', () => {
    const view = render(
      <ThemeProvider>
        <div>ready</div>
      </ThemeProvider>
    )

    expect(document.documentElement).toHaveAttribute('data-lightselect-ready', 'true')
    view.unmount()
    expect(document.documentElement).not.toHaveAttribute('data-lightselect-ready')
  })
})
