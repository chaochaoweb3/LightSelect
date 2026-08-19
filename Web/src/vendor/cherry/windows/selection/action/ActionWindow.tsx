// Adapted from Cherry Studio src/renderer/windows/selection/action/ActionWindow.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import { Droplet, Pin, X } from 'lucide-react'
import type { FC } from 'react'
import { useEffect, useRef, useState, useSyncExternalStore } from 'react'

import { actionStore } from '../../../../../action/actionStore'
import { cn } from '../../../../../adapters/cn'
import { useTranslation } from '../../../../../adapters/i18n'
import { nativeBridge } from '../../../../../bridge/nativeBridge'
import { preferenceStore } from '../../../../../preferences/store'
import SelectionActionIcon from '../../../components/selection/SelectionActionIcon'
import ActionGeneral from './components/ActionGeneral'
import ActionTranslate from './components/ActionTranslate'

const ActionWindow: FC = () => {
  const state = useSyncExternalStore(actionStore.subscribe, actionStore.getSnapshot)
  const preferences = useSyncExternalStore(preferenceStore.subscribe, preferenceStore.getSnapshot)
  const { t } = useTranslation()
  const [isPinned, setIsPinned] = useState(preferences.autoPin)
  const [isWindowFocus, setIsWindowFocus] = useState(true)
  const [showOpacitySlider, setShowOpacitySlider] = useState(false)
  const [opacity, setOpacity] = useState(preferences.actionWindowOpacity)
  const shouldCloseWhenBlur = useRef(false)
  const contentElementRef = useRef<HTMLDivElement>(null)
  const autoPinRef = useRef(preferences.autoPin)
  const defaultOpacityRef = useRef(preferences.actionWindowOpacity)
  autoPinRef.current = preferences.autoPin
  defaultOpacityRef.current = preferences.actionWindowOpacity

  useEffect(() => {
    setIsPinned(autoPinRef.current)
    nativeBridge.send({ type: 'action.pin', pinned: autoPinRef.current })
    setOpacity(defaultOpacityRef.current)
    setShowOpacitySlider(false)
    if (typeof contentElementRef.current?.scrollTo === 'function') {
      contentElementRef.current.scrollTo({ top: 0 })
    }
  }, [state.requestId])

  useEffect(() => {
    setIsPinned(preferences.autoPin)
    nativeBridge.send({ type: 'action.pin', pinned: preferences.autoPin })
  }, [preferences.autoPin])

  useEffect(() => {
    setOpacity(preferences.actionWindowOpacity)
  }, [preferences.actionWindowOpacity])

  useEffect(() => {
    shouldCloseWhenBlur.current = preferences.autoClose && !isPinned
  }, [preferences.autoClose, isPinned])

  useEffect(() => {
    const handleWindowFocus = (): void => setIsWindowFocus(true)
    const handleWindowBlur = (): void => {
      if (shouldCloseWhenBlur.current) {
        nativeBridge.send({ type: 'action.close' })
      } else {
        setIsWindowFocus(false)
      }
    }
    window.addEventListener('focus', handleWindowFocus)
    window.addEventListener('blur', handleWindowBlur)
    return () => {
      window.removeEventListener('focus', handleWindowFocus)
      window.removeEventListener('blur', handleWindowBlur)
    }
  }, [])

  useEffect(() => {
    if (typeof contentElementRef.current?.scrollTo === 'function') {
      contentElementRef.current.scrollTo({ top: contentElementRef.current.scrollHeight, behavior: 'smooth' })
    }
  }, [state.content])

  const title = state.action ? (state.action.isBuiltIn ? t(state.action.name) : state.action.name) : ''
  useEffect(() => {
    if (title) document.title = `${title} - ${t('selection.name')}`
  }, [title, t])

  if (!state.action || !state.requestId) return null
  const action = state.action

  const togglePin = (): void => {
    const pinned = !isPinned
    setIsPinned(pinned)
    nativeBridge.send({ type: 'action.pin', pinned })
  }

  const changeOpacity = (nextOpacity: number): void => {
    setOpacity(nextOpacity)
    nativeBridge.send({ type: 'action.setOpacity', opacity: nextOpacity })
  }

  return (
    <div
      data-ui="selection.action"
      className="relative m-0.5 flex h-[calc(100%-6px)] w-[calc(100%-6px)] flex-col overflow-hidden rounded-lg border border-border bg-popover shadow-[0_0_2px_var(--border)]"
      style={{ opacity: opacity / 100 }}>
      <div
        className={cn(
          'flex h-8 shrink-0 flex-row items-center px-2 transition-colors duration-300 [-webkit-app-region:drag]',
          isWindowFocus ? 'bg-muted' : 'bg-secondary'
        )}
        style={{ paddingLeft: '78px' }}>
        {action.icon && (
          <div className="ml-1 flex items-center justify-center">
            <SelectionActionIcon name={action.icon} size={14} className="text-foreground" fallback={() => null} />
          </div>
        )}
        <div className="ml-2 flex-1 overflow-hidden text-ellipsis whitespace-nowrap font-normal text-foreground text-sm">
          {title}
        </div>
        <div className="relative flex gap-2 [-webkit-app-region:no-drag]">
          <button
            type="button"
            aria-label={t('selection.action.window.pin')}
            aria-pressed={isPinned}
            title={isPinned ? t('selection.action.window.pinned') : t('selection.action.window.pin')}
            onClick={togglePin}
            className={cn(
              'flex size-6 items-center justify-center rounded border-0 bg-transparent p-0 text-muted-foreground shadow-none transition-colors hover:bg-accent hover:text-accent-foreground',
              isPinned && 'bg-accent text-accent-foreground hover:bg-accent'
            )}>
            <Pin className={cn('size-[13px] transition-transform', isPinned && 'rotate-45 text-accent-foreground')} />
          </button>
          <button
            type="button"
            aria-label={t('selection.action.window.opacity')}
            title={t('selection.action.window.opacity')}
            onClick={() => setShowOpacitySlider(!showOpacitySlider)}
            className={cn(
              'flex size-6 items-center justify-center rounded border-0 bg-transparent p-0 pb-0.5 text-muted-foreground shadow-none transition-colors hover:bg-accent hover:text-accent-foreground',
              showOpacitySlider && 'bg-accent text-accent-foreground hover:bg-accent'
            )}>
            <Droplet className="size-[13px]" />
          </button>
          <button
            type="button"
            aria-label={t('selection.action.window.close')}
            title={t('selection.action.window.close')}
            onClick={() => nativeBridge.send({ type: 'action.close' })}
            className="flex size-6 items-center justify-center rounded border-0 bg-transparent p-0 text-muted-foreground shadow-none transition-colors hover:bg-error-subtle hover:text-error">
            <X className="size-[14px]" aria-hidden="true" />
          </button>
          {showOpacitySlider && (
            <div className="absolute top-full right-0 z-[80] mt-2 flex h-[120px] items-center justify-center rounded bg-popover px-2 pt-4 pb-3 opacity-100! shadow-md">
              <input
                type="range"
                aria-label={t('selection.action.window.opacity')}
                min={20}
                max={100}
                value={opacity}
                onChange={(event) => changeOpacity(Number(event.currentTarget.value))}
                className="h-[90px] w-5 accent-primary"
                style={{ writingMode: 'vertical-lr', direction: 'rtl' }}
              />
            </div>
          )}
        </div>
      </div>
      <div className="flex min-h-0 w-full flex-1 justify-center overflow-auto">
        <div
          ref={contentElementRef}
          className="flex max-w-[1280px] flex-1 select-text flex-col overflow-auto p-4 pb-10 text-sm [-webkit-app-region:no-drag]">
          {action.id === 'translate' ? (
            <ActionTranslate
              key={state.requestId}
              requestId={state.requestId}
              selectedText={state.selectedText}
              content={state.content}
              status={state.status}
              error={state.error}
            />
          ) : (
            <ActionGeneral
              key={state.requestId}
              action={action}
              requestId={state.requestId}
              selectedText={state.selectedText}
              content={state.content}
              status={state.status}
              error={state.error}
            />
          )}
        </div>
      </div>
    </div>
  )
}

export default ActionWindow
