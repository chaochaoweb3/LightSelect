import type { SelectionPreferences } from '../bridge/types'

export const defaultSelectionPreferences: SelectionPreferences = {
  interfaceLanguage: 'zh-CN',
  enabled: false,
  actionItems: [
    {
      enabled: true,
      icon: 'languages',
      id: 'translate',
      isBuiltIn: true,
      name: 'selection.action.builtin.translate'
    },
    {
      enabled: true,
      icon: 'file-question',
      id: 'explain',
      isBuiltIn: true,
      name: 'selection.action.builtin.explain'
    },
    {
      enabled: true,
      icon: 'scan-text',
      id: 'summary',
      isBuiltIn: true,
      name: 'selection.action.builtin.summary'
    },
    {
      enabled: true,
      icon: 'search',
      id: 'search',
      isBuiltIn: true,
      name: 'selection.action.builtin.search',
      searchEngine: 'Google|https://www.google.com/search?q={{queryString}}'
    },
    {
      enabled: true,
      icon: 'clipboard-copy',
      id: 'copy',
      isBuiltIn: true,
      name: 'selection.action.builtin.copy'
    },
    {
      enabled: false,
      icon: 'wand-sparkles',
      id: 'refine',
      isBuiltIn: true,
      name: 'selection.action.builtin.refine'
    },
    {
      enabled: false,
      icon: 'quote',
      id: 'quote',
      isBuiltIn: true,
      name: 'selection.action.builtin.quote'
    }
  ],
  actionWindowOpacity: 100,
  autoClose: false,
  autoPin: false,
  compact: false,
  filterList: [],
  filterMode: 'default',
  followToolbar: true,
  rememberWindowSize: false,
  triggerMode: 'selected',
  api: {
    baseURL: 'https://api.openai.com/v1',
    model: 'gpt-4.1-mini',
    sourceLanguage: 'auto',
    targetLanguage: 'zh-cn',
    timeoutSeconds: 60
  }
}
