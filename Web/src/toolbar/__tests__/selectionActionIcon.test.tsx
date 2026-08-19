import { render, screen, waitFor } from '@testing-library/react'
import { describe, expect, it } from 'vitest'

import SelectionActionIcon from '../../vendor/cherry/components/selection/SelectionActionIcon'

describe('Cherry SelectionActionIcon', () => {
  it.each(['languages', 'file-question', 'scan-text', 'search', 'clipboard-copy', 'wand-sparkles', 'quote'])(
    'renders built-in %s without showing a fallback',
    (name) => {
      render(
        <SelectionActionIcon
          name={name}
          data-testid="selection-action-icon"
          fallback={() => <span data-testid="selection-action-fallback" />}
        />
      )

      expect(screen.getByTestId('selection-action-icon')).toBeInTheDocument()
      expect(screen.queryByTestId('selection-action-fallback')).not.toBeInTheDocument()
    }
  )

  it('renders the fallback synchronously when the optional icon name is empty', () => {
    render(<SelectionActionIcon fallback={() => <span data-testid="selection-action-fallback" />} />)
    expect(screen.getByTestId('selection-action-fallback')).toBeInTheDocument()
  })

  it('lazy-loads a valid custom Lucide icon and preserves its class', async () => {
    const { container } = render(
      <SelectionActionIcon
        name="alarm-clock"
        className="custom-icon-class"
        fallback={() => <span data-testid="selection-action-fallback" />}
      />
    )

    expect(screen.getByTestId('selection-action-fallback')).toBeInTheDocument()
    await waitFor(() => {
      expect(container.querySelector('.lucide-alarm-clock')).toHaveClass('custom-icon-class')
    })
  })

  it('uses the provided fallback for an unknown custom icon', async () => {
    render(
      <SelectionActionIcon
        name="not-a-real-lucide-icon"
        fallback={() => <span data-testid="selection-action-fallback" />}
      />
    )

    expect(await screen.findByTestId('selection-action-fallback')).toBeInTheDocument()
  })
})
