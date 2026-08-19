import { describe, expect, it } from 'vitest'

import { defaultSelectionPreferences } from '../defaults'
import { createPreferenceStore } from '../store'

describe('selection preference defaults', () => {
  it('matches Cherry Studio action order and enabled state', () => {
    expect(defaultSelectionPreferences.actionItems.map(({ id, enabled }) => ({ id, enabled }))).toEqual([
      { id: 'translate', enabled: true },
      { id: 'explain', enabled: true },
      { id: 'summary', enabled: true },
      { id: 'search', enabled: true },
      { id: 'copy', enabled: true },
      { id: 'refine', enabled: false },
      { id: 'quote', enabled: false }
    ])
  })
})

describe('preferenceStore', () => {
  it('defaults to Chinese and accepts an English bootstrap language', () => {
    const store = createPreferenceStore()
    expect(store.getSnapshot().interfaceLanguage).toBe('zh-CN')

    store.applyEvent({
      type: 'bootstrap',
      hasAPIKey: false,
      preferences: { ...defaultSelectionPreferences, interfaceLanguage: 'en-US' }
    })

    expect(store.getSnapshot().interfaceLanguage).toBe('en-US')
  })

  it('replaces the complete snapshot on bootstrap', () => {
    const store = createPreferenceStore()
    const bootstrap = {
      ...defaultSelectionPreferences,
      enabled: true,
      compact: true,
      actionWindowOpacity: 72
    }

    store.applyEvent({ type: 'bootstrap', preferences: bootstrap, hasAPIKey: true })

    expect(store.getSnapshot()).toEqual(bootstrap)
    expect(store.hasAPIKey()).toBe(true)
  })

  it('immutably replaces only the named key on a preference change', () => {
    const store = createPreferenceStore()
    const before = store.getSnapshot()

    store.applyEvent({ type: 'preferences.changed', key: 'compact', value: true })

    const after = store.getSnapshot()
    expect(after).not.toBe(before)
    expect(after.compact).toBe(true)
    expect(after.actionItems).toBe(before.actionItems)
    expect(before.compact).toBe(false)
  })

  it('rolls back a matching failed save and ignores a stale failure', () => {
    const store = createPreferenceStore()
    store.beginUpdate('save-1', 'compact', true)
    expect(store.getSnapshot().compact).toBe(true)
    expect(store.getSaveSnapshot()).toEqual({ phase: 'saving', requestId: 'save-1' })

    store.beginUpdate('save-2', 'compact', false)
    store.applyEvent({ type: 'preferences.saveFailed', requestId: 'save-1', key: 'compact' })
    expect(store.getSnapshot().compact).toBe(false)
    expect(store.getSaveSnapshot()).toEqual({ phase: 'saving', requestId: 'save-2' })

    store.applyEvent({ type: 'preferences.saveFailed', requestId: 'save-2', key: 'compact' })
    expect(store.getSnapshot().compact).toBe(false)
    expect(store.getSaveSnapshot()).toEqual({ phase: 'failed', requestId: 'save-2' })
  })

  it('confirms only the matching save acknowledgement', () => {
    const store = createPreferenceStore()
    store.beginUpdate('save-1', 'interfaceLanguage', 'en-US')
    store.applyEvent({
      type: 'preferences.saved',
      requestId: 'save-1',
      key: 'interfaceLanguage',
      value: 'en-US'
    })

    expect(store.getSnapshot().interfaceLanguage).toBe('en-US')
    expect(store.getSaveSnapshot()).toEqual({ phase: 'saved', requestId: 'save-1' })
  })
})
