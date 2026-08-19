import { describe, expect, it, vi } from 'vitest'

import { getSelectionActionErrorMessage } from '../../vendor/cherry/windows/selection/action/errorMessage'

describe('Cherry selection action error message', () => {
  it('localizes controlled translation error keys', () => {
    const translate = vi.fn(() => 'Translation model is not configured')

    expect(getSelectionActionErrorMessage(new Error('translate.error.not_configured'), translate)).toBe(
      'Translation model is not configured'
    )
    expect(translate).toHaveBeenCalledWith('translate.error.not_configured')
  })

  it('preserves native bridge and unknown error messages', () => {
    const translate = vi.fn((key: string) => key)

    expect(getSelectionActionErrorMessage(new Error('Provider returned an unexpected response'), translate)).toBe(
      'Provider returned an unexpected response'
    )
    expect(getSelectionActionErrorMessage('Timed out', translate)).toBe('Timed out')
    expect(translate).not.toHaveBeenCalled()
  })
})
