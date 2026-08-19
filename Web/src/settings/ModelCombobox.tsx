import { LoaderCircle, RefreshCw } from 'lucide-react'
import type { FC } from 'react'
import { useState } from 'react'

const ModelCombobox: FC<{
  value: string
  models: string[]
  loading: boolean
  onChange: (value: string) => void
  onCommit: (value: string) => void
  onRefresh: () => void
  refreshLabel: string
}> = ({ value, models, loading, onChange, onCommit, onRefresh, refreshLabel }) => {
  const [open, setOpen] = useState(false)
  const [activeIndex, setActiveIndex] = useState(-1)
  const listID = 'lightselect-model-options'
  const choose = (model: string): void => {
    onChange(model)
    onCommit(model)
    setOpen(false)
    setActiveIndex(-1)
  }
  return <div className="lightselect-model-combobox">
    <div className="lightselect-field-control">
      <input
        role="combobox"
        aria-label="Model"
        aria-controls={listID}
        aria-expanded={open && models.length > 0}
        aria-activedescendant={activeIndex >= 0 ? `${listID}-${activeIndex}` : undefined}
        value={value}
        onFocus={() => setOpen(true)}
        onChange={(event) => { onChange(event.currentTarget.value); setOpen(true); setActiveIndex(-1) }}
        onBlur={(event) => onCommit(event.currentTarget.value)}
        onKeyDown={(event) => {
          if (event.key === 'Escape') {
            setOpen(false)
            setActiveIndex(-1)
          } else if (event.key === 'ArrowDown' && models.length > 0) {
            event.preventDefault()
            setOpen(true)
            setActiveIndex((current) => Math.min(current + 1, models.length - 1))
          } else if (event.key === 'ArrowUp' && models.length > 0) {
            event.preventDefault()
            setOpen(true)
            setActiveIndex((current) => current <= 0 ? models.length - 1 : current - 1)
          } else if (event.key === 'Enter' && open && activeIndex >= 0) {
            event.preventDefault()
            choose(models[activeIndex])
          }
        }}
      />
      <button type="button" aria-label={refreshLabel} title={refreshLabel} aria-busy={loading} disabled={loading} onClick={() => { setOpen(true); onRefresh() }}>
        {loading ? <LoaderCircle className="is-spinning" /> : <RefreshCw />}
      </button>
    </div>
    {open && models.length > 0 && <div role="listbox" id={listID} className="lightselect-model-list">
      {models.map((model, index) => <button key={model} id={`${listID}-${index}`} type="button" role="option" aria-selected={model === value} onMouseDown={(event) => event.preventDefault()} onClick={() => choose(model)}>{model}</button>)}
    </div>}
  </div>
}

export default ModelCombobox
