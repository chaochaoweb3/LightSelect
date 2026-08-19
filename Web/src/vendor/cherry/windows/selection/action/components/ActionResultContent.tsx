// Adapted from Cherry Studio src/renderer/windows/selection/action/components/ActionResultContent.tsx @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
import type { FC, MouseEvent } from 'react'
import Markdown from 'react-markdown'
import remarkGfm from 'remark-gfm'

import { nativeBridge } from '../../../../../../bridge/nativeBridge'

const ActionResultContent: FC<{ content: string }> = ({ content }) => (
  <div className="lightselect-markdown w-full text-foreground text-sm">
    <Markdown
      remarkPlugins={[remarkGfm]}
      components={{
        a: ({ children, href, ...props }) => (
          <a
            {...props}
            href={href}
            onClick={(event: MouseEvent<HTMLAnchorElement>) => {
              event.preventDefault()
              if (href) nativeBridge.send({ type: 'system.openURL', url: href })
            }}>
            {children}
          </a>
        )
      }}>
      {content}
    </Markdown>
  </div>
)

export default ActionResultContent
