import type { ErrorInfo, ReactNode } from 'react'
import { Component } from 'react'

type ErrorBoundaryState = { failed: boolean }

export class ErrorBoundary extends Component<{ children: ReactNode }, ErrorBoundaryState> {
  state: ErrorBoundaryState = { failed: false }

  static getDerivedStateFromError(): ErrorBoundaryState {
    return { failed: true }
  }

  componentDidCatch(error: Error, info: ErrorInfo): void {
    console.error('Selection toolbar failed to render', error, info.componentStack)
  }

  render(): ReactNode {
    if (this.state.failed) {
      return <div role="alert">LightSelect failed to render.</div>
    }
    return this.props.children
  }
}
