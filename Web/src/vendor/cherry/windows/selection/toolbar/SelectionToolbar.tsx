// Adapted from Cherry Studio src/renderer/windows/selection/toolbar/SelectionToolbar.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import type { FC } from 'react'
import { useCallback, useEffect, useMemo, useRef, useState, useSyncExternalStore } from 'react'

import { nativeBridge } from '../../../../../bridge/nativeBridge'
import type { SelectionActionItem } from '../../../../../bridge/types'
import { preferenceStore } from '../../../../../preferences/store'
import SelectionToolbarView from '../../../components/selection/SelectionToolbarView'

const getCssPixelValue = (value: string) => Number.parseFloat(value) || 0

const getElementOuterSize = (element: HTMLElement) => {
  const rect = element.getBoundingClientRect()
  const style = window.getComputedStyle(element)

  return {
    width: rect.width + getCssPixelValue(style.marginLeft) + getCssPixelValue(style.marginRight),
    height: rect.height + getCssPixelValue(style.marginTop) + getCssPixelValue(style.marginBottom)
  }
}

//tell main the actual size of the content
const updateWindowSize = (contentElement?: HTMLElement | null) => {
  const rootElement = document.getElementById('root')
  const targetElement =
    contentElement ??
    (rootElement?.firstElementChild instanceof HTMLElement ? rootElement.firstElementChild : rootElement)

  if (!targetElement) {
    console.error('Toolbar content element not found')
    return
  }

  const { width, height } = getElementOuterSize(targetElement)

  // ceil to whole pixels so the OS window never clips sub-pixel content
  nativeBridge.send({
    type: 'selection.determineToolbarSize',
    width: Math.ceil(width),
    height: Math.ceil(height)
  })
}

const SelectionToolbar: FC = () => {
  const preferences = useSyncExternalStore(preferenceStore.subscribe, preferenceStore.getSnapshot)
  const isCompact = preferences.compact
  const actionItems = preferences.actionItems
  const [copyIconStatus, setCopyIconStatus] = useState<'normal' | 'success' | 'fail'>('normal')
  const [copyIconAnimation, setCopyIconAnimation] = useState<'none' | 'enter' | 'exit'>('none')
  const copyIconTimer = useRef<number | undefined>(undefined)
  const toolbarRef = useRef<HTMLDivElement>(null)

  const clearCopyIconTimer = useCallback(() => {
    if (copyIconTimer.current !== undefined) {
      window.clearTimeout(copyIconTimer.current)
      copyIconTimer.current = undefined
    }
  }, [])

  const setCopyIconTimer = useCallback((callback: () => void, delay: number) => {
    clearCopyIconTimer()
    copyIconTimer.current = window.setTimeout(callback, delay)
  }, [clearCopyIconTimer])

  const realActionItems = useMemo(() => {
    return actionItems?.filter((item) => item.enabled)
  }, [actionItems])

  const selectedText = useRef('')
  // [macOS] only macOS has the fullscreen mode
  const isFullScreen = useRef(false)

  const onHideCleanUp = useCallback(() => {
    setCopyIconStatus('normal')
    setCopyIconAnimation('none')
    clearCopyIconTimer()
  }, [clearCopyIconTimer])

  // listen to selection events pushed from main
  useEffect(() => nativeBridge.on('selection.textSelected', (event) => {
    selectedText.current = event.text
    isFullScreen.current = event.isFullscreen ?? false
  }), [])

  useEffect(() => nativeBridge.on('toolbar.visibilityChanged', (event) => {
    if (!event.visible) {
      updateWindowSize(toolbarRef.current)
      onHideCleanUp()
    }
  }), [onHideCleanUp])

  useEffect(() => clearCopyIconTimer, [clearCopyIconTimer])

  //make sure the toolbar size is updated when the compact mode/actionItems is changed
  useEffect(() => {
    updateWindowSize(toolbarRef.current)
  }, [isCompact, actionItems])

  /**
   * Check if text is a valid URI or file path
   */
  const isUriOrFilePath = (text: string): boolean => {
    const trimmed = text.trim()
    // Must not contain newlines or whitespace
    if (/\s/.test(trimmed)) {
      return false
    }
    // URI patterns: http://, https://, ftp://, file://, etc.
    if (/^[a-zA-Z][a-zA-Z0-9+.-]*:\/\//.test(trimmed)) {
      return true
    }
    // Windows absolute path: C:\, D:\, etc.
    if (/^[a-zA-Z]:[/\\]/.test(trimmed)) {
      return true
    }
    // Unix absolute path: /path/to/file
    if (/^\/[^/]/.test(trimmed)) {
      return true
    }
    return false
  }

  // copy selected text to clipboard
  const handleCopy = useCallback(() => {
    if (selectedText.current) {
      const result = nativeBridge.send({ type: 'selection.copySelectedText', selectedText: selectedText.current })

      setCopyIconStatus(result ? 'success' : 'fail')
      setCopyIconAnimation('enter')
      setCopyIconTimer(
        () => {
          setCopyIconAnimation('exit')
        },
        2000
      )
    }
  }, [setCopyIconTimer])

  const handleSearch = useCallback((action: SelectionActionItem) => {
    if (!action.selectedText) return

    const selectedText = action.selectedText.trim()

    let actionString = ''
    if (isUriOrFilePath(selectedText)) {
      actionString = selectedText
    } else {
      if (!action.searchEngine) return

      const customUrl = action.searchEngine.split('|')[1]
      if (!customUrl) return

      actionString = customUrl.replace('{{queryString}}', encodeURIComponent(selectedText))
    }

    nativeBridge.send({ type: 'system.openURL', url: actionString })
  }, [])

  /**
   * Quote the selected text to the inputbar of the main window
   */
  const handleQuote = (action: SelectionActionItem) => {
    if (action.selectedText) {
      nativeBridge.send({
        type: 'selection.performAction',
        actionId: action.id,
        selectedText: action.selectedText
      })
    }
  }

  const handleDefaultAction = (action: SelectionActionItem) => {
    if (action.selectedText) {
      // Fullscreen positioning remains native; the web action contract only carries action and text.
      void isFullScreen.current
      nativeBridge.send({
        type: 'selection.performAction',
        actionId: action.id,
        selectedText: action.selectedText
      })
    }
  }

  const handleAction = useCallback(
    (action: SelectionActionItem) => {
      /** avoid mutating the original action, it will cause syncing issue */
      const newAction = { ...action, selectedText: selectedText.current }

      switch (action.id) {
        case 'copy':
          handleCopy()
          break
        case 'search':
          handleSearch(newAction)
          break
        case 'quote':
          handleQuote(newAction)
          break
        default:
          handleDefaultAction(newAction)
          break
      }
    },
    [handleCopy, handleSearch]
  )

  return (
    <SelectionToolbarView
      ref={toolbarRef}
      actionItems={realActionItems}
      isCompact={isCompact}
      handleAction={handleAction}
      copyIconStatus={copyIconStatus}
      copyIconAnimation={copyIconAnimation}
      draggable
    />
  )
}

export default SelectionToolbar
