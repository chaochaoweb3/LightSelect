// Adapted from Cherry Studio src/renderer/windows/selection/action/components/WindowFooter.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import { Copy, RefreshCw, Square, X } from 'lucide-react'
import type { FC } from 'react'
import { useCallback, useEffect } from 'react'

import { cn } from '../../../../../../adapters/cn'
import { useTranslation } from '../../../../../../adapters/i18n'
import { nativeBridge } from '../../../../../../bridge/nativeBridge'

interface FooterProps {
  requestId: string
  content?: string
  loading?: boolean
}

const WindowFooter: FC<FooterProps> = ({ requestId, content = '', loading = false }) => {
  const { t } = useTranslation()

  const handleStop = useCallback(() => {
    nativeBridge.send({ type: 'action.cancel', requestId })
  }, [requestId])

  const handleClose = useCallback(() => {
    nativeBridge.send({ type: 'action.close' })
  }, [])

  const handleEsc = useCallback(() => {
    if (loading) handleStop()
    else handleClose()
  }, [handleClose, handleStop, loading])

  const handleRegenerate = useCallback(() => {
    if (loading) nativeBridge.send({ type: 'action.cancel', requestId })
    nativeBridge.send({ type: 'action.regenerate', requestId })
  }, [loading, requestId])

  const handleCopy = useCallback(() => {
    if (content && !loading) nativeBridge.send({ type: 'result.copy', content })
  }, [content, loading])

  useEffect(() => {
    const handleKeyDown = (event: KeyboardEvent): void => {
      if (event.key === 'Escape') handleEsc()
    }
    window.addEventListener('keydown', handleKeyDown)
    return () => window.removeEventListener('keydown', handleKeyDown)
  }, [handleEsc])

  const footerButtonClassName = (enabled: boolean, danger = false) =>
    cn(
      'flex h-7 cursor-pointer select-none flex-row items-center justify-center gap-1.5 overflow-hidden text-ellipsis whitespace-nowrap rounded-md border border-transparent bg-muted px-2.5 text-muted-foreground text-xs transition-colors',
      enabled ? 'opacity-100' : 'cursor-default opacity-20',
      danger
        ? 'min-w-[64px] border-error-border bg-error-subtle text-error hover:bg-error-border hover:text-error'
        : 'hover:text-foreground hover:[&_.btn-icon]:text-foreground'
    )

  return (
    <div className="-translate-x-1/2 absolute bottom-0 left-1/2 flex h-10 w-[calc(100%-16px)] min-w-min max-w-[480px] flex-row items-center justify-center rounded-lg px-2 py-1.5 backdrop-blur-sm transition-all duration-300">
      <div className="flex flex-row items-center justify-center gap-1.5 text-muted-foreground text-xs">
        {loading && (
          <button type="button" onClick={handleStop} className={footerButtonClassName(true, true)}>
            <Square className="btn-icon size-3 fill-current" aria-hidden="true" />
            {t('selection.action.window.esc_stop')}
          </button>
        )}
        <button type="button" onClick={handleClose} className={footerButtonClassName(true)}>
          <X size={14} className="btn-icon" aria-hidden="true" />
          {t('selection.action.window.esc_close')}
        </button>
        <button type="button" onClick={handleRegenerate} className={footerButtonClassName(true)}>
          <RefreshCw size={14} className="btn-icon" />
          {t('selection.action.window.r_regenerate')}
        </button>
        <button
          type="button"
          disabled={!content || loading}
          onClick={handleCopy}
          className={footerButtonClassName(Boolean(content) && !loading)}>
          <Copy size={14} className="btn-icon" />
          {t('selection.action.window.c_copy')}
        </button>
      </div>
    </div>
  )
}

export default WindowFooter
