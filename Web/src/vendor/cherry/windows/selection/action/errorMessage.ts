// Adapted from Cherry Studio src/renderer/windows/selection/action/errorMessage.ts @ 83d9d6325f7a00ab03a59eea31d0c943b3acf530.
type Translate = (key: string) => string
const TRANSLATE_ERROR_KEY_PATTERN = /^translate\.error\.[a-zA-Z0-9_.-]+$/

export function getSelectionActionErrorMessage(error: unknown, t: Translate): string {
  const message = error instanceof Error ? error.message : String(error)
  return error instanceof Error && TRANSLATE_ERROR_KEY_PATTERN.test(message) ? t(message) : message
}
