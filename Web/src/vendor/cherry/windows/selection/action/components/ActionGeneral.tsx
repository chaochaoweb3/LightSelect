// Adapted from Cherry Studio src/renderer/windows/selection/action/components/ActionGeneral.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import { ChevronDown, Copy, Loader2 } from 'lucide-react'
import type { FC } from 'react'
import { useState } from 'react'

import { cn } from '../../../../../../adapters/cn'
import { useTranslation } from '../../../../../../adapters/i18n'
import { nativeBridge } from '../../../../../../bridge/nativeBridge'
import type { SelectionActionItem } from '../../../../../../bridge/types'
import type { ActionState } from '../../../../../../action/actionStore'
import ActionResultContent from './ActionResultContent'
import WindowFooter from './WindowFooter'

type Props = Pick<ActionState, 'requestId' | 'selectedText' | 'content' | 'status' | 'error'> & {
  action: SelectionActionItem
}

const ActionGeneral: FC<Props> = ({ requestId, selectedText, content, status, error }) => {
  const { t } = useTranslation()
  const [showOriginal, setShowOriginal] = useState(false)
  if (!requestId) return null

  const isStreaming = status === 'loading'

  return (
    <>
      <div className="flex w-full flex-col items-center justify-center">
        <div className="flex w-full flex-row items-center justify-end">
          <button
            type="button"
            onClick={() => setShowOriginal(!showOriginal)}
            className="flex cursor-pointer items-center justify-between text-muted-foreground text-xs transition-colors hover:text-foreground">
            <span>
              {showOriginal
                ? t('selection.action.window.original_hide')
                : t('selection.action.window.original_show')}
            </span>
            <ChevronDown size={14} className={cn('transition-transform', showOriginal && 'rotate-180')} />
          </button>
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
        <div className="mt-1 w-full">
          {isStreaming && !content && <Loader2 className="size-4 animate-spin text-muted-foreground" />}
          {content && <ActionResultContent content={content} />}
        </div>
        {error && (
          <div
            role="alert"
            className="mt-3 mb-3 break-all rounded border border-error-border bg-error-subtle px-3 py-2 text-[13px] text-error-subtle-foreground">
            {error.message}
          </div>
        )}
      </div>
      <div className="min-h-3" />
      <WindowFooter requestId={requestId} loading={isStreaming} content={content} />
    </>
  )
}

export default ActionGeneral
