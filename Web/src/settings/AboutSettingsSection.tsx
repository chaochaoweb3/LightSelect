import { ExternalLink, ShieldCheck } from 'lucide-react'
import type { FC } from 'react'

import { useTranslation } from '../adapters/i18n'
import { nativeBridge } from '../bridge/nativeBridge'

const AboutSettingsSection: FC = () => {
  const { t } = useTranslation()
  return <section className="lightselect-settings-section">
    <div className="lightselect-about-product"><strong>LightSelect</strong><span>2.0</span></div>
    <div className="lightselect-setting-row"><div className="lightselect-row-copy"><ShieldCheck aria-hidden="true" /><div><div className="text-sm">{t('settings.accessibility')}</div><div className="text-muted-foreground text-xs">{t('settings.accessibility.description')}</div></div></div><button type="button" onClick={() => nativeBridge.send({ type: 'application.openAccessibilitySettings' })}>{t('settings.accessibility.open')}</button></div>
    <div className="lightselect-setting-row"><div className="lightselect-row-copy"><ExternalLink aria-hidden="true" /><div><div className="text-sm">{t('settings.source')}</div><div className="text-muted-foreground text-xs">AGPL-3.0</div></div></div><button type="button" onClick={() => nativeBridge.send({ type: 'application.openSource' })}>{t('settings.source')}</button></div>
  </section>
}

export default AboutSettingsSection
