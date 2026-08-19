// Adapted from Cherry Studio src/renderer/windows/selection/action/components/ActionTranslate.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import { ArrowRight, ChevronDown, Copy, Globe2, Loader2 } from 'lucide-react'
import type { FC } from 'react'
import { useState, useSyncExternalStore } from 'react'

import { cn } from '../../../../../../adapters/cn'
import { useTranslation } from '../../../../../../adapters/i18n'
import { nativeBridge } from '../../../../../../bridge/nativeBridge'
import type { ActionState } from '../../../../../../action/actionStore'
import { preferenceStore } from '../../../../../../preferences/store'
import ActionResultContent from './ActionResultContent'
import WindowFooter from './WindowFooter'

type Props = Pick<ActionState, 'requestId' | 'selectedText' | 'content' | 'status' | 'error'>

const ActionTranslate: FC<Props> = ({ requestId, selectedText, content, status, error }) => {
  const { t } = useTranslation()
  const preferences = useSyncExternalStore(preferenceStore.subscribe, preferenceStore.getSnapshot)
  const [showOriginal, setShowOriginal] = useState(false)
  if (!requestId) return null

  const isStreaming = status === 'loading'

  return (
    <>
      <div className="flex w-full flex-1 flex-col items-center">
        <div className="flex w-full flex-wrap items-center gap-x-1.5 gap-y-1">
          <div className="flex min-w-0 shrink items-center gap-1.5">
            <div className="flex min-w-0 items-center whitespace-nowrap rounded bg-muted px-2 py-1 text-muted-foreground text-xs">
              <Globe2 className="mr-1 inline size-3.5 shrink-0" />
              <span className="min-w-0 truncate">{t('translate.detected.language')}</span>
            </div>
            <ArrowRight className="size-4 shrink-0 text-muted-foreground" />
            <div className="min-w-[100px] max-w-[160px] rounded bg-muted px-2 py-1 text-xs">
              {preferences.api.targetLanguage}
            </div>
          </div>
          <div className="ml-auto flex shrink-0 items-center gap-1">
            <button
              type="button"
              onClick={() => setShowOriginal(!showOriginal)}
              className="flex h-7 items-center gap-1 rounded px-2 text-muted-foreground text-xs hover:bg-accent hover:text-foreground">
              {showOriginal
                ? t('selection.action.window.original_hide')
                : t('selection.action.window.original_show')}
              <ChevronDown size={14} className={cn('transition-transform', showOriginal && 'rotate-180')} />
            </button>
          </div>
        </div>
        {showOriginal && (
          <div className="mt-2 mb-3 w-full whitespace-pre-wrap break-words rounded bg-muted p-2 text-muted-foreground text-xs">
            {selectedText}
            <div className="flex justify-end">
              <button
                type="button"
                aria-label={t('selection.action.window.original_copy')}
                onClick={() => nativeBridge.send({ type: 'result.copy', content: selectedText })}>
                <Copy size={12} />
              </button>
            </div>
          </div>
        )}
        <div className="mt-3 w-full">
          {isStreaming && !content && <Loader2 className="size-4 animate-spin text-muted-foreground" />}
          {content && <ActionResultContent content={content} />}
        </div>
        {error && (
          <div
            role="alert"
            className="mt-3 mb-3 w-full break-all rounded border border-error-border bg-error-subtle px-3 py-2 text-[13px] text-error-subtle-foreground">
            {error.message}
          </div>
        )}
      </div>
      <div className="min-h-3" />
      <WindowFooter requestId={requestId} loading={isStreaming} content={content} />
    </>
  )
}

export default ActionTranslate
